/*

# Filename:         hiccup_timer.sv

# File Description: Cool-down timer for the hiccup state. Holds the gate driver
                    off for a duration that doubles with each strike,
#                   so a fault that keeps recurring is given progressively
#                   longer to clear before the next retry. Asserts
#                   hiccup_done when the interval has elapsed, which is what
#                   releases the supervisor from S_HICCUP back to S_SS.

# Global variables: None

*/

`default_nettype none

module hiccup_timer #(

    // STRIKE_W: width of the strike level input
    parameter int STRIKE_W  = pmic_types_pkg::STRIKE_W,
    // TIMER_W: width of the cool-down counter, sized for the longest interval
    parameter int TIMER_W   = pmic_types_pkg::HICCUP_TIMER_W

) (                     
    input   wire logic                                      clk,
    input   wire logic                                      rst_n,
    input   wire logic                                      hiccup_active,  // high only while the supervisor is in S_HICCUP
    input   wire logic [STRIKE_W-1:0]                       strike_level,   // strikes accumulated so far
    input   wire logic [pmic_types_pkg::HICCUP_BASE_W-1:0]  base_clks,      // base_clks: cool-down for strike level 0
    output  logic                                           hiccup_done     // cool-down interval has elapsed
);

    // cool_down_target: BASE_CLKS shifted left by strike_level
    logic [TIMER_W-1:0] cool_down_target;
    // cool_counter: clk ticks elapsed in the present cool-down
    logic [TIMER_W-1:0] cool_counter;

    

    always_comb begin
        /*
    Purpose:
    ---
    Derive the cool-down interval for the present strike level. Each strike
    doubles the interval, so a fault that keeps recurring is given
    progressively longer to clear.

    strike_counter increments on entry to S_HICCUP, one clock after
    hiccup_active rises, so cool_down_target steps up while cool_counter is
    still near zero. The match below simply occurs at the new, larger target;
    the target only ever grows, so the counter can never step past it.
    */

    cool_down_target = TIMER_W'(base_clks)<<strike_level;
    
    end


    always_ff @(posedge clk or negedge rst_n) begin
        /*
    Purpose:
    ---
    Run the cool-down while the supervisor holds S_HICCUP, and assert
    hiccup_done once the interval has elapsed. The counter is held at target
    rather than reset, so a waveform distinguishes a finished cool-down from
    one that has just re-armed.

    Clocks are counted rather than switching cycles: the power stage is
    disabled throughout S_HICCUP, so there is no PWM and no cycle boundary
    to count.

    The !hiccup_active branch clears both the counter and hiccup_done on
    leaving the state. Without it hiccup_done would stay asserted into S_SS
    and S_RUN, and the next entry into S_HICCUP would exit immediately on the
    stale flag - skipping every cool-down after the first, which is exactly
    the case the escalating interval exists for.
    */
    
    if(!rst_n) begin
      cool_counter <= 0;
      hiccup_done <= 0;
    end

    else if (!hiccup_active) begin
      hiccup_done <= 1'b0;
      cool_counter <= 0;

    end

    else if (cool_counter == cool_down_target) begin
      hiccup_done  <= 1'b1;
      cool_counter <= cool_counter;   // hold
    end

    
    else cool_counter <= cool_counter + 1;

    end


endmodule

`default_nettype wire

