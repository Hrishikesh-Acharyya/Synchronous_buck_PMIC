/*

# Filename:         supervisor.sv

# File Description: Supervisory state machine for the buck converter. Decides
#                   when the power stage may run, sequences soft start into
#                   regulation, sends a faulting converter into a hiccup
#                   cool-down, and shuts it off on any hard fault. Four states:
#
#                     S_OFF     disabled; leaves only when enabled and no
#                               fault is present
#                     S_SS      enabled, ramping the duty ceiling; to S_RUN
#                               on SS_done, to S_HICCUP on window_trip_SS
#                     S_RUN     enabled, regulating; to S_HICCUP on
#                               window_trip
#                     S_HICCUP  disabled for the cool-down; back to S_SS on
#                               hiccup_done - a retry always re-ramps, never
#                               re-enables straight into S_RUN
#
#                   OTP, UVLO, the latch read-back, latch_assert and losing
#                   the enable force S_OFF from every state. The analog OVP
#                   comparator needs no input here: it trips the shared
#                   protection latch directly, and the latch is seen on
#                   latch_state at once.
#
#                   en, the Gate Driver enable, is gated combinationally by the
#                   fault inputs as well as by the state, so a trip pulls the
#                   gate drive low on the same clock rather than waiting for
#                   the next state to register.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none

module supervisor
    import pmic_types_pkg::*;
(
    input  wire logic clk,
    input  wire logic rst_n,

    // ---- enable: both must be high to run ----
    input  wire logic en_SW,           // physical on/off switch, synchronised and debounced
    input  wire logic spi_enable,      // host enable over SPI (tied high without telemetry)

    // ---- hard faults: any one forces S_OFF ----
    input  wire logic OTP,             // over-temperature, debounced
    input  wire logic UVLO,            // input undervoltage, debounced
    input  wire logic latch_state,     // SCR protection latch read back, debounced
    input  wire logic latch_assert,    // strike_counter's trip into the latch

    // ---- sequencing handshakes ----
    input  wire logic SS_done,         // soft_start: the ramp has reached its target
    input  wire logic window_trip_SS,  // fault_arbiter: overcurrent window exceeded in S_SS
    input  wire logic window_trip,     // fault_arbiter: overcurrent window exceeded in S_RUN
    input  wire logic hiccup_done,     // hiccup_timer: the cool-down has elapsed

    // ---- outputs ----
    output logic      en,              // LM5106 enable
    output logic      ss_active,       // high only in S_SS
    output logic      run_active,      // high only in S_RUN
    output logic      hiccup_active,   // high only in S_HICCUP
    output state_t    state_out        // present state, for telemetry
);

// g_en: the converter is enabled - the switch is on and the host has not
//       disabled it
logic   g_en;
// state: the present state, registered
state_t state;
// next_state: the state the next clock edge will load
state_t next_state;
// en_from_state: the states in which the power stage may switch, before the
//                fault gating applied to en
logic   en_from_state;


always_comb begin

/*
Purpose:
---
Combine the two enables. The physical switch and the host must both allow the
converter to run; either one alone turns it off.
*/

  g_en = spi_enable & en_SW;

end


always_ff @(posedge clk or negedge rst_n) begin

/*
Purpose:
---
State register. Reset puts the converter in S_OFF, so it never powers up
switching.
*/

  if (!rst_n) begin

    state <= S_OFF;

  end
  else begin

    state <= next_state;

  end

end


always_comb begin

/*
Purpose:
---
Next-state logic. In every state the hard faults - losing g_en, OTP, UVLO,
latch_state, latch_assert - are tested first and go to S_OFF, so no sequencing
condition can outrank a shutdown. latch_assert also inhibits start-up, so a
strike-latched part cannot restart before the latch is read back on
latch_state, and it is tested in S_RUN as well so that state and output agree:
en is already forced low by it, and without the state change the FSM would
stay in S_RUN and re-enable at full duty when it released.

Each state then holds unless its own condition moves it on. S_SS holds until
SS_done, otherwise the state would last a single clock and the ramp would never
be awaited; S_HICCUP holds until hiccup_done, so the cool-down actually elapses
before a retry. An illegal encoding turns the converter off.
*/

  next_state = state;

  unique case (state)

    S_OFF: begin

      if (g_en & ~latch_state & ~OTP & ~UVLO & ~latch_assert) begin

        next_state = S_SS;

      end
      else begin

        next_state = S_OFF;

      end

    end

    S_SS: begin

      if (~g_en | OTP | latch_state | UVLO | latch_assert) begin

        next_state = S_OFF;

      end
      else if (window_trip_SS) begin

        next_state = S_HICCUP;

      end
      else if (SS_done) begin

        next_state = S_RUN;

      end
      else begin

        next_state = S_SS;

      end

    end

    S_RUN: begin

      if (~g_en | latch_state | OTP | UVLO | latch_assert) begin

        next_state = S_OFF;

      end
      else if (window_trip) begin

        next_state = S_HICCUP;

      end
      else begin

        next_state = S_RUN;

      end

    end

    S_HICCUP: begin

      if (~g_en | latch_state | OTP | latch_assert | UVLO) begin

        next_state = S_OFF;

      end
      else if (hiccup_done) begin

        next_state = S_SS;

      end
      else begin

        next_state = S_HICCUP;

      end

    end

    // an illegal state encoding turns the converter off
    default: next_state = S_OFF;

  endcase

end


always_comb begin

/*
Purpose:
---
The states in which the power stage may switch: soft start and regulation.
Off and the hiccup cool-down hold the gate drive low.
*/

  unique case (state)
    S_OFF:    en_from_state = 1'b0;
    S_SS:     en_from_state = 1'b1;
    S_RUN:    en_from_state = 1'b1;
    S_HICCUP: en_from_state = 1'b0;
    default:  en_from_state = 1'b0;
  endcase

end


always_comb begin

/*
Purpose:
---
Decode the present state for the blocks that act in one state only - soft
start, the PWM statistics, the hiccup timer and strike counter, the fault log
and power-good - and expose it for telemetry.
*/

  ss_active     = (state == S_SS);
  run_active    = (state == S_RUN);
  hiccup_active = (state == S_HICCUP);
  state_out     = state;

end


always_comb begin

/*
Purpose:
---
Drive the LM5106 enable. Gated by the fault inputs directly as well as by the
state, so a trip pulls the gate drive low combinationally, on the same clock,
instead of a clock later when the FSM has registered S_OFF.
*/

  en = g_en & en_from_state & ~OTP & ~latch_state & ~UVLO & ~latch_assert;

end


endmodule

`default_nettype wire
