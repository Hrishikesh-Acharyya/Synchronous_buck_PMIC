/*

# Filename:         fault_arbiter_tb.sv

# File Description: Directed testbench for fault_arbiter, the rolling-window
#                   overcurrent detector. The bound checker
#                   (sva/protect/fault_arbiter_sva.sv) holds every claim true
#                   at an edge; this file adds the one it cannot hold - the
#                   counts' exact values - as a reference model that keeps its
#                   own copy of both windows and the comparator history, and
#                   compares against the DUT on every edge.
#
#                   The DUT runs at the package's real configuration - both
#                   window sizes, the blanking lookback and the default trip
#                   thresholds - so real counter and threshold widths are
#                   exercised. The two windows differ in size, so a window
#                   used in the wrong state still shows. The model reads the
#                   same localparams the DUT is built with, so the two cannot
#                   disagree on the configuration.
#
#                   Inputs are driven through a clocking block; rst_n alone is
#                   driven directly, because it is asynchronous.

# Global variables: checks_run, checks_failed - tallies mutated by check() and
#                   read by finish_run().

*/

`timescale 1ns/1ps
`default_nettype none

module fault_arbiter_tb;

import pmic_types_pkg::*;
// ANSI_*: terminal colour escapes for the verdict lines. Harmless when the
//         output is redirected to a file - the codes are inert bytes - but
//         they do appear as literal escapes there, so keep them off any
//         line a script parses. The Makefile's cover check greps the
//         annotated sources, not this output, so nothing downstream breaks.
localparam string ANSI_RED   = "\033[1;31m";
localparam string ANSI_GREEN = "\033[1;32m";
localparam string ANSI_RESET = "\033[0m";
// ANSI_BOLD / ANSI_CYAN / ANSI_DIM: styling for the verdict banner - the
//                                   frame, the testbench name, and the
//                                   explanatory notes beside each tally
localparam string ANSI_BOLD  = "\033[1m";
localparam string ANSI_CYAN  = "\033[36m";
localparam string ANSI_DIM   = "\033[2m";
// ANSI_PASS_BADGE / ANSI_FAIL_BADGE: the verdict as a filled block - black on
//                                    green, white on red - so it reads at a
//                                    glance in a scrolled terminal
localparam string ANSI_PASS_BADGE = "\033[1;30;42m";
localparam string ANSI_FAIL_BADGE = "\033[1;97;41m";


// TB_NAME: prefix on every log line, so output is attributable when
//          several testbenches run in one session
localparam string   TB_NAME         = "fault_arbiter_tb";
// CLK_PERIOD_NS: clock period, derived from the package rather than
//                hardcoded, so retuning CLK_HZ moves every testbench with it
localparam realtime CLK_PERIOD_NS   = 1.0e9 / real'(CLK_HZ);
// WATCHDOG_NS: hard stop so a stalled run fails instead of hanging CI. Group 7
//              dominates: 2 states x (4 x 200 + 200) = 2,000 switching cycles
//              of PWM_LOW_CLKS + PWM_HIGH_CLKS clocks each. The directed groups
//              add a few hundred cycles more; 3,000 cycles leaves margin.
localparam realtime WATCHDOG_NS = 3_000.0 * (PWM_LOW_CLKS + PWM_HIGH_CLKS) * CLK_PERIOD_NS;
// RESET_CLKS: clocks reset is held in do_reset(), and clocks waited after
//             its release
localparam int      RESET_CLKS      = 3;
// DRIVE_OFFSET_NS: how long after each clock edge the clocking block's drives
//                  land, so the DUT never captures a value on the edge it was
//                  assigned. Only cb.* drives use it.
localparam realtime DRIVE_OFFSET_NS = 3.0;
// SETTLE_NS: delay after a mid-cycle reset before check() reads the DUT -
//            lets the asynchronous clear finish within that instant, while
//            staying well inside the clock period
localparam realtime SETTLE_NS       = 0.1;
// WINDOW_RUN_TB / WINDOW_SS_TB: the DUT's windows, at the package values.
//                               Different from each other, so a DUT that used
//                               one state's window size in the other fails.
localparam int      WINDOW_RUN_TB   = WINDOW_RUN;
localparam int      WINDOW_SS_TB    = WINDOW_SS;
// BLANK_CLKS_TB: the DUT's blanking lookback, at the fault_arbiter module value
localparam int      BLANK_CLKS_TB   = 5;
/// PWM_LOW_CLKS / PWM_HIGH_CLKS: default switching-cycle shape for
//                               pwm_cycle(). The low phase is two clocks
//                               longer than the lookback, so a cp_sync value
//                               held from the start of the cycle is the one
//                               the lookback reads at the rise, whatever
//                               BLANK_CLKS_TB is.
localparam int      PWM_LOW_CLKS    = BLANK_CLKS_TB+2;
localparam int      PWM_HIGH_CLKS   = 4;


// DUT inputs, initialised to their inactive levels so they are defined from
// time zero, before the clocking block's first drive lands at the first edge.
// Thresholds start at the window sizes - legal, and out of reach until a
// group lowers them.
logic                clk        = 1'b0;
logic                rst_n      = 1'b1;
logic                pwm_sync   = 1'b0;
logic                cp_sync    = 1'b0;
logic                ss_active  = 1'b0;
logic                run_active = 1'b0;
logic [TRIP_W-1:0]   trip_run   = TRIP_W'(WINDOW_RUN_TB);
logic [TRIP_W-1:0]   trip_ss    = TRIP_W'(WINDOW_SS_TB);

// DUT outputs. The trips are read only by the bound checker; the counts by
// the checker and the reference model, through the clocking block.
/* verilator lint_off UNUSEDSIGNAL */
logic                                 window_trip;
logic                                 window_trip_SS;
logic [$clog2(WINDOW_RUN_TB+1)-1:0]   fault_count_run_out;
logic [$clog2(WINDOW_SS_TB+1)-1:0]    fault_count_ss_out;
/* verilator lint_on UNUSEDSIGNAL */

// drv_*: the values the testbench currently wants on each DUT input. Helpers
//        change these and call drive(), which puts all six through the
//        clocking block together - so every input gets exactly one drive per
//        call and none is ever left stale.
logic              drv_pwm    = 1'b0;
logic              drv_cp     = 1'b0;
logic              drv_ss     = 1'b0;
logic              drv_run    = 1'b0;
logic [TRIP_W-1:0] drv_trip_run = TRIP_W'(WINDOW_RUN_TB);
logic [TRIP_W-1:0] drv_trip_ss  = TRIP_W'(WINDOW_SS_TB);

// prbs15: state of the PRBS15 generator, x^15 + x^14 + 1 - period 32767, so
//         per-clock driving at several bits per sample does not repeat within
//         a run. Any non-zero seed.
logic [14:0] prbs15 = 15'h7FFF;



int unsigned checks_run    = 0;
int unsigned checks_failed = 0;


// ============================================================
// DUT
// ============================================================

fault_arbiter #(
    .WINDOW_RUN (WINDOW_RUN_TB),
    .WINDOW_SS  (WINDOW_SS_TB),
    .BLANK_CLKS (BLANK_CLKS_TB)
) dut (
    .clk                 (clk),
    .rst_n               (rst_n),
    .pwm_sync            (pwm_sync),
    .cp_sync             (cp_sync),
    .ss_active           (ss_active),
    .run_active          (run_active),
    .trip_run            (trip_run),
    .trip_ss             (trip_ss),
    .window_trip         (window_trip),
    .window_trip_SS      (window_trip_SS),
    .fault_count_run_out (fault_count_run_out),
    .fault_count_ss_out  (fault_count_ss_out)
);


initial begin

    /*
    Purpose:
    ---
    Free-running clock. Generates the clock and nothing else - a second
    initial block assigning any signal this one touches is a race.
    */

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
        $dumpvars(0, fault_arbiter_tb);

    end

end


/*
Purpose:
---
Fix when the testbench drives and samples relative to the clock. Every cb.*
drive lands DRIVE_OFFSET_NS after the edge it was issued on, so the DUT never
captures a value on the edge it was assigned. Every cb.* read returns the
value from just before the edge (#1step) - what the DUT's flops captured at
that edge - which is how the reference model reads the counts the DUT showed
going into each edge, with no race against the edge's own updates.

The driven inputs are outputs only. Verilator does not support inout clocking
items, so the model reads them directly - safe, because every drive lands
DRIVE_OFFSET_NS after an edge, so at any edge they already hold the value the
DUT samples. rst_n is not in the block: it is asynchronous and must be
drivable between edges.

The clockvars are only ever written or read through cb, which Verilator
reports as unused (outputs) or undriven (inputs), so the waivers are confined
to this block.
*/
/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */
default clocking cb @(posedge clk);
    default input #1step output #(DRIVE_OFFSET_NS);
    output pwm_sync, cp_sync, ss_active, run_active;
    output trip_run, trip_ss;
    input  fault_count_run_out, fault_count_ss_out;
endclocking
/* verilator lint_on UNDRIVEN */
/* verilator lint_on UNUSEDSIGNAL */

task automatic check(input bit condition, input string label);

    /*
    Purpose:
    ---
    check: procedural comparison, for claims no clocked property can see -
    the counts' exact values, computed by the reference model - and
    facts about the testbench itself.
    */

    checks_run++;
    if (!condition) begin

        checks_failed++;
        $display("[%0t] CHECK FAIL: %s", $time, label);

    end

endtask


task automatic tick(input int n = 1);

    /*
    Purpose:
    ---
    tick: advance n edges of the clocking block. Returns AT the nth edge, so a
    drive issued next lands DRIVE_OFFSET_NS after it. Written as
    repeat (n) @(cb) rather than ##(n): a cycle delay by a variable
    count crashes Verilator 5.020 with an internal fault.
    */

    repeat (n) @(cb);

endtask


task automatic drive();

    /*
    Purpose:
    ---
    drive: puts all six drv_* values onto the DUT inputs through the clocking
    block, landing DRIVE_OFFSET_NS after the current edge. Every helper
    drives through here, never through a single cb.* assignment: under
    some simulator versions (seen in Verilator 5.020) driving one output
    of a clocking block disturbs the others.
    */

    cb.pwm_sync   <= drv_pwm;
    cb.cp_sync    <= drv_cp;
    cb.ss_active  <= drv_ss;
    cb.run_active <= drv_run;
    cb.trip_run   <= drv_trip_run;
    cb.trip_ss    <= drv_trip_ss;

endtask


task automatic set_state(input bit ss, input bit run);

    /*
    Purpose:
    ---
    set_state: the two state flags the supervisor would drive - at most one of
    them high, by the checker's input contract. Neither high is
    S_OFF / S_HICCUP, which clears both windows.
    */

    drv_ss  = ss;
    drv_run = run;
    drive();

endtask


/* verilator lint_off UNUSEDSIGNAL */
task automatic set_trips(input int run_thr, input int ss_thr);

    /*
    Purpose:
    ---
    set_trips: drives both thresholds. Keep them within [1, window size] - the
    checker's reg_file contract. int arguments so callers pass plain
    numbers; only the low TRIP_W bits are driven, hence the waiver.
    */

    drv_trip_run = TRIP_W'(run_thr);
    drv_trip_ss  = TRIP_W'(ss_thr);
    drive();

endtask
/* verilator lint_on UNUSEDSIGNAL */


task automatic pwm_cycle(input bit faulted,
                         input int low_clks  = PWM_LOW_CLKS,
                         input int high_clks = PWM_HIGH_CLKS);

    /*
    Purpose:
    ---
    pwm_cycle: one switching cycle, low phase first: pwm_sync low for low_clks,
    then high for high_clks, with cp_sync held at faulted from the
    start. The rise between the two phases is the cycle's one
    sample; with low_clks >= BLANK_CLKS_TB the lookback reads
    faulted. Returns at the last edge of the high phase.
    */

    drv_cp  = faulted;
    drv_pwm = 1'b0;
    drive();
    tick(low_clks);
    drv_pwm = 1'b1;
    drive();
    tick(high_clks);

endtask


task automatic pwm_cycles(input int n, input bit faulted);

    /*
    Purpose:
    ---
    pwm_cycles: n identical switching cycles
    */

    repeat (n) pwm_cycle(faulted);

endtask

