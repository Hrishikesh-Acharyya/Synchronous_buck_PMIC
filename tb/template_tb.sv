/*

# Filename:         tb_template.sv

# File Description: Skeleton for a directed Verilator testbench. Copy to
#                   tb/<group>/<module>_tb.sv, rename the module, set TB_NAME,
#                   fill the DUT section and the stimulus segments. Carries the
#                   clock, reset, watchdog, verdict and VCD plumbing that every
#                   testbench needs and none of them should re-derive.
#
#                   Checking is split: invariants and temporal claims live in
#                   the bound checker under sva/, and check() below is for the
#                   claims SVA cannot see - sub-cycle behaviour and anything
#                   needing a reference model. The verdict reads both tallies.
#
#                   Every <ANGLE_BRACKET> marker is a place to edit.

# Global variables: checks_run, checks_failed - mutated by check() from every
#                   stimulus segment, so they are shared mutable state within
#                   the file.

*/

`timescale 1ns/1ps
`default_nettype none

module <MODULE>_tb;

    import pmic_types_pkg::*;

    // ============================================================
    // Testbench constants
    // ============================================================
    // TB_NAME: prefix on every log line, so output is attributable when
    //          several testbenches run in one session
    localparam string   TB_NAME         = "<MODULE>_tb";
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

    // ============================================================
    // Signals
    // ============================================================
    // Asynchronous inputs are initialised to their INACTIVE level at
    // declaration. An uninitialised logic driven straight to its active level
    // transitions x -> 0, which is not a reliable negedge, so an async clear
    // in the DUT never fires and the flops sit at x until the first clock edge.
    logic clk;
    logic rst_n = 1'b1;

    // <DUT inputs and outputs here>

    int unsigned checks_run    = 0;
    int unsigned checks_failed = 0;

    // ============================================================
    // DUT
    // ============================================================
    // <MODULE> #(.<PARAM>(<VALUE>)) u_dut (
    //     .clk     (clk),
    //     .rst_n   (rst_n),
    //     ...
    // );

    // ============================================================
    // Infrastructure
    // ============================================================

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
            $dumpvars(0, <MODULE>_tb);
        end
    end

    // check: procedural comparison, for claims no clocked property can see -
    //        sub-cycle behaviour, and anything needing a computed expected
    //        value. Invariants and temporal claims belong in the bound checker.
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
        $display("--------------------------------------------------");
        $display("%s exit     : %s", TB_NAME, reason);
        $display("procedural      : %0d run, %0d failed",
                 checks_run, checks_failed);
        $display("assertion fails : %0d", sva_pkg::sva_failures);
        if (checks_failed == 0 && sva_pkg::sva_failures == 0)
            $display("%s: PASS  (check cover hits before trusting this)", TB_NAME);
        else
            $display("%s: FAIL", TB_NAME);
        $display("--------------------------------------------------");
        $finish;
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

        do_reset();

        // ---- Segment 1: <what this makes happen> ----
        // <stimulus>

        // ---- Segment 2: <...> ----
        // <stimulus>

        finish_run("normal end");
    end

endmodule

`default_nettype wire