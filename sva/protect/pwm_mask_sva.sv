/*

# Filename:         pwm_mask_sva.sv

# File Description: Concurrent assertion checker for pwm_mask. Attached with
#                   bind so the RTL source carries no assertion constructs and
#                   the sv2v / Yosys ASIC path never sees them. ON_TIME_W is
#                   passed through from the bound instance so the counter
#                   comparisons match the call site's bus width.
#
#                   pwm_mask sits directly in front of the LM5106 IN pin, so
#                   its claims are safety claims rather than functional ones:
#                   the block may only ever shorten a pulse, and must never
#                   produce an edge the analog modulator did not command.
#
#                   The enforced on-time is max_on_counts + 1 clk, documented
#                   in the DUT header as a measured fixed offset rather than
#                   an error - pulse_allowed is decided from the pre-edge
#                   run_counter, so it clears one clock after the ceiling is
#                   reached. Properties here are written against the realised
#                   on-time, not against max_on_counts directly.
#
#                   pwm_out is registered, not combinational, so every claim
#                   relating it to pwm_sync reaches one edge back.

# Global variables: None

*/

`default_nettype none

module pwm_mask_sva #(
    parameter int ON_TIME_W = pmic_types_pkg::ON_TIME_W
)(
    input  wire logic                 clk,
    input  wire logic                 rst_n,
    input  wire logic                 pwm_sync,
    input  wire logic [ON_TIME_W-1:0] max_on_counts,
    input  wire logic                 pwm_out,
    // DUT internals
    input  wire logic [ON_TIME_W-1:0] dut_run_counter
);

    // ---- aux logic, if any ----


/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         The pwm_mask can only shorten the pwm, not create new ones
*/

property p_mask_doesnt_produce_pwm;

  @(posedge clk) disable iff (!rst_n)
    pwm_out |-> $past(pwm_sync); //pwm_out is registered so it appears one clock after pwm_sync

endproperty

a_mask_doesnt_produce_pwm: assert property (p_mask_doesnt_produce_pwm)
  else begin
    
     sva_pkg::note_failure($sformatf(
      "a_mask_doesnt_produce_pwm: mask produced a spurious pwm, pwm should be = %0b, it produced = %0b",
      $past(pwm_sync), pwm_out));

  end

  c_mask_doesnt_produce_pwm: cover property (@(posedge clk) disable iff (!rst_n) pwm_out);



/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         PWM_OUT cannot go back to high again once it has been truncated by the module
         in the same cycle
*/

property p_pwm_out_cannot_go_back_up_once_truncated;

  @(posedge clk) disable iff (!rst_n)
    (!pwm_out && pwm_sync && $past(pwm_sync)) |=> (!pwm_out); 

endproperty

a_pwm_out_cannot_go_back_up_once_truncated: assert property (p_pwm_out_cannot_go_back_up_once_truncated)
  else begin
    
    sva_pkg::note_failure($sformatf(
      "a_pwm_out_cannot_go_back_up_once_truncated: Pwm went back high after truncation in same cycle"));

  end

c_pwm_out_cannot_go_back_up_once_truncated: cover property (@(posedge clk) disable iff (!rst_n) (!pwm_out && pwm_sync && $past(pwm_sync)));


/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         Reset forces PMW_OUT to low
*/

property p_pwm_out_low_on_reset;

  @(posedge clk)
    !rst_n |-> !pwm_out;

endproperty

a_pwm_out_low_on_reset: assert property(p_pwm_out_low_on_reset)
  else begin
    
    sva_pkg::note_failure($sformatf(
      "a_pwm_out_low_on_reset: Reset did not force pwm_out low"));

  end

c_pwm_out_low_on_reset: cover property (@(posedge clk) !rst_n);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         In low phase the counter resets to zero
*/

property p_counter_0_in_low_phase;

  @(posedge clk) disable iff (!rst_n)
    (!pwm_sync) |=> (dut_run_counter == 0);

endproperty

a_counter_0_in_low_phase: assert property (p_counter_0_in_low_phase)
  else begin
    
    sva_pkg::note_failure($sformatf(
      "a_counter_0_in_low_phase: zero_counter reads: %0d when it should read 0 in the low phase",
      dut_run_counter));

  end

c_counter_0_in_low_phase: cover property (@(posedge clk) disable iff (!rst_n) (!pwm_sync));

/*
////////////////////////////////////////////////////////////////////////////////
*/


/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         Short pulses pass through untouched, analog side retains control
*/


property p_short_pulses_pass;

  @(posedge clk) disable iff (!rst_n)
    (dut_run_counter < max_on_counts) && (pwm_sync)|=> pwm_out;

endproperty

a_short_pulses_pass: assert property (p_short_pulses_pass)
  else begin
    
    sva_pkg::note_failure($sformatf(
      "a_short_pulses_pass: short pulse truncated, dut_run_counter reads: %0d",
      $past(dut_run_counter)));

  end


c_short_pulses_pass: cover property (@(posedge clk) disable iff (!rst_n)
   (pwm_sync && (dut_run_counter < max_on_counts)));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 6:
         UPPER BOUND on on-time. A pulse that reaches the ceiling is cut on
         the next edge. Group 5 is the lower bound; neither alone pins the
         on-time, both together do. Without this a DUT that truncated far
         late would satisfy every other property here.
          The two-edge delay is structural: pulse_allowed is registered from
         run_counter, and pwm_out is registered from pulse_allowed, so the
         ceiling being reached takes two edges to appear at the output. This
         is the realised on-time the DUT header documents as max_on_counts+1,
         seen from the property's side. Chekced from waveform
*/


property p_long_pulses_truncated;

  @(posedge clk) disable iff (!rst_n)
    (pwm_sync && (dut_run_counter >= max_on_counts)) |-> ##2 !pwm_out;

endproperty

a_long_pulses_truncated: assert property (p_long_pulses_truncated)
  else begin
    
    sva_pkg::note_failure($sformatf(
      "a_long_pulses_truncated: pulse longer than clamp allowed to be passed, run counter: %0d",
      $past(dut_run_counter)));

  end

c_long_pulses_truncated: cover property (@(posedge clk) disable iff
   (!rst_n) (pwm_sync && (dut_run_counter >= max_on_counts)));

/*
////////////////////////////////////////////////////////////////////////////////
*/


endmodule

`default_nettype wire

