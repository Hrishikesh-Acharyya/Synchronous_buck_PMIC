/*

# Filename:         soft_start_sva.sv

# File Description: Concurrent assertion checker for soft_start. Attached with
#                   bind so the RTL source carries no assertion constructs and
#                   the sv2v / Yosys ASIC path never sees them. MIN_ON_COUNTS
#                   and ON_TIME_W are passed through from the bound instance,
#                   so the floor and the bus width track the DUT under test.
#
#                   soft_start hands pwm_mask the on-time ceiling, so its claims
#                   are about the duty the power stage is allowed: the ceiling
#                   must never exceed what the host set, must only climb one
#                   count at a time on whole switching-cycle windows, and must
#                   fall back to the floor whenever the supervisor leaves
#                   S_SS / S_RUN, so a hiccup retry re-ramps from the bottom.
#
#                      
#                   Claims 4 and 8 were written against two open problems the
#                   RTL had (known_issues A1: the ramp stopped on == and wrapped
#                   past a lowered limit; and a ramp with limit == floor waited a
#                   whole step period for SS_done). Both fail on the old RTL.
#
#                   Every claim measures switching cycles with the checker's
#                   own falling-edge detector and window counter, not the
#                   DUT's pwm_fall and cycle_counter, so a fencepost in the
#                   DUT's chain cannot appear identically in the reference.
#                   Every claim spanning two edges is gated on out_of_reset,
#                   which an asynchronous reset clears between edges.

# Global variables: None

*/

`default_nettype none

module soft_start_sva #(
    // MIN_ON_COUNTS: the floor the ceiling starts from and returns to
    parameter int MIN_ON_COUNTS = pmic_types_pkg::MIN_ON_COUNTS,
    // ON_TIME_W: width of the ceiling bus
    parameter int ON_TIME_W     = pmic_types_pkg::ON_TIME_W
)(
    input  wire logic                                  clk,
    input  wire logic                                  rst_n,
    input  wire logic                                  pwm_sync,
    input  wire logic                                  ss_active,
    input  wire logic                                  run_active,
    input  wire logic [pmic_types_pkg::CYC_STEP_W-1:0] cycles_per_step,
    input  wire logic [ON_TIME_W-1:0]                  max_on_limit,
    input  wire logic [ON_TIME_W-1:0]                  max_on_counts,
    input  wire logic                                  SS_done
);

// MIN_CNT: the floor at the ceiling bus width
localparam logic [ON_TIME_W-1:0] MIN_CNT = MIN_ON_COUNTS[ON_TIME_W-1:0];

// out_of_reset: low from an asynchronous reset until the first clock edge with
//               rst_n high. Entering edge k it reads 1 only if no reset was
//               seen since edge k-1, so it gates every claim that reaches one
//               edge back - disable iff sees only the edge being evaluated.
logic out_of_reset;
// pwm_sync_q: the checker's own one-clock copy of pwm_sync
logic pwm_sync_q;
// fall: a switching-cycle boundary, from the checker's own copy
logic fall;
// falls_in_window: switching-cycle boundaries counted in the current step
//                  window of a ramp. Counts INTERVALS from the window start,
//                  so entering edge k it reads the falls already seen; the
//                  window completes on the fall that finds it at
//                  cycles_per_step - 1. Cleared outside S_SS: a ramp's first
//                  window starts at S_SS entry.
logic [pmic_types_pkg::CYC_STEP_W-1:0] falls_in_window;
// window_done: this edge's fall completes a step window
logic window_done;

always_ff @(posedge clk or negedge rst_n) begin
  /*
  Purpose:
  ---
  The checker's own reset tracker and edge detector. out_of_reset is cleared
  asynchronously, so a reset pulse that falls entirely between two edges still
  disarms the two-edge claims at the second of them.
  */
  if (!rst_n) begin

    out_of_reset <= 1'b0;
    pwm_sync_q   <= 1'b0;

  end

  else begin

    out_of_reset <= 1'b1;
    pwm_sync_q   <= pwm_sync;

  end

end

always_comb begin

  /*
  Purpose:
  ---
  A switching cycle ends on the falling edge of pwm_sync, which is where the
  header says the ceiling may change - while the pulse is over.
  */
  fall        = pwm_sync_q && !pwm_sync;
  window_done = fall && (falls_in_window == cycles_per_step - 1'b1);

end

always_ff @(posedge clk or negedge rst_n) begin

  /*
  Purpose:
  ---
  The checker's measure of the step window: falls since the ramp started or
  since the last completed window. The restart conditions are the header's by
  necessity - S_SS entry and window completion - but the count is the
  checker's, compared against cycles_per_step independently of the DUT's
  cycle_counter.
  */

  if (!rst_n) begin

    falls_in_window <= '0;

  end

  else if (!ss_active) begin

    falls_in_window <= '0;

  end

  else if (window_done) begin

    falls_in_window <= '0;

  end

  else if (fall) begin

    falls_in_window <= falls_in_window + 1'b1;

  end

end


/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         RESET. While rst_n is low the ceiling sits at the floor and SS_done
         is low. Carries no disable iff - reset is the condition under test,
         and disabling on it would silence the property exactly when it has
         something to say.
*/

property p_reset_floor;

  @(posedge clk)
    !rst_n |-> (max_on_counts == MIN_CNT) && !SS_done;

endproperty

a_reset_floor: assert property (p_reset_floor)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_reset_floor: in reset the ceiling = %0d (floor %0d), SS_done = %b",
      max_on_counts, MIN_CNT, SS_done));

  end

c_reset_floor: cover property (@(posedge clk) !rst_n);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         BACK TO THE FLOOR OUTSIDE S_SS AND S_RUN. Off and in hiccup the
         ceiling returns to the floor and SS_done clears, so the next soft
         start re-ramps from the bottom rather than re-enabling at full duty
         into an unresolved fault. A change, so |=>.
*/

property p_floor_when_idle;

  @(posedge clk) disable iff (!rst_n)
    (!ss_active && !run_active) |=>
      (out_of_reset -> ((max_on_counts == MIN_CNT) && !SS_done));

endproperty

a_floor_when_idle: assert property (p_floor_when_idle)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_floor_when_idle: outside S_SS/S_RUN the ceiling = %0d (floor %0d), SS_done = %b",
      max_on_counts, MIN_CNT, SS_done));

  end

c_floor_when_idle: cover property (@(posedge clk) disable iff (!rst_n)
    !ss_active && !run_active);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         HOLD THROUGH S_RUN. In S_RUN the ceiling is the running duty backstop
         and SS_done stays as the ramp left it. A max_on_limit written during
         S_RUN therefore takes effect at the next soft start, not now - the
         header's "held through S_RUN". $stable describes the transition into
         the next edge, so |=>.
*/

property p_hold_in_run;

  @(posedge clk) disable iff (!rst_n)
    run_active |=> (out_of_reset -> ($stable(max_on_counts) && $stable(SS_done)));

endproperty

a_hold_in_run: assert property (p_hold_in_run)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_hold_in_run: in S_RUN the ceiling went %0d -> %0d, SS_done %b -> %b",
      $past(max_on_counts), max_on_counts, $past(SS_done), SS_done));

  end

c_hold_in_run: cover property (@(posedge clk) disable iff (!rst_n) run_active);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         THE CEILING NEVER EXCEEDS THE LIMIT IN S_SS. Whatever max_on_limit
         held at an S_SS edge, the ceiling after that edge is no higher - so a
         limit the host lowers mid-ramp takes effect on the next clock. This
         is known_issues A1: the RTL used to stop the ramp on == only, and a
         ceiling already above a newly lowered limit kept climbing to the top
         of its range and wrapped, removing the duty backstop for the rest of
         the ramp. Group 5 cannot catch it - a DUT that never clamps leaves
         the ceiling unchanged, which group 5 accepts.

         Two covers: a limit at or above the ceiling, and the clamp case,
         which only a limit lowered below the ceiling builds.
*/

property p_ceiling_within_limit;

  @(posedge clk) disable iff (!rst_n)
    ss_active |=> (out_of_reset -> (max_on_counts <= $past(max_on_limit)));

endproperty

a_ceiling_within_limit: assert property (p_ceiling_within_limit)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_ceiling_within_limit: in S_SS the ceiling = %0d above the limit %0d",
      max_on_counts, $past(max_on_limit)));

  end

c_ceiling_within_limit: cover property (@(posedge clk) disable iff (!rst_n)
    ss_active && (max_on_counts <= max_on_limit));

c_ceiling_clamped: cover property (@(posedge clk) disable iff (!rst_n)
    ss_active && (max_on_counts > max_on_limit));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         The ceiling moves only by a known path. Every way it can change,
         listed before the expression:
           - reset, to the floor (excluded here by out_of_reset; group 1)
           - leaving S_SS / S_RUN, to the floor
           - a completed step window in S_SS below the limit, by exactly +1
           - a clamp in S_SS, to the limit that was above it
         There is no saturation path: the ramp stops at the limit, which the
         step condition already excludes. A DUT that stepped by two, stepped
         mid-window, stepped on a clock rather than a fall, or moved the
         ceiling in S_RUN fails here.

         One cover per path, so a count cannot hide one that never ran.
*/

property p_ceiling_moves_by_known_path;

  @(posedge clk) disable iff (!rst_n)
    (out_of_reset && $changed(max_on_counts)) |->
         ($past(!ss_active && !run_active) && (max_on_counts == MIN_CNT))
      || ($past(ss_active && window_done && (max_on_counts < max_on_limit))
            && (max_on_counts == $past(max_on_counts) + 1'b1))
      || ($past(ss_active && (max_on_counts > max_on_limit))
            && (max_on_counts == $past(max_on_limit)));

endproperty

a_ceiling_moves_by_known_path: assert property (p_ceiling_moves_by_known_path)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_ceiling_moves_by_known_path: ceiling %0d -> %0d with ss_active = %b, run_active = %b, window_done = %b, limit = %0d",
      $past(max_on_counts), max_on_counts, $past(ss_active), $past(run_active),
      $past(window_done), $past(max_on_limit)));

  end

c_ceiling_steps: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $past(ss_active) && (max_on_counts == $past(max_on_counts) + 1'b1));

c_ceiling_to_floor: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $changed(max_on_counts) && $past(!ss_active && !run_active));

c_ceiling_clamp_lands: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $past(ss_active && (max_on_counts > max_on_limit)));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 6:
         UPPER BOUND ON THE STEP. A completed step window in S_SS with the
         ceiling below the limit widens it by one on that edge. Group 5 is
         the lower bound - no step without a completed window - and the two
         only pin the ramp rate together: either alone passes a ceiling that
         never moves, or one that moves on every fall.
*/

property p_window_steps_ceiling;

  @(posedge clk) disable iff (!rst_n)
    (ss_active && window_done && (max_on_counts < max_on_limit)) |=>
      (out_of_reset -> (max_on_counts == $past(max_on_counts) + 1'b1));

endproperty

a_window_steps_ceiling: assert property (p_window_steps_ceiling)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_window_steps_ceiling: window of %0d cycles completed, ceiling %0d -> %0d",
      $past(cycles_per_step), $past(max_on_counts), max_on_counts));

  end

c_window_steps_ceiling: cover property (@(posedge clk) disable iff (!rst_n)
    ss_active && window_done && (max_on_counts < max_on_limit));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 7:
         SS_DONE IS EARNED. It rises only in S_SS, and only with the ceiling
         at the limit it was decided against - a ramp cannot be declared
         finished early. The lower bound; group 8 is the upper.
*/

property p_done_rises_at_target;

  @(posedge clk) disable iff (!rst_n)
    (out_of_reset && $rose(SS_done)) |->
      $past(ss_active) && (max_on_counts == $past(max_on_limit));

endproperty

a_done_rises_at_target: assert property (p_done_rises_at_target)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_done_rises_at_target: SS_done rose with ss_active = %b, ceiling = %0d, limit = %0d",
      $past(ss_active), max_on_counts, $past(max_on_limit)));

  end

c_done_rises: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $rose(SS_done));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 8:
         AT THE TARGET, SS_DONE FOLLOWS. In S_SS, a ceiling at or above the
         limit means the ramp is over, and SS_done is high after that edge.
         Covers three ways to be there: the last step landing, a limit
         lowered below the ceiling (A1), and a ramp with nothing to climb -
         max_on_limit equal to the floor at S_SS entry, which the RTL used to
         hold for a whole step period before declaring done.
*/

property p_done_follows_target;

  @(posedge clk) disable iff (!rst_n)
    (ss_active && (max_on_counts >= max_on_limit)) |=> (out_of_reset -> SS_done);

endproperty

a_done_follows_target: assert property (p_done_follows_target)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_done_follows_target: ceiling %0d at or above limit %0d in S_SS, SS_done still low",
      $past(max_on_counts), $past(max_on_limit)));

  end

c_done_follows_target: cover property (@(posedge clk) disable iff (!rst_n)
    ss_active && (max_on_counts >= max_on_limit));

c_no_ramp_needed: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && ss_active && !$past(ss_active) && (max_on_counts == max_on_limit));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 9:
         SS_DONE LANDS WITH THE LAST STEP. On the edge the ceiling steps onto
         the limit, SS_done is set on that same edge - from the value about to
         land, as the RTL comment promises - so the ramp does not finish a
         step late. Group 8 alone passes a DUT that raises SS_done one clock
         after the last step.
*/

property p_done_with_last_step;

  @(posedge clk) disable iff (!rst_n)
    (out_of_reset && $past(ss_active)
        && (max_on_counts == $past(max_on_counts) + 1'b1)
        && (max_on_counts == $past(max_on_limit)))
      |-> SS_done;

endproperty

a_done_with_last_step: assert property (p_done_with_last_step)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_done_with_last_step: ceiling stepped onto the limit %0d but SS_done is low",
      max_on_counts));

  end

c_done_with_last_step: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $past(ss_active)
      && (max_on_counts == $past(max_on_counts) + 1'b1)
      && (max_on_counts == $past(max_on_limit)));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 10:
         SS_DONE FALLS ONLY ON LEAVING S_SS / S_RUN. Every path down, listed:
         reset (group 1, excluded here by out_of_reset) and leaving both
         states (group 2). A DUT that dropped SS_done when the host raised the
         limit mid-ramp, or in S_RUN, fails here.
*/

property p_done_falls_on_exit;

  @(posedge clk) disable iff (!rst_n)
    (out_of_reset && $fell(SS_done)) |-> $past(!ss_active && !run_active);

endproperty

a_done_falls_on_exit: assert property (p_done_falls_on_exit)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_done_falls_on_exit: SS_done fell with ss_active = %b, run_active = %b",
      $past(ss_active), $past(run_active)));

  end

c_done_falls_on_exit: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $fell(SS_done));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: INPUT CONTRACTS. Not claims about soft_start - promises its
         neighbours make, written as assertions so a violation points at the
         module that broke it rather than at a confusing failure above.
           - supervisor: ss_active and run_active are never high together;
             they decode two different states.
           - reg_file: max_on_limit is clamped to at least the floor
             (clamp_max_on), and cycles_per_step to at least 1
             (clamp_cyc_step) - zero would make the step condition never
             match.
           - reg_file: cycles_per_step is written only in S_OFF (off_ok), so
             it is stable for the whole of a ramp.
         No covers: the first two have no antecedent, and the last shares
         its antecedent with groups 4 to 9.
*/

property p_contract_states_exclusive;

  @(posedge clk) disable iff (!rst_n)
    !(ss_active && run_active);

endproperty

a_contract_states_exclusive: assert property (p_contract_states_exclusive)
  else begin

    sva_pkg::note_failure("a_contract_states_exclusive: supervisor drove ss_active and run_active together");

  end

property p_contract_inputs_legal;

  @(posedge clk) disable iff (!rst_n)
    (max_on_limit >= MIN_CNT) && (cycles_per_step != '0);

endproperty

a_contract_inputs_legal: assert property (p_contract_inputs_legal)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_contract_inputs_legal: reg_file delivered max_on_limit = %0d (floor %0d), cycles_per_step = %0d",
      max_on_limit, MIN_CNT, cycles_per_step));

  end

property p_contract_step_stable;

  @(posedge clk) disable iff (!rst_n)
    (out_of_reset && ss_active && $past(ss_active)) |-> $stable(cycles_per_step);

endproperty

a_contract_step_stable: assert property (p_contract_step_stable)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_contract_step_stable: reg_file changed cycles_per_step %0d -> %0d mid-ramp",
      $past(cycles_per_step), cycles_per_step));

  end

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: Directed-scenario covers. No assertion of their own - the groups
         above state what must hold - but each is the evidence that the
         testbench actually built the case.

         c_one_cycle_steps: cycles_per_step = 1, the lowest legal value, where
                            every fall is a whole window.
         c_limit_raised_mid_ramp: the host raises max_on_limit during S_SS;
                            the ramp must carry on to the new target.
         c_static_pwm_in_ss: S_SS with pwm_sync not moving - no falls, so the
                            ceiling must not move.
         c_reset_mid_ramp:  reset while ramping.
         c_ss_left_unfinished: S_SS left before SS_done, as a hiccup does.
         c_ceiling_at_top:  the ceiling at the top of its bus range, where a
                            stepping DUT would wrap.
*/

c_one_cycle_steps: cover property (@(posedge clk) disable iff (!rst_n)
    ss_active && window_done && (cycles_per_step == 1));

c_limit_raised_mid_ramp: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && ss_active && $past(ss_active) && (max_on_limit > $past(max_on_limit)));

c_static_pwm_in_ss: cover property (@(posedge clk) disable iff (!rst_n)
    ss_active && $stable(pwm_sync) && $past($stable(pwm_sync)) && $past($stable(pwm_sync), 2));

c_reset_mid_ramp: cover property (@(posedge clk) !rst_n && ss_active);

c_ss_left_unfinished: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $past(ss_active && !SS_done) && !ss_active);

c_ceiling_at_top: cover property (@(posedge clk) disable iff (!rst_n)
    max_on_counts == {ON_TIME_W{1'b1}});

/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire
