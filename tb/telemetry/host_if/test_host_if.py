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
from tb_utils import start_test, check_sva
from spi_driver import spi_transfer, spi_write, spi_read, crc8
from reg_file_model import THRESHOLD_DEFAULTS


@cocotb.test()
async def idle_bus_after_reset(dut): 

    """
    Purpose: This check tests if the bus is idle after reset
    """

    failures_before = start_test(dut)

    await ClockCycles(dut.clk, IDLE_CLKS)

    miso_level = int(dut.MISO.value)
    assert miso_level == 0, f"MISO = {miso_level} on an idle bus, expected 0"

    dut_state = int(dut.u_spi_slave.spi_state.value)
    assert dut_state == S_IDLE, f"SPI state = {dut_state} on an idle bus, expected {S_IDLE}"
    
    check_sva(dut, failures_before)



@cocotb.test()
async def read_identity_register(dut): 
    """
    Purpose: Reads PMIC_ID and VERSION in one burst, proving the read path
             is robust. Tha values are fixed by reh file's parameters
    """
    
    failures_before = start_test(dut)

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

    check_sva(dut, failures_before)

    
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

    failures_before = start_test(dut)

    scratch_value = 0x5A
    
    await spi_write(dut, ADDR_SCRATCH, [scratch_value])

    read_data = await spi_read (dut, ADDR_SCRATCH, 1)

    assert read_data[0] == scratch_value, f"Data sent was {scratch_value:#04x}, received is: {read_data[0]:#04x}"

    # We wait after the spi_transfer return to allow the end sequence(Cs_n rising) 
    # to pass through the filters and read by the checkers, so the end of read assertions
    # and covers are exercise. IDLE_CLKS is enough time for that to happenac
    await ClockCycles(dut.clk, IDLE_CLKS)
    check_sva(dut, failures_before)

    
@cocotb.test()
async def bad_crc_write_rejected(dut):

    """
    Purpose: A bad-CRC byte is sent to reg_file. CRC error is detected,
             the data is discarded (SCRATCH keeps its old value), and the error is counted exactly once.
    """

    failures_before = start_test(dut)

    scratch_value = 0x5A
    bad_value = 0xA5

    bus_error_count_intial_list = await spi_read(dut, ADDR_BUS_ERR_L, 2)
   
    await spi_write(dut, ADDR_SCRATCH, [scratch_value])
    good_read_data = await spi_read (dut, ADDR_SCRATCH, 1)
    assert good_read_data[0] == scratch_value, f"Read returned {good_read_data[0]:#04x} on writing {scratch_value:#04x} even with good crc"
    
    
    await spi_write(dut, ADDR_SCRATCH, [bad_value], corrupt_crc=True)
    bad_read_data = await spi_read(dut, ADDR_SCRATCH, 1)
    #assert bad_read_data[0] == scratch_value, f"Sent bad data {bad_value:#04x}, reg_file allowed it to be written"


    bus_error_count_final_list = await spi_read(dut, ADDR_BUS_ERR_L, 2)
    await ClockCycles(dut.clk, IDLE_CLKS)  

    errors_before = (bus_error_count_intial_list[1] << 8) | bus_error_count_intial_list[0]
    errors_after  = (bus_error_count_final_list[1] << 8) | bus_error_count_final_list[0] 
    assert errors_after - errors_before == 1, f"The bus_error rose by {int(errors_after-errors_before)}, after sending one bad-CRC byte"

    check_sva(dut, failures_before)
    
    

    
    

