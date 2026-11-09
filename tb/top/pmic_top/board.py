#
# Filename:         board.py
#
# File Description: Drives the board around pmic_top and compares it with the
#                   supervisor model. Every knob helper changes the harness and
#                   the model together, so the two cannot disagree; check()
#                   reads every status pin and, in the full build, STATUS and
#                   STRIKE_LEVEL over SPI, and fails the test with one line per
#                   mismatch. SPI access reuses host_if's driver.
#
# Global variables: None

import os

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer, with_timeout
from cocotb.utils import get_sim_time
try:                                    # cocotb 2.x
    from cocotb.triggers import SimTimeoutError
except ImportError:                     # cocotb 1.x
    from cocotb.result import SimTimeoutError

from spi_driver import spi_write, spi_read
from host_if_constants import (ADDR_WRITE_KEY, WRITE_KEY, ADDR_STATUS, ADDR_DISABLE_KEY,
                               DISABLE_KEY, ADDR_CONTROL)
from top_constants import (CLK_PERIOD_NS, OSC_ON_NOMINAL, RESET_PRESS_CLKS, MAX_ON_COUNTS,
                           FAST_HICCUP_BASE, FAST_CYCLES_PER_STEP, FAST_CLEAN_RUN, MAX_STRIKES,
                           TRIP_RUN_DEFAULT, TRIP_SS_DEFAULT)

# ADDR_STRIKE_LEVEL: reg_file STRIKE_LEVEL
ADDR_STRIKE_LEVEL = 0x12
# TELEMETRY: whether the build under test has the SPI host interface - the
#            Makefile exports TB_TELEMETRY from its TELEMETRY_EN
TELEMETRY = os.environ.get("TB_TELEMETRY", "1") == "1"


def bytes_le(value, count):

    """
    Purpose: value as count bytes, low byte first - reg_file's multi-byte order.
    """
    return [(value >> (8 * i)) & 0xFF for i in range(count)]


async def wait_ms(dut, model, ms):

    """
    Purpose: Let time pass with the board steady, and tell the model.
    """
    if ms > 0:
        await Timer(int(ms * 1_000_000), units="ns")
    model.elapse(ms)


async def settle(dut, model, at_least_ms):

    """
    Purpose: Wait an event's settle time - at least at_least_ms, and longer
             if the model says the converter is still on its way to S_RUN.
    """
    await wait_ms(dut, model, max(at_least_ms, model.settle_needed()))


# _powered_up: whether this simulation has had its power-on pre-roll
_powered_up = False


async def power_on(dut):

    """
    Purpose: Once per simulation: hold reset across the first clock edges,
             then release it, so the design is in a running state before the
             first test presses the reset button - every test's reset is then
             a genuine falling edge. The harness keeps the assertions off over
             the very first edges, where Verilator's zero-initialised flops
             would trip the reset claims (see pmic_top_harness.sv).
    """
    global _powered_up
    if _powered_up:
        return
    _powered_up = True
    dut.reset_button.value = 1
    await ClockCycles(dut.clk, RESET_PRESS_CLKS)
    await FallingEdge(dut.clk)
    dut.reset_button.value = 0
    await ClockCycles(dut.clk, RESET_PRESS_CLKS)


async def start(dut, model):

    """
    Purpose: Common start of every test: set the board idle (switch off, no
             faults, rail good, modulator running), make sure the simulation
             has powered on, record the SVA failure count so far, and press
             the reset button. Returns the recorded count for check_sva.
    """
    dut.SCK.value, dut.CS_n.value, dut.MOSI.value = 0, 1, 0
    dut.en_from_switch.value = 0
    dut.osc_on_clks.value    = OSC_ON_NOMINAL
    dut.overcurrent.value    = 0
    dut.oc_per16.value       = 0
    dut.OTP_trig.value       = 0
    dut.UVLO_trig.value      = 0
    dut.PGOOD_comp.value     = 1
    dut.ovp_trip.value       = 0

    await power_on(dut)
    failures_before = int(dut.sva_fail_count.value)
    await press_reset_button(dut, model)
    return failures_before


