/*

# Filename:         timestamp_sva.sv

# File Description: Concurrent assertion checker for timestamp. Attached with
#                   bind so the RTL source carries no assertion constructs and
#                   the sv2v / Yosys ASIC path never sees them. PRESCALE_VAL
#                   and TIMESTAMP_W are passed through from the bound
#                   instance, so the testbench can run at five clocks per tick
#                   and a sixteen-tick wrap while pmic_top is still checked
#                   against the real 50,000 and 2**24.
#
#                   Every claim here is an invariant - the module is two
#                   free-running counters with no inputs beyond the clock and
#                   reset, so nothing has to be constructed and the testbench
#                   is stimulus-free apart from the reset and letting the
#                   clock run.
#
#
#                   timestamp_ms is telemetry and drives no control path, but
#                   fault_cause latches it into the fault log and reg_file
#                   measures the host watchdog against it, so a prescaler
#                   dividing by the wrong number would put every logged
#                   timestamp and the 5 s bus timeout out by the same factor.

# Global variables: None

*/

`default_nettype none

module timestamp_sva #(
    parameter int PRESCALE_VAL = pmic_types_pkg::PRESCALE_VAL,
    parameter int TIMESTAMP_W  = pmic_types_pkg::TIMESTAMP_W,
    parameter int PRESCALAR_W  = $clog2(PRESCALE_VAL + 1)
)(
    input  wire logic                   clk,
    input  wire logic                   rst_n,
    input  wire logic [TIMESTAMP_W-1:0] timestamp_ms,
    // DUT internal, connected explicitly in bind_sva.sv. The prescaler is
    // named in timestamp.sv's own header and is what the module's whole
    // contract is about, so it is part of the contract rather than an
    // implementation detail.
    input  wire logic [PRESCALAR_W-1:0] dut_prescalar
);

// PRESCALE_MAX: the value the prescaler reaches before wrapping. The DUT
//               compares against PRESCALE_VAL-1, so a division by
//               PRESCALE_VAL takes the counter through 0 to PRESCALE_MAX
//               inclusive - PRESCALE_VAL distinct values, one tick.
localparam logic [PRESCALAR_W-1:0] PRESCALE_MAX = PRESCALAR_W'(PRESCALE_VAL - 1);


/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         Both counters read zero at every edge while rst_n is low. Carries no
         disable iff - reset is the condition under test, and disabling on it
         would silence the property exactly when it has something to say.
*/

property p_counters_zero_in_reset;

  @(posedge clk)
    (!rst_n) |-> ((timestamp_ms == '0) && (dut_prescalar == '0));

endproperty

a_counters_zero_in_reset: assert property (p_counters_zero_in_reset)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_counters_zero_in_reset: in reset with timestamp_ms=%0d prescalar=%0d",
      timestamp_ms, dut_prescalar));

  end

c_counters_zero_in_reset: cover property (@(posedge clk) (!rst_n));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         The prescaler never exceeds its wrap point. A plain invariant with no
         antecedent - true at every edge, so it needs no implication.

         Subsumed in principle by groups 3 and 4, but kept because it is the
         one property that still holds if the prescaler is loaded wrongly out
         of reset rather than counting wrongly, and because it costs one line.
*/

property p_prescalar_in_range;

  @(posedge clk) disable iff (!rst_n)
    (dut_prescalar <= PRESCALE_MAX);

endproperty

a_prescalar_in_range: assert property (p_prescalar_in_range)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_prescalar_in_range: prescalar=%0d exceeds max=%0d",
      dut_prescalar, PRESCALE_MAX));

  end

c_prescalar_at_max: cover property (@(posedge clk) disable iff (!rst_n)
                        (dut_prescalar == PRESCALE_MAX));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         Below the wrap point the prescaler advances by exactly one per clock.
         Catches a counter that skipped values or stalled - either would
         change the division ratio without changing the wrap point, so group 4
         alone would not see it.
*/

property p_prescalar_advances_by_one;

  @(posedge clk) disable iff (!rst_n)
    (dut_prescalar != PRESCALE_MAX) |=> (dut_prescalar == $past(dut_prescalar) + 1'b1);

endproperty

a_prescalar_advances_by_one: assert property (p_prescalar_advances_by_one)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_prescalar_advances_by_one: prescalar went %0d -> %0d",
      $past(dut_prescalar), dut_prescalar));

  end

c_prescalar_advances_by_one: cover property (@(posedge clk) disable iff (!rst_n)
                                 (dut_prescalar != PRESCALE_MAX));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         At the wrap point the prescaler returns to zero on the next clock.
         The complement of group 3: together they pin the division ratio to
         exactly PRESCALE_VAL clocks per tick, and neither alone does.
*/

property p_prescalar_wraps_to_zero;

  @(posedge clk) disable iff (!rst_n)
    (dut_prescalar == PRESCALE_MAX) |=> (dut_prescalar == '0);

endproperty

a_prescalar_wraps_to_zero: assert property (p_prescalar_wraps_to_zero)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_prescalar_wraps_to_zero: prescalar read %0d on the clock after max=%0d",
      dut_prescalar, PRESCALE_MAX));

  end

c_prescalar_wraps_to_zero: cover property (@(posedge clk) disable iff (!rst_n)
                               (dut_prescalar == PRESCALE_MAX));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         timestamp_ms increments by exactly one on each prescaler wrap. The +
         is unsigned and the counter is TIMESTAMP_W wide, so this holds across
         the natural wrap at 2**TIMESTAMP_W without a special case.
*/

property p_timestamp_increments_on_wrap;

  @(posedge clk) disable iff (!rst_n)
    (dut_prescalar == PRESCALE_MAX) |=> (timestamp_ms == $past(timestamp_ms) + 1'b1);

endproperty

a_timestamp_increments_on_wrap: assert property (p_timestamp_increments_on_wrap)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_timestamp_increments_on_wrap: timestamp_ms went %0d -> %0d on a prescaler wrap",
      $past(timestamp_ms), timestamp_ms));

  end

c_timestamp_wraps: cover property (@(posedge clk) disable iff (!rst_n)
                       (timestamp_ms == '1) ##1 (timestamp_ms == '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 6:
         timestamp_ms is stable on every clock that is not a prescaler wrap.
         The free-running claim: no fault, state change or host read may move
         it, and the only thing that clears it is rst_n.

         Without this a counter that incremented on every clock would satisfy
         group 5 - group 5 only constrains the wrap clocks, not the others.
*/

property p_timestamp_stable_otherwise;

  @(posedge clk) disable iff (!rst_n)
    (dut_prescalar != PRESCALE_MAX) |=> $stable(timestamp_ms);

endproperty

a_timestamp_stable_otherwise: assert property (p_timestamp_stable_otherwise)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_timestamp_stable_otherwise: timestamp_ms went %0d -> %0d with prescalar=%0d",
      $past(timestamp_ms), timestamp_ms, $past(dut_prescalar)));

  end

c_timestamp_stable_otherwise: cover property (@(posedge clk) disable iff (!rst_n)
                                  (dut_prescalar != PRESCALE_MAX));

/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire

