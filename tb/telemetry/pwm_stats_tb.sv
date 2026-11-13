/*

# Filename:         pwm_stats_tb.sv

# File Description: Directed testbench for pwm_stats. Carries stimulus only -
#                   every claim lives as a property in pwm_stats_sva.sv, bound
#                   to the DUT. No sub-cycle claims and no reference model, so
#                   there are no procedural checks and checks_run is
#                   legitimately zero.
#
#                   CNT_W is overridden down to six bits, so an input stuck
#                   high reaches the counter's all-ones in a few tens of
#                   clocks. The stimulus drives whole switching cycles of
#                   chosen high and low lengths: steady periods, duty changes
#                   at a fixed period, period changes at a fixed duty, a
#                   one-clock high phase, an input stuck high, and a reset
#                   part-way through a cycle.

# Global variables: checks_run, checks_failed - the verdict's tallies; nothing
#                   in this file calls check(), so both stay zero.

*/

`timescale 1ns/1ps
`default_nettype none

module pwm_stats_tb;

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
localparam string   TB_NAME         = "pwm_stats_tb";
// CLK_PERIOD_NS: supervisor clock period, derived from the package rather
//                than hardcoded, so retuning CLK_HZ moves every testbench
//                with it. Real division: integer arithmetic truncates for
//                any CLK_HZ that does not divide 1e9 exactly.
localparam realtime CLK_PERIOD_NS   = 1.0e9 / real'(CLK_HZ);
// WATCHDOG_NS: hard stop so a stalled run fails instead of hanging CI.
//              Size it against the longest segment below, not by habit.
localparam realtime WATCHDOG_NS     = 500.0 * CLK_PERIOD_NS;  // 500 clocks: 10 us at 50 MHz, 50 us at 10 MHz
// RESET_CLKS: clocks reset is held in do_reset()
localparam int      RESET_CLKS      = 3;
localparam realtime DRIVE_OFFSET_NS = 3.0;
// SETTLE_NS: delay after a mid-cycle reset before the procedural checks
//            read sync_out. Small enough to stay inside the clock period,
//            so the check observes the asynchronous clear and not the next
//            clock edge.
localparam realtime SETTLE_NS       = 0.1;


// CNT_W_TB: counter width under test, against the package's 8. Six bits puts
//           all-ones at 63, so a stuck-high input reaches the wrap in a few
//           tens of clocks rather than hundreds.
localparam int CNT_W_TB = 6;
logic clk;
logic rst_n    = 1'b1;
logic pwm_sync = 1'b0;

// duty_count / prev_period: driven by the DUT and not read in this scope -
//                           the properties read them inside pwm_stats' own
//                           scope through the bind. The nets exist so both
//                           are traceable in the waveform.
/* verilator lint_off UNUSEDSIGNAL */
logic [CNT_W_TB-1:0] duty_count;
logic [CNT_W_TB-1:0] prev_period;
/* verilator lint_on UNUSEDSIGNAL */


int unsigned checks_run    = 0;
int unsigned checks_failed = 0;


// ============================================================
// DUT
// ============================================================

pwm_stats #(.CNT_W(CNT_W_TB)) u_dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .pwm_sync   (pwm_sync),
    .duty_count (duty_count),
    .prev_period(prev_period)
);


initial begin

    /*
    Purpose:
    ---
    Free-running clock. Generates the clock and nothing else - a second
    initial block assigning any signal this one touches is a race.
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

initial $timeformat(-9, 1, " ns", 10);



initial begin

    /*
    Purpose:
    ---
    Record a VCD only when asked, since the trace costs more than the run on
    a short testbench. Enabled by +WAVES, which the Makefile passes for
    WAVES=1.
    */

    if ($test$plusargs("WAVES")) begin

        $dumpfile({TB_NAME, ".vcd"});
        $dumpvars(0, pwm_stats_tb);

    end

end


task automatic do_reset();

    /*
    Purpose:
    ---
    do_reset: asserts and releases reset with a genuine falling edge, so the
    DUT's async clear fires before any clock arrives. rst_n is
    driven high first for that reason even when already high.
    */

    rst_n = 1'b1;
    #1;
    rst_n = 1'b0;
    repeat (RESET_CLKS) @(posedge clk);
    #(DRIVE_OFFSET_NS);
    rst_n = 1'b1;
    repeat (RESET_CLKS) @(posedge clk);

endtask


