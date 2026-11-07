import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer
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

async def check_sva(dut, failures_before):

    await ClockCycles(dut.clk, IDLE_CLKS)

    assertion_fail_count = int(dut.sva_fail_count.value)
    assert assertion_fail_count == failures_before, f"{assertion_fail_count - failures_before} SVA failure(s) during this test"
    
    