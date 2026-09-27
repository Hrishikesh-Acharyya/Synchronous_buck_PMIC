/*

# Filename:         strike_counter.sv

# File Description: Counts hiccup retries and gives up after MAX_STRIKES.
#                    Each entry into the hiccup state is one strike; the
#                    strike level sets the cool-down interval in
#                    hiccup_timer, and reaching MAX_STRIKES asserts
#                    latch_assert to trip the SCR protection latch. A
#                    sustained fault-free period in S_RUN clears the count,
#                    so unrelated transients separated in time cannot
#                    accumulate into a permanent shutdown.

# Global variables: None

*/

`default_nettype none

module strike_counter #(
    // MAX_STRIKES: hiccup retries permitted before the latch is asserted
    parameter int MAX_STRIKES     = 3,
    // CLEAN_RUN_CYCLES: fault-free switching cycles in S_RUN that clear the
    //                   strike count. 2**19 cycles is about 1.17 s at 450 kHz
    parameter int CLEAN_RUN_CYCLES = 19,
    // STRIKE_W: width of the strike level bus, must match hiccup_timer
    parameter int STRIKE_W        = 2
) (
    input  logic                clk,
    input  logic                rst_n,
    input  logic                pwm_sync,      // synchronised raw PWM, for the cycle boundary
    input  logic                hiccup_active, // high only while the supervisor is in S_HICCUP
    input  logic                run_active,    // high only while the supervisor is in S_RUN
    input  logic                window_trip,   // running fault window exceeded
    output logic [STRIKE_W-1:0] strike_level,  // strikes accumulated, sets the cool-down
    output logic                latch_assert   // MAX_STRIKES reached, trip the latch
);

    // hiccup_active_d: hiccup_active delayed one clk, to count entries not duration
    logic hiccup_active_d;
    // hiccup_entry: one-clk pulse on each entry into the hiccup state
    logic hiccup_entry;
    // pwm_sync_d: pwm_sync delayed one clk, used to detect the cycle boundary
    logic pwm_sync_d;
    // pwm_fall: one-clk pulse marking the end of a switching cycle
    logic pwm_fall;
    // clean_counter: consecutive fault-free switching cycles in S_RUN
    logic [CLEAN_RUN_CYCLES-1:0] clean_counter;


    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Delayed copies of hiccup_active and pwm_sync, so the edges below can be
    detected combinationally.
    */

    if(!rst_n) begin
      hiccup_active_d <= 0;
      pwm_sync_d <= 0;

    end
    else begin
      hiccup_active_d <= hiccup_active;
      pwm_sync_d <= pwm_sync;

    end
    end


    always_comb begin
    /*
    Purpose:
    ---
    Convert two levels into one-clk enable pulses. hiccup_active is held for
    the whole cool-down, so counting it directly would add a strike every
    clock; the rising edge gives exactly one strike per hiccup. pwm_fall
    marks the switching-cycle boundary for the clean-run counter.

    Both are used as enables on the 50 MHz domain, never as clocks.
    */


      hiccup_entry = hiccup_active & ~hiccup_active_d;
      pwm_fall = pwm_sync_d & ~pwm_sync;
    end


    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Accumulate strikes and assert the latch once MAX_STRIKES is reached.
    The comparison is against MAX_STRIKES-1 because strike_level still holds
    the pre-increment value on this edge, so testing the value about to land
    fires the latch on the correct hiccup rather than one later.

    latch_assert is set-only and cleared by rst_n alone: it trips a physical
    SCR, which cannot be un-tripped in logic. strike_level is deliberately
    not zeroed on latching, so the accumulated count remains readable for
    telemetry.

    The clean-run clear is a sibling of hiccup_entry, not nested inside it,
    so a fault-free run clears the strikes during normal operation rather
    than only at the moment another hiccup begins.
    */

    if (!rst_n) begin
      latch_assert <= 1'b0;
      strike_level <= '0;
    end

    else if (hiccup_entry) begin
      strike_level <= strike_level + 1;

    if (strike_level == MAX_STRIKES-1) latch_assert <= 1'b1;
    end

    else if (clean_counter == 2**CLEAN_RUN_CYCLES-1) begin
      strike_level <= '0;
    end

    end



    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Count consecutive fault-free switching cycles in S_RUN, saturating at the
    terminal value rather than wrapping.

    The streak is broken by leaving S_RUN as well as by window_trip. Time
    spent in S_HICCUP or S_SS is not running, and a counter that survived a
    hiccup would clear the very strike that hiccup earned - defeating the
    distinction between one isolated fault and a converter failing
    repeatedly.
    */

    if(!rst_n || !run_active || window_trip) begin
      clean_counter <= 0;
    end

    else if(pwm_fall)

      if(clean_counter == 2**CLEAN_RUN_CYCLES-1) begin
        clean_counter <= clean_counter;
      end
      else
      clean_counter <= clean_counter + 1;
    end

endmodule

`default_nettype wire

