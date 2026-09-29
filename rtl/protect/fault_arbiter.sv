/*

# Filename:         fault_arbiter.sv

# File Description: Rolling-window overcurrent detector. Samples the
#                    synchronised current-protection flag once per switching
#                    cycle and asserts window_trip / window_trip_SS when the
#                    number of faulted cycles within the trailing window
#                    exceeds the threshold for the present state. Two
#                    thresholds are used because elevated current during
#                    soft start is expected as the output capacitor charges,
#                    whereas sustained overcurrent in S_RUN is a real load
#                    fault.

# Global variables: None

*/

`default_nettype none

module fault_arbiter #(
    
    // WINDOW_RUN: trailing switching cycles examined while in S_RUN
    parameter int WINDOW_RUN = pmic_types_pkg::WINDOW_RUN,
    // TRIP_RUN: faulted cycles within WINDOW_RUN that assert window_trip
    parameter int TRIP_RUN   = pmic_types_pkg::TRIP_RUN,
    // WINDOW_SS: trailing switching cycles examined while in S_SS
    parameter int WINDOW_SS  = pmic_types_pkg::WINDOW_SS,
    // TRIP_SS: faulted cycles within WINDOW_SS that assert window_trip_SS
    parameter int TRIP_SS    = pmic_types_pkg::TRIP_SS
    
) (
    input  wire logic clk,
    input  wire logic rst_n,
    input  wire logic pwm_sync,        // synchronised raw PWM, for the cycle boundary
    input  wire logic cp_sync,         // synchronised current-protection flag (CP_trig)
    input  wire logic ss_active,       // high only while the supervisor is in S_SS
    input  wire logic run_active,      // high only while the supervisor is in S_RUN
    output logic window_trip,     // fault window exceeded while running
    output logic window_trip_SS   // fault window exceeded during soft start
);

    // pwm_sync_d: pwm_sync delayed one clk, used to detect the cycle boundary
    logic pwm_sync_d;
    // pwm_fall: one-clk pulse marking the end of a switching cycle
    logic pwm_fall;
    // fault_shifter_SS: 32 bit register, each bit is the CP_trig value for one switching cycle,
    // with the most recent cycle in bit 0. Shifted left each cycle to make room for the new sample
    logic [WINDOW_SS-1:0] fault_shifter_SS;
    //fault_shifter_RUN: 16 bit register for RUN state fault handling
    logic[WINDOW_RUN-1:0] fault_shifter_RUN;
    // fault_count_run: faulted cycles within the trailing WINDOW_RUN bits
    logic [$clog2(WINDOW_RUN+1)-1:0] fault_count_run;
    // fault_count_ss: faulted cycles within the trailing WINDOW_SS bits
    logic [$clog2(WINDOW_SS+1)-1:0] fault_count_ss;


    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Create a one-clock delayed copy of the synchronised PWM so that the end
    of a switching cycle can be detected combinationally below.
    */
    
    if(!rst_n) begin
        pwm_sync_d <= 0;
    end

    else
      pwm_sync_d <= pwm_sync;


      end

    always_comb begin
     /*
    Purpose:
    ---
    Detect the falling edge of the switching cycle and produce a one-clk
    enable pulse. Sampling on the falling edge places the sample well away
    from low-side turn-on, where reverse-recovery ringing can false-trip the
    current comparator.
    */
    pwm_fall = pwm_sync_d & ~pwm_sync;
      end


    always_ff @(posedge clk or negedge rst_n) begin
        /*
    Purpose:
    ---
    Maintain a rolling window of the current-protection flag, one bit per
    switching cycle, and a running count of the faulted cycles within it.

    cp_sync is sampled as a level rather than as an edge: the comparator has
    hysteresis and holds high for as long as the overcurrent persists, and
    what matters thermally is the fraction of recent cycles spent in
    overcurrent, not how many separate excursions occurred. A single
    sustained fault must trip the window, and edge counting would never see
    it.

    The counts are maintained incrementally - plus the bit entering, minus
    the bit leaving the window - rather than by summing the register every
    clock, which would synthesise to a wide adder tree. Both reads use the
    pre-edge register value, so the indexed bit is the one about to be
    displaced.

    Both windows are cleared whenever neither state is active, so a hiccup
    retry starts on a clean window rather than re-tripping immediately on
    the history that caused the trip.
    */
    if(!rst_n) begin
      fault_shifter_RUN <= 0;
      fault_shifter_SS <=0;
      fault_count_run <= 0;
      fault_count_ss <=0;
    end

    else if (pwm_fall && run_active) begin

      fault_count_run <= fault_count_run + cp_sync - fault_shifter_RUN[WINDOW_RUN-1];
      fault_shifter_RUN <= (fault_shifter_RUN<<1)|cp_sync;

    end 


    else if (pwm_fall && ss_active) begin

      fault_count_ss <= fault_count_ss + cp_sync - fault_shifter_SS[WINDOW_SS-1];
      fault_shifter_SS <= (fault_shifter_SS<<1)|cp_sync;
      
    end 

    else if (!run_active && !ss_active) begin
      fault_shifter_RUN <= 0;
      fault_shifter_SS <= 0;
      fault_count_run <=0;
      fault_count_ss <= 0;

    end


     end

    // Thresholds differ because elevated current during soft start is
    // expected as the output capacitor charges from zero in FCCM, whereas
    // sustained overcurrent in S_RUN is a genuine load fault.
    always_comb window_trip = fault_count_run >= TRIP_RUN;
    always_comb window_trip_SS = fault_count_ss>=TRIP_SS;

endmodule

`default_nettype wire

