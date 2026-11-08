import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, FallingEdge
from host_if_constants import CLK_PERIOD_NS, RESET_CLKS, IDLE_CLKS, STATUS_INPUTS

def initiate_clock(dut):
    
    """
    Purpose: Similar to the initial clock toggling block
             Create a clock with the required parameters and start toggling it
    """
    clock = Clock(dut.clk, CLK_PERIOD_NS, units="ns")
    cocotb.start_soon(clock.start(start_high=False))

def set_inputs_idle(dut): 
    
    """
    Purpose: Set all signals to idle level
    """
    dut.CS_n.value = 1
    dut.SCK.value = 0
    dut.MOSI.value = 0

    for signal in STATUS_INPUTS: 
      getattr(dut, signal).value = 0

async def reset(dut):

    """
    Purpose: Reset the dut for RESET_CLKS clocks
    """
    dut.rst_n.value = 1
    await Timer(1, units="ns")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, RESET_CLKS)
    dut.rst_n.value = 1

async def start_test(dut):
    
    failures_before = int(dut.sva_fail_count.value)
     
    initiate_clock(dut)
    set_inputs_idle(dut)
    await reset(dut)

    return failures_before

async def check_sva(dut, failures_before, expected_failures=0):

    """
    Purpose: Settle, then assert this test caused exactly expected_failures
             SVA failures. Normally zero; a test that deliberately forces DUT
             state (a deposit) breaks a "moves only when..." property exactly
             once and says so here.
    """
    await ClockCycles(dut.clk, IDLE_CLKS)
    new_failures = int(dut.sva_fail_count.value) - failures_before
    assert new_failures == expected_failures, \
        f"{new_failures} SVA failure(s) during this test, expected {expected_failures}"

def set_sup_state(dut, model, state):

    """
    Purpose: Drive sup_state into the DUT and tell the model the same thing,
             so the two never disagree about the supervisor state.
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
             the rising edge it is sampled; two clocks let a release take
             effect before anything reads the result.
    """
    await FallingEdge(dut.clk)
    dut.timestamp_ms.value = new_timestamp_ms & 0xFFFFFF
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



    
    