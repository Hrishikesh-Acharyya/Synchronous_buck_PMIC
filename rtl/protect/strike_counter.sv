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
    input  var logic                clk,
    input  var logic                rst_n,
    input  var logic                pwm_sync,      // synchronised raw PWM, for the cycle boundary
    input  var logic                hiccup_active, // high only while the supervisor is in S_HICCUP
    input  var logic                run_active,    // high only while the supervisor is in S_RUN
    input  var logic                window_trip,   // running fault window exceeded
    output var logic [STRIKE_W-1:0] strike_level,  // strikes accumulated, sets the cool-down
    output var logic                latch_assert   // MAX_STRIKES reached, trip the latch
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
    */
      // ___
    end


    always_comb begin
    /*
    Purpose:
    ---
    */
      // ___
    end


    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    */
      // ___
    end


    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    */
      // ___
    end

endmodule

`default_nettype wire