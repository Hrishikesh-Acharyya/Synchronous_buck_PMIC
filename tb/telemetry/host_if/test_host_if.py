#
# Filename:         test_host_if.py
#
# File Description: Cocotb testbench for host interface modules(spi_slave + reg_file).
#                    The test acts as the master (the host MCU)
#
# Global variables: CLK_PERIOD_NS, RESET_CLKS, IDLE_CLKS, STATUS_INPUTS, S_IDLE
#                   S_CMD, S_WRITE, S_TURN, S_READ, S_DEAD, READ_FLAG, ADDR_PMIC_ID
#                   PMIC_ID, VERSION_ID, SCK_HALF_PERIOD_NS, CRC8_POLY, WRITE_MASK
#                   ADDR_BUS_ERR_L, ADDR_BUS_ERR_H

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, FallingEdge
import cocotb
from cocotb.triggers import ClockCycles
from host_if_constants import (S_IDLE, READ_FLAG, ADDR_PMIC_ID, PMIC_ID, VERSION_ID,
                               ADDR_SCRATCH, ADDR_BUS_ERR_L, ADDR_TRIP_RUN, IDLE_CLKS)
from tb_utils import start_test, check_sva, reset
from spi_driver import spi_transfer, spi_write, spi_read, crc8
from reg_file_model import THRESHOLD_DEFAULTS, THRESHOLD_BIODATA, clamp, RegfileModel
from scoreboard import read_thresholds, scoreboard_check


@cocotb.test()
async def idle_bus_after_reset(dut): 

    """
    Purpose: This check tests if the bus is idle after reset
    """

    failures_before = await start_test(dut)

    await ClockCycles(dut.clk, IDLE_CLKS)

    miso_level = int(dut.MISO.value)
    assert miso_level == 0, f"MISO = {miso_level} on an idle bus, expected 0"

    dut_state = int(dut.u_spi_slave.spi_state.value)
    assert dut_state == S_IDLE, f"SPI state = {dut_state} on an idle bus, expected {S_IDLE}"
    
    await check_sva(dut, failures_before)



@cocotb.test()
async def read_identity_register(dut): 

    """
    Purpose: Reads PMIC_ID and VERSION in one burst, proving the read path
             is robust. Tha values are fixed by reh file's parameters
    """
    
    failures_before = await start_test(dut)

    command_byte = READ_FLAG|ADDR_PMIC_ID

    read_frame = [command_byte, 0x00, 0x00,0x00]
    result = await spi_transfer(dut, read_frame)
    # We wait after the spi_transfer return to allow the end sequence(Cs_n rising) 
    # to pass through the filters and read by the checkers, so the end of read assertions
    # and covers are exercise. IDLE_CLKS is enough time for that to happenac
    await ClockCycles(dut.clk, IDLE_CLKS)

    assert result[0] == 0x00, f"Command byte answer should be 0x00, read {result[0]:#04x}"
    assert result[1] == 0x00, f"Turnaround byte answer should be 0x00, read {result[1]:#04x}"
    assert result[2] == PMIC_ID, f"PMIC_ID value read as {result[2]:#04x}, should be {PMIC_ID:#04x}"
    assert result[3] == VERSION_ID, f"VERSION_ID value read as {result[3]:#04x}, should be {VERSION_ID:#04x}"

    await check_sva(dut, failures_before)

    
@cocotb.test()
async def crc8_model_check(dut):

    """
    Purpose: This test checks the CRC model itself against the published 
             CRC-8/SMBUS check value, and the zero-remainder property spi_slave relies on. 
             It doesn't use the DUT
    """

    # Send the message 123456789
    send_message = list(range(0x31,0x3A))
    crc = crc8(send_message)
    assert crc==0xF4, f"The crc value received for 123456789 is {crc:#04x}, whereas it should be 0xF4"
    
    # Add the crc byte to the original message and resend new message
    appended_message = send_message + [crc]
    # CRC of the message + the crc itself should be zero
    crc_zero = crc8(appended_message)
    assert crc_zero == 0, f"The crc value of the message + its crc is {crc_zero:#04x}, it should be 0"
    
@cocotb.test()
async def write_scratch_read_back(dut):
    """
    Purpose: Writes a scratch data to ADDR_SCRATCH and reads it back
             Reading the correct data back means command, data, CRC, integrity_OK
             and reg_file data storing operation are correct
    """

    failures_before = await start_test(dut)

    scratch_value = 0x5A
    
    await spi_write(dut, ADDR_SCRATCH, [scratch_value])

    read_data = await spi_read (dut, ADDR_SCRATCH, 1)

    assert read_data[0] == scratch_value, f"Data sent was {scratch_value:#04x}, received is: {read_data[0]:#04x}"

    # We wait after the spi_transfer return to allow the end sequence(Cs_n rising) 
    # to pass through the filters and read by the checkers, so the end of read assertions
    # and covers are exercise. IDLE_CLKS is enough time for that to happenac
    await ClockCycles(dut.clk, IDLE_CLKS)
    await check_sva(dut, failures_before)

    
@cocotb.test()
async def bad_crc_write_rejected(dut):
    """
    Purpose: A bad-CRC byte is sent to reg_file. CRC error is detected,
             the data is discarded (SCRATCH keeps its old value), and the error is counted exactly once.
    """

    failures_before = await start_test(dut)

    scratch_value = 0x5A
    bad_value = 0xA5

    bus_error_count_intial_list = await spi_read(dut, ADDR_BUS_ERR_L, 2)
   
    await spi_write(dut, ADDR_SCRATCH, [scratch_value])
    good_read_data = await spi_read (dut, ADDR_SCRATCH, 1)
    assert good_read_data[0] == scratch_value, f"Read returned {good_read_data[0]:#04x} on writing {scratch_value:#04x} even with good crc"
    
    
    await spi_write(dut, ADDR_SCRATCH, [bad_value], corrupt_crc=True)
    bad_read_data = await spi_read(dut, ADDR_SCRATCH, 1)
    assert bad_read_data[0] == scratch_value, f"Sent bad data {bad_value:#04x}, reg_file allowed it to be written"


    bus_error_count_final_list = await spi_read(dut, ADDR_BUS_ERR_L, 2)
    await ClockCycles(dut.clk, IDLE_CLKS)  

    errors_before = (bus_error_count_intial_list[1] << 8) | bus_error_count_intial_list[0]
    errors_after  = (bus_error_count_final_list[1] << 8) | bus_error_count_final_list[0] 
    assert errors_after - errors_before == 1, f"The bus_error rose by {int(errors_after-errors_before)}, after sending one bad-CRC byte"

    await check_sva(dut, failures_before)

@cocotb.test()
async def thresholds_reset_defaults(dut):
    """
    Purpose: Resets the dut and reads the registers at address
             0x50-0x6F (writable thresholds) to see if they defaulted
             to their reset values
    """

    failures_before = await start_test(dut)
    read_back = await read_thresholds(dut)

    for name, expected in THRESHOLD_DEFAULTS.items():
        actual = read_back[name]
        assert actual == expected, f"{name}: read {actual}, expected{expected}"

    await check_sva(dut,failures_before)
    
@cocotb.test()
async def clamp_model_check(dut):
    """
    Purpose: Checks the clamp model against values worked out by hand from
             pmic_types_pkg, independent of THRESHOLD_BIODATA - so a wrong
             entry in the table fails here. Covers below, inside, at and above
             a bound, a minimum other than 1, and the largest raw value each
             register width can carry (0xFF, 0xFFFFFF). Does not use the DUT.
    """

    # (register, raw value written, expected value after clamp)
    # Every register: below its minimum, inside the range, above its maximum.
    # Raw values are ones the bus can carry: 0..0xFF for 1-byte registers,
    # 0..0xFFFFFF for the 3-byte ones. Expected values worked out by hand from
    # pmic_types_pkg - never read from THRESHOLD_BIODATA.

    clamp_cases = [
        ("trip_run",         0,        1),
        ("trip_run",         10,       10),
        ("trip_run",         0xFF,     16),        # WINDOW_RUN

        ("trip_ss",          0,        1),
        ("trip_ss",          20,       20),
        ("trip_ss",          0xFF,     32),        # WINDOW_SS

        ("max_strikes",      0,        1),
        ("max_strikes",      2,        2),
        ("max_strikes",      0xFF,     3),         # MAX_STRIKES_DEFAULT: downward only

        ("max_on_limit",     5,        12),        # MIN_ON_COUNTS: 240 ns -> 12 clks
        ("max_on_limit",     50,       50),
        ("max_on_limit",     83,       83),        # exactly at the ceiling
        ("max_on_limit",     0xFF,     83),        # MAX_ON_COUNTS_DEFAULT: downward only

        ("hiccup_base",      0,        50000),     # 1 ms
        ("hiccup_base",      250000,   250000),    # the 5 ms default
        ("hiccup_base",      0xFFFFFF, 1000000),   # 20 ms

        ("cycles_per_step",  0,        1),
        ("cycles_per_step",  16,       16),
        ("cycles_per_step",  0xFF,     64),        # CYCLES_PER_STEP_MAX

        ("clean_run_target", 1,        45000),     # 100 ms of 450 kHz cycles
        ("clean_run_target", 450000,   450000),    # the 1 s default
        ("clean_run_target", 0xFFFFFF, 524287),    # 2^19 - 1, the 19-bit width
    ]

    for name, raw_value, expected in clamp_cases:
        result = clamp(name, raw_value)
        assert result == expected, f"clamp({name}, {raw_value}) gave {result}, expected {expected}"
        


@cocotb.test()
async def scratch_through_model(dut):

    """
    Purpose: Drives SCRATCH and the bus-error counter through the register
             model - one good write, one bad-CRC write - and compares the DUT
             against the model's prediction. No expected value is typed in:
             the test states what it did, the model states what should have
             happened, and the DUT is checked against the model.
    """

    failures_before = await start_test(dut)

    # The model starts at reset, matching the DUT start_test just reset.
    model = RegfileModel()

    # good_value / bad_value: differ from each other and from SCRATCH's reset
    # value 0x00, so neither a rejected write nor a stuck register can pass
    good_value = 0x5A
    bad_value  = 0xA5

    # Good write: do it on the bus, then tell the model the same thing.
    await spi_write(dut, ADDR_SCRATCH, [good_value])
    model.apply_write(ADDR_SCRATCH, [good_value])

    # Bad-CRC write: the DUT must discard it; the model predicts that too.
    await spi_write(dut, ADDR_SCRATCH, [bad_value], corrupt_crc=True)
    model.apply_write(ADDR_SCRATCH, [bad_value], crc_ok=False)

    # Compare the bus-error counter: two bytes, low first, read in one burst.
    # Also checks the scratch read
    await scoreboard_check(dut, model)

    await check_sva(dut, failures_before)
    

    
    

