/*

# Filename:         spi_slave.sv

# File Description: Three-wire SPI slave front end for the PMIC supervisor. Converts
#                   bus transactions into addr / wr_en / wdata / rdata accesses on
#                   reg_file.
#
#                   Mode 0 (CPOL = 0, CPHA = 0), MSB first, half duplex on a single
#                   bidirectional SDIO line. SCK, CS and SDIO are oversampled in the
#                   50 MHz domain rather than SCK being used as a clock: that keeps
#                   the design in one clock domain, keeps SCK off the global clock
#                   network, and is what makes digital filtering of SCK possible at
#                   all. Filtering required as a 450 kHz half-bridge large voltage swings
#                   sits a few centimetres away for the life of the board.
#
#                   Write frame:  [cmd] [data ...] [CRC]
#                   Read frame:   [cmd] [turnaround] [data ...]
#
#                   The turnaround BYTE, rather than a single dummy bit, exists
#                   because MCU hardware SPI peripherals clock whole 8- or 16-bit
#                   frames and cannot generate a lone 9th clock. It also gives eight
#                   clocks of dead time for the master to release SDIO before the
#                   slave drives it, instead of half a bit period.

# Global variables: None

*/

`default_nettype none

module spi_slave
    import pmic_types_pkg::*;
#(
    // SCK_IDLE_TIMEOUT_CLKS: SCK silent this long with CS still low means the master
    //                        died mid-transaction. Without this the slave can sit
    //                        waiting forever, and on a read it would hold SDIO driven.
    parameter int SCK_IDLE_TIMEOUT_CLKS = ms_to_clks(2)
)(
    input  wire logic       clk,
    input  wire logic       rst_n,

    // ---------------- bus side ----------------
    // Already synchronised AND filtered in pmic_top. This module never sees a raw
    // pin, and all three lines must use IDENTICAL filter settings - unequal delay
    // between sck and sdio_in shifts the data relative to the clock.
    input  wire logic       sck,
    input  wire logic       cs_n,
    input  wire logic       sdio_in,
    output logic            sdio_out,
    // sdio_oe: drive enable. High only while shifting out read data. The tri-state
    //          itself lives in pmic_top so simulation and hardware agree.
    output logic            sdio_oe,

    // ---------------- reg_file side ----------------
    output logic [6:0]      addr,
    // wr_en: one pulse per DATA byte. Never pulses for the command byte or the CRC
    //        byte - see BLOCK 5.
    output logic            wr_en,
    output logic [7:0]      wdata,
    input  wire logic [7:0] rdata,
    output logic            rd_first,
    // integrity_ok: CS rose on a byte boundary, length was legal, CRC checked out
    output logic            integrity_ok,
    // abort: write transaction ended any other way
    output logic            abort
);

    // sck_d / cs_n_d: delayed copies, one clk, for edge detection. sck is treated
    //                 as ordinary data here.
    logic sck_d, cs_n_d;

    // One-clock enable pulses derived from them.
    logic sck_rise;   // master samples SDIO here, so the slave shifts IN here
    logic sck_fall;   // slave changes SDIO here, so it is stable across the rise
    logic cs_fall;    // start of a transaction
    logic cs_rise;    // end of a transaction - the only commit/discard decision point
    // bit_count: bits received within the present byte, 0..7. Nonzero at cs_rise
    //            means the master stopped mid-byte, which invalidates a write.
    logic [2:0] bit_count;

    // byte_count: bytes completed since cs_fall. Saturates rather than wrapping, so
    //             a long transaction cannot roll it back under the length check.
    //             Only the first few values are ever tested.
    logic [3:0] byte_count;

    // byte_done: one-clock pulse on the SCK rise that completes a byte
    logic       byte_done;
    // rx_byte: the byte completing on this rising edge. rx_shift holds the pre-edge
    //          value, so the arriving bit must be appended here rather than read
    //          from the register.
    logic [7:0] rx_byte;

    // ==================================================================
    // FSM states
    // ==================================================================
    // S_IDLE      : CS high, nothing happening
    // S_CMD       : receiving the command byte
    // S_WRITE     : receiving data bytes, then the CRC byte
    // S_TURN      : read turnaround byte; nobody drives SDIO
    // S_READ      : shifting read data out
    // S_DEAD      : transaction poisoned (timeout, or illegal length); wait for CS
    //               to rise, commit nothing


    // Transaction states. Two bits would hold four, so three are needed for six.
    typedef enum logic [2:0] {

      S_IDLE = 3'b000,    // CS high, nothing happening
      S_CMD = 3'b001,     // receiving the command byte
      S_WRITE = 3'b010,   // receiving data bytes, then the CRC byte
      S_TURN = 3'b011,    // read turnaround byte; nobody drives SDIO
      S_READ = 3'b100,    // shifting read data out
      S_DEAD = 3'b101     // poisoned; wait for CS to rise, commit nothing

    } spi_states_t;

    spi_states_t spi_state,spi_state_next;
     // rw: bit 7 of the command byte, 1 = read
    logic rw;
    // sck_timeout: one-clock pulse.
    logic sck_timeout;
    // rx_shift: receive staging register. Seven bits, not eight - rx_byte appends
    //           the arriving bit to complete a byte, so an eighth bit here would
    //           shift out unused.
    logic [6:0] rx_shift;
    // crc: running CRC-8 over every received bit. Polynomial 0x07, init 0x00, no
    //      final XOR. The host must use the same parameters - a datasheet
    //      requirement, since CRC-8 has no universal default.
    logic [7:0] crc;
    // held_data: one-byte delay line. A completed byte waits here until the NEXT
    //            byte completes, which is the only moment it is known not to have
    //            been the CRC.
    logic [7:0] held_data;
    // held_valid: the delay line holds a byte not yet released
    logic       held_valid;
    /* verilator lint_off UNUSEDSIGNAL */
    // tx_shift: transmit shift register, MSB first. Bit 7 is written on load but
    //           never read - sdio_out takes rdata[7] on the load and tx_shift[6] on
    //           each shift, so the top bit is always one position ahead of what is
    //           needed. Kept 8 bits so a load is a plain byte assignment.
    logic [7:0] tx_shift;
    /* verilator lint_on UNUSEDSIGNAL */

    // ==================================================================
    // BLOCK 1 - edge detection
    // ==================================================================
    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Delayed copies of sck and cs_n so the four edges below can be detected
    combinationally. Everything in this module is an enable on the 50 MHz domain;
    sck is never used as a clock.
    */

    if(!rst_n) begin
      
      sck_d <= 0;
      cs_n_d <= 1;

    end

    else begin

      sck_d <= sck;
      cs_n_d <= cs_n;

    end
    end

    always_comb begin
    /*
    Purpose:
    ---
    Produce the one-clock enable pulses the rest of the module runs on.
    */

    sck_fall = sck_d & ~sck;
    sck_rise = ~sck_d & sck;
    cs_fall = cs_n_d & ~cs_n;
    cs_rise = ~cs_n_d & cs_n;

    end


    // ==================================================================
    // BLOCK 2 - transaction FSM
    // ==================================================================
    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    State register. Reset to S_IDLE, which is also where every abandoned transaction
    ends up once CS rises.
    */

    if(!rst_n) begin
      spi_state <= S_IDLE;
    end

    else
      spi_state <= spi_state_next;
    end

    always_comb begin

    /*
    Purpose:
    ---
    Next-state logic.

    Two conditions are checked ahead of the case and override every state. cs_fall
    restarts the transaction from anywhere, so a master that abandons one and asserts
    CS again needs no timeout to recover. cs_rise returns to idle from anywhere, since a transaction cannot
    outlive its chip select.

    sck_timeout poisons the transaction to S_DEAD rather than returning to idle. 
    S_DEAD holds until CS actually rises, so SDIO stays released
    and BLOCK 9 sees a state it can refuse to commit. Dropping straight to S_IDLE
    would leave the FSM ready to misread the next edges of a transaction that is still
    physically in progress.

    rx_byte[7] is used rather than the latched rw: on the byte_done clock rw still
    holds its pre-edge value, because it is being assigned on that same edge in
    BLOCK 4.
    */

    spi_state_next = spi_state;

    if(cs_fall) begin
      spi_state_next = S_CMD;
    end

    else if (cs_rise) begin
      spi_state_next = S_IDLE;
    end

    else if (sck_timeout && (spi_state != S_IDLE)) begin

      spi_state_next = S_DEAD;

    end

    else begin

      unique case(spi_state)

        S_IDLE  : spi_state_next = S_IDLE;        // only cs_fall leaves
        // The command byte decides the direction of everything that follows.
        S_CMD   : if (byte_done) spi_state_next = rx_byte[7] ? S_TURN : S_WRITE;
        // Data bytes then the CRC byte. The CRC is not distinguished here -
        // delay line is what keeps it from reaching reg_file.
        S_WRITE : spi_state_next = S_WRITE;
        // One full byte during which NOBODY drives SDIO. The master needs
        // time to release the line before the slave drives it; contention
        // on a push-pull line is a short between a driver sourcing and one
        // sinking.
        S_TURN  : if (byte_done) spi_state_next = S_READ;
        S_READ  : spi_state_next = S_READ;
        // Poisoned. Only cs_rise leaves, handled above.
        S_DEAD  : spi_state_next = S_DEAD;
        default : spi_state_next = S_DEAD;

      endcase

    end

    end


    // ==================================================================
    // BLOCK 3 - bit and byte counters
    // ==================================================================

    always_comb begin
      /*
    Purpose:
    ---
    Flag the rising edge that completes a byte. bit_count holds the PRE-edge value,
    so the eighth bit of a byte arrives while bit_count reads 7.
    */

      byte_done = sck_rise & (bit_count == 3'd7);

    end

    always_ff @ (posedge clk or negedge rst_n) begin

       /*
    Purpose:
    ---
    Count bits within a byte and bytes within a transaction.

    cs_fall clears both, so a master that abandons a transaction and asserts CS again
    starts from a clean count with no timeout needed. 

    bit_count wraps naturally at 8 because it is three bits wide - no comparison and
    no reset term is needed on the count itself.

    byte_count saturates instead of wrapping. The length check at cs_rise only asks
    whether at least three bytes arrived, so counting past the saturation point is
    wasted, and a wrap could make a very long transaction look too short.

    Nothing here is gated on the FSM state: bits and bytes are counted identically
    whether the transaction turns out to be a read or a write, and the FSM in BLOCK 2
    is driven BY these counters rather than the other way round.
    */
      if(!rst_n) begin

        bit_count <= 0;
        byte_count <= 0;

      end

      else if (cs_fall) begin

        bit_count <= 0;
        byte_count <= 0;

      end

      else if (sck_rise) begin

        bit_count <= bit_count + 1;
        
        if(byte_done && !(&byte_count)) begin

            byte_count <= byte_count + 1;

        end

      end

    end
 
    // ==================================================================
    // BLOCK 4 - receive shift, command capture and write delay line
    // ==================================================================

    
    always_comb rx_byte = {rx_shift, sdio_in};

    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Shift SDIO in on each rising SCK edge, capture the command byte, and release data
    bytes to reg_file one byte late.

    Sampling on the RISING edge is Mode 0: the master changes SDIO on falling edges,
    so by the rising edge the bit has had half a period to settle.

    rx_shift is NOT cleared between bytes. Each byte pushes the previous one out and
    only the eight most recent bits are ever read.

    The DELAY LINE exists because a write frame carries no length field, so a
    completed byte cannot be classified until the next one arrives. Each finished byte
    goes into held_data, and the byte already held is released as wr_en only when the
    FOLLOWING byte completes. At cs_rise whatever is still held is the CRC, and it is
    discarded by doing nothing with it.

    The command capture and the delay line share this block because both drive addr -
    one loads it from the command byte, the other increments it per released byte.
    Driving one variable from two always_ff blocks is illegal, and they are mutually
    exclusive by state anyway.
    */
        if (!rst_n) begin
            rx_shift   <= 7'h00;
            rw         <= 1'b0;
            addr       <= 7'h00;
            held_data  <= 8'h00;
            held_valid <= 1'b0;
            wr_en      <= 1'b0;
            wdata      <= 8'h00;
        end
        else begin

            wr_en <= 1'b0;                      // one-clock pulse, default low

            if (sck_rise) begin
                rx_shift <= {rx_shift[5:0], sdio_in};
            end

            if (cs_fall) begin
                held_valid <= 1'b0;             // nothing carries between transactions
            end
            else if (byte_done) begin

                // ---- command byte: direction and starting address ----
                if (spi_state == S_CMD) begin
                    rw   <= rx_byte[7];
                    addr <= rx_byte[6:0];
                end

                // ---- data byte: release the previous one, hold this one ----
                else if (spi_state == S_WRITE) begin
                    if (held_valid) begin
                        wdata <= held_data;
                        wr_en <= 1'b1;
                        addr  <= addr + 7'd1;   // auto-increment for the NEXT byte
                    end

                    held_data  <= rx_byte;
                    held_valid <= 1'b1;
                end

                else if (spi_state == S_READ) begin
                    addr <= addr + 7'd1;
                end

            end

        end
    end

    // ==================================================================
    // BLOCK 6 - CRC-8
    // ==================================================================
    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Update a CRC-8 over every bit received while CS is low.

    No byte awareness is needed, and none of the block is gated on the FSM state.
    Running a CRC over a message followed by its own CRC leaves the register at zero,
    so the check in BLOCK 9 is simply crc == 0. That property is why the CRC byte
    does not have to be separated out here - it is just eight more bits.

    The shift is the standard bitwise form: XOR the incoming bit with the MSB, shift
    left, and XOR in the polynomial if that top bit was set. One XOR tree and eight
    flops.

    Reads also update the CRC. The result is simply ignored, because a read has
    nothing to commit and the host is free to stop mid-byte.
    */

     if (!rst_n) begin
            crc <= 8'h00;
        end
        else if (cs_fall) begin
            crc <= 8'h00;          // init value, fresh for each transaction
        end
        else if (sck_rise) begin
            if (crc[7] ^ sdio_in) crc <= (crc << 1) ^ 8'h07;
            else                  crc <= (crc << 1);
        end

    end


    // ==================================================================
    // BLOCK 7 - transmit shift
    // ==================================================================
        always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Load rdata into tx_shift and shift it out MSB first on FALLING SCK edges, so each
    bit is stable across the rising edge where the master samples it - half a bit
    period of setup, 500 ns at 1 MHz.

    With CPHA = 0 there is no clock edge available
    to launch the first bit of a byte: the first edge of the byte is a sampling edge,
    not a shifting one. The first byte is therefore loaded on the LAST FALLING EDGE OF
    THE TURNAROUND BYTE, before any of its own clocks arrive. Every byte after it is
    loaded on the falling edge that follows its predecessor's eighth rising edge,
    which exists and is free.

    sdio_oe is asserted only in S_READ. During S_CMD, S_TURN, S_WRITE, S_DEAD and
    S_IDLE the slave leaves SDIO entirely alone, so the master owns the line for the
    whole command byte and the whole turnaround byte.

    rd_first pulses on the load of the first read byte. reg_file uses it to snapshot
    multi-byte values so a burst read cannot tear.
    */

        if (!rst_n) begin
            tx_shift <= 8'h00;
            sdio_out <= 1'b0;
            sdio_oe  <= 1'b0;
            rd_first <= 1'b0;
        end
        else begin

            rd_first <= 1'b0;                   // one-clock pulse, default low

            // ---- release the line outside S_READ ----
            if (spi_state != S_READ) begin
                sdio_oe <= 1'b0;
            end

            if (sck_fall) begin

                // Last falling edge of the turnaround byte: load the FIRST read byte
                // and take the line. bit_count is 7 here, the pre-edge value for the
                // turnaround byte's eighth bit.
                if ((spi_state == S_TURN) && (bit_count == 3'd7)) begin
                    tx_shift <= rdata;
                    sdio_out <= rdata[7];
                    sdio_oe  <= 1'b1;
                    rd_first <= 1'b1;
                end

                else if (spi_state == S_READ) begin

                    // Byte boundary: the previous byte's eighth bit was sampled on
                    // the rising edge just passed, so addr has already advanced and
                    // rdata has settled. Load the next byte.
                    if (bit_count == 3'd0) begin
                        tx_shift <= rdata;
                        sdio_out <= rdata[7];
                    end

                    // Within a byte: shift out the next bit.
                    else begin
                        tx_shift <= {tx_shift[6:0], 1'b0};
                        sdio_out <= tx_shift[6];
                    end

                end
            end

        end
    end


    // ==================================================================
    // BLOCK 8 - SCK idle timeout
    // ==================================================================

    // idle_counter: clocks since the last SCK edge, while CS is low. Sized for the
    //               full timeout so it cannot wrap and re-arm.
    logic [$clog2(SCK_IDLE_TIMEOUT_CLKS+1)-1:0] idle_counter;

    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Count clocks since the last SCK edge while CS is low, and poison the transaction
    on expiry.

    This covers the one case CS framing cannot: a master that asserts CS, sends part
    of a transaction, then stops clocking WITHOUT releasing CS. Power loss, a reset
    mid-burst, a yanked header. The board is detachable, so this is routine rather
    than exotic.

    Without it the slave sits waiting forever, and on a read it would hold SDIO
    driven - blocking the line for anything else and, on silicon, sinking current
    into whatever the master's pad does when unpowered.

    The counter is held at zero whenever CS is high, so it measures silence WITHIN a
    transaction, not idle bus time. Either SCK edge resets it: a master clocking at
    any rate above roughly 4 kHz never trips it.

    sck_timeout is a one-clock pulse. BLOCK 2 consumes it and moves to S_DEAD, which
    is what actually releases the line and refuses the commit.
    */

    if (!rst_n) begin

      idle_counter <= 0;
      sck_timeout <= 0;

    end

    else begin

      sck_timeout <= 0;

      if(cs_n) begin

        idle_counter <= 0;

      end

      else if (sck_rise || sck_fall) begin

        idle_counter <= 0; //master alive

      end

       else if (idle_counter == SCK_IDLE_TIMEOUT_CLKS[$bits(idle_counter)-1:0]) begin
                sck_timeout  <= 1'b1;
                idle_counter <= '0;

       end

       else begin
        
        idle_counter <= idle_counter + 1;

       end  

    end
    end


    // ==================================================================
    // BLOCK 9 - transaction end
    // ==================================================================
    always_ff @(posedge clk or negedge rst_n) begin
     /*
    Purpose:
    ---
    Decide, at cs_rise, whether a write transaction committed or was discarded.

    integrity_ok requires ALL of:
      - the transaction was a write (rw low)
      - CS rose on a byte boundary (bit_count == 0), so no byte was left partial
      - at least three bytes arrived: command, one data byte, CRC
      - crc == 0, which is the CRC-8 property that a message followed by its own
        CRC divides to zero

    Anything else on a write pulses abort instead, and reg_file discards its
    temporary registers.

    Reads produce NEITHER pulse. There is nothing to commit and nothing to discard,
    and a host is free to stop a read mid-byte.

    S_DEAD produces abort regardless: a timed-out transaction must never commit, even
    if the bytes that did arrive happen to satisfy the length and CRC checks.

    Both pulses land on cs_rise, which is at least one clock after the last wr_en -
    wr_en fires on an sck_rise, and cs_rise cannot coincide with one. This matters
    because reg_file gives integrity_OK priority over wr_en, so a write landing on the
    same edge would be dropped.
    */

    if(!rst_n) begin

      integrity_ok <= 0;
      abort <= 0;

    end

    else begin 


      integrity_ok <= 1'b0;
      abort        <= 1'b0;

        if (cs_rise && !rw) begin
                if ((spi_state != S_DEAD) &&
                    (bit_count == 3'd0)   &&
                    (byte_count >= 4'd3)  &&
                    (crc == 8'h00))
                    integrity_ok <= 1'b1;
                else
                    abort        <= 1'b1;
      
      end

    end
    end


endmodule

`default_nettype wire

