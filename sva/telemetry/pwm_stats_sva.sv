/*

# Filename:         pwm_stats_sva.sv

# File Description: Concurrent assertion checker for pwm_stats. Attached with
#                   bind so the RTL source carries no assertion constructs and
#                   the sv2v / Yosys ASIC path never sees them. CNT_W is
#                   passed through from the bound instance, so the testbench
#                   can run a six-bit counter and reach the wrap while
#                   pmic_top is still checked against the real eight.
#
#                   THE DOCUMENTED OFFSET. Both outputs read exactly one below
#                   the true count, and this file is where that number was
#                   settled. pwm_rise clears period_counter on the same edge
#                   it latches prev_period, so the counter enters the new
#                   period at zero and only reaches one on the second edge:
#
#                     true period  = R - 1 clocks   captured = R - 2
#                     true on-time = H clocks       captured = H - 1
#
#                   The offset is the same on both, so the ratio the host
#                   computes is close but not exact - at the nominal 83 / 111
#                   it reads 82 / 110, a duty error of about 0.4 %. That is
#                   well inside the tolerance the analog modulator already
#                   carries, and correcting it would cost an extra compare in
#                   the capture path for no gain. Documented rather than
#                   fixed; the host can add one to each if it cares.
#
#                   pwm_rise and pwm_fall are recomputed here as $rose and
#                   $fell on pwm_sync rather than read from the DUT. The DUT
#                   derives them from a registered delayed copy, which is the
#                   same edge by construction, so an independent copy costs
#                   nothing and a bug in that copy does not cancel out.
#
#                   Telemetry only. Nothing here drives a control path, but
#                   duty times a known Vin infers Vout with no ADC in the
#                   loop, so a capture error shows up as an output voltage the
#                   host believes and cannot cross-check.

# Global variables: None

*/

