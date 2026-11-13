/*

# Filename:         spi_slave_sva.sv

# File Description: Concurrent assertion checker for spi_slave. Attached with
#                   bind so the RTL carries no assertion constructs and the
#                   sv2v / Yosys ASIC path never sees them.
#
#                   SCOPE. This file owns the cycle-level rules of the SPI
#                   front end: state entries, MISO direction and bit timing,
#                   how addr moves, when wr_en / rd_first / rd_byte_done may
#                   pulse, the SCK idle timeout, and the commit / abort
#                   decision at CS rise. The value claims go to the cocotb
#                   scoreboard instead: that wdata equals the byte the host
#                   sent, that MISO carries rdata of the addressed register
#                   MSB first, and that integrity_ok agrees with a CRC-8 from
#                   an independent model. Those are M claims - the expected
#                   value depends on the frame the testbench chose.
#
#                   INDEPENDENCE. Bit, byte and silence counts are rebuilt
#                   here from sck, cs_n and sdio_in rather than read from
#                   bit_count, byte_count and idle_counter. The only DUT
#                   internal read is spi_state, whose six states and
#                   encodings are documented in spi_slave.sv's header.
#
#                   EDGE OFFSETS. Two numbers here were pinned from the RTL,
#                   because the header says "this long" and "after the strobe"
#                   without saying which clock:
#                     - S_DEAD first reads true when chk_silence equals the
#                       timeout plus 2: one clock for idle_counter's compare
#                       to raise sck_timeout, one for the FSM to register it.
#                     - addr advances on the clock AFTER wr_en, so reg_file
#                       sees each strobe with the address its byte belongs to.
#
#                   STATE ENTRIES. Every state's entry carries its own
#                   precondition (groups 3 and 4), so any illegal transition
#                   fails the property of the state it lands in. No separate
#                   transition table is needed.

# Global variables: None

*/

