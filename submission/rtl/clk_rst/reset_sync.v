/*

# Filename:         reset_sync.v

# File Description: Two-flop synchronizer for the supervisor clock domain.
#                   Reset asserts asynchronously the instant rst_n_enter
#                   falls, and releases synchronously two clocks after
#                   rst_n_enter rises, so every flop clocked by clk comes
#                   out of reset on the same edge.
#
#                   Verilog-2005, converted from rtl/clk_rst/reset_sync.sv by sv2v,
#                   with the comments restored by hand from the source.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module reset_sync (
	clk,
	rst_n_enter,
	rst_n_exit
);
	input wire clk;
	input wire rst_n_enter;
	output reg rst_n_exit;
	// meta_ff: First stage of the synchronizer. Named for what it absorbs -
	//          any metastability from rst_n_enter's asynchronous release -
	//          rather than for its position in the chain.
	reg meta_ff;
	/*
	Purpose:
	---
	First synchronizer stage. Clears asynchronously with rst_n_enter so
	assertion has zero clock latency; sets high on the first clock after
	release.
	*/
	always @(posedge clk or negedge rst_n_enter)
		if (!rst_n_enter)
			meta_ff <= 1'b0;
		else
			meta_ff <= 1'b1;
	/*
	Purpose:
	---
	Second synchronizer stage. Independent async clear on rst_n_enter, same
	as the first stage, so both flops release on the same tested edge rather
	than one depending on the other's clear path settling first.
	*/
	always @(posedge clk or negedge rst_n_enter)
		if (!rst_n_enter)
			rst_n_exit <= 1'b0;
		else
			rst_n_exit <= meta_ff;
endmodule
`default_nettype wire