`default_nettype none

module pwm_stats_sva #(
    parameter int CNT_W = pmic_types_pkg::CNT_W
)(
    input  wire logic             clk,
    input  wire logic             rst_n,
    input  wire logic             pwm_sync,
    input  wire logic [CNT_W-1:0] duty_count,
    input  wire logic [CNT_W-1:0] prev_period,
    // DUT internal, connected explicitly in bind_sva.sv. period_counter is
    // named in pwm_stats.sv's own header and is what both outputs are
    // captured from, so it is part of the contract rather than an
    // implementation detail.
    input  wire logic [CNT_W-1:0] dut_period_counter
);

// same_run: high between a rise and the following fall, which is the window
//           in which duty_count and prev_period both describe the previous
//           complete period. Outside it duty_count is one cycle ahead of
//           prev_period and the two are legitimately inconsistent.
logic same_run;

always_ff @(posedge clk or negedge rst_n) begin
  /*
  Purpose:
  ---
  Track whether the two outputs currently describe the same counter run.
  Set on a rise, because that is the edge prev_period catches up to the cycle
  duty_count already described. Cleared on a fall, because that is where
  duty_count moves on to the new cycle and prev_period has not yet followed.

  Cleared by reset as well, so the first comparison after release waits for a
  genuine rise rather than trusting whatever the outputs held.
  */
  if (!rst_n)                              same_run <= 1'b0;
  else if (pwm_sync && !$past(pwm_sync))   same_run <= 1'b1;
  else if (!pwm_sync && $past(pwm_sync))   same_run <= 1'b0;
end


/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         All three outputs are zero at every edge while rst_n is low. Carries
         no disable iff - reset is the condition under test, and disabling on
         it would silence the property exactly when it has something to say.
*/

property p_outputs_zero_in_reset;

  @(posedge clk)
    (!rst_n) |-> ((duty_count == '0) && (prev_period == '0) && (dut_period_counter == '0));

endproperty

a_outputs_zero_in_reset: assert property (p_outputs_zero_in_reset)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_outputs_zero_in_reset: in reset with duty=%0d prev=%0d counter=%0d",
      duty_count, prev_period, dut_period_counter));

  end

c_outputs_zero_in_reset: cover property (@(posedge clk) (!rst_n));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         period_counter clears on a rise and advances by exactly one on every
         other clock - including the fall, which captures duty_count without
         interrupting the count. Two properties because they are the two
         halves of the counter's behaviour and neither alone rules out a
         counter that cleared on the wrong edge.

         Guarded on $past(rst_n): both reach one edge back, and disable iff
         only covers the edge being evaluated. A reset asserted mid-cycle
         clears the counter between edges, so at the next edge it is
         legitimately zero while the edge before said otherwise.

         The advance property excludes the ceiling: once period_counter
         saturates it holds rather than increments, which group 6 asserts.
         Without the exclusion the two properties contradict each other on
         every clock of a stalled input.
*/

property p_counter_clears_on_rise;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && $rose(pwm_sync)) |=> (dut_period_counter == '0);

endproperty

a_counter_clears_on_rise: assert property (p_counter_clears_on_rise)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_counter_clears_on_rise: period_counter=%0d on the clock after a rise",
      dut_period_counter));

  end

property p_counter_advances_otherwise;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && !$rose(pwm_sync) && (dut_period_counter != '1))
        |=> (dut_period_counter == $past(dut_period_counter) + 1'b1);

endproperty

a_counter_advances_otherwise: assert property (p_counter_advances_otherwise)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_counter_advances_otherwise: period_counter went %0d -> %0d with no rise",
      $past(dut_period_counter), dut_period_counter));

  end

c_counter_clears_on_rise: cover property (@(posedge clk) disable iff (!rst_n)
                              $rose(pwm_sync));

c_counter_advances_on_fall: cover property (@(posedge clk) disable iff (!rst_n)
                                $fell(pwm_sync));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         prev_period takes period_counter on a rise and holds it until the
         next one. The capture is the period measurement, and the hold is what
         makes the value readable by a host that polls at an unrelated rate.

         The captured value is the counter as it entered the rise edge, which
         is one below the true period - see the offset note in the header.
*/

property p_prev_period_captures_on_rise;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && $rose(pwm_sync)) |=> (prev_period == $past(dut_period_counter, 1));

endproperty

a_prev_period_captures_on_rise: assert property (p_prev_period_captures_on_rise)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_prev_period_captures_on_rise: prev_period=%0d, counter was %0d at the rise",
      prev_period, $past(dut_period_counter, 1)));

  end

property p_prev_period_stable_otherwise;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && !$rose(pwm_sync)) |=> $stable(prev_period);

endproperty

a_prev_period_stable_otherwise: assert property (p_prev_period_stable_otherwise)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_prev_period_stable_otherwise: prev_period went %0d -> %0d with no rise",
      $past(prev_period), prev_period));

  end

c_prev_period_nonzero: cover property (@(posedge clk) disable iff (!rst_n)
                           (prev_period != '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         duty_count takes period_counter on a fall and holds it until the next
         one. The mirror of group 3, measuring the high phase rather than the
         whole period.

         Note the fall does NOT clear the counter - it only samples it. That
         is what lets prev_period at the following rise describe the whole
         period rather than just the low phase, and it is why group 2's
         advance property has no fall term in its antecedent.
*/

property p_duty_count_captures_on_fall;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && $fell(pwm_sync)) |=> (duty_count == $past(dut_period_counter, 1));

endproperty

a_duty_count_captures_on_fall: assert property (p_duty_count_captures_on_fall)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_duty_count_captures_on_fall: duty_count=%0d, counter was %0d at the fall",
      duty_count, $past(dut_period_counter, 1)));

  end

property p_duty_count_stable_otherwise;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && !$fell(pwm_sync)) |=> $stable(duty_count);

endproperty

a_duty_count_stable_otherwise: assert property (p_duty_count_stable_otherwise)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_duty_count_stable_otherwise: duty_count went %0d -> %0d with no fall",
      $past(duty_count), duty_count));

  end

c_duty_count_nonzero: cover property (@(posedge clk) disable iff (!rst_n)
                          (duty_count != '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         Within a single counter run the high phase cannot exceed
         the whole period, so duty_count never reads above prev_period.

         The header claims both outputs are captured from the same run and are
         therefore always consistent with each other. That is only true inside
         a window: duty_count updates at the fall of cycle N, prev_period at
         the rise beginning cycle N+1. Between those two edges duty_count
         already describes cycle N while prev_period still describes N-1, and
         a comparison there is meaningless rather than wrong.

         same_run marks the window, so this property states the claim the
         header actually makes rather than a stronger one that would fire on
         correct hardware.
*/

property p_duty_within_period;

  @(posedge clk) disable iff (!rst_n)
    same_run |-> (duty_count <= prev_period);

endproperty

a_duty_within_period: assert property (p_duty_within_period)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_duty_within_period: duty_count=%0d exceeds prev_period=%0d in one run",
      duty_count, prev_period));

  end

c_duty_within_period: cover property (@(posedge clk) disable iff (!rst_n)
                          same_run && (duty_count != '0) && (prev_period != '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 6:
         period_counter saturates at all-ones rather than wrapping. CNT_W is
         sized from CLKS_PER_SW plus a spare bit for oscillator drift, so a
         period within tolerance never reaches the ceiling - only a stalled or
         stuck-high pwm_sync does.

         Written as two properties: the counter never decreases except on a
         rise, and once at the ceiling it stays there. The first is what
         caught the original defect, where the counter rolled 63 -> 0 and the
         next captured period would have read as a very short one.
*/

property p_counter_never_wraps;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && !$rose(pwm_sync)) |=> (dut_period_counter >= $past(dut_period_counter));

endproperty

a_counter_never_wraps: assert property (p_counter_never_wraps)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_counter_never_wraps: period_counter went %0d -> %0d, wrapped",
      $past(dut_period_counter), dut_period_counter));

  end

property p_counter_holds_at_ceiling;

  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && (dut_period_counter == '1) && !$rose(pwm_sync))
        |=> (dut_period_counter == '1);

endproperty

a_counter_holds_at_ceiling: assert property (p_counter_holds_at_ceiling)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_counter_holds_at_ceiling: period_counter left the ceiling, now %0d",
      dut_period_counter));

  end

c_counter_saturated: cover property (@(posedge clk) disable iff (!rst_n)
                         (dut_period_counter == '1));

/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire

