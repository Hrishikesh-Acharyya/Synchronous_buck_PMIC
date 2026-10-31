/*

# Filename:         supervisor.v

# File Description: Supervisor state machine for the buck converter. Four
#                   states - S_OFF, S_SS (soft start), S_RUN and S_HICCUP
#                   (post-fault cool-down) - and the LM5106 enable output.
#                   Any fault, a host disable or the enable switch forces
#                   S_OFF from every state; an overcurrent window trip sends
#                   S_SS or S_RUN to S_HICCUP; the cool-down timer returns
#                   S_HICCUP to S_SS for a retry; a completed ramp moves
#                   S_SS to S_RUN. En is the state decode gated
#                   combinationally by every fault, so the gate driver is
#                   disabled in the same clock a fault is seen, one clock
#                   ahead of the state change.
#
#                   Verilog-2005, converted from rtl/supervisor.sv by sv2v.
#                   The source has no file header or Purpose blocks; these
#                   were written for the submission from its state comments.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module supervisor (
	clk,
	SS_done,
	rst_n,
	latch_state,
	OTP,
	window_trip_SS,
	window_trip,
	latch_assert,
	UVLO,
	hiccup_done,
	en_SW,
	spi_enable,
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
	input wire clk;  // supervisor clock
	input wire SS_done;  // soft-start ramp has reached its ceiling
	input wire rst_n;  // synchronised reset, active low
	input wire latch_state;  // debounced SCR latch readback
	input wire OTP;  // debounced over-temperature flag
	input wire window_trip_SS;  // overcurrent window exceeded in S_SS
	input wire window_trip;  // overcurrent window exceeded in S_RUN
	input wire latch_assert;  // strike_counter's trip into the latch
	input wire UVLO;  // debounced input undervoltage flag
	input wire hiccup_done;  // cool-down interval has elapsed
	input wire en_SW;  // debounced enable switch
	input wire spi_enable;  // host enable from the register file
	output reg en;  // LM5106 enable
	output reg ss_active;  // high only in S_SS
	output reg run_active;  // high only in S_RUN
	output reg hiccup_active;  // high only in S_HICCUP
	output reg [1:0] state_out;  // supervisor state, for telemetry
	// en_from_state: the states that drive the gate driver, before fault gating
	reg en_from_state;
	// state / next_state: the enum state_t in the source. Binary encoding - at
	// four states it costs two flops against one-hot's four, and the next-state
	// logic is small enough that binary does not hurt timing:
	//   2'b00 S_OFF     converter disabled; every fault forces entry here
	//   2'b01 S_SS      soft start; output enabled, ramp in progress
	//   2'b10 S_RUN     normal regulation
	//   2'b11 S_HICCUP  post-fault off-time while the power stage cools
	reg [1:0] state;
	reg [1:0] next_state;
	//The enabled derived via spi signal from MCU and the physical on/off switch.
	wire g_en;
	assign g_en = spi_enable & en_SW;
	/*
	Purpose:
	---
	State register. Resets to S_OFF.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			state <= 2'b00;  // S_OFF
		else
			state <= next_state;
	/*
	Purpose:
	---
	Next-state logic. Every state tests the fault and enable conditions first,
	so a fault reaches S_OFF from anywhere, then its own advance. The final
	else of each state holds it: soft start in particular must stay active
	until SS_done, or the ramp would last a single clock.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		// (* full_case, parallel_case *) is how the conversion renders the source's
		// unique case: the simulator's overlap check is gone, and synthesis is told
		// the items are complete and mutually exclusive. Both hold here - every
		// encoding has its own item and the default covers the unused ones.
		(* full_case, parallel_case *)
		case (state)
			// S_OFF: go to S_SS only when g_en is high, not latched, and no OTP or
			// UVLO. Start-up is also inhibited by latch_assert, so a strike-latched
			// part cannot restart before the latch is read back on latch_state.
			2'b00:  // S_OFF
				if ((((g_en & ~latch_state) & ~OTP) & ~UVLO) & ~latch_assert)
					next_state = 2'b01;  // S_SS
				else
					next_state = 2'b00;  // S_OFF
			// S_SS: loss of enable or any fault goes to S_OFF; too many faulted cycles
			// in the soft-start window goes to S_HICCUP; a completed ramp goes to
			// S_RUN. Overvoltage needs no term: any latching shows on latch_state.
			2'b01:  // S_SS
				if ((((~g_en | OTP) | latch_state) | UVLO) | latch_assert)
					next_state = 2'b00;  // S_OFF
				else if (window_trip_SS)
					next_state = 2'b11;  // S_HICCUP
				else if (SS_done)
					next_state = 2'b10;  // S_RUN
				else
					next_state = 2'b01;  // S_SS
			// S_RUN: loss of enable or any fault goes to S_OFF - latch_assert included
			// so state and output agree; a window trip goes to S_HICCUP.
			2'b10:  // S_RUN
				if ((((~g_en | latch_state) | OTP) | UVLO) | latch_assert)
					next_state = 2'b00;  // S_OFF
				else if (window_trip)
					next_state = 2'b11;  // S_HICCUP
				else
					next_state = 2'b10;  // S_RUN
			// S_HICCUP: loss of enable or any fault goes to S_OFF; otherwise hold until
			// the cool-down has actually elapsed, then retry through S_SS.
			2'b11:  // S_HICCUP
				if ((((~g_en | latch_state) | OTP) | latch_assert) | UVLO)
					next_state = 2'b00;  // S_OFF
				else if (hiccup_done)
					next_state = 2'b01;  // S_SS
				else
					next_state = 2'b11;  // S_HICCUP
			default: next_state = 2'b00;  // illegal encodings turn the PMIC off
		endcase
	end
	/*
	Purpose:
	---
	Which states enable the gate driver: S_SS and S_RUN.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		// see the note on the case above
		(* full_case, parallel_case *)
		case (state)
			2'b00: en_from_state = 1'b0;  // S_OFF
			2'b01: en_from_state = 1'b1;  // S_SS
			2'b10: en_from_state = 1'b1;  // S_RUN
			2'b11: en_from_state = 1'b0;  // S_HICCUP
			default: en_from_state = 1'b0;
		endcase
	end
	/*
	Purpose:
	---
	Status decode for the protection and status blocks: high only in S_SS.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		ss_active = state == 2'b01;  // S_SS
	end
	/*
	Purpose:
	---
	Status decode: high only in S_RUN.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		run_active = state == 2'b10;  // S_RUN
	end
	/*
	Purpose:
	---
	Status decode: high only in S_HICCUP.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		hiccup_active = state == 2'b11;  // S_HICCUP
	end
	/*
	Purpose:
	---
	LM5106 enable: the state decode, gated combinationally by both enables
	and every fault, so a fault removes gate drive in the same clock it
	appears, ahead of the state change on the next edge.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		en = ((((g_en & en_from_state) & ~OTP) & ~latch_state) & ~UVLO) & ~latch_assert;
	end
	/*
	Purpose:
	---
	State out to the register file, for telemetry.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		state_out = state;
	end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
