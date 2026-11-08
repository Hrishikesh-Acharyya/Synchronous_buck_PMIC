#
# Filename:         test_host_if.py
#
# File Description: cocotb tests for the host interface (spi_slave + reg_file
#                   through host_if_wrapper). The tests act as the host MCU.
#                   Constants come from host_if_constants.py, bring-up and the
#                   SVA verdict from tb_utils.py, bus access from spi_driver.py,
#                   the reference model from reg_file_model.py and the full
#                   readback comparison from scoreboard.py. This file holds
#                   only the tests:
#                     directed   - reset and idle bus, identity read, SCRATCH
#                                  write/readback, bad-CRC discard, threshold
#                                  defaults, then model-checked walks of the
#                                  threshold rules, the enable path, the
#                                  watchdog, telemetry mapping, the timestamp
#                                  snapshot, the fault-record clear, broken
#                                  frames, key lapse and counter saturation
#                     model-only - crc8_model_check, clamp_model_check: the
#                                  reference functions against hand-worked
#                                  values; they do not use the DUT
#                     random     - random_walk: constrained-random traffic
#                                  checked against the model
#
# Global variables: None

import csv
import os
import random

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

from host_if_constants import (S_IDLE, READ_FLAG, ADDR_PMIC_ID, PMIC_ID, VERSION_ID,
                               ADDR_SCRATCH, ADDR_BUS_ERR_L, ADDR_TRIP_RUN, IDLE_CLKS,
                               ADDR_WRITE_KEY, WRITE_KEY, ADDR_DISABLE_KEY, DISABLE_KEY,
                               ADDR_CONTROL, SUP_S_OFF, SUP_S_SS, SUP_S_RUN, SUP_S_HICCUP,
                               WD_TIMEOUT_MS, TIMESTAMP_MASK, SCK_PAUSE_NS, ADDR_STATUS,
                               ADDR_TIME_0, ADDR_FAULT_CAUSE, ADDR_FTIME_2, ARM_LAPSE_NS, SCK_HALF_PERIODS)
from tb_utils import (start_test, check_sva, set_sup_state, set_status_input,
                      set_timestamp, pulse_switch_rise)
from spi_driver import spi_transfer, spi_write, spi_read, crc8, build_write_frame
from reg_file_model import THRESHOLD_DEFAULTS, clamp, RegfileModel, THRESHOLD_BIODATA
from scoreboard import read_thresholds, scoreboard_check


@cocotb.test()
async def idle_bus_after_reset(dut): 

    """
    Purpose: After reset and IDLE_CLKS of an idle bus, MISO is low and
             spi_slave is in S_IDLE.
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
    Purpose: Read PMIC_ID and VERSION in one burst. Both values are fixed by
             reg_file's parameters, so this proves the command, turnaround
             and burst-read path end to end. The command and turnaround
             bytes must read back 0x00 (MISO is held low outside S_READ).
    """
    
    failures_before = await start_test(dut)

    command_byte = READ_FLAG|ADDR_PMIC_ID

    read_frame = [command_byte, 0x00, 0x00,0x00]
    result = await spi_transfer(dut, read_frame)
    # Let CS_n's rise pass the input filter and reach spi_slave before the
    # checks, so the end-of-transaction assertions and covers are evaluated.
    await ClockCycles(dut.clk, IDLE_CLKS)

    assert result[0] == 0x00, f"Command byte answer should be 0x00, read {result[0]:#04x}"
    assert result[1] == 0x00, f"Turnaround byte answer should be 0x00, read {result[1]:#04x}"
    assert result[2] == PMIC_ID, f"PMIC_ID value read as {result[2]:#04x}, should be {PMIC_ID:#04x}"
    assert result[3] == VERSION_ID, f"VERSION_ID value read as {result[3]:#04x}, should be {VERSION_ID:#04x}"

    await check_sva(dut, failures_before)

    
@cocotb.test()
async def crc8_model_check(dut):

    """
    Purpose: Check the CRC model itself: the published CRC-8/SMBUS check
             value (0xF4 for "123456789"), and the zero-remainder property
             spi_slave relies on - a message followed by its own CRC divides
             to zero. Does not use the DUT.
    """

    # the standard check message, ASCII "123456789"
    send_message = list(range(0x31,0x3A))
    crc = crc8(send_message)
    assert crc==0xF4, f"The crc value received for 123456789 is {crc:#04x}, whereas it should be 0xF4"
    
    # message followed by its own CRC: the remainder must be zero
    appended_message = send_message + [crc]
    crc_zero = crc8(appended_message)
    assert crc_zero == 0, f"The crc value of the message + its crc is {crc_zero:#04x}, it should be 0"
    
@cocotb.test()
async def write_scratch_read_back(dut):
    """
    Purpose: Write SCRATCH and read it back. A correct readback proves the
             whole write path: command, data, CRC, integrity_OK and the commit
             in reg_file.
    """

    failures_before = await start_test(dut)

    scratch_value = 0x5A
    
    await spi_write(dut, ADDR_SCRATCH, [scratch_value])

    read_data = await spi_read (dut, ADDR_SCRATCH, 1)

    assert read_data[0] == scratch_value, f"Data sent was {scratch_value:#04x}, received is: {read_data[0]:#04x}"

    # Let CS_n's rise pass the input filter and reach spi_slave before the
    # checks, so the end-of-transaction assertions and covers are evaluated.
    await ClockCycles(dut.clk, IDLE_CLKS)
    await check_sva(dut, failures_before)

    
@cocotb.test()
async def bad_crc_write_rejected(dut):
    """
    Purpose: A good SCRATCH write, then one with a corrupted CRC. The bad
             write must be discarded (SCRATCH keeps the good value) and the
             bus-error counter must rise by exactly one.
    """

    failures_before = await start_test(dut)

    scratch_value = 0x5A
    bad_value = 0xA5

    bus_error_count_initial_list = await spi_read(dut, ADDR_BUS_ERR_L, 2)
   
    await spi_write(dut, ADDR_SCRATCH, [scratch_value])
    good_read_data = await spi_read (dut, ADDR_SCRATCH, 1)
    assert good_read_data[0] == scratch_value, f"Read returned {good_read_data[0]:#04x} on writing {scratch_value:#04x} even with good crc"
    
    
    await spi_write(dut, ADDR_SCRATCH, [bad_value], corrupt_crc=True)
    bad_read_data = await spi_read(dut, ADDR_SCRATCH, 1)
    assert bad_read_data[0] == scratch_value, f"Sent bad data {bad_value:#04x}, reg_file allowed it to be written"


    bus_error_count_final_list = await spi_read(dut, ADDR_BUS_ERR_L, 2)
    await ClockCycles(dut.clk, IDLE_CLKS)  

    errors_before = (bus_error_count_initial_list[1] << 8) | bus_error_count_initial_list[0]
    errors_after  = (bus_error_count_final_list[1] << 8) | bus_error_count_final_list[0] 
    assert errors_after - errors_before == 1, f"The bus_error rose by {int(errors_after-errors_before)}, after sending one bad-CRC byte"

    await check_sva(dut, failures_before)

@cocotb.test()
async def thresholds_reset_defaults(dut):
    """
    Purpose: After reset, every threshold (bank 0x50-0x5A) reads back its
             reset default.
    """

    failures_before = await start_test(dut)
    read_back = await read_thresholds(dut)

    for name, expected in THRESHOLD_DEFAULTS.items():
        actual = read_back[name]
        assert actual == expected, f"{name}: read {actual}, expected {expected}"

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

    # the model starts from reset, like the DUT start_test just reset
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

    # SCRATCH and the bus-error counter are both in the scoreboard's readback
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
    expected = model.predict_reads(ADDR_TIME_0, 3)     # predicted at the read's start

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