`default_nettype none

module spi_slave_sva #(
    // SCK_IDLE_TIMEOUT_CLKS: passed through from the bound instance, so a
    //                        testbench can shrink the 2 ms timeout to a few
    //                        dozen clocks and still hit the exact boundary
    parameter int SCK_IDLE_TIMEOUT_CLKS = pmic_types_pkg::ms_to_clks(2)
)(
    input  wire logic       clk,
    input  wire logic       rst_n,
    input  wire logic       sck,
    input  wire logic       cs_n,
    input  wire logic       sdio_in,
    input  wire logic       sdio_out,
    input  wire logic       sdio_oe,
    input  wire logic [6:0] addr,
    input  wire logic       wr_en,
    input  wire logic       rd_first,
    input  wire logic       rd_byte_done,
    input  wire logic       integrity_ok,
    input  wire logic       txn_abort,
    // DUT internal, connected explicitly in bind_sva.sv. The state names and
    // encodings are part of spi_slave.sv's documented contract.
    input  wire logic [2:0] dut_spi_state
);

// S_*: spi_slave's state encodings, copied from its header. A mismatch here
//      makes nearly every state property fire, so it cannot hide.
localparam logic [2:0] S_IDLE  = 3'b000;
localparam logic [2:0] S_CMD   = 3'b001;
localparam logic [2:0] S_WRITE = 3'b010;
localparam logic [2:0] S_TURN  = 3'b011;
localparam logic [2:0] S_READ  = 3'b100;
localparam logic [2:0] S_DEAD  = 3'b101;

// SILENCE_W: wide enough to count past the timeout boundary without saturating
localparam int SILENCE_W = $clog2(SCK_IDLE_TIMEOUT_CLKS + 4) + 1;

// DEAD_AT_SILENCE: chk_silence entering the edge where spi_state first reads
//                  S_DEAD - see EDGE OFFSETS in the header
localparam logic [SILENCE_W-1:0] DEAD_AT_SILENCE = SILENCE_W'(SCK_IDLE_TIMEOUT_CLKS + 2);

// sck_q / cs_n_q: one-clock delayed copies of the bus lines, the checker's
//                 own edge detectors
logic sck_q, cs_n_q;

// chk_sck_rise / chk_cs_fall / chk_cs_rise: edge pulses rebuilt from the pins
logic chk_sck_rise, chk_cs_fall, chk_cs_rise;

// chk_bit_count: bits received in the present byte, value entering this edge
logic [2:0] chk_bit_count;

// chk_byte_done: this rising SCK edge completes a byte
logic chk_byte_done;

// chk_byte_count: whole bytes since CS fell, saturating at all-ones
logic [7:0] chk_byte_count;

// chk_shift_byte: the last eight MOSI bits, newest in bit 0
logic [7:0] chk_shift_byte;

// chk_cmd_valid: this transaction's command byte has completed AND spi_slave
//                accepted it (it was in S_CMD, not timed out). A host may keep
//                clocking after a stall, so the pins alone can show a whole
//                command byte the slave never accepted.
logic chk_cmd_valid;

// chk_is_read: bit 7 of this transaction's command byte, i.e. its first MOSI bit
logic chk_is_read;

// chk_write_bytes: bytes completed after the command in a write (data + CRC),
//                  saturating
logic [7:0] chk_write_bytes;

// chk_strobes: wr_en pulses since CS fell, saturating
logic [7:0] chk_strobes;

// chk_seen_rd_first: rd_first has pulsed in this transaction
logic chk_seen_rd_first;

// chk_last_was_read: direction of the most recent transaction whose command
//                    byte completed. Lets a cover show that a truncated
//                    command was tried after a READ - the history that, before
//                    spi_slave cleared rw on cs_fall, suppressed its abort.
logic chk_last_was_read;

// chk_had_command: at least one transaction since reset has completed its
//                  command byte, so chk_last_was_read names a real command
//                  rather than its reset value
logic chk_had_command;

// chk_silence: clocks since the last SCK edge while CS is low; zero while CS
//              is high. Counts INTERVALS: the edge that sees an SCK change
//              leaves it at zero.
logic [SILENCE_W-1:0] chk_silence;

assign chk_sck_rise  = sck && !sck_q;
assign chk_cs_fall   = !cs_n && cs_n_q;
assign chk_cs_rise   = cs_n && !cs_n_q;
assign chk_byte_done = chk_sck_rise && (chk_bit_count == 3'd7);

always_ff @(posedge clk or negedge rst_n) begin

  /*
  Purpose:
  ---
  Delayed copies of sck and cs_n for edge detection. Reset values match an
  idle Mode 0 bus: SCK low, CS high.
  */

  if (!rst_n) begin

    sck_q  <= 1'b0;
    cs_n_q <= 1'b1;

  end
  else begin

    sck_q  <= sck;
    cs_n_q <= cs_n;

  end

end

always_ff @(posedge clk or negedge rst_n) begin

  /*
  Purpose:
  ---
  Remember the direction of the last transaction that completed its command
  byte, updated as CS rises. A transaction cut short before its command
  completes leaves it unchanged, so it always names the last real command.

  chk_had_command marks that such a command exists at all. Without it the
  reset value of chk_last_was_read (0) would read as "the last command was a
  write", and a truncated first transaction after reset would satisfy the
  after-write history cover with no write ever sent.
  */

  if (!rst_n) begin

    chk_last_was_read <= 1'b0;
    chk_had_command   <= 1'b0;

  end

  else if (chk_cs_rise && chk_cmd_valid) begin

    chk_last_was_read <= chk_is_read;
    chk_had_command   <= 1'b1;

  end

end

always_ff @(posedge clk or negedge rst_n) begin

  /*
  Purpose:
  ---
  Rebuild the transaction's framing from the pins: bit and byte position,
  the command byte, the read/write direction, how many bytes followed the
  command in a write, how many strobes the DUT issued, and whether rd_first
  has fired.

  CS falling clears everything, matching the header's rule that nothing
  carries between transactions. chk_shift_byte is not cleared - it only ever
  holds the most recent eight bits, like the DUT's receive register.
  */

  if (!rst_n) begin

    chk_bit_count     <= 3'd0;
    chk_byte_count    <= 8'd0;
    chk_shift_byte    <= 8'd0;
    chk_cmd_valid     <= 1'b0;
    chk_is_read       <= 1'b0;
    chk_write_bytes   <= 8'd0;
    chk_strobes       <= 8'd0;
    chk_seen_rd_first <= 1'b0;

  end

  else if (chk_cs_fall) begin

    chk_bit_count     <= 3'd0;
    chk_byte_count    <= 8'd0;
    chk_cmd_valid     <= 1'b0;
    chk_is_read       <= 1'b0;
    chk_write_bytes   <= 8'd0;
    chk_strobes       <= 8'd0;
    chk_seen_rd_first <= 1'b0;

  end
  else begin

    if (chk_sck_rise) begin

      chk_bit_count  <= chk_bit_count + 3'd1;
      chk_shift_byte <= {chk_shift_byte[6:0], sdio_in};
      // The first bit of the transaction is the read/write flag.
      if ((chk_byte_count == 8'd0) && (chk_bit_count == 3'd0)) chk_is_read <= sdio_in;

    end

    if (chk_byte_done) begin

      if (chk_byte_count != '1) chk_byte_count <= chk_byte_count + 8'd1;
      // a command counts only if spi_slave ACCEPTED it, in S_CMD; a command
      // byte that completes after a timeout (S_DEAD) was never accepted and
      // is judged a truncated command (txn_abort)
      if ((chk_byte_count == 8'd0) && (dut_spi_state == S_CMD)) chk_cmd_valid <= 1'b1;
      if (chk_cmd_valid && !chk_is_read && (chk_write_bytes != '1)) begin

        chk_write_bytes <= chk_write_bytes + 8'd1;

      end

    end

    if (wr_en && (chk_strobes != '1)) chk_strobes <= chk_strobes + 8'd1;
    if (rd_first) chk_seen_rd_first <= 1'b1;

  end

end


always_ff @(posedge clk or negedge rst_n) begin

  /*
  Purpose:
  ---
  Measure SCK silence within a transaction. Held at zero while CS is high, so
  idle bus time is never mistaken for a dead master. Either SCK edge restarts
  it. Saturates rather than wrapping, so a long-dead master cannot roll it
  back below the boundary.
  */

  if (!rst_n) begin

    chk_silence <= '0;

  end

  else if (cs_n || (sck != sck_q)) begin

    chk_silence <= '0;

  end

  else if (chk_silence != '1) begin

    chk_silence <= chk_silence + 1'b1;

  end

end


/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         Every output is at rest while rst_n is low: S_IDLE, MISO disabled
         and low, no strobes, no end-of-transaction pulse, addr zero. No
         disable iff - reset is the condition under test.
*/


property p_outputs_idle_in_reset;

  @(posedge clk)
    (!rst_n) |-> ((dut_spi_state == S_IDLE) && !sdio_oe && !sdio_out && !wr_en &&
                  !rd_first && !rd_byte_done && !integrity_ok && !txn_abort &&
                  (addr == 7'h00));

endproperty

a_outputs_idle_in_reset: assert property (p_outputs_idle_in_reset)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_outputs_idle_in_reset: state=%0d oe=%0b out=%0b wr_en=%0b ok=%0b abort=%0b addr=%0h",
      dut_spi_state, sdio_oe, sdio_out, wr_en, integrity_ok, txn_abort, addr));

  end

c_in_reset: cover property (@(posedge clk) (!rst_n));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         In Mode 0 the host moves CS only
         while SCK is idle low. The header's argument that wr_en can never
         coincide with an end pulse rests on this, because a CS rise on the
         same clock as an SCK rise would let both fire together.

         A failure here means the testbench driver (or a host) broke the
         protocol, not that spi_slave is wrong.
*/

property p_cs_moves_with_sck_low;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && $changed(cs_n)) |-> (!sck && !$past(sck));

endproperty

a_cs_moves_with_sck_low: assert property (p_cs_moves_with_sck_low)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_cs_moves_with_sck_low: INPUT CONTRACT - cs_n changed to %0b with sck=%0b (was %0b)",
      cs_n, sck, $past(sck)));

  end

c_cs_fall: cover property (@(posedge clk) disable iff (!rst_n) chk_cs_fall);
c_cs_rise: cover property (@(posedge clk) disable iff (!rst_n) chk_cs_rise);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         State legality and the entry condition of every state except S_DEAD
         (group 4).
           - spi_state holds one of the six encodings.
           - S_CMD is entered only from a CS fall, and every CS fall enters it.
           - S_IDLE is entered only from a CS rise, and every CS rise enters it.
           - S_WRITE and S_TURN are entered from S_CMD on the edge that
             completes byte 1, chosen by the command's bit 7.
           - S_READ is entered from S_TURN on the edge that completes byte 2,
             so the turnaround is exactly one byte.
         Each entry pins its precondition, so a transition the FSM should
         not make fails here whichever state it lands in.
*/

property p_state_legal;

  @(posedge clk) disable iff (!rst_n)
    (dut_spi_state <= S_DEAD);       // encodings are contiguous 0..5

endproperty

a_state_legal: assert property (p_state_legal)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_state_legal: spi_state=%0d is not a legal encoding", dut_spi_state));

  end

property p_cmd_entered_only_on_cs_fall;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && $rose(dut_spi_state == S_CMD)) |-> $past(chk_cs_fall);

endproperty

a_cmd_entered_only_on_cs_fall: assert property (p_cmd_entered_only_on_cs_fall)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_cmd_entered_only_on_cs_fall: entered S_CMD from state %0d without a CS fall",
      $past(dut_spi_state)));

  end

property p_cs_fall_enters_cmd;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && chk_cs_fall) |=> (dut_spi_state == S_CMD);

endproperty

a_cs_fall_enters_cmd: assert property (p_cs_fall_enters_cmd)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_cs_fall_enters_cmd: state=%0d on the clock after a CS fall", dut_spi_state));

  end


property p_idle_entered_only_on_cs_rise;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && $rose(dut_spi_state == S_IDLE)) |-> $past(chk_cs_rise);

endproperty

a_idle_entered_only_on_cs_rise: assert property (p_idle_entered_only_on_cs_rise)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_idle_entered_only_on_cs_rise: entered S_IDLE from state %0d without a CS rise",
      $past(dut_spi_state)));

  end

property p_cs_rise_enters_idle;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && chk_cs_rise) |=> (dut_spi_state == S_IDLE);

endproperty

a_cs_rise_enters_idle: assert property (p_cs_rise_enters_idle)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_cs_rise_enters_idle: state=%0d on the clock after a CS rise", dut_spi_state));

  end

property p_write_entry;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && $rose(dut_spi_state == S_WRITE))
        |-> (($past(dut_spi_state) == S_CMD) && !chk_is_read && (chk_byte_count == 8'd1));

endproperty

a_write_entry: assert property (p_write_entry)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_write_entry: S_WRITE entered from state %0d, is_read=%0b, bytes=%0d",
      $past(dut_spi_state), chk_is_read, chk_byte_count));

  end

property p_turn_entry;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && $rose(dut_spi_state == S_TURN))
        |-> (($past(dut_spi_state) == S_CMD) && chk_is_read && (chk_byte_count == 8'd1));

endproperty

a_turn_entry: assert property (p_turn_entry)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_turn_entry: S_TURN entered from state %0d, is_read=%0b, bytes=%0d",
      $past(dut_spi_state), chk_is_read, chk_byte_count));

  end

property p_read_entry;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && $rose(dut_spi_state == S_READ))
        |-> (($past(dut_spi_state) == S_TURN) && (chk_byte_count == 8'd2));

endproperty

a_read_entry: assert property (p_read_entry)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_read_entry: S_READ entered from state %0d after %0d bytes (turnaround must be one byte)",
      $past(dut_spi_state), chk_byte_count));
      
  end

c_enter_write: cover property (@(posedge clk) disable iff (!rst_n) $rose(dut_spi_state == S_WRITE));
c_enter_turn:  cover property (@(posedge clk) disable iff (!rst_n) $rose(dut_spi_state == S_TURN));
c_enter_read:  cover property (@(posedge clk) disable iff (!rst_n) $rose(dut_spi_state == S_READ));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         The SCK idle timeout, as a lower and an upper bound. Either alone
         passes a DUT whose timeout never moves.
           - Lower: S_DEAD is entered only on the edge where silence reaches
             the boundary - never early, and never from anything else.
           - Upper: once silence has reached the boundary inside a
             transaction, the state is S_DEAD.
         The upper bound excludes S_IDLE because the DUT gates its timeout
         on "not idle". With a correct host, CS is never low in S_IDLE beyond
         the single cs_fall edge.
*/

property p_dead_entered_at_boundary;

  @(posedge clk) disable iff (!rst_n)
    $rose(dut_spi_state == S_DEAD) |-> (chk_silence == DEAD_AT_SILENCE);

endproperty

a_dead_entered_at_boundary: assert property (p_dead_entered_at_boundary)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_dead_entered_at_boundary: S_DEAD entered from state %0d at silence=%0d, expected %0d",
      $past(dut_spi_state), chk_silence, DEAD_AT_SILENCE));

  end

property p_silence_forces_dead;

  @(posedge clk) disable iff (!rst_n)
    (!cs_n && (dut_spi_state != S_IDLE) && (chk_silence >= DEAD_AT_SILENCE))
        |-> (dut_spi_state == S_DEAD);

endproperty

a_silence_forces_dead: assert property (p_silence_forces_dead)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_silence_forces_dead: silence=%0d past the boundary but state=%0d",
      chk_silence, dut_spi_state));

  end

c_timeout_in_cmd:   cover property (@(posedge clk) disable iff (!rst_n)
                        $rose(dut_spi_state == S_DEAD) && ($past(dut_spi_state) == S_CMD));
c_timeout_in_write: cover property (@(posedge clk) disable iff (!rst_n)
                        $rose(dut_spi_state == S_DEAD) && ($past(dut_spi_state) == S_WRITE));
c_timeout_in_read:  cover property (@(posedge clk) disable iff (!rst_n)
                        $rose(dut_spi_state == S_DEAD) && ($past(dut_spi_state) == S_READ));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         MISO direction and bit timing.
           - sdio_oe is high exactly in S_READ, on the same edges.
           - sdio_out changes only on the clock after a falling SCK edge, so
             each bit is stable across the rising edge where the host samples.
         Considered and subsumed: "MISO is low outside a transaction" follows
         from the first property plus group 3's CS rise -> S_IDLE. Whether
         the bits are the right DATA is an M claim for the cocotb scoreboard.
*/

property p_miso_enable_tracks_read;

  @(posedge clk) disable iff (!rst_n)
    (sdio_oe == (dut_spi_state == S_READ));

endproperty

a_miso_enable_tracks_read: assert property (p_miso_enable_tracks_read)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_miso_enable_tracks_read: sdio_oe=%0b in state %0d", sdio_oe, dut_spi_state));

  end

property p_miso_changes_on_sck_fall;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && !$fell(sck)) |=> $stable(sdio_out);

endproperty

a_miso_changes_on_sck_fall: assert property (p_miso_changes_on_sck_fall)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_miso_changes_on_sck_fall: sdio_out went %0b -> %0b with no falling SCK edge",
      $past(sdio_out), sdio_out));

  end

c_miso_driven:       cover property (@(posedge clk) disable iff (!rst_n) sdio_oe);
c_miso_bit_launched: cover property (@(posedge clk) disable iff (!rst_n) $fell(sck) && sdio_oe);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 6:
         How addr moves - every way, so a stray change cannot slip through:
           - load from the command byte's low seven bits when it completes;
           - +1 on the clock after each wr_en;
           - +1 on the clock after each rd_byte_done;
           - otherwise unchanged, including across CS edges.
         Increments wrap 0x7F -> 0x00 because both operands are seven bits.
         Considered and subsumed: "wr_en arrives with the address its byte
         belongs to" follows from the load, the post-strobe increment and
         the hold together.
*/

property p_addr_loads_from_command;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && chk_byte_done && (dut_spi_state == S_CMD))
        |=> (addr == chk_shift_byte[6:0]);
        
endproperty

a_addr_loads_from_command: assert property (p_addr_loads_from_command)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_addr_loads_from_command: addr=%0h, command byte was %0h",
      addr, chk_shift_byte));

  end

property p_addr_steps_after_strobe;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && wr_en) |=> (addr == ($past(addr) + 7'd1));

endproperty

a_addr_steps_after_strobe: assert property (p_addr_steps_after_strobe)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_addr_steps_after_strobe: addr went %0h -> %0h after wr_en",
      $past(addr), addr));

  end

property p_addr_steps_after_read_byte;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && rd_byte_done) |=> (addr == ($past(addr) + 7'd1));

endproperty

a_addr_steps_after_read_byte: assert property (p_addr_steps_after_read_byte)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_addr_steps_after_read_byte: addr went %0h -> %0h after rd_byte_done",
      $past(addr), addr));

  end

property p_addr_holds_otherwise;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && !wr_en && !rd_byte_done && !(chk_byte_done && (dut_spi_state == S_CMD)))
        |=> $stable(addr);

endproperty

a_addr_holds_otherwise: assert property (p_addr_holds_otherwise)
  else begin
    
    sva_pkg::note_failure($sformatf(
      "a_addr_holds_otherwise: addr went %0h -> %0h with no load, strobe or read byte",
      $past(addr), addr));

  end

c_addr_load: cover property (@(posedge clk) disable iff (!rst_n)
                 chk_byte_done && (dut_spi_state == S_CMD));
c_addr_wrap: cover property (@(posedge clk) disable iff (!rst_n)
                 (wr_en || rd_byte_done) && (addr == 7'h7F));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 7:
         Write strobes.
           - wr_en is a one-clock pulse.
           - It is issued only from S_WRITE, so never for the command byte.
           - It never shares a clock with integrity_ok or txn_abort; reg_file
             gives integrity_OK priority and would drop a coinciding write.
           - At CS rise, the strobe count equals the bytes after the command
             minus one. The last byte is the CRC and must never be released.
             This is the claim the delay line exists for.
*/

property p_strobe_one_clock;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && wr_en) |=> !wr_en;

endproperty

a_strobe_one_clock: assert property (p_strobe_one_clock)
  else begin

    sva_pkg::note_failure("a_strobe_one_clock: wr_en held for two clocks");

  end

property p_strobe_only_from_write;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && wr_en) |-> ($past(dut_spi_state) == S_WRITE);

endproperty

a_strobe_only_from_write: assert property (p_strobe_only_from_write)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_strobe_only_from_write: wr_en issued from state %0d", $past(dut_spi_state)));

  end

property p_strobe_not_with_end_pulse;

  @(posedge clk) disable iff (!rst_n)
    !(wr_en && (integrity_ok || txn_abort));

endproperty

a_strobe_not_with_end_pulse: assert property (p_strobe_not_with_end_pulse)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_strobe_not_with_end_pulse: wr_en on the same clock as ok=%0b abort=%0b",
      integrity_ok, txn_abort));

  end

property p_strobe_count_excludes_crc;

  @(posedge clk) disable iff (!rst_n)
    (chk_cs_rise && (dut_spi_state == S_WRITE) && (chk_write_bytes != '1))
        |-> (chk_strobes == ((chk_write_bytes == 8'd0) ? 8'd0 : (chk_write_bytes - 8'd1)));

endproperty

a_strobe_count_excludes_crc: assert property (p_strobe_count_excludes_crc)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_strobe_count_excludes_crc: %0d strobes for %0d bytes after the command",
      chk_strobes, chk_write_bytes));

  end

c_strobe:        cover property (@(posedge clk) disable iff (!rst_n) wr_en);
c_second_strobe: cover property (@(posedge clk) disable iff (!rst_n) wr_en && (chk_strobes != 8'd0));
c_write_closed:  cover property (@(posedge clk) disable iff (!rst_n)
                     chk_cs_rise && (dut_spi_state == S_WRITE));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 8:
         Read handshakes.
           - rd_first pulses only on the last falling edge of the turnaround
             byte, where the first read byte is loaded.
           - It pulses at most once per transaction, and every read data
             phase is preceded by it.
           - rd_byte_done pulses exactly on the eighth rising edge of each
             read data byte - lower and upper bound in one equality.
         Whether the snapshot rd_first triggers makes a burst coherent is an
         M claim, checked by the scoreboard on timestamp reads.
*/

property p_rd_first_on_last_turn_fall;

  @(posedge clk) disable iff (!rst_n)
    rd_first |-> ((dut_spi_state == S_TURN) && $fell(sck) && (chk_bit_count == 3'd7));

endproperty

a_rd_first_on_last_turn_fall: assert property (p_rd_first_on_last_turn_fall)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_rd_first_on_last_turn_fall: rd_first in state %0d at bit %0d",
      dut_spi_state, chk_bit_count));

  end

property p_rd_first_once;

  @(posedge clk) disable iff (!rst_n)
    rd_first |-> !chk_seen_rd_first;

endproperty

a_rd_first_once: assert property (p_rd_first_once)
  else begin

    sva_pkg::note_failure("a_rd_first_once: second rd_first in one transaction");

  end

property p_read_phase_after_rd_first;

  @(posedge clk) disable iff (!rst_n)
    (dut_spi_state == S_READ) |-> chk_seen_rd_first;

endproperty

a_read_phase_after_rd_first: assert property (p_read_phase_after_rd_first)
  else begin

    sva_pkg::note_failure("a_read_phase_after_rd_first: in S_READ with no rd_first this transaction");

  end

property p_rd_byte_done_exact;

  @(posedge clk) disable iff (!rst_n)
    (rd_byte_done == (chk_byte_done && (dut_spi_state == S_READ)));

endproperty

a_rd_byte_done_exact: assert property (p_rd_byte_done_exact)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_rd_byte_done_exact: rd_byte_done=%0b, byte_done=%0b, state=%0d",
      rd_byte_done, chk_byte_done, dut_spi_state));

  end

c_rd_first:      cover property (@(posedge clk) disable iff (!rst_n) rd_first);
c_rd_byte_done:  cover property (@(posedge clk) disable iff (!rst_n) rd_byte_done);
c_burst_read:    cover property (@(posedge clk) disable iff (!rst_n)
                     rd_byte_done && (chk_byte_count >= 8'd3));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 9:
         End of transaction.
           - integrity_ok and txn_abort never fire together.
           - Neither fires except on the clock after a CS rise.
           - A write whose command completed always resolves into one of the
             two.
           - A read never produces either.
           - A transaction whose command spi_slave never accepted always
             produces txn_abort, so the bus-error count sees every truncated
             command: CS rising before the command byte completed, or an SCK
             stall that sent the slave to S_DEAD first - even if the host then
             clocked the rest of the byte (see chk_cmd_valid). spi_slave
             clears rw on cs_fall to guarantee this.
             Before that change the outcome depended on the PREVIOUS
             transaction: aborted after a write, silently dropped after a
             read. c_closed_before_command_after_read is that history case,
             the regression scenario for the fix.
           - integrity_ok is impossible when the transaction was not framed:
             CS rose mid-byte, fewer than three bytes arrived, or the slave
             had timed out. Whether the CRC itself was right is an M claim
             for the scoreboard's independent CRC model.
         Considered and subsumed: "each is a one-clock pulse" follows from
         the second property, since CS cannot rise on consecutive clocks.
*/

property p_end_pulses_exclusive;

  @(posedge clk) disable iff (!rst_n)
    !(integrity_ok && txn_abort);

endproperty

a_end_pulses_exclusive: assert property (p_end_pulses_exclusive)
  else begin

    sva_pkg::note_failure("a_end_pulses_exclusive: integrity_ok and txn_abort together");

  end

property p_end_pulses_follow_cs_rise;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && !chk_cs_rise) |=> !(integrity_ok || txn_abort);

endproperty

a_end_pulses_follow_cs_rise: assert property (p_end_pulses_follow_cs_rise)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_end_pulses_follow_cs_rise: ok=%0b abort=%0b with no CS rise",
      integrity_ok, txn_abort));

  end

property p_write_always_resolved;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && chk_cs_rise && chk_cmd_valid && !chk_is_read)
        |=> (integrity_ok || txn_abort);

endproperty

a_write_always_resolved: assert property (p_write_always_resolved)
  else begin

    sva_pkg::note_failure("a_write_always_resolved: write ended with neither integrity_ok nor txn_abort");

  end

property p_read_never_resolved;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && chk_cs_rise && chk_cmd_valid && chk_is_read)
        |=> !(integrity_ok || txn_abort);

endproperty

a_read_never_resolved: assert property (p_read_never_resolved)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_read_never_resolved: read ended with ok=%0b abort=%0b", integrity_ok, txn_abort));

  end

property p_truncated_command_aborts;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && chk_cs_rise && !chk_cmd_valid) |=> txn_abort;

endproperty

a_truncated_command_aborts: assert property (p_truncated_command_aborts)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_truncated_command_aborts: CS rose after %0d command bits with no txn_abort (last command was a %0s)",
      $past(chk_bit_count), $past(chk_last_was_read) ? "read" : "write"));

  end

property p_no_commit_unframed;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && chk_cs_rise &&
     ((chk_bit_count != 3'd0) || (chk_byte_count < 8'd3) || (dut_spi_state == S_DEAD)))
        |=> !integrity_ok;

endproperty

a_no_commit_unframed: assert property (p_no_commit_unframed)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_no_commit_unframed: committed with bit=%0d bytes=%0d state=%0d at CS rise",
      $past(chk_bit_count), $past(chk_byte_count), $past(dut_spi_state)));

  end

c_committed:             cover property (@(posedge clk) disable iff (!rst_n) integrity_ok);
c_abort_framed:          cover property (@(posedge clk) disable iff (!rst_n)
                             txn_abort && $past((chk_bit_count == 3'd0) && (chk_byte_count >= 8'd3) &&
                                                (dut_spi_state == S_WRITE)));
c_abort_mid_byte:        cover property (@(posedge clk) disable iff (!rst_n)
                             txn_abort && $past(chk_bit_count != 3'd0));
c_abort_short:           cover property (@(posedge clk) disable iff (!rst_n)
                             txn_abort && $past((chk_bit_count == 3'd0) && (chk_byte_count < 8'd3)));
c_abort_after_timeout:   cover property (@(posedge clk) disable iff (!rst_n)
                             txn_abort && $past(dut_spi_state == S_DEAD));
c_read_closed_mid_byte:  cover property (@(posedge clk) disable iff (!rst_n)
                             chk_cs_rise && chk_cmd_valid && chk_is_read && (chk_bit_count != 3'd0));
c_closed_before_command_after_read:  cover property (@(posedge clk) disable iff (!rst_n)
                             chk_cs_rise && !chk_cmd_valid && chk_had_command && chk_last_was_read);
c_closed_before_command_after_write: cover property (@(posedge clk) disable iff (!rst_n)
                             chk_cs_rise && !chk_cmd_valid && chk_had_command && !chk_last_was_read);
c_read_dead_before_command:          cover property (@(posedge clk) disable iff (!rst_n)
                             chk_cs_rise && !chk_cmd_valid && chk_is_read && (chk_byte_count != 8'd0));


/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire
