/*

# Filename:         spi_slave.v

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

#                   Verilog-2005, converted from rtl/telemetry/spi_slave.sv by sv2v,
#                   with the comments restored by hand from the source.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module spi_slave (
	clk,
	rst_n,
	sck,
	cs_n,
	sdio_in,
	sdio_out,
	sdio_oe,
	addr,
	wr_en,
	wdata,
	rdata,
	rd_first,
	rd_byte_done,
	integrity_ok,
	abort
);
	// _sv2v_0: added by the conversion. An always_comb block runs once at
	// time zero; always @(*) does not, so each converted block reads this
	// constant-zero register to be evaluated at start-up in simulation.
	// Never assigned after time zero; synthesis removes it.
	reg _sv2v_0;
	// Package constants used here, inlined by the conversion from
	// pmic_types_pkg.sv. Each is evaluated at elaboration; none is hardware.
	// CLK_HZ: supervisor clock, from the external oscillator
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 10000000;
	// ms_to_clks: milliseconds -> clk counts
	function automatic signed [31:0] pmic_types_pkg_ms_to_clks;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_clks = 10000 * ms;
	endfunction
	// SCK_IDLE_TIMEOUT_CLKS: SCK silent this long with CS still low means the master
	//                        died mid-transaction. Without this the slave can sit
	//                        waiting forever, and on a read it would hold SDIO driven.
	parameter signed [31:0] SCK_IDLE_TIMEOUT_CLKS = pmic_types_pkg_ms_to_clks(2);
	input wire clk;
	input wire rst_n;
	// ---------------- bus side ----------------
	// Already synchronised AND filtered in pmic_top. This module never sees a raw
	// pin, and all three lines must use IDENTICAL filter settings - unequal delay
	// between sck and sdio_in shifts the data relative to the clock.
	input wire sck;
	input wire cs_n;
	input wire sdio_in;
	output reg sdio_out;
	// sdio_oe: drive enable. High only while shifting out read data. The tri-state
	//          itself lives in pmic_top so simulation and hardware agree.
	output reg sdio_oe;
	// ---------------- reg_file side ----------------
	output reg [6:0] addr;
	// wr_en: one pulse per DATA byte. Never pulses for the command byte or the CRC
	//        byte - see BLOCK 5.
	output reg wr_en;
	output reg [7:0] wdata;
	input wire [7:0] rdata;
	output reg rd_first;
	// rd_byte_done: one-clock pulse when a READ data byte has been fully clocked out,
	//               on its eighth rising SCK edge, while addr still names that byte
	output reg rd_byte_done;
	// integrity_ok: CS rose on a byte boundary, length was legal, CRC checked out
	output reg integrity_ok;
	// abort: write transaction ended any other way
	output reg abort;
	// sck_d / cs_n_d: delayed copies, one clk, for edge detection. sck is treated
	//                 as ordinary data here.
	reg sck_d;
	reg cs_n_d;
	// One-clock enable pulses derived from them.
	reg sck_rise;  // master samples SDIO here, so the slave shifts IN here
	reg sck_fall;  // slave changes SDIO here, so it is stable across the rise
	reg cs_fall;  // start of a transaction
	reg cs_rise;  // end of a transaction - the only commit/discard decision point
	// bit_count: bits received within the present byte, 0..7. Nonzero at cs_rise
	//            means the master stopped mid-byte, which invalidates a write.
	reg [2:0] bit_count;
	// byte_count: bytes completed since cs_fall. Saturates rather than wrapping, so
	//             a long transaction cannot roll it back under the length check.
	//             Only the first few values are ever tested.
	reg [3:0] byte_count;
	// byte_done: one-clock pulse on the SCK rise that completes a byte
	reg byte_done;
	// rx_byte: the byte completing on this rising edge. rx_shift holds the pre-edge
	//          value, so the arriving bit must be appended here rather than read
	//          from the register.
	reg [7:0] rx_byte;
	// Transaction state, the enum spi_states_t in the source. The conversion
	// replaces the names with their values; each use below carries the name.
	// Three bits, because two would hold four states and there are six:
	//   3'b000 S_IDLE   CS high, nothing happening
	//   3'b001 S_CMD    receiving the command byte
	//   3'b010 S_WRITE  receiving data bytes, then the CRC byte
	//   3'b011 S_TURN   read turnaround byte; nobody drives SDIO
	//   3'b100 S_READ   shifting read data out
	//   3'b101 S_DEAD   poisoned (timeout or illegal state); wait for CS to rise,
	//                   commit nothing
	reg [2:0] spi_state;
	reg [2:0] spi_state_next;
	// rw: bit 7 of the command byte, 1 = read
	reg rw;
	// sck_timeout: one-clock pulse.
	reg sck_timeout;
	// rx_shift: receive staging register. Seven bits, not eight - rx_byte appends
	//           the arriving bit to complete a byte, so an eighth bit here would
	//           shift out unused.
	reg [6:0] rx_shift;
	// crc: running CRC-8 over every received bit. Polynomial 0x07, init 0x00, no
	//      final XOR. The host must use the same parameters - a datasheet
	//      requirement, since CRC-8 has no universal default.
	reg [7:0] crc;
	// held_data: one-byte delay line. A completed byte waits here until the NEXT
	//            byte completes, which is the only moment it is known not to have
	//            been the CRC.
	reg [7:0] held_data;
	// held_valid: the delay line holds a byte not yet released
	reg held_valid;
	// tx_shift: transmit shift register, MSB first. Bit 7 is written on load but
	//           never read - sdio_out takes rdata[7] on the load and tx_shift[6] on
	//           each shift, so the top bit is always one position ahead of what is
	//           needed. Kept 8 bits so a load is a plain byte assignment.
	reg [7:0] tx_shift;
	/*
	Purpose:
	---
	Delayed copies of sck and cs_n so the four edges below can be detected
	combinationally. Everything in this module is an enable on the 50 MHz domain;
	sck is never used as a clock.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			sck_d <= 0;
			cs_n_d <= 1;
		end
		else begin
			sck_d <= sck;
			cs_n_d <= cs_n;
		end
	/*
	Purpose:
	---
	Produce the one-clock enable pulses the rest of the module runs on.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		sck_fall = sck_d & ~sck;
		sck_rise = ~sck_d & sck;
		cs_fall = cs_n_d & ~cs_n;
		cs_rise = ~cs_n_d & cs_n;
	end
	/*
	Purpose:
	---
	State register. Reset to S_IDLE, which is also where every abandoned transaction
	ends up once CS rises.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			spi_state <= 3'b000;  // S_IDLE
		else
			spi_state <= spi_state_next;
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
	always @(*) begin
		if (_sv2v_0)
			;
		spi_state_next = spi_state;
		if (cs_fall)
			spi_state_next = 3'b001;  // S_CMD
		else if (cs_rise)
			spi_state_next = 3'b000;  // S_IDLE
		else if (sck_timeout && (spi_state != 3'b000))  // not S_IDLE
			spi_state_next = 3'b101;  // S_DEAD
		else
			// (* full_case, parallel_case *) is how the conversion renders the source's
			// unique case: the simulator's overlap check is gone, and synthesis is told
			// the items are complete and mutually exclusive. Both hold here - every
			// encoding has its own item and the default covers the unused ones.
			(* full_case, parallel_case *)
			case (spi_state)
				3'b000: spi_state_next = 3'b000;  // S_IDLE: holds
				3'b001:  // S_CMD
					if (byte_done)
						spi_state_next = (rx_byte[7] ? 3'b011 : 3'b010);  // a read: S_TURN; a write: S_WRITE
				3'b010: spi_state_next = 3'b010;  // S_WRITE: holds
				3'b011:  // S_TURN
					if (byte_done)
						spi_state_next = 3'b100;  // S_READ
				3'b100: spi_state_next = 3'b100;  // S_READ: holds
				3'b101: spi_state_next = 3'b101;  // S_DEAD: holds
				default: spi_state_next = 3'b101;  // S_DEAD
			endcase
	end
	/*
	Purpose:
	---
	Flag the rising edge that completes a byte. bit_count holds the PRE-edge value,
	so the eighth bit of a byte arrives while bit_count reads 7.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		byte_done = sck_rise & (bit_count == 3'd7);
	end
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
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			bit_count <= 0;
			byte_count <= 0;
		end
		else if (cs_fall) begin
			bit_count <= 0;
			byte_count <= 0;
		end
		else if (sck_rise) begin
			bit_count <= bit_count + 1;
			if (byte_done && !(&byte_count))
				byte_count <= byte_count + 1;
		end
	/*
	Purpose:
	---
	The byte completing on this rising edge. rx_shift holds the pre-edge
	bits, so the arriving bit is appended here rather than read from the
	register.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		rx_byte = {rx_shift, sdio_in};
	end
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
	Driving one variable from two always blocks is illegal, and they are mutually
	exclusive by state anyway.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			rx_shift <= 7'h00;
			rw <= 1'b0;
			addr <= 7'h00;
			held_data <= 8'h00;
			held_valid <= 1'b0;
			wr_en <= 1'b0;
			wdata <= 8'h00;
		end
		else begin
			wr_en <= 1'b0;
			if (wr_en)
				addr <= addr + 7'd1;
			if (sck_rise)
				rx_shift <= {rx_shift[5:0], sdio_in};
			if (cs_fall)
				held_valid <= 1'b0;
			else if (byte_done) begin
				if (spi_state == 3'b001) begin  // S_CMD
					rw <= rx_byte[7];
					addr <= rx_byte[6:0];
				end
				else if (spi_state == 3'b010) begin  // S_WRITE
					if (held_valid) begin
						wdata <= held_data;
						wr_en <= 1'b1;
					end
					held_data <= rx_byte;
					held_valid <= 1'b1;
				end
				else if (spi_state == 3'b100)  // S_READ
					addr <= addr + 7'd1;
			end
		end
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
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			crc <= 8'h00;
		else if (cs_fall)
			crc <= 8'h00;
		else if (sck_rise) begin
			if (crc[7] ^ sdio_in)
				crc <= (crc << 1) ^ 8'h07;
			else
				crc <= crc << 1;
		end
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
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			tx_shift <= 8'h00;
			sdio_out <= 1'b0;
			sdio_oe <= 1'b0;
		end
		else begin
			sdio_oe <= spi_state_next == 3'b100;  // S_READ
			if (sck_fall) begin
				if ((spi_state == 3'b011) && (bit_count == 3'd7)) begin  // S_TURN
					tx_shift <= rdata;
					sdio_out <= rdata[7];
				end
				else if (spi_state == 3'b100) begin  // S_READ
					if (bit_count == 3'd0) begin
						tx_shift <= rdata;
						sdio_out <= rdata[7];
					end
					else begin
						tx_shift <= {tx_shift[6:0], 1'b0};
						sdio_out <= tx_shift[6];
					end
				end
			end
		end
	/*
	Purpose:
	---
	Flag the load of the first read byte, COMBINATIONALLY rather than as a
	registered pulse.

	reg_file uses this to snapshot the free-running millisecond counter. A
	registered pulse arrives one clk after the load, so the first byte would be
	served from the PREVIOUS transaction's snapshot while the rest came from this
	one - stale by however long it had been since the last read. Asserting on the
	same edge as the load lets reg_file present the live value for that byte and
	the frozen copy for the rest, which are then the same value.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		rd_first = (sck_fall && (spi_state == 3'b011)) && (bit_count == 3'd7);  // S_TURN
	end
	/*
	Purpose:
	---
	Flag the completion of each READ data byte: its eighth rising SCK edge, which
	is where the master samples the last bit. addr still names the byte that has
	just gone out on this clock and advances on the edge that ends it, so a
	consumer can tell exactly which address the host has finished reading.

	This is the only event that means "the host has read this byte". An address
	change alone does not: addr also moves when a command byte loads it and when a
	write releases a data byte, and reg_file must not mistake either for a read.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		rd_byte_done = byte_done && (spi_state == 3'b100);  // S_READ
	end
	// idle_counter: clocks since the last SCK edge, while CS is low. Sized for the
	//               full timeout so it cannot wrap and re-arm.
	reg [$clog2(SCK_IDLE_TIMEOUT_CLKS + 1) - 1:0] idle_counter;
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
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			idle_counter <= 0;
			sck_timeout <= 0;
		end
		else begin
			sck_timeout <= 0;
			if (cs_n)
				idle_counter <= 0;
			else if (sck_rise || sck_fall)
				idle_counter <= 0;
			else if (idle_counter == SCK_IDLE_TIMEOUT_CLKS[$clog2(SCK_IDLE_TIMEOUT_CLKS + 1) - 1:0]) begin
				sck_timeout <= 1'b1;
				idle_counter <= 1'sb0;
			end
			else
				idle_counter <= idle_counter + 1;
		end
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
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			integrity_ok <= 0;
			abort <= 0;
		end
		else begin
			integrity_ok <= 1'b0;
			abort <= 1'b0;
			if (cs_rise && !rw) begin
				if ((((spi_state != 3'b101) && (bit_count == 3'd0)) && (byte_count >= 4'd3)) && (crc == 8'h00))  // S_DEAD
					integrity_ok <= 1'b1;
				else
					abort <= 1'b1;
			end
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
