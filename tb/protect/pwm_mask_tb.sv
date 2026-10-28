/*

# Filename:         pwm_mask.sv
#
# File Description: Directed testbench for pwm_mask. Carries stimulus only -
#                   every claim lives as a property in pwm_mask_sva.sv, bound
#                   to the DUT. No sub-cycle claims and no reference model, so
#                   there are no procedural checks and checks_run is
#                   legitimately zero.
#
#                   max_on_counts is an input port rather than a parameter, so
#                   the ceiling is driven as a signal and no parameter
#                   override is needed. CEILING is set far below
#                   MAX_ON_COUNTS_DEFAULT so a boundary case costs six clocks
#                   rather than hundreds.
#
#                   Pulse widths are driven directly rather than generated
#                   from a PWM period. The module counts clocks while
#                   pwm_sync is high and has no opinion about the switching
#                   frequency, and the interesting cases are exact widths -
#                   CEILING-2, CEILING, CEILING+1 - which a free-running
#                   generator would not land on.

# Global variables: none
*/

`timescale 1ns/1ps
`default_nettype none

module pwm_mask_tb;

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
localparam string   TB_NAME         = "pwm_mask_tb";
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



// pwm_sync is initialised low at declaration so the DUT starts in its low
// phase with run_counter cleared, rather than seeing x on the first edge.
logic clk;
logic rst_n = 1'b1;
// CEILING: on-time ceiling in clk counts, driven onto max_on_counts. In the
//          real design soft_start drives this bus and ramps it during
//          startup; here it is a fixed signal, small enough that the
//          boundary cases are a handful of clocks.
localparam int CEILING = 6;
logic [ON_TIME_W-1:0] max_on_counts = ON_TIME_W'(CEILING);
logic pwm_sync = 1'b0;
// pwm_out: driven by the DUT and not read in this scope - the properties read
//          it inside pwm_mask's own scope through the bind. The net exists so
//          the output is traceable in the waveform.
/* verilator lint_off UNUSEDSIGNAL */
logic pwm_out;
/* verilator lint_on UNUSEDSIGNAL */
int unsigned checks_run    = 0;
int unsigned checks_failed = 0;


//===========================================
//          DUT
//===========================================

pwm_mask dut (.clk(clk), .rst_n (rst_n), .pwm_sync(pwm_sync),
 .max_on_counts(max_on_counts), .pwm_out(pwm_out));

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
        $dumpvars(0, pwm_mask_tb);
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
    $finish;
endtask

// drive_pulse: one pwm_sync pulse of the given width in clocks, followed by
//              low_clks of low phase so the mask re-arms before the next one.
task automatic drive_pulse(input int high_clks, input int low_clks);
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b1;
    repeat (high_clks) @(posedge clk);
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b0;
    repeat (low_clks) @(posedge clk);
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
Drives the directed segments in order. Most segments carry no checks: the
bound checker evaluates on every edge regardless, and the segments exist
to make its antecedents occur. Add check() only where the claim is
sub-cycle or needs a reference model.
*/
initial begin

$display("\n==== %s ====\n", TB_NAME);


/*
 Group 1: reset.
 ---
 do_reset drives rst_n high before asserting it, so the fall is a genuine
 negedge and the async clear reaches the flops before any clock edge.
 Exercises a_pwm_out_low_on_reset.
 */

do_reset();

 /*
 Group 2: short pulse, well under the ceiling.
 ---
 CEILING-2 clocks high, so run_counter never reaches max_on_counts and the
 pulse passes through untouched one clock late. Exercises the lower bound,
 a_short_pulses_pass - without which a DUT whose output never rose would
 satisfy every other property in the checker.
 */

drive_pulse(CEILING-2,4);
    

 /*
Group 3: long pulse, well over the ceiling.
---
CEILING+5 clocks high. The output must drop two edges after run_counter
reaches the ceiling - pulse_allowed is registered from run_counter and
pwm_out from pulse_allowed - and stay down for the rest of the high phase.
Exercises the upper bound and the no-double-pulse property together.
*/

drive_pulse(CEILING + 5, 4);

 /*
Group 4: the boundary, either side.
---
Exactly CEILING, then CEILING+1. This is where an off-by-one in the
comparison lives: a pulse of exactly the ceiling must still be truncated,
one of CEILING-1 must not. Two pulses rather than one because the two
cases take different paths through the comparison.
*/

drive_pulse(CEILING, 4);
drive_pulse(CEILING+1,4);

/*
Group 5: back-to-back long pulses.
---
Two truncated pulses with only three low clocks between them. Confirms
pulse_allowed re-arms on the low phase: if it stayed cleared, the second
pulse would be suppressed entirely and a_short_pulses_pass would fire.
*/

drive_pulse(CEILING + 4,3);
drive_pulse(CEILING + 4,3);

/*
 Group 6: input stuck high.
 ---
 Three times the ceiling in one pulse, checking that run_counter saturates
 rather than wrapping. A wrap would drop the count back below the ceiling,
 re-arm pulse_allowed mid-pulse and hand the gate driver a second turn-on
 inside one switching cycle - the shoot-through hazard the DUT header
 warns about.
 */

drive_pulse (3*CEILING, 4);


finish_run("normal end");


end

endmodule
`default_nettype wire

