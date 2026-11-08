#
# Filename:         reg_file_model.py
#
# File Description: Reference model of reg_file as the host sees it through
#                   spi_slave: the writable state (thresholds, SCRATCH,
#                   CONTROL, write_rejected, the bus-error counter, the
#                   watchdog) and the byte every address reads back. Written
#                   from the documented contracts of reg_file.sv and
#                   spi_slave.sv (headers, register map, port comments), so
#                   a disagreement with the DUT is a finding about one or the
#                   other. Tests tell the model what they did; scoreboard.py
#                   compares.
#
# Global variables: THRESHOLD_DEFAULTS - reset value of each threshold
#                   THRESHOLD_BIODATA  - address, width, S_OFF rule and clamp
#                                        range of each threshold

from host_if_constants import (ADDR_SCRATCH, ADDR_TRIP_RUN, ADDR_WRITE_KEY, WRITE_KEY,
                               SUP_S_OFF, ADDR_DISABLE_KEY, ADDR_CONTROL, DISABLE_KEY,
                               WD_TIMEOUT_MS, TIMESTAMP_MASK, ADDR_STATUS, PMIC_ID, VERSION_ID,
                               CAPABILITY_VAL)
from spi_driver import crc8


# THRESHOLD_DEFAULTS: reset value of each writable threshold (bank 0x50-0x5A),
#                     computed from pmic_types_pkg. These are derived values:
#                     recompute them whenever CLK_HZ, CONVERTOR_HZ or a default
#                     in the package changes.
THRESHOLD_DEFAULTS = {
    "trip_run": 12,	
    "trip_ss": 28,	
    "max_strikes": 3,	
    "max_on_limit": 83,	#duty_to_counts(75): 111 × 75 / 100, rounded down
    "hiccup_base": 250000,	#ms_to_clks(5): 5 × 50,000
    "cycles_per_step": 16,	
    "clean_run_target": 450000	#ms_to_sw_cycles(1000): 1000 × 450
}

# THRESHOLD_BIODATA: per threshold - first address, width in bytes, whether it
#                    is writable only in S_OFF, and the clamp range of
#                    reg_file's clamp functions. Listed in address order;
#                    random_walk relies on that to build a bank-ordered frame.
THRESHOLD_BIODATA = {
    "trip_run": {"address": 0x50, "bytes": 1, "S_OFF_only": False, "min": 1, "max": 16},	
    "trip_ss": {"address": 0x51, "bytes": 1, "S_OFF_only": False, "min": 1, "max": 32},	
    "max_strikes": {"address": 0x52, "bytes": 1, "S_OFF_only": False, "min": 1, "max": 3},	
    "max_on_limit": {"address": 0x53, "bytes": 1, "S_OFF_only": False, "min": 12, "max": 83},
    "hiccup_base": {"address": 0x54, "bytes": 3, "S_OFF_only": True, "min": 50000, "max": 1000000},
    "cycles_per_step": {"address": 0x57, "bytes": 1, "S_OFF_only": True, "min": 1, "max": 64},
    "clean_run_target": {"address": 0x58, "bytes": 3, "S_OFF_only": True, "min": 45000, "max": 524287}
  
}


def clamp_region(name, raw_value):

    """
    Purpose: Which part of its register's range a raw written value falls in,
             before the clamp - for functional coverage.
    """
    low  = THRESHOLD_BIODATA[name]["min"]
    high = THRESHOLD_BIODATA[name]["max"]
    if raw_value < low:   return "below"
    if raw_value == low:  return "at_min"
    if raw_value < high:  return "inside"
    if raw_value == high: return "at_max"
    return "above"

def clamp(name, raw_value):

    """
    Purpose: Models reg_file's clamp on write - an out-of-range value is
             saturated to the nearest bound of its register, never rejected.
    """
    low  = THRESHOLD_BIODATA[name]["min"]
    high = THRESHOLD_BIODATA[name]["max"]
    return min(max(raw_value, low), high)


class RegfileModel():
    """
    Purpose: Reference model of reg_file. One instance per test, created
             right after reset; tests call the apply_* / switch_rise /
             advance_time methods as they act on the DUT, and the predict_*
             methods say what a read should return.
    """
    def __init__ (self):
        """
        Purpose: Reset state - what reg_file holds immediately after rst_n.
        """
        self.thresholds = dict(THRESHOLD_DEFAULTS)
        self.scratch = 0x00
        self.write_rejected = 0
        self.bus_err_count = 0
        self.sup_state = SUP_S_OFF
        self.spi_enable  = 1     # reset: the host does not veto the converter
        self.wd_restored = 0     # set only by a watchdog release (advance_time)
        self.timestamp_ms = 0    # what the test is driving into timestamp_ms
        self.wd_mark      = 0    # timestamp of the last proof the host is alive
        # committed_regions: (register, clamp region) for each threshold the
        #                    last frame committed - read by random_walk for
        #                    the clamp covergroup
        self.committed_regions = []
        # status_inputs: what the test drives on reg_file's status inputs,
        #                keyed by wrapper port name
        self.status_inputs = {
            "PGOOD": 0, "latch_stat_sync_db": 0, "en_from_switch_sync_db": 0,
            "CP_sync": 0, "OTP_sync_db": 0, "UVLO_sync_db": 0,
            "strike_level": 0, "duty_count": 0, "prev_period": 0,
            "fault_count_run": 0, "fault_count_ss": 0,
            "fault_reg": 0, "fault_time": 0,
        }

    def switch_rise(self):

        """
        Purpose: Models en_switch_rise: the physical enable switch forces
                 spi_enable high, overriding any host veto.
        """
        self.spi_enable = 1

    def advance_time(self, new_timestamp_ms):

        """
        Purpose: Models the bus-silence watchdog as timestamp_ms moves. While
                 enabled, the mark follows the counter. While vetoed, the veto
                 is released - and wd_restored set - once the host has gone
                 WD_TIMEOUT_MS without a valid write. The subtraction wraps at
                 24 bits, as reg_file's unsigned subtraction does.
        """
        self.timestamp_ms = new_timestamp_ms & TIMESTAMP_MASK

        if self.spi_enable:
            self.wd_mark = self.timestamp_ms
        elif ((self.timestamp_ms - self.wd_mark) & TIMESTAMP_MASK) >= WD_TIMEOUT_MS:
            self.spi_enable  = 1
            self.wd_restored = 1
            self.wd_mark     = self.timestamp_ms   # enabled again: the mark follows

    def predict_read(self, address):

        """
        Purpose: Predict the byte a read of one telemetry address returns,
                 from the register map in reg_file's header. Between
                 transactions the disable key is never armed, so STATUS bit 6
                 is always 0. Unmapped 0x17 reads 0x00.
        """
        s = self.status_inputs

        if address == 0x00: return PMIC_ID
        if address == 0x01: return VERSION_ID
        if address == 0x02: return CAPABILITY_VAL
        if address == 0x03: return self.scratch

        if address == 0x10:      # STATUS
            return ((self.write_rejected << 7) | (0 << 6) | (self.spi_enable << 5)
                    | (s["en_from_switch_sync_db"] << 4) | (s["latch_stat_sync_db"] << 3)
                    | (s["PGOOD"] << 2) | (self.sup_state & 0x3))
        if address == 0x11:      # FAULT_FLAGS
            return (s["CP_sync"] << 2) | (s["OTP_sync_db"] << 1) | s["UVLO_sync_db"]
        if address == 0x12: return s["strike_level"]
        if address == 0x13: return s["duty_count"]
        if address == 0x14: return s["prev_period"]
        if address == 0x15: return s["fault_count_run"]
        if address == 0x16: return s["fault_count_ss"]
        if 0x18 <= address <= 0x1A:                       # timestamp, low byte first
            return (self.timestamp_ms >> (8 * (address - 0x18))) & 0xFF
        if address == 0x1B: return self.bus_err_count & 0xFF
        if address == 0x1C: return (self.bus_err_count >> 8) & 0xFF
        if address == 0x1D: return s["fault_reg"]
        if 0x1E <= address <= 0x20:                       # fault_time, low byte first
            return (s["fault_time"] >> (8 * (address - 0x1E))) & 0xFF

        # keys read {7'b0, armed}; a key never survives into a read transaction
        if address == 0x40: return 0x00
        if address == 0x4F: return 0x00
        if address == ADDR_CONTROL:
            return (self.wd_restored << 3) | self.spi_enable

        # threshold bank: the byte of whichever register covers this address
        for name, info in THRESHOLD_BIODATA.items():
            if info["address"] <= address < info["address"] + info["bytes"]:
                byte_index = address - info["address"]
                return (self.thresholds[name] >> (8 * byte_index)) & 0xFF
        return 0x00                                        # 0x17 and anything unmapped

    def predict_reads(self, address, count):

        """
        Purpose: Predict a burst read of count bytes from address, with the
                 7-bit auto-increment wrap.
        """
        return [self.predict_read((address + i) & 0x7F) for i in range(count)]

    def apply_abort(self):

        """
        Purpose: Models a write transaction spi_slave rejects with txn_abort -
                 bad CRC, CS rising mid-byte, fewer than three bytes, a
                 truncated command, or an SCK timeout. Nothing commits; the
                 bus-error counter counts it, saturating at 0xFFFF.
        """
        self.bus_err_count = min(self.bus_err_count + 1, 0xFFFF)

    def apply_frame(self, frame, bits_sent=None, dead_after_bits=None):

        """
        Purpose: Predicts what spi_slave + reg_file do with ANY frame, however
                 the host ended it - the general form of apply_write.
                   bits_sent       - bits clocked before CS rose (None = all)
                   dead_after_bits - bits clocked before an SCK stall sent
                                     spi_slave to S_DEAD (None = no stall)
                 Rules, from spi_slave's contract:
                   - command byte never accepted (CS rose, or the slave went
                     dead, before 8 bits): judged a write -> txn_abort
                   - a read never commits and never aborts
                   - a write commits only if CS rose on a byte boundary, at
                     least 3 bytes arrived, the slave never went dead, and the
                     CRC over everything received is zero; otherwise txn_abort
                 The CRC is computed over the bytes actually received, so a
                 write cut on a byte boundary whose last received byte happens
                 to be a valid CRC is predicted to commit, as spi_slave would.
                 Returns how the frame ended, for the frame covergroup:
                 truncated_cmd, read, read_cut, read_stall, write_stall,
                 cut_mid_byte, short, bad_crc or clean.
        """
        self.committed_regions = []             # nothing committed by this frame yet
        if bits_sent is None:
            bits_sent = 8 * len(frame)

        command_bits = bits_sent if dead_after_bits is None else min(bits_sent, dead_after_bits)
        if command_bits < 8:
            self.apply_abort()                  # command never accepted
            return "truncated_cmd"

        if frame[0] & 0x80:                     # a read: no commit, no abort
            if dead_after_bits is not None:
                return "read_stall"
            if bits_sent % 8 != 0:
                return "read_cut"
            return "read"

        if dead_after_bits is not None:
            self.apply_abort()                  # timed out: S_DEAD discards the write
            return "write_stall"

        received = frame[: bits_sent // 8]
        if bits_sent % 8 != 0:
            self.apply_abort()
            return "cut_mid_byte"
        if len(received) < 3:
            self.apply_abort()
            return "short"
        if crc8(received) != 0:
            self.apply_abort()
            return "bad_crc"
        self.apply_write(received[0] & 0x7F, received[1:-1])
        return "clean"

    def apply_write(self, address, data_bytes, crc_ok=True):
        """
        Purpose: Predict the effect of one complete write transaction that
                 started at address. A bad CRC discards everything and counts
                 one bus error. Otherwise byte i goes to address + i (7-bit
                 wrap) and nothing commits until the end of the frame:
                   - SCRATCH and CONTROL commit on their own;
                   - the threshold writes commit all or nothing - one refused
                     write (no key, an S_OFF-only register outside S_OFF, a
                     partially written multi-byte register) rejects them all
                     and sets write_rejected; an accepted set clears it;
                   - a frame with no threshold write leaves write_rejected alone;
                   - any valid write re-marks the watchdog.
                 Returns the threshold verdict for the coverage - accepted,
                 no_key, partial or not_off - or None if the frame wrote no
                 threshold (or failed its CRC).
        """

        pending_scratch = None
        unlocked      = False    # write key: valid for this transaction only
        staged        = {}       # threshold bytes written, by address
        disable_armed = False    # disable key: valid for this transaction only
        en_pending    = None     # CONTROL change to apply at commit; None = no change
        self.committed_regions = []

        if not crc_ok:
            self.apply_abort()
            return

        for offset,value in enumerate(data_bytes):
            register_address = (address + offset) & 0x7F

            if(register_address == ADDR_SCRATCH):
                pending_scratch = value

            elif register_address == ADDR_DISABLE_KEY:
                disable_armed = (value == DISABLE_KEY)

            elif register_address == ADDR_CONTROL:
                if value & 0x01:
                    en_pending    = 1        # enable: no key needed
                    disable_armed = False
                elif disable_armed:
                    en_pending    = 0        # disable: honoured because the key came first
                    disable_armed = False
                # bit 0 clear with no key armed: silently ignored

            elif(register_address == ADDR_WRITE_KEY):
                unlocked = (value == WRITE_KEY)

            elif ADDR_TRIP_RUN <= register_address <= 0x5A:
                staged[register_address] = value

        if pending_scratch is not None:
            self.scratch = pending_scratch

        # CONTROL commits independently of the threshold verdict: a rejected
        # threshold write does not stop a valid enable or disable
        if en_pending is not None:
            self.spi_enable = en_pending
            if en_pending == 0:
                self.wd_restored = 0     # a host disable reclaims the veto


        threshold_reason = None             # returned for coverage; None = no threshold written

        if staged:
            # ---- decide: one pass over every register, nothing changed yet ----
            no_key  = not unlocked
            not_off = False
            partial = False
            for name, info in THRESHOLD_BIODATA.items():
                addresses = range(info["address"], info["address"] + info["bytes"])
                written   = [a in staged for a in addresses]

                if any(written) and info["S_OFF_only"] and self.sup_state != SUP_S_OFF:
                    not_off = True      # an S_OFF-only register written outside S_OFF

                if any(written) and not all(written):
                    partial = True      # a multi-byte register only partly written

            rejected = no_key or not_off or partial

            # the reason coverage records; when several apply, the first in this order
            if no_key:
                threshold_reason = "no_key"
            elif partial:
                threshold_reason = "partial"
            elif not_off:
                threshold_reason = "not_off"
            else:
                threshold_reason = "accepted"

            # ---- apply ----
            if rejected:

                self.write_rejected = 1
            else:

                self.write_rejected = 0

                for name, info in THRESHOLD_BIODATA.items():
                    addresses = range(info["address"], info["address"] + info["bytes"])

                    # only registers written in full this transaction are committed
                    if all(a in staged for a in addresses):

                        # rebuild the value from its bytes, low byte first
                        raw_value = 0
                        for i in range(info["bytes"]):
                            raw_value = raw_value | (staged[info["address"] + i] << (8 * i))

                        self.committed_regions.append((name, clamp_region(name, raw_value)))
                        # clamp on the way in, as reg_file does
                        self.thresholds[name] = clamp(name, raw_value)

        # any valid write is proof of life: the watchdog re-marks
        self.wd_mark = self.timestamp_ms
        return threshold_reason