async def press_reset_button(dut, model):

    """
    Purpose: Hold the board's reset button: rst_n_pin low and the SCR drained.
             Released on a falling edge, so the release never lands on the
             edge the reset synchroniser samples.
    """
    await FallingEdge(dut.clk)
    dut.reset_button.value = 1
    await ClockCycles(dut.clk, RESET_PRESS_CLKS)
    await FallingEdge(dut.clk)
    dut.reset_button.value = 0
    model.reset_button()


async def configure_fast_timers(dut, model=None):

    """
    Purpose: Program the short timers every test runs on: 1 ms hiccup base,
             one cycle per ramp step, a 100 ms clean-run window. These three
             are S_OFF-only, so this runs before the switch is turned on. The
             whole bank is written as one keyed frame, the live thresholds at
             their reset values. The model, if given, takes the same timers.
    """
    bank = ([TRIP_RUN_DEFAULT, TRIP_SS_DEFAULT, MAX_STRIKES, MAX_ON_COUNTS]
            + bytes_le(FAST_HICCUP_BASE, 3)
            + [FAST_CYCLES_PER_STEP] + bytes_le(FAST_CLEAN_RUN, 3))
    await spi_write(dut, ADDR_WRITE_KEY, [WRITE_KEY] + bank)
    if model is not None:
        model.fast_timers()


async def write_live_thresholds(dut, trip_run=TRIP_RUN_DEFAULT, trip_ss=TRIP_SS_DEFAULT,
                                max_strikes=MAX_STRIKES, max_on=MAX_ON_COUNTS):

    """
    Purpose: One keyed frame writing the four live thresholds (0x50-0x53),
             which reg_file accepts in any state: every register written
             whole, none S_OFF-only. Raw values - reg_file clamps them.
    """
    await spi_write(dut, ADDR_WRITE_KEY, [WRITE_KEY, trip_run, trip_ss, max_strikes, max_on])


async def read_register(dut, address, count=1):

    """
    Purpose: Read count bytes from address; one int, low byte first.
    """
    data = await spi_read(dut, address, count)
    return sum(byte << (8 * i) for i, byte in enumerate(data))


async def set_knob(dut, model, knob, value):

    """
    Purpose: Drive one board knob and tell the model. Driven on a falling edge
             so it never changes on the edge the input synchronisers sample.
    """
    await FallingEdge(dut.clk)
    getattr(dut, knob).value = value
    if knob == "en_from_switch":
        model.set_switch(value)
    elif knob == "OTP_trig":
        model.set_otp(value)
    elif knob == "UVLO_trig":
        model.set_uvlo(value)
    elif knob == "PGOOD_comp":
        model.set_pgood_comp(value)


async def glitch_knob(dut, knob, value, clocks):

    """
    Purpose: Drive a knob to value for a number of clocks, then back to what
             it was. The model is not told: a glitch the design must filter.
    """
    await FallingEdge(dut.clk)
    signal = getattr(dut, knob)
    before = int(signal.value)
    signal.value = value
    await ClockCycles(dut.clk, clocks)
    await FallingEdge(dut.clk)
    signal.value = before


async def trip_once(dut, model, clocks=5_000):

    """
    Purpose: One overcurrent episode: the valley current over the limit for
             a number of clocks (default 100 us, about 45 cycles - well past
             the 12-of-16 trip), then gone before the retry. Returns the
             hiccup the model expects, in ms (0: the strike latched, or the
             converter was not running).
    """
    await FallingEdge(dut.clk)
    dut.overcurrent.value = 1
    cool_down = model.overcurrent_trip()
    await ClockCycles(dut.clk, clocks)
    await FallingEdge(dut.clk)
    dut.overcurrent.value = 0
    return cool_down


async def edge_within(dut, signal_name, rising, timeout_ms):

    """
    Purpose: Wait for the next rising (or falling) edge of a signal; its
             simulation time in ms, or None if it did not come in time.
    """
    signal  = getattr(dut, signal_name)
    trigger = RisingEdge(signal) if rising else FallingEdge(signal)
    try:
        await with_timeout(trigger, int(timeout_ms * 1_000_000), "ns")
    except SimTimeoutError:
        return None
    return get_sim_time("ns") / 1_000_000


