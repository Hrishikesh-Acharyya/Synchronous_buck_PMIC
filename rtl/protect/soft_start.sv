/*

# Filename:         soft_start.sv

# File Description: Generates the ramping on-time count ceiling used during
#                    soft start. Counts switching cycles of the incoming PWM
#                    and widens max_on_counts by one clk count every
#                    CYCLES_PER_STEP cycles, from MIN_ON_COUNTS up to
#                    MAX_ON_COUNTS, then asserts SS_done. The ceiling is held
#                    through S_RUN as a digital backstop sitting above the
#                    70% analog duty clamp, and resets to the floor in any
#                    other state so that a hiccup retry always re-ramps.

# Global variables: None

*/
`default_nettype none

module soft_start #(
    // MIN_ON_COUNTS: starting on-time ceiling in clk counts (~11% duty). Based on dead timing delay of LM5105 gate driver spec sheet
    parameter int MIN_ON_COUNTS   = 12,
    // MAX_ON_COUNTS: final on-time ceiling in clk counts (~75% duty)
    parameter int MAX_ON_COUNTS   = 83,
    // CYCLES_PER_STEP: switching cycles held at each ceiling before widening
    parameter int CYCLES_PER_STEP = 16,
    // ON_TIME_W: width of the on-time ceiling bus
    parameter int ON_TIME_W       = $clog2(MAX_ON_COUNTS+1)
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 pwm_sync,       // synchronised raw PWM from the analog modulator
    input  logic                 ss_active,      // high only while the supervisor is in S_SS
    input  logic                 run_active,     // high only while the supervisor is in S_RUN
    output logic [ON_TIME_W-1:0] max_on_counts,  // on-time ceiling count handed to pwm_mask
    output logic                 SS_done         // ramp has reached MAX_ON_COUNTS
);

    // MIN_ON_CNT: MIN_ON_COUNTS sized to the ceiling bus
    localparam logic [ON_TIME_W-1:0] MIN_ON_CNT = MIN_ON_COUNTS[ON_TIME_W-1:0];
    // MAX_ON_CNT: MAX_ON_COUNTS sized to the ceiling bus
    localparam logic [ON_TIME_W-1:0] MAX_ON_CNT = MAX_ON_COUNTS[ON_TIME_W-1:0];

    // pwm_sync_d: pwm_sync delayed one clk, used to detect the cycle boundary
    logic pwm_sync_d;
    // pwm_fall: one-clk pulse marking the end of a switching cycle
    logic pwm_fall;
    // cycle_counter: switching cycles elapsed at the present ceiling
    logic [$clog2(CYCLES_PER_STEP)-1:0] cycle_counter;


    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Create a one-clock delayed copy of the incoming PWM so that the falling
    edge of a switching cycle can be detected combinationally below.
    */
      if (!rst_n) begin
        pwm_sync_d <= 1'b0;
      end
      else begin
        pwm_sync_d <= pwm_sync;
      end
    end


    always_comb begin
    /*
    Purpose:
    ---
    Detect the falling edge of the incoming PWM and produce a one-clk pulse
    for the cycle counter. The falling edge is used rather than the rising
    edge so that max_on_counts is updated while the pulse is over and
    pwm_mask's run_counter is parked, never mid-pulse.
    */
      pwm_fall = pwm_sync_d & ~pwm_sync;
    end


    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Run the soft-start ramp. In S_SS, count switching cycles and widen
    max_on_counts by one count every CYCLES_PER_STEP cycles until it reaches
    MAX_ON_CNT, then assert SS_done. In S_RUN, hold everything so the ceiling
    persists as the running duty backstop. In any other state, reset to the
    floor so that a hiccup retry re-ramps from the bottom rather than
    re-enabling at full duty into an unresolved fault.
    */
      if (!rst_n) begin
        cycle_counter <= '0;
        max_on_counts <= MIN_ON_CNT;
        SS_done       <= 1'b0;
      end

      else if (ss_active) begin
        if (pwm_fall) begin
          if (cycle_counter == CYCLES_PER_STEP-1) begin
            cycle_counter <= '0;

            if (max_on_counts == MAX_ON_CNT) begin
              SS_done <= 1'b1;
            end
            else begin
              max_on_counts <= max_on_counts + 1;
              // SS_done is set from the value about to land, not the current
              // one, so the ramp does not finish a step late.
              if (max_on_counts + 1 == MAX_ON_CNT) begin
                SS_done <= 1'b1;
              end
            end
          end
          else begin
            cycle_counter <= cycle_counter + 1;
          end
        end
      end

      else if (run_active) begin
        // Hold: ceiling and SS_done keep their values for all of S_RUN.
      end

      else begin
        cycle_counter <= '0;
        max_on_counts <= MIN_ON_CNT;
        SS_done       <= 1'b0;
      end
    end


endmodule

`default_nettype wire