task automatic pwm_cycle_noisy(input int k, input bit use_or);

    /*
    Purpose:
    ---
    pwm_cycle_noisy: one switching cycle with cp_sync redrawn from the PRBS on
    EVERY clock, at the chosen density. The verdict at the rise
    then depends on exactly which clock the lookback reads, so a
    lookback of the wrong depth produces wrong verdicts that only
    a model replaying the comparator history can predict.
    */

    drv_pwm = 1'b0;
    repeat (PWM_LOW_CLKS) begin

        drv_cp = prbs_shaped(k, use_or);
        drive();
        tick(1);

    end
    drv_pwm = 1'b1;
    repeat (PWM_HIGH_CLKS) begin

        drv_cp = prbs_shaped(k, use_or);
        drive();
        tick(1);

    end

endtask

task automatic pwm_cycle_split(input bit first_value, input bit second_value,
                               input int second_clks);

    /*
    Purpose:
    ---
    pwm_cycle_split: one switching cycle whose cp_sync changes during the low
    phase: first_value for the opening clocks, then
    second_value for the last second_clks clocks before the
    rise. The lookback reads second_value only if second_clks
    >= BLANK_CLKS_TB; a change any later falls inside the
    blanking and is ignored. Returns at the last edge of the
    high phase.
    */

    drv_cp  = first_value;
    drv_pwm = 1'b0;
    drive();
    tick(PWM_LOW_CLKS - second_clks);
    drv_cp  = second_value;
    drive();
    tick(second_clks);
    drv_pwm = 1'b1;
    drive();
    tick(PWM_HIGH_CLKS);

endtask


function automatic bit prbs_next();

    /*
    Purpose:
    ---
    prbs_next: advance the generator one step and return the new bit
    */

    prbs15 = {prbs15[13:0], prbs15[14] ^ prbs15[13]};
    return prbs15[0];

endfunction


function automatic bit prbs_shaped(input int k, input bit use_or);

    /*
    Purpose:
    ---
    prbs_shaped: one fault bit at a chosen density, from k PRBS bits combined -
    AND of k gives 1/2^k (k=2: 25%, k=3: 12.5%), OR of k gives
    1 - 1/2^k (k=2: 75%, k=3: 87.5%, k=4: 93.75%); k=1 is 50%
    */

    bit result;
    result = prbs_next();
    for (int i = 1; i < k; i++) begin

        result = use_or ? (result | prbs_next()) : (result & prbs_next());

    end
    return result;

endfunction



task automatic do_reset();

    /*
    Purpose:
    ---
    do_reset: everything inactive, then a reset pulse with a genuine falling
    edge, so the DUT's async clear fires before any clock arrives.
    Leaves both windows empty, neither state active, PWM low,
    thresholds at the window sizes.
    */

    drv_pwm      = 1'b0;
    drv_cp       = 1'b0;
    drv_ss       = 1'b0;
    drv_run      = 1'b0;
    drv_trip_run = TRIP_W'(WINDOW_RUN_TB);
    drv_trip_ss  = TRIP_W'(WINDOW_SS_TB);
    drive();
    rst_n = 1'b1;
    #1;
    rst_n = 1'b0;
    tick(RESET_CLKS);
    rst_n = 1'b1;
    tick(RESET_CLKS);

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
    $display("");
    $display("%s==================================================%s",
             ANSI_CYAN, ANSI_RESET);
    $display(" %s%s%s  %s|%s  %s  %s|%s  %t",
             ANSI_BOLD, TB_NAME, ANSI_RESET, ANSI_CYAN, ANSI_RESET,
             reason, ANSI_CYAN, ANSI_RESET, $time);
    $display("%s--------------------------------------------------%s",
             ANSI_CYAN, ANSI_RESET);
    // Every tally is stated as an outcome rather than a bare number, so a
    // clean run reads as what it proved instead of a column of zeros.
    if (sva_pkg::sva_failures == 0) begin

        $display(" assertions  %s✔ none failed%s", ANSI_GREEN, ANSI_RESET);

    end
    else begin

        $display(" assertions  %s✘ %0d failed%s  %s(SVA FAIL lines above)%s",
                 ANSI_RED, sva_pkg::sva_failures, ANSI_RESET, ANSI_DIM, ANSI_RESET);

    end
    if (checks_failed != 0) begin

        $display(" checks      %s✘ %0d failed%s  %s(%0d run)%s",
                 ANSI_RED, checks_failed, ANSI_RESET, ANSI_DIM, checks_run, ANSI_RESET);

    end
    else if (checks_run == 0) begin

        $display(" checks      %s- none run: every claim is in the bound checker%s",
                 ANSI_DIM, ANSI_RESET);

    end
    else begin

        $display(" checks      %s✔ %0d of %0d passed%s",
                 ANSI_GREEN, checks_run, checks_run, ANSI_RESET);

    end
    $display("%s--------------------------------------------------%s",
             ANSI_CYAN, ANSI_RESET);
    if (passed) begin

        $display(" %s PASS %s  %sprovisional until every cover hits%s",
                 ANSI_PASS_BADGE, ANSI_RESET, ANSI_DIM, ANSI_RESET);

    end
    else begin

        $display(" %s FAIL %s", ANSI_FAIL_BADGE, ANSI_RESET);

    end
    $display("%s==================================================%s",
             ANSI_CYAN, ANSI_RESET);
    // tally: one plain key=value line for the run scripts (run_tb.sh reads
    //        it for the summary card; the terminal filter hides it). The
    //        banner above is for people and may be reworded freely.
    $display("tally: checks_run=%0d checks_failed=%0d sva_failures=%0d exit=%s",
             checks_run, checks_failed, sva_pkg::sva_failures, reason);
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
    simulator. Absolute delay, so it fires even if the clock stops. Counts as
    a failure so the verdict and the exit status both report it.
    */

    #(WATCHDOG_NS);
    checks_failed++;
    finish_run("WATCHDOG - did not complete");

