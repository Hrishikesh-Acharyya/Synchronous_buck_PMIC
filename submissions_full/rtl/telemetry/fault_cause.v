/*
# Filename:         fault_cause.v

# File Description: Records WHICH fault conditions occurred during an episode of
#                   converter operation, as a one-hot vector that accumulates
#                   until the host reads it.
#
#                   Every fault input in this design is transient. OTP clears as
#                   the board cools, UVLO clears as Vin recovers, and window_trip
#                   is a combinational comparison on a rolling window that resets
#                   the moment the supervisor leaves S_RUN. So by the time anyone
#                   asks why the converter shut down, the condition that caused it
#                   is usually gone. This module stores history to tell what went
#                   wrong after the fact.
#
#                   Priority is encoded in bit position, MSB highest.
#
#                   OVP is INFERRED, not measured. The shared protection latch has
#                   exactly two trip sources - the analog OVP comparator and the
#                   CPLD's own latch_out, driven by latch_assert - and an
#                   overcurrent reaches it only through the digital window, strikes
#                   and latch_assert. So latch_assert is always already high on a
#                   CPLD-originated trip, and latch_state high with latch_assert low
#                   isolates an analog-origin trip. This holds only because
#                   rst_n_pin is wired to the latch's manual drain button, so the
#                   SCR and latch_assert always clear together.
#
#                   LIMITATIONS:
#                   - No ordering or repetition is preserved. OTP-then-OCP reads
#                     identically to OCP-then-OTP, and a cause that recurred reads
#                     the same as one that happened once.
#                   - A fault asserting while the converter is already stopped is
#                     not captured. The register means "faults that interrupted
#                     operation", not "conditions that were ever true".
#
#                   Telemetry only. Drives no control path and takes no part in any
#                   protection decision; removing this module leaves the converter
#                   functionally identical.

#                   Verilog-2005, converted from rtl-systemverilog/telemetry/fault_cause.sv by sv2v,
#                   with the comments restored by hand from the source.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module fault_cause (
	clk,
	rst_n,
	otp_state,
	uvlo_state,
	latch_state,
	latch_assert,
	window_trip,
	window_trip_SS,
	ss_active,
	run_active,
	fault_reg_read_done,
	timestamp_ms,
	fault_time,
	fault_reg
);
	// _sv2v_0: added by the conversion. An always_comb block runs once at
	// time zero; always @(*) does not, so each converted block reads this
	// constant-zero register to be evaluated at start-up in simulation.
	// Never assigned after time zero; synthesis removes it.
	reg _sv2v_0;
	input wire clk;
	input wire rst_n;
	// ---- live fault conditions, all already synchronised and debounced ----
	input wire otp_state;  // debounced OTP comparator
	input wire uvlo_state;  // debounced input UVLO comparator
	input wire latch_state;  // debounced SCR readback
	input wire latch_assert;  // CPLD's own trip into the latch
	input wire window_trip;  // overcurrent window exceeded in S_RUN
	input wire window_trip_SS;  // overcurrent window exceeded in S_SS
	// ---- episode scoping ----
	input wire ss_active;
	input wire run_active;
	input wire fault_reg_read_done;  // one-clk pulse from reg_file
	// Package constants used here, inlined by the conversion from
	// pmic_types_pkg.sv. Each is evaluated at elaboration; none is hardware.
	//TIMESTAMP_W: Width of timestamp generstor register. Arbitrary. Gives ~4.6 hours of timestamping
	//              before resetting.
	localparam signed [31:0] pmic_types_pkg_TIMESTAMP_W = 24;
	input wire [23:0] timestamp_ms;  // free-running ms counter
	//fault_time: timestamp_ms latched at the instant this episode began - the
	//            empty-to-non-empty transition of fault_reg. Held while further
	//            causes accumulate, cleared with the bits on a host read.
	output reg [23:0] fault_time;
	//FAULT_CAUSE_W: Width of the fault_cause reg in fault_cause.sv
	//                Also the number of faults
	localparam signed [31:0] pmic_types_pkg_FAULT_CAUSE_W = 5;
	//fault_reg:  Keeps state of the faults that have occured,
	//            1- hot encoded and OR-accumulated.
	//            [10000] - OVP
	//            [01000] - LATCH_ASSERT (OCP/SCP)
	//            [00100] - OTP
	//            [00010] - UVLO
	//            [00001] - OVERCURRENT -> WINDOW_TRIP/WINDOW_SS FIRED
	output reg [4:0] fault_reg;
	// Bit positions in fault_reg. MSB-first is priority order.
	localparam signed [31:0] BIT_OVP = 4;
	localparam signed [31:0] BIT_LATCH = 3;
	localparam signed [31:0] BIT_OTP = 2;
	localparam signed [31:0] BIT_UVLO = 1;
	localparam signed [31:0] BIT_OC = 0;
	//convertor_running: Is the convertor is run or ss state?
	reg convertor_running;
	//ovp: latch was triggered due to ovp?
	reg ovp;
	//episode_start: high on the clk a cause is about to be captured into an empty
	//               fault_reg - the first fault of a new episode
	reg episode_start;
	/*
	Purpose:
	---
	Capture gate. Faults are recorded only while the converter is actually running,
	so a normal power-down - which drops Vin and asserts UVLO while the housekeeping
	rail still holds the CPLD up - does not log a fault for every routine shutdown.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		convertor_running = ss_active || run_active;
	end
	/*
	Purpose:
	---
	Infer an analog overvoltage trip. The protection latch is shared between the
	analog OVP comparator and the CPLD, and only the CPLD's own trips are preceded by
	latch_assert, so the latch reading back set with latch_assert clear means the
	analog side tripped it. See the file header for why no other condition produces
	this combination.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		if (latch_state & ~latch_assert)
			ovp = 1'b1;
		else
			ovp = 1'b0;
	end
	/*
	Purpose:
	---
	Detect the first fault of an episode. True when fault_reg is still empty and at
	least one capture condition is live, which is exactly the clk on which the
	accumulator below sets its first bit.

	Built from the same conditions the accumulator tests rather than from fault_reg
	going non-empty, so the timestamp is latched on the SAME edge as the first cause
	rather than one clk later. The two blocks must agree; a condition added to one
	must be added to the other.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		episode_start = (convertor_running && (fault_reg == {5 {1'sb0}})) && (((((otp_state || uvlo_state) || ovp) || latch_assert) || window_trip) || window_trip_SS);
	end
	/*
	Purpose:
	---
	Latch the time the episode began, and hold it while further causes accumulate
	into fault_reg.

	Start rather than most-recent: with several causes in one record, one timestamp
	cannot describe them all, and "when did this begin" is the question worth
	answering. The later causes are usually consequences of the first.

	Cleared with fault_reg on a host read, so each read window carries its own start
	time. Clear takes priority over capture for the same reason it does below.

	LIMITATION: two episodes separated by a quiet interval, with no host read between
	them, merge into one record carrying the EARLIER timestamp. Ordering and
	repetition are not recoverable here - see the file header.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			fault_time <= 1'sb0;
		else if (fault_reg_read_done)
			fault_time <= 1'sb0;
		else if (episode_start)
			fault_time <= timestamp_ms;
	/*
	Purpose:
	---
	Accumulate causes across an episode and clear when the host reads the register.
	Bits are set, never cleared individually, so a fault that has since gone away is
	still reported.

	Clear-on-read makes the register mean "faults since you last asked", which is the
	question firmware is actually asking. It also self-corrects: a fault still live
	after a read re-sets its own bit on the next clock, so the register cannot go
	stale while something is genuinely wrong.

	The clear branch takes priority over capture, so a read landing on the same clock
	as a new cause starts a clean interval. Nothing is lost - if that cause is still
	asserted it is captured again immediately.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			fault_reg <= 1'sb0;
		else if (fault_reg_read_done)
			fault_reg <= 1'sb0;
		else if (convertor_running) begin
			if (otp_state)
				fault_reg[BIT_OTP] <= 1'b1;
			if (uvlo_state)
				fault_reg[BIT_UVLO] <= 1'b1;
			if (window_trip || window_trip_SS)
				fault_reg[BIT_OC] <= 1'b1;
			if (ovp)
				fault_reg[BIT_OVP] <= 1'b1;
			if (latch_assert)
				fault_reg[BIT_LATCH] <= 1'b1;
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
