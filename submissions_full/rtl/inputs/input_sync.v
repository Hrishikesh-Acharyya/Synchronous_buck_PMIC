/*

# Filename:         input_sync.v

# File Description: Two-flop synchronizer for a single asynchronous data
#                   input. rst_n gives both flops a known, defined value at
#                   power-up -- it does not represent or override the real
#                   state of async_in. Async clear is used (rather than a
#                   synchronous reset) so both flops reach a known state
#                   immediately, without waiting for a first clock edge that
#                   may be arbitrarily far away after power-on.

#                   Verilog-2005, converted from rtl-systemverilog/inputs/input_sync.sv by sv2v,
#                   with the comments restored by hand from the source.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module input_sync (
	clk,
	rst_n,
	async_in,
	sync_out
);
	// RESET_VALUE: Safe value on sync_out before a real sample has
	//              propagated through. For a fault input, set this to the
	//              value that means "fault asserted" -- assume the worst
	//              until a real reading proves otherwise.
	parameter [0:0] RESET_VALUE = 1'b0;
	input wire clk;
	input wire rst_n;
	input wire async_in;
	output reg sync_out;
	// meta_ff: First stage, absorbs metastability from async_in.
	reg meta_ff;
	/*
	Purpose:
	---
	The two synchroniser flops. meta_ff absorbs any metastability from
	async_in; sync_out is the clean copy one clock later. Both reset
	asynchronously to RESET_VALUE, so they hold a defined level before the
	first clock edge arrives.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			meta_ff <= RESET_VALUE;
			sync_out <= RESET_VALUE;
		end
		else begin
			meta_ff <= async_in;
			sync_out <= meta_ff;
		end
endmodule
`default_nettype wire
