#
# Filename:         tb_utils.py
#
# File Description: Bring-up and stimulus helpers shared by every test: the
#                   clock, idle levels, reset, the SVA verdict, and drivers for
#                   the reg_file inputs that cocotb drives in place of the rest
#                   of the chip. Every helper that changes DUT state also
#                   updates the reference model, so the two cannot disagree.
#
# Global variables: None

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, FallingEdge
from host_if_constants import CLK_PERIOD_NS, RESET_CLKS, IDLE_CLKS, STATUS_INPUTS, TIMESTAMP_MASK


def initiate_clock(dut):

    """
    Purpose: Start the supervisor clock, CLK_PERIOD_NS, beginning low.
    """
    clock = Clock(dut.clk, CLK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start(start_high=False))


def set_inputs_idle(dut):

    """
    Purpose: Drive every input to its idle level: CS_n high, SCK and MOSI low
             (SPI Mode 0 idle), and every reg_file status input at 0.
    """
    dut.CS_n.value = 1
    dut.SCK.value = 0
    dut.MOSI.value = 0

    for signal in STATUS_INPUTS:
        getattr(dut, signal).value = 0


async def reset(dut):

    """
    Purpose: Pulse rst_n low for RESET_CLKS clocks, with a genuine falling
             edge first so the asynchronous clears fire before any clock.
    """
    dut.rst_n.value = 1
    await Timer(1, units="ns")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, RESET_CLKS)
    dut.rst_n.value = 1


async def start_test(dut):

    """
    Purpose: Common start of every test: record the SVA failure count so far
             (all tests share one simulation), start the clock, drive the
             inputs idle and reset the DUT. Returns the recorded count for
             check_sva.
    """
    failures_before = int(dut.sva_fail_count.value)

    initiate_clock(dut)
    set_inputs_idle(dut)
    await reset(dut)

    return failures_before


async def check_sva(dut, failures_before, expected_failures=0):

    """
    Purpose: Settle, then assert that this test caused exactly
             expected_failures SVA failures - normally zero. A test that
             deliberately forces DUT state can declare the failures it
             expects.
    """
    await ClockCycles(dut.clk, IDLE_CLKS)
    new_failures = int(dut.sva_fail_count.value) - failures_before
    assert new_failures == expected_failures, \
        f"{new_failures} SVA failure(s) during this test, expected {expected_failures}"


def set_sup_state(dut, model, state):

    """
    Purpose: Drive sup_state into the DUT and the model together.
    """
    dut.sup_state.value = state
    model.sup_state = state


async def pulse_switch_rise(dut, model):

    """
    Purpose: Drive a one-clock en_switch_rise pulse, as the debounced enable
             switch produces, and tell the model. Driven on falling edges so
             the pulse never changes on the rising edge reg_file samples.
    """
    await FallingEdge(dut.clk)
    dut.en_switch_rise.value = 1
    await FallingEdge(dut.clk)
    dut.en_switch_rise.value = 0
    model.switch_rise()


async def set_timestamp(dut, model, new_timestamp_ms):

    """
    Purpose: Move timestamp_ms in the DUT and the model together. Driven on a
             falling edge so the watchdog comparison never sees it change on
             the rising edge it is sampled; two clocks let a watchdog release
             take effect before anything reads the result.
    """
    await FallingEdge(dut.clk)
    dut.timestamp_ms.value = new_timestamp_ms & TIMESTAMP_MASK
    await ClockCycles(dut.clk, 2)
    model.advance_time(new_timestamp_ms)


def set_status_input(dut, model, port_name, value):

    """
    Purpose: Drive one reg_file status input and tell the model. These are
             plain levels read by reg_file's read mux; nothing samples them
             on a clock edge, so no phase alignment is needed.
    """
    getattr(dut, port_name).value = value
    model.status_inputs[port_name] = value
