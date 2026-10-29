/*

# Filename:         fault_LED_tb.sv

# File Description: Directed testbench for fault_LED. Carries stimulus only -
#                   every claim lives as a property in fault_LED_sva.sv, bound
#                   to the DUT. No sub-cycle claims and no reference model, so
#                   there are no procedural checks and checks_run is
#                   legitimately zero.
#
#                   LED_BLINK_HALF_CLKS is overridden to four clocks against
#                   the package-derived 6.25 M. At the real value one blink
#                   edge is 125 ms of simulated time, so neither the toggle
#                   nor the counter wrap is reachable in a testbench. The
#                   timebase logic is parameter-independent, so a proof at
#                   four generalises.
#
#                   The groups walk the Red_LED1 priority chain in both
#                   directions - clean, then strikes, then a latch on top of
#                   the strikes, then back - because the priority is the
#                   module's one real decision and an inversion only shows
#                   when both conditions are live at once.

# Global variables: checks_run, checks_failed - declared for the template's
#                   verdict block; no check() calls exist on this module.

*/

`timescale 1ns/1ps
`default_nettype none

module fault_LED_tb;

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
localparam string   TB_NAME         = "fault_LED_tb";
// CLK_PERIOD_NS: supervisor clock period, derived from the package rather
//                than hardcoded, so retuning CLK_HZ moves every testbench
//                with it. Real division: integer arithmetic truncates for
//                any CLK_HZ that does not divide 1e9 exactly.
localparam realtime CLK_PERIOD_NS   = 1.0e9 / real'(CLK_HZ);
// WATCHDOG_NS: hard stop so a stalled run fails instead of hanging CI.
localparam realtime WATCHDOG_NS     = 20_000.0;
// RESET_CLKS: clocks reset is held in do_reset()
localparam int      RESET_CLKS      = 3;
// DRIVE_OFFSET_NS: how far past a clock edge stimulus is applied. Must be
//                  non-zero: @(posedge clk) resumes AT the edge, so an
//                  assignment on the next line lands in the same timestep and
//                  the DUT and the properties disagree about which side of
//                  the edge the change fell on.
localparam realtime DRIVE_OFFSET_NS = 3.0;

// BLINK_HALF_TB: half the blink period under test, against the package-derived
//                6.25 M. Four clocks puts a full blink period at eight.
localparam int      BLINK_HALF_TB   = 4;

logic clk;
logic rst_n        = 1'b1;
logic otp_state    = 1'b0;
logic uvlo_state   = 1'b0;
logic latch_state  = 1'b0;
logic latch_assert = 1'b0;
logic ss_active    = 1'b0;
logic run_active   = 1'b0;
logic pgood        = 1'b0;

logic [STRIKE_W-1:0] strike_level = '0;

// The five indicators are driven by the DUT and not read in this scope - the
// properties read them inside fault_LED's own scope through the bind. The nets
// exist so each is separately traceable in the waveform.
/* verilator lint_off UNUSEDSIGNAL */
logic Green_LED;
logic pgood_LED;
logic Red_LED1;
logic Red_LED2;
logic Red_LED3;
/* verilator lint_on UNUSEDSIGNAL */

int unsigned checks_run    = 0;
int unsigned checks_failed = 0;


// ============================================================
// DUT
// ============================================================

