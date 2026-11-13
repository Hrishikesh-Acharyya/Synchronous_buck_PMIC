/*

# Filename:         strike_counter_sva.sv

# File Description: Concurrent assertion checker for strike_counter. Attached
#                   with bind so the RTL source carries no assertion
#                   constructs and the sv2v / Yosys ASIC path never sees them.
#                   CLEAN_RUN_W and STRIKE_W are passed through from the bound
#                   instance.
#
#                   strike_counter decides when the converter stops retrying
#                   and trips the SCR latch - a physical, set-only shutdown -
#                   so these are protection claims: the latch must trip on the
#                   strike that reaches MAX_STRIKES and not before, must never
#                   un-trip in logic, and the strike count must only be
#                   forgiven by a genuinely fault-free run.
#
#                   Contract, from the module header and its Purpose blocks:
#                     1 (I) reset clears strike_level and latch_assert
#                     2 (E) each hiccup entry adds exactly one strike, on that
#                           edge, and wins over a clean-run clear
#                     3 (I) strike_level moves only by +1 on an entry, to 0
#                           after a clean run, or by reset - it is not zeroed
#                           on latching, so the count stays readable
#                     4 (E) latch_assert rises only on an entry whose strike
#                           reaches or passes max_strikes
#                     5 (E) every such entry raises it
#                     6 (I) latch_assert is set-only; only reset clears it
#                     7 (E) strikes clear only after clean_run_target
#                           consecutive fault-free switching cycles in S_RUN;
#                           a window_trip or leaving S_RUN breaks the streak
#                     8 (E) a completed clean run does clear them
#
#                   "Reaches or passes" is known_issues A2, fixed in the RTL:
#                   max_strikes is host-writable at any time, and the RTL used
#                   to test strike_level == max_strikes - 1, so a limit lowered
#                   below the present count was missed, the 2-bit level
#                   wrapped and the latch tripped up to four hiccups late. The
#                   checker compares at integer width, so no wrap can hide in
#                   the reference, and the testbench still builds the case
#                   (c_strikes_above_max) as a regression test.
#
#                   Entries and switching cycles are detected with the
#                   checker's own edge detectors and the clean run is timed
#                   with its own counter, never the DUT's hiccup_entry,
#                   pwm_fall or clean_counter.

# Global variables: None

*/

