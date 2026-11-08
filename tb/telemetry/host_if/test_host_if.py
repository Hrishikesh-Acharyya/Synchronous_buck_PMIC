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
from cocotb.triggers import ClockCycles, Timer, FallingEdge, RisingEdge
import cocotb
from host_if_constants import (S_IDLE, READ_FLAG, ADDR_PMIC_ID, PMIC_ID, VERSION_ID,
                               ADDR_SCRATCH, ADDR_BUS_ERR_L, ADDR_TRIP_RUN, IDLE_CLKS,
                               ADDR_WRITE_KEY, SUP_S_OFF, WRITE_KEY, SUP_S_RUN, ADDR_CONTROL,
                               ADDR_DISABLE_KEY, DISABLE_KEY, WD_TIMEOUT_MS, TIMESTAMP_MASK,
                               ADDR_TIME_0, ADDR_FAULT_CAUSE, ADDR_FTIME_2, TELEMETRY_BYTES)
from tb_utils import start_test, check_sva, reset, set_sup_state,pulse_switch_rise, set_timestamp, set_status_input
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
    
@cocotb.test()
async def threshold_writes_through_model(dut):

    """
    Purpose: Walks the threshold write rules as a sequence of scenarios on one
             DUT and one model: the write key, the S_OFF gate, the multi-byte
             rule, all-or-nothing rejection, the clamp, and CRC discard. Rows
             run in order and state carries between them. After each row the
             scoreboard compares every register against the model, so the test
             asserts nothing by hand.
    """
    failures_before = await start_test(dut)
    model = RegfileModel()

    key = WRITE_KEY

    # hiccup_default_bytes: 250000 (the 5 ms default) as three bytes, low first
    hiccup_default_bytes = [0x90, 0xD0, 0x03]

    # Row 6 and row 7: the same frame, run in S_RUN and then in S_OFF. It passes
    # through every live threshold and hiccup_base on its way to cycles_per_step.
    through_cycles_frame = [key, 9, 20, 2, 60] + hiccup_default_bytes + [32]

    # (description, sup_state, start address, data bytes, crc_ok)
    threshold_cases = [
        ("key + trip_run",                  SUP_S_OFF, ADDR_WRITE_KEY, [key, 8],              True),
        ("no key",                          SUP_S_OFF, ADDR_TRIP_RUN,  [10],                  True),
        ("SCRATCH after a rejection",       SUP_S_OFF, ADDR_SCRATCH,   [0x77],                True),
        ("wrong key value",                 SUP_S_OFF, ADDR_WRITE_KEY, [0x12, 10],            True),
        ("live thresholds while running",   SUP_S_RUN, ADDR_WRITE_KEY, [key, 9, 20, 2, 60],   True),
        ("cycles_per_step while running",   SUP_S_RUN, ADDR_WRITE_KEY, through_cycles_frame,  True),
        ("same frame in S_OFF",             SUP_S_OFF, ADDR_WRITE_KEY, through_cycles_frame,  True),
        ("partial hiccup_base",             SUP_S_OFF, ADDR_WRITE_KEY, [key, 12, 28, 3, 83, 0x50, 0xC3], True),
        ("everything out of range",         SUP_S_OFF, ADDR_WRITE_KEY,
                                            [key, 0xFF, 0xFF, 0xFF, 0x00,
                                             0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF],             True),
        ("key + trip_run, bad CRC",         SUP_S_OFF, ADDR_WRITE_KEY, [key, 5],              False),
    ]

    for description, state, address, data, crc_ok in threshold_cases:
        dut._log.info(f"threshold row: {description}")

        set_sup_state(dut, model, state)

        await spi_write(dut, address, data, corrupt_crc=not crc_ok)
        model.apply_write(address, data, crc_ok=crc_ok)

        await scoreboard_check(dut, model)

    await check_sva(dut, failures_before)