task automatic finish_run(input string reason);

    /*
    Purpose:
    ---
    finish_run: single exit point for both the normal end and the watchdog,
    so a timeout reports a verdict instead of dying silently.
    Never $fatal - it exits before the tallies are printed.
    */

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
    if (passed) begin

        $display("%s%s: PASS%s  (check cover hits before trusting this)",
                 ANSI_GREEN, TB_NAME, ANSI_RESET);

    end
    else begin

        $display("%s%s: FAIL%s", ANSI_RED, TB_NAME, ANSI_RESET);

    end
    $display("--------------------------------------------------");
    // tally: one plain key=value line for the run scripts (run_tb.sh reads
    //        it for the summary card; the terminal filter hides it). Keep it
    //        as is - the banner above is for people and may be reworded.
    $display("tally: checks_run=%0d checks_failed=%0d sva_failures=%0d exit=%s",
             checks_run, checks_failed, sva_pkg::sva_failures, reason);
    // $stop on failure: non-zero exit status, so make and CI see the FAIL.
    // Not $fatal - by this point the tallies are already printed.
    if (passed) $finish;
    else        $stop;

endtask


task automatic drive_cycle(input int high_clks, input int low_clks);

    /*
    Purpose:
    ---
    drive_cycle: one switching cycle of the given shape, in clocks. The module
    measures whatever it is given, so the widths here are the test
    rather than a property of the design.
    */

    #(DRIVE_OFFSET_NS) pwm_sync = 1'b1;
    repeat (high_clks) @(posedge clk);
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b0;
    repeat (low_clks) @(posedge clk);

endtask


initial begin

    /*
    Purpose:
    ---
    Bounds the run so a stalled testbench fails rather than hanging the
    simulator. Absolute delay, so it fires even if the clock stops. Counts as
    a failure so the verdict and the exit status both report it.
    */

    #(WATCHDOG_NS);
    checks_failed++;
    finish_run("WATCHDOG - did not complete");

end


// ============================================================
// Stimulus
// ============================================================
initial begin

    /*
    Purpose:
    ---
    Drives the directed segments in order. Most segments carry no checks: the
    bound checker evaluates on every edge regardless, and the segments exist
    to make its antecedents occur. Add check() only where the claim is
    sub-cycle or needs a reference model.
    */

    $display("\n==== %s ====\n", TB_NAME);
    /*
    Group 1: reset.
    ---
    Exercises a_outputs_zero_in_reset on all three.
    */

    do_reset();

    /*
    Group 2: steady periods.
    ---
    Four identical cycles at 8 high and 12 low. The first rise only starts a
    measurement, so prev_period is not meaningful until the second - four
    cycles gives three complete measurements and leaves the capture and hold
    properties in groups 3 and 4 plenty of clocks either side.
    */

    repeat (4) drive_cycle(8, 12);

    /*
    Group 3: duty changes, period constant.
    ---
    Same 20-clock period, high phase down to 4. duty_count must follow while
    prev_period holds - the two are captured on different edges and a design
    that shared a capture would show both moving together.
    */

    repeat (3) drive_cycle(4, 16);

    /*
    Group 4: period changes, duty constant.
    ---
    The reverse: high phase back to 8 with the period down to 16. This is the
    case the module exists for - the analog oscillator drifts, and duty
    referenced to a nominal period would carry the drift into the inferred
    output voltage.
    */
    repeat (3) drive_cycle(8, 8);

    /*
    Group 5: one-clock high phase.
    ---
    The narrowest input that still has a rise and a fall. duty_count reads
    zero here, which is the documented offset at its most visible: a single
    clock of conduction captures as zero.
    */
    repeat (2) drive_cycle(1, 10);

    /*
    Group 6: input stuck high.
    ---
    Held past all-ones on a six-bit counter, so the wrap is reachable.
    a_counter_never_wraps is the only property that sees it, and the symptom
    on a real board would be a captured period reading short - the host would
    conclude the oscillator had doubled in frequency.
    */

    #(DRIVE_OFFSET_NS) pwm_sync = 1'b1;
    repeat (70) @(posedge clk);
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b0;
    repeat (8) @(posedge clk);

    /*
    Group 7: reset part-way through a cycle.
    ---
    Asserted mid-high-phase, so period_counter is mid-count when the clear
    arrives. Then two clean cycles, confirming measurement resumes rather
    than carrying a stale count into the first period after release.
    */
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b1;
    repeat (5) @(posedge clk);
    do_reset();
    repeat (2) drive_cycle(8, 12);


    finish_run("normal end");

end

endmodule

`default_nettype wire