@cocotb.test()
async def random_walk(dut):

    """
    Purpose: Constrained-random traffic against the register model. Each event
             is a weighted random choice of:
               bus traffic   - a burst read (checked against the model as it
                               happens), a SCRATCH write, a threshold frame
                               from the write key (right key 80% of the time,
                               1-11 threshold bytes), a CONTROL frame (keyed or
                               plain), or an unconstrained write anywhere;
               state events  - a random supervisor state, a random status
                               input (within its width), a time step biased
                               toward the 5000 ms watchdog boundary, or a pulse
                               of the physical enable switch.
             One write in ten carries a bad CRC; data values are biased toward
             boundaries (0x00, 0x01, 0x7F, 0x80, 0xFE, 0xFF). The full
             scoreboard runs every SCOREBOARD_EVERY events and at the end, and
             a tally of the event kinds drawn is logged. Every run is
             reproducible: the log's first line is the `make replay` command
             for it. Under `make soak`, each event is also written to a CSV.
    """
    failures_before = await start_test(dut)
    model = RegfileModel()

    # RANDOM_EVENTS: events per run; set RANDOM_EVENTS=<n> on the make line to change it
    RANDOM_EVENTS = int(os.environ.get("RANDOM_EVENTS", "30"))
    # SCOREBOARD_EVERY: run the full scoreboard after every N events, so a
    #                   failure is pinned to the last N; set on the make line
    SCOREBOARD_EVERY = int(os.environ.get("SCOREBOARD_EVERY", "10"))

    dut._log.info(f"random_walk: {RANDOM_EVENTS} events - to replay this exact run: "
                  f"make replay SEED={cocotb.RANDOM_SEED} EVENTS={RANDOM_EVENTS}")

    # RANDOM_CSV: if set (by `make soak`), one CSV row per event recording the
    #             event and the model state after it - for offline analysis
    csv_path   = os.environ.get("RANDOM_CSV")
    csv_file   = open(csv_path, "w", newline="") if csv_path else None
    csv_writer = csv.writer(csv_file) if csv_file else None
    if csv_writer:
        csv_writer.writerow(["seed", "event", "kind", "note", "sup_state", "spi_enable",
                             "wd_restored", "write_rejected", "bus_err_count",
                             "timestamp_ms", "scratch"] + list(THRESHOLD_DEFAULTS))

    EVENT_KINDS   = ["read", "scratch", "threshold", "control", "raw_write",
                     "sup_state", "status", "time", "switch",
                     "broken_write", "broken_read"]
    EVENT_WEIGHTS = [25,     8,         20,          12,        15,
                     7,           7,        7,      3,
                     6,              3]

    def biased_byte():
        # half the time an edge value, the other half anything
        if random.random() < 0.5:
            return random.choice([0x00, 0x01, 0x7F, 0x80, 0xFE, 0xFF])
        return random.randint(0x00, 0xFF)

    def threshold_value(name):
        # one of five regions of the register's range, equally likely - so
        # in-range commits are as common as clamped ones
        info = THRESHOLD_BIODATA[name]
        low, high = info["min"], info["max"]
        top = (1 << (8 * info["bytes"])) - 1          # largest value the bytes can carry
        region = random.choice(["below", "at_min", "inside", "at_max", "above"])
        if region == "below":
            return random.randint(0, low - 1)
        if region == "at_min":
            return low
        if region == "inside":
            return random.randint(low, high)
        if region == "at_max":
            return high
        return random.randint(high + 1, top)

    def threshold_bank_bytes():
        # all 11 bank bytes, 0x50..0x5A, one region-picked value per register,
        # multi-byte registers low byte first (THRESHOLD_BIODATA is in address order)
        bank = []
        for name, info in THRESHOLD_BIODATA.items():
            value = threshold_value(name)
            bank += [(value >> (8 * i)) & 0xFF for i in range(info["bytes"])]
        return bank

    async def random_write(address, data, half_period_ns):
        crc_ok = random.random() < 0.9                    # 1 write in 10 is corrupted
        await spi_write(dut, address, data, corrupt_crc=not crc_ok,
                        half_period_ns=half_period_ns)
        model.apply_write(address, data, crc_ok=crc_ok)
        return f"write @{address:#04x} {[hex(b) for b in data]} crc_ok={crc_ok} sck_half={half_period_ns}"

    # STATUS_WIDTHS: width of each status input, so a random value always fits
    STATUS_WIDTHS = {
        "PGOOD": 1, "latch_stat_sync_db": 1, "en_from_switch_sync_db": 1,
        "CP_sync": 1, "OTP_sync_db": 1, "UVLO_sync_db": 1,
        "strike_level": 2, "duty_count": 8, "prev_period": 8,
        "fault_count_run": 5, "fault_count_ss": 6, "fault_reg": 5, "fault_time": 24,
    }

    # timestamp: the time this test has driven so far; time events add to it
    timestamp = 0
    # event_counts: how many times each kind was drawn this run
    event_counts = {kind: 0 for kind in EVENT_KINDS}

    for event_number in range(1, RANDOM_EVENTS + 1):

        random_event = random.choices(EVENT_KINDS, weights=EVENT_WEIGHTS)[0]
        event_counts[random_event] = event_counts[random_event] + 1
        half_period_ns = random.choice(SCK_HALF_PERIODS)

        if random_event == "read":
            rand_start_addr = random.randint(0x00, 0x7F)
            rand_count      = random.randint(1, 16)

            read_model_bytes = model.predict_reads(rand_start_addr, rand_count)   # before the read
            read_dut_bytes   = await spi_read(dut, rand_start_addr, rand_count)

            if read_dut_bytes != read_model_bytes:
                # list only the addresses that differ, so a 16-byte burst is not a wall of hex
                diffs = [f"{(rand_start_addr + i) & 0x7F:#04x}: DUT {d:#04x} model {m:#04x}"
                         for i, (d, m) in enumerate(zip(read_dut_bytes, read_model_bytes))
                         if d != m]
                assert False, (f"event {event_number}: read @{rand_start_addr:#04x} x{rand_count} "
                               f"mismatch at {len(diffs)} address(es):\n  " + "\n  ".join(diffs))

            note = f"read @{rand_start_addr:#04x} x{rand_count} -> {[hex(b) for b in read_dut_bytes]}"

        elif random_event == "scratch":
            note = await random_write(ADDR_SCRATCH, [random.randint(0x00, 0xFF)], half_period_ns)

        elif random_event == "threshold":
            # constrained shape: start at the write key so the first byte IS the key;
            # right key 80% of the time, then 1-11 threshold bytes
            key  = WRITE_KEY if random.random() < 0.8 else biased_byte()
            data = [key] + threshold_bank_bytes()[:random.randint(1, 11)]
            note = await random_write(ADDR_WRITE_KEY, data, half_period_ns)

        elif random_event == "control":
            control_byte = random.choice([0x00, 0x01])          # disable or enable
            if random.random() < 0.5:
                # keyed form: [disable key, CONTROL]; right key 70% of the time
                key  = DISABLE_KEY if random.random() < 0.7 else biased_byte()
                note = await random_write(ADDR_DISABLE_KEY, [key, control_byte], half_period_ns)
            else:
                # plain CONTROL write: an enable works, a disable is ignored
                note = await random_write(ADDR_CONTROL, [control_byte], half_period_ns)

        elif random_event == "raw_write":
            # no constraint: anywhere, 1-8 bytes - read-only addresses, wraps past
            # 0x7F, and the occasional accidental key all come from here
            address = random.randint(0x00, 0x7F)
            data    = [biased_byte() for _ in range(random.randint(1, 8))]
            note    = await random_write(address, data, half_period_ns)

        elif random_event == "sup_state":
            # any supervisor state; outside S_OFF the S_OFF-only thresholds are refused
            rand_state = random.choice([SUP_S_OFF, SUP_S_SS, SUP_S_RUN, SUP_S_HICCUP])
            set_sup_state(dut, model, rand_state)
            note = f"sup_state -> {rand_state}"

        elif random_event == "status":
            # one random status input, a random value that fits its width
            rand_port  = random.choice(list(STATUS_WIDTHS))
            rand_value = random.randint(0, (1 << STATUS_WIDTHS[rand_port]) - 1)
            set_status_input(dut, model, rand_port, rand_value)
            note = f"{rand_port} -> {rand_value:#x}"

        elif random_event == "time":
            # steps biased to land on the watchdog boundary, plus any jump
            rand_step = random.choice([1, 100, WD_TIMEOUT_MS - 1, WD_TIMEOUT_MS,
                                       WD_TIMEOUT_MS + 1, random.randint(0, 20000)])
            timestamp = (timestamp + rand_step) & TIMESTAMP_MASK
            await set_timestamp(dut, model, timestamp)
            note = f"time +{rand_step} -> {timestamp}"

        elif random_event == "switch":
            # the physical enable switch: forces spi_enable high, overriding a veto
            await pulse_switch_rise(dut, model)
            note = "switch pulse"

        elif random_event == "broken_write":
            # a write the host ends badly: cut at a random bit, or stalled past
            # the SCK timeout at a random bit. 0-4 data bytes, so short frames too
            frame = build_write_frame(random.randint(0x00, 0x7F),
                                      [biased_byte() for _ in range(random.randint(0, 4))])
            total_bits = 8 * len(frame)
            if random.random() < 0.5:
                stop_after_bits, pause_after_bits = random.randint(0, total_bits - 1), None
            else:
                stop_after_bits, pause_after_bits = None, random.randint(0, total_bits)
            await spi_transfer(dut, frame, half_period_ns=half_period_ns,
                               stop_after_bits=stop_after_bits, pause_after_bits=pause_after_bits,
                               pause_ns=SCK_PAUSE_NS if pause_after_bits is not None else 0)
            model.apply_frame(frame, bits_sent=stop_after_bits, dead_after_bits=pause_after_bits)
            note = (f"broken write {[hex(b) for b in frame]} cut={stop_after_bits} "
                    f"stall={pause_after_bits} sck_half={half_period_ns}")

        elif random_event == "broken_read":
            # a read the host ends badly: cut or stalled anywhere, including
            # during its command (which counts as an aborted write)
            frame = [READ_FLAG | random.randint(0x00, 0x7F), 0x00] + [0x00] * random.randint(1, 8)
            total_bits = 8 * len(frame)
            if random.random() < 0.5:
                stop_after_bits, pause_after_bits = random.randint(0, total_bits - 1), None
            else:
                stop_after_bits, pause_after_bits = None, random.randint(0, total_bits)
            await spi_transfer(dut, frame, half_period_ns=half_period_ns,
                               stop_after_bits=stop_after_bits, pause_after_bits=pause_after_bits,
                               pause_ns=SCK_PAUSE_NS if pause_after_bits is not None else 0)
            model.apply_frame(frame, bits_sent=stop_after_bits, dead_after_bits=pause_after_bits)
            note = (f"broken read @{frame[0] & 0x7F:#04x} cut={stop_after_bits} "
                    f"stall={pause_after_bits} sck_half={half_period_ns}")

        # one line per event: what happened, in order - the log a failure is read from
        dut._log.info(f"event {event_number}: {random_event}: {note}")

        if csv_writer:
            csv_writer.writerow([cocotb.RANDOM_SEED, event_number, random_event, note,
                                 model.sup_state, model.spi_enable, model.wd_restored,
                                 model.write_rejected, model.bus_err_count,
                                 model.timestamp_ms, model.scratch]
                                + [model.thresholds[name] for name in THRESHOLD_DEFAULTS])
            csv_file.flush()      # keep every row even if a later event fails the test

        if event_number % SCOREBOARD_EVERY == 0:
            dut._log.info(f"event {event_number}: scoreboard check")
            await scoreboard_check(dut, model)

    dut._log.info(f"random_walk: events drawn per kind: {event_counts}")
    never_drawn = [kind for kind, count in event_counts.items() if count == 0]
    if never_drawn:
        dut._log.warning(f"random_walk: never drawn this run: {never_drawn}")

    if csv_file:
        csv_file.close()

    dut._log.info(f"random_walk: all {RANDOM_EVENTS} events done, final scoreboard check")
    await scoreboard_check(dut, model)
    await check_sva(dut, failures_before)

