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
#                   Design-intent edge cases - what the blocks' contracts
#                   imply once they are wired together, tested at the pins:
#                     window_thresholds_exact       11 of 16 never trips in S_RUN, 12 does;
#                                                   26 of 32 never trips in S_SS, 28 does
#                     overcurrent_seen_above_ceiling  a modulator pulse longer than its own
#                                                   low phase: the valley sample lands in
#                                                   pwm_mask's cut, so the fault is seen
#                     hiccup_backoff_doubles        trip latency, then 2 ms and 4 ms
#                                                   cool-downs, then the latch
#                     strikes_survive_stops         host and OTP stops do not launder strikes;
#                                                   three separate episodes latch
#                     max_strikes_lowered_live      a limit below the count acts on the
#                                                   next hiccup, not at once; 0 clamps to 1
#                     max_on_lowered_while_running  MAX_ON lowered in S_RUN reaches the gate at
#                                                   the next soft start, not before
#                     fault_during_hiccup           UVLO or a host disable mid-cool-down
#                                                   ends in S_OFF, strike kept, no retry
#                     short_glitches_filtered       sub-debounce OTP/UVLO pulses, chatter, a
#                                                   switch drop-out, a short fault release
#                     modulator_stall               soft start waits on switching cycles; a
#                                                   stuck-high modulator gets one capped pulse
#                     reset_mid_run                 safe at once, config lost, restart on
#                                                   the reset timers
#                     latched_and_faulted_while_off OVP and OTP before the switch: never
#                                                   starts; reset clears the SCR, not OTP
#
#                   random_walk is the constrained-random test: see its
#                   docstring.
#
#                   Every test but reset_is_safe programs short timers over
#                   SPI, so in the reduced build (TELEMETRY_EN=0, no SPI) only
#                   reset_is_safe runs; the others are skipped.
#
# Global variables: None

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer
from cocotb.utils import get_sim_time

from supervisor_model import SupervisorModel, S_OFF, S_SS, S_RUN
from board import (TELEMETRY, start, press_reset_button, configure_fast_timers, set_knob, pulse_knob,
                   host_disable, host_enable, measure_pulse, check, check_sva, wait_ms, settle,
                   glitch_knob, trip_once, edge_within, write_live_thresholds, read_register,
                   ADDR_STRIKE_LEVEL)
from host_if_constants import ADDR_STATUS
from top_constants import (OSC_ON_NOMINAL, OSC_ON_ABOVE_CEILING, OSC_ON_NEAR_FULL, MAX_ON_COUNTS,
                           MIN_ON_COUNTS, SETTLE_START_MS, SETTLE_PGOOD_MS, SETTLE_FAULT_MS,
                           SETTLE_HICCUP_MS, SETTLE_LATCH_MS, FAST_CLEAN_RUN_MS, FAST_HICCUP_MS,
                           TRIP_RUN_DEFAULT, TRIP_SS_DEFAULT, WINDOW_RUN, CYCLE_MS,
                           CLK_PERIOD_NS, PGOOD_DELAY_EXACT_MS, FAULT_ASSERT_MS,
                           FAULT_RELEASE_MS, SWITCH_DEBOUNCE_MS, DEFAULT_CYCLES_PER_STEP,
                           MAX_STRIKES)

# ADDR_*: reg_file thresholds read back by the edge-case tests
ADDR_MAX_STRIKES, ADDR_MAX_ON, ADDR_HICCUP, ADDR_CYC_PER_STEP, ADDR_CLEAN_RUN = 0x52, 0x53, 0x54, 0x57, 0x58


def ms_clocks(ms):

    """
    Purpose: Milliseconds as a whole number of supervisor clocks.
    """
    return int(ms * 1_000_000 / CLK_PERIOD_NS)