@cocotb.test()
async def control_writes_through_model(dut):

    """
    Purpose: Walks the host enable path as a sequence of scenarios on one DUT
             and one model: enable needs no key, disable needs the disable key
             in the same frame, a disable without it is ignored, a bad CRC
             discards a disable, the physical switch overrides the veto, and a
             CONTROL write commits independently of a rejected threshold write
             in the same frame. The scoreboard compares every register after
             each row.
    """
    failures_before = await start_test(dut)
    model = RegfileModel()

    # unmapped_gap: the 13 bytes for 0x42..0x4E, between CONTROL and the write
    # key. Writes there are ignored, so a frame can run from DISABLE_KEY into
    # the threshold bank.
    unmapped_gap = [0x00] * 13

    # (description, start address, data bytes, crc_ok)
    # address None = pulse the physical switch instead of a bus write
    control_cases = [
        ("enable while already enabled",        ADDR_CONTROL,     [0x01],              True),
        ("disable without key: ignored",        ADDR_CONTROL,     [0x00],              True),
        ("wrong disable key: ignored",          ADDR_DISABLE_KEY, [0x12, 0x00],        True),
        ("keyed disable",                       ADDR_DISABLE_KEY, [DISABLE_KEY, 0x00], True),
        ("enable needs no key",                 ADDR_CONTROL,     [0x01],              True),
        ("keyed disable, bad CRC: discarded",   ADDR_DISABLE_KEY, [DISABLE_KEY, 0x00], False),
        ("keyed disable again",                 ADDR_DISABLE_KEY, [DISABLE_KEY, 0x00], True),
        ("physical switch overrides the veto",  None,             None,                True),
        # key + disable, then the gap, a WRONG write key at 0x4F and trip_run:
        # the threshold is rejected, the disable still commits
        ("disable + rejected threshold, one frame",
                                                ADDR_DISABLE_KEY,
                                                [DISABLE_KEY, 0x00] + unmapped_gap + [0x00, 7],
                                                                                       True),
        ("key then enable: enable wins",        ADDR_DISABLE_KEY, [DISABLE_KEY, 0x01], True),
    ]

    for description, address, data, crc_ok in control_cases:
        dut._log.info(f"control row: {description}")

        if address is None:
            await pulse_switch_rise(dut, model)
        else:
            await spi_write(dut, address, data, corrupt_crc=not crc_ok)
            model.apply_write(address, data, crc_ok=crc_ok)

        await scoreboard_check(dut, model)

    await check_sva(dut, failures_before)
    
    

@cocotb.test()
async def watchdog_through_model(dut):

    """
    Purpose: Walks the bus-silence watchdog through the model: a keyed disable
             holds the veto; a valid write (SCRATCH heartbeat) extends it; reads
             and a bad-CRC write do not; after WD_TIMEOUT_MS of silence the veto
             is released and wd_restored set; a fresh keyed disable clears
             wd_restored; and the timeout is measured correctly across the
             24-bit timestamp wrap. The scoreboard checks every register after
             every step.
    """
    failures_before = await start_test(dut)
    model = RegfileModel()

    async def host_write(description, address, data, crc_ok=True):
        dut._log.info(f"watchdog step: {description}")
        await spi_write(dut, address, data, corrupt_crc=not crc_ok)
        model.apply_write(address, data, crc_ok=crc_ok)
        await scoreboard_check(dut, model)

    async def time_passes(description, new_timestamp_ms):
        dut._log.info(f"watchdog step: {description} (timestamp_ms = {new_timestamp_ms})")
        await set_timestamp(dut, model, new_timestamp_ms)
        await scoreboard_check(dut, model)

    keyed_disable = [DISABLE_KEY, 0x00]

    # ---- the veto, extended by a heartbeat, then released by silence ----
    t_disable = 1000
    await time_passes("clock running, converter enabled", t_disable)
    await host_write("keyed disable: veto held", ADDR_DISABLE_KEY, keyed_disable)
    await time_passes("1 ms short of the timeout", t_disable + WD_TIMEOUT_MS - 1)

    t_heartbeat = t_disable + WD_TIMEOUT_MS - 1
    await host_write("SCRATCH heartbeat re-marks the watchdog", ADDR_SCRATCH, [0x11])
    await time_passes("heartbeat extended the veto", t_heartbeat + WD_TIMEOUT_MS - 1)

    # scoreboard_check has been READING throughout - reads must not extend it
    await time_passes("reads alone: veto released", t_heartbeat + WD_TIMEOUT_MS)

    # ---- a bad-CRC heartbeat is not proof of life ----
    t_second = t_heartbeat + WD_TIMEOUT_MS
    await host_write("fresh keyed disable clears wd_restored", ADDR_DISABLE_KEY, keyed_disable)
    await host_write("bad-CRC heartbeat", ADDR_SCRATCH, [0x22], crc_ok=False)
    await time_passes("bad heartbeat did not extend: released", t_second + WD_TIMEOUT_MS)

    # ---- the 24-bit wrap ----
    t_wrap = 0xFFFF00
    await time_passes("counter just below the wrap", t_wrap)
    await host_write("keyed disable near the wrap", ADDR_DISABLE_KEY, keyed_disable)
    await time_passes("across the wrap, 1 ms short", (t_wrap + WD_TIMEOUT_MS - 1) & TIMESTAMP_MASK)
    await time_passes("across the wrap: released",   (t_wrap + WD_TIMEOUT_MS)     & TIMESTAMP_MASK)

    await check_sva(dut, failures_before)