async def pulse_knob(dut, knob, clocks):

    """
    Purpose: Raise a knob for a number of clocks, then drop it.
    """
    await FallingEdge(dut.clk)
    getattr(dut, knob).value = 1
    await ClockCycles(dut.clk, clocks)
    await FallingEdge(dut.clk)
    getattr(dut, knob).value = 0


async def host_disable(dut, model):

    """
    Purpose: Keyed host disable over SPI: [DISABLE_KEY][CONTROL = 0].
    """
    await spi_write(dut, ADDR_DISABLE_KEY, [DISABLE_KEY, 0x00])
    model.set_host_enable(0)


async def host_enable(dut, model):

    """
    Purpose: Host enable over SPI: CONTROL = 1, no key needed.
    """
    await spi_write(dut, ADDR_CONTROL, [0x01])
    model.set_host_enable(1)


async def measure_pulse(dut, signal_name):

    """
    Purpose: Width, in clocks, of the next high pulse on a signal, from the
             simulation time of its rising and falling edges.
    """
    signal = getattr(dut, signal_name)
    await RisingEdge(signal)
    rise_ns = get_sim_time("ns")
    await FallingEdge(signal)
    return round((get_sim_time("ns") - rise_ns) / CLK_PERIOD_NS)


async def check(dut, model, telemetry=TELEMETRY, pgood_settled=None):

    """
    Purpose: Compare the settled board with the model: every status pin, and
             in the full build STATUS (state, latch, PGOOD, switch, host
             enable) and STRIKE_LEVEL over SPI. Red_LED1 "blink" accepts
             either level - it toggles every 125 ms - and is checked through
             STRIKE_LEVEL instead. A field the model reports as unknown
             (None: too close to a timing boundary) is skipped.
             pgood_settled overrides the model's timed PGOOD prediction.
             Returns the prediction, for the caller's coverage.
    """
    expected = model.predict(pgood_settled)
    mismatches = []

    for pin in ["En", "PGOOD", "switch_supply", "pgood_LED", "Green_LED", "latch_out",
                "latch_stat", "Red_LED2", "Red_LED3"]:
        actual = int(getattr(dut, pin).value)
        if expected[pin] is not None and actual != expected[pin]:
            mismatches.append(f"{pin}: DUT {actual}, model {expected[pin]}")

    red1 = int(dut.Red_LED1.value)
    if expected["Red_LED1"] == "solid" and red1 != 1:
        mismatches.append("Red_LED1: DUT 0, model solid")
    if expected["Red_LED1"] == "off" and red1 != 0:
        mismatches.append("Red_LED1: DUT 1, model off")

    if telemetry:
        status  = (await spi_read(dut, ADDR_STATUS, 1))[0]
        strikes = (await spi_read(dut, ADDR_STRIKE_LEVEL, 1))[0]
        fields = {
            "STATUS state":       (status & 0x3,        expected["state"]),
            "STATUS latch":       ((status >> 3) & 1,   expected["latch_stat"]),
            "STATUS pgood":       ((status >> 2) & 1,   expected["PGOOD"]),
            "STATUS en_switch":   ((status >> 4) & 1,   model.switch_seen()),
            "STATUS spi_enable":  ((status >> 5) & 1,   model.host_enable),
            "STRIKE_LEVEL":       (strikes,             expected["strikes"]),
        }
        for name, (actual, wanted) in fields.items():
            if wanted is not None and actual != wanted:
                mismatches.append(f"{name}: DUT {actual}, model {wanted}")

    assert not mismatches, "board mismatch:\n" + "\n".join(mismatches)
    return expected


async def check_sva(dut, failures_before):

    """
    Purpose: Assert that this test caused no SVA failures.
    """
    await ClockCycles(dut.clk, 100)
    new_failures = int(dut.sva_fail_count.value) - failures_before
    assert new_failures == 0, f"{new_failures} SVA failure(s) during this test"
