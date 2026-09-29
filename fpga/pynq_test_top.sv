/*

# Filename:         pynq_test_top.sv

# File Description: PYNQ-Z2 hardware test harness for the CPLD supervisor.
#                    Wraps pmic_top unchanged and stands in for the analog
#                    side of the converter, so the supervisor can be
#                    exercised on the board by hand:
#
#                      - MMCM turns the 125 MHz board clock into the 50 MHz
#                        CLK_HZ the package assumes
#                      - a counter generates the 450 kHz master PWM that the
#                        analog modulator would normally supply on Osc_in
#                      - switches and buttons play the fault comparators
#                      - a flop plays the SCR protection latch
#                      - LEDs and PMOD JA show the supervisor outputs
#
#                    Board mapping:
#                      SW0  en_from_switch        LD0  En
#                      SW1  reset (up = held)     LD1  PGOOD
#                      BTN0 CP_trig (overcurrent) LD2  latch_out
#                      BTN1 OTP_trig              LD3  PWM_out
#                      BTN2 UVLO_trig             LD4 blue  200 ms flash on every En drop
#                      BTN3 clear the fake latch  LD5 green MMCM locked
#                      JA0..5  Osc_in, PWM_out, En, PGOOD, latch_out, CP_trig

# Global variables: None

*/

`default_nettype none

module pynq_test_top #(
    // USE_MMCM: 1 on hardware. 0 in simulation, where sysclk is driven at
    //           50 MHz directly and no unisim models are needed.
    parameter bit USE_MMCM = 1'b1,
    // DUTY_PCT: duty of the generated master PWM. 40% is roughly 5 V out of
    //           12 V in; set above 75 to watch pwm_mask clamp it.
    parameter int DUTY_PCT = 40
) (
    input  wire logic       sysclk,   // 125 MHz on H16 (50 MHz when USE_MMCM = 0)
    input  wire logic [1:0] sw,
    input  wire logic [3:0] btns,
    output logic      [3:0] leds,
    output logic            led4_b,
    output logic            led5_g,
    output logic      [7:0] ja
);

    import pmic_types_pkg::*;

    // PWM_ON_COUNTS: high time of the generated master PWM, in clk counts
    localparam int PWM_ON_COUNTS = duty_to_counts(DUTY_PCT);
    // STRETCH_CLKS: how long LD4 stays lit after En drops, so that 5-20 ms
    //               hiccups are visible to the eye
    localparam int STRETCH_CLKS  = ms_to_clks(200);

    logic clk;
    logic mmcm_locked;


    // ============================================================
    // Clock: 125 MHz -> 50 MHz
    // ============================================================
    /*
    VCO = 125 MHz * 8 = 1000 MHz, inside the 600-1200 MHz range of a -1
    part; CLKOUT0 = 1000 / 20 = 50 MHz. Primitive rather than Clocking
    Wizard IP so the harness is plain text and rebuilds from git.
    */
    generate
        if (USE_MMCM) begin : g_mmcm
            logic clk_mmcm, clkfb;

            MMCME2_BASE #(
                .CLKIN1_PERIOD    (8.000),
                .DIVCLK_DIVIDE    (1),
                .CLKFBOUT_MULT_F  (8.000),
                .CLKOUT0_DIVIDE_F (20.000)
            ) u_mmcm (
                .CLKIN1   (sysclk),
                .CLKFBIN  (clkfb),
                .CLKFBOUT (clkfb),
                .CLKOUT0  (clk_mmcm),
                .LOCKED   (mmcm_locked),
                .PWRDWN   (1'b0),
                .RST      (1'b0),
                .CLKFBOUTB(),
                .CLKOUT0B (),
                .CLKOUT1  (), .CLKOUT1B(),
                .CLKOUT2  (), .CLKOUT2B(),
                .CLKOUT3  (), .CLKOUT3B(),
                .CLKOUT4  (),
                .CLKOUT5  (),
                .CLKOUT6  ()
            );

            BUFG u_bufg (.I(clk_mmcm), .O(clk));
        end
        else begin : g_no_mmcm
            assign clk         = sysclk;
            assign mmcm_locked = 1'b1;
        end
    endgenerate


    // ============================================================
    // Stand-ins for the analog side
    // ============================================================

    // pwm_cnt: position within the switching period, 0 .. CLKS_PER_SW-1
    logic [$clog2(CLKS_PER_SW)-1:0] pwm_cnt = '0;
    (* mark_debug = "true" *) logic osc_pwm = 1'b0;

    always_ff @(posedge clk) begin
    /*
    Purpose:
    ---
    Free-running 450 kHz master PWM, registered so Osc_in never glitches.
    Runs regardless of reset, like the analog oscillator it replaces.
    */
        pwm_cnt <= (pwm_cnt == CLKS_PER_SW-1) ? '0 : pwm_cnt + 1'b1;
        osc_pwm <= (pwm_cnt < PWM_ON_COUNTS);
    end


    // btn3_sync: latch-clear button, synchronised. Reset only by the MMCM,
    //            so it still works while SW1 holds the supervisor in reset.
    logic btn3_sync;
    input_sync u_btn3_sync (.clk(clk), .rst_n(mmcm_locked), .async_in(btns[3]), .sync_out(btn3_sync));

    // scr_q: the SCR protection latch. Set by the supervisor's latch_out,
    //        cleared only by BTN3 - deliberately not by SW1, because the
    //        real SCR does not care whether the CPLD has been reset.
    (* mark_debug = "true" *) logic scr_q = 1'b0;
    (* mark_debug = "true" *) logic latch_out;

    always_ff @(posedge clk) begin
        if (latch_out)      scr_q <= 1'b1;
        else if (btn3_sync) scr_q <= 1'b0;
    end


    // en_q: En delayed one clk. Doubles as the fake output-rail comparator
    //       (the rail is good while the power stage is enabled) and as the
    //       falling-edge detector for the LD4 flash.
    (* mark_debug = "true" *) logic En;
    logic en_q = 1'b0;
    always_ff @(posedge clk) en_q <= En;


    // ============================================================
    // Device under test
    // ============================================================

    (* mark_debug = "true" *) logic PWM_out;
    (* mark_debug = "true" *) logic PGOOD;

    pmic_top u_pmic (
        .clk            (clk),
        .rst_n_pin      (mmcm_locked & ~sw[1]),
        .Osc_in         (osc_pwm),
        .CP_trig        (btns[0]),
        .OTP_trig       (btns[1]),
        .UVLO_trig      (btns[2]),
        .latch_stat     (scr_q),
        .PGOOD_comp     (en_q),
        .en_from_switch (sw[0]),
        .PWM_out        (PWM_out),
        .En             (En),
        .PGOOD          (PGOOD),
        .latch_out      (latch_out)
    );


    // ============================================================
    // Indicators
    // ============================================================

    // stretch_cnt: counts down after each En drop, holds LD4 on meanwhile
    logic [$clog2(STRETCH_CLKS+1)-1:0] stretch_cnt = '0;

    always_ff @(posedge clk) begin
        if (en_q & ~En)          stretch_cnt <= STRETCH_CLKS;
        else if (stretch_cnt != 0) stretch_cnt <= stretch_cnt - 1'b1;
    end

    assign leds   = {PWM_out, latch_out, PGOOD, En};
    assign led4_b = (stretch_cnt != 0);
    assign led5_g = mmcm_locked;
    assign ja     = {2'b00, btns[0], latch_out, PGOOD, En, PWM_out, osc_pwm};

endmodule

`default_nettype wire
