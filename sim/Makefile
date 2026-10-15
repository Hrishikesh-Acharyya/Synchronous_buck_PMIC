# Simulation and lint for the CPLD supervisor.
#
#   make lint   Verilator lint pass over every module  (CI runs this)
#   make sim    ModelSim build + run of the testbench  (local only)
#   make wave   open the waveform
#   make clean  remove build outputs
#
# CI runs lint only. The testbench uses clocking blocks and ##() cycle
# delays: Icarus 12.0 does not support clocking blocks at all.

VERILATOR ?= verilator
VLOG      ?= vlog
VSIM      ?= vsim
VIEWER    ?= gtkwave

# Package first: it defines state_t, which supervisor imports.
RTL := ../rtl/pkg/pmic_types_pkg.sv \
       ../rtl/clk_rst/reset_sync.sv \
       ../rtl/inputs/input_sync.sv \
			 ../rtl/inputs/input_debounce.sv \
       ../rtl/protect/soft_start.sv \
       ../rtl/protect/pwm_mask.sv \
       ../rtl/protect/fault_arbiter.sv \
       ../rtl/protect/hiccup_timer.sv \
       ../rtl/protect/strike_counter.sv \
       ../rtl/status/pgood_gen.sv \
			 ../rtl/status/timestamp.sv \
			 ../rtl/status/fault_LED.sv \
			 ../rtl/telemetry/pwm_stats.sv \
			 ../rtl/telemetry/reg_file.sv \
			 ../rtl/telemetry/spi_slave.sv \
			 ../rtl/telemetry/fault_cause.sv \
       ../rtl/supervisor.sv \
       ../rtl/pmic_top.sv

TB  := ../tb/supervisor_tb.sv
VCD := supervisor.vcd

# Single top: elaborating the whole hierarchy is the only way port width
# mismatches between modules get caught.
LINT_TOPS := pmic_top


# WIDTHEXPAND: benign zero-extension of 1-bit operands into wider counters
#              and of int parameters into sized comparisons. TODO: size the
#              operands and drop this waiver.
# UNUSEDPARAM: package parameters whose consumers are not in scope with
#              per-module tops. Should clear once pmic_top elaborates.
LINT_WAIVERS := -Wno-WIDTHEXPAND -Wno-UNUSEDPARAM

.PHONY: all lint sim wave clean

all: lint

# Uses if/else rather than `command -v verilator && verilator ... || echo`:
# in the latter form a lint failure falls through to the fallback branch and
# make still exits 0, masking the error. The `|| exit 1` inside the loop is
# there for the same reason.
lint:
	@if command -v $(VERILATOR) >/dev/null 2>&1; then \
	  for top in $(LINT_TOPS); do \
	    echo "--- linting $$top ---"; \
	    $(VERILATOR) --lint-only -Wall $(LINT_WAIVERS) $(RTL) \
	      --top-module $$top || exit 1; \
	  done; \
	  echo "--- lint passed ---"; \
	else \
	  echo "verilator not installed - skipping lint"; \
	fi

sim:
	@if command -v $(VLOG) >/dev/null 2>&1; then \
	  $(VLOG) -sv $(RTL) $(TB) && \
	  $(VSIM) -c -do "run -all; quit -f" supervisor_tb; \
	else \
	  echo "ModelSim not on PATH - simulation is a local step, see header"; \
	  exit 1; \
	fi

wave:
	$(VIEWER) $(VCD) &

clean:
	rm -f $(VCD) transcript vsim.wlf
	rm -rf work


# ============================================================
# Verilator testbenches
# ============================================================
# Each testbench gets its own target and its own build directory.
#
#   make tb_reset_sync            build + run, exit status is the verdict
#   make tb_reset_sync WAVES=1    same, but record a VCD for debug
#   make tb_clean                 remove all testbench build output
#
# Build output goes under $(HOME) rather than into the repo: this tree is
# on a Windows mount, and Verilator writes hundreds of small files that
# each cost a 9p round trip from the WSL2 side.

VFLAGS := --binary --timing --assert -Wall
TBBUILD ?= $(HOME)/build/sync_buck

# PKG: compiled first wherever a testbench imports it. reset_sync does not.
PKG := ../rtl/pkg/pmic_types_pkg.sv

.PHONY: tb_reset_sync tb_clean

tb_reset_sync: TOP  := reset_sync_tb
tb_reset_sync: SRCS := ../rtl/clk_rst/reset_sync.sv ../tb/clk_rst/reset_sync_tb.sv
tb_reset_sync:
	rm -rf $(TBBUILD)/$(TOP)
	mkdir -p $(TBBUILD)/$(TOP)
	$(VERILATOR) $(VFLAGS) --Mdir $(TBBUILD)/$(TOP) --top-module $(TOP) $(SRCS)
	$(TBBUILD)/$(TOP)/V$(TOP) $(if $(WAVES),+WAVES)

tb_clean:
	rm -rf $(TBBUILD)