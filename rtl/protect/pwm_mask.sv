/*

# Filename:         pwm_mask.sv

# File Description: Per-cycle on-time limiter. Counts clk ticks for the
#                    duration of each incoming PWM pulse and truncates that
#                    pulse once the count reaches max_on_counts, re-arming on
#                    the low phase of the next switching cycle. The block can
#                    only shorten a pulse, never extend one, so the analog
#                    modulator keeps control whenever it commands less than
#                    the ceiling.
#                    Enforced on-time is max_on_counts + 1 clk. pulse_allowed
#                    is decided from the pre-edge run_counter, so it clears
#                    one clock after the ceiling is reached. Fixed offset,
#                    measured, not an error — account for it when setting
#                    MIN_ON_COUNTS / MAX_ON_COUNTS in soft_start.

# Global variables: None

*/

`default_nettype none

module pwm_mask #(
    // ON_TIME_W: width of the on-time ceiling bus, must match soft_start
    parameter int ON_TIME_W = 7
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 pwm_sync,       // synchronised raw PWM from the analog modulator
    input  logic [ON_TIME_W-1:0] max_on_counts,  // on-time ceiling count from soft_start
    output logic                 pwm_out         // truncated PWM to the gate driver
);

    // run_counter: clk ticks elapsed within the present pulse
    logic [ON_TIME_W-1:0] run_counter;
    // pulse_allowed: envelope gate, low once the present pulse has hit the ceiling
    logic pulse_allowed;


    always_ff @(posedge clk or negedge rst_n) begin
       /*
    Purpose:
    ---
    Measure the on-time of each PWM pulse and close the envelope once it
    reaches the ceiling. run_counter is held at zero for the whole low phase
    and counts up through the high phase, so no edge detector is needed.

    pulse_allowed is armed on the low phase rather than on the rising edge:
    pwm_sync lags the raw PWM by two clocks through the input synchroniser,
    so arming on the edge would leave the gate still closed for the first
    clocks of every pulse and chop the front off each one.

    Once cleared, pulse_allowed stays cleared for the rest of the pulse even
    though pwm_sync is still high - only the low phase re-arms it. Without
    that hold the pulse could restart mid-cycle and hand the gate driver a
    double pulse.

    run_counter saturates at max_on_counts rather than wrapping, so a PWM
    input stuck high cannot roll the counter past its range and re-open the
    envelope.
    */
      if(!rst_n) begin
        run_counter <= 0;
        pulse_allowed <= 1;
      end

      else begin

          if(pwm_sync) begin
              if(run_counter < max_on_counts) begin
                  run_counter <= run_counter + 1;
                  pulse_allowed <= 1;
              end
              else begin
                  run_counter <= run_counter;
                  pulse_allowed <= 0;
              end
          end

          else begin
              run_counter <= 0;
              pulse_allowed <= 1;
          end

      end
    end


    always_ff @(posedge clk or negedge rst_n) begin

      /*
    Purpose:
    ---
    Register the masked PWM out to the gate driver. Flopping the output
    rather than driving it combinationally guarantees the driver never sees
    a glitch from unequal routing delays on pwm_sync and pulse_allowed - a
    glitch on the LM5106 IN pin is a shoot-through hazard. The register
    delays both edges equally, so pulse width is unaffected.

    Gate-drive enable is not gated here: supervisor.en drives the LM5106 EN
    pin, which holds both HO and LO low regardless of IN.
    */

      if(!rst_n) begin
        pwm_out <= 0;
      end
      else begin
      pwm_out <= pwm_sync & pulse_allowed;
      end
      
    end



endmodule

`default_nettype wire