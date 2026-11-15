/*

# Filename:         supervisor.v

# File Description: Supervisory state machine for the buck converter. Decides
#                   when the power stage may run, sequences soft start into
#                   regulation, sends a faulting converter into a hiccup
#                   cool-down, and shuts it off on any hard fault. Four states:
#
#                     S_OFF     disabled; leaves only when enabled and no
#                               fault is present
#                     S_SS      enabled, ramping the duty ceiling; to S_RUN
#                               on SS_done, to S_HICCUP on window_trip_SS
#                     S_RUN     enabled, regulating; to S_HICCUP on
#                               window_trip
#                     S_HICCUP  disabled for the cool-down; back to S_SS on
#                               hiccup_done - a retry always re-ramps, never
#                               re-enables straight into S_RUN
#
#                   OTP, UVLO, the latch read-back, latch_assert and losing
#                   the enable force S_OFF from every state. The analog OVP
#                   comparator needs no input here: it trips the shared
#                   protection latch directly, and the latch is seen on
#                   latch_state at once.
#
#                   en, the LM5106 enable, is gated combinationally by the
#                   fault inputs as well as by the state, so a trip pulls the
#                   gate drive low on the same clock rather than waiting for
#                   the next state to register.
#
#                   Verilog-2005, converted from rtl-systemverilog/supervisor.sv by sv2v,
#                   with the comments restored by hand from the source. The
#                   state_t enum becomes a 2-bit code: S_OFF 2'b00, S_SS 2'b01,
#                   S_RUN 2'b10, S_HICCUP 2'b11.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module supervisor (
	clk,
	rst_n,
	en_SW,
	spi_enable,
	OTP,
	UVLO,
	latch_state,
	latch_assert,
	SS_done,
	window_trip_SS,
	window_trip,
	hiccup_done,
	en,
	ss_active,
	run_active,
	hiccup_active,
	state_out
);
	// _sv2v_0: added by the conversion. An always_comb block runs once at
	// time zero; always @(*) does not, so each converted block reads this
	// constant-zero register to be evaluated at start-up in simulation.
	// Never assigned after time zero; synthesis removes it.
	reg _sv2v_0;
	input wire clk;
	input wire rst_n;
	input wire en_SW;  // physical on/off switch, synchronised and debounced
	input wire spi_enable;  // host enable over SPI (tied high without telemetry)
	input wire OTP;  // over-temperature, debounced
	input wire UVLO;  // input undervoltage, debounced
	input wire latch_state;  // SCR protection latch read back, debounced
	input wire latch_assert;  // strike_counter's trip into the latch
	input wire SS_done;  // soft_start: the ramp has reached its target
	input wire window_trip_SS;  // fault_arbiter: overcurrent window exceeded in S_SS
	input wire window_trip;  // fault_arbiter: overcurrent window exceeded in S_RUN
	input wire hiccup_done;  // hiccup_timer: the cool-down has elapsed
	output reg en;  // LM5106 enable
	output reg ss_active;  // high only in S_SS
	output reg run_active;  // high only in S_RUN
	output reg hiccup_active;  // high only in S_HICCUP
	output reg [1:0] state_out;  // present state, for telemetry
	// g_en: the converter is enabled - the switch is on and the host has not
	//       disabled it
	reg g_en;
	// state: the present state, registered
	reg [1:0] state;
	// next_state: the state the next clock edge will load
	reg [1:0] next_state;
	// en_from_state: the states in which the power stage may switch, before the
	//                fault gating applied to en
	reg en_from_state;
	/*
	Purpose:
	---
	Combine the two enables. The physical switch and the host must both allow the
	converter to run; either one alone turns it off.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		g_en = spi_enable & en_SW;
	end
	/*
	Purpose:
	---
	State register. Reset puts the converter in S_OFF, so it never powers up
	switching.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			state <= 2'b00;
		else
			state <= next_state;
	/*
	Purpose:
	---
	Next-state logic. In every state the hard faults - losing g_en, OTP, UVLO,
	latch_state, latch_assert - are tested first and go to S_OFF, so no sequencing
	condition can outrank a shutdown. latch_assert also inhibits start-up, so a
	strike-latched part cannot restart before the latch is read back on
	latch_state, and it is tested in S_RUN as well so that state and output agree:
	en is already forced low by it, and without the state change the FSM would
	stay in S_RUN and re-enable at full duty when it released.

	Each state then holds unless its own condition moves it on. S_SS holds until
	SS_done, otherwise the state would last a single clock and the ramp would never
	be awaited; S_HICCUP holds until hiccup_done, so the cool-down actually elapses
	before a retry. An illegal encoding turns the converter off.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		(* full_case, parallel_case *)
		case (state)
			2'b00:
				if ((((g_en & ~latch_state) & ~OTP) & ~UVLO) & ~latch_assert)
					next_state = 2'b01;
				else
					next_state = 2'b00;
			2'b01:
				if ((((~g_en | OTP) | latch_state) | UVLO) | latch_assert)
					next_state = 2'b00;
				else if (window_trip_SS)
					next_state = 2'b11;
				else if (SS_done)
					next_state = 2'b10;
				else
					next_state = 2'b01;
			2'b10:
				if ((((~g_en | latch_state) | OTP) | UVLO) | latch_assert)
					next_state = 2'b00;
				else if (window_trip)
					next_state = 2'b11;
				else
					next_state = 2'b10;
			2'b11:
				if ((((~g_en | latch_state) | OTP) | latch_assert) | UVLO)
					next_state = 2'b00;
				else if (hiccup_done)
					next_state = 2'b01;
				else
					next_state = 2'b11;
			// an illegal state encoding turns the converter off
			default: next_state = 2'b00;
		endcase
	end
	/*
	Purpose:
	---
	The states in which the power stage may switch: soft start and regulation.
	Off and the hiccup cool-down hold the gate drive low.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (state)
			2'b00: en_from_state = 1'b0;
			2'b01: en_from_state = 1'b1;
			2'b10: en_from_state = 1'b1;
			2'b11: en_from_state = 1'b0;
			default: en_from_state = 1'b0;
		endcase
	end
	/*
	Purpose:
	---
	Decode the present state for the blocks that act in one state only - soft
	start, the PWM statistics, the hiccup timer and strike counter, the fault log
	and power-good - and expose it for telemetry.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		ss_active = state == 2'b01;
		run_active = state == 2'b10;
		hiccup_active = state == 2'b11;
		state_out = state;
	end
	/*
	Purpose:
	---
	Drive the LM5106 enable. Gated by the fault inputs directly as well as by the
	state, so a trip pulls the gate drive low combinationally, on the same clock,
	instead of a clock later when the FSM has registered S_OFF.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		en = ((((g_en & en_from_state) & ~OTP) & ~latch_state) & ~UVLO) & ~latch_assert;
	end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
