/*

# Filename:         input_sync_tb.sv

# File Description: Directed testbench for input_sync. Carries stimulus only -
#                   the three functional claims (reset value, both stages
#                   cleared, two-clock latency) live as properties in
#                   input_sync_sva.sv, bound to both DUT instances. The only
#                   procedural checks here are the sub-cycle async-clear
#                   comparisons in group 4.
#
#                   Two DUTs share one stimulus stream so RESET_VALUE 0 and 1
#                   are both exercised in one run. They form a differential
#                   pair: any claim comparing against RESET_VALUE is
#                   non-trivial on exactly one of them whatever async_in is
#                   driven to.

# Global variables: checks_run, checks_failed - mutated by check() from the
#                   stimulus block, so they are shared mutable state in this
#                   file.

*/

`timescale 1ns/1ps
`default_nettype none

module input_sync_tb;

import pmic_types_pkg::*;

// ANSI_*: terminal colour escapes for the verdict lines. Harmless when the
//         output is redirected to a file - the codes are inert bytes - but
//         they do appear as literal escapes there, so keep them off any
//         line a script parses. The Makefile's cover check greps the
//         annotated sources, not this output, so nothing downstream breaks.
localparam string ANSI_RED   = "\033[1;31m";
localparam string ANSI_GREEN = "\033[1;32m";
localparam string ANSI_RESET = "\033[0m";

// TB_NAME: prefix on log lines, so output stays attributable when several
//          testbenches run in one session
localparam string   TB_NAME         = "input_sync_tb";
// CLK_PERIOD_NS: supervisor clock period, derived from the package rather
//                than hardcoded, so retuning CLK_HZ moves every testbench
//                with it. Real division: integer arithmetic truncates for
//                any CLK_HZ that does not divide 1e9 exactly.
localparam realtime CLK_PERIOD_NS   = 1.0e9 / real'(CLK_HZ);
// WATCHDOG_NS: hard stop so a stalled run fails instead of hanging CI.
//              Sized well above the ~575 ns the four groups need.
localparam realtime WATCHDOG_NS     = 10_000.0;
// DRIVE_OFFSET_NS: how far past a clock edge stimulus is applied. Must be
//                  non-zero: @(posedge clk) resumes AT the edge, so an
//                  assignment on the next line lands in the same timestep.
//                  The DUT's always_ff would then capture the new value
//                  while the assertion's preponed sample sees the old one,
//                  and the two disagree about which side of the edge the
//                  change fell on. Group 2 varies the offset deliberately -
//                  async_in is asynchronous, so transitions should land at
//                  several phases rather than one fixed safe one.
localparam realtime DRIVE_OFFSET_NS = 3.0;
// SETTLE_NS: delay after a mid-cycle reset before the procedural checks
//            read sync_out. Small enough to stay inside the clock period,
//            so the check observes the asynchronous clear and not the next
//            clock edge.
localparam realtime SETTLE_NS       = 0.1;
// Asynchronous inputs are initialised to their inactive level at
// declaration. An uninitialised logic driven straight to its active level
// transitions x -> 0, which is not a reliable negedge, so the DUT's async
// clear never fires and both flops hold x until the first clock edge.


logic clk;
logic rst_n    = 1'b1;
logic async_in = 1'b0;
logic sync_out_lo;      // sync_out of the RESET_VALUE = 0 instance
logic sync_out_hi;      // sync_out of the RESET_VALUE = 1 instanc
int unsigned checks_run    = 0;
int unsigned checks_failed = 0;


// ============================================================
// DUTs
// ============================================================
input_sync #(.RESET_VALUE(1'b0)) u_dut_lo (
    .clk      (clk),
    .rst_n    (rst_n),
    .async_in (async_in),
    .sync_out (sync_out_lo)
);
input_sync #(.RESET_VALUE(1'b1)) u_dut_hi (
    .clk      (clk),
    .rst_n    (rst_n),
    .async_in (async_in),
    .sync_out (sync_out_hi)
);


initial begin
    /*
    Purpose:
    ---
    Free-running clock. Drives clk and nothing else - a second initial
    block assigning any signal this one touches is a race.
    */
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2.0) clk = ~clk;
end


/*
Purpose:
---
Print $time in nanoseconds, matching the timescale a reader of this file
already has in mind.
*/
initial $timeformat(-9, 0, " ns", 10);

initial begin
    /*
    Purpose:
    ---
    Record a VCD only when asked, since the trace costs more than the run
    on a testbench this short. Enabled by +WAVES, which the Makefile
    passes for WAVES=1.
    */
    if ($test$plusargs("WAVES")) begin
        $dumpfile({TB_NAME, ".vcd"});
        $dumpvars(0, input_sync_tb);
    end
end


// check: procedural comparison, for claims no clocked property can see -
//        here, the asynchronous clear taking effect between clock edges.

