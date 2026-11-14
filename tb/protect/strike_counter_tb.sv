/*

# Filename:         strike_counter_tb.sv

# File Description: Directed testbench for strike_counter. Carries stimulus
#                   only - every claim lives as a property in
#                   strike_counter_sva.sv, bound to both DUTs. No sub-cycle
#                   claims and no computed expected values, so there are no
#                   procedural checks and checks_run is legitimately zero.
#
#                   Two instances:
#                     dut      CLEAN_RUN_W = 4 - the clean-run counter
#                              overridden down, so a clean run is five
#                              switching cycles instead of the package's
#                              450 000.
#                     dut_pkg  package values - the scaling smoke test, run
#                              once over a real 100 ms clean run.
#                   max_strikes and clean_run_target are inputs, so they need
#                   no override: they are driven directly. clean_run_target
#                   changes only outside S_RUN, as reg_file only accepts it in
#                   S_OFF; max_strikes is live and may change at any time.
#
#                   Strikes come from hiccup(): one entry into S_HICCUP, a
#                   few clocks in it, out again. The clean run counts falling
#                   edges of pwm_sync in S_RUN, so it is driven through
#                   drive_cycle(); pulse widths are arbitrary.
#
#                   latch_assert is set-only and cleared by reset alone, so
#                   every group that needs it low again starts with
#                   do_reset().
#
#                   Group 10 builds known_issues A2 on purpose - MAX_STRIKES
#                   lowered below the present count - as a regression test for
#                   its fix: the first hiccup after the write trips the latch.

# Global variables: checks_run, checks_failed - declared for the template's
#                   verdict block; no check() calls exist on this module.

*/

`timescale 1ns/1ps
`default_nettype none

module strike_counter_tb;

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
localparam string   TB_NAME         = "strike_counter_tb";
// CLK_PERIOD_NS: supervisor clock period, derived from the package rather
//                than hardcoded, so retuning CLK_HZ moves every testbench
//                with it. Real division: integer arithmetic truncates for
//                any CLK_HZ that does not divide 1e9 exactly.
localparam realtime CLK_PERIOD_NS   = 1.0e9 / real'(CLK_HZ);
// WATCHDOG_NS: hard stop so a stalled run fails instead of hanging CI. The
//              longest stretch is group 13, CLEAN_RUN_MIN_CYCLES switching
//              cycles of two clocks each - 90 000 clocks; everything else is
//              under 2 000 clocks. Three clocks per clean-run cycle covers it
//              at any clock rate without hiding a hang.
localparam realtime WATCHDOG_NS     = 3.0 * real'(CLEAN_RUN_MIN_CYCLES) * CLK_PERIOD_NS;
// RESET_CLKS: clocks reset is held in do_reset()
localparam int      RESET_CLKS      = 3;
localparam realtime DRIVE_OFFSET_NS = 3.0;

// CLEAN_RUN_W_TB: clean-run counter width of the small instance
localparam int CLEAN_RUN_W_TB = 4;
// CLEAN_TB: clean-run target of the small instance, in switching cycles
localparam int CLEAN_TB       = 5;

// Asynchronous inputs are initialised to their INACTIVE level at
// declaration. An uninitialised logic driven straight to its active level
// transitions x -> 0, which is not a reliable negedge, so an async clear
// in the DUT never fires and the flops sit at x until the first clock edge.
logic clk;
logic rst_n         = 1'b1;
logic pwm_sync      = 1'b0;
logic hiccup_active = 1'b0;
logic run_active    = 1'b0;
logic window_trip   = 1'b0;
// max_strikes: shared by both instances, at the package default
logic [STRIKE_W-1:0]       max_strikes  = STRIKE_W'(MAX_STRIKES_DEFAULT);
// clean_small / clean_pkg: each instance's clean_run_target
logic [CLEAN_RUN_W_TB-1:0] clean_small  = CLEAN_RUN_W_TB'(CLEAN_TB);
logic [CLEAN_RUN_W-1:0]    clean_pkg    = CLEAN_RUN_W'(CLEAN_RUN_MIN_CYCLES);

// DUT outputs: not read here - the properties read them through the bind
/* verilator lint_off UNUSEDSIGNAL */
logic [STRIKE_W-1:0] strike_level;
logic                latch_assert;
logic [STRIKE_W-1:0] strike_level_pkg;
logic                latch_assert_pkg;
/* verilator lint_on UNUSEDSIGNAL */


int unsigned checks_run    = 0;
int unsigned checks_failed = 0;


// ============================================================
// DUTs
// ============================================================

strike_counter #(.CLEAN_RUN_W(CLEAN_RUN_W_TB)) dut (
    .clk(clk), .rst_n(rst_n), .pwm_sync(pwm_sync),
    .hiccup_active(hiccup_active), .run_active(run_active),
    .window_trip(window_trip), .max_strikes(max_strikes),
    .clean_run_target(clean_small),
    .strike_level(strike_level), .latch_assert(latch_assert));

strike_counter dut_pkg (
    .clk(clk), .rst_n(rst_n), .pwm_sync(pwm_sync),
    .hiccup_active(hiccup_active), .run_active(run_active),
    .window_trip(window_trip), .max_strikes(max_strikes),
    .clean_run_target(clean_pkg),
    .strike_level(strike_level_pkg), .latch_assert(latch_assert_pkg));


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
        $dumpvars(0, strike_counter_tb);
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


// set_state: the supervisor's two flags, as one state change. Never both high
//            (an input contract the checker asserts).
task automatic set_state(input bit hiccup, input bit run);
    @(posedge clk);
    #(DRIVE_OFFSET_NS);
    hiccup_active = hiccup;
    run_active    = run;
endtask

// hiccup: one strike - into S_HICCUP for three clocks, then out. Only the
//         entry counts; the time spent there is arbitrary.
task automatic hiccup();
    set_state(1'b1, 1'b0);
    repeat (3) @(posedge clk);
    set_state(1'b0, 1'b0);
    @(posedge clk);
endtask

// drive_cycle: one pwm_sync switching cycle. The clean run counts falling
//              edges, so the high and low widths are arbitrary.
task automatic drive_cycle();
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b1;
    @(posedge clk);
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b0;
    @(posedge clk);
endtask

// run_cycles: into S_RUN and n switching cycles there
task automatic run_cycles(input int n);
    set_state(1'b0, 1'b1);
    repeat (n) drive_cycle();
endtask

// set_max: a live MAX_STRIKES write, legal in any state
task automatic set_max(input logic [STRIKE_W-1:0] value);
    @(posedge clk);
    #(DRIVE_OFFSET_NS) max_strikes = value;
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
    Count zero, latch request low. Exercises a_reset_clears.
    */

    do_reset();

    /*
    Group 2: two strikes of three.
    ---
    max_strikes = 3. Two hiccups take the count to 2 - one per entry, not per
    clock of the cool-down - and the latch must stay low: the N-1 side of
    the trip. Exercises a_strike_per_entry and a_latch_earned.
    */

    repeat (2) hiccup();

    /*
    Group 3: the third strike.
    ---
    The entry that brings the count to 3 trips the latch on that edge. With
    group 2 this pins the trip to exactly the MAX_STRIKES-th hiccup. Two more
    hiccups follow and the latch stays high; the count goes on to 3 and wraps
    to 0 but is never cleared by the latch. Exercises a_last_strike_trips,
    a_latch_held and lights c_latch_at_max3.
    */

    hiccup();
    repeat (2) hiccup();

    /*
    Group 4: MAX_STRIKES at 1 and 2.
    ---
    The other two legal limits: at 1 the first hiccup trips the latch, at 2
    the second. With group 3 the comparison is pinned at every value the
    2-bit bus can hold. Lights c_latch_at_max1 and c_latch_at_max2.
    */

    do_reset();
    set_max(2'd1);
    hiccup();
    do_reset();
    set_max(2'd2);
    hiccup();
    hiccup();

    /*
    Group 5: a clean run, one cycle short.
    ---
    max_strikes back to 3, two strikes, then four fault-free switching cycles
    in S_RUN against a target of five. The count must still read 2. The N-1
    side of the forgiveness; a_clear_earned fires on an early clear.
    */

    do_reset();
    set_max(2'd3);
    repeat (2) hiccup();
    run_cycles(CLEAN_TB - 1);

    /*
    Group 6: the completing cycle.
    ---
    The fifth cycle completes the clean run and the count clears. With group
    5 this pins the clean run to exactly clean_run_target cycles. A few more
    cycles show the clear holds once the streak is saturated. Exercises
    a_clean_run_clears and lights c_level_cleared.
    */

    repeat (3) drive_cycle();
    set_state(1'b0, 1'b0);

    /*
    Group 7: a window_trip breaks the streak.
    ---
    One strike, three clean cycles, a one-clock window_trip, three more: six
    cycles in S_RUN but no streak of five, so no clear. Two more cycles make
    five in a row and the count clears. Lights c_streak_broken_by_trip.
    */

    hiccup();
    run_cycles(3);
    #(DRIVE_OFFSET_NS) window_trip = 1'b1;
    @(posedge clk);
    #(DRIVE_OFFSET_NS) window_trip = 1'b0;
    repeat (3) drive_cycle();
    repeat (2) drive_cycle();
    set_state(1'b0, 1'b0);

    /*
    Group 8: leaving S_RUN breaks the streak.
    ---
    One strike, three clean cycles, two clocks out of S_RUN, three more: no
    streak of five, no clear - time out of S_RUN is not running, and a
    streak that survived it would forgive what the next hiccup earned. Two
    more cycles complete it. Lights c_streak_broken_by_exit.
    */

    hiccup();
    run_cycles(3);
    set_state(1'b0, 1'b0);
    @(posedge clk);
    run_cycles(3);
    repeat (2) drive_cycle();
    set_state(1'b0, 1'b0);

    /*
    Group 9: a hiccup on the edge a clean run completes.
    ---
    One strike, then a clean run whose fifth fall is followed at once by
    S_RUN to S_HICCUP, so the entry and the completed streak meet on one
    edge. The entry must win: the count goes up, not to zero. Lights
    c_entry_beats_clear.
    */

    hiccup();
    run_cycles(CLEAN_TB - 1);
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b1;
    @(posedge clk);
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b0;
    @(posedge clk);
    #(DRIVE_OFFSET_NS);
    run_active    = 1'b0;
    hiccup_active = 1'b1;
    repeat (3) @(posedge clk);
    set_state(1'b0, 1'b0);
    @(posedge clk);

    /*
    Group 10: MAX_STRIKES lowered below the count (known_issues A2).
    ---
    Two strikes of three, then the host writes MAX_STRIKES = 1. The next
    entry finds the count already past the limit and must trip the latch at
    once - before the fix, the RTL's == test missed it, the count wrapped and
    the latch came three hiccups late. Two more hiccups follow with the latch
    held. Exercises a_last_strike_trips and a_latch_earned; lights
    c_strikes_above_max.
    */

    do_reset();
    repeat (2) hiccup();
    set_max(2'd1);
    repeat (3) hiccup();
    set_max(2'd3);

    /*
    Group 11: no switching cycles in S_RUN.
    ---
    One strike, then S_RUN with pwm_sync held low and then stuck high for
    twenty clocks each: no falling edge, so no clean-run progress and no
    clear. Releasing it gives one cycle, not a completed run. The degenerate
    input; lights c_static_pwm_in_run.
    */

    do_reset();
    hiccup();
    set_state(1'b0, 1'b1);
    repeat (20) @(posedge clk);
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b1;
    repeat (20) @(posedge clk);
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b0;
    repeat (2) @(posedge clk);

    /*
    Group 12: reset part-way through a clean run.
    ---
    Three clean cycles, then reset with run_active still high. The count is
    zero from reset; afterwards the streak starts again from nothing. Lights
    c_reset_mid_streak.
    */

    repeat (3) drive_cycle();
    do_reset();
    repeat (2) drive_cycle();
    set_state(1'b0, 1'b0);

    /*
    Group 13: scaling smoke test at package parameters.
    ---
    One strike, then a clean run of CLEAN_RUN_MIN_CYCLES - 100 ms of
    switching cycles - for dut_pkg, every cycle counted by its own bound
    checker, ending in the clear.
    */

    hiccup();
    run_cycles(CLEAN_RUN_MIN_CYCLES + 2);
    set_state(1'b0, 1'b0);
    repeat (2) @(posedge clk);

    finish_run("normal end");
end

endmodule

`default_nettype wire
