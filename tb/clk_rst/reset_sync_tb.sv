/*

# Filename:         reset_sync_tb.sv

# File Description: Directed testbench for reset_sync, built from
#                   tb_template.sv. Makes the bound checker's antecedents
#                   occur - reset held, release, a release too short to
#                   propagate, assertion mid-operation, a narrow glitch - and
#                   checks procedurally only the two claims no clocked
#                   property can see, because they happen between edges:
#
#                     - assertion has zero clock latency: rst_n_exit falls in
#                       the timestep rst_n_enter does, with no edge between
#                     - release is synchronous: rst_n_exit only ever rises in
#                       the timestep of a rising clk edge
#
#                   Edge-sampled claims - low in reset, not released early,
#                   released on time - belong to reset_sync_sva and are not
#                   repeated here.
#
#                   No clocking block: the module is asynchronous and a
#                   clocking block can only drive relative to edges. No
#                   parameters to override - reset_sync has none.
#
#                   do_reset() differs from the template: the template's
#                   version releases reset, but here the release IS the
#                   behaviour under test, so do_reset() only asserts it and
#                   each segment releases explicitly.

# Global variables: checks_run, checks_failed - mutated by check() from every
#                   stimulus segment and the release monitor, so they are
#                   shared mutable state within the file.

*/

`timescale 1ns/1ps
`default_nettype none

module reset_sync_tb;

import pmic_types_pkg::*;

// BLKSEQ waived for this file: the edge-triggered release monitor updates
// testbench bookkeeping with blocking assignments on purpose - the value must
// be visible to the next statement in the same timestep. Simulation-only code,
// not inferred hardware.
/* verilator lint_off BLKSEQ */

// ANSI_*: terminal colour escapes for the verdict lines. Kept off any line a
//         script parses.
localparam string ANSI_RED   = "\033[1;31m";
localparam string ANSI_GREEN = "\033[1;32m";
localparam string ANSI_RESET = "\033[0m";

// TB_NAME: prefix on every log line
localparam string   TB_NAME         = "reset_sync_tb";
// CLK_PERIOD_NS: supervisor clock period, derived from the package
localparam realtime CLK_PERIOD_NS   = 1.0e9 / real'(CLK_HZ);
// WATCHDOG_NS: the whole run is ~40 clocks; this is a generous bound on it
localparam realtime WATCHDOG_NS     = 10_000.0;
// RESET_CLKS: clocks reset is held in do_reset()
localparam int      RESET_CLKS      = 3;
// DRIVE_OFFSET_NS: stimulus lands this long after an edge, so the DUT never
//                  captures a change the checker's preponed sample misses
localparam realtime DRIVE_OFFSET_NS = 3.0;
// SETTLE_NS: wait after an asynchronous drive before reading rst_n_exit -
//            long enough for the async clear to land, far short of an edge
localparam realtime SETTLE_NS       = 0.1;
// MID_CYCLE_NS: offset after an edge for the asynchronous events, clear of
//               both neighbouring edges
localparam realtime MID_CYCLE_NS    = CLK_PERIOD_NS / 4.0;

// rst_n_enter is initialised to its INACTIVE level at declaration, so the
// first assertion is a real 1 -> 0 edge. x -> 0 is not a reliable negedge and
// the DUT's async clear would never fire.
logic clk;
logic rst_n_enter = 1'b1;
logic rst_n_exit;

int unsigned checks_run    = 0;
int unsigned checks_failed = 0;

// last_posedge_ns: time of the most recent rising clk edge, read by the
//                  release monitor and the zero-latency check. No initial
//                  value: a real starts at 0.0, and the always block below
//                  is its only writer.
realtime last_posedge_ns;


// ============================================================
// DUT
// ============================================================
reset_sync u_dut (
    .clk        (clk),
    .rst_n_enter(rst_n_enter),
    .rst_n_exit (rst_n_exit)
);


/*
Purpose:
---
Free-running clock. Generates the clock and nothing else.
*/
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2.0) clk = ~clk;
end

/*
Purpose:
---
Print $time in nanoseconds.
*/
initial $timeformat(-9, 1, " ns", 10);

/*
Purpose:
---
Record a VCD only when asked. Enabled by +WAVES, which the Makefile passes
for WAVES=1.
*/
initial begin
    if ($test$plusargs("WAVES")) begin
        $dumpfile({TB_NAME, ".vcd"});
        $dumpvars(0, reset_sync_tb);
    end
end


always @(posedge clk) begin
    /*
    Purpose:
    ---
    Record when the latest rising edge happened. Blocking, in the active
    region, so it is already updated when the DUT's NBA update for the same
    edge wakes the release monitor below.
    */
    last_posedge_ns = $realtime;
end