`default_nettype none

module strike_counter_sva
#(
    // CLEAN_RUN_W: width of the clean-run target
    parameter int CLEAN_RUN_W = pmic_types_pkg::CLEAN_RUN_W,
    // STRIKE_W: width of the strike level bus
    parameter int STRIKE_W    = pmic_types_pkg::STRIKE_W
)(
    input  wire logic                   clk,
    input  wire logic                   rst_n,
    input  wire logic                   pwm_sync,
    input  wire logic                   hiccup_active,
    input  wire logic                   run_active,
    input  wire logic                   window_trip,
    input  wire logic [STRIKE_W-1:0]    max_strikes,
    input  wire logic [CLEAN_RUN_W-1:0] clean_run_target,
    input  wire logic [STRIKE_W-1:0]    strike_level,
    input  wire logic                   latch_assert
);

// out_of_reset: low from an asynchronous reset until the first clock edge with
//               rst_n high. Entering edge k it reads 1 only if no reset was
//               seen since edge k-1, so it gates every claim that reaches one
//               edge back - disable iff sees only the edge being evaluated.
logic out_of_reset;
// hiccup_active_q / pwm_sync_q: the checker's own one-clock copies
logic hiccup_active_q;
logic pwm_sync_q;
// entry: this edge is the first in S_HICCUP - one strike
logic entry;
// fall: a switching-cycle boundary
logic fall;
// clean_cycles: consecutive fault-free switching cycles in S_RUN, saturating
//               at clean_run_target. Counts INTERVALS: entering edge k it
//               reads the cycles completed before k. The restarts are the
//               header's by necessity - leaving S_RUN and window_trip break
//               the streak - the count and saturation are the checker's.
logic [CLEAN_RUN_W-1:0] clean_cycles;
// clean_run_due: the streak has reached the target
logic clean_run_due;

always_ff @(posedge clk or negedge rst_n) begin

  /*
  Purpose:
  ---
  The checker's own reset tracker and edge detectors. out_of_reset is cleared
  asynchronously, so a reset pulse between two edges still disarms the
  two-edge claims at the second of them.
  */

  if (!rst_n) begin

    out_of_reset    <= 1'b0;
    hiccup_active_q <= 1'b0;
    pwm_sync_q      <= 1'b0;

  end

  else begin

    out_of_reset    <= 1'b1;
    hiccup_active_q <= hiccup_active;
    pwm_sync_q      <= pwm_sync;

  end

end

always_comb begin

  /*
  Purpose:
  ---
  One strike per hiccup, not per clock of it; one clean cycle per switching
  cycle, not per clock.
  */

  entry         = hiccup_active && !hiccup_active_q;
  fall          = pwm_sync_q && !pwm_sync;
  clean_run_due = (clean_cycles == clean_run_target);

end

always_ff @(posedge clk or negedge rst_n) begin

  /*
  Purpose:
  ---
  The checker's measure of the clean run: switching cycles completed in S_RUN
  with no window_trip, back to zero on either break, held once the target is
  reached.
  */

  if (!rst_n) begin

    clean_cycles <= '0;

  end

  else if (!run_active || window_trip) begin

    clean_cycles <= '0;

  end

  else if (fall && !clean_run_due) begin

    clean_cycles <= clean_cycles + 1'b1;

  end

end


/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         RESET. While rst_n is low the count is zero and the latch request is
         low. Carries no disable iff - reset is the condition under test, and
         disabling on it would silence the property exactly when it has
         something to say. rst_n is the only thing that clears latch_assert,
         because the SCR it trips and the manual drain button are on the same
         line.
*/

property p_reset_clears;

  @(posedge clk)
    !rst_n |-> (strike_level == '0) && !latch_assert;

endproperty

a_reset_clears: assert property (p_reset_clears)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_reset_clears: in reset strike_level = %0d, latch_assert = %b",
      strike_level, latch_assert));

  end

c_reset_clears: cover property (@(posedge clk) !rst_n);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         ONE STRIKE PER HICCUP ENTRY. The edge that first samples
         hiccup_active high adds exactly one strike, and wins over a clean-run
         clear on the same edge. A DUT that counted every clock of the
         cool-down, or let a clean run swallow the entry, fails here. The
         increment is at the bus width, so a count that wraps (A2) still
         reads as +1 here.

         Two covers: an ordinary entry, and one landing on the edge a clean
         run completes, where the priority shows.
*/

property p_strike_per_entry;

  @(posedge clk) disable iff (!rst_n)
    entry |=> (out_of_reset -> (strike_level == $past(strike_level) + 1'b1));

endproperty

a_strike_per_entry: assert property (p_strike_per_entry)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_strike_per_entry: hiccup entry took strike_level %0d -> %0d",
      $past(strike_level), strike_level));

  end

c_strike_per_entry: cover property (@(posedge clk) disable iff (!rst_n) entry);

c_entry_beats_clear: cover property (@(posedge clk) disable iff (!rst_n)
    entry && clean_run_due && (strike_level != '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         THE COUNT MOVES ONLY BY A KNOWN PATH. Every way strike_level can
         change, listed before the expression:
           - reset, to zero (excluded here by out_of_reset; group 1)
           - a hiccup entry, by +1 (group 2)
           - a completed clean run with no entry, to zero
         There is no saturation path and no clear on latching: the header
         keeps the count readable after the latch trips. A DUT that cleared
         the count on latch_assert, on leaving S_RUN, or on any fault-free
         clock fails here.

         One cover per path.
*/

property p_level_moves_by_known_path;

  @(posedge clk) disable iff (!rst_n)
    (out_of_reset && $changed(strike_level)) |->
         ($past(entry) && (strike_level == $past(strike_level) + 1'b1))
      || ($past(!entry && run_active && clean_run_due) && (strike_level == '0));

endproperty

a_level_moves_by_known_path: assert property (p_level_moves_by_known_path)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_level_moves_by_known_path: strike_level %0d -> %0d with entry = %b, run_active = %b, clean run %0d of %0d",
      $past(strike_level), strike_level, $past(entry), $past(run_active),
      $past(clean_cycles), $past(clean_run_target)));

  end

c_level_up: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $past(entry) && $changed(strike_level));

c_level_cleared: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $past(!entry) && $changed(strike_level) && (strike_level == '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         THE LATCH IS EARNED. latch_assert rises only off a hiccup entry whose
         strike brings the count to max_strikes or past it - so a converter is
         never shut down permanently a strike early. The lower bound; group 5
         is the upper. Compared at integer width: the 2-bit count never wraps
         in the reference.

         One cover per max_strikes value the testbench runs, so the
         comparison is shown at each, not just the default.
*/

property p_latch_earned;

  @(posedge clk) disable iff (!rst_n)
    (out_of_reset && $rose(latch_assert)) |->
      $past(entry) && (int'($past(strike_level)) + 1 >= int'($past(max_strikes)));

endproperty

a_latch_earned: assert property (p_latch_earned)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_latch_earned: latch_assert rose with entry = %b, strike_level = %0d, max_strikes = %0d",
      $past(entry), $past(strike_level), $past(max_strikes)));

  end

c_latch_at_max1: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $rose(latch_assert) && (max_strikes == 1));
c_latch_at_max2: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $rose(latch_assert) && (max_strikes == 2));
c_latch_at_max3: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $rose(latch_assert) && (max_strikes == 3));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         THE LAST STRIKE TRIPS THE LATCH. A hiccup entry that brings the count
         to max_strikes, or past it, raises latch_assert on that edge - from
         the value about to land, so the latch trips on the right hiccup
         rather than one later. "Past it" covers a MAX_STRIKES the host has
         lowered below the present count (known_issues A2, fixed): the first
         hiccup after that write trips the latch. Group 4 alone passes a DUT
         that never trips.

         Two covers: the ordinary last strike, and an entry with the count
         already at or above the limit.
*/

property p_last_strike_trips;

  @(posedge clk) disable iff (!rst_n)
    (entry && (int'(strike_level) + 1 >= int'(max_strikes)))
      |=> (out_of_reset -> latch_assert);

endproperty

a_last_strike_trips: assert property (p_last_strike_trips)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_last_strike_trips: strike %0d of %0d landed, latch_assert still low",
      $past(strike_level) + 1'b1, $past(max_strikes)));

  end

c_last_strike_trips: cover property (@(posedge clk) disable iff (!rst_n)
    entry && (int'(strike_level) + 1 == int'(max_strikes)));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 6:
         SET-ONLY. Once latch_assert is high it stays high until reset: it
         trips a physical SCR, which logic cannot un-trip. A DUT that dropped
         it when the count cleared, or on leaving S_HICCUP, fails here. A
         property about holding through everything except reset, so the
         reset path is excluded by disable iff and out_of_reset, and group 1
         covers it.
*/

property p_latch_held;

  @(posedge clk) disable iff (!rst_n)
    latch_assert |=> (out_of_reset -> latch_assert);

endproperty

a_latch_held: assert property (p_latch_held)
  else begin

    sva_pkg::note_failure("a_latch_held: latch_assert fell without a reset");

  end

c_latch_held: cover property (@(posedge clk) disable iff (!rst_n)
    latch_assert && $past(latch_assert) && $past(entry || run_active));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 7:
         FORGIVEN ONLY BY A CLEAN RUN. A non-zero count goes to zero without a
         reset only off an edge at which clean_run_target consecutive
         fault-free switching cycles had completed in S_RUN. The lower bound:
         a DUT whose streak survived a hiccup, a window_trip or a spell out of
         S_RUN - and so forgave strikes a persistent fault had earned - fails
         here, as does one counting clocks instead of cycles. Group 8 is the
         upper bound.
*/

property p_clear_earned;

  @(posedge clk) disable iff (!rst_n)
    (out_of_reset && $fell(|strike_level) && !$past(entry)) |->
      $past(run_active && clean_run_due);

endproperty

a_clear_earned: assert property (p_clear_earned)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_clear_earned: strikes cleared after %0d clean cycles of %0d (run_active = %b)",
      $past(clean_cycles), $past(clean_run_target), $past(run_active)));

  end

c_clear_earned: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $fell(|strike_level) && !$past(entry));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 8:
         A CLEAN RUN DOES FORGIVE. In S_RUN, a completed clean run with no
         hiccup entry leaves the count at zero after that edge, so unrelated
         transients separated in time do not add up to a permanent shutdown.
         Group 7 alone passes a DUT that never clears.
*/

property p_clean_run_clears;

  @(posedge clk) disable iff (!rst_n)
    (run_active && clean_run_due && !entry) |=> (out_of_reset -> (strike_level == '0));

endproperty

a_clean_run_clears: assert property (p_clean_run_clears)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_clean_run_clears: %0d clean cycles completed, strike_level still %0d",
      $past(clean_run_target), strike_level));

  end

c_clean_run_clears: cover property (@(posedge clk) disable iff (!rst_n)
    run_active && clean_run_due && !entry && (strike_level != '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: INPUT CONTRACTS. Not claims about strike_counter - promises its
         neighbours make, written as assertions so a violation points at the
         module that broke it rather than at a confusing failure above.
           - supervisor: hiccup_active and run_active are never high
             together; they decode two different states.
           - reg_file: max_strikes is clamped to at least 1
             (clamp_max_strikes), and clean_run_target to at least
             CLEAN_RUN_MIN_CYCLES - never zero.
           - reg_file: clean_run_target is written only in S_OFF (off_ok), so
             it is stable for the whole of a run.
         No covers: the first two have no antecedent, and the last shares
         its antecedent with groups 7 and 8.
*/

property p_contract_states_exclusive;

  @(posedge clk) disable iff (!rst_n)
    !(hiccup_active && run_active);

endproperty

a_contract_states_exclusive: assert property (p_contract_states_exclusive)
  else begin

    sva_pkg::note_failure("a_contract_states_exclusive: supervisor drove hiccup_active and run_active together");

  end

property p_contract_inputs_legal;

  @(posedge clk) disable iff (!rst_n)
    (max_strikes != '0) && (clean_run_target != '0);

endproperty

a_contract_inputs_legal: assert property (p_contract_inputs_legal)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_contract_inputs_legal: reg_file delivered max_strikes = %0d, clean_run_target = %0d",
      max_strikes, clean_run_target));

  end

property p_contract_target_stable;

  @(posedge clk) disable iff (!rst_n)
    (out_of_reset && run_active && $past(run_active)) |-> $stable(clean_run_target);

endproperty

a_contract_target_stable: assert property (p_contract_target_stable)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_contract_target_stable: reg_file changed clean_run_target %0d -> %0d in S_RUN",
      $past(clean_run_target), clean_run_target));

  end

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: Directed-scenario covers. No assertion of their own - the groups
         above state what must hold - but each is the evidence that the
         testbench actually built the case.

         c_streak_broken_by_trip: a window_trip part-way through a clean run.
         c_streak_broken_by_exit: S_RUN left part-way through a clean run.
         c_static_pwm_in_run:  S_RUN with pwm_sync not moving - no cycles, so
                               no clean-run progress.
         c_reset_mid_streak:   reset part-way through a clean run.
         c_strikes_above_max:  a hiccup entry with strike_level already at or
                               above max_strikes - the A2 case, which must
                               trip the latch at once.
*/

c_streak_broken_by_trip: cover property (@(posedge clk) disable iff (!rst_n)
    run_active && window_trip && (clean_cycles != '0));

c_streak_broken_by_exit: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && !run_active && $past(run_active)
      && (clean_cycles != '0) && !clean_run_due);

c_static_pwm_in_run: cover property (@(posedge clk) disable iff (!rst_n)
    run_active && $stable(pwm_sync) && $past($stable(pwm_sync)) && $past($stable(pwm_sync), 2));

c_reset_mid_streak: cover property (@(posedge clk) !rst_n && run_active && ($past(clean_cycles) != '0));

c_strikes_above_max: cover property (@(posedge clk) disable iff (!rst_n)
    entry && (strike_level >= max_strikes));

/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire
