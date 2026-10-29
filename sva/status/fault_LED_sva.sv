/*

# Filename:         fault_LED_sva.sv

# File Description: Concurrent assertion checker for fault_LED. Attached with
#                   bind so the RTL source carries no assertion constructs and
#                   the sv2v / Yosys ASIC path never sees them.
#                   LED_BLINK_HALF_CLKS is passed through from the bound
#                   instance, so the testbench can run a four-clock half period
#                   while pmic_top is still checked against the real 6.25 M.
#
#                   Every output is registered, so every claim relating an
#                   indicator to its inputs reaches exactly one edge back.
#                   There is no latency to discover here the way there was in
#                   pwm_mask - the module is one flop deep throughout.
#
#                   currently_faulted is recomputed here from the four input
#                   conditions rather than read from the DUT. It is a plain OR
#                   of signals already on the port list, so an independent copy
#                   costs nothing and a bug in the DUT's version does not
#                   cancel out in the check.
#
#
#                   Not checked: that the blink timebase free-runs regardless
#                   of fault state. Group 7's antecedent contains no fault
#                   terms, so a timebase that stalled on a fault fails it
#                   already.
#
#                   Status only. Nothing here drives a control path, so a
#                   failure in this file is a wrong indication rather than a
#                   wrong decision - but the indicators are what a person
#                   standing at the bench believes, which is its own kind of
#                   safety claim.

# Global variables: None

*/

