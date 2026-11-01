/*

# Filename:         soft_start_tb.sv

# File Description: Directed testbench for soft_start. Carries stimulus, plus
#                   the one claim no property can hold: the ramp length,
#                   (max_on_limit - MIN_ON_COUNTS) x cycles_per_step switching
#                   cycles, which needs a computed expected value (claim 11 in
#                   soft_start_sva.sv) and is checked procedurally. Every other
#                   claim lives as a property in soft_start_sva.sv, bound to
#                   both DUTs.
#
#                   Two instances:
#                     dut      MIN_ON_COUNTS = 2, ON_TIME_W = 3 - the floor
#                              and bus width overridden down, so a ramp is a
#                              handful of steps and the top of the bus range
#                              (7) is reachable, which is where a stepping
#                              ceiling would wrap.
#                     dut_pkg  package values - the scaling smoke test.
#                   cycles_per_step and max_on_limit are inputs, so they need
#                   no override: they are driven small directly.
#
#                   Switching cycles are driven through drive_cycle(); the
#                   module counts falling edges of pwm_sync, so the pulse
#                   widths are arbitrary. cycles_per_step changes only while
#                   the supervisor flags are both low, as reg_file only
#                   accepts it in S_OFF (an input contract in the checker).
#
#                   Writing the claim list found two open RTL problems, fixed
#                   with approval before this testbench closed: the ramp
#                   stopped on max_on_counts == max_on_limit only, so a limit
#                   lowered below the ceiling mid-ramp let it climb and wrap
#                   (known_issues A1, group 10); and a ramp with max_on_limit
#                   equal to the floor waited a whole step period before
#                   SS_done (group 9).

# Global variables: checks_run, checks_failed - mutated by check() from the
#                   ramp-length groups, shared mutable state within the file.

*/

`timescale 1ns/1ps
`default_nettype none

module soft_start_tb;

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
localparam string   TB_NAME         = "soft_start_tb";
// CLK_PERIOD_NS: supervisor clock period, derived from the package rather
//                than hardcoded, so retuning CLK_HZ moves every testbench
//                with it. Real division: integer arithmetic truncates for
//                any CLK_HZ that does not divide 1e9 exactly.
localparam realtime CLK_PERIOD_NS   = 1.0e9 / real'(CLK_HZ);
// WATCHDOG_NS: hard stop so a stalled run fails instead of hanging CI. The
//              longest stretch is group 14, 71 switching cycles of 4 clocks;
//              the whole run is about 900 clocks, so 3000 leaves room
//              without hiding a hang.
localparam realtime WATCHDOG_NS     = 3000.0 * CLK_PERIOD_NS;  // 3000 clocks: 60 us at 50 MHz
// RESET_CLKS: clocks reset is held in do_reset()
localparam int      RESET_CLKS      = 3;
localparam realtime DRIVE_OFFSET_NS = 3.0;
// SETTLE_NS: delay after a mid-cycle reset before a procedural check reads
//            an output. Small enough to stay inside the clock period, so the
//            check observes the asynchronous clear and not the next edge.
localparam realtime SETTLE_NS       = 0.1;

// MIN_TB: floor of the small instance
localparam int MIN_TB = 2;
// W_TB: ceiling bus width of the small instance; its range tops out at 7
localparam int W_TB   = 3;

// Asynchronous inputs are initialised to their INACTIVE level at
// declaration. An uninitialised logic driven straight to its active level
// transitions x -> 0, which is not a reliable negedge, so an async clear
// in the DUT never fires and the flops sit at x until the first clock edge.
logic clk;
logic rst_n      = 1'b1;
logic pwm_sync   = 1'b0;
logic ss_active  = 1'b0;
logic run_active = 1'b0;
// cycles_per_step: shared by both instances; written only while idle
logic [CYC_STEP_W-1:0] cycles_per_step = CYC_STEP_W'(1);
// max_on_limit: the small instance's target; starts at its floor, the lowest
//               value reg_file can deliver
logic [W_TB-1:0]       max_on_limit    = W_TB'(MIN_TB);
// max_on_limit_pkg: the package instance's target, the reset default reg_file
//                   holds
logic [ON_TIME_W-1:0]  max_on_limit_pkg = ON_TIME_W'(MAX_ON_COUNTS_DEFAULT);

// max_on_counts / SS_done: the small instance's outputs, read by the
//                          ramp-length checks
logic [W_TB-1:0]       max_on_counts;
logic                  SS_done;
// max_on_counts_pkg: not read here - the properties read it through the bind
/* verilator lint_off UNUSEDSIGNAL */
logic [ON_TIME_W-1:0]  max_on_counts_pkg;
/* verilator lint_on UNUSEDSIGNAL */
// SS_done_pkg: read by the scaling smoke test
logic                  SS_done_pkg;


int unsigned checks_run    = 0;
int unsigned checks_failed = 0;


// ============================================================
// DUTs
// ============================================================

