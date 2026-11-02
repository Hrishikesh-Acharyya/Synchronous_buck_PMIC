/*

# Filename:         fault_arbiter_sva.sv

# File Description: Bound checker for fault_arbiter, the rolling-window
#                   overcurrent detector. Holds the claims that are true at an
#                   edge without knowing the window's contents: reset, the
#                   trip decode, the count bounds, how and when each count may
#                   move, the clear, and that each trip stays within its own
#                   state. The count's exact value - the faulted samples in
#                   the trailing window - needs the window itself and is the
#                   testbench's reference model, not a property here.
#
#                   The checker reads fault_count_run_out / fault_count_ss_out
#                   as the counts: they are the only view of them a port
#                   offers. cp_sync is deliberately not a port - nothing here
#                   needs the comparator; only the model does.

# Global variables: None

*/

`default_nettype none

module fault_arbiter_sva
#(
    parameter int WINDOW_RUN = pmic_types_pkg::WINDOW_RUN,
    parameter int WINDOW_SS = pmic_types_pkg::WINDOW_SS
)(
    input  wire logic                              clk,
    input  wire logic                              rst_n,
    input  wire logic                              pwm_sync,
    input  wire logic                              cp_sync,
    input  wire logic                              ss_active,
    input  wire logic                              run_active,
    input  wire logic [pmic_types_pkg::TRIP_W-1:0] trip_run,
    input  wire logic [pmic_types_pkg::TRIP_W-1:0] trip_ss,
    input  wire logic                              window_trip,  // DUT output
    input  wire logic                              window_trip_SS,  // DUT output
    input  wire logic [$clog2(WINDOW_RUN+1)-1:0]   fault_count_run_out,  // DUT output
    input  wire logic [$clog2(WINDOW_SS+1)-1:0]    fault_count_ss_out  // DUT output

);

// out_of_reset: low from an asynchronous reset until the first clock edge
//               with rst_n high. Read entering edge k, high means no reset
//               has been seen since edge k-1, so it gates every claim that
//               reaches one edge forward - disable iff sees only the edge
//               being evaluated.
logic out_of_reset;

always_ff @(posedge clk or negedge rst_n) begin
/*
Purpose:
---
The checker's own reset tracker. Cleared asynchronously, so a reset pulse that
falls entirely between two edges still disarms the two-edge claims at the
second of them. rst_n sampled at either edge would miss it.
*/
  if (!rst_n) out_of_reset <= 1'b0;
  else        out_of_reset <= 1'b1;
end

// pwm_sync_q: pwm_sync as sampled one edge earlier - the checker's own copy,
//             so the sample event below is computed here, not read from the
//             DUT
logic pwm_sync_q;
// run_sample / ss_sample: high on an edge where the DUT takes a sample into
//                         that state's window - the rising edge of pwm_sync
//                         with the state active. Read entering edge k, they
//                         say the count may change between edge k and k+1.
logic run_sample;
logic ss_sample;
// run_sample_q / ss_sample_q: the sample events one edge later - high on the
//                             edge where a sample's effect on the count first
//                             shows, so a cover can see sample and result on
//                             one edge without a ## sequence
logic run_sample_q;
logic ss_sample_q;

always_ff @(posedge clk or negedge rst_n) begin
/*
Purpose:
---
Delay pwm_sync by one edge. Sampled at edge k, pwm_sync_q holds pwm_sync as
sampled at edge k-1, so pwm_sync && !pwm_sync_q at edge k is the same rising
edge the DUT's sample pulse sees at edge k. The sample events are delayed the
same way, for the covers of groups 5 and 6.
*/
  if (!rst_n) begin
    pwm_sync_q   <= 1'b0;
    run_sample_q <= 1'b0;
    ss_sample_q  <= 1'b0;
  end
  else begin
    pwm_sync_q   <= pwm_sync;
    run_sample_q <= run_sample;
    ss_sample_q  <= ss_sample;
  end
end

always_comb begin
/*
Purpose:
---
The sample event, one per switching cycle, split by the window it feeds. The
header defines it - a sample at the rising edge of pwm_sync, into the window
of the state that is active - so this matches the DUT by necessity; the
independence lies in what groups 5 and 6 then claim about the counts.
*/
  run_sample = pwm_sync && !pwm_sync_q && run_active;
  ss_sample  = pwm_sync && !pwm_sync_q && ss_active;
end

/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         INPUT CONTRACTS - promises fault_arbiter relies on but does not
         make. A failure here is a fault in the named owner or in the
         testbench driving these inputs, not in fault_arbiter.

         ss_active and run_active are never high together: owned by the
         supervisor, whose state decode is one-hot. fault_arbiter's window
         logic gives run_active priority silently if both are high, so this
         is the only place the violation would show.

         trip_run is within [1, WINDOW_RUN] and trip_ss within [1, WINDOW_SS]:
         owned by reg_file, whose clamp saturates every host write into that
         range. Below 1 a trip would sit high with an empty window; above the
         window size it could never assert at all.
*/

property p_active_signals_mutually_exclusive;

  @(posedge clk) disable iff (!rst_n)
     !(run_active && ss_active);

endproperty

a_active_signals_mutually_exclusive: assert property (p_active_signals_mutually_exclusive)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_active_signals_mutually_exclusive: run_active %b and ss_active %b. Both should not be high together.",
      run_active, ss_active));

  end

c_run_active_and_not_ss_active: cover property (@(posedge clk) disable iff (!rst_n)
    run_active && !ss_active);
c_ss_active_and_not_run_active: cover property (@(posedge clk) disable iff (!rst_n)
    ss_active && !run_active);

property p_trip_signals_within_bounds;

  @(posedge clk) disable iff (!rst_n)
    ((int'(trip_run) <= WINDOW_RUN) && int'(trip_run) >= 1)
     && ((int'(trip_ss) <= WINDOW_SS) && int'(trip_ss) >= 1);

endproperty

a_trip_signals_within_bounds: assert property (p_trip_signals_within_bounds)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_trip_signals_within_bounds: trip_run %0d or trip_ss %0d out of bounds. trip_run must be in [1, %0d], trip_ss must be in [1, %0d]",
      trip_run, trip_ss, WINDOW_RUN, WINDOW_SS));

  end

c_trip_run_at_min: cover property (@(posedge clk) disable iff (!rst_n)
    int'(trip_run) == 1);
c_trip_run_at_max: cover property (@(posedge clk) disable iff (!rst_n)
    int'(trip_run) == WINDOW_RUN);
c_trip_ss_at_min:  cover property (@(posedge clk) disable iff (!rst_n)
    int'(trip_ss) == 1);
c_trip_ss_at_max:  cover property (@(posedge clk) disable iff (!rst_n)
    int'(trip_ss) == WINDOW_SS);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         RESET CLEARS BOTH WINDOWS. While rst_n is low both counts are 0 and
         both trips are low. The trips being low follows from the counts being 0 only
         because both thresholds are at least 1 - group 1's reg_file contract -
         so a failure here with a threshold of 0 points there, not at this
         module.
*/

property p_reset_clears;

  @(posedge clk)
    (!rst_n) |-> (fault_count_run_out == '0) && (fault_count_ss_out == '0)
                 && !window_trip && !window_trip_SS;

endproperty

a_reset_clears: assert property (p_reset_clears)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_reset_clears: under reset expected both counts 0 and both trips low, got run=%0d ss=%0d window_trip=%b window_trip_SS=%b",
      fault_count_run_out, fault_count_ss_out, window_trip, window_trip_SS));

  end

c_reset_clears: cover property (@(posedge clk) (!rst_n));

/*
////////////////////////////////////////////////////////////////////////////////
*/


/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         TRIP DECODE. Each trip is high exactly when its count has reached its
         threshold. Equalities, so a trip stuck high fails as surely as one stuck low.
         Plain Booleans, same edge: the comparison is combinational. Compared
         at int width, so the count and threshold widths cannot truncate
         either side.

         Covers split each trip high and low, so both directions of the
         equality are shown to have been evaluated; and each at the exact
         threshold, the fencepost the "reaches" decision turns on.
*/

property p_window_trip_decode;

  @(posedge clk) disable iff (!rst_n)
    window_trip == (int'(fault_count_run_out) >= int'(trip_run));

endproperty

a_window_trip_decode: assert property (p_window_trip_decode)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_window_trip_decode: window_trip = %b with run count %0d against trip_run %0d",
      window_trip, fault_count_run_out, trip_run));

  end


property p_window_trip_ss_decode;

  @(posedge clk) disable iff (!rst_n)
    window_trip_SS == (int'(fault_count_ss_out) >= int'(trip_ss));

endproperty

a_window_trip_ss_decode: assert property (p_window_trip_ss_decode)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_window_trip_ss_decode: window_trip_SS = %b with soft-start count %0d against trip_ss %0d",
      window_trip_SS, fault_count_ss_out, trip_ss));

  end

c_window_trip_high:      cover property (@(posedge clk) disable iff (!rst_n) window_trip);
c_window_trip_at_thr:    cover property (@(posedge clk) disable iff (!rst_n)
  int'(fault_count_run_out) == int'(trip_run));
c_window_trip_ss_high:   cover property (@(posedge clk) disable iff (!rst_n) window_trip_SS);
c_window_trip_ss_at_thr: cover property (@(posedge clk) disable iff (!rst_n)
  int'(fault_count_ss_out) == int'(trip_ss));

/*
////////////////////////////////////////////////////////////////////////////////
*/
/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         Neither count exceeds its window size - a window of N
         samples cannot hold more than N faulted ones. Catches an incremental
         count that adds the entering sample without removing the leaving
         one. Plain Booleans. The covers show each count reaching its full
         window, the edge of the bound.
*/

property p_run_count_bounded;

  @(posedge clk) disable iff (!rst_n)
    int'(fault_count_run_out) <= WINDOW_RUN;

endproperty

a_run_count_bounded: assert property (p_run_count_bounded)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_run_count_bounded: run count %0d exceeds WINDOW_RUN %0d",
      fault_count_run_out, WINDOW_RUN));

  end


property p_ss_count_bounded;

  @(posedge clk) disable iff (!rst_n)
    int'(fault_count_ss_out) <= WINDOW_SS;

endproperty

a_ss_count_bounded: assert property (p_ss_count_bounded)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_ss_count_bounded: soft-start count %0d exceeds WINDOW_SS %0d",
      fault_count_ss_out, WINDOW_SS));

  end

c_run_count_full: cover property (@(posedge clk) disable iff (!rst_n)
  int'(fault_count_run_out) == WINDOW_RUN);
c_ss_count_full:  cover property (@(posedge clk) disable iff (!rst_n)
  int'(fault_count_ss_out) == WINDOW_SS);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         HOW THE RUN COUNT MOVES. The run count can change by exactly three
         paths: a sample taken in S_RUN, the clear (neither state active),
         and reset. Reset is disable iff plus out_of_reset; the clear is
         group 7's claim, so its edges are excused here. That leaves two
         properties:
           - no sample and no clear on edge k: the count is unchanged at k+1.
             This also pins the run window frozen through S_SS.
           - a sample on edge k: the count at k+1 differs from k by at most
             one - plus the entering faulted bit, minus the leaving one. The
             exact value needs the window and is the testbench model's claim;
             the checker only bounds it.
         Edge timing: run_sample at edge k is the DUT's sample pulse at edge
         k; the count it updates is registered, so the change is visible at
         k+1 - hence |=>, and the out_of_reset guard.

         Covers: the count going up and going down on a sample. A sample that
         leaves the count unchanged is either nothing in and nothing out, or
         a faulted bit in and a faulted bit out; the checker cannot tell them
         apart, so that case is the model's to cover.
*/

property p_run_count_holds;

  @(posedge clk) disable iff (!rst_n)
    !run_sample && (run_active || ss_active)
      |=> (!out_of_reset || $stable(fault_count_run_out));

endproperty

a_run_count_holds: assert property (p_run_count_holds)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_run_count_holds: run count moved %0d -> %0d with no S_RUN sample and no clear",
      $past(fault_count_run_out), fault_count_run_out));

  end


property p_run_count_step;

  @(posedge clk) disable iff (!rst_n)
    run_sample
      |=> (!out_of_reset
           || ((int'(fault_count_run_out) - int'($past(fault_count_run_out)) <= 1)
            && (int'(fault_count_run_out) - int'($past(fault_count_run_out)) >= -1)));

endproperty

a_run_count_step: assert property (p_run_count_step)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_run_count_step: one S_RUN sample moved the run count %0d -> %0d, more than one step",
      $past(fault_count_run_out), fault_count_run_out));

  end

c_run_count_up:   cover property (@(posedge clk) disable iff (!rst_n)
  run_sample_q && (fault_count_run_out > $past(fault_count_run_out)));
c_run_count_down: cover property (@(posedge clk) disable iff (!rst_n)
  run_sample_q && (fault_count_run_out < $past(fault_count_run_out)));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 6:
         HOW THE SOFT-START COUNT MOVES. Group 5 for the soft-start window:
         three paths - a sample in S_SS, the clear, reset - so the same two
         properties. The hold property also pins the soft-start window frozen
         through S_RUN, which is what lets a count left at trip_ss on the
         S_SS -> S_RUN edge stand for the whole of S_RUN (group 8).
*/

property p_ss_count_holds;

  @(posedge clk) disable iff (!rst_n)
    !ss_sample && (run_active || ss_active)
      |=> (!out_of_reset || $stable(fault_count_ss_out));

endproperty

a_ss_count_holds: assert property (p_ss_count_holds)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_ss_count_holds: soft-start count moved %0d -> %0d with no S_SS sample and no clear",
      $past(fault_count_ss_out), fault_count_ss_out));

  end


property p_ss_count_step;

  @(posedge clk) disable iff (!rst_n)
    ss_sample
      |=> (!out_of_reset
           || ((int'(fault_count_ss_out) - int'($past(fault_count_ss_out)) <= 1)
            && (int'(fault_count_ss_out) - int'($past(fault_count_ss_out)) >= -1)));

endproperty

a_ss_count_step: assert property (p_ss_count_step)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_ss_count_step: one S_SS sample moved the soft-start count %0d -> %0d, more than one step",
      $past(fault_count_ss_out), fault_count_ss_out));

  end

c_ss_count_up:   cover property (@(posedge clk) disable iff (!rst_n)
  ss_sample_q && (fault_count_ss_out > $past(fault_count_ss_out)));
c_ss_count_down: cover property (@(posedge clk) disable iff (!rst_n)
  ss_sample_q && (fault_count_ss_out < $past(fault_count_ss_out)));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 7:
         THE CLEAR. With neither state active, both counts are 0 on the next
         edge - a hiccup retry starts on a clean window, not on the history
         that caused the trip. |=> because the clear is registered; the
         consequent is guarded by out_of_reset, which also lands both counts
         at 0 but by a different path.

         The covers are the edges where the clear has work to do: inactive
         with a count still non-zero, i.e. the first edge after leaving each
         state with faults in its window. An inactive edge with both counts
         already 0 satisfies the property without testing it.
*/

property p_inactive_clears;

  @(posedge clk) disable iff (!rst_n)
    !run_active && !ss_active
      |=> (!out_of_reset || ((fault_count_run_out == '0) && (fault_count_ss_out == '0)));

endproperty

a_inactive_clears: assert property (p_inactive_clears)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_inactive_clears: neither state active, yet run count %0d / soft-start count %0d not cleared",
      fault_count_run_out, fault_count_ss_out));

  end

c_clear_run_nonzero: cover property (@(posedge clk) disable iff (!rst_n)
  !run_active && !ss_active && (fault_count_run_out != '0));
c_clear_ss_nonzero:  cover property (@(posedge clk) disable iff (!rst_n)
  !run_active && !ss_active && (fault_count_ss_out != '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 8:
         EACH TRIP STAYS IN ITS OWN STATE. window_trip_SS may be high outside
         S_SS only on the first edge after leaving it, and window_trip outside
         S_RUN only on the first edge after leaving that - the one edge the
         registered clear takes to land. Beyond that, a trip outside its state
         is a phantom: fault_cause logs an overcurrent on either trip whenever
         the converter is running, in S_SS or S_RUN, so a soft-start trip
         left standing in S_RUN would be recorded with no overcurrent behind
         it.

         The S_SS -> S_RUN transition does not clear, so if a faulted sample
         lands on the very edge the FSM leaves S_SS, the soft-start count
         freezes at or above trip_ss for the whole of S_RUN. This group is
         written to catch that; c_ss_count_at_trip_in_run below is the
         scenario that provokes it.

         Same edge with a one-edge reach back, so $past is used and the
         consequent is guarded by out_of_reset. The covers are the excused
         edge in each direction - the claim's only allowance, shown to occur.
*/

property p_trip_ss_confined;

  @(posedge clk) disable iff (!rst_n)
    window_trip_SS && !ss_active |-> (!out_of_reset || $past(ss_active));

endproperty

a_trip_ss_confined: assert property (p_trip_ss_confined)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_trip_ss_confined: window_trip_SS high outside S_SS for more than one edge (ss count %0d, trip_ss %0d, run_active %b)",
      fault_count_ss_out, trip_ss, run_active));

  end


property p_trip_run_confined;

  @(posedge clk) disable iff (!rst_n)
    window_trip && !run_active |-> (!out_of_reset || $past(run_active));

endproperty

a_trip_run_confined: assert property (p_trip_run_confined)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_trip_run_confined: window_trip high outside S_RUN for more than one edge (run count %0d, trip_run %0d, ss_active %b)",
      fault_count_run_out, trip_run, ss_active));

  end

c_trip_ss_clear_edge:  cover property (@(posedge clk) disable iff (!rst_n)
  window_trip_SS && !ss_active);
c_trip_run_clear_edge: cover property (@(posedge clk) disable iff (!rst_n)
  window_trip && !run_active);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: Directed-scenario covers. 
         c_ss_count_at_trip_in_run: the soft-start count at or above trip_ss
         while in S_RUN - the frozen-count case group 8 exists to catch.
         c_run_trip_at_window: a full window at the largest legal threshold,
         the "reaches, not exceeds" fencepost at its extreme.
*/

c_ss_count_at_trip_in_run: cover property (@(posedge clk) disable iff (!rst_n)
  run_active && (int'(fault_count_ss_out) >= int'(trip_ss)));
c_run_trip_at_window:      cover property (@(posedge clk) disable iff (!rst_n)
  window_trip && (int'(trip_run) == WINDOW_RUN));

/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire

