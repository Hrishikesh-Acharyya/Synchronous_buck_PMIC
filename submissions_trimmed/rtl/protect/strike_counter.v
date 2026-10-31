/*

# Filename:         strike_counter.v

# File Description: Counts hiccup retries and gives up after MAX_STRIKES.
#                    Each entry into the hiccup state is one strike; the
#                    strike level sets the cool-down interval in
#                    hiccup_timer, and reaching MAX_STRIKES asserts
#                    latch_assert to trip the SCR protection latch. A
#                    sustained fault-free period in S_RUN clears the count,
#                    so unrelated transients separated in time cannot
#                    accumulate into a permanent shutdown.

#                   Verilog-2005, converted from rtl/protect/strike_counter.sv by sv2v,
#                   with the comments restored by hand from the source.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module strike_counter (
	clk,
	rst_n,
	pwm_sync,
	hiccup_active,
	run_active,
	window_trip,
	max_strikes,
	clean_run_target,
	strike_level,
	latch_assert
);
	// _sv2v_0: added by the conversion. An always_comb block runs once at
	// time zero; always @(*) does not, so each converted block reads this
	// constant-zero register to be evaluated at start-up in simulation.
	// Never assigned after time zero; synthesis removes it.
	reg _sv2v_0;
	// Package constants used here, inlined by the conversion from
	// pmic_types_pkg.sv. Each is evaluated at elaboration; none is hardware.
	// CLEAN_RUN_MS: fault-free time in S_RUN that clears the strike count,
	//               so unrelated transients separated in time cannot
	//               accumulate into a permanent shutdown
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_MS = 1000;
	// CONVERTOR_HZ: switching frequency of the analog modulator
	localparam signed [31:0] pmic_types_pkg_CONVERTOR_HZ = 450000;
	// ms_to_sw_cycles: milliseconds -> switching cycles.
	function automatic signed [31:0] pmic_types_pkg_ms_to_sw_cycles;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_sw_cycles = 450 * ms;
	endfunction
	// CLEAN_RUN_CYCLES: the same interval in switching cycles, and the reset
	//                   default of the writable clean_run_target register
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_CYCLES = pmic_types_pkg_ms_to_sw_cycles(pmic_types_pkg_CLEAN_RUN_MS);
	// CLEAN_RUN_W: width of the clean-run counter and of the writable target.
	//              strike_counter now compares against clean_run_target rather
	//              than saturating at all-ones, so the realised interval is
	//              the value written, not 2**CLEAN_RUN_W. At the default this
	//              is 1.000 s, where the saturating version gave 1.165 s.
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_W = $clog2(pmic_types_pkg_CLEAN_RUN_CYCLES + 1);
	// CLEAN_RUN_W: fault-free switching cycle counter width;
	parameter signed [31:0] CLEAN_RUN_W = pmic_types_pkg_CLEAN_RUN_W;
	// MAX_STRIKES_DEFAULT: hiccup retries permitted before latch_assert, and
	//                      the reset value of the writable max_strikes
	//                      register. Writable DOWNWARD ONLY: raising it would
	//                      allow more retries into a persistent fault, and
	//                      would also widen STRIKE_W and HICCUP_TIMER_W, so
	//                      reg_file saturates upward writes at this value.
	localparam signed [31:0] pmic_types_pkg_MAX_STRIKES_DEFAULT = 3;
	// STRIKE_W: width of the strike level bus, shared by strike_counter and
	//           hiccup_timer
	localparam signed [31:0] pmic_types_pkg_STRIKE_W = 2;
	// STRIKE_W: width of the strike level bus, must match hiccup_timer
	parameter signed [31:0] STRIKE_W = pmic_types_pkg_STRIKE_W;
	input wire clk;
	input wire rst_n;
	input wire pwm_sync;  // synchronised raw PWM, for the cycle boundary
	input wire hiccup_active;  // high only while the supervisor is in S_HICCUP
	input wire run_active;  // high only while the supervisor is in S_RUN
	input wire window_trip;  // running fault window exceeded
	input wire [STRIKE_W - 1:0] max_strikes;  // MAX_STRIKES: hiccup entries permitted before latch assertion
	input wire [CLEAN_RUN_W - 1:0] clean_run_target;  // How many cycles no strikes
	output reg [STRIKE_W - 1:0] strike_level;  // strikes accumulated, sets the cool-down
	output reg latch_assert;  // MAX_STRIKES reached, trip the latch
	// hiccup_active_d: hiccup_active delayed one clk, to count entries not duration
	reg hiccup_active_d;
	// hiccup_entry: one-clk pulse on each entry into the hiccup state
	reg hiccup_entry;
	// pwm_sync_d: pwm_sync delayed one clk, used to detect the cycle boundary
	reg pwm_sync_d;
	// pwm_fall: one-clk pulse marking the end of a switching cycle
	reg pwm_fall;
	// clean_counter: consecutive fault-free switching cycles in S_RUN
	reg [CLEAN_RUN_W - 1:0] clean_counter;
	/*
	Purpose:
	---
	Delayed copies of hiccup_active and pwm_sync, so the edges below can be
	detected combinationally.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			hiccup_active_d <= 0;
			pwm_sync_d <= 0;
		end
		else begin
			hiccup_active_d <= hiccup_active;
			pwm_sync_d <= pwm_sync;
		end
	/*
	Purpose:
	---
	Convert two levels into one-clk enable pulses. hiccup_active is held for
	the whole cool-down, so counting it directly would add a strike every
	clock; the rising edge gives exactly one strike per hiccup. pwm_fall
	marks the switching-cycle boundary for the clean-run counter.

	Both are used as enables on the clk domain, never as clocks.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		hiccup_entry = hiccup_active & ~hiccup_active_d;
		pwm_fall = pwm_sync_d & ~pwm_sync;
	end
	/*
	Purpose:
	---
	Accumulate strikes and assert the latch once MAX_STRIKES is reached.
	The comparison is against MAX_STRIKES-1 because strike_level still holds
	the pre-increment value on this edge, so testing the value about to land
	fires the latch on the correct hiccup rather than one later.

	latch_assert is set-only and cleared by rst_n alone: it trips a physical
	SCR, which cannot be un-tripped in logic. strike_level is deliberately
	not zeroed on latching, so the accumulated count remains readable for
	telemetry.

	The clean-run clear is a sibling of hiccup_entry, not nested inside it,
	so a fault-free run clears the strikes during normal operation rather
	than only at the moment another hiccup begins.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			latch_assert <= 1'b0;
			strike_level <= 1'sb0;
		end
		else if (hiccup_entry) begin
			strike_level <= strike_level + 1;
			if (strike_level == (max_strikes - 1'b1))
				latch_assert <= 1'b1;
		end
		else if (clean_counter == clean_run_target)
			strike_level <= 1'sb0;
	/*
	Purpose:
	---
	Count consecutive fault-free switching cycles in S_RUN, saturating at the
	terminal value rather than wrapping.

	The streak is broken by leaving S_RUN as well as by window_trip. Time
	spent in S_HICCUP or S_SS is not running, and a counter that survived a
	hiccup would clear the very strike that hiccup earned - defeating the
	distinction between one isolated fault and a converter failing
	repeatedly.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			clean_counter <= 0;
		else if (!run_active || window_trip)
			clean_counter <= 0;
		else if (pwm_fall) begin
			if (clean_counter == clean_run_target)
				clean_counter <= clean_counter;
			else
				clean_counter <= clean_counter + 1;
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
