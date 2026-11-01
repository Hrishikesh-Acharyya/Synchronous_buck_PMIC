/*

# Filename:         hiccup_timer_tb.sv

# File Description: Directed testbench for hiccup_timer. Carries stimulus, plus
#                   one procedural check of the release delay as the testbench
#                   itself measures it - interval + 1 clocks, the fixed offset
#                   every timing claim in hiccup_timer_sva.sv is written
#                   against - so the offset is pinned from outside the
#                   checker's own counter as well. Every other claim lives as a
#                   property in hiccup_timer_sva.sv, bound to both DUTs.
#
#                   Two instances:
#                     dut      TIMER_W = 6 - the cool-down counter overridden
#                              down, so an interval of 2**6 - 1 = 63 clocks
#                              sits at the top of its range, where a counter
#                              that stepped past the target would wrap.
#                     dut_pkg  package values - the scaling smoke test, run
#                              once at a real one-millisecond base.
#                   base_clks is an input, so it needs no override: it is
#                   driven small directly, separately for each instance, and
#                   changed only while hiccup_active is low, as reg_file only
#                   accepts it in S_OFF.
#
#                   strike_level is driven the way strike_counter drives it:
#                   the new level lands on the clock after hiccup_active
#                   rises, and nowhere else inside S_HICCUP (an input contract
#                   in the checker). The module counts clocks, not switching
#                   cycles - the power stage is off in S_HICCUP - so there is
#                   no PWM here.

# Global variables: checks_run, checks_failed - mutated by check() from the
#                   release-delay groups, shared mutable state within the file.

*/

`timescale 1ns/1ps
`default_nettype none

module hiccup_timer_tb;

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
localparam string   TB_NAME         = "hiccup_timer_tb";
// CLK_PERIOD_NS: supervisor clock period, derived from the package rather
//                than hardcoded, so retuning CLK_HZ moves every testbench
//                with it. Real division: integer arithmetic truncates for
//                any CLK_HZ that does not divide 1e9 exactly.
localparam realtime CLK_PERIOD_NS   = 1.0e9 / real'(CLK_HZ);
// WATCHDOG_NS: hard stop so a stalled run fails instead of hanging CI. The
//              longest stretch is group 12, a 2 ms cool-down: twice
//              HICCUP_BASE_MIN_CLKS, 100 000 clocks at 50 MHz. Everything else
//              is under 1 000 clocks, so 2.5 x HICCUP_BASE_MIN_CLKS covers the
//              run at any CLK_HZ without hiding a hang.
localparam realtime WATCHDOG_NS     = 2.5 * real'(HICCUP_BASE_MIN_CLKS) * 2.0 * CLK_PERIOD_NS;
// RESET_CLKS: clocks reset is held in do_reset()
localparam int      RESET_CLKS      = 3;
localparam realtime DRIVE_OFFSET_NS = 3.0;
// SETTLE_NS: delay after a mid-cycle reset before a procedural check reads
//            an output. Small enough to stay inside the clock period, so the
//            check observes the asynchronous clear and not the next edge.
localparam realtime SETTLE_NS       = 0.1;

// TIMER_W_TB: cool-down counter width of the small instance; its longest
//             interval is 63 clocks
localparam int TIMER_W_TB = 6;
// BASE_TB: base interval of the small instance, small enough that 5 << 3 =
//          40 still fits its counter at every strike level
localparam int BASE_TB    = 5;

// Asynchronous inputs are initialised to their INACTIVE level at
// declaration. An uninitialised logic driven straight to its active level
// transitions x -> 0, which is not a reliable negedge, so an async clear
// in the DUT never fires and the flops sit at x until the first clock edge.
logic clk;
logic rst_n         = 1'b1;
logic hiccup_active = 1'b0;
logic [STRIKE_W-1:0]      strike_level = '0;
// base_small: the small instance's base_clks
logic [HICCUP_BASE_W-1:0] base_small   = HICCUP_BASE_W'(BASE_TB);
// base_pkg: the package instance's base_clks, at reg_file's reset default
logic [HICCUP_BASE_W-1:0] base_pkg     = HICCUP_BASE_W'(HICCUP_BASE_DEFAULT_CLKS);

// hiccup_done / hiccup_done_pkg: read by the release-delay checks
logic hiccup_done;
logic hiccup_done_pkg;


int unsigned checks_run    = 0;
int unsigned checks_failed = 0;


// ============================================================
// DUTs
// ============================================================

hiccup_timer #(.TIMER_W(TIMER_W_TB)) dut (
    .clk(clk), .rst_n(rst_n), .hiccup_active(hiccup_active),
    .strike_level(strike_level), .base_clks(base_small),
    .hiccup_done(hiccup_done));

hiccup_timer dut_pkg (
    .clk(clk), .rst_n(rst_n), .hiccup_active(hiccup_active),
    .strike_level(strike_level), .base_clks(base_pkg),
    .hiccup_done(hiccup_done_pkg));


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
        $dumpvars(0, hiccup_timer_tb);
    end
end


// check: procedural comparison, for claims no clocked property can see -
//        here, the release delay measured from the testbench's side.
task automatic check(input bit condition, input string label);
    checks_run++;
    if (!condition) begin
        checks_failed++;
        $display("[%0t] CHECK FAIL: %s", $time, label);
    end
endtask


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


// enter_hiccup: raises hiccup_active, then lands the strike for this hiccup
//               one clock later, as strike_counter does. Returns at the edge
//               after the strike landed, so the caller has used two clocks of
//               the cool-down.
task automatic enter_hiccup(input logic [STRIKE_W-1:0] level);

    @(posedge clk);
    #(DRIVE_OFFSET_NS) hiccup_active = 1'b1;
    @(posedge clk);
    #(DRIVE_OFFSET_NS) strike_level  = level;
    @(posedge clk);

endtask

// leave_hiccup: the supervisor leaves S_HICCUP (to S_SS, or to S_OFF on a fault)
task automatic leave_hiccup();

    @(posedge clk);
    #(DRIVE_OFFSET_NS) hiccup_active = 1'b0;
    repeat (2) @(posedge clk);

endtask

// clear_strikes: strike_level back to 0 while not in S_HICCUP, as
//                strike_counter's clean-run clear does - the only way the level
//                goes down
task automatic clear_strikes();

    @(posedge clk);
    #(DRIVE_OFFSET_NS) strike_level = '0;
    @(posedge clk);

endtask

// set_bases: new base intervals, applied only while hiccup_active is low -
//            reg_file accepts base_clks in S_OFF only
task automatic set_bases(input logic [HICCUP_BASE_W-1:0] small_base,
                         input logic [HICCUP_BASE_W-1:0] pkg_base);

    @(posedge clk);
    #(DRIVE_OFFSET_NS);
    base_small = small_base;
    base_pkg   = pkg_base;
    @(posedge clk);

endtask

// wait_done: clocks until the small instance's hiccup_done, up to max_clocks.
//            Called after enter_hiccup, which has already used two clocks, so
//            a release at interval + 1 clocks returns interval - 1.
task automatic wait_done(input int max_clocks, output int clocks);

    clocks = 0;
    while (!hiccup_done && (clocks < max_clocks)) begin
        @(posedge clk);
        // read after the edge's updates, not in the same instant as them
        #(SETTLE_NS);
        clocks++;

    end

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
    int clocks;

    $display("\n==== %s ====\n", TB_NAME);

    /*
    Group 1: reset.
    ---
    hiccup_done low through reset on both instances. Exercises
    a_reset_done_low and, on release, a_done_cleared_outside.
    */

    do_reset();

    /*
    Group 2: strike level 0, one clock short.
    ---
    A 5-clock cool-down (base 5 << 0). enter_hiccup returns after two
    clocks of it; three more make five clocks in S_HICCUP, where the
    counter has only just reached its target, so hiccup_done must still be
    low - the registered output shows a clock later. The N side of the
    timing; a_done_not_early fires on a release here.
    */

    enter_hiccup(2'd0);
    repeat (3) @(posedge clk);
    #(SETTLE_NS);
    check(!hiccup_done, "hiccup_done low after 5 clocks of a 5-clock cool-down");

    /*
    Group 3: the release.
    ---
    One more clock and hiccup_done is high: interval + 1 clocks after
    hiccup_active, measured here from outside the checker. With group 2 this
    pins the release to one clock. Exercises a_done_on_time and lights
    c_done_rises_level0.
    */

    @(posedge clk);
    #(SETTLE_NS);
    check(hiccup_done, "hiccup_done high 6 clocks into a 5-clock cool-down");

    /*
    Group 4: the supervisor is slow to leave.
    ---
    Six more clocks in S_HICCUP: hiccup_done stays high and the counter
    does not re-arm. Exercises a_done_held.
    */

    repeat (6) @(posedge clk);

    /*
    Group 5: leaving S_HICCUP.
    ---
    hiccup_done clears on the edge after hiccup_active falls. Exercises
    a_done_cleared_outside.
    */

    leave_hiccup();

    /*
    Group 6: escalation, strike levels 1 to 3.
    ---
    Each hiccup lands one more strike on its second clock, and the interval
    doubles: 10, 20 and 40 clocks. Every release is pinned by groups 3 and 4
    of the checker against an interval it computes itself, so a DUT that
    read the target before the strike landed, or shifted by the wrong
    amount, fails here. Lights c_done_rises_level1 to level3.
    */

    enter_hiccup(2'd1);
    wait_done(100, clocks);
    check(clocks == (BASE_TB << 1) - 1, $sformatf("strike 1 released %0d clocks after entry+2, expected %0d", clocks, (BASE_TB << 1) - 1));
    leave_hiccup();
    enter_hiccup(2'd2);
    wait_done(100, clocks);
    check(clocks == (BASE_TB << 2) - 1, $sformatf("strike 2 released %0d clocks after entry+2, expected %0d", clocks, (BASE_TB << 2) - 1));
    leave_hiccup();
    enter_hiccup(2'd3);
    wait_done(100, clocks);
    check(clocks == (BASE_TB << 3) - 1, $sformatf("strike 3 released %0d clocks after entry+2, expected %0d", clocks, (BASE_TB << 3) - 1));

    /*
    Group 7: back into S_HICCUP one clock after leaving.
    ---
    hiccup_active low for a single clock, then high again, with the strike
    level unchanged. The cool-down must start again from zero - the case a
    stale hiccup_done would skip. Lights c_quick_reentry.
    */

    @(posedge clk);
    #(DRIVE_OFFSET_NS) hiccup_active = 1'b0;
    @(posedge clk);
    #(DRIVE_OFFSET_NS) hiccup_active = 1'b1;
    repeat (2) @(posedge clk);
    #(SETTLE_NS);
    check(!hiccup_done, "no immediate release on a quick re-entry");
    wait_done(100, clocks);
    leave_hiccup();

    /*
    Group 8: S_HICCUP left before the cool-down ends.
    ---
    A fault forces S_OFF five clocks into a 10-clock cool-down. The next
    entry must count the full interval from zero, not resume. Lights
    c_left_before_done.
    */

    enter_hiccup(2'd1);
    repeat (3) @(posedge clk);
    leave_hiccup();
    enter_hiccup(2'd1);
    wait_done(100, clocks);
    leave_hiccup();

    /*
    Group 9: reset mid cool-down.
    ---
    Reset while counting. hiccup_done must stay low through it, and with
    hiccup_active still high afterwards the cool-down restarts from zero.
    Lights c_reset_mid_cooldown.
    */

    enter_hiccup(2'd1);
    repeat (4) @(posedge clk);
    do_reset();
    wait_done(100, clocks);
    leave_hiccup();

    /*
    Group 10: one clock in S_HICCUP.
    ---
    The degenerate input: hiccup_active high for one clock. Nothing must
    release. Lights c_one_clock_hiccup.
    */

    @(posedge clk);
    #(DRIVE_OFFSET_NS) hiccup_active = 1'b1;
    @(posedge clk);
    #(DRIVE_OFFSET_NS) hiccup_active = 1'b0;
    repeat (4) @(posedge clk);

    /*
    Group 11: the longest interval the small counter holds.
    ---
    Base 63 at strike level 0 - 2**TIMER_W - 1 clocks. The counter must stop
    at the target rather than step past it and wrap to zero. The strikes are
    cleared first, as a clean run would: entering with the old level 1 would
    put a 126-clock interval in force for a clock, which the small counter
    cannot hold (a_contract_interval_fits). Lights c_interval_at_top.
    */

    clear_strikes();
    set_bases(HICCUP_BASE_W'(63), HICCUP_BASE_W'(HICCUP_BASE_DEFAULT_CLKS));
    enter_hiccup(2'd0);
    wait_done(100, clocks);
    check(clocks == 63 - 1, $sformatf("63-clock cool-down released %0d clocks after entry+2, expected 62", clocks));
    repeat (4) @(posedge clk);
    leave_hiccup();

    /*
    Group 12: scaling smoke test at package parameters.
    ---
    dut_pkg at a real one-millisecond base and strike level 1: a 2 ms
    cool-down, every clock counted by its own bound checker. The small
    instance runs alongside at base 5 so its interval still fits.
    */

    set_bases(HICCUP_BASE_W'(BASE_TB), HICCUP_BASE_W'(HICCUP_BASE_MIN_CLKS));
    enter_hiccup(2'd1);
    while (!hiccup_done_pkg) @(posedge clk);
    #(SETTLE_NS);
    check(hiccup_done_pkg, "package instance released after a 2 ms cool-down");
    leave_hiccup();

    finish_run("normal end");
    
end

endmodule

`default_nettype wire
