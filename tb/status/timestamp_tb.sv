/*

# Filename:         timestamp_tb.sv

# File Description: Directed testbench for timestamp. Carries stimulus only -
#                   every claim lives as a property in timestamp_sva.sv, bound
#                   to the DUT. No sub-cycle claims and no reference model, so
#                   there are no procedural checks and checks_run is
#                   legitimately zero.
#
#                   There is almost no stimulus to write. The module has no
#                   inputs beyond clk and rst_n, so every claim is an
#                   invariant that fires on its own once the clock runs. The
#                   groups below exist to reach particular COUNTS rather than
#                   particular input conditions: enough ticks to see several
#                   prescaler wraps, then enough to carry timestamp_ms through
#                   its own wrap, then a mid-count reset.
#
#                   Both scaling constants are overridden far below the
#                   package values. At PRESCALE_VAL = 50,000 one tick costs a
#                   millisecond of simulated time and the counter wrap costs
#                   4.66 hours, so neither is reachable. Five clocks per tick
#                   and a four-bit counter put a full wrap at eighty clocks
#                   and the whole run inside a few microseconds. The counting
#                   logic is parameter-independent, so a proof at five
#                   generalises.

# Global variables: checks_run, checks_failed - declared for the template's
#                   verdict block; no check() calls exist on this module.

*/

`timescale 1ns/1ps
`default_nettype none

module timestamp_tb;

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
localparam string   TB_NAME         = "timestamp_tb";
// CLK_PERIOD_NS: supervisor clock period, derived from the package rather
//                than hardcoded, so retuning CLK_HZ moves every testbench
//                with it. Real division: integer arithmetic truncates for
//                any CLK_HZ that does not divide 1e9 exactly.
localparam realtime CLK_PERIOD_NS   = 1.0e9 / real'(CLK_HZ);
// WATCHDOG_NS: hard stop so a stalled run fails instead of hanging CI. Sized
//              well above the ~4 us the groups below need.
localparam realtime WATCHDOG_NS     = 20_000.0;
// RESET_CLKS: clocks reset is held in do_reset()
localparam int      RESET_CLKS      = 3;

// PRESCALE_VAL_TB: clocks per tick under test, against the package's 50,000
localparam int      PRESCALE_VAL_TB = 5;
// TIMESTAMP_W_TB:  counter width under test, against the package's 24. Four
//                  bits puts a full wrap at 16 ticks, or 80 clocks.
localparam int      TIMESTAMP_W_TB  = 4;
// TICK_CLKS:       clocks per tick, for sizing the groups below
localparam int      TICK_CLKS       = PRESCALE_VAL_TB;
// WRAP_TICKS:      ticks per timestamp_ms wrap
localparam int      WRAP_TICKS      = 2 ** TIMESTAMP_W_TB;

logic clk;
logic rst_n = 1'b1;

// timestamp_ms: driven by the DUT and not read in this scope - the properties
//               read it inside timestamp's own scope through the bind. The net
//               exists so the counter is traceable in the waveform.
/* verilator lint_off UNUSEDSIGNAL */
logic [TIMESTAMP_W_TB-1:0] timestamp_ms;
/* verilator lint_on UNUSEDSIGNAL */

int unsigned checks_run    = 0;
int unsigned checks_failed = 0;


// ============================================================
// DUT
// ============================================================

timestamp #(
    .PRESCALE_VAL(PRESCALE_VAL_TB),
    .TIMESTAMP_W (TIMESTAMP_W_TB)
) u_dut (
    .clk         (clk),
    .rst_n       (rst_n),
    .timestamp_ms(timestamp_ms)
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
        $dumpvars(0, timestamp_tb);
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
Runs the clock long enough to reach the counts each group is about. No
checks: the bound checker evaluates on every edge regardless, and this
module has no inputs to drive.
*/
initial begin

    $display("\n==== %s ====\n", TB_NAME);

    /*
    Group 1: reset.
    ---
    do_reset drives rst_n high before asserting it, so the fall is a genuine
    negedge and the async clear reaches both counters before any clock edge.
    Exercises a_counters_zero_in_reset.
    */
    do_reset();

    /*
    Group 2: several prescaler periods.
    ---
    Four ticks, so the prescaler runs through its full range and wraps four
    times. This is where groups 2 to 5 of the checker do their work: the
    range bound, the increment, the wrap, and timestamp_ms advancing once per
    wrap and holding on every other clock.
    */
    repeat (4 * TICK_CLKS) @(posedge clk);

    /*
    Group 3: carry timestamp_ms through its own wrap.
    ---
    A full WRAP_TICKS of ticks plus a few more, so the counter runs from its
    current value past all-ones and back through zero. Lights
    c_timestamp_wraps, which is the only evidence claim 7 was reached -
    at the package's 24 bits this would take 4.66 hours and the cover would
    read zero forever.

    The increment property is not special-cased for the wrap: the addition is
    unsigned and TIMESTAMP_W wide, so all-ones plus one is zero and group 5
    holds across the boundary like any other tick.
    */
    repeat ((WRAP_TICKS + 3) * TICK_CLKS) @(posedge clk);

    /*
    Group 4: reset part-way through a prescaler period.
    ---
    Asserted at a point that is deliberately not a tick boundary, so both
    counters are mid-count when the clear arrives. Confirms the asynchronous
    clear reaches the prescaler as well as timestamp_ms - a prescaler that
    survived reset would put the first tick after release at the wrong
    interval, and nothing downstream would ever notice a single short
    millisecond.
    */
    repeat (TICK_CLKS / 2) @(posedge clk);
    do_reset();

    /*
    Group 5: counting resumes from zero after the reset.
    ---
    Two more ticks, so the properties see the counters restart rather than
    resume. Without this the run would end in reset and group 4 would have
    proved only that the clear happened, not that the module recovered.
    */
    repeat (2 * TICK_CLKS) @(posedge clk);

    finish_run("normal end");

end

endmodule

`default_nettype wire

