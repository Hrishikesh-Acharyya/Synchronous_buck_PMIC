/*

# Filename:         fault_LED.sv

# File Description: Drives the front-panel indicators. Shows what is wrong RIGHT
#                   NOW, which is a different question from the one fault_cause
#                   answers.
#
#
#                   Indicator map:
#                     Green_LED  solid while the converter is running unfaulted
#                     pgood_LED  follows the power-good comparator
#                     Red_LED1   solid on a latched trip, blinking while strikes
#                                are outstanding
#                     Red_LED2   over-temperature
#                     Red_LED3   input undervoltage
#
#                   Green and Red_LED1 are both lit during the clean-run window: the
#                   board genuinely is running while strikes are still outstanding,
#                   and showing both is more informative than suppressing either.
#
#                   Status only. Drives no control path and takes no part in any
#                   protection decision; removing this module leaves the converter
#                   functionally identical.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none

module fault_LED
import pmic_types_pkg::*;
#(
    // LED_BLINK_HALF_CLKS: half the blink period, giving a 4 Hz blink. Sized
    //                      against the clean-run window rather than chosen for
    //                      looks: strikes clear after clean_run_target cycles,
    //                      about 1 s at the switching frequency, so a slower
    //                      blink would show only one or two cycles on a board
    //                      that recovers - which reads as a glitch rather than
    //                      a pattern. At 125 ms the recovery shows four clean
    //                      cycles.
    //
    //                      A parameter rather than a localparam so simulation
    //                      can override it: at 6.25 M clocks one blink edge is
    //                      125 ms of simulated time and no property about the
    //                      timebase is reachable.
    parameter int LED_BLINK_HALF_CLKS = pmic_types_pkg::ms_to_clks(125),
    // BLINK_W: derived from the half-period rather than taken independently,
    //          so an override cannot leave the two disagreeing.
    parameter int BLINK_W             = $clog2(LED_BLINK_HALF_CLKS + 1)
)(
    input  wire logic clk,
    input  wire logic rst_n,

    // ---- live fault conditions, all already synchronised and debounced ----
    input  wire logic otp_state,       // debounced OTP comparator
    input  wire logic uvlo_state,      // debounced input UVLO comparator
    input  wire logic latch_state,     // debounced SCR readback
    input  wire logic latch_assert,    // CPLD's own trip into the latch

    // ---- supervisor state ----
    // strike_level: hiccup strikes outstanding; non-zero from the first hiccup
    //               entry until clean_run_target fault-free cycles clear it
    input  wire logic [STRIKE_W-1:0] strike_level,
    input  wire logic ss_active,
    input  wire logic run_active,
    input  wire logic pgood,

    // ---- indicators ----
    output logic Green_LED,  // running, no fault present
    output logic pgood_LED,  // output rail in regulation
    output logic Red_LED1,   // latched trip (solid) or strikes outstanding (blink)
    output logic Red_LED2,   // over-temperature
    output logic Red_LED3    // input undervoltage
);


    //blink_counter: free-running half-period counter for the blink pattern
    logic [BLINK_W-1:0] blink_counter;
    //blink: square wave, high for half the blink period
    logic               blink;
    //currently_faulted: any fault condition live right now
    logic               currently_faulted;


    always_ff @ (posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Free-running blink timebase. Runs unconditionally rather than being started by
    a fault, so a blink that begins mid-period is not half-length - the pattern is
    always a clean square wave whenever something chooses to display it.
    */

        if(!rst_n) begin

            blink_counter <= '0;
            blink         <= 1'b0;

        end

        else if (blink_counter == BLINK_W'(LED_BLINK_HALF_CLKS-1)) begin

            blink_counter <= '0;
            blink         <= ~blink;

        end

        else blink_counter <= blink_counter + 1'b1;

    end


    always_comb begin
    /*
    Purpose:
    ---
    Any fault live right now. Used only to extinguish the green LED, so it is
    deliberately coarse - a separate red indicator says which fault it was.

    latch_state covers both trip sources, so no OVP inference is needed here. The
    display does not care WHO tripped the latch, only that it is set; fault_cause
    is where that distinction matters.

    The window trips are deliberately absent. A window trip takes the supervisor
    out of S_RUN on the next edge, so run_active extinguishes the green LED anyway
    - including them would be a second path to the same result.
    */

        currently_faulted = (otp_state || uvlo_state || latch_state || latch_assert);

    end


    always_ff @ (posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Running indication. Lit only while the converter is actually switching and
    nothing is wrong, so it goes dark in S_OFF, S_HICCUP and S_LATCHED as well as
    on any live fault.
    */

        if(!rst_n) Green_LED <= 1'b0;
        else       Green_LED <= (ss_active || run_active) && !currently_faulted;

    end


    always_ff @ (posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Power-good indication, straight from the comparator.
    */

        if(!rst_n) pgood_LED <= 1'b0;
        else       pgood_LED <= pgood;

    end


    always_ff @ (posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Latch and strike indication, in priority order: a latched trip is terminal and
    outranks strikes that may still clear, so solid beats blinking. Solid versus
    blinking distinguishes "this board has given up" from "this board is working
    through a problem", which is the distinction worth making at a glance.

    The blink persists after the hiccup itself ends - through the retry, the
    soft-start and into S_RUN - until clean_run_target fault-free cycles clear the
    strikes. A recovering board therefore blinks for about a second of healthy
    running. That is deliberate: "recently troubled, now proving itself" is real
    information, and a board that keeps failing to earn the clear keeps blinking.

    After a latch the clean counter can never advance, because the converter never
    runs again, so strike_level stays non-zero indefinitely. The priority order
    masks it - the LED is solid, and the blink branch is unreachable in that state.
    */

        if(!rst_n)                            Red_LED1 <= 1'b0;

        else if (latch_state || latch_assert) Red_LED1 <= 1'b1;

        else if (strike_level != '0)          Red_LED1 <= blink;

        else                                  Red_LED1 <= 1'b0;

    end


    always_ff @ (posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Over-temperature indication. The comparator holds its output for as long as the
    board is too hot, so no stretch is needed.
    */

        if(!rst_n) Red_LED2 <= 1'b0;
        else       Red_LED2 <= otp_state;

    end


    always_ff @ (posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Input undervoltage indication. Independent of Red_LED2 rather than chained
    after it: both conditions can be live at once and both must show.
    */

        if(!rst_n) Red_LED3 <= 1'b0;
        else       Red_LED3 <= uvlo_state;

    end


endmodule

`default_nettype wire

