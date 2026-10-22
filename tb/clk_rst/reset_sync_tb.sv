/*
# Filename:         reset_sync_tb.sv
# File Description: Directed testbench for reset_sync - checks async assertion
#                   and synchronous release of the internal reset
# Global variables: None
*/
`default_nettype none
`timescale 1ns/1ps

module reset_sync_tb;

import pmic_types_pkg::*;

// CLK_PERIOD_NS: supervisor clock period, derived from the package rather than
//                hardcoded, so retuning CLK_HZ moves every testbench with it.
//                Real division: integer arithmetic truncates for any CLK_HZ
//                that does not divide 1e9 exactly.
localparam realtime CLK_PERIOD_NS = 1.0e9 / real'(CLK_HZ);
// DRIVE_OFFSET_NS: How far past a clock edge stimulus is applied, so the
//                  DUT never sees an input change at its own capture edge.
localparam realtime DRIVE_OFFSET_NS = 3.0;
logic rst_n_enter;

logic rst_n_exit;

logic clk;
// checks_run:    Number of comparisons attempted across all test groups.
int checks_run    = 0;
// checks_failed: Number of those comparisons that mismatched.
int checks_failed = 0;

/*
Purpose:
---
Bounds the run so a stuck testbench fails rather than hanging the
simulator. Absolute delay, so it fires even if the clock stops.
*/
initial begin
    #10us;
    $fatal(1, "timeout - simulation did not complete");
end

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
    Compares one observed value against its expectation, logs the outcome and
    maintains the tallies. Generic rather than DUT-specific, so the same
    machinery carries to every testbench in the project. Uses !== so an X or Z
    is reported as a mismatch instead of passing silently.
  */
function automatic void check (input logic actual, 
                               input logic expected,
                               input string label);

  checks_run++;
  if(actual !== expected) begin

    checks_failed++;
    $display("[%0t] %s : expected %b, got %b", $time, label, expected, actual);

  end

  else begin

    $display("[%0t] %s : PASSED",$time, label);
  end

endfunction

initial begin

  clk = 1'b0;
  rst_n_enter = 1'b0;

end

always begin
  /*
    Purpose:
    ---
    Generate the 50 MHz testbench clock.
   */

  #(CLK_PERIOD_NS/2.0) clk = ~clk;

end

reset_sync dut (.clk(clk),.rst_n_enter(rst_n_enter), .rst_n_exit(rst_n_exit));

initial begin

  /*
    Purpose:
    ---
    Runs the directed test groups in order and reports the final verdict.
  */
    $display("\n==== reset_sync Testbench ====\n");

    // Test groups go here

    $display("[1] reset from time zero");
    rst_n_enter = 1'b0;
    repeat (2) @(posedge clk);
    check(rst_n_exit, 1'b0, "held in reset while rst_n_enter low");

    $display("\n[2] synchronous release");
    @(posedge clk);
    #DRIVE_OFFSET_NS;
    rst_n_enter = 1'b1;
    check(rst_n_exit, 1'b0, "release is not immediate");

    @(posedge clk); #1;
    check(rst_n_exit, 1'b0, "still low after one clock (meta_ff loading)");

    @(posedge clk); #1;
    check(rst_n_exit, 1'b1, "released after exactly two clocks");

    $display("\n[3] asynchronous assertion");
    @(posedge clk);
    #DRIVE_OFFSET_NS;
    rst_n_enter = 1'b0;
    #1;
    check(rst_n_exit, 1'b0, "asserts without waiting for a clock edge");

   


    $display("\n%0d checks, %0d failed", checks_run, checks_failed);
    if (checks_failed != 0) $fatal(1, "FAIL");
    $display("PASS\n");
    $finish;

end

endmodule

`default_nettype wire