async def bring_up(dut, model, pgood=True):

    """
    Purpose: From reset to a settled S_RUN: program the fast timers, turn the
             switch on, wait out the debounce and ramp - and, if asked, the
             PGOOD qualification. Checked against the model at each stop.
    """
    await configure_fast_timers(dut, model)
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

    # PGOOD_comp is not debounced (pmic_top): a single-clock drop-out of the
    # rail comparator drops PGOOD at once, and the full 9 ms qualification
    # starts again - still low 1 ms before it ends, high after
    await FallingEdge(dut.clk)
    dut.PGOOD_comp.value = 0
    model.set_pgood_comp(0)
    await FallingEdge(dut.clk)
    dut.PGOOD_comp.value = 1
    model.set_pgood_comp(1)
    await ClockCycles(dut.clk, 5)
    assert int(dut.PGOOD.value) == 0, "PGOOD survived a one-clock rail drop-out"
    await wait_ms(dut, model, PGOOD_DELAY_EXACT_MS - 1)
    await check(dut, model)
    await wait_ms(dut, model, 2)
    await check(dut, model)
    assert int(dut.PGOOD.value) == 1, "PGOOD did not requalify"

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


# ==============================================================================
# Design-intent edge cases
# ==============================================================================

@cocotb.test(skip=not TELEMETRY)
async def window_thresholds_exact(dut):

    """
    Purpose: The overcurrent windows at their thresholds, end to end through
             the valley comparator, the blanked sample and the window count.
             oc_per16 faults the first N cycles of every 16, so every 16-cycle
             window holds exactly N and every 32-cycle window 2N.
             S_RUN (12 of 16): 11 runs on indefinitely, 12 trips.
             S_SS  (28 of 32): 13 per 16 (26 of 32) ramps through, 14 (28)
             trips. For the soft-start half TRIP_RUN is raised to 16, so the
             pattern cannot trip the run window instead, and each attempt
             starts a fresh ramp with a host disable / enable.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    dut.oc_per16.value = TRIP_RUN_DEFAULT - 1
    await wait_ms(dut, model, 2)                          # ~900 cycles
    await check(dut, model)
    assert model.strikes == 0

    dut.oc_per16.value = TRIP_RUN_DEFAULT
    model.overcurrent_trip()
    await ClockCycles(dut.clk, ms_clocks(0.1))            # 45 cycles: one window is 16
    dut.oc_per16.value = 0
    await settle(dut, model, 0.5)
    await check(dut, model)
    assert model.strikes == 1

    await write_live_thresholds(dut, trip_run=WINDOW_RUN)
    for per16 in [TRIP_SS_DEFAULT // 2 - 1, TRIP_SS_DEFAULT // 2]:
        dut._log.info(f"soft start with {per16} of every 16 cycles faulted")
        await host_disable(dut, model)
        await wait_ms(dut, model, 0.1)
        dut.oc_per16.value = per16
        await host_enable(dut, model)
        if 2 * per16 >= TRIP_SS_DEFAULT:
            model.overcurrent_trip()
        await ClockCycles(dut.clk, ms_clocks(0.12))       # 54 of the ~71 ramp cycles
        dut.oc_per16.value = 0
        await settle(dut, model, 0.5)
        await check(dut, model)
    assert model.strikes == 2

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def overcurrent_seen_above_ceiling(dut):

    """
    Purpose: A modulator pulse of 108 of 111 clocks leaves only 3 clocks of
             its own low phase - shorter than fault_arbiter's 5-clock
             lookback, so the valley sample falls inside the modulator's
             pulse. pwm_mask has already cut the gate at MAX_ON, though, and
             the low-side FET conducts from the cut: the sample must still
             see an overcurrent there, and trip.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    dut.osc_on_clks.value = OSC_ON_NEAR_FULL
    await ClockCycles(dut.clk, 300)
    width = await measure_pulse(dut, "PWM_out")
    assert width == MAX_ON_COUNTS + 1, f"PWM_out pulse {width} clocks, ceiling {MAX_ON_COUNTS} + 1"

    await trip_once(dut, model)
    await settle(dut, model, 0.5)
    await check(dut, model)
    assert model.strikes == 1

    dut.osc_on_clks.value = OSC_ON_NOMINAL
    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def hiccup_backoff_doubles(dut):

    """
    Purpose: A persistent overcurrent, timed at the pins. The first trip
             comes within the run window's threshold count of cycles; each
             cool-down is the base doubled per strike - 2 ms, then 4 ms with
             the 1 ms base (the level after the increment); the third entry
             trips the latch and En never returns.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    await set_knob(dut, model, "overcurrent", 1)
    onset = get_sim_time("ns") / 1_000_000
    first_trip = await edge_within(dut, "En", rising=False, timeout_ms=1)
    assert first_trip is not None, "no trip within 1 ms of a persistent overcurrent"
    latency_cycles = (first_trip - onset) / CYCLE_MS
    assert latency_cycles <= TRIP_RUN_DEFAULT + 2, f"trip took {latency_cycles:.1f} cycles"

    trip = first_trip
    for level in [1, 2]:
        retry = await edge_within(dut, "En", rising=True, timeout_ms=10)
        assert retry is not None, f"no retry after strike {level}"
        off_ms = retry - trip
        wanted = FAST_HICCUP_MS * (1 << level)
        assert abs(off_ms - wanted) < 0.01, f"cool-down {off_ms:.4f} ms at strike {level}, wanted {wanted} ms"
        trip = await edge_within(dut, "En", rising=False, timeout_ms=1)
        assert trip is not None, f"retry after strike {level} did not trip again"

    assert await edge_within(dut, "En", rising=True, timeout_ms=10) is None, "En returned after the latch"
    model.persistent_overcurrent()
    await set_knob(dut, model, "overcurrent", 0)
    await check(dut, model)
    assert model.latch_out == 1

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def strikes_survive_stops(dut):

    """
    Purpose: Strikes are cleared only by a clean run or a reset. Stopping the
             converter - a host disable, an over-temperature - and starting
             it again must not launder them, or a failing converter could be
             cycled forever. Three separate episodes, each followed by a stop
             and a restart, therefore end in the latch.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    await trip_once(dut, model)
    await settle(dut, model, 0.5)
    await check(dut, model)

    await host_disable(dut, model)
    await wait_ms(dut, model, 0.2)
    await check(dut, model)
    await host_enable(dut, model)
    await settle(dut, model, 0.5)
    await check(dut, model)
    assert model.strikes == 1

    await trip_once(dut, model)
    await settle(dut, model, 0.5)
    await check(dut, model)

    await set_knob(dut, model, "OTP_trig", 1)
    await wait_ms(dut, model, SETTLE_FAULT_MS)
    await check(dut, model)
    await set_knob(dut, model, "OTP_trig", 0)
    await settle(dut, model, SETTLE_FAULT_MS)
    await check(dut, model)
    assert model.strikes == 2

    assert await trip_once(dut, model) == 0
    await wait_ms(dut, model, SETTLE_FAULT_MS)
    await check(dut, model)
    assert model.latch_out == 1

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def max_strikes_lowered_live(dut):

    """
    Purpose: MAX_STRIKES is live but acts only at a hiccup entry. With one
             strike outstanding the host writes 0: reg_file clamps it to 1,
             the converter keeps running (a limit below the count does not
             latch by itself), and the next trip - strike 2, past the limit -
             latches at once rather than retrying.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    await trip_once(dut, model)
    await settle(dut, model, 0.5)
    await check(dut, model)

    await write_live_thresholds(dut, max_strikes=0)
    model.set_max_strikes(0)
    readback = await read_register(dut, ADDR_MAX_STRIKES)
    assert readback == 1, f"MAX_STRIKES read back {readback} after writing 0, wanted the clamp 1"
    await wait_ms(dut, model, 1)
    await check(dut, model)

    assert await trip_once(dut, model) == 0
    await wait_ms(dut, model, SETTLE_FAULT_MS)
    await check(dut, model)
    assert model.latch_out == 1 and model.strikes == 2

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def max_on_lowered_while_running(dut):

    """
    Purpose: When a live MAX_ON write reaches the gate. reg_file commits it at
             once and reads it back, but soft_start copies the limit into the
             gate ceiling only while ramping: lowered in S_RUN, the gate keeps
             the ceiling the last ramp reached until the next soft start, and
             is cut at the new limit (+1) from then on. Deliberate - the duty
             ceiling only moves through a ramp, never under a regulating loop
             - and safe, since the held ceiling passed the same downward-only
             clamp. Pinned here so a change to either half is caught.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    dut.osc_on_clks.value = OSC_ON_ABOVE_CEILING
    await ClockCycles(dut.clk, 300)
    width = await measure_pulse(dut, "PWM_out")
    assert width == MAX_ON_COUNTS + 1

    new_max_on = 40
    await write_live_thresholds(dut, max_on=new_max_on)
    readback = await read_register(dut, ADDR_MAX_ON)
    assert readback == new_max_on, f"MAX_ON read back {readback}, wrote {new_max_on}"
    await ClockCycles(dut.clk, 300)
    width_live = await measure_pulse(dut, "PWM_out")
    assert width_live == MAX_ON_COUNTS + 1, \
        f"MAX_ON lowered in S_RUN: gate cut at {width_live} clocks, wanted the held " \
        f"ceiling {MAX_ON_COUNTS} + 1 until the next soft start"
    await check(dut, model)

    await host_disable(dut, model)
    await wait_ms(dut, model, 0.1)
    await host_enable(dut, model)
    await settle(dut, model, 0.5)
    width_restarted = await measure_pulse(dut, "PWM_out")
    dut.osc_on_clks.value = OSC_ON_NOMINAL
    assert width_restarted == new_max_on + 1, \
        f"after the next soft start PWM_out pulse {width_restarted} clocks, wanted {new_max_on} + 1"

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def fault_during_hiccup(dut):

    """
    Purpose: A hard stop that arrives during the cool-down wins over the
             retry: UVLO raised just after a trip (it qualifies 1 ms later,
             inside the 2 ms cool-down) leaves the converter in S_OFF - En
             never rises while it is held - with the strike kept. The same
             for a host disable sent during the cool-down. Each recovers
             through a fresh soft start.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    await FallingEdge(dut.clk)
    dut.overcurrent.value = 1
    model.overcurrent_trip()
    await set_knob(dut, model, "UVLO_trig", 1)
    await ClockCycles(dut.clk, 5_000)
    dut.overcurrent.value = 0
    assert await edge_within(dut, "En", rising=True, timeout_ms=3 * FAST_HICCUP_MS) is None, \
        "the converter retried although UVLO qualified during the cool-down"
    await check(dut, model)
    await set_knob(dut, model, "UVLO_trig", 0)
    await settle(dut, model, SETTLE_FAULT_MS)
    await check(dut, model)
    assert model.strikes == 1

    await FallingEdge(dut.clk)
    dut.overcurrent.value = 1
    model.overcurrent_trip()
    await ClockCycles(dut.clk, 5_000)
    dut.overcurrent.value = 0
    await host_disable(dut, model)
    assert await edge_within(dut, "En", rising=True, timeout_ms=5 * FAST_HICCUP_MS) is None, \
        "the converter retried although the host disabled it during the cool-down"
    await check(dut, model)
    await host_enable(dut, model)
    await settle(dut, model, 0.5)
    await check(dut, model)
    assert model.strikes == 2

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def short_glitches_filtered(dut):

    """
    Purpose: The debouncers' design intent at the pins - a healthy board is
             never shut down by a glitch, at the price of reacting late:
               - OTP and UVLO pulses of 0.8 ms (assert needs 1 ms) do nothing;
               - OTP chattering 0.9 ms on / 0.05 ms off never asserts: the
                 disagreement counter restarts at every drop-out;
               - a 15 ms switch drop-out (the switch needs 20 ms) does nothing;
               - an asserted OTP that drops for 0.1 ms (release needs
                 0.2 ms) keeps the converter off.
             None of these is told to the model, so every check expects the
             board unchanged.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)

    for knob in ["OTP_trig", "UVLO_trig"]:
        await glitch_knob(dut, knob, 1, ms_clocks(0.8 * FAULT_ASSERT_MS))
        await wait_ms(dut, model, 0.5)
        await check(dut, model)

    for _ in range(4):
        await glitch_knob(dut, "OTP_trig", 1, ms_clocks(0.9 * FAULT_ASSERT_MS))
        await ClockCycles(dut.clk, ms_clocks(0.05))
    await wait_ms(dut, model, 0.5)
    await check(dut, model)

    await glitch_knob(dut, "en_from_switch", 0, ms_clocks(0.75 * SWITCH_DEBOUNCE_MS))
    await wait_ms(dut, model, 1)
    await check(dut, model)

    await set_knob(dut, model, "OTP_trig", 1)
    await wait_ms(dut, model, SETTLE_FAULT_MS)
    await check(dut, model)
    await glitch_knob(dut, "OTP_trig", 0, ms_clocks(0.5 * FAULT_RELEASE_MS))
    await wait_ms(dut, model, 0.5)
    await check(dut, model)
    await set_knob(dut, model, "OTP_trig", 0)
    await settle(dut, model, SETTLE_FAULT_MS)
    await check(dut, model)

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def modulator_stall(dut):

    """
    Purpose: Soft start, PGOOD and the clean-run window count switching
             cycles, not time. With the modulator stopped the converter is
             enabled into S_SS and waits there - En high, no gate pulse, no
             PGOOD - and finishes the ramp once the modulator runs. A
             modulator stuck HIGH in S_RUN gets one pulse cut at MAX_ON + 1,
             then no gate drive at all until it falls.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await configure_fast_timers(dut, model)

    dut.osc_on_clks.value = 0
    await set_knob(dut, model, "en_from_switch", 1)
    await wait_ms(dut, model, SETTLE_START_MS)
    status = await read_register(dut, ADDR_STATUS)
    assert status & 0x3 == S_SS, f"STATUS state {status & 0x3} with the modulator stopped, wanted S_SS"
    assert int(dut.En.value) == 1 and int(dut.PWM_out.value) == 0 and int(dut.PGOOD.value) == 0

    dut.osc_on_clks.value = OSC_ON_NOMINAL
    model.ramp_restarted()
    await settle(dut, model, 0.5)
    await check(dut, model)

    await FallingEdge(dut.Osc_in)
    await ClockCycles(dut.clk, 10)                        # inside the low phase
    dut.osc_on_clks.value = 255                           # above the period: always high
    width = await measure_pulse(dut, "PWM_out")
    assert width == MAX_ON_COUNTS + 1, f"stuck-high modulator gave a {width}-clock pulse"
    assert await edge_within(dut, "PWM_out", rising=True, timeout_ms=0.1) is None, \
        "PWM_out pulsed again while the modulator was stuck high"
    dut.osc_on_clks.value = OSC_ON_NOMINAL
    await ClockCycles(dut.clk, 300)
    await check(dut, model)

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def reset_mid_run(dut):

    """
    Purpose: The reset button while running with a strike outstanding: the
             power stage is off at once, the strike and every programmed
             timer are gone (the S_OFF-only registers read their reset
             values), and - the switch still on - the converter restarts by
             itself after the switch debounce, ramping at the reset rate.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)
    await trip_once(dut, model)
    await settle(dut, model, 0.5)
    await check(dut, model)

    await FallingEdge(dut.clk)
    dut.reset_button.value = 1
    await ClockCycles(dut.clk, 3)
    for pin in ["En", "PWM_out", "PGOOD", "latch_out"]:
        assert int(getattr(dut, pin).value) == 0, f"{pin} high 3 clocks into a reset"
    await press_reset_button(dut, model)

    assert await read_register(dut, ADDR_STRIKE_LEVEL) == 0
    assert await read_register(dut, ADDR_HICCUP, 3) == 250_000
    assert await read_register(dut, ADDR_CYC_PER_STEP) == DEFAULT_CYCLES_PER_STEP
    assert await read_register(dut, ADDR_CLEAN_RUN, 3) == 450_000
    await wait_ms(dut, model, 2 * FAULT_RELEASE_MS)       # the fail-safe fault flags release
    await check(dut, model)
    await settle(dut, model, 1)
    await check(dut, model)
    assert model.state() == S_RUN

    await check_sva(dut, failures_before)


