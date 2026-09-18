/*

# Filename:         input_sync.sv

# File Description: Two-flop synchronizer for a single asynchronous data
#                   input. rst_n gives both flops a known, defined value at
#                   power-up -- it does not represent or override the real
#                   state of async_in. Async clear is used (rather than a
#                   synchronous reset) so both flops reach a known state
#                   immediately, without waiting for a first clock edge that
#                   may be arbitrarily far away after power-on.

# Global variables: None

*/

`default_nettype none

module input_sync #(
    // RESET_VALUE: Safe value on sync_out before a real sample has
    //              propagated through. For a fault input, set this to the
    //              value that means "fault asserted" -- assume the worst
    //              until a real reading proves otherwise.
    parameter logic RESET_VALUE = 1'b0
) (
    input  logic clk,
    input  logic rst_n,
    input  logic async_in,
    output logic sync_out
);

    // meta_ff: First stage, absorbs metastability from async_in.
    logic meta_ff;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            meta_ff  <= RESET_VALUE;
            sync_out <= RESET_VALUE;
        end
        else begin
            meta_ff  <= async_in;
            sync_out <= meta_ff;
        end
    end

endmodule

`default_nettype wire