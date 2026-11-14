#
# Filename:         scoreboard.py
#
# File Description: Full readback comparison between the DUT and the reference
#                   model. Reads every register the model tracks over SPI -
#                   the telemetry block, STATUS, CONTROL and the threshold bank
#                   - and fails the test with one line per mismatch. Reads are
#                   used deliberately: they exercise the real read path, and
#                   reads never change reg_file state (they do not feed the
#                   watchdog), so a check cannot disturb what it checks.
#
# Global variables: None

from spi_driver import spi_read
from host_if_constants import ADDR_TRIP_RUN, ADDR_STATUS, ADDR_CONTROL, TELEMETRY_BYTES


async def read_thresholds(dut):

    """
    Purpose: Read the whole threshold bank 0x50-0x5A in one burst and return
             it as a dict keyed like RegfileModel.thresholds. Multi-byte
             registers are reassembled low byte first.
    """
    threshold_bank = await spi_read(dut, ADDR_TRIP_RUN, 11)

    read_back = {
        "trip_run":         threshold_bank[0],
        "trip_ss":          threshold_bank[1],
        "max_strikes":      threshold_bank[2],
        "max_on_limit":     threshold_bank[3],
        "hiccup_base":      threshold_bank[4] | (threshold_bank[5] << 8) | (threshold_bank[6] << 16),
        "cycles_per_step":  threshold_bank[7],
        "clean_run_target": threshold_bank[8] | (threshold_bank[9] << 8) | (threshold_bank[10] << 16),
    }

    return read_back


async def scoreboard_check(dut, model):

    """
    Purpose: Compare every register the model tracks against the DUT and
             assert with the full list of mismatches. Checked: the telemetry
             block 0x10-0x20 byte for byte, STATUS write_rejected and
             spi_enable, CONTROL (wd_restored and the live enable), and every
             threshold.
    """
    mismatches = []

    telemetry_read     = await spi_read(dut, ADDR_STATUS, TELEMETRY_BYTES)
    telemetry_expected = model.predict_reads(ADDR_STATUS, TELEMETRY_BYTES)
    for offset, (dut_byte, model_byte) in enumerate(zip(telemetry_read, telemetry_expected)):
        if dut_byte != model_byte:
            mismatches.append(f"telemetry {ADDR_STATUS + offset:#04x}: DUT {dut_byte:#04x}, model {model_byte:#04x}")

    # STATUS on its own, so a mismatch in these two bits is named directly
    dut_status_byte    = await spi_read(dut, ADDR_STATUS, 1)
    dut_write_rejected = (dut_status_byte[0] >> 7) & 1
    if model.write_rejected != dut_write_rejected:
        mismatches.append(f"STATUS write_rejected: DUT {dut_write_rejected}, model {model.write_rejected}")

    dut_status_enable = (dut_status_byte[0] >> 5) & 1
    if model.spi_enable != dut_status_enable:
        mismatches.append(f"STATUS spi_enable: DUT {dut_status_enable}, model {model.spi_enable}")

    # CONTROL: bit 3 wd_restored, bit 0 the live enable; keys are never armed
    # between transactions, so bits 2-1 read 0
    control_read  = await spi_read(dut, ADDR_CONTROL, 1)
    dut_control   = control_read[0]
    model_control = (model.wd_restored << 3) | model.spi_enable
    if dut_control != model_control:
        mismatches.append(f"CONTROL: DUT {dut_control:#04x}, model {model_control:#04x}")

    thresholds = await read_thresholds(dut)
    for key, value in model.thresholds.items():
        if value != thresholds[key]:
            mismatches.append(f"{key}: DUT {thresholds[key]:#04x}, model {value:#04x}")

    assert not mismatches, "scoreboard mismatch:\n" + "\n".join(mismatches)
