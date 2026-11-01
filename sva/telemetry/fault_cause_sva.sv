/*

# Filename:         fault_cause_sva.sv

# File Description: Concurrent assertion checker for fault_cause. Attached with
#                   bind so the RTL source carries no assertion constructs and
#                   the sv2v / Yosys ASIC path never sees them. The module has
#                   no parameters; widths come from the package.
#
#                   fault_cause is telemetry - it drives no control path - so
#                   these are claims about what the host is told: every cause
#                   that interrupted operation must be in the record, nothing
#                   else may be, a read must start a clean record, and the
#                   timestamp must be the moment the episode began.
#
#
#                   System-level note, not a module defect: in pmic_top,
#                   latch_assert rises only in S_HICCUP and then holds the
#                   supervisor in S_OFF, so it is never high while the
#                   converter runs and the LATCH bit is never set in the full
#                   design (README, known issues). Here the module is checked
#                   against its own spec, so the testbench drives latch_assert
#                   while running and the bit is captured.
#
#                   The checker forms the cause vector itself from the inputs,
#                   by the header's bit map (OVP, LATCH, OTP, UVLO, OC from MSB
#                   down), never from the DUT's ovp or episode_start.

# Global variables: None

*/

`default_nettype none

module fault_cause_sva
    import pmic_types_pkg::*;
(
    input  wire logic                     clk,
    input  wire logic                     rst_n,
    input  wire logic                     otp_state,
    input  wire logic                     uvlo_state,
    input  wire logic                     latch_state,
    input  wire logic                     latch_assert,
    input  wire logic                     window_trip,
    input  wire logic                     window_trip_SS,
    input  wire logic                     ss_active,
    input  wire logic                     run_active,
    input  wire logic                     fault_reg_read_done,
    input  wire logic [TIMESTAMP_W-1:0]   timestamp_ms,
    input  wire logic [TIMESTAMP_W-1:0]   fault_time,
    input  wire logic [FAULT_CAUSE_W-1:0] fault_reg
);

// out_of_reset: low from an asynchronous reset until the first clock edge with
//               rst_n high. Entering edge k it reads 1 only if no reset was
//               seen since edge k-1, so it gates every claim that reaches one
//               edge back - disable iff sees only the edge being evaluated.
logic out_of_reset;
// running: the converter is in S_SS or S_RUN - the capture window
logic running;
// causes: every cause live on this edge, at its fault_reg bit position -
//         [4] OVP (latch set without the CPLD's own trip), [3] LATCH,
//         [2] OTP, [1] UVLO, [0] OC (either overcurrent window)
logic [FAULT_CAUSE_W-1:0] causes;

always_ff @(posedge clk or negedge rst_n) begin
  /*
  Purpose:
  ---
  The checker's own reset tracker. Cleared asynchronously, so a reset pulse
  between two edges still disarms the two-edge claims at the second of them.
  */
  if (!rst_n) begin

    out_of_reset <= 1'b0;

  end

  else begin

    out_of_reset <= 1'b1;

  end
end

always_comb begin
  /*
  Purpose:
  ---
  The cause vector by the header's bit map, built from the inputs. The OVP
  rule is the header's: the latch reading back set with latch_assert low can
  only be the analog comparator's trip.
  */
  running = ss_active || run_active;
  causes  = {latch_state && !latch_assert,
             latch_assert,
             otp_state,
             uvlo_state,
             window_trip || window_trip_SS};
end


/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         RESET. While rst_n is low the record and its timestamp are zero.
         Carries no disable iff - reset is the condition under test, and
         disabling on it would silence the property exactly when it has
         something to say.
*/

property p_reset_clears;

  @(posedge clk)
    !rst_n |-> (fault_reg == '0) && (fault_time == '0);

endproperty

a_reset_clears: assert property (p_reset_clears)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_reset_clears: in reset fault_reg = %b, fault_time = %0d", fault_reg, fault_time));

  end

c_reset_clears: cover property (@(posedge clk) !rst_n);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         A READ STARTS A CLEAN RECORD. The edge after fault_reg_read_done
         leaves both the causes and the timestamp at zero - even if a cause is
         live on that same clock, since the clear wins and a cause still
         present is captured again on the next one (group 3). A DUT that let a
         capture beat the clear would hand firmware a record mixing the old
         window and the new.

         Two covers: a read of a quiet register, and one landing on a clock
         with a live cause while running, where the priority shows.
*/

property p_read_clears;

  @(posedge clk) disable iff (!rst_n)
    fault_reg_read_done |=> (out_of_reset -> ((fault_reg == '0) && (fault_time == '0)));

endproperty

a_read_clears: assert property (p_read_clears)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_read_clears: after a read fault_reg = %b, fault_time = %0d", fault_reg, fault_time));

  end

c_read_clears: cover property (@(posedge clk) disable iff (!rst_n) fault_reg_read_done);

c_read_beats_capture: cover property (@(posedge clk) disable iff (!rst_n)
    fault_reg_read_done && running && (causes != '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         CAPTURE WHILE RUNNING. With the converter in S_SS or S_RUN and no
         read, the record after an edge is exactly the record before it OR
         every cause live on that edge. One equation carries three claims:
         each live cause is captured, nothing that was not live is set, and
         no bit already set is cleared - a fault that has gone away is still
         reported. A wrong bit position, a missed cause, a wrong OVP inference
         or a bit that cleared itself all fail here.

         One cover per cause bit, so every position is shown captured.
*/

property p_capture_while_running;

  @(posedge clk) disable iff (!rst_n)
    (running && !fault_reg_read_done) |=>
      (out_of_reset -> (fault_reg == ($past(fault_reg) | $past(causes))));

endproperty

a_capture_while_running: assert property (p_capture_while_running)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_capture_while_running: fault_reg %b with causes %b became %b, expected %b",
      $past(fault_reg), $past(causes), fault_reg, $past(fault_reg) | $past(causes)));

  end

c_capture_oc:    cover property (@(posedge clk) disable iff (!rst_n)
    running && !fault_reg_read_done && causes[0]);
c_capture_uvlo:  cover property (@(posedge clk) disable iff (!rst_n)
    running && !fault_reg_read_done && causes[1]);
c_capture_otp:   cover property (@(posedge clk) disable iff (!rst_n)
    running && !fault_reg_read_done && causes[2]);
c_capture_latch: cover property (@(posedge clk) disable iff (!rst_n)
    running && !fault_reg_read_done && causes[3]);
c_capture_ovp:   cover property (@(posedge clk) disable iff (!rst_n)
    running && !fault_reg_read_done && causes[4]);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         NOTHING CAPTURED WHILE STOPPED. Outside S_SS and S_RUN, with no read,
         the record holds - a cause asserting with the converter already off
         is not captured, so a routine power-down, which drops Vin and raises
         UVLO while the housekeeping rail still holds the chip up, does not log
         a fault. The header calls this a limitation; it is the intended
         meaning of the register. $stable is a transition, so |=>.
*/

property p_hold_when_stopped;

  @(posedge clk) disable iff (!rst_n)
    (!running && !fault_reg_read_done) |=> (out_of_reset -> $stable(fault_reg));

endproperty

a_hold_when_stopped: assert property (p_hold_when_stopped)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_hold_when_stopped: converter stopped, fault_reg %b -> %b",
      $past(fault_reg), fault_reg));

  end

c_hold_when_stopped: cover property (@(posedge clk) disable iff (!rst_n)
    !running && !fault_reg_read_done && (causes != '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         THE EPISODE IS TIMESTAMPED WHEN IT BEGINS. On the edge fault_reg goes
         from empty to non-empty, fault_time takes the timestamp of that same
         edge - not the next one, which the header says episode_start exists
         to avoid. A read on that edge would have left the record empty, so
         no read guard is needed.
*/

property p_time_at_episode_start;

  @(posedge clk) disable iff (!rst_n)
    (out_of_reset && ($past(fault_reg) == '0) && (fault_reg != '0)) |->
      (fault_time == $past(timestamp_ms));

endproperty

a_time_at_episode_start: assert property (p_time_at_episode_start)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_time_at_episode_start: episode began at %0d ms, fault_time = %0d",
      $past(timestamp_ms), fault_time));

  end

c_time_at_episode_start: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && ($past(fault_reg) == '0) && (fault_reg != '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 6:
         THE TIMESTAMP MOVES ONLY AT AN EPISODE START OR A READ. Every way
         fault_time can change, listed:
           - reset, to zero (excluded by out_of_reset; group 1)
           - a read, to zero
           - an episode start - empty record, converter running, a cause
             live, no read - to that edge's timestamp
         So it is held while later causes accumulate ("start rather than most
         recent"), and an episode after a quiet spell with no read between
         keeps the earlier time. A DUT that restamped on every new cause, or
         on re-entering S_RUN, fails here.
*/

property p_time_moves_by_known_path;

  @(posedge clk) disable iff (!rst_n)
    (out_of_reset && $changed(fault_time)) |->
         ($past(fault_reg_read_done) && (fault_time == '0))
      || ($past(!fault_reg_read_done && running && (fault_reg == '0) && (causes != '0))
            && (fault_time == $past(timestamp_ms)));

endproperty

a_time_moves_by_known_path: assert property (p_time_moves_by_known_path)
  else begin

    sva_pkg::note_failure($sformatf(
      "a_time_moves_by_known_path: fault_time %0d -> %0d with fault_reg = %b, causes = %b, read = %b",
      $past(fault_time), fault_time, $past(fault_reg), $past(causes),
      $past(fault_reg_read_done)));

  end

c_time_held_as_causes_add: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && ($past(fault_reg) != '0) && (fault_reg != $past(fault_reg))
      && !$past(fault_reg_read_done));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: INPUT CONTRACT. Not a claim about fault_cause - a promise the
         supervisor makes: ss_active and run_active are never high together,
         they decode two different states. Written as an assertion so a
         violation points at the supervisor. No cover: no antecedent.
*/

property p_contract_states_exclusive;

  @(posedge clk) disable iff (!rst_n)
    !(ss_active && run_active);

endproperty

a_contract_states_exclusive: assert property (p_contract_states_exclusive)
  else begin

    sva_pkg::note_failure("a_contract_states_exclusive: supervisor drove ss_active and run_active together");

  end

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: Directed-scenario covers. No assertion of their own - the groups
         above state what must hold - but each is the evidence that the
         testbench actually built the case.

         c_ovp_vs_latch:     latch_state and latch_assert both high - the
                             CPLD's own trip, which must NOT read as OVP.
         c_merge_after_quiet: a new cause captured into a record that is
                             already non-empty from an earlier run, with the
                             converter having stopped in between and no read.
         c_capture_in_ss:    a cause captured in S_SS rather than S_RUN.
         c_reset_mid_episode: reset with a non-empty record.
*/

c_ovp_vs_latch: cover property (@(posedge clk) disable iff (!rst_n)
    running && latch_state && latch_assert);

c_merge_after_quiet: cover property (@(posedge clk) disable iff (!rst_n)
    out_of_reset && running && !$past(running) && (fault_reg != '0)
      && ((causes & ~fault_reg) != '0));

c_capture_in_ss: cover property (@(posedge clk) disable iff (!rst_n)
    ss_active && (causes != '0) && !fault_reg_read_done);

c_reset_mid_episode: cover property (@(posedge clk) !rst_n && ($past(fault_reg) != '0));

/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire
