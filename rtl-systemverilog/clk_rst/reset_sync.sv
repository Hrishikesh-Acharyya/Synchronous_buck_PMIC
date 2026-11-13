/*

# Filename:         reset_sync.sv

# File Description: Two-flop synchronizer for the supervisor clock domain.
#                   Reset asserts asynchronously the instant rst_n_enter
#                   falls, and releases synchronously two clocks after
#                   rst_n_enter rises, so every flop clocked by clk comes
#                   out of reset on the same edge.
#
# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none

module reset_sync (
    input  wire logic clk,
    input  wire logic rst_n_enter,
    output logic rst_n_exit
);

// meta_ff: First stage of the synchronizer. Named for what it absorbs -
//          any metastability from rst_n_enter's asynchronous release -
//          rather than for its position in the chain.
logic meta_ff;

always_ff @(posedge clk or negedge rst_n_enter) begin

    /*
    Purpose:
    ---
    First synchronizer stage. Clears asynchronously with rst_n_enter so
    assertion has zero clock latency; sets high on the first clock after
    release.
    */

    if (!rst_n_enter) begin

        meta_ff <= 1'b0;

    end
    else begin

        meta_ff <= 1'b1;

    end

end

always_ff @(posedge clk or negedge rst_n_enter) begin

    /*
    Purpose:
    ---
    Second synchronizer stage. Independent async clear on rst_n_enter, same
    as the first stage, so both flops release on the same tested edge rather
    than one depending on the other's clear path settling first.
    */

    if (!rst_n_enter) begin

        rst_n_exit <= 1'b0;

    end
    else begin

        rst_n_exit <= meta_ff;

    end

end

endmodule

`default_nettype wire