task automatic check(input bit condition, input string label);
    checks_run++;
    if (!condition) begin
        checks_failed++;
        $display("[%0t] CHECK FAIL: %s", $time, label);
    end
endtask


// finish_run: single exit point for both the normal end and the watchdog,
//             so a timeout reports a verdict instead of dying silently.
//             Never $fatal - it exits before the tallies are printed.
task automatic finish_run(input string reason);
    bit passed;
    passed = (sva_pkg::sva_failures == 0) && (checks_failed == 0);
    $display("--------------------------------------------------");
    $display("exit            : %s", reason);
    $display("assertion fails : %s%0d%s",
             (sva_pkg::sva_failures == 0) ? ANSI_GREEN : ANSI_RED,
             sva_pkg::sva_failures, ANSI_RESET);
    $display("checks run      : %0d", checks_run);
    $display("checks failed   : %s%0d%s",
             (checks_failed == 0) ? ANSI_GREEN : ANSI_RED,
             checks_failed, ANSI_RESET);
    if (passed)
        $display("%s%s: PASS%s  (check cover hits before trusting this)",
                 ANSI_GREEN, TB_NAME, ANSI_RESET);
    else
        $display("%s%s: FAIL%s", ANSI_RED, TB_NAME, ANSI_RESET);
    $display("--------------------------------------------------");
    // $stop on failure: non-zero exit status, so make and CI see the FAIL.
    // Not $fatal - by this point the tallies are already printed.
    if (passed) $finish;
    else        $stop;
    
endtask


initial begin
    /*
    Purpose:
    ---
    Bounds the run so a stalled testbench fails rather than hanging the
    simulator. Absolute delay, so it fires even if the clock stops. Counts
    as a failure so the verdict and the exit status both report it.
    */
    #(WATCHDOG_NS);
    checks_failed++;
    finish_run("WATCHDOG - did not complete");
end


// ============================================================
// Stimulus
// ===========================================================
initial begin
    /*
    Purpose:
    ---
    Drives the four directed groups in order, then reports the verdict.
    Groups 1 to 3 carry no checks: the bound checker evaluates on every
    edge regardless, and these groups exist to make its antecedents occur.
    Only group 4 checks procedurally.
    */
    $display("\n==== %s ====\n", TB_NAME);


    // ---- Group 1: reset behaviour ----
    // Establishes a known high before asserting, so the fall is a genuine
    // negedge and the DUT's async clear fires before any clock edge.
    // Exercises a_sync_out_reads_RESET.
    rst_n = 1'b1;
    #1 rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    repeat (3) @(posedge clk);
    #(DRIVE_OFFSET_NS) rst_n = 1'b0;
    @(posedge clk);


    // ---- Group 2: two-clock latency ----
    // Toggles async_in while the chain is running, at three different
    // phases within the clock period, to exercise a_two_clock_latency in
    // both directions. The three settling clocks after release let
    // clocks_after_reset_release saturate before the first transition, so
    // no edge falls inside the property's blanking window.
    rst_n = 1'b1;
    repeat (3) @(posedge clk);
    #(DRIVE_OFFSET_NS) async_in = 1'b1;
    repeat (3) @(posedge clk);
    #(5.0) async_in = 1'b0;
    repeat (3) @(posedge clk);
    #(7.0) async_in = 1'b1;
    repeat (3) @(posedge clk);


    // ---- Group 3: reset asserted mid-propagation ----
    // async_in is driven opposite to u_dut_lo's RESET_VALUE and given
    // exactly one clock, so meta_ff has loaded it while sync_out has not.
    // Reset then arrives with the two stages holding different values -
    // the only state in which "both stages cleared" is distinguishable
    // from "only sync_out cleared". Exercises
    // a_one_clock_after_release on the following release.
    #(DRIVE_OFFSET_NS) async_in = 1'b1;
    @(posedge clk);                         // meta_ff takes 1, sync_out does not
    #(DRIVE_OFFSET_NS) rst_n = 1'b0;        // clear arrives with stages differing
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    repeat (3) @(posedge clk);


    // ---- Group 4: asynchronous clear is immediate ----
    // The one claim no clocked property can observe: the clear must take
    // effect between edges, not at the next one. async_in is held high so
    // both outputs are high beforehand, making the lo instance's clear a
    // real change rather than a value it already held.
    #(DRIVE_OFFSET_NS) async_in = 1'b1;
    repeat (3) @(posedge clk);
    #(DRIVE_OFFSET_NS) rst_n = 1'b0;
    #(SETTLE_NS);
    check(sync_out_lo === 1'b0, "u_dut_lo: async clear did not take effect");
    check(sync_out_hi === 1'b1, "u_dut_hi: async clear did not take effect");
    finish_run("normal end");

end

endmodule

`default_nettype wire

