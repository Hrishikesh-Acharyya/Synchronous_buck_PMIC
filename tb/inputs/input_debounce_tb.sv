/*

# Filename:         input_debounce_tb.sv

# File Description: Directed testbench for input_debounce. Carries stimulus
#                   only - every functional claim lives as a property in
#                   input_debounce_sva.sv, bound to both DUT instances.o.
#
#                   Two DUTs share one flag_in. u_dut_asym has unequal
#                   qualification times, so a swapped target selection is
#                   visible; u_dut_sym runs the symmetric regime the three
#                   SPI filters use. They also reset to opposite levels, so
#                   any flag_in level puts one in agreement and the other in
#                   a qualification window - both directions get exercised
#                   from a single hold, and the covers split on direction to
#                   show it.
#
#                   Parameters are overridden far below the package values.
#                   DEBOUNCE_ASSERT_CLKS is ms_to_clks(1) = 50,000 at 50 MHz,
#                   which would make an N-1 boundary case take a millisecond
#                   of simulated time. Five and three preserve the asymmetry
#                   and cost five clocks.

# Global variables: None

*/

`timescale 1ns/1ps
`default_nettype none

module input_debounce_tb;

import pmic_types_pkg::*;

// ANSI_*: terminal colour escapes for the verdict lines. Harmless when the
//         output is redirected to a file - the codes are inert bytes - but
//         they do appear as literal escapes there, so keep them off any
//         line a script parses. The Makefile's cover check greps the
//         annotated sources, not this output, so nothing downstream breaks.
localparam string ANSI_RED   = "\033[1;31m";
localparam string ANSI_GREEN = "\033[1;32m";
localparam string ANSI_RESET = "\033[0m";


// TB_NAME: prefix on every log line, so output is attributable when
//          several testbenches run in one session
localparam string   TB_NAME         = "input_debounce_tb";
// CLK_PERIOD_NS: supervisor clock period, derived from the package rather
//                than hardcoded, so retuning CLK_HZ moves every testbench
//                with it. Real division: integer arithmetic truncates for
//                any CLK_HZ that does not divide 1e9 exactly.
localparam realtime CLK_PERIOD_NS   = 1.0e9 / real'(CLK_HZ);
// WATCHDOG_NS: hard stop so a stalled run fails instead of hanging CI.
//              Size it against the longest segment below, not by habit.
localparam realtime WATCHDOG_NS     = 10_000.0;
// RESET_CLKS: clocks reset is held in do_reset()
localparam int      RESET_CLKS      = 3;
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



// Asynchronous inputs are initialised to their INACTIVE level at
// declaration. An uninitialised logic driven straight to its active level
// transitions x -> 0, which is not a reliable negedge, so an async clear
// in the DUT never fires and the flops sit at x until the first clock edge.
logic clk;
logic rst_n = 1'b1;
logic flag_in = 1'b0;
/* verilator lint_off UNUSEDSIGNAL */

logic flag_out_asym = 1'b0;
logic flag_out_sym = 1'b0;
/* verilator lint_on UNUSEDSIGNAL */
int unsigned checks_run    = 0;
int unsigned checks_failed = 0;



// ============================================================
// DUT
// ============================================================

// u_dut_asym: the main DUT. ASSERT_CLKS != RELEASE_CLKS so a swapped target
//             selection is visible; both small enough that an N-1 boundary
//             case costs five clocks rather than a millisecond.
input_debounce #(.ASSERT_CLKS(5), .RELEASE_CLKS(3), .RESET_VALUE(1'b1)) u_dut_asym (
    .clk(clk),
    .rst_n(rst_n),
    .flag_in(flag_in),
    .flag_out(flag_out_asym));

// u_dut_sym: symmetric and short, the regime the three SPI filters run in.
input_debounce #(.ASSERT_CLKS(SPI_FILTER_CLKS), .RELEASE_CLKS(SPI_FILTER_CLKS),
                 .RESET_VALUE(1'b0)) u_dut_sym (
                    .clk(clk),
                    .rst_n(rst_n),
                    .flag_in(flag_in),
                    .flag_out(flag_out_sym)
                 );


/*
Purpose:
---
Free-running clock. Generates the clock and nothing else - a second
initial block assigning any signal this one touches is a race.
*/
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2.0) clk = ~clk;
end

/*
Purpose:
---
Print $time in nanoseconds, matching the timescale a reader of this file
already has in mind.
*/

initial $timeformat(-9, 1, " ns", 10);



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
        $dumpvars(0, input_debounce_tb);
    end
end



// do_reset: asserts and releases reset with a genuine falling edge, so the
//           DUT's async clear fires before any clock arrives. rst_n is
//           driven high first for that reason even when already high.
task automatic do_reset();
    rst_n = 1'b1;
    #1;
    rst_n = 1'b0;
    repeat (RESET_CLKS) @(posedge clk);
    rst_n = 1'b1;
    repeat (RESET_CLKS) @(posedge clk);
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



/*
Purpose:
---
Bounds the run so a stalled testbench fails rather than hanging the
simulator. Absolute delay, so it fires even if the clock stops. Counts as
a failure so the verdict and the exit status both report it.
*/
initial begin
    #(WATCHDOG_NS);
    checks_failed++;
    finish_run("WATCHDOG - did not complete");
end


// ============================================================
// Stimulus
// ============================================================
/*
Purpose:
---
Drives the directed groups in order. None of them carry procedural checks:
every claim on this module is an edge-clocked statement about signal values,
so all of them live as properties in the bound checker, which evaluates on
every edge regardless of what the stimulus is doing. The groups exist only to
make the checker's antecedents occur, and the cover counts are the evidence
that they did.
*/


initial begin
$display("\n==== %s ====\n", TB_NAME);

/*
Group 1: reset.
---
do_reset drives rst_n high before asserting it, so the fall is a genuine
negedge and the async clear reaches the flops before any clock edge. An
uninitialised signal going x->0 is not reliably a negedge: the always_ff
would never wake, and flag_out would hold x until the first clock loaded
it one cycle late.

*/

do_reset();


/*
Group 2: full qualification windows, both directions.
---
flag_in is held well past the longest target so every window completes:
12 clocks clears the symmetric DUT's 8 as well as the asymmetric DUT's 5
and 3. Shorter holds leave the symmetric instance mid-window and
c_ASSERT_works drops to one hit instead of two - the count is how you
tell.
Because the two DUTs reset to opposite levels, each flag_in level puts
one instance in agreement and the other in a qualification window. One
hold therefore exercises an assert on one instance and a release on the
other, which is what makes c_ASSERT_works and c_RELEASE_works both
non-zero from two stimulus lines.
Exercises the latency bounds together: a_flag_out_qualified is the lower
bound (no transition without an earned window) and
a_ASSERT_and_RELEASE_work the upper (a completed window does produce one,
on the next edge).
*/
#(DRIVE_OFFSET_NS) flag_in = 1'b1;
repeat (12) @(posedge clk);
#(DRIVE_OFFSET_NS) flag_in = 1'b0;
repeat (12) @(posedge clk);
/*
Group 3: glitch at N-1, the module's reason for existing.
---
flag_in disagrees for four edges - one short of the asymmetric DUT's
ASSERT_CLKS of 5 - then agrees for a single edge, then holds the full
window. flag_out must move only after the second window: the first is
abandoned and the count must restart from zero rather than resume.

*/

#(DRIVE_OFFSET_NS) flag_in = 1'b1;
repeat (4) @(posedge clk);          // one short of ASSERT_CLKS = 5
#(DRIVE_OFFSET_NS) flag_in = 1'b0;
@(posedge clk);                     // the glitch
#(DRIVE_OFFSET_NS) flag_in = 1'b1;
repeat (12) @(posedge clk);


finish_run("normal end");


end

endmodule

`default_nettype wire