`default_nettype none

module fault_LED_sva #(
    parameter int LED_BLINK_HALF_CLKS = pmic_types_pkg::ms_to_clks(125),
    parameter int BLINK_W             = $clog2(LED_BLINK_HALF_CLKS + 1),
    parameter int STRIKE_W            = pmic_types_pkg::STRIKE_W
)(
    input  wire logic                clk,
    input  wire logic                rst_n,
    input  wire logic                otp_state,
    input  wire logic                uvlo_state,
    input  wire logic                latch_state,
    input  wire logic                latch_assert,
    input  wire logic [STRIKE_W-1:0] strike_level,
    input  wire logic                ss_active,
    input  wire logic                run_active,
    input  wire logic                pgood,
    input  wire logic                Green_LED,
    input  wire logic                pgood_LED,
    input  wire logic                Red_LED1,
    input  wire logic                Red_LED2,
    input  wire logic                Red_LED3,
    // DUT internals, connected explicitly in bind_sva.sv. Both are named in
    // fault_LED.sv's own header and the blink pattern is the module's visible
    // contract, so they are part of it rather than implementation detail.
    input  wire logic [BLINK_W-1:0]  dut_blink_counter,
    input  wire logic                dut_blink
);

// BLINK_MAX: the value blink_counter reaches before wrapping. The DUT compares
//            against LED_BLINK_HALF_CLKS-1, so a half period takes the counter
//            through 0 to BLINK_MAX inclusive.
localparam logic [BLINK_W-1:0] BLINK_MAX = BLINK_W'(LED_BLINK_HALF_CLKS - 1);

// fault_live: any fault condition live right now, recomputed from the inputs
//             rather than read from the DUT's currently_faulted
logic fault_live;
assign fault_live = (otp_state || uvlo_state || latch_state || latch_assert);

// latch_live: either path into the protection latch - the SCR readback or the
//             CPLD's own trip. Both mean terminal, so both mean solid.
logic latch_live;
assign latch_live = (latch_state || latch_assert);


/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         Every indicator is dark at each edge while rst_n is low. Carries no
         disable iff - reset is the condition under test, and disabling on it
         would silence the property exactly when it has something to say.
*/

property p_all_leds_dark_in_reset;

  @(posedge clk)
    (!rst_n) |-> (!Green_LED && !pgood_LED && !Red_LED1 && !Red_LED2 && !Red_LED3);

endproperty

a_all_leds_dark_in_reset: assert property (p_all_leds_dark_in_reset)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_all_leds_dark_in_reset: in reset with G=%b PG=%b R1=%b R2=%b R3=%b",
      Green_LED, pgood_LED, Red_LED1, Red_LED2, Red_LED3));

  end

c_all_leds_dark_in_reset: cover property (@(posedge clk) (!rst_n));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         The three direct indicators each carry their input, one clock later.
         Grouped rather than split into three groups because it is one claim
         applied three times - the comparators hold their own outputs for as
         long as the condition lasts, so none of these needs a stretch.

         Red_LED2 and Red_LED3 are independent rather than chained: both
         conditions can be live at once and both must show.

         Guarded on $past(rst_n): these properties reach one edge back, and
         disable iff only covers the edge being evaluated. A reset asserted
         mid-cycle clears the outputs between edges, so at the next edge the
         output is legitimately low while the input one edge back said high.
         The guard skips that single attempt.
*/

property p_red2_follows_otp;

  @(posedge clk) disable iff (!rst_n)
     $past(rst_n) |->(Red_LED2 == $past(otp_state));

endproperty

a_red2_follows_otp: assert property (p_red2_follows_otp)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_red2_follows_otp: Red_LED2=%b with otp_state=%b one edge back",
      Red_LED2, $past(otp_state)));

  end

property p_red3_follows_uvlo;

  @(posedge clk) disable iff (!rst_n)
     $past(rst_n) |->(Red_LED3 == $past(uvlo_state));

endproperty

a_red3_follows_uvlo: assert property (p_red3_follows_uvlo)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_red3_follows_uvlo: Red_LED3=%b with uvlo_state=%b one edge back",
      Red_LED3, $past(uvlo_state)));

  end

property p_pgood_led_follows_pgood;

  @(posedge clk) disable iff (!rst_n)
    $past(rst_n) |-> (pgood_LED == $past(pgood));

endproperty

a_pgood_led_follows_pgood: assert property (p_pgood_led_follows_pgood)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_pgood_led_follows_pgood: pgood_LED=%b with pgood=%b one edge back",
      pgood_LED, $past(pgood)));

  end

c_red2_lit: cover property (@(posedge clk) disable iff (!rst_n) Red_LED2);
c_red3_lit: cover property (@(posedge clk) disable iff (!rst_n) Red_LED3);
c_pgood_led_lit: cover property (@(posedge clk) disable iff (!rst_n) pgood_LED);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         Green is lit one clock after the converter is switching with nothing
         live, and dark otherwise. Both directions in one property, because
         the DUT drives it from a single expression and a one-directional
         claim would let a permanently dark LED pass.

         fault_live is recomputed from the inputs here. The window trips are
         deliberately absent from it, matching the DUT: a window trip takes
         the supervisor out of S_RUN on the next edge, so run_active
         extinguishes green anyway.

         Guarded on $past(rst_n): these properties reach one edge back, and
         disable iff only covers the edge being evaluated. A reset asserted
         mid-cycle clears the outputs between edges, so at the next edge the
         output is legitimately low while the input one edge back said high.
         The guard skips that single attempt.
*/

property p_green_shows_healthy_running;

  @(posedge clk) disable iff (!rst_n)
     $past(rst_n) |-> (Green_LED == $past((ss_active || run_active) && !fault_live));

endproperty

a_green_shows_healthy_running: assert property (p_green_shows_healthy_running)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_green_shows_healthy_running: Green_LED=%b with ss=%b run=%b fault=%b one edge back",
      Green_LED, $past(ss_active), $past(run_active), $past(fault_live)));

  end

c_green_lit: cover property (@(posedge clk) disable iff (!rst_n) Green_LED);

c_green_dark_on_fault: cover property (@(posedge clk) disable iff (!rst_n)
                           (ss_active || run_active) && fault_live);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         PRIORITY. A latched trip shows solid, whatever the strike level says.
         Terminal outranks recoverable, and this is the branch that makes
         solid and blinking mean different things.

         After a latch the clean counter can never advance, because the
         converter never runs again, so strike_level stays non-zero
         indefinitely. Without the priority the indicator would blink forever
         on a board that has permanently given up - which reads as "working
         through a problem" to anyone standing at the bench.
*/

property p_red1_solid_on_latch;

  @(posedge clk) disable iff (!rst_n)
    latch_live |=> Red_LED1;

endproperty

a_red1_solid_on_latch: assert property (p_red1_solid_on_latch)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_red1_solid_on_latch: Red_LED1=%b with latch_state=%b latch_assert=%b one edge back",
      Red_LED1, $past(latch_state), $past(latch_assert)));

  end

c_red1_solid_on_latch: cover property (@(posedge clk) disable iff (!rst_n)
                           latch_live && (strike_level != '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         With strikes outstanding and no latch, Red_LED1 carries the blink
         pattern exactly. Not merely "it changes sometimes" - the indicator
         must be the timebase, so a board recovering from a hiccup shows a
         clean square wave rather than a flicker tied to the fault itself.

         The blink persists through the retry, the soft-start and into S_RUN
         until clean_run_target fault-free cycles clear the strikes, so a
         recovering board blinks for about a second of healthy running. That
         is deliberate: "recently troubled, now proving itself" is real
         information.
*/

property p_red1_blinks_on_strikes;

  @(posedge clk) disable iff (!rst_n)
    (!latch_live && (strike_level != '0)) |=> (Red_LED1 == $past(dut_blink));

endproperty

a_red1_blinks_on_strikes: assert property (p_red1_blinks_on_strikes)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_red1_blinks_on_strikes: Red_LED1=%b with blink=%b strike_level=%0d one edge back",
      Red_LED1, $past(dut_blink), $past(strike_level)));

  end

c_red1_blinks_on_strikes: cover property (@(posedge clk) disable iff (!rst_n)
                              !latch_live && (strike_level != '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 6:
         With neither a latch nor strikes, Red_LED1 is dark. The third branch
         of the priority chain. Without it a permanently lit indicator would
         satisfy groups 4 and 5 and report a fault on a healthy board.
*/

property p_red1_dark_when_clean;

  @(posedge clk) disable iff (!rst_n)
    (!latch_live && (strike_level == '0)) |=> !Red_LED1;

endproperty

a_red1_dark_when_clean: assert property (p_red1_dark_when_clean)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_red1_dark_when_clean: Red_LED1 lit with no latch and strike_level=%0d one edge back",
      $past(strike_level)));

  end

c_red1_dark_when_clean: cover property (@(posedge clk) disable iff (!rst_n)
                            !latch_live && (strike_level == '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 7:
         The blink counter stays in range, advances by exactly one below the
         wrap point, and returns to zero at it. Three properties because they
         are the range bound and the two halves of the period: one says the
         counter advances by one, the other that it wraps, and neither alone
         rules out a counter that skipped values or wrapped early.

         No fault term appears in any antecedent, which is what makes the
         free-running claim hold: a timebase that stalled on a fault would
         fail the advance property.
*/

property p_blink_counter_in_range;

  @(posedge clk) disable iff (!rst_n)
    (dut_blink_counter <= BLINK_MAX);

endproperty

a_blink_counter_in_range: assert property (p_blink_counter_in_range)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_blink_counter_in_range: blink_counter=%0d exceeds max=%0d",
      dut_blink_counter, BLINK_MAX));

  end

property p_blink_counter_advances;

  @(posedge clk) disable iff (!rst_n)
    (dut_blink_counter != BLINK_MAX) |=> (dut_blink_counter == $past(dut_blink_counter) + 1'b1);

endproperty

a_blink_counter_advances: assert property (p_blink_counter_advances)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_blink_counter_advances: blink_counter went %0d -> %0d",
      $past(dut_blink_counter), dut_blink_counter));

  end

property p_blink_counter_wraps;

  @(posedge clk) disable iff (!rst_n)
    (dut_blink_counter == BLINK_MAX) |=> (dut_blink_counter == '0);

endproperty

a_blink_counter_wraps: assert property (p_blink_counter_wraps)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_blink_counter_wraps: blink_counter read %0d on the clock after max=%0d",
      dut_blink_counter, BLINK_MAX));

  end

c_blink_counter_at_max: cover property (@(posedge clk) disable iff (!rst_n)
                            (dut_blink_counter == BLINK_MAX));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 8:
         blink inverts on each counter wrap and holds on every other clock.
         Together with group 7 this pins the blink period to exactly
         2 * LED_BLINK_HALF_CLKS - the square wave the indicator claims to be.

         Without the stability half, a blink that toggled every clock would
         satisfy the inversion property on the wrap clocks and still be a
         flicker.
*/

property p_blink_toggles_on_wrap;

  @(posedge clk) disable iff (!rst_n)
    (dut_blink_counter == BLINK_MAX) |=> (dut_blink == !$past(dut_blink));

endproperty

a_blink_toggles_on_wrap: assert property (p_blink_toggles_on_wrap)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_blink_toggles_on_wrap: blink went %b -> %b on a counter wrap",
      $past(dut_blink), dut_blink));

  end

property p_blink_stable_otherwise;

  @(posedge clk) disable iff (!rst_n)
    (dut_blink_counter != BLINK_MAX) |=> $stable(dut_blink);

endproperty

a_blink_stable_otherwise: assert property (p_blink_stable_otherwise)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_blink_stable_otherwise: blink went %b -> %b with blink_counter=%0d",
      $past(dut_blink), dut_blink, $past(dut_blink_counter)));

  end

c_blink_high: cover property (@(posedge clk) disable iff (!rst_n) dut_blink);
c_blink_low:  cover property (@(posedge clk) disable iff (!rst_n) !dut_blink);

/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire

