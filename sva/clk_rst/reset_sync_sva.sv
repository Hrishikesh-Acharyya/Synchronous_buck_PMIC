/*

# Filename:         reset_sync_sva.sv

# File Description: Concurrent assertion checker for reset_sync. Attached with
#                   bind so the RTL source carries no assertion constructs and
#                   the sv2v / Yosys ASIC path never sees them.
#
#                   The contract, from the module header: reset asserts
#                   asynchronously the instant rst_n_enter falls, and releases
#                   synchronously two clocks after rst_n_enter rises.
#
#
#                   Every claim measures time from a release the checker
#                   tracks itself, in edges_since_release, rather than from the
#                   DUT's meta_ff. meta_ff is an implementation detail the
#                   header never promises, and a fencepost bug in the DUT's
#                   chain must not appear identically in the reference and
#                   cancel out.
#
#                   Reset IS the subject here, so no property carries a
#                   disable iff. rst_n_enter is the DUT's input, not a
#                   reset of the checker's claims.
#
#                   No parameters: the module has none, so there are no
#                   N-1 / N / N+1 boundaries to pass through.

# Global variables: None

*/

`default_nettype none

module reset_sync_sva (
    input  wire logic clk,
    input  wire logic rst_n_enter,
    input  wire logic rst_n_exit
);

// edges_since_release: rising clk edges since rst_n_enter last rose, saturating
//                      at 3. Counts INTERVALS - it starts at zero - so entering
//                      edge k it reads the number of edges strictly before k
//                      since release. Cleared asynchronously, so a low pulse
//                      that falls entirely between two edges still restarts
//                      it, which sampling rst_n_enter at the edges alone would
//                      miss.
logic [1:0] edges_since_release;

always_ff @(posedge clk or negedge rst_n_enter) begin
  /*
  Purpose:
  ---
  The checker's own measure of time since release, independent of the DUT's
  two-flop chain. Saturates at 3 rather than 2 so "the release edge" (2) and
  "held after release" (3) can be covered separately. Compared against the
  value explicitly rather than with &edges_since_release, so the saturation
  point is stated, not implied by the width.
  */
  if (!rst_n_enter) begin

    edges_since_release <= 2'd0;

  end

  else if (edges_since_release != 2'd3) begin

    edges_since_release <= edges_since_release + 2'd1;

  end
  // else: saturated - hold

end


/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         While rst_n_enter is low, rst_n_exit is low at every edge. Carries no
         disable iff - reset is the condition under test, and disabling on it
         would silence the property exactly when it has something to say.

         Not subsumed by group 2: group 2's antecedent requires rst_n_enter
         high, so an output that stayed high through a held reset would pass
         it.
*/

property p_exit_low_in_reset;

  @(posedge clk)
    !rst_n_enter |-> !rst_n_exit;

endproperty

a_exit_low_in_reset: assert property (p_exit_low_in_reset)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_exit_low_in_reset: rst_n_exit=%b while rst_n_enter is low", rst_n_exit));

  end

c_reset_held: cover property (@(posedge clk) !rst_n_enter);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         LOWER BOUND. After rst_n_enter rises, rst_n_exit is still low at the
         first two edges. A one-flop synchroniser, or one that released
         combinationally, fails here.

         Value at the selected edges, so |->. Two covers because the
         antecedent spans two distinct edges; one count would hide a stimulus
         that never held the release long enough to reach the second.
*/

property p_no_early_release;

  @(posedge clk)
    (rst_n_enter && (edges_since_release < 2'd2)) |-> !rst_n_exit;

endproperty

a_no_early_release: assert property (p_no_early_release)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_no_early_release: rst_n_exit high only %0d edge(s) after release",
      edges_since_release));

  end

c_first_edge_after_release:  cover property (@(posedge clk)
                                 rst_n_enter && (edges_since_release == 2'd0));

c_second_edge_after_release: cover property (@(posedge clk)
                                 rst_n_enter && (edges_since_release == 2'd1));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         UPPER BOUND. From the second edge after release onward, rst_n_exit is
         high - it is owed at that edge, and it stays there while rst_n_enter
         does. A three-flop chain, or an output stuck low, fails here.

         rst_n_enter does not appear in the antecedent: edges_since_release
         is cleared asynchronously, so a value of 2 or more already implies
         rst_n_enter has been high continuously since the release it counts.

         Split covers: the release edge itself, and holding afterwards.
*/

property p_release_on_time;

  @(posedge clk)
    (edges_since_release >= 2'd2) |-> rst_n_exit;

endproperty

a_release_on_time: assert property (p_release_on_time)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_release_on_time: rst_n_exit still low %0d edges after release",
      edges_since_release));

  end

c_release_edge: cover property (@(posedge clk) (edges_since_release == 2'd2));
c_release_held: cover property (@(posedge clk) (edges_since_release == 2'd3));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: Directed-scenario covers. Neither has an assertion of its own - the
         properties above already state what must hold - but each is the
         evidence that the testbench actually built the case.

         c_release_pulse_too_short: rst_n_enter high across exactly one edge,
         then low again. The degenerate input: shorter than the synchroniser,
         so rst_n_exit must never rise. Group 2 is what checks it.

         c_narrow_glitch: a low pulse that fell entirely between two edges
         while released. Visible only because edges_since_release clears
         asynchronously - rst_n_enter samples high at two consecutive edges
         yet the count has restarted, so it went low in between. Group 2 then requires the output to have
         dropped, and group 3 requires it back two edges later.

         Both written with $past rather than ##1 - same meaning for a
         two-edge window, and the form Verilator supports across versions.
*/

c_release_pulse_too_short: cover property (@(posedge clk)
    !rst_n_enter && $past(rst_n_enter && (edges_since_release == 2'd0)));

c_narrow_glitch: cover property (@(posedge clk)
    rst_n_enter && $past(rst_n_enter) && (edges_since_release == 2'd0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire

