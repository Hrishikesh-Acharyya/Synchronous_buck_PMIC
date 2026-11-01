/*

# Filename:         supervisor_tb.sv

# File Description: Directed testbench for supervisor, the converter's
#                   four-state FSM. Checking is done by the bound checker
#                   (sva/supervisor_sva.sv) on every edge; this file only
#                   makes its antecedents happen.
#
#                   Inputs are driven through a clocking block, so every drive
#                   lands DRIVE_OFFSET_NS after the edge; rst_n alone is driven
#                   directly, because it is asynchronous. check() is kept for
#                   what no clocked property can see: sub-cycle behaviour and
#                   facts about this testbench.

# Global variables: checks_run, checks_failed - tallies mutated by check() and
#                   read by finish_run().

*/

`timescale 1ns/1ps
`default_nettype none

module supervisor_tb;

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
localparam string   TB_NAME         = "supervisor_tb";
// CLK_PERIOD_NS: supervisor clock period, derived from the package rather
//                than hardcoded, so retuning CLK_HZ moves every testbench
//                with it. Real division: integer arithmetic truncates for
//                any CLK_HZ that does not divide 1e9 exactly.
localparam realtime CLK_PERIOD_NS   = 1.0e9 / real'(CLK_HZ);
// WATCHDOG_NS: hard stop so a stalled run fails instead of hanging CI. Sized
//              for the planned exhaustive sweep, which dominates: 1024 vectors
//              in each state at 2 clocks per vector for S_OFF, 3 for S_SS and
//              4 each for S_RUN and S_HICCUP (steering plus the vector) -
//              13 x 1024 = 13,312 clocks, plus a few hundred for the directed
//              groups. 25,000 clocks leaves ample margin.
localparam realtime WATCHDOG_NS     = 25_000.0 * CLK_PERIOD_NS;
// RESET_CLKS: clocks reset is held in do_reset(), and clocks waited after
//             its release
localparam int      RESET_CLKS      = 3;
// DRIVE_OFFSET_NS: how long after each clock edge the clocking block's drives
//                  land, so the DUT never captures a value on the edge it was
//                  assigned. Only cb.* drives use it.
localparam realtime DRIVE_OFFSET_NS = 3.0;
// SETTLE_NS: delay after a mid-cycle reset before check() reads
//            state_out and en - lets the asynchronous clear and the
//            combinational outputs finish updating within that instant.
//            Small enough to stay well inside the clock period, so the check
//            observes the asynchronous clear and not the next clock edge.
localparam realtime SETTLE_NS       = 0.1;


// Stimulus vector bit order, used by every helper and by the sweep:
//   [9] en_SW  [8] spi_enable  [7] OTP  [6] UVLO  [5] latch_state
//   [4] latch_assert  [3] SS_done  [2] window_trip_SS  [1] window_trip
//   [0] hiccup_done
// Bits [9:4] line up with the checker's fault_cause bits [5:0], cause for
// cause, which is what lets apply_cause() reuse its index.

// IDLE: both enables on, no faults, no handshakes - the converter is allowed
//       to run and nothing is asking it to change state
localparam logic [9:0] IDLE          = 10'b11_0000_0000;
// SWITCH_OFF: IDLE with the physical switch off - do_reset()'s pattern, and
//             the one-step route to S_OFF from any state
localparam logic [9:0] SWITCH_OFF    = 10'b01_0000_0000;
// B_*: single-bit masks into the stimulus vector, for OR-ing handshakes onto
//      IDLE or onto a cause - so no group carries a bare binary literal
localparam logic [9:0] B_SS_DONE     = 10'b00_0000_1000;
localparam logic [9:0] B_TRIP_SS     = 10'b00_0000_0100;
localparam logic [9:0] B_TRIP_RUN    = 10'b00_0000_0010;
localparam logic [9:0] B_HICCUP_DONE = 10'b00_0000_0001;
// B_OTP: OTP's bit, for the priority contests, which need one specific cause
localparam logic [9:0] B_OTP         = 10'b00_1000_0000;


// DUT inputs, initialised to do_reset()'s pattern - switch off, everything
// else quiet - so they are defined from time zero, before the clocking
// block's first drive lands at the first edge
logic clk            = 1'b0;
logic rst_n          = 1'b1;
logic en_SW          = 1'b0;
logic spi_enable     = 1'b1;
logic OTP            = 1'b0;
logic UVLO           = 1'b0;
logic latch_state    = 1'b0;
logic latch_assert   = 1'b0;
logic SS_done        = 1'b0;
logic window_trip_SS = 1'b0;
logic window_trip    = 1'b0;
logic hiccup_done    = 1'b0;

// en, state_out: read by the mid-cycle reset check(); every other claim on
//                them is made by the bound checker
logic   en;
state_t state_out;
// *_active: driven by the DUT and not read here - the properties read them
//           inside supervisor's own scope through the bind

/* verilator lint_off UNUSEDSIGNAL */
logic ss_active;
logic run_active;
logic hiccup_active;
/* verilator lint_on UNUSEDSIGNAL */

// exit_states: the three states a hard fault forces the FSM out of
state_t exit_states [3] = '{S_SS, S_RUN, S_HICCUP};
// sweep_states: every state, for the exhaustive sweep in group 11
state_t sweep_states [4] = '{S_OFF, S_SS, S_RUN, S_HICCUP};
// vectors_applied: stimulus vectors the sweep has driven - checked against
//                  4 x 1024 at its end, so a shortened loop cannot pass
int unsigned vectors_applied = 0;

int unsigned checks_run      = 0;
int unsigned checks_failed   = 0;


// ============================================================
// DUT
// ============================================================

supervisor dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .en_SW          (en_SW),
    .spi_enable     (spi_enable),
    .OTP            (OTP),
    .UVLO           (UVLO),
    .latch_state    (latch_state),
    .latch_assert   (latch_assert),
    .SS_done        (SS_done),
    .window_trip_SS (window_trip_SS),
    .window_trip    (window_trip),
    .hiccup_done    (hiccup_done),
    .en             (en),
    .ss_active      (ss_active),
    .run_active     (run_active),
    .hiccup_active  (hiccup_active),
    .state_out      (state_out)
);


/*
Purpose:
---
Free-running clock. Generates the clock and nothing else - a second
initial block assigning any signal this one touches is a race.
*/
initial begin

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
        $dumpvars(0, supervisor_tb);

    end

end


/*
Purpose:
---
Fix when the testbench drives relative to the clock. Every cb.* drive lands
DRIVE_OFFSET_NS after the edge it was issued on, so the DUT never captures a
value on the edge it was assigned - the same job as a manual #(DRIVE_OFFSET_NS)
before each assignment, but impossible to forget on one line. No inputs are
sampled here: the bound checker reads the outputs. rst_n is not in the block,
because it is asynchronous and must be drivable between edges.
*/

default clocking cb @(posedge clk);

    default input #1step output #(DRIVE_OFFSET_NS);
    output en_SW, spi_enable;
    output OTP, UVLO, latch_state, latch_assert;
    output SS_done, window_trip_SS, window_trip, hiccup_done;

endclocking


// check: procedural comparison, for claims no clocked property can see -
//        sub-cycle behaviour, and facts about the testbench itself.
//        Invariants and temporal claims belong in the bound checker.
task automatic check(input bit condition, input string label);

    checks_run++;
    if (!condition) begin

        checks_failed++;
        $display("[%0t] CHECK FAIL: %s", $time, label);

    end

endtask


// tick: advance n edges of the clocking block. Returns AT the nth edge, so a
//       set_inputs() issued next lands DRIVE_OFFSET_NS after it. Written as
//       repeat (n) @(cb) rather than ##(n): a cycle delay by a variable count
//       crashes Verilator 5.020 with an internal fault.
task automatic tick(input int n = 1);

    repeat (n) @(cb);

endtask


// set_inputs: drives all ten DUT inputs from one vector, through the
//             clocking block, so each lands DRIVE_OFFSET_NS after the edge.
//             Does not advance time - the caller decides how many clocks.
//             Every helper drives through here, so each input gets exactly
//             one drive per clock and none is ever left untouched.
task automatic set_inputs(input logic [9:0] stim);

    cb.en_SW          <= stim[9];
    cb.spi_enable     <= stim[8];
    cb.OTP            <= stim[7];
    cb.UVLO           <= stim[6];
    cb.latch_state    <= stim[5];
    cb.latch_assert   <= stim[4];
    cb.SS_done        <= stim[3];
    cb.window_trip_SS <= stim[2];
    cb.window_trip    <= stim[1];
    cb.hiccup_done    <= stim[0];

endtask


// apply_cause: IDLE with exactly one hard-fault cause present. cause uses the
//              checker's fault_cause numbering: 5 en_SW lost, 4 spi_enable
//              lost, 3 OTP, 2 UVLO, 1 latch_state, 0 latch_assert. XOR flips
//              the one bit away from IDLE - an enable goes 1 -> 0, a fault
//              goes 0 -> 1 - so one expression serves both polarities.
task automatic apply_cause(input int cause);

    set_inputs(IDLE ^ (10'b1 << (cause + 4)));

endtask


// goto_state: steers the FSM to target from any state, without a reset, using
//             only arrows the checker verifies. Returns AT the edge where
//             state_out has just become target, so the caller's next
//             set_inputs() is sampled with the FSM in target.
task automatic goto_state(input state_t target);

    set_inputs(SWITCH_OFF);                      // any state -> S_OFF
    tick(1);
    if (target == S_OFF) return;
    set_inputs(IDLE);                            // S_OFF -> S_SS
    tick(1);
    if (target == S_SS) return;
    if (target == S_RUN) set_inputs(IDLE | B_SS_DONE);   // S_SS -> S_RUN
    else                 set_inputs(IDLE | B_TRIP_SS);   // S_SS -> S_HICCUP
    tick(1);

endtask


// do_reset: inputs to "switch off, everything else quiet", then a reset pulse
//           with a genuine falling edge, so the DUT's async clear fires before
//           any clock arrives. Leaves the FSM in S_OFF held there by one
//           deliberate cause, the switch - not by several faults at once.
task automatic do_reset();

    set_inputs(SWITCH_OFF);
    rst_n = 1'b1;
    #1;
    rst_n = 1'b0;
    tick(RESET_CLKS);
    rst_n = 1'b1;
    tick(RESET_CLKS);

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
Drives the directed groups in order. The groups carry no checks of their own:
the bound checker evaluates every edge, and each group exists to make its
antecedents and covers occur, named in the group's comment. Timing rule for
every group: set_inputs() lands DRIVE_OFFSET_NS after the edge it is issued
on, and the FSM samples it at the NEXT edge - so tick(1) after a
transition-causing vector means one edge sees it, and tick(n) on a hold means
n edges see it and the FSM must not move.
*/

initial begin

    $display("\n==== %s ====\n", TB_NAME);

      /*
    Group 1: reset.
    ---
    Switch off, everything else quiet, reset pulsed with a genuine falling
    edge. Under reset the FSM must be in S_OFF with en low; after release it
    must stay there, held by the switch alone. Exercises a_reset_means_off and
    a_off_holds_on_fault; lights c_reset_means_off, c_state_off and
    g_cause[5].c_cause_in_off.
    */

    do_reset();
    tick(2);

    /*
    Group 2: start-up inhibit, one cause at a time.
    ---
    For each of the six hard-fault causes: steer to S_OFF, then everything
    enabled EXCEPT that one cause, for three edges. The FSM must not start a
    ramp on any of them - it must keep refusing, not refuse once. One cause
    alone, so a DUT that ignored one input cannot pass on edges where another
    cause happened to be present too. i follows the checker's fault_cause
    numbering. Exercises a_off_holds_on_fault and a_hard_fault_holds_en_low;
    lights g_cause[0..5].c_cause_in_off.
    */

    goto_state(S_OFF);
    tick(1);

    for(int i = 0; i < 6; i++) begin

        goto_state(S_OFF);
        apply_cause(i);
        tick(3);
    
    end
    
    /*
    Group 3: the ramp.
    ---
    Enter S_SS from S_OFF, then hold it with the S_RUN trip asserted - S_SS
    must ignore window_trip, so a DUT with the two trips cross-wired fails
    here. Then a plain hold, then SS_done for exactly one edge completes the
    ramp into S_RUN. Exercises a_off_to_ss, a_ss_holds, a_ss_to_run and the
    en groups; lights c_off_to_ss, c_ss_holds, c_ss_ignores_trip_run,
    c_ss_to_run, c_en_in_ss and c_allowed_in_ss.
    */

    goto_state(S_SS);
    set_inputs(IDLE | B_TRIP_RUN);
    tick(4);
    set_inputs(IDLE);
    tick(3);
    set_inputs(IDLE | B_SS_DONE);
    tick(1);
    set_inputs(IDLE);
    tick(2);

    /*
    Group 4: regulation.
    ---
    Hold S_RUN with the S_SS trip asserted - S_RUN must ignore
    window_trip_SS, the mirror of group 3 - then a plain hold. Exercises
    a_run_holds and the en groups; lights c_run_holds, c_run_ignores_trip_ss,
    c_en_in_run and c_allowed_in_run.
    */

    goto_state(S_RUN);
    set_inputs(IDLE | B_TRIP_SS);
    tick(4);
    set_inputs(IDLE);
    tick(3);

    /*
    Group 5: hiccup from S_RUN, and the retry.
    ---
    An overcurrent in S_RUN for one edge sends the FSM to the cool-down. It is
    held there for four edges with both trips and SS_done high - none of them
    has any say in S_HICCUP. Then hiccup_done ends the cool-down while SS_done
    is STILL high from the previous ramp, as it would be in the real design:
    the FSM must re-ramp through S_SS, never skip it - a skipped ramp would
    leave the converter in S_RUN with the duty ceiling still at the floor.
    The stale SS_done is confined to that one deciding edge; IDLE follows so
    the FSM then holds in S_SS. Exercises a_run_to_hiccup, a_hiccup_holds,
    a_hiccup_to_ss and a_ss_holds; lights c_run_to_hiccup, c_hiccup_holds,
    c_hiccup_ignores_trips, c_hiccup_to_ss and c_retry_with_stale_ss_done.
    */

    goto_state(S_RUN);
    set_inputs(IDLE | B_TRIP_RUN);
    tick(1);
    set_inputs(IDLE|B_SS_DONE|B_TRIP_SS|B_TRIP_RUN);
    tick(4);
    set_inputs(IDLE|B_HICCUP_DONE|B_SS_DONE);
    tick(1);
    set_inputs(IDLE);
    tick(1);

    /*
    Group 6: hiccup from S_SS.
    ---
    An overcurrent during the ramp, for one edge: the FSM goes to the
    cool-down. goto_state(S_HICCUP) takes this arrow internally, but it is
    written out here so the scenario is visible in the file and the cover
    report. IDLE follows, so the FSM holds in S_HICCUP. Exercises
    a_ss_to_hiccup and a_hiccup_holds; lights c_ss_to_hiccup.
    */

    goto_state(S_SS);
    set_inputs(IDLE | B_TRIP_SS);
    tick(1);
    set_inputs(IDLE);
    tick(1);

    /*
    Group 7: forced exit, one cause at a time, from every non-OFF state.
    ---
    For each of S_SS, S_RUN and S_HICCUP, and each of the six causes alone:
    one edge of the fault. On that edge en must already be low through the
    combinational gate, before the FSM has moved; on the next it must be in
    S_OFF. One edge only - after it the FSM is in S_OFF, and further edges
    would test S_OFF holding, not the exit. Eighteen passes. Exercises
    a_hard_fault_holds_en_low and a_hard_fault_to_off; lights all eighteen
    g_cause[i].c_cause_in_ss / _run / _hiccup and c_fault_before_exit_ss /
    _run / _hiccup.
    */

    foreach (exit_states[s]) begin
        for (int cause = 0; cause < 6; cause++) begin
            goto_state(exit_states[s]);
            apply_cause(cause);
            tick(1);
        end
    end

    /*
    Group 8: priority contests.
    ---
    Two rows' conditions true on the same edge, so the order of the DUT's
    checks decides the outcome: the S_SS trip against SS_done (the trip must
    win), then a hard fault (OTP) against each state's own sequencing input
    (the fault must win). A DUT with its priority chain in the wrong order
    passes every other group and fails here. Each contest lasts one edge; the
    next block's goto_state reads the outcome on its first edge and steers on.
    Exercises the rows of checker groups 6 and 8; lights c_ss_trip_beats_done,
    c_fault_beats_ss_done, c_fault_beats_trip_ss, c_fault_beats_trip_run and
    c_fault_beats_hiccup_done.
    */

    goto_state(S_SS);
    set_inputs(IDLE | B_TRIP_SS | B_SS_DONE);
    tick(1);

    goto_state(S_SS);
    set_inputs(IDLE | B_OTP | B_SS_DONE);
    tick(1);

    goto_state(S_SS);
    set_inputs(IDLE | B_OTP | B_TRIP_SS);
    tick(1);

    goto_state(S_RUN);
    set_inputs(IDLE | B_OTP | B_TRIP_RUN);
    tick(1);

    goto_state(S_HICCUP);
    set_inputs(IDLE | B_OTP | B_HICCUP_DONE);
    tick(1);

    /*
    Group 9: stale SS_done at start-up.
    ---
    SS_done is high while the FSM sits in S_OFF with the switch off - two
    edges, and it must hold. Then the switch comes on with SS_done still
    high, for one edge: start-up must enter S_SS, never skip the ramp. S_OFF's
    next-state logic does not consult SS_done at all; this group is what gives
    a future edit that did the chance to fail. IDLE follows, so the stale
    SS_done never reaches an edge where the FSM is in S_SS. Exercises
    a_off_holds_on_fault, a_off_to_ss and a_ss_holds; lights
    c_off_to_ss_with_stale_ss_done.
    */

    goto_state(S_OFF);
    set_inputs(SWITCH_OFF|B_SS_DONE);
    tick(2);
    set_inputs(IDLE|B_SS_DONE);
    tick(1);
    set_inputs(IDLE);
    tick(3);

    /*
    Group 10: reset asserted and released between two edges.
    ---
    In S_RUN, rst_n falls a quarter-period after an edge and rises a quarter-
    period later, so no edge ever samples it low. The asynchronous clear must
    still put the FSM in S_OFF with en low at once - read after SETTLE_NS,
    since no clocked property can see between edges. This is the testbench's
    one check() on the DUT.

    It also tests the checker's out_of_reset guard: a_run_holds started an
    attempt on the edge before the pulse and finds S_OFF on the next one. The
    guard must disarm it. An a_run_holds failure here means the guard is
    wrong, not the DUT. After release the FSM restarts through S_SS.
    */

    goto_state(S_RUN);
    set_inputs(IDLE);
    tick(2);
    #(CLK_PERIOD_NS/4.0) rst_n = 1'b0;
    #(SETTLE_NS);
    check((state_out == S_OFF) && !en,
          "asynchronous reset clears S_RUN between edges, with en low");
    #(CLK_PERIOD_NS/4.0) rst_n = 1'b1;
    tick(3);

    /*
    Group 11: exhaustive sweep.
    ---
    Every one of the 1024 input vectors, applied for exactly one edge, in each
    of the four states - 4096 cases. Groups 1-10 give readable, named
    scenarios; this gives completeness: the checker's partition is exercised
    on every input combination, so a row too narrow or too wide cannot hide.

    One edge per vector is enough. The vector is sampled at the next edge,
    and each transition claim's consequent at the edge after that - the first
    edge of the next pass's goto_state, which still shows the FSM's response,
    because the steering vector lands only after it. Holding a vector longer
    would move the FSM and test a different state than the one named. The
    final check() is a fact about this testbench: a shortened loop fails it
    rather than silently testing less.
    */

    foreach (sweep_states[s]) begin
        for (int v = 0; v < 1024; v++) begin
            goto_state(sweep_states[s]);
            set_inputs(10'(v));
            tick(1);
            vectors_applied++;
        end
    end
    set_inputs(SWITCH_OFF);
    tick(2);
    check(vectors_applied == 4096, "sweep applied every vector in every state");

    finish_run("normal end");

end

endmodule

`default_nettype wire

