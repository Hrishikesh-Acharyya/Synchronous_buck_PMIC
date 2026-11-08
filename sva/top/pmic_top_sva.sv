/*

# Filename:         pmic_top_sva.sv

# File Description: Bound checker for pmic_top. Holds the claims that only the
#                   top level can make: how the blocks are WIRED to each other
#                   and to the pins. Every block below has its own checker for
#                   its own behaviour; nothing here repeats one of them. What
#                   is left is what a miswired top would break while every
#                   block still passed its own checker:
#                     - reset: every power-stage output is safe while the
#                       synchronised reset is low
#                     - the LM5106 enable: high only in S_SS or S_RUN, and only
#                       while every enable is given and every hard fault is
#                       clear, as the supervisor actually sees them
#                     - the gate PWM: only ever a pulse the modulator asked for
#                     - PGOOD: only while regulating; switch_supply is PGOOD
#                     - MISO: silent in a build without telemetry
#
#                   Claim tags (docs/VERIFICATION_RULES.md): every claim here
#                   is I - it holds on every edge and the bound checker is the
#                   whole check. The M claims - which state, which LEDs and
#                   which strike level a given sequence of board events leads
#                   to - need a model, and live in the cocotb testbench
#                   (tb/top/pmic_top, supervisor_model.py).
#
#                   Bound into pmic_top's scope with (.*), so the inputs are
#                   pmic_top's own internal nets: the debounced flags the
#                   supervisor sees, its state decode and spi_enable. Those
#                   names exist in the sv2v output too, so the same bind
#                   works on the converted Verilog.

# Global variables: None

*/

`default_nettype none

module pmic_top_sva #(
    parameter bit TELEMETRY_EN = 1'b1
)(
    input  wire logic       clk,
    input  wire logic       rst_n,                   // synchronised reset
    input  wire logic       Osc_sync,                // modulator PWM, synchronised
    input  wire logic       en_from_switch_sync_db,  // enable switch, debounced
    input  wire logic       spi_enable,              // host enable (tied 1 without telemetry)
    input  wire logic       OTP_sync_db,             // over-temperature, debounced
    input  wire logic       UVLO_sync_db,            // undervoltage, debounced
    input  wire logic       latch_stat_sync_db,      // SCR latch read-back, debounced
    input  wire logic       ss_active,               // supervisor in S_SS
    input  wire logic       run_active,              // supervisor in S_RUN
    input  wire logic       hiccup_active,           // supervisor in S_HICCUP
    input  wire logic       En,                      // DUT pin
    input  wire logic       PWM_out,                 // DUT pin
    input  wire logic       PGOOD,                   // DUT pin
    input  wire logic       switch_supply,           // DUT pin
    input  wire logic       latch_out,               // DUT pin
    input  wire logic       MISO                     // DUT pin
);

// out_of_reset: low from an asynchronous reset until the first clock edge
//               with rst_n high, so a claim that reaches back one edge is
//               never judged across a reset.
logic out_of_reset;

always_ff @(posedge clk or negedge rst_n) begin
  /*
  Purpose:
  ---
  Post-reset gate for the one claim that reads $past.
  */
  if (!rst_n) out_of_reset <= 1'b0;
  else        out_of_reset <= 1'b1;
end

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         RESET IS SAFE. While the synchronised reset is low the gate driver is
         disabled, no gate pulse is issued, the latch is not tripped and PGOOD
         is low. A property about reset, so it carries no disable iff.
         Cover: reset seen at least once.
*/

property p_reset_safe;

  @(posedge clk)
    !rst_n |-> (!En && !PWM_out && !latch_out && !PGOOD);

endproperty

a_reset_safe: assert property (p_reset_safe)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_reset_safe: in reset with En=%b PWM_out=%b latch_out=%b PGOOD=%b",
      En, PWM_out, latch_out, PGOOD));

  end

c_reset: cover property (@(posedge clk) !rst_n);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         THE GATE-DRIVER ENABLE. En is high only in S_SS or S_RUN, and only
         while the switch and the host both enable the converter and no hard
         fault is live - the debounced OTP, UVLO and latch read-back, and the
         strike counter's own latch trip. These are the nets pmic_top feeds
         the supervisor, so a fault wired to the wrong port, or not at all,
         fails here even though the supervisor passes its own checker.
         Same edge: En is combinational on all of them.
         Covers: En in each of its two states, and each gating input seen
         taking En down - so every term of the claim has been tested low.
*/

property p_en_only_switching_states;

  @(posedge clk) disable iff (!rst_n)
    En |-> (ss_active || run_active);

endproperty

a_en_only_switching_states: assert property (p_en_only_switching_states)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_en_only_switching_states: En high with ss=%b run=%b hiccup=%b",
      ss_active, run_active, hiccup_active));

  end


property p_en_gated_by_faults;

  @(posedge clk) disable iff (!rst_n)
    En |-> (en_from_switch_sync_db && spi_enable && !OTP_sync_db && !UVLO_sync_db &&
            !latch_stat_sync_db && !latch_out);

endproperty

a_en_gated_by_faults: assert property (p_en_gated_by_faults)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_en_gated_by_faults: En high with switch=%b host=%b OTP=%b UVLO=%b latch_stat=%b latch_out=%b",
      en_from_switch_sync_db, spi_enable, OTP_sync_db, UVLO_sync_db,
      latch_stat_sync_db, latch_out));

  end

c_en_in_ss:          cover property (@(posedge clk) disable iff (!rst_n) En && ss_active);
c_en_in_run:         cover property (@(posedge clk) disable iff (!rst_n) En && run_active);
c_switch_off_stops:  cover property (@(posedge clk) disable iff (!rst_n)
                       $fell(en_from_switch_sync_db) && $past(En));
c_host_off_stops:    cover property (@(posedge clk) disable iff (!rst_n)
                       $fell(spi_enable) && $past(En));
c_otp_stops:         cover property (@(posedge clk) disable iff (!rst_n)
                       $rose(OTP_sync_db) && $past(En));
c_uvlo_stops:        cover property (@(posedge clk) disable iff (!rst_n)
                       $rose(UVLO_sync_db) && $past(En));
c_latch_stat_stops:  cover property (@(posedge clk) disable iff (!rst_n)
                       $rose(latch_stat_sync_db) && !latch_out && $past(ss_active || run_active));
c_latch_out_rises:   cover property (@(posedge clk) disable iff (!rst_n) $rose(latch_out));
c_hiccup:            cover property (@(posedge clk) disable iff (!rst_n) $rose(hiccup_active));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         THE GATE PWM. PWM_out is a registered copy of the synchronised
         modulator PWM, cut short by pwm_mask but never extended, so a gate
         pulse on this edge means the modulator was high on the previous one.
         A PWM_out wired to anything but the masked modulator fails here.
         One edge back, so gated by out_of_reset.
         Covers: a pulse passed through, and a pulse cut short by the ceiling
         (modulator still high, gate already low) while switching.
*/

property p_pwm_only_when_modulator;

  @(posedge clk) disable iff (!rst_n)
    PWM_out |-> (!out_of_reset || $past(Osc_sync));

endproperty

a_pwm_only_when_modulator: assert property (p_pwm_only_when_modulator)
  else begin

    sva_pkg::note_failure("a_pwm_only_when_modulator: PWM_out high with the modulator low on the previous edge");

  end

c_pwm_passed:    cover property (@(posedge clk) disable iff (!rst_n) PWM_out && run_active);
c_pwm_truncated: cover property (@(posedge clk) disable iff (!rst_n)
                   run_active && $past(Osc_sync) && Osc_sync && $fell(PWM_out));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         POWER-GOOD AND THE SUPPLY CHANGEOVER. PGOOD is high only in S_RUN,
         and switch_supply carries PGOOD exactly - the two pins differ only
         electrically. Same edge.
         Covers: PGOOD high; PGOOD dropped by leaving S_RUN.
*/

property p_pgood_only_running;

  @(posedge clk) disable iff (!rst_n)
    PGOOD |-> run_active;

endproperty

a_pgood_only_running: assert property (p_pgood_only_running)
  else begin

    sva_pkg::note_failure("a_pgood_only_running: PGOOD high outside S_RUN");

  end


property p_switch_supply_is_pgood;

  @(posedge clk) disable iff (!rst_n)
    switch_supply == PGOOD;

endproperty

a_switch_supply_is_pgood: assert property (p_switch_supply_is_pgood)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_switch_supply_is_pgood: switch_supply=%b, PGOOD=%b", switch_supply, PGOOD));

  end

c_pgood:           cover property (@(posedge clk) disable iff (!rst_n) PGOOD);
c_pgood_left_run:  cover property (@(posedge clk) disable iff (!rst_n)
                     $fell(PGOOD) && $fell(run_active));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         NO TELEMETRY, NO MISO. In a build without telemetry there is no SPI
         slave, and MISO is tied low. Considered and subsumed for the full
         build: MISO there is spi_slave's business (its checker).
         No cover: the claim holds trivially in the full build and cannot be
         shown to fire there.
*/

property p_miso_silent_without_telemetry;

  @(posedge clk) disable iff (!rst_n)
    (TELEMETRY_EN == 1'b0) |-> !MISO;

endproperty

a_miso_silent_without_telemetry: assert property (p_miso_silent_without_telemetry)
  else begin

    sva_pkg::note_failure("a_miso_silent_without_telemetry: MISO high in a build without telemetry");

  end

/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire
