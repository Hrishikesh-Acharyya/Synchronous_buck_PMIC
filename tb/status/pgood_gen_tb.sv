/*

# Filename:         pgood_gen_tb.sv

# File Description: Directed testbench for pgood_gen. Carries stimulus only -
#                   every claim lives as a property in pgood_gen_sva.sv, bound
#                   to the DUT. No sub-cycle claims and no reference model, so
#                   there are no procedural checks and checks_run is
#                   legitimately zero.
#
#                   PGOOD_DELAY_CYCLES is overridden to QUAL_CYCLES_TB against
#                   the package's 4500, so a boundary case costs five
#                   switching cycles rather than a quarter of a second of
#                   simulated time. The counting logic is parameter-
#                   independent, so a proof at 5 generalises. The bind passes
#                   the same override to the checker, which is why its
#                   comparisons track the DUT rather than the package value.
#
#                   The counter advances on switching-cycle boundaries, not on
#                   clocks, so stimulus is driven through drive_cycle() rather
#                   than by counting clock edges. Group 7 holds pwm_sync
#                   static with both live conditions high: that is the
#                   scenario catching a counter that ticked per clock, which
#                   would qualify the rail roughly a hundred times too fast
#                   and which no other group here would notice.
#
#
#                   Writing the claim list for this module found an RTL
#                   defect: both comparisons in pgood_gen were against
#                   2**PGOOD_DELAY_W - 1 rather than the qualifying cycle
#                   count, so the counter ran to the top of its range and the
#                   realised delay was roughly 1.8x the intended 9 ms. Fixed
#                   before any property was written.

# Global variables: checks_run, checks_failed - declared for the template's
#                   verdict block; no check() calls exist on this module.

*/

`timescale 1ns/1ps
`default_nettype none

module pgood_gen_tb;

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
localparam string   TB_NAME         = "pgood_gen_tb";
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
// QUAL_CYCLES_TB: qualifying period for the DUT under test, far below the
//                 package's PGOOD_DELAY_CYCLES
localparam int QUAL_CYCLES_TB = 5;
logic pwm_sync   = 1'b0;
logic pgood_comp = 1'b0;
logic run_active = 1'b0;
// PGOOD: driven by the DUT and not read here - the properties read it inside
//        pgood_gen's own scope through the bind.
/* verilator lint_off UNUSEDSIGNAL */
logic PGOOD;
/* verilator lint_on UNUSEDSIGNAL */


int unsigned checks_run    = 0;
int unsigned checks_failed = 0;


// ============================================================
// DUT
// ============================================================


pgood_gen #(.PGOOD_DELAY_CYCLES(QUAL_CYCLES_TB)) dut (
    .clk(clk), .rst_n(rst_n), .pwm_sync(pwm_sync),
    .pgood_comp(pgood_comp), .run_active(run_active), .PGOOD(PGOOD));


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
        $dumpvars(0, pgood_gen_tb);
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


// drive_cycle: one pwm_sync switching cycle. The DUT counts falling edges, so
//              the high and low widths are arbitrary - only the edge matters.
task automatic drive_cycle();
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b1;
    repeat (3) @(posedge clk);
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b0;
    repeat (3) @(posedge clk);
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

initial begin
    $display("\n==== %s ====\n", TB_NAME);

    /*
    Group 1: reset.
    ---
    PGOOD is combinational on qualify_counter, which reset clears, so it goes
    low through the output expression rather than through a reset branch of
    its own. Exercises a_rst_n_mean_pgood_low.
    */

    do_reset();

    /*
    Group 2: qualify, one cycle short.
    ---
    Rail good and supervisor regulating, but only QUAL_CYCLES_TB-1 switching
    cycles. PGOOD must still be low: the counter has not reached the target.
    This is the N-1 boundary, where an off-by-one in the comparison lives.
    */

    #(DRIVE_OFFSET_NS) pgood_comp = 1'b1;
    #(DRIVE_OFFSET_NS) run_active = 1'b1;
    repeat (QUAL_CYCLES_TB - 1) drive_cycle();

    /*
    Group 3: the qualifying cycle.
    ---
    One more switching cycle and the counter reaches the target, so PGOOD
    asserts. Together with group 2 this pins the delay exactly - neither
    alone does. Lights c_pgood_assertion, which is what proves the module
    ever asserts at all.
    */

    drive_cycle();
    repeat (4) @(posedge clk);

    /*
    Group 4: immediate deassert on a rail dip.
    ---
    PGOOD is asserted and the comparator drops. The output must follow on the
    same edge, with no clock of latency - the secondary circuitry has to be
    handed back to the input LDO before the rail collapses. Exercises
    a_pgood_drops_immediately and, on the next edge, a_qualify_counter_resets.
    */
    
    #(DRIVE_OFFSET_NS) pgood_comp = 1'b0;
    repeat (4) @(posedge clk);

    /*
    Group 5: re-qualification starts from zero.
    ---
    The rail recovers and runs the full count again. If the counter had
    merely paused rather than cleared, PGOOD would return far too early and
    a_pgood_assertion would fire. Also confirms the counter saturates: the
    extra cycles past the target must not move it.
    */

    #(DRIVE_OFFSET_NS) pgood_comp = 1'b1;
    repeat (QUAL_CYCLES_TB + 3) drive_cycle();

    /*
    Group 6: immediate deassert on leaving S_RUN.
    ---
    The other live condition, with the rail still good. run_active and
    pgood_comp are independent terms in the output expression and in the
    counter's clear condition, so both paths need exercising - a DUT that
    only watched the comparator would pass group 4 and fail here.
    */

    #(DRIVE_OFFSET_NS) run_active = 1'b0;
    repeat (4) @(posedge clk);

    /*
    Group 7: good rail, static pwm_sync.
    ---
    Both live conditions high but no switching-cycle boundaries, so the
    counter must not advance and PGOOD must stay low. This is the scenario
    that catches a counter ticking per clock instead of per cycle - the
    failure that would make the delay two orders of magnitude short and that
    no other group here would notice.
    */

    #(DRIVE_OFFSET_NS) run_active = 1'b1;
    repeat (QUAL_CYCLES_TB * 6) @(posedge clk);

    /*
    Group 8: re-qualify after the static stretch.
    ---
    Confirms the counter was genuinely held rather than stalled - it must
    still reach the target on real switching cycles.
    */

    repeat (QUAL_CYCLES_TB + 1) drive_cycle();

    finish_run("normal end");
end

endmodule

`default_nettype wire

