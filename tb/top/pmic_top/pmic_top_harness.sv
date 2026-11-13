/*

# Filename:         pmic_top_harness.sv

# File Description: Testbench toplevel for the whole supervisor: pmic_top and a
#                   behavioural model of the board around it. cocotb sets the
#                   board's knobs (switch, fault comparators, rail-good, an
#                   overcurrent, the reset button) and talks SPI; everything
#                   that changes every switching cycle runs here in SV, so the
#                   simulation is not paced by Python.
#
#                   Board model:
#                     modulator    Osc_in, a free-running PWM of OSC_PERIOD_CLKS
#                                  clocks (450 kHz at 50 MHz) with osc_on_clks
#                                  of on-time; 0 holds it low (modulator off)
#                     valley comp  CP_trig high while the low-side FET conducts
#                                  (En high, PWM_out low) in a faulted cycle,
#                                  so fault_arbiter's valley sample sees it. A
#                                  cycle is faulted while overcurrent is set,
#                                  or by oc_per16: the first oc_per16 cycles
#                                  of every 16 - a fault duty that any 16-cycle
#                                  window (and any 32-cycle window, twice
#                                  over) sees exactly, for testing the window
#                                  thresholds at their edges
#                     SCR latch    latch_stat, set by the CPLD's latch_out or by
#                                  the analog OVP comparator (ovp_trip), and
#                                  cleared only by the reset button
#                     reset button rst_n_pin low and the SCR drained together -
#                                  on the board they are one switch
#                   The board runs on clk, so its edges are synchronous to the
#                   design; asynchrony at the pins is input_sync's job, covered
#                   by its own checker.
#
#                   Testbench only; never synthesised.

# Global variables: None

*/

`timescale 1ns/1ps
`default_nettype none

module pmic_top_harness #(
    // TELEMETRY_EN: passed to pmic_top - 1 the full build, 0 the reduced one
    parameter bit TELEMETRY_EN    = 1'b1,
    // OSC_PERIOD_CLKS: modulator period in clk cycles - 111 = 450 kHz at 50 MHz
    parameter int OSC_PERIOD_CLKS = 111
)(
    output logic            clk,              // 50 MHz, generated here
    // ---- SPI host: driven by cocotb, the same pins as host_if's wrapper ----
    input  wire logic       SCK,
    input  wire logic       CS_n,
    input  wire logic       MOSI,
    output logic            MISO,
    // ---- board knobs: driven by cocotb ----
    input  wire logic       reset_button,     // 1 = held: rst_n_pin low, SCR drained
    input  wire logic       en_from_switch,   // the physical enable switch
    input  wire logic [7:0] osc_on_clks,      // modulator on-time in clocks; 0 = stopped
    input  wire logic       overcurrent,      // valley current above the limit, every cycle
    input  wire logic [4:0] oc_per16,         // faulted cycles out of every 16; 0 = none
    input  wire logic       OTP_trig,         // over-temperature comparator
    input  wire logic       UVLO_trig,        // input undervoltage comparator
    input  wire logic       PGOOD_comp,       // output rail in its window
    input  wire logic       ovp_trip,         // analog OVP comparator: trips the SCR
    // ---- observed by cocotb ----
    output logic            Osc_in,           // the modulator PWM pmic_top receives
    output logic            CP_trig,          // the valley comparator output
    output logic            latch_stat,       // SCR state, read back by pmic_top
    output logic            PWM_out,
    output logic            En,
    output logic            PGOOD,
    output logic            latch_out,
    output logic            switch_supply,
    output logic            Green_LED,
    output logic            pgood_LED,
    output logic            Red_LED1,
    output logic            Red_LED2,
    output logic            Red_LED3,
    // sva_fail_count: running total of SVA failures from every bound checker,
    //                 exposed as a port because cocotb cannot read a package
    //                 variable
    output int unsigned     sva_fail_count
);

/*
Purpose:
---
The 50 MHz clock, generated here rather than by cocotb: a cocotb Clock costs a
Python callback on every edge, which made the simulation about ten times
slower. Needs Verilator's --timing (the Makefile passes it).
*/
initial clk = 1'b0;
always #10 clk = !clk;

// osc_count: position in the current modulator period
logic [7:0] osc_count;
// osc_cycle: modulator periods, modulo 16 - the oc_per16 pattern's position
logic [3:0] osc_cycle;
// cycle_faulted: this period carries an overcurrent
logic       cycle_faulted;
// scr: the SCR protection latch
logic       scr;

always @(posedge clk) begin

  /*
  Purpose:
  ---
  The modulator: a free-running counter over one switching period. Not reset by
  the CPLD's reset - on the board the modulator is analog and runs regardless -
  so it starts from an initial value; plain always, not always_ff, because the
  initial block is a second writer.
  */

  if (osc_count >= 8'(OSC_PERIOD_CLKS - 1)) begin

    osc_count <= 8'd0;
    osc_cycle <= osc_cycle + 4'd1;

  end
  else osc_count <= osc_count + 8'd1;

end

initial begin

  /*
  Purpose:
  ---
  Start the modulator counters from zero. The CPLD's reset does not reach
  the modulator, so this is its only initialisation.
  */

  osc_count = 8'd0;
  osc_cycle = 4'd0;

end

always_comb begin

  /*
  Purpose:
  ---
  Modulator output and the valley comparator. The comparator reads the
  low-side FET's current, so it reports only while that FET conducts: the
  converter enabled and the gate drive low. fault_arbiter's blanked sample,
  taken just before the modulator's next rising edge, finds it there - also
  when pwm_mask has cut the pulse short of the modulator's, because the
  low-side FET then conducts from the cut onward. The pattern index changes
  at the period boundary, so a whole low phase belongs to one cycle.
  */

  Osc_in        = (osc_count < osc_on_clks);
  cycle_faulted = overcurrent || ({1'b0, osc_cycle} < oc_per16);
  CP_trig       = cycle_faulted && En && !PWM_out;

end

always @(posedge clk) begin

  /*
  Purpose:
  ---
  The SCR latch: set by either trip source, held until the reset button drains
  it. It powers up clear (initial block, hence plain always).
  */

  if (reset_button)              scr <= 1'b0;
  else if (latch_out || ovp_trip) scr <= 1'b1;

end

// the SCR powers up clear
initial scr = 1'b0;

// latch_stat: the SCR's state, which the CPLD reads back
always_comb latch_stat = scr;

pmic_top #(.TELEMETRY_EN(TELEMETRY_EN)) u_dut (
    .clk            (clk),
    .rst_n_pin      (!reset_button),
    .SCK            (SCK),
    .CS_n           (CS_n),
    .MOSI           (MOSI),
    .MISO           (MISO),
    .Osc_in         (Osc_in),
    .CP_trig        (CP_trig),
    .OTP_trig       (OTP_trig),
    .UVLO_trig      (UVLO_trig),
    .latch_stat     (latch_stat),
    .PGOOD_comp     (PGOOD_comp),
    .en_from_switch (en_from_switch),
    .PWM_out        (PWM_out),
    .En             (En),
    .PGOOD          (PGOOD),
    .latch_out      (latch_out),
    .switch_supply  (switch_supply),
    .Green_LED      (Green_LED),
    .pgood_LED      (pgood_LED),
    .Red_LED1       (Red_LED1),
    .Red_LED2       (Red_LED2),
    .Red_LED3       (Red_LED3)
);

/*
Purpose:
---
Power-up. Verilator starts every flop at 0 with no reset edge, so on the first
clock edges, with reset held low, the flops take their reset values while the
bound checkers sample the zeros before them - a simulation artefact, not a
design fault (silicon is in reset from power-on). Assertions are off until the
reset button has been held across POWER_ON_CLKS edges; from then on every
reset the tests apply is a genuine falling edge, so the reset claims are
checked in every test.
*/
localparam int POWER_ON_CLKS = 4;

// power_on_count: clock edges since time zero, until POWER_ON_CLKS
logic [2:0] power_on_count;

initial begin

  /*
  Purpose:
  ---
  Assertions off from time zero, until the reset button has been held
  across POWER_ON_CLKS edges (see the Purpose block above POWER_ON_CLKS).
  */

  power_on_count = 3'd0;
  $assertoff;

end

always @(posedge clk) begin

  /*
  Purpose:
  ---
  Count the power-up edges, and turn the assertions on at the last one.
  */

  if (power_on_count < 3'(POWER_ON_CLKS)) begin

    power_on_count <= power_on_count + 3'd1;
    if (power_on_count == 3'(POWER_ON_CLKS - 1)) $asserton;

  end

end

// Expose the shared SVA failure tally for the cocotb verdict.
assign sva_fail_count = sva_pkg::sva_failures;

endmodule

`default_nettype wire
