/*

# Filename:         fault_LED.v

# File Description: Drives the front-panel indicators. Shows what is wrong RIGHT
#                   NOW, which is a different question from the one fault_cause
#                   answers.
#
#
#                   Indicator map:
#                     Green_LED  solid while the converter is running unfaulted
#                     pgood_LED  follows the power-good comparator
#                     Red_LED1   solid on a latched trip, blinking while strikes
#                                are outstanding
#                     Red_LED2   over-temperature
#                     Red_LED3   input undervoltage
#
#                   Green and Red_LED1 are both lit during the clean-run window: the
#                   board genuinely is running while strikes are still outstanding,
#                   and showing both is more informative than suppressing either.
#
#                   Status only. Drives no control path and takes no part in any
#                   protection decision; removing this module leaves the converter
#                   functionally identical.

#                   Verilog-2005, converted from rtl/status/fault_LED.sv by sv2v,
#                   with the comments restored by hand from the source.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module fault_LED (
	clk,
	rst_n,
	otp_state,
	uvlo_state,
	latch_state,
	latch_assert,
	strike_level,
	ss_active,
	run_active,
	pgood,
	Green_LED,
	pgood_LED,
	Red_LED1,
	Red_LED2,
	Red_LED3
);
	// _sv2v_0: added by the conversion. An always_comb block runs once at
	// time zero; always @(*) does not, so each converted block reads this
	// constant-zero register to be evaluated at start-up in simulation.
	// Never assigned after time zero; synthesis removes it.
	reg _sv2v_0;
	// Package constants used here, inlined by the conversion from
	// pmic_types_pkg.sv. Each is evaluated at elaboration; none is hardware.
	// CLK_HZ: supervisor clock, from the external oscillator
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
	// ms_to_clks: milliseconds -> clk counts
	function automatic signed [31:0] pmic_types_pkg_ms_to_clks;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_clks = 50000 * ms;
	endfunction
	// LED_BLINK_HALF_CLKS: half the blink period, giving a 4 Hz blink. Sized
	//                      against the clean-run window rather than chosen for
	//                      looks: strikes clear after clean_run_target cycles,
	//                      about 1 s at the switching frequency, so a slower
	//                      blink would show only one or two cycles on a board
	//                      that recovers - which reads as a glitch rather than
	//                      a pattern. At 125 ms the recovery shows four clean
	//                      cycles.
	//
	//                      A parameter rather than a localparam so simulation
	//                      can override it: at 6.25 M clocks one blink edge is
	//                      125 ms of simulated time and no property about the
	//                      timebase is reachable.
	parameter signed [31:0] LED_BLINK_HALF_CLKS = pmic_types_pkg_ms_to_clks(125);
	// BLINK_W: derived from the half-period rather than taken independently,
	//          so an override cannot leave the two disagreeing.
	parameter signed [31:0] BLINK_W = $clog2(LED_BLINK_HALF_CLKS + 1);
	input wire clk;
	input wire rst_n;
	// ---- live fault conditions, all already synchronised and debounced ----
	input wire otp_state;  // debounced OTP comparator
	input wire uvlo_state;  // debounced input UVLO comparator
	input wire latch_state;  // debounced SCR readback
	input wire latch_assert;  // CPLD's own trip into the latch
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
	// ---- supervisor state ----
	// strike_level: hiccup strikes outstanding; non-zero from the first hiccup
	//               entry until clean_run_target fault-free cycles clear it
	input wire [1:0] strike_level;
	input wire ss_active;
	input wire run_active;
	input wire pgood;
	// ---- indicators ----
	output reg Green_LED;  // running, no fault present
	output reg pgood_LED;  // output rail in regulation
	output reg Red_LED1;  // latched trip (solid) or strikes outstanding (blink)
	output reg Red_LED2;  // over-temperature
	output reg Red_LED3;  // input undervoltage
	//blink_counter: free-running half-period counter for the blink pattern
	reg [BLINK_W - 1:0] blink_counter;
	//blink: square wave, high for half the blink period
	reg blink;
	//currently_faulted: any fault condition live right now
	reg currently_faulted;
	// sv2v_cast_*: generated by the conversion. Each implements one
	// SystemVerilog width cast, N'(x), of the source: it returns its
	// argument resized to the declared width - a pure width conversion that adds no logic.
	function automatic signed [BLINK_W - 1:0] sv2v_cast_83398_signed;
		input reg signed [BLINK_W - 1:0] inp;
		sv2v_cast_83398_signed = inp;
	endfunction
	/*
	Purpose:
	---
	Free-running blink timebase. Runs unconditionally rather than being started by
	a fault, so a blink that begins mid-period is not half-length - the pattern is
	always a clean square wave whenever something chooses to display it.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			blink_counter <= 1'sb0;
			blink <= 1'b0;
		end
		else if (blink_counter == sv2v_cast_83398_signed(LED_BLINK_HALF_CLKS - 1)) begin
			blink_counter <= 1'sb0;
			blink <= ~blink;
		end
		else
			blink_counter <= blink_counter + 1'b1;
	/*
	Purpose:
	---
	Any fault live right now. Used only to extinguish the green LED, so it is
	deliberately coarse - a separate red indicator says which fault it was.

	latch_state covers both trip sources, so no OVP inference is needed here. The
	display does not care WHO tripped the latch, only that it is set; fault_cause
	is where that distinction matters.

	The window trips are deliberately absent. A window trip takes the supervisor
	out of S_RUN on the next edge, so run_active extinguishes the green LED anyway
	- including them would be a second path to the same result.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		currently_faulted = ((otp_state || uvlo_state) || latch_state) || latch_assert;
	end
	/*
	Purpose:
	---
	Running indication. Lit only while the converter is actually switching and
	nothing is wrong, so it goes dark in S_OFF and S_HICCUP, and once latched, as well as
	on any live fault.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			Green_LED <= 1'b0;
		else
			Green_LED <= (ss_active || run_active) && !currently_faulted;
	/*
	Purpose:
	---
	Power-good indication, straight from the comparator.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			pgood_LED <= 1'b0;
		else
			pgood_LED <= pgood;
	/*
	Purpose:
	---
	Latch and strike indication, in priority order: a latched trip is terminal and
	outranks strikes that may still clear, so solid beats blinking. Solid versus
	blinking distinguishes "this board has given up" from "this board is working
	through a problem", which is the distinction worth making at a glance.

	The blink persists after the hiccup itself ends - through the retry, the
	soft-start and into S_RUN - until clean_run_target fault-free cycles clear the
	strikes. A recovering board therefore blinks for about a second of healthy
	running. That is deliberate: "recently troubled, now proving itself" is real
	information, and a board that keeps failing to earn the clear keeps blinking.

	After a latch the clean counter can never advance, because the converter never
	runs again, so strike_level stays non-zero indefinitely. The priority order
	masks it - the LED is solid, and the blink branch is unreachable in that state.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			Red_LED1 <= 1'b0;
		else if (latch_state || latch_assert)
			Red_LED1 <= 1'b1;
		else if (strike_level != {2 {1'sb0}})
			Red_LED1 <= blink;
		else
			Red_LED1 <= 1'b0;
	/*
	Purpose:
	---
	Over-temperature indication. The comparator holds its output for as long as the
	board is too hot, so no stretch is needed.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			Red_LED2 <= 1'b0;
		else
			Red_LED2 <= otp_state;
	/*
	Purpose:
	---
	Input undervoltage indication. Independent of Red_LED2 rather than chained
	after it: both conditions can be live at once and both must show.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			Red_LED3 <= 1'b0;
		else
			Red_LED3 <= uvlo_state;
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
