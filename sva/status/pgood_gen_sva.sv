/*

# Filename:         pgood_gen_sva.sv

# File Description: Concurrent assertion checker for pgood_gen. Attached with
#                   bind so the RTL source carries no assertion constructs and
#                   the sv2v / Yosys ASIC path never sees them.
#                   PGOOD_DELAY_W is passed through from the bound instance so
#                   the saturation comparisons match the call site's width.
#
#                   PGOOD drives
#                   the changeover that moves the secondary analog circuitry
#                   off the input LDO and onto the converter's own output, so
#                   the load must be handed back before the rail collapses,
#                   not a clock after.
#
#                   The asymmetry is the whole point of the module: assertion
#                   is slow, gated on a full qualifying count, while
#                   deassertion is immediate.
#
#                   qualify_counter advances on the switching-cycle boundary,
#                   not on every clock - a counter that advanced per clock
#                   would give a delay roughly two orders of magnitude short
#                   and no other property would notice.

# Global variables: None

*/

`default_nettype none

module pgood_gen_sva #(
    // QUAL_CYCLES: switching cycles the rail must be continuously good before
    //              PGOOD asserts. The DUT compares qualify_counter against this
    //              directly, so the realised delay is the millisecond figure the
    //              parameter was derived from.
    parameter int QUAL_CYCLES   = pmic_types_pkg::PGOOD_DELAY_CYCLES,
    parameter int PGOOD_DELAY_W = $clog2(QUAL_CYCLES + 1)
)(
    input  wire logic                     clk,
    input  wire logic                     rst_n,
    input  wire logic                     pgood_comp,
    input  wire logic                     run_active,
    input  wire logic                     PGOOD,
    // DUT internals, connected explicitly in bind_sva.sv
    input  wire logic [PGOOD_DELAY_W-1:0] dut_qualify_counter,
    input  wire logic                     dut_pwm_fall
);


/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         PGOOD is low at every edge while rst_n is low. Carries no disable iff
         - reset is the condition under test, and disabling on it would
         silence the property exactly when it has something to say. PGOOD is
         combinational on the counter, which reset clears, so this holds
         through the output expression rather than through a reset branch of
         its own.
*/
property p_rst_n_mean_pgood_low;

  @(posedge clk)
    (!rst_n) |-> (!PGOOD);

endproperty

a_rst_n_mean_pgood_low: assert property (p_rst_n_mean_pgood_low)
  else begin
    
    sva_pkg::note_failure($sformatf(
     "a_rst_n_mean_pgood_low: rst did not pull pgood low"));

  end

c_rst_n_mean_pgood_low: cover property (@(posedge clk) (!rst_n));



/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         IMMEDIATE DEASSERT. If either live condition is low, PGOOD is low on
         that same edge - no clock of latency. This is the safety half of the
         module's asymmetry: the secondary circuitry must be handed back to
         the input LDO before the rail collapses, and a registered output
         would cost a clock the rail may not have.

*/

property p_pgood_drops_immediately;

  @(posedge clk) disable iff (!rst_n)
    (!pgood_comp || !run_active) |-> !PGOOD;

endproperty

a_pgood_drops_immediately: assert property (p_pgood_drops_immediately)
  else begin
    
    sva_pkg::note_failure($sformatf(
     "a_pgood_drops_immediately: pgood did not deassert on pgood_comp = %b, run_active = %b",
     pgood_comp,run_active));

  end

c_buck_is_not_in_smooth_run: cover property (@(posedge clk) disable iff
 (!rst_n) (!pgood_comp || !run_active));


/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         SLOW ASSERT. PGOOD high implies the qualifying count was reached -
         the rail cannot be declared good early. Same-edge, since PGOOD is
         combinational on the counter.

      
*/

property p_pgood_assertion;

  @(posedge clk) disable iff (!rst_n)
    PGOOD |-> dut_qualify_counter == QUAL_CYCLES;

endproperty

a_pgood_assertion: assert property (p_pgood_assertion)
  else begin
    
    sva_pkg::note_failure($sformatf(
     "a_pgood_assertion: PGOOD high even though qualify counter not saturated and is at = %0d",
     dut_qualify_counter));

  end

c_pgood_assertion: cover property (@(posedge clk) disable iff (!rst_n) PGOOD);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         The qualifying period measures CONSECUTIVE good cycles. Any dip below
         the comparator threshold, or any departure from S_RUN, clears the
         counter rather than pausing it, so the rail must earn the full delay
         again from zero.

         Antecedent is the same expression as c_buck_is_not_in_smooth_run in
         group 2, which is why this group carries no cover of its own.
*/

property p_qualify_counter_resets;

  @(posedge clk) disable iff (!rst_n)
    (!pgood_comp || !run_active) |=> (dut_qualify_counter == 0);

endproperty

a_qualify_counter_resets: assert property (p_qualify_counter_resets)
  else begin
    
    sva_pkg::note_failure($sformatf(
     "a_qualify_counter_resets: run counter did not reset even though pgood comp = %b and run_active = %b",
     pgood_comp,run_active));

  end

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         The counter advances once per switching cycle, not once per clock.
         Any movement must have been preceded by a pwm_fall pulse.

         A counter that
         ticked per clock would still saturate, still gate PGOOD, still pass
         groups 3, 4 and 6 - and would qualify the rail roughly a hundred
         times too fast, which on a real board means handing the secondary
         load over before the output has settled.


*/

property p_run_counter_advances_on_pwm_fall;

  @(posedge clk) disable iff (!rst_n)
    (dut_qualify_counter > $past(dut_qualify_counter)) |-> $past(dut_pwm_fall);

endproperty

a_run_counter_advances_on_pwm_fall: assert property (p_run_counter_advances_on_pwm_fall)
  else begin
    
    sva_pkg::note_failure($sformatf(
     "a_run_counter_advances_on_pwm_fall: run counter advanced without cause"));

  end

c_run_counter_advances_on_pwm_fall: cover property (@(posedge clk) disable iff (!rst_n)
  (dut_qualify_counter > $past(dut_qualify_counter)));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 6:
         The counter saturates at the target rather than wrapping. A wrap
         would drop the count back below the qualifying value and drag PGOOD
         low again on a rail that is still good - a spurious changeover back
         to the LDO.

         The consequent is guarded rather than demanded: a drop in pgood_comp
         or run_active legitimately clears the counter, which group 4 asserts.
         Without the guard the two properties would contradict each other.
*/

property p_qualify_counter_saturates;

  @(posedge clk) disable iff (!rst_n)
        (dut_qualify_counter == QUAL_CYCLES)
        |=> ((pgood_comp && run_active) -> $stable(dut_qualify_counter));

endproperty

a_qualify_counter_saturates: assert property (p_qualify_counter_saturates)
  else begin
    
    sva_pkg::note_failure($sformatf(
     "a_qualify_counter_saturates: run counter went past saturation, it reads = %0d", dut_qualify_counter));

  end

c_qualify_counter_saturates: cover property (@(posedge clk) disable iff (!rst_n)
 (dut_qualify_counter == QUAL_CYCLES));



/*
////////////////////////////////////////////////////////////////////////////////
*/


endmodule

`default_nettype wire

