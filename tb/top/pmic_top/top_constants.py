#
# Filename:         top_constants.py
#
# File Description: Constants for the pmic_top testbench: the board model's
#                   timing, the RTL timings the tests wait out, and the short
#                   timer configuration the tests program over SPI. Each value
#                   mirrors a definition in pmic_types_pkg.sv, pmic_top.sv or
#                   pmic_top_harness.sv; the source is named beside it, and a
#                   change there must be repeated here. Register addresses and
#                   key values come from host_if_constants.py.
#
# Global variables: All names below are module-level constants.

# ==============================================================================
# Clock and board model
# ==============================================================================

# CLK_PERIOD_NS: supervisor clock period - CLK_HZ = 50 MHz in pmic_types_pkg
CLK_PERIOD_NS = 20
# OSC_PERIOD_CLKS: modulator period - pmic_top_harness OSC_PERIOD_CLKS (450 kHz)
OSC_PERIOD_CLKS = 111
# OSC_ON_NOMINAL: modulator on-time used by default, about 45 % duty - well
#                 inside the soft-start ceiling, so pwm_mask passes it whole
OSC_ON_NOMINAL = 50
# OSC_ON_ABOVE_CEILING: an on-time beyond MAX_ON (83 clocks), so pwm_mask cuts it
OSC_ON_ABOVE_CEILING = 100
# MAX_ON_COUNTS: the on-time ceiling after soft start - duty_to_counts(75)
MAX_ON_COUNTS = 83
# RESET_PRESS_CLKS: how long the test holds the reset button
RESET_PRESS_CLKS = 20

# ==============================================================================
# RTL timings the tests wait out (pmic_types_pkg, pmic_top)
# ==============================================================================

# SWITCH_DEBOUNCE_MS: the enable switch's debounce, both edges - pmic_top
#                     instances input_debounce at ms_to_clks(20) for it
SWITCH_DEBOUNCE_MS = 20
# FAULT_ASSERT_MS: OTP / UVLO / latch read-back debounce to assert
FAULT_ASSERT_MS = 1
# FAULT_RELEASE_MS: the same flags' debounce to release - 200 us
FAULT_RELEASE_MS = 0.2
# PGOOD_DELAY_MS: the rail must be good this long in S_RUN before PGOOD
PGOOD_DELAY_MS = 9

# ==============================================================================
# Fast timers, programmed over SPI before each test switches the converter on
# ==============================================================================

# FAST_HICCUP_BASE: 1 ms of clocks - the smallest hiccup base reg_file accepts
FAST_HICCUP_BASE = 50_000
# FAST_HICCUP_MS: the same, in ms; strike n waits FAST_HICCUP_MS << n
FAST_HICCUP_MS = 1
# FAST_CYCLES_PER_STEP: one switching cycle per soft-start step - the shortest
#                       ramp, about 71 cycles (0.16 ms)
FAST_CYCLES_PER_STEP = 1
# FAST_CLEAN_RUN: 100 ms of switching cycles - the shortest clean-run window
FAST_CLEAN_RUN = 45_000
# FAST_CLEAN_RUN_MS: the same, in ms
FAST_CLEAN_RUN_MS = 100
# MAX_STRIKES: strikes before the latch trips - the reset default
MAX_STRIKES = 3

# ==============================================================================
# Settle times: how long a test waits for a board event to have its full
# effect, with margin. Derived from the timings above and the fast timers.
# ==============================================================================

# SETTLE_START_MS: switch on to S_RUN - debounce, then the fast ramp
SETTLE_START_MS = SWITCH_DEBOUNCE_MS + 2
# SETTLE_PGOOD_MS: S_RUN to PGOOD
SETTLE_PGOOD_MS = PGOOD_DELAY_MS + 1
# SETTLE_FAULT_MS: a fault flag, set or cleared, to the state that follows it
SETTLE_FAULT_MS = FAULT_ASSERT_MS + 1
# SETTLE_HICCUP_MS: one overcurrent trip to back in S_RUN at strike level 1
SETTLE_HICCUP_MS = 2 * FAST_HICCUP_MS + 2
# SETTLE_LATCH_MS: a persistent overcurrent to the latch - three trips and the
#                  1 + 2 ms cool-downs between them, then the latch read-back
SETTLE_LATCH_MS = (1 + 2) * FAST_HICCUP_MS + FAULT_ASSERT_MS + 4
