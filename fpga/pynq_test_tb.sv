/*

# Filename:         pynq_test_tb.sv

# File Description: Self-checking testbench for the PYNQ-Z2 harness. Drives
#                   the board's switches and buttons exactly as a person
#                   would and checks what the LEDs and PMOD pins would show:
#                   start-up and soft start, power-good, immediate OTP/UVLO
#                   shutdown, hiccup under sustained overcurrent, strike
#                   latch-off, and recovery through reset plus latch clear.
#                   This is the same sequence to repeat by hand on the board.
#
#                   Built with USE_MMCM = 0, so sysclk is driven at 50 MHz and
#                   no unisim models are needed. About 60 ms of simulated
#                   time; in xsim run it with "run all".

# Global variables: checks_run, checks_failed - mutated by check() from every
#                   scenario.

*/

`default_nettype none
`timescale 1ns/1ps

module pynq_test_tb;

    // CLK_PERIOD_NS: 50 MHz, matching CLK_HZ in pmic_types_pkg
    localparam realtime CLK_PERIOD_NS = 20.0;

    logic       clk = 1'b0;
    logic [1:0] sw;
    logic [3:0] btns;
    logic [3:0] leds;
    logic       led4_b, led5_g;
    logic [7:0] ja;

    // Named views of the board outputs
    logic en, pgood, latch_out, pwm_out, osc;
    assign en        = leds[0];
    assign pgood     = leds[1];
    assign latch_out = leds[2];
    assign pwm_out   = ja[1];
    assign osc       = ja[0];

    int checks_run    = 0;
    int checks_failed = 0;

    always #(CLK_PERIOD_NS/2.0) clk = ~clk;

    pynq_test_top #(.USE_MMCM(1'b0)) dut (
        .sysclk (clk),
        .sw     (sw),
        .btns   (btns),
        .leds   (leds),
        .led4_b (led4_b),
        .led5_g (led5_g),
        .ja     (ja)
    );


    /*
    Purpose:
    ---
    Count one check, and report it. Failures are reported with $error so they
    stand out in the log, but the run continues so every failure is seen.
    */
    function automatic void check(input bit ok, input string label);
        checks_run++;
        if (ok) $display("[%8.3f ms] PASS  %s", $realtime/1.0e6, label);
        else begin
            checks_failed++;
            $error("[%8.3f ms] FAIL  %s", $realtime/1.0e6, label);
        end
    endfunction


    /*
    Purpose:
    ---
    Select a board output by name. The tasks below take a selector rather
    than a ref argument, which Icarus does not support. Every output is
    driven from the clk domain, so sampling on clk edges loses nothing.
    */
    typedef enum {SIG_EN, SIG_PGOOD, SIG_LATCH, SIG_PWM, SIG_OSC} sig_t;

    function automatic logic get(input sig_t s);
        case (s)
            SIG_EN:    return en;
            SIG_PGOOD: return pgood;
            SIG_LATCH: return latch_out;
            SIG_PWM:   return pwm_out;
            default:   return osc;
        endcase
    endfunction


    /*
    Purpose:
    ---
    Wait up to tmax for a signal to reach val, then check that it did.
    */
    task automatic expect_within(input sig_t s, input logic val,
                                 input realtime tmax, input string label);
        realtime t0;
        t0 = $realtime;
        while (get(s) !== val && ($realtime - t0) < tmax) @(posedge clk);
        check(get(s) === val, label);
    endtask


    /*
    Purpose:
    ---
    Measure the next complete high pulse on a signal, in clk cycles.
    */
    task automatic pulse_width(input sig_t s, output int width);
        while (get(s) === 1'b1) @(posedge clk);   // skip a pulse already in progress
        while (get(s) !== 1'b1) @(posedge clk);
        width = 0;
        while (get(s) === 1'b1) begin
            @(posedge clk);
            width++;
        end
    endtask


    /*
    Purpose:
    ---
    A button press as a person makes one: asynchronous to clk, held for a
    few microseconds.
    */
    task automatic press(input int idx);
        btns[idx] = 1'b1;
        #(3_000);
        btns[idx] = 1'b0;
    endtask


    initial begin
        int w_pwm, w_osc;

        // SW1 up (reset), everything else off
        sw   = 2'b10;
        btns = 4'b0000;
        #(1_000);

        //////////////////////////////////////////////////////////
        $display("\n[1] Reset and enable switch");
        check(en === 1'b0, "En low while SW1 holds reset");
        sw[1] = 1'b0;
        #(2_000);
        check(en === 1'b0, "En low after reset release with SW0 off");

        //////////////////////////////////////////////////////////
        $display("\n[2] Start-up and soft start");
        sw[0] = 1'b1;
        expect_within(SIG_EN, 1'b1, 2_000, "En rises after SW0 on");
        pulse_width(SIG_PWM, w_pwm);
        pulse_width(SIG_OSC, w_osc);
        $display("      early soft start: PWM_out %0d clk, Osc_in %0d clk", w_pwm, w_osc);
        check(w_pwm < w_osc, "soft start truncates PWM_out below Osc_in");

        //////////////////////////////////////////////////////////
        $display("\n[3] Power good");
        expect_within(SIG_PGOOD, 1'b1, 20_000_000, "PGOOD asserts within 20 ms");
        pulse_width(SIG_PWM, w_pwm);
        pulse_width(SIG_OSC, w_osc);
        $display("      running: PWM_out %0d clk, Osc_in %0d clk", w_pwm, w_osc);
        check(w_pwm == w_osc, "PWM_out passes Osc_in unchanged once running");

        //////////////////////////////////////////////////////////
        $display("\n[4] OTP and UVLO shut down immediately");
        @(negedge clk) btns[1] = 1'b1;
        expect_within(SIG_EN,    1'b0, 10*CLK_PERIOD_NS, "OTP: En low within 10 clk");
        expect_within(SIG_PGOOD, 1'b0, 10*CLK_PERIOD_NS, "OTP: PGOOD low within 10 clk");
        btns[1] = 1'b0;
        expect_within(SIG_EN, 1'b1, 20_000, "OTP released: soft start again");

        @(negedge clk) btns[2] = 1'b1;
        expect_within(SIG_EN, 1'b0, 10*CLK_PERIOD_NS, "UVLO: En low within 10 clk");
        btns[2] = 1'b0;
        expect_within(SIG_EN, 1'b1, 20_000, "UVLO released: soft start again");

        expect_within(SIG_PGOOD, 1'b1, 20_000_000, "back to PGOOD before overcurrent test");

        //////////////////////////////////////////////////////////
        $display("\n[5] Sustained overcurrent: hiccup, then latch-off");
        btns[0] = 1'b1;
        expect_within(SIG_EN, 1'b0, 200_000, "overcurrent trips the fault window");
        #(5_000_000);
        check(en === 1'b0, "En still low 5 ms into the hiccup cool-down");
        check(latch_out === 1'b0, "not latched after the first strike");
        expect_within(SIG_LATCH, 1'b1, 50_000_000, "latch_out after MAX_STRIKES hiccups");
        @(posedge clk);
        @(posedge clk);
        check(dut.scr_q === 1'b1, "fake SCR latch is set");
        check(en === 1'b0, "En low while latched");

        //////////////////////////////////////////////////////////
        $display("\n[6] Recovery: reset, then clear the latch");
        btns[0] = 1'b0;
        sw[1]   = 1'b1;
        #(1_000);
        sw[1]   = 1'b0;
        #(20_000);
        check(latch_out === 1'b0, "reset clears latch_out");
        check(en === 1'b0, "still off: the SCR latch survives reset");
        press(3);
        expect_within(SIG_EN, 1'b1, 20_000, "BTN3 clears the latch and the converter restarts");

        //////////////////////////////////////////////////////////
        $display("\n=== %0d checks, %0d failures ===", checks_run, checks_failed);
        if (checks_failed == 0) begin
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
