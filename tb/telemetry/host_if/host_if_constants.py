#
# Filename:         host_if_constants.py
#
# File Description: Constants shared by the host interface testbench: clock
#                   and SPI timing, the register addresses and key values of
#                   reg_file, spi_slave's FSM encoding and the supervisor
#                   state encoding. Every value mirrors a definition in the
#                   RTL (pmic_types_pkg.sv, reg_file.sv, spi_slave.sv) or in
#                   host_if_wrapper.sv; the source is named beside each one,
#                   and a change there must be repeated here.
#
# Global variables: All names below are module-level constants.

# ==============================================================================
# Clock, reset and SPI timing
# ==============================================================================

# CLK_PERIOD_NS: supervisor clock period - CLK_HZ = 50 MHz in pmic_types_pkg
CLK_PERIOD_NS = 20
# RESET_CLKS: clocks rst_n is held low at the start of every test
RESET_CLKS = 5
# IDLE_CLKS: settle time after reset or after a transaction before anything is
#            checked. Longer than the input path (2-flop synchroniser + 8-clock
#            filter = 10 clocks), so every pin change has reached spi_slave
#            and the bound checkers.
IDLE_CLKS = 100
# SCK_HALF_PERIOD_NS: SCK high time and low time - 1 MHz, the design point in
#                     pmic_top. SCK is asynchronous to clk, so it is timed in
#                     ns, never in clk cycles. 500 ns clears both the 160 ns
#                     filter window and the ~220 ns MISO turnaround (2 sync +
#                     8 filter + 1 clock after a falling edge, before the
#                     master samples on the next rising edge).
SCK_HALF_PERIOD_NS = 500
# SCK_HALF_PERIODS: SCK speeds random_walk picks from. 500 ns is the 1 MHz
#                   maximum; slower hosts are legal. Each is a multiple of
#                   CLK_PERIOD_NS (drives stay off rising clk edges) and well
#                   below the wrapper's SCK timeout (100 clocks = 2000 ns), so
#                   a slow host is never mistaken for a dead one.
SCK_HALF_PERIODS = [500, 600, 760, 1000, 1500]
# SCK_TIMEOUT_NS: spi_slave's SCK idle timeout in this testbench -
#                 host_if_wrapper's SCK_IDLE_TIMEOUT_CLKS (100) x CLK_PERIOD_NS.
#                 Keep in step with the wrapper.
SCK_TIMEOUT_NS = 100 * CLK_PERIOD_NS
# SCK_PAUSE_NS: an SCK stall long enough to send spi_slave to S_DEAD - twice
#               the timeout
SCK_PAUSE_NS = 2 * SCK_TIMEOUT_NS
# ARM_LAPSE_NS: a stall past reg_file's key arm timer (2^16 clocks = 1.31 ms),
#               with margin
ARM_LAPSE_NS = 1_400_000

# ==============================================================================
# SPI protocol
# ==============================================================================

# READ_FLAG: command bit 7 set - a read command
READ_FLAG = 0x80
# WRITE_MASK: command bit 7 clear - a write command
WRITE_MASK = 0x7F
# CRC8_POLY: CRC-8/SMBUS polynomial, as spi_slave computes it
CRC8_POLY = 0x07

# ==============================================================================
# reg_file register map and key values (reg_file.sv)
# ==============================================================================

# ADDR_PMIC_ID / PMIC_ID: identity register and its fixed value
ADDR_PMIC_ID = 0x00
PMIC_ID = 0xB5
# VERSION_ID: register-map version at 0x01
VERSION_ID = 0x01
# CAPABILITY_VAL: CAPABILITY byte at 0x02 (build configuration)
CAPABILITY_VAL = 0x3D
# ADDR_SCRATCH: read/write byte with no side effect; used as the heartbeat
ADDR_SCRATCH = 0x03
# ADDR_STATUS: STATUS, first byte of the telemetry block
ADDR_STATUS = 0x10
# ADDR_TIME_0: timestamp_ms byte 0; bytes 1-2 follow at 0x19-0x1A
ADDR_TIME_0 = 0x18
# ADDR_BUS_ERR_L / ADDR_BUS_ERR_H: bus-error counter, low and high byte
ADDR_BUS_ERR_L = 0x1B
ADDR_BUS_ERR_H = 0x1C
# ADDR_FAULT_CAUSE: start of the four-byte fault record 0x1D-0x20
ADDR_FAULT_CAUSE = 0x1D
# ADDR_FTIME_2: top byte of the fault record; a read covering it clears the record
ADDR_FTIME_2 = 0x20
# TELEMETRY_BYTES: STATUS 0x10 through FTIME_2 0x20, read as one burst
TELEMETRY_BYTES = 17
# ADDR_DISABLE_KEY / DISABLE_KEY: the key that arms a host disable; it sits
#                                 one below CONTROL so key and command share a frame
ADDR_DISABLE_KEY = 0x40
DISABLE_KEY = 0xD1
# ADDR_CONTROL: CONTROL register; bit 0 is the host enable
ADDR_CONTROL = 0x41
# ADDR_WRITE_KEY / WRITE_KEY: the key that unlocks the threshold bank; it sits
#                             one below the first threshold
ADDR_WRITE_KEY = 0x4F
WRITE_KEY = 0xA7
# ADDR_TRIP_RUN: first threshold register (0x50-0x5A)
ADDR_TRIP_RUN = 0x50
# WD_TIMEOUT_MS: bus-silence timeout while the host holds the veto
WD_TIMEOUT_MS = 5000
# TIMESTAMP_MASK: timestamp_ms is TIMESTAMP_W = 24 bits wide and wraps
TIMESTAMP_MASK = 0xFFFFFF

# ==============================================================================
# FSM encodings
# ==============================================================================

# S_IDLE .. S_DEAD: spi_slave's transaction states (spi_slave.sv)
S_IDLE  = 0
S_CMD   = 1
S_WRITE = 2
S_TURN  = 3
S_READ  = 4
S_DEAD  = 5

# SUP_S_*: supervisor state_t encoding (pmic_types_pkg.sv), driven on sup_state
SUP_S_OFF    = 0
SUP_S_SS     = 1
SUP_S_RUN    = 2
SUP_S_HICCUP = 3

# ==============================================================================
# Wrapper ports
# ==============================================================================

# STATUS_INPUTS: the reg_file status inputs host_if_wrapper exposes as ports;
#                tb_utils drives them all idle at the start of every test
STATUS_INPUTS = ["CP_sync", "OTP_sync_db", "UVLO_sync_db", "latch_stat_sync_db",
                 "en_from_switch_sync_db", "en_switch_rise", "strike_level", "duty_count",
                 "prev_period", "timestamp_ms", "fault_time", "sup_state", "fault_count_run",
                 "fault_count_ss", "fault_reg", "PGOOD"]
