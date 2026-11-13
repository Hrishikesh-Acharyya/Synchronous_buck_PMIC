/*

# Filename:         hiccup_timer_sva.sv

# File Description: Concurrent assertion checker for hiccup_timer. Attached
#                   with bind so the RTL source carries no assertion
#                   constructs and the sv2v / Yosys ASIC path never sees them.
#                   STRIKE_W and TIMER_W are passed through from the bound
#                   instance, so the claims track the DUT's own widths.
#
#                   hiccup_done is what releases the supervisor from S_HICCUP
#                   back into a soft start, so these are protection claims: a
#                   cool-down must never end early - the fault gets its full,
#                   escalating time to clear - and must end, or the converter
#                   never retries.
#
#                   Contract, from the module header and its comments:
#                     1 (I) hiccup_done is low in reset
#                     2 (I) outside S_HICCUP hiccup_done is cleared - a stale
#                           flag would skip every cool-down after the first
#                     3 (E) hiccup_done rises only once base_clks <<
#                           strike_level clocks have elapsed in this cool-down
#                     4 (E) and does rise once they have
#                     5 (I) it stays high for the rest of S_HICCUP
#                     6 (E) the interval doubles per strike - claims 3 and 4
#                           at each strike level, one cover per level
#
#                   The fixed offset every timing claim is written against:
#                   the cool-down counter reaches the target after target
#                   clocks in S_HICCUP, and hiccup_done is registered, so it
#                   appears target + 1 clocks after hiccup_active. The hold-off
#                   is therefore at least the commanded interval, one clock
#                   longer - not an error, and not something to "fix" in the
#                   claims.
#
#                   The checker computes the interval itself, at 32 bits, from
#                   base_clks and strike_level, and counts the clocks with its
#                   own counter - never the DUT's cool_down_target or
#                   cool_counter - so a shift or fencepost bug in the DUT
#                   cannot appear identically in the reference.

# Global variables: None

*/

`default_nettype none

module hiccup_timer_sva
#(
    // STRIKE_W: width of the strike level input
    parameter int STRIKE_W = pmic_types_pkg::STRIKE_W,
    // TIMER_W: width of the DUT's cool-down counter; the longest interval
    //          it can hold is 2**TIMER_W - 1
    parameter int TIMER_W  = pmic_types_pkg::HICCUP_TIMER_W
)(
    input  wire logic                                     clk,
    input  wire logic                                     rst_n,
    input  wire logic                                     hiccup_active,
    input  wire logic [STRIKE_W-1:0]                      strike_level,
    input  wire logic [pmic_types_pkg::HICCUP_BASE_W-1:0] base_clks,
    input  wire logic                                     hiccup_done
);

// out_of_reset: low from an asynchronous reset until the first clock edge with
//               rst_n high. Entering edge k it reads 1 only if no reset was
//               seen since edge k-1, so it gates every claim that reaches one
//               edge back - disable iff sees only the edge being evaluated.
logic out_of_reset;
// clocks_in_hiccup: clock edges already seen in S_HICCUP this cool-down.
//                   Counts INTERVALS: entering the first edge that samples
//                   hiccup_active high it reads 0, so entering edge k it reads
//                   the clocks elapsed before k. Saturates at its top value
//                   rather than wrapping.
logic [31:0] clocks_in_hiccup;
// interval_clks: the cool-down the header promises for the present strike
//                level, base_clks doubled strike_level times, at 32 bits so a
//                result too wide for the DUT's counter is visible rather than
//                silently truncated
logic [31:0] interval_clks;

always_ff @(posedge clk or negedge rst_n) begin

  /*
  Purpose:
  ---
  The checker's own measure of time in S_HICCUP. The restart is the header's
  by necessity - a cool-down starts when S_HICCUP is entered - but the count
  and its saturation are the checker's. out_of_reset is cleared
  asynchronously, so a reset pulse between two edges still disarms the
  two-edge claims at the second of them.
  */

  if (!rst_n) begin

    out_of_reset     <= 1'b0;
    clocks_in_hiccup <= '0;

  end

  else begin

    out_of_reset <= 1'b1;

    if (!hiccup_active) begin

      clocks_in_hiccup <= '0;

    end

    else if (clocks_in_hiccup != 32'hFFFF_FFFF) begin

      clocks_in_hiccup <= clocks_in_hiccup + 32'd1;

    end
    // else: saturated - hold

  end

end

always_comb begin

  /*
  Purpose:
  ---
  The promised interval, recomputed from the inputs rather than read from
  the DUT.
  */

  interval_clks = 32'(base_clks) << strike_level;

end


/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         RESET. hiccup_done is low at every edge while rst_n is low. Carries
         no disable iff - reset is the condition under test, and disabling on
         it would silence the property exactly when it has something to say.
*/

property p_reset_done_low;

  @(posedge clk)
    !rst_n |-> !hiccup_done;

endproperty

a_reset_done_low: assert property (p_reset_done_low)
  else begin

    sva_pkg::note_failure("a_reset_done_low: hiccup_done high in reset");

  end

c_reset_done_low: cover property (@(posedge clk) !rst_n);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         CLEARED OUTSIDE S_HICCUP. Any edge that samples hiccup_active low
         leaves hiccup_done low after it. Without this the flag would stay
         high into S_SS and S_RUN, and the next entry into S_HICCUP would
         exit at once on the stale value - skipping every cool-down after the
         first, which is exactly the case the escalating interval exists for.
         hiccup_done is registered, so the change shows one edge later: |=>.
*/

property p_done_cleared_outside;

  @(posedge clk) disable iff (!rst_n)
    !hiccup_active |=> (out_of_reset -> !hiccup_done);

endproperty

a_done_cleared_outside: assert property (p_done_cleared_outside)
  else begin

    sva_pkg::note_failure("a_done_cleared_outside: hiccup_done still high after leaving S_HICCUP");

  end

c_done_cleared_outside: cover property (@(posedge clk) disable iff (!rst_n)
    !hiccup_active && hiccup_done);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         NEVER EARLY. hiccup_done rises only off an edge in S_HICCUP at which
         exactly the promised interval had elapsed - base_clks doubled once
         per strike - so the fault always gets its full cool-down. Exact
         rather than "at least", so a DUT that finishes late but before the
         next retry would still be caught by group 4, and one that finishes
         early is caught here. A shift by the wrong amount, a counter that
         starts at one, or a target read before the strike landed all fail
         here.

         One cover per strike level, so the escalation itself is shown to
         run, not just the first interval.
*/

property p_done_not_early;

  @(posedge clk) disable iff (!rst_n)
    (out_of_reset && $rose(hiccup_done)) |->
      $past(hiccup_active) && ($past(clocks_in_hiccup) == $past(interval_clks));

endproperty

a_done_not_early: assert property (p_done_not_early)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_done_not_early: hiccup_done rose after %0d clocks of a %0d-clock cool-down (hiccup_active = %b)",
      $past(clocks_in_hiccup), $past(interval_clks), $past(hiccup_active)));

  end

c_done_rises_level0: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $rose(hiccup_done) && (strike_level == 0));
c_done_rises_level1: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $rose(hiccup_done) && (strike_level == 1));
c_done_rises_level2: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $rose(hiccup_done) && (strike_level == 2));
c_done_rises_level3: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && $rose(hiccup_done) && (strike_level == 3));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         NEVER LATE. An edge in S_HICCUP at which the promised interval has
         elapsed raises hiccup_done after it. Group 3 is the lower bound and
         this the upper; either alone passes a DUT that never finishes, or one
         that finishes on entry. Together they pin the release to the one
         clock the fixed offset predicts.
*/

property p_done_on_time;

  @(posedge clk) disable iff (!rst_n)
    (hiccup_active && (clocks_in_hiccup == interval_clks)) |=>
      (out_of_reset -> hiccup_done);

endproperty

a_done_on_time: assert property (p_done_on_time)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_done_on_time: %0d-clock cool-down elapsed, hiccup_done still low",
      $past(interval_clks)));

  end

c_done_on_time: cover property (@(posedge clk) disable iff (!rst_n)
    hiccup_active && (clocks_in_hiccup == interval_clks));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         HELD FOR THE REST OF S_HICCUP. Once high, hiccup_done stays high at
         every edge that still samples hiccup_active - the counter is held at
         the target, not re-armed - until the supervisor leaves. A DUT that
         pulsed it for one clock, or re-armed and counted again while the
         supervisor was slow to act, fails here.

         Considered and subsumed: "hiccup_done falls only on leaving
         S_HICCUP" is this property's contrapositive - a fall in S_HICCUP
         means an edge with both high followed by done low.
*/

property p_done_held;

  @(posedge clk) disable iff (!rst_n)
    (hiccup_active && hiccup_done) |=> (out_of_reset -> hiccup_done);

endproperty

a_done_held: assert property (p_done_held)
  else begin

    sva_pkg::note_failure("a_done_held: hiccup_done fell while still in S_HICCUP");

  end

c_done_held: cover property (@(posedge clk) disable iff (!rst_n)
    hiccup_active && hiccup_done && $past(hiccup_active && hiccup_done));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: INPUT CONTRACTS. Not claims about hiccup_timer - promises its
         neighbours make, written as assertions so a violation points at the
         module that broke it rather than at a confusing failure above.
           - reg_file: base_clks is written only in S_OFF (off_ok) and is
             clamped to at least one millisecond of clocks - never zero, and
             stable for the whole of a cool-down.
           - strike_counter: strike_level changes during S_HICCUP only on the
             clock after entry, when the strike for this hiccup lands; the
             header relies on the target only ever growing from there.
           - reg_file / pmic_types_pkg: the interval fits the DUT's counter.
             TIMER_W is sized for the longest base at strike level
             MAX_STRIKES-1. known_issues A2 used to break this - a wrapped
             strike count let a whole cool-down run at level 3, where base << 3
             truncates once base exceeds about 10.5 ms of clocks - and the
             contract stays as the guard against its return.
         No covers: the antecedents are shared with groups 2 to 5.
*/

property p_contract_base_legal;

  @(posedge clk) disable iff (!rst_n)
    (base_clks != '0)
      && ((out_of_reset && hiccup_active && $past(hiccup_active)) -> $stable(base_clks));

endproperty

a_contract_base_legal: assert property (p_contract_base_legal)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_contract_base_legal: reg_file delivered base_clks = %0d (was %0d) during a cool-down",
      base_clks, $past(base_clks)));

  end

property p_contract_strike_settles;

  @(posedge clk) disable iff (!rst_n)
    (out_of_reset && hiccup_active && $changed(strike_level)) |->
      (clocks_in_hiccup == 32'd1);

endproperty

a_contract_strike_settles: assert property (p_contract_strike_settles)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_contract_strike_settles: strike_counter changed strike_level %0d -> %0d %0d clocks into S_HICCUP",
      $past(strike_level), strike_level, clocks_in_hiccup));

  end

property p_contract_interval_fits;

  @(posedge clk) disable iff (!rst_n)
    hiccup_active |-> (interval_clks < (32'd1 << TIMER_W));

endproperty

a_contract_interval_fits: assert property (p_contract_interval_fits)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_contract_interval_fits: interval %0d clocks (base %0d, strike %0d) does not fit a %0d-bit counter",
      interval_clks, base_clks, strike_level, TIMER_W));

  end

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: Directed-scenario covers. No assertion of their own - the groups
         above state what must hold - but each is the evidence that the
         testbench actually built the case.

         c_quick_reentry:     S_HICCUP re-entered one clock after leaving -
                              where a stale hiccup_done would skip the
                              cool-down.
         c_left_before_done:  S_HICCUP left mid cool-down, as a fault forcing
                              S_OFF does; the next entry must count from zero.
         c_reset_mid_cooldown: reset during a cool-down.
         c_one_clock_hiccup:  hiccup_active high for a single clock.
         c_interval_at_top:   an interval of 2**TIMER_W - 1, the most the
                              DUT's counter can hold, where a counter that
                              stepped past the target would wrap.
*/

c_quick_reentry: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && hiccup_active && $past(!hiccup_active) && $past(hiccup_active, 2));

c_left_before_done: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && !hiccup_active && $past(hiccup_active && !hiccup_done));

c_reset_mid_cooldown: cover property (@(posedge clk) !rst_n && hiccup_active);

c_one_clock_hiccup: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && !hiccup_active && $past(hiccup_active) && !$past(hiccup_active, 2));

c_interval_at_top: cover property (@(posedge clk) disable iff (!rst_n)
    hiccup_active && (interval_clks == (32'd1 << TIMER_W) - 32'd1));

/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire
