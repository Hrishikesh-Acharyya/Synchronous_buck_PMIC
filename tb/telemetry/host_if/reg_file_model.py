
from host_if_constants import ADDR_SCRATCH



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

    def apply_write(self, address, data_bytes, crc_ok=True):
        """
        Purpose: The docstring says it predicts the effect of one write transaction:
                 a bad CRC discards everything and counts one bus error
                .Otherwise each byte goes to address + offset, and writes commit only at the end.
        """

        pending_scratch = None

        if not crc_ok:
            self.bus_err_count = min(self.bus_err_count + 1, 0xFFFF)
            return

        for offset,value in enumerate(data_bytes):
            register_address = (address + offset) & 0xF7
            pending_scratch = value

        if pending_scratch is not None:
            self.scratch = pending_scratch

