/*

# Filename:         pwm_stats.sv

# File Description: This module provides the duty cycle of the input pwm 
#                   from the analog oscillator. It measures the period first
#                   as the oscillator may drift from the nominal 111.1 clock ticks
#                   and hence provide error on duty cycle telemetry.
#                   
#                   Duty cycle data arrives one cycle late as period can be ascertained
#                   only after the period is over!!
#
#

# Global variables: None

*/

`default_nettype none

module pwm_stats (input  logic clk,
                  input  logic rst_n,
                  input  logic pwm_sync, // synchronised raw PWM
                  output int  duty       // duty cycle data
                  );

// CNT_W: Width of the countr used to count number of periods. 
//        Derives base value from the nominal duty count defined in pmic_packages + 1 bit extra
//        to account for oscillator drift
//        @TODO: Check if extra bit required or not
localparam CNT_W = $clog2(pmic_types_pkg::CLKS_PER_SW + 1)+ 1; 
//pwm_fall: Gives idea of when the PWM has fallen for duty cycle measurement
logic pwm_fall;
//pwm_rise: Marks the start of the next switching cycle.
logic pwm_rise;
//pwm_sync_d: Delayed copy of pwm_sync, used to generate pwm_fall and pwm_rise
logic pwm_sync_d;
//duty_count: keeps track of number of clock ticks the PWM was high for
logic [CNT_W-1:0] duty_count;
//period_count: keeps track of how many clock ticks one switching cycle took
logic [CNT_W-1:0] period_counter;
//prev_period: Stores the previous period length for calculations
logic [CNT_W-1:0] prev_period;

always_ff @(posedge clk or negedge rst_n) begin
  /*
    Purpose:
    ---
    Create a one-clock delayed copy of the synchronised PWM so that the 
    start of a switching cycle and the end of HS conduction can be detected combinationally below.
  */

  if(!rst_n) begin
    pwm_sync_d <= 0;
  end

  else
    pwm_sync_d <= pwm_sync;

end

/*
    Purpose:
    ---
    The blocks assign values to pwm_fall and pwm_rise. Chekc variable declaration comment
    for more information on the variables.
*/
always_comb pwm_fall = pwm_sync_d & ~pwm_sync;
always_comb pwm_rise = ~pwm_sync_d & pwm_sync;

always_ff @ (posedge clk or negedge rst_n) begin

  /*
    Purpose:
    ---
    Runs the period_counter. 
    Clears and starts the counter on PWM rise, and before clearing the counter
    the old value is read into prev_counter so the data is not lost.
    On pwm_fall, it reads the current period count into duty counts to keep track 
    of the HS conduction time required for duty cycle calculations.
  */

  if(!rst_n) begin
    period_counter <= 0;
    duty_count <= 0;
  end

  else if (pwm_rise) begin
    prev_period <= period_counter;
    period_counter <= 0;
  end

  else if (pwm_fall) begin
    duty_count <= period_counter;
  end

  else begin
    period_counter <= period_counter + 1;
  end

  end

  always_ff begin

    /*
    Purpose:
    ---
    Does the duty cycle calculation whenever new cycle begins for the old cycle.
    Explicitly handles the reset case when both duty_count and period_count are 0
    to prevent a divide by zero error.

    @TODO: duty is defined as integer. It may truncate to 0 in some cases.
           Native divider is costly in hardware. Either output duty_counts and prev_periods so the
           downstream MCU may calculate duty itself or write a divider module.

    */
    
    if (!rst_n) begin
      duty <= 0;
    end

    else if(pwm_rise) begin

      if(!(duty_count == 0 && prev_period == 0)) begin

        duty <= (duty_count * 100)/ prev_period;

      end

    end

    end

endmodule

`default_nettype wire

