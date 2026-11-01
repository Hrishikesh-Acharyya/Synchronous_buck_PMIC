/*

# Filename:         supervisor_sva.sv

# File Description: Bound checker for supervisor, the converter's four-state
#                   FSM (S_OFF, S_SS, S_RUN, S_HICCUP). Groups 1-5 cover
#                   reset, the state decode and the gate-driver enable;
#                   groups 6-10 pin the next state for every state and every
#                   input combination, so the header's headline promises - a
#                   retry always re-ramps, S_RUN is reached only through
#                   S_SS - follow from them rather than being written twice.
#
#                   en is the safety-critical output. It is combinational on
#                   the state AND on the hard faults, so every en claim is
#                   same-edge. state_out is registered, so every transition
#                   claim reaches one edge forward with |=>.

# Global variables: None

*/

`default_nettype none

module supervisor_sva
    import pmic_types_pkg::*;
(
    input  wire logic    clk,
    input  wire logic    rst_n,
    input  wire logic    en_SW,
    input  wire logic    spi_enable,
    input  wire logic    OTP,
    input  wire logic    UVLO,
    input  wire logic    latch_state,
    input  wire logic    latch_assert,
    input  wire logic    SS_done,
    input  wire logic    window_trip_SS,
    input  wire logic    window_trip,
    input  wire logic    hiccup_done,
    input  wire logic    en,              // DUT output
    input  wire logic    ss_active,       // DUT output
    input  wire logic    run_active,      // DUT output
    input  wire logic    hiccup_active,   // DUT output
    input  wire state_t  state_out        // DUT output
);




// out_of_reset: low from an asynchronous reset until the first clock edge
//               with rst_n high. Read entering edge k, high means no reset
//               has been seen since edge k-1, so it gates every claim that
//               reaches one edge forward - disable iff sees only the edge
//               being evaluated.
logic out_of_reset;
// fault_cause: the six hard-fault causes as a vector, for the per-cause
//              covers. Bit order: [5] en_SW lost, [4] spi_enable lost,
//              [3] OTP, [2] UVLO, [1] latch_state, [0] latch_assert.
//              The two enables are separate bits, not g_en, so the stimulus
//              must exercise each one on its own.
logic [5:0] fault_cause;

always_ff @(posedge clk or negedge rst_n) begin
/*
Purpose:
---
The checker's own reset tracker. Cleared asynchronously, so a reset pulse that
falls entirely between two edges - asserted and released inside one clock
period - still disarms the transition claims at the second of them. rst_n
sampled at either edge would miss it.
*/
  if (!rst_n) out_of_reset <= 1'b0;
  else        out_of_reset <= 1'b1;
end

always_comb begin
/*
Purpose:
---
  The six hard-fault causes as separate bits. hard_fault is their OR, so the
  list is written once. Kept as a vector so the directed covers can demand one
  cause ALONE: a DUT that ignored OTP would otherwise pass every OTP cover on
  edges where UVLO happened to be high as well.
*/
  fault_cause = {!en_SW, !spi_enable, OTP, UVLO, latch_state, latch_assert};

end

// hard_fault: any condition the supervisor header lists as forcing S_OFF
//             from every state - either enable lost, OTP, UVLO, the latch
//             read-back, or strike_counter's latch trip
logic hard_fault;

always_comb begin
/*
Purpose:
---
One definition of "hard fault", taken from the module header's list, shared by
every property that needs it. The RTL spells this list out separately in each
state's branch and again in the en expression; a term dropped from any one of
those copies shows up as a disagreement with this single signal.
*/
  hard_fault = |fault_cause;

end
/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         RESET MEANS OFF. While rst_n is low the FSM is in S_OFF and en is
         low, so the converter never powers up switching. Carries no
         disable iff - reset is the condition under test.
*/

property p_reset_means_off;

  @(posedge clk)
    (!rst_n) |-> (state_out == S_OFF) && !en;

endproperty

a_reset_means_off: assert property (p_reset_means_off)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_reset_means_off: under reset expected S_OFF with en low, got %s with en = %b",
      state_out.name(), en));

  end

c_reset_means_off: cover property (@(posedge clk) (!rst_n));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         STATE DECODE. Each *_active flag is high exactly when state_out is
         its state. Written as an equality, so it pins both directions: a flag
         stuck high fails as surely as a flag stuck low. Plain Booleans - the
         antecedent would always be true. Same edge, since the decode is
         combinational on the same register state_out reads.

         "At most one flag high" is NOT written: it follows from these three,
         because state_out holds one value at a time.

         One cover per state, including S_OFF, so every row of the decode is
         shown to have been evaluated with its flag both high and low.
*/

property p_ss_active_decode;

  @(posedge clk) disable iff (!rst_n)
    ss_active == (state_out == S_SS);

endproperty

a_ss_active_decode: assert property (p_ss_active_decode)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_ss_active_decode: ss_active = %b in state %s",
      ss_active, state_out.name()));

  end


property p_run_active_decode;

  @(posedge clk) disable iff (!rst_n)
    run_active == (state_out == S_RUN);

endproperty

a_run_active_decode: assert property (p_run_active_decode)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_run_active_decode: run_active = %b in state %s",
      run_active, state_out.name()));

  end


property p_hiccup_active_decode;

  @(posedge clk) disable iff (!rst_n)
    hiccup_active == (state_out == S_HICCUP);

endproperty

a_hiccup_active_decode: assert property (p_hiccup_active_decode)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_hiccup_active_decode: hiccup_active = %b in state %s",
      hiccup_active, state_out.name()));

  end


c_state_off:    cover property (@(posedge clk) disable iff (!rst_n) state_out == S_OFF);
c_state_ss:     cover property (@(posedge clk) disable iff (!rst_n) state_out == S_SS);
c_state_run:    cover property (@(posedge clk) disable iff (!rst_n) state_out == S_RUN);
c_state_hiccup: cover property (@(posedge clk) disable iff (!rst_n) state_out == S_HICCUP);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         EN ONLY WHERE SWITCHING IS ALLOWED. en high means the state is S_SS
         or S_RUN. S_OFF and the S_HICCUP cool-down hold the gate drive low.
         Same edge: en is combinational on the state.

         Covers split by state, so a DUT that only ever enabled in one of the
         two states cannot hide behind a single count.
*/

property p_en_only_in_ss_or_run;

  @(posedge clk) disable iff (!rst_n)
    en |-> ((state_out == S_SS) || (state_out == S_RUN));

endproperty

a_en_only_in_ss_or_run: assert property (p_en_only_in_ss_or_run)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_en_only_in_ss_or_run: en high in state %s",
      state_out.name()));

  end

c_en_in_ss:  cover property (@(posedge clk) disable iff (!rst_n) en && (state_out == S_SS));
c_en_in_run: cover property (@(posedge clk) disable iff (!rst_n) en && (state_out == S_RUN));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         A HARD FAULT HOLDS EN LOW, on the same edge and for as long as the
         fault lasts. A level, not an edge: a DUT that dropped en for one clock
         and re-enabled into a fault still present must fail.

         The covers target the edge that makes this claim matter - a fault
         present while the state is still S_SS or S_RUN, before the FSM has
         registered S_OFF. On that edge only the combinational gate keeps en
         low; in every later edge group 3 would catch it anyway.
*/

property p_hard_fault_holds_en_low;

  @(posedge clk) disable iff (!rst_n)
    hard_fault |-> !en;

endproperty

a_hard_fault_holds_en_low: assert property (p_hard_fault_holds_en_low)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_hard_fault_holds_en_low: en high with a hard fault present in state %s (en_SW=%b spi_enable=%b OTP=%b UVLO=%b latch_state=%b latch_assert=%b)",
      state_out.name(), en_SW, spi_enable, OTP, UVLO, latch_state, latch_assert));

  end

c_fault_before_exit_ss:  cover property (@(posedge clk) disable iff (!rst_n)
  hard_fault && (state_out == S_SS));
c_fault_before_exit_run: cover property (@(posedge clk) disable iff (!rst_n)
  hard_fault && (state_out == S_RUN));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         AVAILABILITY. In S_SS or S_RUN with no hard fault present, en is
         high. Groups 3 and 4 only say when en must be LOW - a DUT with en
         stuck at 0 passes both, perfectly safe and a converter that never
         switches. This is the other half of the bound.
*/

property p_en_high_when_allowed;

  @(posedge clk) disable iff (!rst_n)
    ((state_out == S_SS) || (state_out == S_RUN)) && !hard_fault |-> en;

endproperty

a_en_high_when_allowed: assert property (p_en_high_when_allowed)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_en_high_when_allowed: en low in state %s with no hard fault",
      state_out.name()));

  end

c_allowed_in_ss:  cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_SS)  && !hard_fault);
c_allowed_in_run: cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_RUN) && !hard_fault);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 6:
         A HARD FAULT OUTRANKS EVERYTHING. From S_SS, S_RUN or S_HICCUP, a hard
         fault means S_OFF on the next edge, whatever the sequencing inputs
         say. This is the first row of every non-OFF state's partition; the
         rows in groups 8-10 all carry !hard_fault for that reason.

         |=> because state_out is registered: inputs sampled at edge k appear
         in the state at k+1. The consequent is guarded by out_of_reset, so a
         reset pulse between the two edges - which also lands in S_OFF, but by
         a different path - cannot be mistaken for this transition or fail it.

         Covers: S_SS and S_RUN are c_fault_before_exit_ss / _run in group 4,
         the same expressions. S_HICCUP has its own here. The priority covers
         put a fault on the same edge as each state's sequencing input, so
         the "outranks" part is shown to have been contested, not just met.
*/

property p_hard_fault_to_off;

  @(posedge clk) disable iff (!rst_n)
    (state_out != S_OFF) && hard_fault
      |=> (!out_of_reset || (state_out == S_OFF));

endproperty

a_hard_fault_to_off: assert property (p_hard_fault_to_off)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_hard_fault_to_off: hard fault in state %0d did not lead to S_OFF, got %s (0 OFF, 1 SS, 2 RUN, 3 HICCUP)",
      $past(state_out), state_out.name()));
  end

c_fault_before_exit_hiccup: cover property (@(posedge clk) disable iff (!rst_n)
  hard_fault && (state_out == S_HICCUP));

c_fault_beats_ss_done:     cover property (@(posedge clk) disable iff (!rst_n)
  hard_fault && (state_out == S_SS) && SS_done);
c_fault_beats_trip_ss:     cover property (@(posedge clk) disable iff (!rst_n)
  hard_fault && (state_out == S_SS) && window_trip_SS);
c_fault_beats_trip_run:    cover property (@(posedge clk) disable iff (!rst_n)
  hard_fault && (state_out == S_RUN) && window_trip);
c_fault_beats_hiccup_done: cover property (@(posedge clk) disable iff (!rst_n)
  hard_fault && (state_out == S_HICCUP) && hiccup_done);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 7:
         S_OFF. Two rows, partitioned on hard_fault:
           - a hard fault present: stay in S_OFF. The start-up inhibit - a
             faulted or disabled converter never begins a ramp.
           - no hard fault: go to S_SS. Start-up always ramps; S_OFF never
             goes straight to S_RUN or S_HICCUP.
         The sequencing inputs appear in neither row on purpose: they have no
         say in S_OFF, so the rows hold whatever they are.

         Per-cause inhibit covers are in the directed-scenario section.
*/

property p_off_holds_on_fault;

  @(posedge clk) disable iff (!rst_n)
    (state_out == S_OFF) && hard_fault
      |=> (!out_of_reset || (state_out == S_OFF));

endproperty

a_off_holds_on_fault: assert property (p_off_holds_on_fault)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_off_holds_on_fault: left S_OFF with a hard fault present, got %s",
      state_out.name()));

  end


property p_off_to_ss;

  @(posedge clk) disable iff (!rst_n)
    (state_out == S_OFF) && !hard_fault
      |=> (!out_of_reset || (state_out == S_SS));

endproperty

a_off_to_ss: assert property (p_off_to_ss)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_off_to_ss: S_OFF with no hard fault must go to S_SS, got %s",
      state_out.name()));

  end

c_off_to_ss: cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_OFF) && !hard_fault);
c_off_to_ss_with_stale_ss_done: cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_OFF) && !hard_fault && SS_done);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 8:
         S_SS. With no hard fault (group 6 owns that row), three rows in the
         header's priority order:
           - window_trip_SS:                     to S_HICCUP
           - no window_trip_SS, SS_done:         to S_RUN
           - no window_trip_SS, no SS_done:      stay in S_SS
         The trip outranks SS_done, so a ramp that completes on the same edge
         as an overcurrent still goes to the cool-down.

         window_trip - the S_RUN trip - appears in no row: S_SS must ignore
         it. That needs no property of its own (the hold row already says the
         state stays put whatever window_trip does), but it does need
         c_ss_ignores_trip_run, or a DUT with the two trips cross-wired would
         never be given the chance to fail.
*/

property p_ss_to_hiccup;

  @(posedge clk) disable iff (!rst_n)
    (state_out == S_SS) && !hard_fault && window_trip_SS
      |=> (!out_of_reset || (state_out == S_HICCUP));

endproperty

a_ss_to_hiccup: assert property (p_ss_to_hiccup)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_ss_to_hiccup: window_trip_SS in S_SS must go to S_HICCUP, got %s",
      state_out.name()));

  end


property p_ss_to_run;

  @(posedge clk) disable iff (!rst_n)
    (state_out == S_SS) && !hard_fault && !window_trip_SS && SS_done
      |=> (!out_of_reset || (state_out == S_RUN));

endproperty

a_ss_to_run: assert property (p_ss_to_run)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_ss_to_run: SS_done in S_SS with no trip must go to S_RUN, got %s",
      state_out.name()));

  end


property p_ss_holds;

  @(posedge clk) disable iff (!rst_n)
    (state_out == S_SS) && !hard_fault && !window_trip_SS && !SS_done
      |=> (!out_of_reset || (state_out == S_SS));

endproperty

a_ss_holds: assert property (p_ss_holds)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_ss_holds: S_SS left before SS_done with no trip, got %s",
      state_out.name()));

  end

c_ss_to_hiccup:        cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_SS) && !hard_fault && window_trip_SS);
c_ss_trip_beats_done:  cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_SS) && !hard_fault && window_trip_SS && SS_done);
c_ss_to_run:           cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_SS) && !hard_fault && !window_trip_SS && SS_done);
c_ss_holds:            cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_SS) && !hard_fault && !window_trip_SS && !SS_done);
c_ss_ignores_trip_run: cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_SS) && !hard_fault && !window_trip_SS && !SS_done && window_trip);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 9:
         S_RUN. With no hard fault, two rows:
           - window_trip:     to S_HICCUP
           - no window_trip:  stay in S_RUN
         window_trip_SS must be ignored here, as window_trip is in S_SS;
         c_run_ignores_trip_ss gives a cross-wired DUT the chance to fail.

         window_trip is not a hard fault, so en is not gated by it directly.
         On the edge window_trip is first sampled en is still high; it drops
         one edge later, when S_HICCUP registers. This extra clock is
         intended: window_trip is a judgement over a window of many switching
         cycles, so the overcurrent has already been present for far longer
         than one supervisor clock, and one more adds nothing material. The
         latency is bounded by this group's S_HICCUP row together with group
         3 (no en outside S_SS and S_RUN), so it can never exceed one clock.
*/

property p_run_to_hiccup;

  @(posedge clk) disable iff (!rst_n)
    (state_out == S_RUN) && !hard_fault && window_trip
      |=> (!out_of_reset || (state_out == S_HICCUP));

endproperty

a_run_to_hiccup: assert property (p_run_to_hiccup)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_run_to_hiccup: window_trip in S_RUN must go to S_HICCUP, got %s",
      state_out.name()));

  end


property p_run_holds;

  @(posedge clk) disable iff (!rst_n)
    (state_out == S_RUN) && !hard_fault && !window_trip
      |=> (!out_of_reset || (state_out == S_RUN));

endproperty

a_run_holds: assert property (p_run_holds)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_run_holds: S_RUN left with no fault and no trip, got %s",
      state_out.name()));

  end

c_run_to_hiccup:       cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_RUN) && !hard_fault && window_trip);
c_run_holds:           cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_RUN) && !hard_fault && !window_trip);
c_run_ignores_trip_ss: cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_RUN) && !hard_fault && !window_trip && window_trip_SS);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 10:
         S_HICCUP. With no hard fault, two rows:
           - hiccup_done:     to S_SS
           - no hiccup_done:  stay in S_HICCUP
         The first row is the header's "a retry always re-ramps, never
         re-enables straight into S_RUN". c_retry_with_stale_ss_done is the
         case that tests it: SS_done still high from the previous ramp when
         the cool-down ends. A DUT that consulted SS_done here would jump to
         S_RUN at full duty and fail the row.

         Window trips have no say in S_HICCUP; c_hiccup_ignores_trips gives a
         DUT that re-entered or left on them the chance to fail the hold row.
*/

property p_hiccup_to_ss;

  @(posedge clk) disable iff (!rst_n)
    (state_out == S_HICCUP) && !hard_fault && hiccup_done
      |=> (!out_of_reset || (state_out == S_SS));

endproperty

a_hiccup_to_ss: assert property (p_hiccup_to_ss)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_hiccup_to_ss: hiccup_done must re-ramp through S_SS, got %s",
      state_out.name()));

  end


property p_hiccup_holds;

  @(posedge clk) disable iff (!rst_n)
    (state_out == S_HICCUP) && !hard_fault && !hiccup_done
      |=> (!out_of_reset || (state_out == S_HICCUP));

endproperty

a_hiccup_holds: assert property (p_hiccup_holds)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_hiccup_holds: S_HICCUP left before hiccup_done with no fault, got %s",
      state_out.name()));

  end

c_hiccup_to_ss:             cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_HICCUP) && !hard_fault && hiccup_done);
c_retry_with_stale_ss_done: cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_HICCUP) && !hard_fault && hiccup_done && SS_done);
c_hiccup_holds:             cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_HICCUP) && !hard_fault && !hiccup_done);
c_hiccup_ignores_trips:     cover property (@(posedge clk) disable iff (!rst_n)
  (state_out == S_HICCUP) && !hard_fault && !hiccup_done
    && (window_trip || window_trip_SS));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: Directed-scenario covers. No assertion of their own - groups 6 and 7
         state what must happen - but each is the evidence that the testbench
         drove every hard-fault cause ALONE in every state: 6 causes x 4
         states = 24 covers. "Alone" because fault_cause is compared against a
         one-hot value, so a DUT that ignored one cause cannot pass on the
         edges where another happened to be high too.

         Index i follows fault_cause's bit order: 5 en_SW lost, 4 spi_enable
         lost, 3 OTP, 2 UVLO, 1 latch_state, 0 latch_assert. Reports show the
         covers as g_cause[i].c_<name>.

         c_cause_in_off is the start-up inhibit per cause; the other three are
         the forced exit per cause.
*/

for (genvar i = 0; i < 6; i++) begin : g_cause

  c_cause_in_off:    cover property (@(posedge clk) disable iff (!rst_n)
    (state_out == S_OFF)    && (fault_cause == (6'b1 << i)));
  c_cause_in_ss:     cover property (@(posedge clk) disable iff (!rst_n)
    (state_out == S_SS)     && (fault_cause == (6'b1 << i)));
  c_cause_in_run:    cover property (@(posedge clk) disable iff (!rst_n)
    (state_out == S_RUN)    && (fault_cause == (6'b1 << i)));
  c_cause_in_hiccup: cover property (@(posedge clk) disable iff (!rst_n)
    (state_out == S_HICCUP) && (fault_cause == (6'b1 << i)));

end

/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire