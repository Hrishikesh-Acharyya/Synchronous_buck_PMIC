# Simulation and lint for the CPLD supervisor.
#
#   make lint   Verilator lint pass over every module  (CI runs this)
#   make sim    ModelSim build + run of the testbench  (local only)
#   make wave   open the waveform
#   make clean  remove build outputs
#
# CI runs lint only. The testbench uses clocking blocks and ##() cycle
# delays: Icarus 12.0 does not support clocking blocks at all, and
# Verilator 5.020 takes an internal fault on ##() inside an automatic task.
# ModelSim handles both, so simulation is a local step.

VERILATOR ?= verilator
VLOG      ?= vlog
VSIM      ?= vsim
VIEWER    ?= gtkwave

# Package first: it defines state_t, which supervisor imports.
RTL := ../rtl/pkg/pmic_types_pkg.sv \
       ../rtl/clk_rst/reset_sync.sv \
       ../rtl/inputs/input_sync.sv \
       ../rtl/protect/soft_start.sv \
       ../rtl/protect/pwm_mask.sv \
       ../rtl/protect/fault_arbiter.sv \
       ../rtl/protect/hiccup_timer.sv \
       ../rtl/protect/strike_counter.sv \
       ../rtl/status/pgood_gen.sv \
       ../rtl/supervisor.sv

TB  := ../tb/supervisor_tb.sv
VCD := supervisor.vcd

# Each module is linted as its own top, since there is no pmic_top yet to
# elaborate them together. Collapse to a single --top-module pmic_top once
# that exists - that is also the only way port width mismatches between
# modules get caught.
LINT_TOPS := supervisor reset_sync input_sync soft_start pwm_mask \
             fault_arbiter hiccup_timer strike_counter pgood_gen

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