soft_start #(.MIN_ON_COUNTS(MIN_TB), .ON_TIME_W(W_TB)) dut (
    .clk(clk), .rst_n(rst_n), .pwm_sync(pwm_sync),
    .ss_active(ss_active), .run_active(run_active),
    .cycles_per_step(cycles_per_step), .max_on_limit(max_on_limit),
    .max_on_counts(max_on_counts), .SS_done(SS_done));

soft_start dut_pkg (
    .clk(clk), .rst_n(rst_n), .pwm_sync(pwm_sync),
    .ss_active(ss_active), .run_active(run_active),
    .cycles_per_step(cycles_per_step), .max_on_limit(max_on_limit_pkg),
    .max_on_counts(max_on_counts_pkg), .SS_done(SS_done_pkg));


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
        $dumpvars(0, soft_start_tb);
    end
end


// check: procedural comparison, for claims no clocked property can see -
//        here, the ramp length, whose expected value is computed.
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


// drive_cycle: one pwm_sync switching cycle. The DUT counts falling edges, so
//              the high and low widths are arbitrary - only the fall matters.
//              Two clocks low after the fall let the step land before the
//              caller looks.
task automatic drive_cycle();
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b1;
    repeat (2) @(posedge clk);
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b0;
    repeat (2) @(posedge clk);
endtask

// set_state: the supervisor's two flags, as one state change. Never both high
//            (an input contract the checker asserts).
task automatic set_state(input bit ss, input bit run);
    @(posedge clk);
    #(DRIVE_OFFSET_NS);
    ss_active  = ss;
    run_active = run;
    @(posedge clk);
endtask

// go_idle: leave S_SS / S_RUN (off or hiccup) and let the floor land
task automatic go_idle();
    set_state(1'b0, 1'b0);
    repeat (2) @(posedge clk);
endtask

// configure: new ramp settings, applied only while idle - reg_file accepts
//            cycles_per_step in S_OFF only
task automatic configure(input logic [CYC_STEP_W-1:0] step,
                         input logic [W_TB-1:0]       limit);
    @(posedge clk);
    #(DRIVE_OFFSET_NS);
    cycles_per_step = step;
    max_on_limit    = limit;
    @(posedge clk);
endtask

// set_limit: a live max_on_limit write, legal in any state
task automatic set_limit(input logic [W_TB-1:0] limit);
    @(posedge clk);
    #(DRIVE_OFFSET_NS) max_on_limit = limit;
endtask

