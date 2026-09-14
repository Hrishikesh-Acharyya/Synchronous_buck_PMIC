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
        .window_trip(window_trip)
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

        input  en;
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
        tick(1);
        check(S_SS, 1'b1, "S_HICCUP -> S_SS (retry re-ramps)");
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
        tick(1);
        check(S_SS, 1'b1, "S_HICCUP -> S_SS (retry re-ramps)");
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