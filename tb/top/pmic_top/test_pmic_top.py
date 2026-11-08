#
# Filename:         test_pmic_top.py
#
# File Description: cocotb tests for the whole supervisor (pmic_top through
#                   pmic_top_harness), acting as the board and the host MCU.
#                   Each test drives board events - the switch, the fault
#                   comparators, an overcurrent, the analog OVP trip, the
#                   reset button, host commands over SPI - into the harness
#                   and the supervisor model together, waits each event's
#                   settle time, and compares every status pin and STATUS
#                   with the model. The bound checkers (pmic_top_sva and every
#                   block's own) run underneath throughout.
#
#                   Tests:
#                     reset_is_safe                 fail-safe outputs in and after reset
#                     power_up_to_run_and_pgood     switch on, ramp, S_RUN, PGOOD
#                     pwm_passed_and_capped         gate pulse = modulator pulse, cut at MAX_ON
#                     overcurrent_hiccup_and_retry  one trip: hiccup, retry, strike held
#                     persistent_overcurrent_latches  strikes to the latch, no restart, reset recovers
#                     otp_and_uvlo_stop_and_recover each fault from S_RUN and back
#                     host_disable_and_enable       keyed disable, enable, over SPI
#                     analog_ovp_trip               the SCR tripped by the board, not the CPLD
#                     switch_off_and_on             the physical switch
#                     strikes_clear_after_clean_run a strike forgotten after the clean window
#
#                   Every test but reset_is_safe programs short timers over
#                   SPI, so in the reduced build (TELEMETRY_EN=0, no SPI) only
#                   reset_is_safe runs; the others are skipped.
#
# Global variables: None

import cocotb
from cocotb.triggers import ClockCycles, Timer

from supervisor_model import SupervisorModel
from board import (TELEMETRY, start, press_reset_button, configure_fast_timers, set_knob, pulse_knob,
                   host_disable, host_enable, measure_pulse, check, check_sva, wait_ms)
from top_constants import (OSC_ON_NOMINAL, OSC_ON_ABOVE_CEILING, MAX_ON_COUNTS,
                           SETTLE_START_MS, SETTLE_PGOOD_MS, SETTLE_FAULT_MS, SETTLE_HICCUP_MS,
                           SETTLE_LATCH_MS, FAST_CLEAN_RUN_MS)


async def bring_up(dut, model, pgood=True):

    """
    Purpose: From reset to a settled S_RUN: program the fast timers, turn the
             switch on, wait out the debounce and ramp - and, if asked, the
             PGOOD qualification. Checked against the model at each stop.
    """
    await configure_fast_timers(dut)
    await set_knob(dut, model, "en_from_switch", 1)
    await wait_ms(dut, model, SETTLE_START_MS)
    await check(dut, model)
    if pgood:
        await wait_ms(dut, model, SETTLE_PGOOD_MS)
        await check(dut, model, pgood_settled=True)


