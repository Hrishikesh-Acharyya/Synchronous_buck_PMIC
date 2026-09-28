/*

# Filename:         pmic_top.sv

# File Description: Top level of the CPLD supervisor. Instantiates the reset
#                    synchroniser and one input synchroniser per asynchronous
#                    pin, then wires the supervisor FSM to the soft-start
#                    ramp, per-cycle PWM mask, rolling fault window, hiccup
#                    cool-down, strike counter and power-good generator.
#
#                    All clock domain crossing lives here: every signal from
#                    the analog side is comparator output with no relation to
#                    clk, and no submodule sees a raw pin. Each asynchronous
#                    input is synchronised once and the result distributed.

# Global variables: None

*/

`default_nettype none

module pmic_top (
    // ---- clock and reset ----
    input  logic clk,          // Clk_Ext, 50 MHz external oscillator
    input  logic rst_n_pin,    // asynchronous external reset, active low

    // ---- asynchronous inputs from the analog side ----
    input  logic G_En,         // Enable from the MCU
    input  logic Osc_in,       // Master_PWM from the analog modulator
    input  logic CP_trig,      // valley-current comparator
    input  logic OTP_trig,     // over-temperature comparator
    input  logic UVLO_trig,    // input undervoltage lockout comparator
    input  logic latch_stat,   // SCR protection latch, read back
    input  logic PGOOD_comp,   // output rail comparator

    // ---- outputs ----
    output logic PWM_out,      // masked PWM to the LM5106 IN pin
    output logic En,           // LM5106 enable driven by the supervisor FSM
    output logic PGOOD,        // supply changeover and telemetry
    output logic latch_out     // CPLD-driven trip into the shared latch
);

    import pmic_types_pkg::*;

    // ---- reset ----
    // ___
    logic rst_n;
    reset_sync rst_sync (.clk(clk), .rst_n_enter(rst_n_pin), .rst_n_exit(rst_n));

    // ---- synchronised copies of the asynchronous inputs ----
    // ___
    logic G_en_sync, Osc_sync, CP_sync, OTP_sync, UVLO_sync, latch_sync, PGOOD_comp_sync;
    input_sync uut_en_sync (.clk(clk), .rst_n(rst_n), .async_in(G_En), .sync_out(G_en_sync));
    input_sync uut_osc_sync (.clk(clk), .rst_n(rst_n), .async_in(Osc_in), .sync_out(Osc_sync));
    input_sync uut_cp_sync (.clk(clk), .rst_n(rst_n), .async_in(CP_trig), .sync_out(CP_sync));
    input_sync uut_otp_sync (.clk(clk), .rst_n(rst_n), .async_in(OTP_trig), .sync_out(OTP_sync));
    input_sync uut_uvlo_sync (.clk(clk), .rst_n(rst_n), .async_in(UVLO_trig), .sync_out(UVLO_sync));
    input_sync uut_latch_sync (.clk(clk), .rst_n(rst_n), .async_in(latch_stat), .sync_out(latch_sync));
    input_sync uut_pgood_comp_sync (.clk(clk), .rst_n(rst_n), .async_in(PGOOD_comp), .sync_out(PGOOD_comp_sync));

    // ---- inter-module signals ----
    // ___

    logic ss_active, run_active, hiccup_active, hiccup_done, SS_done;
    logic window_trip, window_trip_SS;
    logic [STRIKE_W-1:0]strike_level, en_from_fsm;
    logic [ON_TIME_W-1:0] max_on_counts;
    // ============================================================
    // Reset
    // ============================================================
    // ___


    // ============================================================
    // Input synchronisers
    // ============================================================
    // ___


    // ============================================================
    // Supervisor FSM
    // ============================================================
    // ___

    supervisor supervisor ( .clk(clk),
                            .SS_done(SS_done),
                            .rst_n(rst_n),
                            .g_en(G_en_sync),
                            .latch_state(latch_sync),
                            .OTP(OTP_sync),
                            .window_trip_SS(window_trip_SS),
                            .window_trip(window_trip),
                            .latch_assert(latch_out),
                            .UVLO(UVLO_sync),
                            .hiccup_done(hiccup_done),
                            .en(En),
                            .ss_active(ss_active),
                            .run_active(run_active),
                            .hiccup_active(hiccup_active)
                            );


    // ============================================================
    // Protection
    // ============================================================
    // 
    fault_arbiter uut_fault_arbiter ( .clk(clk),
                                    .rst_n(rst_n),
                                    .pwm_sync(Osc_sync),
                                    .cp_sync(CP_sync),
                                    .ss_active(ss_active),
                                    .run_active(run_active),
                                    .window_trip(window_trip),
                                    .window_trip_SS(window_trip_SS)
                                    );
    hiccup_timer uut_hiccup_timer ( .clk(clk),
                                    .rst_n(rst_n),
                                    .hiccup_active(hiccup_active),
                                    .strike_level(strike_level),
                                    .hiccup_done(hiccup_done)
                                    );
    
    strike_counter uut_strike_counter ( .clk(clk),
                                    .rst_n(rst_n),
                                    .pwm_sync(Osc_sync),
                                    .hiccup_active(hiccup_active),
                                    .run_active(run_active),
                                    .window_trip(window_trip),
                                    .strike_level(strike_level),
                                    .latch_assert(latch_out)
                                    );
    soft_start uut_soft_start ( .clk(clk),
                                    .rst_n(rst_n),
                                    .pwm_sync(Osc_sync),
                                    .ss_active(ss_active),
                                    .run_active(run_active),
                                    .max_on_counts(max_on_counts),
                                    .SS_done(SS_done)
                                    );

    pwm_mask uut_pwm_mask ( .clk(clk),
                            .rst_n(rst_n),
                            .pwm_sync(Osc_sync),
                            .max_on_counts(max_on_counts),
                            .pwm_out(PWM_out)
                            );

    // ============================================================
    // Status
    // ============================================================
    // ___

    pgood_gen uut_pgood_gen ( .clk(clk),
                            .rst_n(rst_n),
                            .pwm_sync(Osc_sync),
                            .pgood_comp(PGOOD_comp_sync),
                            .run_active(run_active),
                            .PGOOD(PGOOD)
                            );


    // ============================================================
    // Output pins
    // ============================================================


    /*
    Purpose:
    ---
    */
    // ___

endmodule

`default_nettype wire