@cocotb.test(skip=not TELEMETRY)
async def latched_and_faulted_while_off(dut):

    """
    Purpose: Faults that arrive before the converter ever starts. The analog
             OVP trips the SCR and OTP is raised with the switch off; turning
             the switch on starts nothing. The reset button drains the SCR
             but cannot clear a live over-temperature - the OTP flag comes
             out of reset asserted and stays so - and the converter starts
             only when OTP clears.
    """
    model = SupervisorModel()
    failures_before = await start(dut, model)
    await configure_fast_timers(dut, model)

    await pulse_knob(dut, "ovp_trip", 10)
    model.ovp_trip()
    await set_knob(dut, model, "OTP_trig", 1)
    await set_knob(dut, model, "en_from_switch", 1)
    await wait_ms(dut, model, SETTLE_START_MS)
    await check(dut, model)
    assert model.state() == S_OFF and model.scr == 1

    await press_reset_button(dut, model)
    await configure_fast_timers(dut, model)
    await wait_ms(dut, model, SETTLE_START_MS)
    await check(dut, model)
    assert model.state() == S_OFF and model.scr == 0

    await set_knob(dut, model, "OTP_trig", 0)
    await settle(dut, model, SETTLE_FAULT_MS)
    await check(dut, model)
    assert model.state() == S_RUN

    await check_sva(dut, failures_before)


