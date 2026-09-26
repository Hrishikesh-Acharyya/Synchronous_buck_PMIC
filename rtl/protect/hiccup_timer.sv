/*

# Filename:         hiccup_timer.sv

# File Description: Cool-down timer for the hiccup state. Holds the power
#                    stage off for a duration that doubles with each strike,
#                    so a fault that keeps recurring is given progressively
#                    longer to clear before the next retry. Asserts
#                    hiccup_done when the interval has elapsed, which is what
#                    releases the supervisor from S_HICCUP back to S_SS.

# Global variables: None

*/

`default_nettype none

module hiccup_timer #(
    // BASE_CLKS: cool-down for strike level 0, in clk counts (5 ms at 50 MHz)
    parameter int BASE_CLKS   = 250_000,
    // STRIKE_W: width of the strike level input
    parameter int STRIKE_W    = 2,
    // TIMER_W: width of the cool-down counter, sized for the longest interval
    parameter int TIMER_W     = 20
) (
    input  var logic                clk,
    input  var logic                rst_n,
    input  var logic                hiccup_active,  // high only while the supervisor is in S_HICCUP
    input  var logic [STRIKE_W-1:0] strike_level,   // strikes accumulated so far
    output var logic                hiccup_done     // cool-down interval has elapsed
);

    // cool_down_target: BASE_CLKS shifted left by strike_level
    logic [TIMER_W-1:0] cool_down_target;
    // cool_counter: clk ticks elapsed in the present cool-down
    logic [TIMER_W-1:0] cool_counter;


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

endmodule

`default_nettype wire