@cocotb.test()
async def broken_frames_through_model(dut):

    """
    Purpose: Drives every way a host can end a frame badly, each checked by
             the model and the scoreboard: commands cut short (after a read,
             after a write, and a CS blip with no clocks), a write cut mid-byte
             and on a byte boundary, a short [command][CRC] frame, SCK stalls
             past the timeout in S_CMD / S_WRITE / after a whole frame / in
             S_TURN / S_READ, a read stalled during its command, and a read
             cut mid-byte. Writes that end badly must abort and count one bus
             error; reads must change nothing. Ends with a clean write to show
             the slave recovers. First exercise of spi_slave_sva's timeout
             and abort properties.
    """
    failures_before = await start_test(dut)
    model = RegfileModel()

    good_write = build_write_frame(ADDR_SCRATCH, [0x5A])          # 24 bits
    short_frm  = build_write_frame(ADDR_SCRATCH, [])              # [command][CRC]: 16 bits
    read_frm   = [READ_FLAG | ADDR_STATUS, 0x00, 0x00, 0x00]      # 32 bits

    # (description, frame, stop_after_bits, pause_after_bits, scoreboard after?)
    # the scoreboard READS, so it is skipped where the next row needs the
    # previous completed command to have been a WRITE
    broken_cases = [
        ("clean write",                        good_write, None, None, False),
        ("command cut after a write",          good_write, 5,    None, True),
        ("clean read",                         read_frm,   None, None, False),
        ("command cut after a read",           read_frm,   4,    None, True),
        ("CS blip, no clocks",                 good_write, 0,    None, True),
        ("write cut mid-byte",                 good_write, 13,   None, True),
        ("write cut on a byte boundary",       good_write, 16,   None, True),
        ("short frame [command][CRC]",         short_frm,  None, None, True),
        ("SCK stall in S_CMD (write)",         good_write, None, 3,    True),
        ("SCK stall in S_WRITE",               good_write, None, 12,   True),
        ("SCK stall after the whole frame",    good_write, None, 24,   True),
        ("SCK stall in S_TURN",                read_frm,   None, 12,   True),
        ("SCK stall in S_READ",                read_frm,   None, 20,   True),
        ("SCK stall in a read's command",      read_frm,   None, 3,    True),
        ("read cut mid-byte",                  read_frm,   20,   None, True),
        ("clean write: slave recovered",       build_write_frame(ADDR_SCRATCH, [0xC3]),
                                                           None, None, True),
    ]

    for description, frame, stop_after_bits, pause_after_bits, check_after in broken_cases:
        dut._log.info(f"broken-frame row: {description}")

        await spi_transfer(dut, frame, stop_after_bits=stop_after_bits,
                           pause_after_bits=pause_after_bits,
                           pause_ns=SCK_PAUSE_NS if pause_after_bits is not None else 0)
        model.apply_frame(frame, bits_sent=stop_after_bits, dead_after_bits=pause_after_bits)

        if check_after:
            await scoreboard_check(dut, model)

    await check_sva(dut, failures_before)

