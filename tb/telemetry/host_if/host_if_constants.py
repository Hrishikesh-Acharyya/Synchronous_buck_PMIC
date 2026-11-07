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
ADDR_TRIP_RUN = 0x50