@cocotb.test()
async def reset_is_safe(dut):

    """
    Purpose: In reset every power-stage output is low. Out of reset the fault
             flags start asserted (their debouncers reset to the fail-safe
             value), so the OTP and UVLO LEDs show until the 200 us release,
             and the converter stays off with the switch off.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)

    await ClockCycles(dut.clk, 50)
    for pin in ["En", "PWM_out", "latch_out", "PGOOD"]:
        assert int(getattr(dut, pin).value) == 0, f"{pin} high just after reset"
    assert int(dut.Red_LED2.value) == 1, "Red_LED2 should show the fail-safe OTP flag after reset"
    assert int(dut.Red_LED3.value) == 1, "Red_LED3 should show the fail-safe UVLO flag after reset"

    await wait_ms(dut, model, 1)
    await check(dut, model)
    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def power_up_to_run_and_pgood(dut):

    """
    Purpose: Switch on: after the 20 ms debounce and the ramp the converter is
             in S_RUN with En and the green LED on; after the 9 ms PGOOD
             qualification PGOOD, pgood_LED and switch_supply follow. A rail
             that leaves its window drops PGOOD at once and regains it only
             after a new qualification.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model)

    await set_knob(dut, model, "PGOOD_comp", 0)
    await wait_ms(dut, model, 0.1)
    await check(dut, model)
    await set_knob(dut, model, "PGOOD_comp", 1)
    await wait_ms(dut, model, 1)
    await check(dut, model, pgood_settled=False)
    await wait_ms(dut, model, SETTLE_PGOOD_MS)
    await check(dut, model, pgood_settled=True)

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def pwm_passed_and_capped(dut):

    """
    Purpose: In S_RUN the gate pulse is the modulator's pulse, delayed but the
             same width, while it is under the ceiling; a modulator pulse
             longer than MAX_ON is cut to MAX_ON + 1 clocks (pwm_mask's
             documented offset).
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    modulator = await measure_pulse(dut, "Osc_in")
    width     = await measure_pulse(dut, "PWM_out")
    assert modulator == OSC_ON_NOMINAL, f"modulator pulse {modulator} clocks, set to {OSC_ON_NOMINAL}"
    assert width == modulator, f"PWM_out pulse {width} clocks, modulator {modulator}"

    dut.osc_on_clks.value = OSC_ON_ABOVE_CEILING
    await ClockCycles(dut.clk, 300)
    width = await measure_pulse(dut, "PWM_out")
    assert width == MAX_ON_COUNTS + 1, f"PWM_out pulse {width} clocks, ceiling {MAX_ON_COUNTS} + 1"

    dut.osc_on_clks.value = OSC_ON_NOMINAL
    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def overcurrent_hiccup_and_retry(dut):

    """
    Purpose: An overcurrent long enough to trip the window once, then gone:
             the converter hiccups, retries through soft start and returns to
             S_RUN with one strike outstanding (Red_LED1 blinking, not solid).
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    await pulse_knob(dut, "overcurrent", 5_000)        # 100 us: past the 12-of-16 trip
    model.overcurrent_trip()
    await wait_ms(dut, model, SETTLE_HICCUP_MS)
    await check(dut, model)

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def persistent_overcurrent_latches(dut):

    """
    Purpose: An overcurrent that never clears: three strikes, the latch trips,
             the converter stays off with Red_LED1 solid, and neither clearing
             the fault nor cycling the switch restarts it. Only the reset
             button (which drains the SCR) brings it back.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    await set_knob(dut, model, "overcurrent", 1)
    model.persistent_overcurrent()
    await wait_ms(dut, model, SETTLE_LATCH_MS)
    await check(dut, model)

    await set_knob(dut, model, "overcurrent", 0)
    await set_knob(dut, model, "en_from_switch", 0)
    await wait_ms(dut, model, SETTLE_START_MS)
    await set_knob(dut, model, "en_from_switch", 1)
    await wait_ms(dut, model, SETTLE_START_MS)
    await check(dut, model)

    await press_reset_button(dut, model)
    await bring_up(dut, model, pgood=False)

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def otp_and_uvlo_stop_and_recover(dut):

    """
    Purpose: Over-temperature, then undervoltage, each from S_RUN: the
             converter stops and the matching red LED lights; when the fault
             clears it ramps back to S_RUN with no strike taken.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    for knob in ["OTP_trig", "UVLO_trig"]:
        dut._log.info(f"fault: {knob}")
        await set_knob(dut, model, knob, 1)
        await wait_ms(dut, model, SETTLE_FAULT_MS)
        await check(dut, model)
        await set_knob(dut, model, knob, 0)
        await wait_ms(dut, model, SETTLE_FAULT_MS)
        await check(dut, model)

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def host_disable_and_enable(dut):

    """
    Purpose: The host vetoes the converter with a keyed disable over SPI and
             releases it with a plain enable; the converter follows.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    await host_disable(dut, model)
    await wait_ms(dut, model, 0.1)
    await check(dut, model)
    await host_enable(dut, model)
    await wait_ms(dut, model, 1)
    await check(dut, model)

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def analog_ovp_trip(dut):

    """
    Purpose: The analog OVP comparator trips the SCR directly. The CPLD did
             not trip it, so latch_out stays low; the latch read-back stops
             the converter and Red_LED1 is solid. The reset button recovers.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    await pulse_knob(dut, "ovp_trip", 10)
    model.ovp_trip()
    await wait_ms(dut, model, SETTLE_FAULT_MS)
    await check(dut, model)

    await press_reset_button(dut, model)
    await bring_up(dut, model, pgood=False)

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def switch_off_and_on(dut):

    """
    Purpose: The physical switch stops the converter after its debounce, and
             restarts it through soft start.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    await set_knob(dut, model, "en_from_switch", 0)
    await wait_ms(dut, model, SETTLE_START_MS)
    await check(dut, model)
    await set_knob(dut, model, "en_from_switch", 1)
    await wait_ms(dut, model, SETTLE_START_MS)
    await check(dut, model)

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def strikes_clear_after_clean_run(dut):

    """
    Purpose: One strike, then a fault-free run longer than the clean-run
             window (100 ms with the fast timers): the strike level returns to
             zero and Red_LED1 stops blinking. Slow: about 105 ms simulated.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    await pulse_knob(dut, "overcurrent", 5_000)
    model.overcurrent_trip()
    await wait_ms(dut, model, SETTLE_HICCUP_MS)
    await check(dut, model)

    await wait_ms(dut, model, FAST_CLEAN_RUN_MS + 5)
    await check(dut, model, pgood_settled=True)

    await check_sva(dut, failures_before)