@cocotb.test()
async def arm_key_lapses(dut):

    """
    Purpose: A key left armed lapses after 2^16 clocks. A frame from the
             write key carries one more byte so the key is released to
             reg_file (spi_slave strobes a byte only when the next one
             completes), then
             SCK stalls with CS low for ARM_LAPSE_NS (~1.4 ms, past the arm
             timer). The slave also times out, so the frame ends in an abort.
             Hits c_arm_lapse and exercises a_arm_timer_lapses_keys. Slow:
             about 1.4 ms of simulated time.
    """
    failures_before = await start_test(dut)
    model = RegfileModel()

    frame = build_write_frame(ADDR_WRITE_KEY, [WRITE_KEY, 0x10])   # key, then trip_run
    await spi_transfer(dut, frame, pause_after_bits=24, pause_ns=ARM_LAPSE_NS)
    model.apply_frame(frame, dead_after_bits=24)

    await scoreboard_check(dut, model)
    await check_sva(dut, failures_before)


@cocotb.test()
async def bus_error_counter_saturates(dut):

    """
    Purpose: The bus-error counter holds at 0xFFFF instead of wrapping.
             Rather than 65,535 aborts, the counter is deposited at
             0xFFFE (model told the same), then two bad-CRC writes take it to
             0xFFFF and try to go past it; the scoreboard checks the result.

             A cocotb deposit is invisible to Verilator's $stable / $past
             sampling, so a_bus_err_moves_only_on_abort does not fire on the
             deposit; its ability to fail was confirmed separately, by moving
             the count in the RTL without an abort. This test therefore
             expects zero SVA failures and relies on the scoreboard and
             a_bus_err_saturates.
    """
    failures_before = await start_test(dut)
    model = RegfileModel()

    await FallingEdge(dut.clk)                       # never change state on a rising edge
    dut.u_reg_file.bus_err_count.value = 0xFFFE
    model.bus_err_count = 0xFFFE

    for _ in range(2):
        await spi_write(dut, ADDR_SCRATCH, [0x11], corrupt_crc=True)
        model.apply_write(ADDR_SCRATCH, [0x11], crc_ok=False)

    await scoreboard_check(dut, model)
    await check_sva(dut, failures_before)