fault_LED #(
    .LED_BLINK_HALF_CLKS(BLINK_HALF_TB)
) u_dut (
    .clk         (clk),
    .rst_n       (rst_n),
    .otp_state   (otp_state),
    .uvlo_state  (uvlo_state),
    .latch_state (latch_state),
    .latch_assert(latch_assert),
    .strike_level(strike_level),
    .ss_active   (ss_active),
    .run_active  (run_active),
    .pgood       (pgood),
    .Green_LED   (Green_LED),
    .pgood_LED   (pgood_LED),
    .Red_LED1    (Red_LED1),
    .Red_LED2    (Red_LED2),
    .Red_LED3    (Red_LED3)
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
        $dumpvars(0, fault_LED_tb);
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
Drives the directed groups in order. No checks: the bound checker evaluates
on every edge regardless, and the groups exist to make its antecedents occur.
*/
initial begin

    $display("\n==== %s ====\n", TB_NAME);

    /*
    Group 1: reset.
    ---
    Exercises a_all_leds_dark_in_reset on all five indicators at once.
    */
    do_reset();

    /*
    Group 2: healthy running.
    ---
    Soft start then run, nothing faulted, rail good. Green and pgood_LED lit,
    all three reds dark. Lights c_green_lit, c_pgood_led_lit and
    c_red1_dark_when_clean - that last one is the branch a permanently lit
    indicator would fail.

    Held for several blink periods so the timebase properties in groups 7 and
    8 have room to wrap repeatedly while nothing is displaying the pattern -
    the counter free-runs whether or not anything is using it.
    */
    #(DRIVE_OFFSET_NS) ss_active = 1'b1;
    repeat (3 * BLINK_HALF_TB) @(posedge clk);
    #(DRIVE_OFFSET_NS) ss_active  = 1'b0;
    #(DRIVE_OFFSET_NS) run_active = 1'b1;
    #(DRIVE_OFFSET_NS) pgood      = 1'b1;
    repeat (3 * BLINK_HALF_TB) @(posedge clk);

    /*
    Group 3: over-temperature, then input undervoltage, then both.
    ---
    The two comparator indicators are independent rather than chained, so the
    overlap matters: a design that chained them would show only one while both
    conditions were live. Green must go dark on either, since fault_live is a
    plain OR.
    */
    #(DRIVE_OFFSET_NS) otp_state = 1'b1;
    repeat (4) @(posedge clk);
    #(DRIVE_OFFSET_NS) uvlo_state = 1'b1;
    repeat (4) @(posedge clk);
    #(DRIVE_OFFSET_NS) otp_state = 1'b0;
    repeat (4) @(posedge clk);
    #(DRIVE_OFFSET_NS) uvlo_state = 1'b0;
    repeat (4) @(posedge clk);

    /*
    Group 4: strikes outstanding, no latch.
    ---
    Red_LED1 must carry the blink pattern exactly. Held for several full
    periods so the indicator is seen both high and low and the square wave is
    checked rather than a single transition. Lights c_red1_blinks_on_strikes
    along with c_blink_high and c_blink_low.
    */
    #(DRIVE_OFFSET_NS) strike_level = STRIKE_W'(1);
    repeat (6 * BLINK_HALF_TB) @(posedge clk);

    /*
    Group 5: the priority case - a latch on top of outstanding strikes.
    ---
    The only scenario that distinguishes the chain from a two-branch decode.
    With both conditions live Red_LED1 must be solid, and must stay solid
    across at least one full blink period: a priority inversion would show as
    the indicator dropping when blink does. Lights c_red1_solid_on_latch.

    Both latch paths are driven in turn - the SCR readback and the CPLD's own
    trip - because either alone means terminal and the DUT ORs them.
    */
    #(DRIVE_OFFSET_NS) latch_assert = 1'b1;
    repeat (3 * BLINK_HALF_TB) @(posedge clk);
    #(DRIVE_OFFSET_NS) latch_assert = 1'b0;
    #(DRIVE_OFFSET_NS) latch_state  = 1'b1;
    repeat (3 * BLINK_HALF_TB) @(posedge clk);

    /*
    Group 6: back down the chain.
    ---
    Latch clears with strikes still outstanding, so the indicator must return
    to blinking rather than going dark - the recovering-board case. Then the
    strikes clear and it goes dark. Walking the chain downward catches a
    design that latched its own display state on the way up.
    */
    #(DRIVE_OFFSET_NS) latch_state = 1'b0;
    repeat (4 * BLINK_HALF_TB) @(posedge clk);
    #(DRIVE_OFFSET_NS) strike_level = '0;
    repeat (2 * BLINK_HALF_TB) @(posedge clk);

    /*
    Group 7: reset part-way through a blink period.
    ---
    Asserted at a point deliberately not on a wrap boundary, so the counter is
    mid-count when the clear arrives. Confirms the asynchronous clear reaches
    the timebase as well as the indicators - a counter that survived reset
    would make the first blink after release a partial one.
    */
    repeat (BLINK_HALF_TB / 2) @(posedge clk);
    do_reset();
    repeat (2 * BLINK_HALF_TB) @(posedge clk);

    finish_run("normal end");

end

endmodule

`default_nettype wire