always @(posedge rst_n_exit) begin
    /*
    Purpose:
    ---
    Sub-cycle claim: release is synchronous. Every rise of rst_n_exit must
    happen in the timestep of a rising clk edge. A DUT that followed
    rst_n_enter combinationally would rise at the release instant instead,
    which every segment places away from an edge.
    */
    check($realtime == last_posedge_ns,
          $sformatf("rst_n_exit rose at %0t, on a clock edge", $realtime));
end


// check: procedural comparison, for claims no clocked property can see
task automatic check(input bit condition, input string label);
    checks_run++;
    if (!condition) begin
        checks_failed++;
        $display("[%0t] CHECK FAIL: %s", $time, label);
    end
endtask


// do_reset: asserts reset with a genuine falling edge and holds it across
//           RESET_CLKS edges. Does NOT release - see the file header.
task automatic do_reset();
    rst_n_enter = 1'b1;
    #1;
    rst_n_enter = 1'b0;
    repeat (RESET_CLKS) @(posedge clk);
    #(DRIVE_OFFSET_NS);
endtask


// tick: advance n edges, then DRIVE_OFFSET_NS, so the next stimulus is
//       unambiguously after the edge rather than at it
task automatic tick(input int n = 1);
    repeat (n) @(posedge clk);
    #(DRIVE_OFFSET_NS);
endtask


// expect_immediate_assert: the zero-latency claim. Called just after
//                          rst_n_enter falls mid-cycle; rst_n_exit must
//                          already be low, with no clock edge since.
task automatic expect_immediate_assert(input string label);
    realtime edge_before;
    edge_before = last_posedge_ns;
    #(SETTLE_NS);
    check(rst_n_exit === 1'b0, {label, ": rst_n_exit low at once"});
    check(last_posedge_ns == edge_before, {label, ": no clock edge in between"});
endtask


// finish_run: single exit point for the normal end and the watchdog.
//             $stop on failure so the exit status is non-zero; never $fatal.
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
    if (passed) $finish;
    else        $stop;
endtask


/*
Purpose:
---
Bounds the run so a stalled testbench fails rather than hanging. Absolute
delay, so it fires even if the clock stops.
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
Drives the directed segments in order. Each puts the DUT in the state it
needs at its own top.
*/
initial begin
    $display("\n==== %s ====\n", TB_NAME);

    // ---- Segment 1: power-on reset, before any clock edge ----
    // Checker group 1 holds rst_n_exit low at every edge of the held reset;
    // this checks what it cannot see - the clear arrived with no edge at all.
    $display("[1] power-on reset");
    #1;
    rst_n_enter = 1'b0;
    expect_immediate_assert("power-on");
    tick(RESET_CLKS);

    // ---- Segment 2: release just after an edge, then hold ----
    // Covers both edges of the lower bound, the release edge and the held
    // state. The release monitor checks the rise lands on an edge.
    $display("\n[2] release just after an edge");
    do_reset();
    rst_n_enter = 1'b1;
    tick(4);

    // ---- Segment 3: release just before an edge ----
    // Latency is counted in edges, not time: a release 3 ns before an edge
    // must still take exactly two edges.
    $display("\n[3] release just before an edge");
    do_reset();
    #(CLK_PERIOD_NS - 2.0 * DRIVE_OFFSET_NS);
    rst_n_enter = 1'b1;
    tick(4);

    // ---- Segment 4: asynchronous assertion mid-operation ----
    // From the released state, between edges. Held across edges so checker
    // group 1 sees it, then released again.
    $display("\n[4] asynchronous assertion mid-operation");
    do_reset();
    rst_n_enter = 1'b1;
    tick(4);
    #(MID_CYCLE_NS - DRIVE_OFFSET_NS);
    rst_n_enter = 1'b0;
    expect_immediate_assert("mid-operation");
    tick(2);
    rst_n_enter = 1'b1;
    tick(4);

    // ---- Segment 5: degenerate input - release shorter than the chain ----
    // High across exactly one edge, then low. rst_n_exit must never rise;
    // checker group 2 fails if it does.
    $display("\n[5] release pulse too short to propagate");
    do_reset();
    rst_n_enter = 1'b1;
    tick(1);
    rst_n_enter = 1'b0;
    tick(3);

    // ---- Segment 6: narrow glitch between edges while released ----
    // Must drop at once (checked here) and return exactly two edges later
    // (checker groups 2 and 3, via the async-cleared count).
    $display("\n[6] narrow glitch between edges");
    do_reset();
    rst_n_enter = 1'b1;
    tick(4);
    #(MID_CYCLE_NS - DRIVE_OFFSET_NS);
    rst_n_enter = 1'b0;
    expect_immediate_assert("glitch");
    rst_n_enter = 1'b1;
    tick(4);

    finish_run("normal end");
end

/* verilator lint_on BLKSEQ */

endmodule

`default_nettype wire