@cocotb.test()
async def telemetry_through_model(dut):

    """
    Purpose: Drives every reg_file status input to two distinct patterns -
             one, then its complement - and lets the scoreboard compare the
             whole telemetry block 0x10-0x20 against the model's map. Proves
             each input reaches the right address and bit position, with no
             two sources swapped (complementary patterns make every bit
             change between the two checks).
    """
    failures_before = await start_test(dut)
    model = RegfileModel()

    # (port, value in pattern A, value in pattern B); each fits its port width
    patterns = [
        ("PGOOD",                  1,        0),
        ("latch_stat_sync_db",     0,        1),
        ("en_from_switch_sync_db", 1,        0),
        ("CP_sync",                1,        0),
        ("OTP_sync_db",            0,        1),
        ("UVLO_sync_db",           1,        0),
        ("strike_level",           2,        1),         # 2 bits
        ("duty_count",             0x5A,     0xA5),
        ("prev_period",            0xA5,     0x5A),
        ("fault_count_run",        0x15,     0x0A),      # 5 bits
        ("fault_count_ss",         0x2A,     0x15),      # 6 bits
        ("fault_reg",              0x13,     0x0C),      # 5 bits
        ("fault_time",             0x123456, 0xEDCBA9),  # 24 bits
    ]

    for pattern_index, sup_state, timestamp in [(1, SUP_S_RUN, 0xABCDEF), (2, SUP_S_OFF, 0x543210)]:
        dut._log.info(f"telemetry pattern {'A' if pattern_index == 1 else 'B'}")
        for port_name, value_a, value_b in patterns:
            set_status_input(dut, model, port_name, value_a if pattern_index == 1 else value_b)
        set_sup_state(dut, model, sup_state)
        await set_timestamp(dut, model, timestamp)
        await scoreboard_check(dut, model)

    await check_sva(dut, failures_before)

@cocotb.test()
async def timestamp_coherent_across_carry(dut):

    """
    Purpose: Proves the read snapshot (contract F5): timestamp_ms ticks from
             0x00FFFF to 0x010000 in the MIDDLE of a burst read of 0x18-0x1A.
             Without the snapshot the bytes would stitch old and new values
             into 0x0100FF - 65 seconds adrift. With it, the burst returns the
             value held when the read began.
    """
    failures_before = await start_test(dut)
    model = RegfileModel()

    await set_timestamp(dut, model, 0x00FFFF)
    expected = model.expected_bytes(ADDR_TIME_0, 3)     # predicted at the read's start

    async def tick_mid_burst():
        # wait for the first data byte to be clocked out, then roll the counter over
        await RisingEdge(dut.spi_rd_byte_done)
        await FallingEdge(dut.clk)
        dut.timestamp_ms.value = 0x010000

    cocotb.start_soon(tick_mid_burst())
    time_read = await spi_read(dut, ADDR_TIME_0, 3)

    assert time_read == expected, \
        f"timestamp burst: DUT {[hex(b) for b in time_read]}, snapshot {[hex(b) for b in expected]}"

    # the tick really happened: bring the model up to date and check everything
    model.advance_time(0x010000)
    await scoreboard_check(dut, model)
    await check_sva(dut, failures_before)

@cocotb.test()
async def fault_record_clear_pulse(dut):

    """
    Purpose: Proves the fault-record clear end to end (contract F6): a read
             that stops before 0x20 produces no fault_reg_read_done pulse, a
             read covering 0x20 produces exactly one, a one-byte read of 0x20
             alone produces one, and a WRITE passing through 0x20 produces none.
    """
    failures_before = await start_test(dut)
    model = RegfileModel()

    pulse_count = [0]      # a one-item list, so the watcher below can update it

    async def count_clear_pulses():
        while True:
            await RisingEdge(dut.fault_reg_read_done)
            pulse_count[0] = pulse_count[0] + 1

    cocotb.start_soon(count_clear_pulses())

    async def expect_pulses(description, action, expected):
        before = pulse_count[0]
        await action
        await ClockCycles(dut.clk, IDLE_CLKS)
        seen = pulse_count[0] - before
        assert seen == expected, f"{description}: {seen} clear pulse(s), expected {expected}"

    await expect_pulses("partial record 0x1D-0x1F",  spi_read(dut, ADDR_FAULT_CAUSE, 3), 0)
    await expect_pulses("full record 0x1D-0x20",     spi_read(dut, ADDR_FAULT_CAUSE, 4), 1)
    await expect_pulses("0x20 alone",                spi_read(dut, ADDR_FTIME_2, 1),     1)
    await expect_pulses("write through 0x20",        spi_write(dut, ADDR_FAULT_CAUSE, [0, 0, 0, 0]), 0)
    model.apply_write(ADDR_FAULT_CAUSE, [0, 0, 0, 0])   # read-only addresses: ignored, but a valid write

    await scoreboard_check(dut, model)
    await check_sva(dut, failures_before)