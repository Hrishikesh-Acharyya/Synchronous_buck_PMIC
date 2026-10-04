/*

# Filename:         pwm_stats.sv

# File Description: Telemetry for the incoming PWM from the analog
#                   modulator. Measures the length of each switching period
#                   in clk counts and the length of the high phase within
#                   it, and exports both for the previous complete period.
#
#                   The period is measured rather than assumed because the
#                   analog oscillator drifts from its nominal 111.1 clk
#                   ticks with temperature and component tolerance. Duty
#                   referenced to the nominal period would carry that drift
#                   straight into the error, and since duty times a known
#                   Vin infers Vout, the drift would appear as an output
#                   voltage error with no ADC in the loop to catch it.
#
#                   Exports raw clock counts rather than a computed duty
#                   cycle. A variable-denominator divide costs a few
#                   hundred LEs and will not close timing at 50 MHz in one
#                   cycle, and the reading MCU divides for free. The raw
#                   period also doubles as switching-frequency telemetry,
#                   which a quotient would discard.
#
#                   Both outputs describe the previous complete period and
#                   are captured from the same counter run, so they are
#                   always consistent with each other. Data is therefore one
#                   switching cycle old: the period is only known once it
#                   has ended.
#
#                   Telemetry only. Drives no control path and takes no part
#                   in any protection timing.

# Global variables: None

*/

`default_nettype none

module pwm_stats #(

// CNT_W: Width of the counter used to count number of periods. 
//        Derives base value from the nominal duty count defined in pmic_packages + 1 bit extra
//        to account for oscillator drift
//        @TODO: Check if extra bit required or not
parameter int CNT_W = pmic_types_pkg::CNT_W

) (input  wire logic clk,
                  input  wire logic rst_n,
                  //synchronised raw PWM
                  input  wire logic pwm_sync,          
                  //duty_count: keeps track of number of clock ticks the PWM was high for
                  output logic [CNT_W-1:0] duty_count, 
                  //prev_period: Stores the previous period length for calculations
                  output logic [CNT_W-1:0] prev_period
                  );

//pwm_fall: Gives idea of when the PWM has fallen for duty cycle measurement
logic pwm_fall;
//pwm_rise: Marks the start of the next switching cycle.
logic pwm_rise;
//pwm_sync_d: Delayed copy of pwm_sync, used to generate pwm_fall and pwm_rise
logic pwm_sync_d;
//period_counter: keeps track of how many clock ticks one switching cycle took
logic [CNT_W-1:0] period_counter;


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
    The blocks assign values to pwm_fall and pwm_rise. Check variable declaration comment
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
    of the HS conduction time, which is exported for the consumer to divide

    
  */

  if(!rst_n) begin
    period_counter <= 0;
    duty_count <= 0;
    prev_period <=0;
  end

  else if (pwm_rise) begin

    prev_period <= period_counter;
    period_counter <= 0;

  end

  else if (pwm_fall) begin

    duty_count <= period_counter;
    period_counter <= period_counter  +1;

  end

  else begin
    period_counter <= period_counter + 1;
  end

  end


endmodule

`default_nettype wire

