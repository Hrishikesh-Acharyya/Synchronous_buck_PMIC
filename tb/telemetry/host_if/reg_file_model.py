
from host_if_constants import (ADDR_SCRATCH, ADDR_TRIP_RUN, ADDR_WRITE_KEY, WRITE_KEY,
                               SUP_S_OFF, ADDR_DISABLE_KEY, ADDR_CONTROL, DISABLE_KEY,
                               WD_TIMEOUT_MS, TIMESTAMP_MASK, ADDR_STATUS, PMIC_ID, VERSION_ID,
                               CAPABILITY_VAL)


# THRESHOLD_DEFAULTS: Dictionary holding constants and their reset values, taken from 
#                     pmic_types_pkg or derived wherever needed. These are the writable
#                     thresholds, address range: 0x50-0x6F 
# WARNING: RECOMPUTE IF PMIC CHANGES
THRESHOLD_DEFAULTS = {
    "trip_run": 12,	
    "trip_ss": 28,	
    "max_strikes": 3,	
    "max_on_limit": 83,	#duty_to_counts(75): 111 × 75 / 100, rounded down
    "hiccup_base": 250000,	#ms_to_clks(5): 5 × 50,000
    "cycles_per_step": 16,	
    "clean_run_target": 450000	#ms_to_sw_cycles(1000): 1000 × 450
}

# THRESHOLD_BIODATA: Dictionary from register name to a dictionary of address, bytes, s_off_only, min
#                    and max. The constant values are taken from/ calculated from pmic package
#                    and reg file's clamp functions
THRESHOLD_BIODATA = {
    "trip_run": {"address": 0x50, "bytes": 1, "S_OFF_only": False, "min": 1, "max": 16},	
    "trip_ss": {"address": 0x51, "bytes": 1, "S_OFF_only": False, "min": 1, "max": 32},	
    "max_strikes": {"address": 0x52, "bytes": 1, "S_OFF_only": False, "min": 1, "max": 3},	
    "max_on_limit": {"address": 0x53, "bytes": 1, "S_OFF_only": False, "min": 12, "max": 83},
    "hiccup_base": {"address": 0x54, "bytes": 3, "S_OFF_only": True, "min": 50000, "max": 1000000},
    "cycles_per_step": {"address": 0x57, "bytes": 1, "S_OFF_only": True, "min": 1, "max": 64},
    "clean_run_target": {"address": 0x58, "bytes": 3, "S_OFF_only": True, "min": 45000, "max": 524287}
  
}

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
    Purpose: Reference model of reg_file's writable state. One instance
             made per state, starting at reset
    """
    def __init__ (self):
        """
        Purpose: Reset state: what reg_file holds immediately after rst_n
        """
        self.thresholds = dict(THRESHOLD_DEFAULTS)
        self.scratch = 0x00
        self.write_rejected = 0
        self.bus_err_count = 0
        self.sup_state = SUP_S_OFF
        self.spi_enable  = 1     # reset: the host does not veto the converter
        self.wd_restored = 0     # set only by the watchdog (not modelled yet)
        self.timestamp_ms = 0    # what the test is driving into timestamp_ms
        self.wd_mark      = 0    # timestamp of the last proof the host is alive
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

    def apply_write(self, address, data_bytes, crc_ok=True):
        """
        Purpose: It predicts the effect of one write transaction:
                 a bad CRC discards everything and counts one bus error
                .Otherwise each byte goes to address + offset, and writes commit only at the end.
        """

        pending_scratch = None
        unlocked = False # Write key: this transaction only
        staged = {} 
        disable_armed = False    # disable key: this transaction only
        en_pending    = None     # CONTROL change to apply at commit; None = no change

        if not crc_ok:
            self.bus_err_count = min(self.bus_err_count + 1, 0xFFFF)
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

        if staged:
            # ---- decide: one pass over every register, nothing changed yet ----
            rejected = not unlocked
            for name, info in THRESHOLD_BIODATA.items():
                addresses = range(info["address"], info["address"] + info["bytes"])
                written   = [a in staged for a in addresses]

                if any(written) and info["S_OFF_only"] and self.sup_state != SUP_S_OFF:
                    rejected = True     # an S_OFF-only register written outside S_OFF

                if any(written) and not all(written):
                    rejected = True     # a multi-byte register only partly written

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

                        # clamp on the way in, as reg_file does
                        self.thresholds[name] = clamp(name, raw_value)

        # any valid write is proof of life: the watchdog re-marks
        self.wd_mark = self.timestamp_ms