end


// ============================================================
// Reference model
// ============================================================

// model_history: the model's copy of the comparator lookback - exactly
//                BLANK_CLKS_TB entries, oldest at [0]. Entry [0] is cp_sync as
//                sampled BLANK_CLKS_TB edges ago: the value a sample reads.
bit model_history [$];
// model_run_window / model_ss_window: the two windows, oldest sample at [0]
bit model_run_window [$];
bit model_ss_window  [$];
// model_pwm_prev: pwm_sync as sampled at the previous edge, for the model's
//                 own rising-edge detection
bit model_pwm_prev;
// expected_run / expected_ss: the counts the model predicts the DUT will show
//                             going into the NEXT edge
int expected_run;
int expected_ss;



always @(cb) begin

    /*
    Purpose:
    ---
    The reference model: an independent copy of the DUT's three memories - the
    comparator lookback, and the S_RUN and S_SS windows - kept as lists and
    counted from scratch every edge, a different method from the DUT's shift
    registers and running counts. On every edge it first COMPARES the counts the
    DUT shows going into the edge with its own prediction from the previous edge,
    then UPDATES itself from the inputs as they stand at this edge and predicts
    the next counts. Inputs are read from the pins, the counts through cb; it
    never reads a DUT internal.
    */
  
    // Compare the model's expected count against the DUT's counts
    if(rst_n) begin

        check(int'(cb.fault_count_run_out) == expected_run,
            $sformatf("model: run count %0d, expected %0d",
                cb.fault_count_run_out, expected_run));

        check(int'(cb.fault_count_ss_out) == expected_ss,
            $sformatf("model: soft-start count %0d, expected %0d",
                    cb.fault_count_ss_out, expected_ss));

    end

    // Just like in the DUT, the shift registers are cleared on reset or outside valide state
    if (!rst_n || (!run_active && !ss_active)) begin

        model_run_window.delete();
        model_ss_window.delete();
        model_history.delete();
        repeat (BLANK_CLKS_TB) model_history.push_back(1'b0);                     

    end

    else begin

        // a rising PWM edge takes one verdict into the active state's window
        if ((pwm_sync && !model_pwm_prev) && run_active) begin

            model_run_window.push_back(model_history[0]);

            if (model_run_window.size() > WINDOW_RUN_TB) begin
                
                void'(model_run_window.pop_front());

            end
              

        end

        else if ((pwm_sync && !model_pwm_prev) && ss_active) begin

            model_ss_window.push_back(model_history[0]);

            if (model_ss_window.size() > WINDOW_SS_TB) begin

                void'(model_ss_window.pop_front());

            end
                

        end

        // the lookback moves on EVERY clock while a state is active
        model_history.push_back(cp_sync);
        void'(model_history.pop_front());

    end

    model_pwm_prev = rst_n ? pwm_sync : 1'b0;

    //Calculation of the model's run count
    expected_run = 0;
    foreach (model_run_window[i]) expected_run += model_run_window[i];

    //Calculation of models SS counts
    expected_ss = 0;
    foreach(model_ss_window[i]) expected_ss += model_ss_window[i];

end


// ============================================================
// Stimulus
// ============================================================

initial begin

    /*
    Purpose:
    ---
    Drives the directed groups in order. The bound checker and the reference model
    judge every edge; each group exists to make their antecedents and covers
    occur, named in the group's comment.
    */

    $display("\n==== %s ====\n", TB_NAME);

    /*
    Group 1: reset.
    ---
    Everything inactive, reset pulsed with a genuine falling edge. Both counts
    must be 0 and both trips low under reset. Lights c_reset_clears.
    */

    do_reset();
    tick(2);

    /*
    Group 2: the S_RUN window.
    ---
    trip_run = 4: three faulted samples (no trip), a fourth (trip - the
    "reaches" fencepost), then WINDOW_RUN_TB clean ones so every fault leaves
    the window and the trip clears. Then trip_run = WINDOW_RUN_TB: a full
    window trips at the largest legal threshold, and two more faulted samples
    enter as two leave, so the count must hold while the window turns over.
    Then trip_run = 1 while the window drains. Lights c_window_trip_high /
    _at_thr, c_run_count_up / _down / _full, c_run_trip_at_window,
    c_trip_run_at_max / _at_min and c_run_active_and_not_ss_active.
    */

    set_trips(4, WINDOW_SS_TB);
    set_state(1'b0, 1'b1);
    pwm_cycles(3, 1'b1);
    pwm_cycle(1'b1);
    pwm_cycles(WINDOW_RUN_TB, 1'b0);
    set_trips(WINDOW_RUN_TB, WINDOW_SS_TB);
    pwm_cycles(WINDOW_RUN_TB, 1'b1);
    pwm_cycles(2, 1'b1);
    set_trips(1, WINDOW_SS_TB);
    pwm_cycles(WINDOW_RUN_TB, 1'b0);
    set_state(1'b0, 1'b0);
    tick(2);

    /*
    Group 3: the S_SS window.
    ---
    Group 2 for the soft-start window, on its own size: trip_ss = 5 with four
    then five faulted samples, a full drain, a full window at
    trip_ss = WINDOW_SS_TB with two cancelling samples, then trip_ss = 1
    while it drains. Lights c_window_trip_ss_high / _at_thr,
    c_ss_count_up / _down / _full, c_trip_ss_at_max / _at_min and
    c_ss_active_and_not_run_active.
    */

    set_trips(WINDOW_RUN_TB, 5);
    set_state(1'b1, 1'b0);
    pwm_cycles(4, 1'b1);
    pwm_cycle(1'b1);
    pwm_cycles(WINDOW_SS_TB, 1'b0);
    set_trips(WINDOW_RUN_TB, WINDOW_SS_TB);
    pwm_cycles(WINDOW_SS_TB, 1'b1);
    pwm_cycles(2, 1'b1);
    set_trips(WINDOW_RUN_TB, 1);
    pwm_cycles(WINDOW_SS_TB, 1'b0);
    set_state(1'b0, 1'b0);
    tick(2);

    /*
    Group 4: the lookback.
    ---
    Blanking: cp_sync changes BLANK_CLKS_TB - 1 clocks before the rise -
    inside the lookback - so the sample must still read the earlier value;
    then exactly BLANK_CLKS_TB clocks before, so it must read the new value.
    Both directions of each. Then activation: cp_sync is held high while
    neither state is active, the converter enters S_RUN, and the first rise
    comes one clock later - before the lookback has refilled - so that
    sample must read no-fault: the history from before switching is
    cleared, not counted. No covers of their own: the reference model is
    what judges every sample here.
    */

    set_state(1'b0, 1'b1);
    pwm_cycle_split(1'b0, 1'b1, BLANK_CLKS_TB - 1);
    pwm_cycle_split(1'b1, 1'b0, BLANK_CLKS_TB - 1);
    pwm_cycle_split(1'b0, 1'b1, BLANK_CLKS_TB);
    pwm_cycle_split(1'b1, 1'b0, BLANK_CLKS_TB);
    set_state(1'b0, 1'b0);
    drv_cp = 1'b1;
    drive();
    tick(5);
    set_state(1'b0, 1'b1);
    pwm_cycle(1'b1, 1);
    pwm_cycles(3, 1'b1);
    set_state(1'b0, 1'b0);
    tick(2);

    /*
    Group 5: the clear, and the freeze.
    ---
    Leave each state with faults in its window and its trip high: the clear
    must empty both windows on the next edge, and the trip must drop with
    the state - not an edge later - while the count is still clearing. Then the soft-start count is left at
    2, below trip_ss = 4, and the FSM moves S_SS -> S_RUN as the supervisor
    would: the soft-start count must freeze through S_RUN while the run
    window counts clean samples from empty. Leaving S_RUN clears both.
    Lights c_clear_run_nonzero, c_clear_ss_nonzero, c_trip_run_gated
    and c_trip_ss_gated.
    */

    set_trips(2, 2);
    set_state(1'b0, 1'b1);
    pwm_cycles(3, 1'b1);
    set_state(1'b0, 1'b0);
    tick(2);
    set_state(1'b1, 1'b0);
    pwm_cycles(3, 1'b1);
    set_state(1'b0, 1'b0);
    tick(2);
    set_trips(WINDOW_RUN_TB, 4);
    set_state(1'b1, 1'b0);
    pwm_cycles(2, 1'b1);
    set_state(1'b0, 1'b1);
    pwm_cycles(4, 1'b0);
    set_state(1'b0, 1'b0);
    tick(2);
    set_state(1'b0, 1'b1);
    pwm_cycles(2, 1'b0);
    set_state(1'b0, 1'b0);
    tick(2);

    /*
    Group 6: a faulted sample on the S_SS -> S_RUN edge (decision B).
    ---
    trip_ss = 3 with two faulted samples in the window, then a third whose
    rise falls on the very edge the FSM leaves S_SS - legal, since on that
    edge the supervisor still sees window_trip_SS low. The sample lands in
    the soft-start count, which then freezes at trip_ss through S_RUN.
    Before the RTL fix that held window_trip_SS high through the whole run
    with no overcurrent behind it, and a_trip_ss_confined failed here - this
    group found the bug. It is now the regression test for the fix: each
    trip is gated by its own state, so the frozen count no longer raises
    window_trip_SS. Lights c_ss_count_at_trip_in_run and c_trip_ss_gated.
    */

    set_trips(WINDOW_RUN_TB, 3);
    set_state(1'b1, 1'b0);
    pwm_cycles(2, 1'b1);
    drv_cp  = 1'b1;
    drv_pwm = 1'b0;
    drive();
    tick(PWM_LOW_CLKS);
    drv_pwm = 1'b1;
    drive();
    tick(1);
    set_state(1'b0, 1'b1);
    tick(PWM_HIGH_CLKS - 1);
    pwm_cycles(4, 1'b0);
    set_state(1'b0, 1'b0);
    tick(2);

       /*
    Group 7: PRBS comparator noise.
    ---
    cp_sync is redrawn from a PRBS15 stream on every clock, so each cycle's
    verdict depends on exactly which clock the blanking lookback reads - the
    comparator history is exercised on every cycle, not only in group 4.
    Each state runs a schedule of quiet stretches (12.5%) broken by bursts
    (87.5% and 93.75%), plus a long 75% stretch, so each trip asserts and
    clears repeatedly at the real thresholds. The state is cleared between
    runs, so no run crosses S_SS -> S_RUN with a trip standing. The reference
    model judges the count on every edge.
    */

    set_trips(TRIP_RUN_DEFAULT, TRIP_SS_DEFAULT);
    for (int pass = 0; pass < 2; pass++) begin

        set_state(pass == 1, pass == 0);              // pass 0: S_RUN, pass 1: S_SS
        repeat (4) begin

            repeat (60) pwm_cycle_noisy(3, 1'b0);     // quiet: 12.5%
            repeat (40) pwm_cycle_noisy(3, 1'b1);     // burst: 87.5%
            repeat (60) pwm_cycle_noisy(3, 1'b0);     // quiet
            repeat (40) pwm_cycle_noisy(4, 1'b1);     // burst: 93.75%

        end
        repeat (200) pwm_cycle_noisy(2, 1'b1);        // long 75% stretch
        set_state(1'b0, 1'b0);
        tick(2);

    end

    finish_run("normal end");

end

endmodule

`default_nettype wire

