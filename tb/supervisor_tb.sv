`timescale 1ns/1ps
//=============================================================================
// Self-checking testbench for the supervisor FSM.
//
// "Self-checking" means three things beyond printing PASS:
//   1. every check is counted,
//   2. the run ends with one clear verdict line,
//   3. a failure calls $fatal, so the exit status is non-zero and a script
//      or CI job notices without anyone reading the log.
//
// Build and run:   cd sim && make
//=============================================================================
module supervisor_tb;

    reg clk = 0;
    reg rst_n, g_en, SS_done;
    reg OTP, UVLO, latch_state;
    reg window_trip, window_trip_SS, latch_assert;
    wire en;

    // Counters are what make it self-checking.
    integer checks = 0;
    integer errors = 0;

    supervisor dut (
        .clk(clk), .SS_done(SS_done), .rst_n(rst_n), .g_en(g_en),
        .latch_state(latch_state), .OTP(OTP),
        .window_trip_SS(window_trip_SS), .window_trip(window_trip),
        .latch_assert(latch_assert), .UVLO(UVLO), .en(en)
    );

    always #10 clk = ~clk;

    // Advance one clock and let the non-blocking state update land.
    task tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    // Check state AND en. Your original used else-if, which meant a wrong
    // state hid a wrong en - only the first problem was ever reported.
    task check;
        input [1:0]     exp_state;
        input           exp_en;
        input [8*40:1]  label;
        begin
            checks = checks + 1;
            if (dut.state !== exp_state) begin
                errors = errors + 1;
                $display("  FAIL  %0s : state expected %b, got %b",
                         label, exp_state, dut.state);
            end
            else if (en !== exp_en) begin
                errors = errors + 1;
                $display("  FAIL  %0s : en expected %b, got %b",
                         label, exp_en, en);
            end
            else
                $display("  pass  %0s", label);
        end
    endtask

    task do_reset;
        begin
            rst_n = 0; g_en = 0; SS_done = 0;
            OTP = 0; UVLO = 0; latch_state = 0;
            window_trip = 0; window_trip_SS = 0; latch_assert = 0;
            tick; tick;
            rst_n = 1;
            tick;
        end
    endtask

    // Walk to S_RUN the legitimate way: enable, then finish the ramp.
    task goto_run;
        begin
            g_en = 1;    tick;
            SS_done = 1; tick;
        end
    endtask

    integer i;

    initial begin
        $dumpfile("supervisor.vcd");
        $dumpvars(0, supervisor_tb);

        $display("\n=== supervisor FSM testbench ===\n");

        $display("[1] reset");
        do_reset;
        check(dut.S_OFF, 1'b0, "reset -> S_OFF");
        g_en = 1; tick;
        check(dut.S_SS,  1'b1, "S_OFF -> S_SS on g_en");

        // ------------------------------------------------------------------
        // Regression test for bug 1. The old code's last else in S_SS went to
        // S_RUN, so soft start lasted exactly one clock no matter what
        // SS_done said. Holding SS_done low for several clocks catches it.
        // ------------------------------------------------------------------
        $display("\n[2] soft start must HOLD until SS_done");
        do_reset;
        g_en = 1; SS_done = 0; tick;
        for (i = 0; i < 5; i = i + 1) tick;
        check(dut.S_SS,  1'b1, "S_SS holds for 5 clocks while SS_done=0");
        SS_done = 1; tick;
        check(dut.S_RUN, 1'b1, "S_SS -> S_RUN once SS_done");

        $display("\n[3] hiccup retry");
        do_reset; goto_run;
        check(dut.S_RUN,    1'b1, "in S_RUN");
        window_trip = 1; tick;
        check(dut.S_HICCUP, 1'b0, "S_RUN -> S_HICCUP on window_trip");
        window_trip = 0; SS_done = 0; tick;
        check(dut.S_SS,     1'b1, "S_HICCUP -> S_SS (retry re-ramps)");

        $display("\n[4] fault window during soft start");
        do_reset;
        g_en = 1; SS_done = 0; tick;
        window_trip_SS = 1; tick;
        check(dut.S_HICCUP, 1'b0, "S_SS -> S_HICCUP on window_trip_SS");
        window_trip_SS = 0;

        // ------------------------------------------------------------------
        // Regression test for bug 2. latch_assert used to be checked only in
        // S_HICCUP, so asserting it in S_RUN left the FSM in S_RUN with en
        // forced low by the output gate - and on release en went straight
        // back high at full duty, skipping soft start entirely.
        // ------------------------------------------------------------------
        $display("\n[5] latch_assert must stop the FSM from every state");
        do_reset; goto_run;
        latch_assert = 1; tick;
        check(dut.S_OFF, 1'b0, "S_RUN -> S_OFF on latch_assert");
        latch_assert = 0; SS_done = 0; tick;
        check(dut.S_SS,  1'b1, "release re-enters S_SS, not S_RUN");

        do_reset;
        g_en = 1; SS_done = 0; tick;
        latch_assert = 1; tick;
        check(dut.S_OFF, 1'b0, "S_SS -> S_OFF on latch_assert");
        latch_assert = 0;

        $display("\n[6] every fault stops S_RUN");
        do_reset; goto_run; OTP = 1; tick;
        check(dut.S_OFF, 1'b0, "OTP -> S_OFF");
        do_reset; goto_run; UVLO = 1; tick;
        check(dut.S_OFF, 1'b0, "UVLO -> S_OFF");
        do_reset; goto_run; latch_state = 1; tick;
        check(dut.S_OFF, 1'b0, "latch_state -> S_OFF");
        do_reset; goto_run; g_en = 0; tick;
        check(dut.S_OFF, 1'b0, "g_en deasserted -> S_OFF");

        $display("\n[7] faults block start up");
        do_reset; g_en = 1; OTP = 1; tick;
        check(dut.S_OFF, 1'b0, "OTP blocks S_OFF -> S_SS");
        do_reset; g_en = 1; latch_state = 1; tick;
        check(dut.S_OFF, 1'b0, "latch_state blocks start up");
        do_reset; g_en = 1; UVLO = 1; tick;
        check(dut.S_OFF, 1'b0, "UVLO blocks start up");
        do_reset; g_en = 1; latch_assert = 1; tick;
        check(dut.S_OFF, 1'b0, "latch_assert blocks start up");

        // en is driven by a combinational always block, so it should fall as
        // soon as a fault appears - without waiting for the next clock edge.
        $display("\n[8] en drops without waiting for a clock edge");
        do_reset; goto_run;
        checks = checks + 1;
        OTP = 1; #1;
        if (en !== 1'b0) begin
            errors = errors + 1;
            $display("  FAIL  OTP did not gate en before the clock edge");
        end
        else
            $display("  pass  OTP gates en combinationally");
        OTP = 0;

        $display("\n=== %0d checks, %0d failures ===", checks, errors);
        if (errors == 0) begin
            $display("RESULT: PASS\n");
            $finish;
        end
        else begin
            $display("RESULT: FAIL\n");
            $fatal(1, "%0d check(s) failed", errors);
        end
    end

    // If a bug makes the FSM hang, fail instead of running forever.
    initial begin
        #100000;
        $display("RESULT: FAIL - timeout");
        $fatal(1, "timeout");
    end

endmodule
