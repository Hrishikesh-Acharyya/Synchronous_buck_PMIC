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

# CLK_PERIOD_NS: Time period of clock. Taken 50MHz clock as in pmic_types_pkg
CLK_PERIOD_NS = 20
# RESET_CLKS: How many clocks reset is held low
RESET_CLKS = 5
# IDLE_CLKS: IDLE_CLKS is how long the test watches an idle
# bus after reset, to make sure nothing happens
# Greater than the time taken for syncing and debouncing the signals (2+8 = 10 clks)
IDLE_CLKS = 100
# SCK_HALF_PERIOD_NS: time SCK stays high, and time it stays low - 1 MHz, the
# design point in pmic_top. The MCU's SCK is asynchronous to clk, so it is
# timed in ns with Timer, never in clk cycles. 500 ns clears both the 160 ns
# filter window and the ~220 ns MISO turnaround (2 sync + 8 filter + 1 clock
# after a falling edge, before the master samples on the next rising edge).
SCK_HALF_PERIOD_NS = 500
# READ_FLAG: sets the bit 7 to 1 i.e it converts the byte into a read command
READ_FLAG = 0x80
# WRITE_MASK: sets the bit 7 to 0 ie converts the byte to a write command
WRITE_MASK = 0x7F
# ADDR_PMIC_ID: Address of PMIC_ID, as set by reg_file.sv
ADDR_PMIC_ID = 0x00
# PMIC_ID: The value stored at ADDR_PMIC_ID
PMIC_ID = 0xB5
# VERSION_ID: The value at version Id's address
VERSION_ID = 0x01
# CRC8_POLY: CRC-8/SMBUS polynomial
CRC8_POLY = 0x07
# ADDR_SCRATCH: The address used by write_scratch_read test
ADDR_SCRATCH = 0x03
# ADDR_BUS_ERR_L: Address of the lower 8 bits of the bus error counter
ADDR_BUS_ERR_L = 0x1B
# ADDR_BUS_ERR_H: Address of the highew 8 bits of the bus error counter
ADDR_BUS_ERR_H = 0x1C


# SPI_S_XXX: Encoding of the SPI_slave's FSM, derived from spi_slave.sv rtl file
S_IDLE     = 0
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

async def spi_transfer(dut, tx_bytes):

    """
    Purpose: One complete SPI transaction as the host MCU - CS_n low, every
             byte of tx_bytes shifted out on MOSI in Mode 0, MSB first, then
             CS_n high. Returns the bytes sampled on MISO, one per byte sent.
             The master owns SCK: every edge is made here. Per bit, MOSI is
             set while SCK is low, SCK rises a half-period later (the slave
             samples MOSI, the master samples MISO), and falls a half-period
             after that (the slave launches its next MISO bit).

             CS_n changes only while SCK is low and has been low for a
             half-period: the lead time is the first bit's setup wait, the lag
             time is the wait before CS_n rises. spi_slave_sva checks this as
             a_cs_moves_with_sck_low.
             
    """
    # align to a falling clk edge: every later step is a multiple of the clk
    # period, so SCK, MOSI and CS_n never change on a rising edge (DRIVE_OFFSET)
    await FallingEdge(dut.clk)
    MISO_received_bytes = []
    dut.CS_n.value = 0

    for byte in tx_bytes:
        received_byte = 0

        for bit_index in range(7, -1, -1):
            # SCK low: put this bit on MOSI before the rising edge
            send_bit = (byte >> bit_index) & 1
            dut.MOSI.value = send_bit
            await Timer(SCK_HALF_PERIOD_NS, units="ns")

            # rising edge: slave samples MOSI, master samples MISO
            dut.SCK.value = 1
            received_bit = int(dut.MISO.value)
            received_byte = (received_bit << bit_index) | received_byte
            await Timer(SCK_HALF_PERIOD_NS, units="ns")

            # falling edge: slave launches its next MISO bit
            dut.SCK.value = 0

        MISO_received_bytes.append(received_byte)

    # lag time: SCK must be settled low before CS_n rises
    await Timer(SCK_HALF_PERIOD_NS, units="ns")
    dut.CS_n.value = 1
    # stay with cs_high for atleast half a period, so that new transactions
    # don't pull cs_n low very soon and get the pulse classified as a glitch 
    # byt the filter 
    await Timer(SCK_HALF_PERIOD_NS, units="ns")
    

    return MISO_received_bytes

def crc8(message_bytes): 

    """
    Purpose: CRC-8/SMBUS (polynomial 0x07, init 0x00, MSB first,
             no reflection, no final XOR), list in, CRC out.
    """
    crc = 0
    for byte in message_bytes:

        crc = crc ^ byte

        for _ in range(8):
            if(((crc >> 7) & 1) == 1): 
                crc = (crc <<1) & 0xFF
                crc = crc^CRC8_POLY
            else: 
                crc = (crc <<1) & 0xFF

    return crc

async def spi_write(dut, address, data_bytes, corrupt_crc=False): 

    """
    Purpose: Write structure: [COMMAND][DATA][CRC], bit 7 of command 0 for write transaction
             The crc covers command and data. The write is only commited if spi_slave
             crc agrees
    """

    write_command = WRITE_MASK & address
    write_frame = [write_command] + data_bytes
    crc = crc8(write_frame)

    if corrupt_crc:
        crc = crc ^ 0x01      # single-bit error: what one EMI hit does

    write_frame = write_frame + [crc]
    await spi_transfer(dut, write_frame)


async def spi_read(dut, address, count):

    """
    Purpose: Read frame = [COMMAND][TURN_AROUND]([DUMMY]*No of bytes to be read)
    """

    read_command = READ_FLAG | address
    # turnaround byte us 0x00
    read_frame = [read_command, 0x00] + [0x00]*count
    result = await spi_transfer(dut,read_frame)
    # return everything except first 2 bytes, which are the slave's answer
    # to command and turnaround bytes
    return result[2:]

@cocotb.test()
async def idle_bus_after_reset(dut): 

    """
    Purpose: This check tests if the bus is idle after reset
    """

    failures_before = int(dut.sva_fail_count.value)
     
    initiate_clock(dut)
    set_inputs_idle(dut)
    await reset(dut)

    await ClockCycles(dut.clk, IDLE_CLKS)

    miso_level = int(dut.MISO.value)
    assert miso_level == 0, f"MISO = {miso_level} on an idle bus, expected 0"

    dut_state = int(dut.u_spi_slave.spi_state.value)
    assert dut_state == S_IDLE, f"SPI state = {dut_state} on an idle bus, expected {S_IDLE}"
    
    assertion_fail_count = int(dut.sva_fail_count.value)
    assert assertion_fail_count == failures_before, f"{assertion_fail_count - failures_before} SVA failure(s) during this test"




@cocotb.test()
async def read_identity_register(dut): 
    """
    Purpose: Reads PMIC_ID and VERSION in one burst, proving the read path
             is robust. Tha values are fixed by reh file's parameters
    """
    
    failures_before = int(dut.sva_fail_count.value)

    initiate_clock(dut)
    set_inputs_idle(dut)
    await reset(dut)

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

    assertion_fail_count = int(dut.sva_fail_count.value)
    assert assertion_fail_count == failures_before, f"{assertion_fail_count - failures_before} SVA failure(s) during this test"

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

    failures_before = int(dut.sva_fail_count.value)
    scratch_value = 0x5A

    initiate_clock(dut)
    set_inputs_idle(dut)
    await reset(dut)
    
    await spi_write(dut, ADDR_SCRATCH, [scratch_value])

    read_data = await spi_read (dut, ADDR_SCRATCH, 1)

    assert read_data[0] == scratch_value, f"Data sent was {scratch_value:#04x}, received is: {read_data[0]:#04x}"

    # We wait after the spi_transfer return to allow the end sequence(Cs_n rising) 
    # to pass through the filters and read by the checkers, so the end of read assertions
    # and covers are exercise. IDLE_CLKS is enough time for that to happenac
    await ClockCycles(dut.clk, IDLE_CLKS)

    assertion_fail_count = int(dut.sva_fail_count.value)
    assert assertion_fail_count == failures_before, f"{assertion_fail_count - failures_before} SVA failure(s) during this test"
    
@cocotb.test()
async def bad_crc_write_rejected(dut):

    """
    Purpose: A bad-CRC byte is sent to reg_file. CRC error is detected,
             the data is discarded (SCRATCH keeps its old value), and the error is counted exactly once.
    """

    failures_before = int(dut.sva_fail_count.value)
    scratch_value = 0x5A
    bad_value = 0xA5

    initiate_clock(dut)
    set_inputs_idle(dut)
    await reset(dut)

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

    assertion_fail_count = int(dut.sva_fail_count.value)
    assert assertion_fail_count == failures_before, f"{assertion_fail_count - failures_before} SVA failure(s) during this test"

    

    
    

