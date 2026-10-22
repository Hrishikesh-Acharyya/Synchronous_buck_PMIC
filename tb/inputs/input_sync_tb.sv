`timescale 1ns/1ps
`default_nettype none

module input_sync_tb;

import pmic_types_pkg::*;

// CLK_PERIOD_NS: supervisor clock period, derived from the package rather than
//                hardcoded, so retuning CLK_HZ moves every testbench with it.
//                Real division: integer arithmetic truncates for any CLK_HZ
//                that does not divide 1e9 exactly.
localparam realtime CLK_PERIOD_NS = 1.0e9 / real'(CLK_HZ);
localparam string   TB_NAME         = "input_sync_tb";
// WATCHDOG_NS: hard stop so a stalled run fails instead of hanging CI.
//              Size it against the longest segment below, not by habit.
localparam realtime WATCHDOG_NS     = 10_000.0;

logic clk;
logic rst_n;
logic async_in = 1'b0;
// Driven by the DUTs but not yet read: the only claim that inspects sync_out
// procedurally is the sub-cycle async-clear check, which is not written yet.
// The properties read these through the bound checker, inside input_sync's own
// scope, so no reader exists here. Remove this waiver with that check.
/* verilator lint_off UNUSEDSIGNAL */
logic sync_out_lo;      // sync_out of the RESET_VALUE = 0 instance
logic sync_out_hi;      // sync_out of the RESET_VALUE = 1 instance
/* verilator lint_on UNUSEDSIGNAL */

/*
Purpose:
---
Print $time in nanoseconds with no unit suffix, so log messages match the
timescale a reader of this file already has in mind.
*/

initial $timeformat(-9, 0, " ns", 10);



/*
Purpose:
---
Record a VCD only when asked, since the trace costs more than the run on
a short testbench. Enabled by +WAVES, which the Makefile passes for
WAVES=1.
*/
initial begin
    if ($test$plusargs("WAVES")) begin
        $dumpfile({TB_NAME, ".vcd"});
        $dumpvars(0, input_sync_tb);
    end
end
    
task automatic finish_run(input string reason);

  /*
  Purpose: single exit point for both the normal end and the watchdog, so a
           timeout reports a verdict instead of dying silently.
  */

    $display("--------------------------------------------------");
    $display("exit            : %s", reason);
    $display("assertion fails : %0d", sva_pkg::sva_failures);
    if (sva_pkg::sva_failures == 0) $display("input_sync_tb: PASS");
    else                            $display("input_sync_tb: FAIL");
    $display("--------------------------------------------------");
    $finish;
endtask

/*
Purpose:
---
Bounds the run so a stuck testbench fails rather than hanging the
simulator. Absolute delay, so it fires even if the clock stops.
*/
initial begin
    #WATCHDOG_NS;
    finish_run("WATCHDOG - Timeout - simulation did not complete");
end

initial begin
    /*
    purpose: Initialize the clock signal and generate the clock waveform.
     The clock is a free-running signal that toggles every half period.
     */
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2.0) clk = ~clk;
end

input_sync #(.RESET_VALUE(1'b0)) u_dut_lo (
    .clk(clk),
    .rst_n(rst_n),
    .async_in(async_in),
    .sync_out(sync_out_lo)
);

input_sync #(.RESET_VALUE(1'b1)) u_dut_hi (
    .clk(clk),
    .rst_n(rst_n),
    .async_in(async_in),
    .sync_out(sync_out_hi)
);

initial begin
    
  /*
    Purpose:
    ---
    Runs the directed test groups in order and reports the final verdict.
  */

  $display("\n==== input_sync Testbench ====\n");

    // Test groups go here
  rst_n = 1'b1;        // start deasserted so the next line is a genuine negedge
  #1 rst_n = 1'b0;     // async clear fires here, before any clock edge
  repeat (3) @(posedge clk);
  rst_n = 1'b1;
  repeat (3) @(posedge clk);
  #3 rst_n = 1'b0;
  @(posedge clk);

  finish_run("normal end");


end


endmodule
`default_nettype wire

