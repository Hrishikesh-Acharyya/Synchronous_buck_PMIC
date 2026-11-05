#
# Filename:         test_host_if.py
#
# File Description: Cocotb testbench for host interface modules(spi_slave + reg_file).
#                    The test acts as the master (the host MCU)
#
# Global variables: CLK_PERIOD_NS, RESET_CLKS, IDLE_CLKS, STATUS_INPUTS, S_IDLE
#                   S_CMD, S_WRITE, S_TURN, S_READ, S_DEAD

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer

# CLK_PERIOD_NS: Time period of clock. Taken 50MHz clock as in pmic_types_pkg
CLK_PERIOD_NS = 20
# RESET_CLKS: How many clocks reset is held low
RESET_CLKS = 5
# IDLE_CLKS: IDLE_CLKS is how long the test watches an idle
# bus after reset, to make sure nothing happens
# Greater than the time taken for syncing and debouncing the signals (2+8 = 10 clks)
IDLE_CLKS = 100

# SPI_S_XXX: Encoding of the SPI_slave's FSM, derived from spi_slave.sv rtl file
S_IDLE = 0
S_CMD      = 1    
S_WRITE    = 2    
S_TURN     = 3    
S_READ     = 4   
S_DEAD     = 5 

# STATUS_INPUTS: Reg file status inputs driven here
STATUS_INPUTS = ["CP_sync", "OTP_sync_db", "UVLO_sync_db", "latch_stat_sync_db",
                  "en_from_switch_sync_db", "en_switch_rise", "strike_level", "duty_count",
                  "prev_period", "timestamp_ms", "fault_time", "sup_state", "fault_count_run",
                  "fault_count_ss", "fault_reg", "PGOOD"]

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


@cocotb.test()
async def idle_bus_after_reset(dut): 

    """
    Purpose: This check tests if the bus is idle after reset
    """
    
    initiate_clock(dut)
    set_inputs_idle(dut)
    await reset(dut)
    await ClockCycles(dut.clk, IDLE_CLKS)

    miso_level = int(dut.MISO.value)
    assert miso_level == 0, f"MISO = {miso_level} on an idle bus, expected 0"

    dut_state = int(dut.u_spi_slave.spi_state.value)
    assert dut_state == S_IDLE, f"SPI state = {dut_state} on an idle bus, expected {S_IDLE}"
    
    assertion_fail_count = int(dut.sva_fail_count.value)
    assert assertion_fail_count == 0, f"{assertion_fail_count} no. of assertions failed"
