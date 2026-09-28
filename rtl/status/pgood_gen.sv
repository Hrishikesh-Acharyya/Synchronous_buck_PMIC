/*

# Filename:         pgood_gen.sv

# File Description: Power-good indicator. Asserts PGOOD once the output
#                    comparator has reported a good rail continuously for a
#                    qualifying period while the supervisor is regulating,
#                    and drops it immediately when either condition fails.
#                    PGOOD drives the changeover that moves the secondary
#                    analog circuitry off the input LDO and onto the
#                    converter's own output, so assertion is deliberately
#                    slow and deassertion deliberately immediate: a load must
#                    be handed back to the LDO before the rail collapses,
#                    not after.

# Global variables: None

*/

`default_nettype none

module pgood_gen #(
    // PGOOD_DELAY_W: width of the qualifying counter.
    parameter int PGOOD_DELAY_W = pmic_types_pkg::PGOOD_DELAY_W
) (
    input  logic clk,
    input  logic rst_n,
    input  logic pwm_sync,     // synchronised raw PWM, for the cycle boundary
    input  logic pgood_comp,   // synchronised output comparator, high when the rail is above threshold
    input  logic run_active,   // high only while the supervisor is in S_RUN
    output logic PGOOD         // power good, to the supply changeover and telemetry
);

    // pwm_sync_d: pwm_sync delayed one clk, used to detect the cycle boundary
    logic pwm_sync_d;
    // pwm_fall: one-clk pulse marking the end of a switching cycle
    logic pwm_fall;
    // qualify_counter: switching cycles the rail has been good while regulating
    logic [PGOOD_DELAY_W-1:0] qualify_counter;


    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Create a one-clock delayed copy of the synchronised PWM so that the end
    of a switching cycle can be detected combinationally below.
    */


    if(!rst_n) begin
      pwm_sync_d<=0;
    end

    else
      pwm_sync_d <= pwm_sync; 
    end


    always_comb begin
    /*
    Purpose:
    ---
    One-clk enable pulse marking the switching-cycle boundary, so the
    qualifying counter below advances once per cycle rather than once per
    clock.
    */

    pwm_fall = pwm_sync_d & ~pwm_sync;
    end


    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Count switching cycles for which the rail has been continuously good
    while the supervisor is regulating, saturating at the terminal value
    rather than wrapping.

    Both run_active and pgood_comp appear in the clear condition, so the
    qualifying period measures *consecutive* good cycles: any dip below the
    comparator threshold, or any departure from S_RUN, restarts it from zero
    rather than resuming where it left off.

    pgood_comp arrives through an input_sync instance, so it changes only on
    clock edges. That matters here as well as for metastability: a transition
    the combinational output below reacts to cannot be shorter than one clock,
    so this counter can never miss a dip that PGOOD has already responded to.
    */

    if(!rst_n) begin
      qualify_counter <= 0;
    end

    else if ( || !run_active ||  !pgood_comp) begin  //split to enable synthesis
      qualify_counter <= 0
    end

    else if(pwm_fall) begin

        if(qualify_counter == 2**PGOOD_DELAY_W -1)
          qualify_counter <= 2**PGOOD_DELAY_W-1;
        
        else
         qualify_counter <= qualify_counter + 1;
      end

    end


    always_comb begin
      /*
    Purpose:
    ---
    PGOOD is the saturated counter ANDed with the two live conditions, not a
    registered flag. The asymmetry is deliberate and is the whole point of
    the module: assertion is slow because qualify_counter must climb the full
    delay, while deassertion is immediate because pgood_comp and run_active
    appear directly in this expression and bypass the counter entirely.

    PGOOD drives the changeover that moves the secondary analog circuitry off
    the input LDO and onto the converter's own output. That load must be
    handed back to the LDO before the rail collapses, so a registered output -
    which would cost an extra clock and could disagree with the counter
    driving it - is the wrong choice here, unlike the gate-drive paths in
    pwm_mask and the supervisor where a combinational glitch would be a
    shoot-through hazard.
    */

    PGOOD = ((qualify_counter == 2**PGOOD_DELAY_W - 1) & pgood_comp & run_active);
    end

endmodule

`default_nettype wire

