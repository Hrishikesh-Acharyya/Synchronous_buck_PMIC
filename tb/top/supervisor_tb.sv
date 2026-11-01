/*

# Filename:         supervisor_tb.sv

# File Description: Directed, self-checking testbench for the supervisor FSM.
#                   Verifies reset behaviour (synchronous entry and asynchronous
#                   assertion mid-operation), the nominal start-up sequence,
#                   soft-start hold until SS_done, hiccup entry and retry from
#                   both S_SS and S_RUN, every fault's ability to force S_OFF
#                   and to inhibit start-up, and fault priority when multiple
#                   triggers assert on the same clock edge. Every comparison is
#                   counted; the run ends with a pass/fail verdict and calls
#                   $fatal on failure so the exit status reports the result
#                   without log parsing.

# Global variables: checks_run, checks_failed - mutated by check() from every
#                   test group, so they are shared mutable state within the file.

*/


`default_nettype none
`timescale 1ns/1ps

module supervisor_tb;

    import pmic_types_pkg::*;


    // CLK_PERIOD_NS: 50Mhz clock gives 20 nanosecond period. This is used to generate the clock in the testbench
    localparam realtime CLK_PERIOD_NS = 20.0;

    logic clk = 1'b0;
    logic rst_n; //reset signal
    logic g_en, SS_done; //global enable and soft start done signal
    logic latch_state, OTP, latch_assert, UVLO; //Fault signals
    logic en; //output enable signal of DUT
    logic window_trip_SS, window_trip; //window trip Hiccup signals
    logic hiccup_done;
    logic ss_active, run_active, hiccup_active;

    // checks_run: Number of checks run in the testbench
    int checks_run = 0; 
    // checks_failed: Number of checks failed in the testbench
    int checks_failed = 0;


    /*
    Purpose: Generate the 50 Mhz clock for the testbench
    */
    always begin
         #(CLK_PERIOD_NS/2.0) clk = ~clk;
    end

    supervisor DUT(
        .clk(clk),
        .rst_n(rst_n),
        .g_en(g_en),
        .SS_done(SS_done),
        .latch_state(latch_state),
        .OTP(OTP),
        .latch_assert(latch_assert),
        .UVLO(UVLO),
        .en(en),
        .window_trip_SS(window_trip_SS),
        .window_trip(window_trip),
        .hiccup_active(hiccup_active),
        .hiccup_done(hiccup_done),
        .ss_active(ss_active),
        .run_active(run_active)
    );

    /*
    Purpose:
    1. Create a clocking block to synchronize the signals with the clock
    2. Set the default input and output delays for the signals in the clocking block
    3. Define when the tb drives stimulus and when it reads in relation to the clock edge
    4. inputs sampled before the edge so checks can't race the DUT's non-blocking updates, outputs 
    driven after it so the DUT never sees a change at its own capture edge.
    */
    default clocking cb @(posedge clk);
        default input #1step output #2ns;

        output g_en, SS_done;
        output OTP, UVLO, latch_state, latch_assert;
        output window_trip, window_trip_SS;
        output hiccup_done;

        input  en;
        input ss_active, run_active, hiccup_active;
    endclocking

    /*
    Purpose:
    ---
    Advances the simulation by n clock cycles. The clocking block handles
    sampling and drive timing, so no settling delay is needed here.
    */
    task automatic tick(input int n = 1);
        ##(n);
    endtask 


    /*
    Purpose:
    ---
    Compares the DUT's current state and enable output against expected values,
    logs the outcome, and maintains the pass/fail tallies. Both fields are
    checked independently so a state mismatch does not mask an output mismatch.
    */
    function automatic void check(input state_t exp_state,
                                  input logic exp_en,
                                  input string label);

        // failed: Set by either comparison so the failure is counted once.
        logic failed = 1'b0;

        checks_run++;

        if(DUT.state !== exp_state) begin

            failed = 1'b1;
            $error(" %s : expected state: %s, got: %s", label, exp_state.name(), DUT.state.name());

        end

        if(en !== exp_en) begin

            failed = 1'b1;
            $error(" %s : expected en: %b, got: %b", label, exp_en, en);

        end 

        if(failed) 
            checks_failed++;
        else
            $display(" %s : PASSED", label);

    endfunction


    /*
    Purpose:
    ---
    Drives all inputs inactive and applies an asynchronous reset, leaving the
    FSM in S_OFF. rst_n is driven directly rather than through the clocking
    block because it is asynchronous by design and must be testable as such.
    */

    task automatic do_reset();
        cb.g_en <= 1'b0;
        cb.SS_done <= 1'b0;
        cb.OTP <= 1'b0;
        cb.UVLO <= 1'b0;
        cb.latch_state <= 1'b0;
        cb.latch_assert <= 1'b0;
        cb.window_trip <= 1'b0;
        cb.window_trip_SS <= 1'b0;
        cb.hiccup_done<= 1'b0;

        rst_n = 1'b0;
        tick(2);
        rst_n = 1'b1;
        tick(1);

    endtask

    /*
    Purpose:
    ---
    Drives the nominal start-up sequence: enable, then complete the soft-start
    ramp, leaving the FSM in S_RUN.
    */
    task automatic goto_run();
        cb.g_en    <= 1'b1;
        tick(1);
        cb.SS_done <= 1'b1;
        tick(1);
    endtask


    /*
    Purpose:
    ---
    Opens the VCD and records the full testbench hierarchy for post-run
    waveform inspection.
    */
    initial begin
        $dumpfile("supervisor.vcd");
        $dumpvars(0, supervisor_tb);
    end


    /*
    Purpose:
    ---
    Bounds the run so a non-advancing FSM fails rather than hanging the
    simulator. Uses an absolute delay so it fires even if the clock stops.
    */
    initial begin
        #100us;
        $error("timeout - simulation did not complete");
        $fatal(1, "timeout");
    end


    /*
    Purpose:
    ---
    Runs the directed test groups in order and reports the final verdict.
    */
    initial begin

        $display("\n==== Supervisor FSM Testbench ====\n");

        //Insert testgroups here

        ///// Group1 /////////////////////////////////////

        $display("[1] reset");
        do_reset();
        check(S_OFF, 1'b0, "reset -> S_OFF");

        cb.g_en <= 1'b1;
        tick(1);
        check(S_SS, 1'b1, "S_OFF -> S_SS on g_en");

        ///////////////////////////////////////////////////


        ////// Group 2 /////////////////////////////////////////////

        $display("\n[2] soft start must HOLD until SS_done");
        do_reset();
        cb.g_en <= 1'b1;
        cb.SS_done <= 1'b0;
        tick(6);
        check(S_SS,1'b1, "S_SS holds until SS_done for 5 clock edge");
        cb.SS_done <= 1'b1;
        tick(1);
        check(S_RUN,1'b1, "S_SS -> S_RUN on SS_done");

        ////////////////////////////////////////////////////////

        ////// Group 3 /////////////////////////////////////////////
        $display("\n[3] hiccup retry");
        do_reset();
        goto_run();
        check(S_RUN,1'b1, "In S_RUN after startup sequence");
        cb.window_trip <= 1'b1;
        tick(1);
        check(S_HICCUP,1'b0, "S_RUN -> S_HICCUP on window_trip");
        cb.window_trip <= 1'b0;        
        cb.SS_done <= 1'b0;
        tick(5);
        check(S_HICCUP, 1'b0, "S_HICCUP holds while hiccup_done low");
        cb.hiccup_done <= 1'b1;
        tick(1);
        check(S_SS, 1'b1, "S_HICCUP -> S_SS once hiccup_done");
        cb.hiccup_done <= 1'b0;
        ////////////////////////////////////////////////////////


        ////// Group 4 /////////////////////////////////////////////
        $display("\n[4] fault window during soft start");
        do_reset();
        cb.g_en <= 1'b1;
        tick(1);
        check(S_SS, 1'b1, "In S_SS after g_en");
        cb.window_trip_SS <= 1'b1;
        tick(1);
        check(S_HICCUP, 1'b0, "S_SS -> S_HICCUP on window_trip_SS");
        cb.window_trip_SS <= 1'b0;
        cb.SS_done <= 1'b0;
        tick(5);
        check(S_HICCUP, 1'b0, "S_HICCUP holds while hiccup_done low");
        cb.hiccup_done <= 1'b1;
        tick(1);
        check(S_SS, 1'b1, "S_HICCUP -> S_SS once hiccup_done");
        cb.hiccup_done <= 1'b0;
        ////////////////////////////////////////////////////////


        ////// Group 5 /////////////////////////////////////////////
        $display("\n[5] latch_assert must stop the FSM from every state");

        // From S_SS
        do_reset();
        cb.g_en <= 1'b1;
        tick(1);
        cb.latch_assert <= 1'b1;
        tick(1);
        check(S_OFF, 1'b0, "S_SS -> S_OFF on latch_assert");
        cb.latch_assert <= 1'b0;
        tick(1);
        check(S_SS, 1'b1, "release from S_SS trip re-enters S_SS");

        // From S_RUN
        do_reset();
        goto_run();
        cb.latch_assert <= 1'b1;
        tick(1);
        check(S_OFF, 1'b0, "S_RUN -> S_OFF on latch_assert");
        cb.latch_assert <= 1'b0;
        cb.SS_done      <= 1'b0;
        tick(1);
        check(S_SS, 1'b1, "release re-enters S_SS, not S_RUN");

        // From S_HICCUP
        do_reset();
        goto_run();
        cb.window_trip <= 1'b1;
        tick(1);
        check(S_HICCUP, 1'b0, "in S_HICCUP before latch_assert");
        cb.latch_assert <= 1'b1;
        tick(1);
        check(S_OFF, 1'b0, "S_HICCUP -> S_OFF on latch_assert");
        cb.latch_assert <= 1'b0;
        cb.window_trip  <= 1'b0;
        cb.SS_done      <= 1'b0;
        tick(1);
        check(S_SS, 1'b1, "release from hiccup trip re-enters S_SS");

        do_reset(); 
        goto_run();
        cb.window_trip <= 1'b1; tick(1);
        cb.window_trip <= 1'b0;
        cb.hiccup_done <= 1'b1;
        cb.latch_assert <= 1'b1;
        tick(1);
        check(S_OFF, 1'b0, "latch_assert takes priority over hiccup_done");
        cb.hiccup_done <= 1'b0; cb.latch_assert <= 1'b0;

        ////////////////////////////////////////////////////////

        ////// Group 6 /////////////////////////////////////////////
        $display("\n[6] every fault stops S_RUN");
        do_reset(); goto_run(); cb.OTP <= 1'b1; tick(1);
        check(S_OFF, 1'b0, "OTP -> S_OFF");
        do_reset(); goto_run(); cb.UVLO <= 1'b1; tick(1);
        check(S_OFF, 1'b0, "UVLO -> S_OFF");
        do_reset(); goto_run(); cb.latch_state <= 1'b1; tick(1);
        check(S_OFF, 1'b0, "latch_state -> S_OFF");
        do_reset(); goto_run(); cb.g_en <= 1'b0; tick(1);
        check(S_OFF, 1'b0, "g_en deasserted -> S_OFF");

        ////////////////////////////////////////////////////////



        /////// Group 7 ///////////////////////////////////////////// 
        $display("\n[7] faults block start up");
        do_reset(); cb.g_en <= 1'b1; cb.OTP <= 1'b1; tick(1);
        check(S_OFF, 1'b0, "OTP blocks S_OFF -> S_SS");
        do_reset(); cb.g_en <= 1'b1; cb.latch_state <= 1'b1; tick(1);
        check(S_OFF, 1'b0, "latch_state blocks start up");
        do_reset(); cb.g_en <= 1'b1; cb.UVLO <= 1'b1; tick(1);
        check(S_OFF, 1'b0, "UVLO blocks start up");
        do_reset(); cb.g_en <= 1'b1; cb.latch_assert <= 1'b1; tick(1);
        check(S_OFF, 1'b0, "latch_assert blocks start up");

        ////////////////////////////////////////////////////////


        /////// Group 8 /////////////////////////////////////////////
        $display("\n[8] reset assertion mid operation");
        do_reset();
        goto_run();
        check(S_RUN, 1'b1, "in S_RUN before reset");

        #(CLK_PERIOD_NS/4.0) rst_n = 1'b0; //assert right between clock edges(async)
        #1; //let async NBA update land
        check(S_OFF, 1'b0, "S_RUN -> S_OFF on reset assertion without clock edge");

        #(CLK_PERIOD_NS/4.0) rst_n = 1'b1; //release reset
        cb.SS_done <= 1'b0; //make sure we don't skip S_SS on release
        tick(1);
        check(S_SS, 1'b1, "release re-enters S_SS");

        ////////////////////////////////////////////////////////////   


        ///// Group 9 /////////////////////////////////////////////
        $display("\n[9] simultaneous fault check");
        do_reset();
        goto_run();
        cb.OTP <= 1'b1;
        cb.UVLO <= 1'b1;
        tick(1);
        check(S_OFF, 1'b0, "S_RUN -> S_OFF on simultaneous OTP and UVLO");

        do_reset(); 
        goto_run();
        cb.window_trip  <= 1'b1;
        cb.latch_assert <= 1'b1;
        tick(1);
        check(S_OFF, 1'b0, "latch_assert takes priority over window_trip");

        do_reset();
        cb.g_en <= 1'b1;
        tick(1);
        check(S_SS, 1'b1, "in S_SS before simultaneous faults");
        cb.window_trip_SS <= 1'b1;
        cb.SS_done <= 1'b1;
        tick(1);
        check(S_HICCUP, 1'b0, "window_trip_SS takes priority over SS_done");

        //////////////////////////////////////////////////////////

        $display("\n=== %0d checks, %0d failures ===", checks_run, checks_failed);
        if(checks_failed == 0) begin
            $display("\n==== Result: PASSED ====\n");
            $finish;
            
        end

        else begin
            $display("\n==== Result: FAILED ====\n");
             $fatal(1, "%0d check(s) failed", checks_failed);
        end



    end


endmodule 


`default_nettype wire

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
localparam realtime DRIVE_OFFSET_NS = 3.0;
// SETTLE_NS: delay after a mid-cycle reset before the procedural checks
//            read sync_out. Small enough to stay inside the clock period,
//            so the check observes the asynchronous clear and not the next
//            clock edge.
localparam realtime SETTLE_NS       = 0.1;
// Asynchronous inputs are initialised to their inactive level at
// declaration. An uninitialised logic driven straight to its active level
// transitions x -> 0, which is not a reliable negedge, so the DUT's async
// clear never fires and both flops hold x until the first clock edge.



// Asynchronous inputs are initialised to their INACTIVE level at
// declaration. An uninitialised logic driven straight to its active level
// transitions x -> 0, which is not a reliable negedge, so an async clear
// in the DUT never fires and the flops sit at x until the first clock edge.
logic clk;
logic rst_n = 1'b1;

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