// ramp_to_done: drives switching cycles until SS_done, up to max_cycles, and
//               returns how many it took
task automatic ramp_to_done(input int max_cycles, output int cycles);
    cycles = 0;
    while (!SS_done && (cycles < max_cycles)) begin
        drive_cycle();
        cycles++;
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
    int cycles;

    $display("\n==== %s ====\n", TB_NAME);

    /*
    Group 1: reset.
    ---
    Both flags low, so after reset both instances sit at their floors with
    SS_done low. Exercises a_reset_floor and a_floor_when_idle.
    */

    do_reset();

    /*
    Group 2: step window, one fall short.
    ---
    cycles_per_step = 3, limit 5 against the floor of 2. Into S_SS and two
    switching cycles: the window is not complete, so the ceiling must not
    move. The N-1 boundary of the step timing, where an off-by-one in the
    window lives. Exercises a_ceiling_moves_by_known_path.
    */

    configure(3, 5);
    set_state(1'b1, 1'b0);
    repeat (2) drive_cycle();

    /*
    Group 3: the completing fall.
    ---
    The third fall completes the window and the ceiling steps to 3. With
    group 2 this pins the step to exactly cycles_per_step falls - neither
    alone does. Exercises a_window_steps_ceiling and lights c_ceiling_steps.
    */

    drive_cycle();

    /*
    Group 4: ramp length, computed.
    ---
    From the floor again, the full ramp to 5 at 3 cycles a step must take
    (5 - 2) x 3 = 9 switching cycles, and SS_done must land with the last
    step (a_done_with_last_step). The one claim here a property cannot hold,
    so it is a check().
    */

    go_idle();
    set_state(1'b1, 1'b0);
    ramp_to_done(40, cycles);
    check(cycles == (5 - MIN_TB) * 3,
          $sformatf("ramp to 5 at 3 cycles/step took %0d cycles, expected %0d",
                    cycles, (5 - MIN_TB) * 3));
    check(max_on_counts == 3'd5, "ceiling at the limit when SS_done rose");

    /*
    Group 5: S_SS to S_RUN, then the limit moves.
    ---
    In S_RUN the ceiling is the running backstop: held, even when the host
    lowers the limit to 3 and raises it to 7, and even with switching cycles
    arriving. A new limit applies at the next soft start. Exercises
    a_hold_in_run.
    */

    set_state(1'b0, 1'b1);
    repeat (2) drive_cycle();
    set_limit(3);
    repeat (2) drive_cycle();
    set_limit(7);
    repeat (2) drive_cycle();

    /*
    Group 6: S_RUN to off.
    ---
    Leaving both states drops the ceiling to the floor and clears SS_done,
    so the next start re-ramps. Exercises a_floor_when_idle and
    a_done_falls_on_exit.
    */

    go_idle();

    /*
    Group 7: one cycle per step, to the top of the bus.
    ---
    cycles_per_step = 1, the lowest legal value - every fall is a window -
    and a limit of 7, the top of the 3-bit range, where a ceiling that kept
    stepping would wrap to 0. (7 - 2) x 1 = 5 cycles. Lights
    c_one_cycle_steps and c_ceiling_at_top.
    */

    configure(1, 7);
    set_state(1'b1, 1'b0);
    ramp_to_done(20, cycles);
    check(cycles == (7 - MIN_TB) * 1,
          $sformatf("ramp to 7 at 1 cycle/step took %0d cycles, expected %0d",
                    cycles, 7 - MIN_TB));
    repeat (3) drive_cycle();

    /*
    Group 8: S_SS left before the ramp finishes.
    ---
    A hiccup mid-ramp: three cycles in at 2 cycles a step, then both flags
    low. The ceiling must fall straight back to the floor rather than keep
    its partial ramp. Lights c_ss_left_unfinished.
    */

    go_idle();
    configure(2, 6);
    set_state(1'b1, 1'b0);
    repeat (3) drive_cycle();
    go_idle();

    /*
    Group 9: nothing to climb.
    ---
    max_on_limit equal to the floor at S_SS entry. The ramp is complete
    before it starts, so SS_done must follow on the next edge with no
    switching cycle at all. The RTL used to wait a whole step period here.
    Exercises a_done_follows_target and lights c_no_ramp_needed.
    */

    configure(3, W_TB'(MIN_TB));
    set_state(1'b1, 1'b0);
    repeat (2) @(posedge clk);
    check(SS_done == 1'b1, "SS_done with max_on_limit at the floor, no cycles driven");

    /*
    Group 10: the limit lowered below the ceiling mid-ramp (known_issues A1).
    ---
    Ramp at one cycle a step towards 7, then at a ceiling of 6 the host
    writes 3. The ceiling must come down to 3 on the next clock and SS_done
    must rise; the RTL used to keep stepping to 7 and wrap to 0. More
    switching cycles follow to show it stays there. Exercises
    a_ceiling_within_limit, a_done_follows_target and lights
    c_ceiling_clamped and c_ceiling_clamp_lands.
    */

    go_idle();
    configure(1, 7);
    set_state(1'b1, 1'b0);
    repeat (4) drive_cycle();
    set_limit(3);
    repeat (2) @(posedge clk);
    check((max_on_counts == 3'd3) && SS_done, "ceiling clamped to a lowered limit, SS_done high");
    repeat (4) drive_cycle();

    /*
    Group 11: the limit raised mid-ramp.
    ---
    Target 4, one step in, then the host raises it to 6. The ramp must carry
    on to the new target without SS_done rising at the old one. Lights
    c_limit_raised_mid_ramp.
    */

    go_idle();
    configure(1, 4);
    set_state(1'b1, 1'b0);
    drive_cycle();
    set_limit(6);
    ramp_to_done(20, cycles);
    check(max_on_counts == 3'd6, "ramp carried on to the raised limit");

    /*
    Group 12: no switching cycles in S_SS.
    ---
    pwm_sync held low, then stuck high, for twenty clocks each: no falling
    edge, so no window and no step. Releasing it gives one fall and one step,
    so the ceiling was held rather than stalled. The degenerate input; lights
    c_static_pwm_in_ss.
    */

    go_idle();
    configure(1, 6);
    set_state(1'b1, 1'b0);
    repeat (20) @(posedge clk);
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b1;
    repeat (20) @(posedge clk);
    #(DRIVE_OFFSET_NS) pwm_sync = 1'b0;
    repeat (2) @(posedge clk);

    /*
    Group 13: reset mid-ramp.
    ---
    Reset while ramping in S_SS. Both instances go to the floor; with
    ss_active still high afterwards the ramp starts again from there.
    Lights c_reset_mid_ramp.
    */

    repeat (2) drive_cycle();
    do_reset();
    repeat (2) drive_cycle();
    go_idle();

    /*
    Group 14: scaling smoke test at package parameters.
    ---
    One cycle a step and the package's 75% target: dut_pkg climbs from its
    floor to MAX_ON_COUNTS_DEFAULT, every step checked by its own bound
    checker. Then S_RUN and off, so the hold and floor paths run at full
    width too.
    */

    configure(1, 7);
    set_state(1'b1, 1'b0);
    repeat (MAX_ON_COUNTS_DEFAULT - MIN_ON_COUNTS) drive_cycle();
    check(SS_done_pkg == 1'b1,
          $sformatf("package instance done after %0d cycles at 1 cycle/step",
                    MAX_ON_COUNTS_DEFAULT - MIN_ON_COUNTS));
    set_state(1'b0, 1'b1);
    repeat (2) drive_cycle();
    go_idle();

    finish_run("normal end");
end

endmodule

`default_nettype wire