# ==============================================================================
# Constrained-random
# ==============================================================================

# EVENT_WEIGHTS: how often random_walk draws each event, before eligibility
EVENT_WEIGHTS = {
    "switch": 2, "otp": 4, "uvlo": 4, "host": 4, "trip": 6, "persist": 2, "ovp": 1,
    "reset": 1, "rail": 3, "wait": 4, "thresholds": 3, "glitch": 3, "fault_in_hiccup": 3,
    "clean_run": 1,
}


@cocotb.test(skip=not TELEMETRY)
async def random_walk(dut):

    """
    Purpose: Constrained-random board history. From a settled S_RUN, draw
             RANDOM_EVENTS events; apply each to the board and the model
             together, wait its settle time, and compare every pin, STATUS
             and STRIKE_LEVEL (check()). Events:
               switch / otp / uvlo / host / rail - toggle that input
               trip            one overcurrent episode (also while off or
                               latched, where it must do nothing)
               persist         an overcurrent that never clears, to the latch
               ovp             the analog OVP trips the SCR
               reset           the reset button, then the fast timers again
               wait            1 to 12 ms of steady board
               thresholds      a live write of TRIP_RUN, TRIP_SS and
                               MAX_STRIKES - raw values, clamped by reg_file
               glitch          a sub-debounce disturbance the model is not
                               told about: the board must not change
               fault_in_hiccup a trip, then OTP, UVLO, a host disable, the
                               OVP or the reset button during the cool-down
               clean_run       run past the clean-run window: strikes clear
             persist, fault_in_hiccup and clean_run are drawn only while the
             converter runs (clean_run only with a strike outstanding); a
             latched converter draws reset more often, so the walk does not
             spend itself latched, and a stopped one favours the inputs
             holding it off. Before each event the walk steps clear of
             the clean-run boundary, so no outcome depends on a call the
             model cannot make. Covergroups (top_coverage.py) are sampled
             from the model's view of every event.
             Environment: RANDOM_EVENTS (default 12), RANDOM_CSV (one row per
             event), FCOV_XML (export the covergroups). Replay with the seed
             the log prints.
    """
    import csv
    import os
    import random
    import top_coverage as fcov

    RANDOM_EVENTS = int(os.environ.get("RANDOM_EVENTS", "12"))
    dut._log.info(f"random_walk: {RANDOM_EVENTS} events - to replay this exact run: "
                  f"make replay SEED={cocotb.RANDOM_SEED} EVENTS={RANDOM_EVENTS}")

    csv_path   = os.environ.get("RANDOM_CSV")
    csv_file   = open(csv_path, "w", newline="") if csv_path else None
    csv_writer = csv.writer(csv_file) if csv_file else None
    if csv_writer:
        csv_writer.writerow(["seed", "event", "kind", "note", "condition", "state", "strikes",
                             "max_strikes", "latched", "En", "PGOOD", "switch", "host_enable",
                             "otp", "uvlo", "rail_good", "sim_ms"])

    model = SupervisorModel()
    failures_before = await start(dut, model)
    await bring_up(dut, model, pgood=False)
    pgood_before = 0
    event_counts = {kind: 0 for kind in EVENT_WEIGHTS}

    def condition():
        if model.latched():
            return "latched"
        return "running" if model.state() == S_RUN else "off"

    def eligible():
        weights = dict(EVENT_WEIGHTS)
        if model.state() != S_RUN:
            for kind in ["persist", "fault_in_hiccup", "clean_run"]:
                weights[kind] = 0
        if not model.strikes:
            weights["clean_run"] = 0
        if model.latched():
            weights["reset"] = 8
        elif model.state() == S_OFF:
            # stopped but not latched: favour the inputs holding it off
            blockers = {"switch": not model.switch, "host": not model.host_enable,
                        "otp": model.otp, "uvlo": model.uvlo}
            for kind, blocking in blockers.items():
                if blocking:
                    weights[kind] *= 3
        return weights

    async def trip_and_sample(stop_from="run"):
        """One overcurrent episode with its coverage; returns the cool-down."""
        running = model.state() == S_RUN
        cool_down = await trip_once(dut, model)
        if running:
            fcov.sample_strike(model.strikes, model.max_strikes, model.latched())
            if model.latched():
                fcov.sample_stop("strike_latch", stop_from)
                fcov.sample_latch("strikes", "running")
            else:
                fcov.sample_recovery("hiccup_retry")
        return cool_down

    for event_number in range(1, RANDOM_EVENTS + 1):
        await wait_ms(dut, model, model.margin_to_certainty())
        weights = eligible()
        kind = random.choices(list(weights), weights=list(weights.values()))[0]
        event_counts[kind] += 1
        before = condition()
        fcov.sample_event(kind, before)
        was_running = model.state() == S_RUN
        note = ""

        if kind in ["switch", "otp", "uvlo"]:
            knob  = {"switch": "en_from_switch", "otp": "OTP_trig", "uvlo": "UVLO_trig"}[kind]
            value = 1 - int(getattr(dut, knob).value)
            await set_knob(dut, model, knob, value)
            note = f"{knob}={value}"
            await settle(dut, model, SETTLE_START_MS if kind == "switch" else SETTLE_FAULT_MS)
            if was_running and model.state() != S_RUN:
                fcov.sample_stop(kind, "run")
            if not was_running and model.state() == S_RUN:
                fcov.sample_recovery("switch_on" if kind == "switch" else "fault_cleared")

        elif kind == "host":
            if model.host_enable:
                await host_disable(dut, model)
                note = "disable"
            else:
                await host_enable(dut, model)
                note = "enable"
            await settle(dut, model, 0.5)
            if was_running and model.state() != S_RUN:
                fcov.sample_stop("host", "run")
            if not was_running and model.state() == S_RUN:
                fcov.sample_recovery("host_enable")

        elif kind == "trip":
            cool_down = await trip_and_sample()
            note = f"strikes={model.strikes} cool_down={cool_down}ms"
            await settle(dut, model, SETTLE_FAULT_MS if model.latched() else 0.5)

        elif kind == "persist":
            await set_knob(dut, model, "overcurrent", 1)
            strikes_before = model.strikes
            total = 0
            while model.allowed():
                total += await_free_trip(model)
                fcov.sample_strike(model.strikes, model.max_strikes, model.latched())
            fcov.sample_stop("strike_latch", "run")
            fcov.sample_latch("strikes", "running")
            note = f"strikes {strikes_before}->{model.strikes}"
            await wait_ms(dut, model, total + 0.5 * (model.strikes - strikes_before) + SETTLE_FAULT_MS)
            await set_knob(dut, model, "overcurrent", 0)

        elif kind == "ovp":
            await pulse_knob(dut, "ovp_trip", 10)
            model.ovp_trip()
            fcov.sample_latch("ovp", "running" if was_running else "off")
            if was_running:
                fcov.sample_stop("ovp", "run")
            await wait_ms(dut, model, SETTLE_FAULT_MS)

        elif kind == "reset":
            await press_reset_button(dut, model)
            await configure_fast_timers(dut, model)
            if was_running:
                fcov.sample_stop("reset", "run")
            await settle(dut, model, 1)
            if not was_running and model.state() == S_RUN:
                fcov.sample_recovery("reset_button")

        elif kind == "rail":
            value = 1 - model.pgood_comp
            await set_knob(dut, model, "PGOOD_comp", value)
            note = f"PGOOD_comp={value}"
            await wait_ms(dut, model, 0.2)

        elif kind == "wait":
            ms = round(random.uniform(1, 12), 2)
            note = f"{ms}ms"
            await wait_ms(dut, model, ms)

        elif kind == "thresholds":
            trip_run    = random.choice([0, 1, random.randint(2, 15), 16, 17, 255])
            trip_ss     = random.choice([0, 1, random.randint(2, 31), 32, 33, 255])
            max_strikes = random.choice([0, 1, 2, 3, 4, 255])
            await write_live_thresholds(dut, trip_run=trip_run, trip_ss=trip_ss,
                                        max_strikes=max_strikes)
            model.set_max_strikes(max_strikes)
            note = f"trip_run={trip_run} trip_ss={trip_ss} max_strikes={max_strikes}"
            await wait_ms(dut, model, 0.1)

        elif kind == "glitch":
            glitch = random.choice(["otp", "uvlo", "switch"])
            if glitch == "switch":
                knob, level = "en_from_switch", 1 - model.switch
                clocks, name = ms_clocks(0.75 * SWITCH_DEBOUNCE_MS), "switch_blip"
            else:
                knob = "OTP_trig" if glitch == "otp" else "UVLO_trig"
                level = 1 - getattr(model, glitch)
                if level:
                    clocks, name = ms_clocks(0.8 * FAULT_ASSERT_MS), f"{glitch}_pulse"
                else:
                    clocks, name = ms_clocks(0.5 * FAULT_RELEASE_MS), f"{glitch}_dropout"
            await glitch_knob(dut, knob, level, clocks)
            fcov.sample_glitch(name)
            note = name
            await wait_ms(dut, model, 0.5)

        elif kind == "fault_in_hiccup":
            stop = random.choice(["otp", "uvlo", "host", "ovp", "reset"])
            note = f"trip then {stop}"
            await FallingEdge(dut.clk)
            dut.overcurrent.value = 1
            model.overcurrent_trip()
            fcov.sample_strike(model.strikes, model.max_strikes, model.latched())
            latched_by_trip = model.latched()
            if latched_by_trip:
                fcov.sample_stop("strike_latch", "run")
                fcov.sample_latch("strikes", "running")
            await ClockCycles(dut.clk, 5_000)
            await FallingEdge(dut.clk)
            dut.overcurrent.value = 0
            in_hiccup = not latched_by_trip
            if stop in ["otp", "uvlo"]:
                await set_knob(dut, model, "OTP_trig" if stop == "otp" else "UVLO_trig", 1)
            elif stop == "host":
                await host_disable(dut, model)
            elif stop == "ovp":
                await pulse_knob(dut, "ovp_trip", 10)
                model.ovp_trip()
                fcov.sample_latch("ovp", "running" if in_hiccup else "off")
            else:
                await press_reset_button(dut, model)
                await configure_fast_timers(dut, model)
            if in_hiccup:
                fcov.sample_stop(stop, "hiccup")
            await settle(dut, model, SETTLE_FAULT_MS + 0.5)

        elif kind == "clean_run":
            wanted = model.run_entry + model.clean_run_ms + 1 - model.clock()
            note = f"{wanted:.1f}ms"
            await wait_ms(dut, model, max(wanted, 1))
            fcov.sample_recovery("strikes_forgotten")

        expected = await check(dut, model)

        pgood_now = expected["PGOOD"]
        if pgood_now is not None:
            if pgood_now and not pgood_before:
                fcov.sample_pgood("qualified")
            elif pgood_before and not pgood_now:
                fcov.sample_pgood("rail_drop" if model.state() == S_RUN else "left_run")
            pgood_before = pgood_now

        if csv_writer:
            csv_writer.writerow([cocotb.RANDOM_SEED, event_number, kind, note, before,
                                 expected["state"], model.strikes, model.max_strikes,
                                 int(model.latched()), expected["En"], pgood_now, model.switch,
                                 model.host_enable, model.otp, model.uvlo, model.pgood_comp,
                                 round(model.clock(), 3)])
            csv_file.flush()      # keep every row even if a later event fails the test
        dut._log.info(f"event {event_number}: {kind} {note} -> {condition()}, strikes {model.strikes}")

    dut._log.info(f"random_walk: events drawn per kind: {event_counts}")
    if csv_file:
        csv_file.close()
    fcov.report_coverage(dut._log, os.environ.get("FCOV_XML"))
    await check_sva(dut, failures_before)


def await_free_trip(model):

    """
    Purpose: One trip of a persistent overcurrent, in the model only (the
             board's overcurrent is simply held): the cool-down it costs, plus
             the retry's ramp and the soft-start window filling.
    """
    cool_down = model.overcurrent_trip()
    return cool_down + (model.ramp_ms() if cool_down else 0)
