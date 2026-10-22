/*

# Filename:         input_sync_sva.sv

# File Description: Concurrent assertion checker for input_sync. Attached with
#                   bind so the RTL source carries no assertion constructs and
#                   the sv2v / Yosys ASIC path never sees them. RESET_VALUE is
#                   passed through from the bound instance so each call site is
#                   checked against its own reset level.

# Global variables: None

*/

`default_nettype none

module input_sync_sva #(
 
    parameter logic RESET_VALUE = 1'b0
) (
    input  wire logic clk,
    input  wire logic rst_n,
    /* verilator lint_off UNUSEDSIGNAL */
    // async_in is a port of input_sync and so must appear here for .* to
    // resolve, but no property reads it yet. Remove this waiver when
    // p_two_clock_latency lands - after that an unused port would be a real
    // finding.
    input  wire logic async_in,
    /* verilator lint_on UNUSEDSIGNAL */
    input  wire logic sync_out
);

property p_sync_out_reads_RESET;

    @(posedge clk)
        !rst_n |-> (sync_out == RESET_VALUE);
endproperty

a_sync_out_reads_RESET: assert property (p_sync_out_reads_RESET)
    else begin

        sva_pkg::note_failure($sformatf(
        "a_sync_out_reads_RESET: sync_out=%b expected %b", sync_out, RESET_VALUE));

    end

// c_reset_active: confirms reset was actually entered. Without a hit here,
//                 a_sync_out_reads_RESET never evaluated and its pass is
//                 vacuous.
c_reset_active: cover property (@(posedge clk) !rst_n);

endmodule
`default_nettype wire




