# Simulation and lint for the CPLD supervisor.
#
#   make lint                     Verilator lint pass over the RTL  (CI runs this)
#   make sim                      ModelSim build + run of supervisor_tb  (local only)
#   make wave                     open the supervisor_tb waveform
#   make clean                    remove build outputs
#
#   make tb_<module>              build + run a Verilator testbench; exit status
#                                 is the verdict, cover hits printed after
#   make tb_<module> WAVES=1      same, plus a VCD for debug
#   make tb_cov TOP=<top>         re-list cover hits; fails on any zero-hit cover
#   make tb_clean                 remove all testbench build output
#
# CI runs lint only. supervisor_tb uses clocking blocks and ##() cycle delays:
# Icarus 12.0 does not support clocking blocks at all.

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

# SVA_SRCS: bound assertion checkers, compiled into every testbench target.
#           Order matters - sva_pkg defines note_failure() and must precede the
#           checkers that call it; bind_sva.sv names the checkers and must
#           follow them. Never added to LINT_TOPS or any synthesis path, which
#           is the point of bind: the RTL carries no assertion constructs.
SVA_SRCS := ../sva/sva_pkg.sv \
            $(wildcard ../sva/*/*.sv) \
            ../sva/bind_sva.sv

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

# TB_WAIVERS: warnings that are artefacts of simulation-only code rather than
#             design problems. Kept separate from LINT_WAIVERS so the CI lint
#             pass over the RTL stays strict.
#
# SYNCASYNCNET: rst_n is asynchronous in the RTL flops and sampled
#               synchronously by the SVA properties. A bound checker is an
#               observer, not hardware, so there is no reset-domain hazard.
#               Fires from every checker that references rst_n.
TB_WAIVERS := -Wno-SYNCASYNCNET

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
# Every target compiles the full RTL list, not just the module under test:
# bind_sva.sv names every checker target by module, and a bind to a module
# that was never compiled is an elaboration error. Verilator elaborates only
# what is reachable from --top-module, so the cost is parse time.
#
# Build output goes under $(HOME) rather than into the repo: this tree is
# on a Windows mount, and Verilator writes hundreds of small files that
# each cost a 9p round trip from the WSL2 side. The rm -rf is deliberate -
# Verilator's timestamp-based incremental logic is unreliable across 9p and
# has repeatedly handed back stale binaries.

# --no-stop-fail:  Verilator's runtime error limit defaults to 1, so without
#                  this the first assertion failure ends the run and every
#                  later one is lost. The verdict block owns the exit status.
# --coverage-user: collect cover property hits into coverage.dat.
# --assert:        default since Verilator 5.038; kept as documentation.
VFLAGS := --binary --timing --assert --no-stop-fail --coverage-user -Wall \
          $(LINT_WAIVERS) $(TB_WAIVERS)
TBBUILD ?= $(HOME)/build/sync_buck

.PHONY: tb_reset_sync tb_input_sync tb_cov tb_clean

tb_reset_sync: TOP  := reset_sync_tb
tb_reset_sync: SRCS := $(RTL) $(SVA_SRCS) ../tb/clk_rst/reset_sync_tb.sv
tb_reset_sync: run_tb

tb_input_sync: TOP  := input_sync_tb
tb_input_sync: SRCS := $(RTL) $(SVA_SRCS) ../tb/inputs/input_sync_tb.sv
tb_input_sync: run_tb

# run_tb: shared build-and-run recipe. Targets set TOP and SRCS and depend on
#         this, so adding a testbench is two lines rather than a copied recipe.
#         The cd puts coverage.dat beside the model instead of in sim/.
#         Cover hits are printed after the verdict but do not fail the build -
#         a testbench under construction legitimately has covers not yet
#         reached. Use `make tb_cov TOP=...` for the strict check.
.PHONY: run_tb
run_tb:
	rm -rf $(TBBUILD)/$(TOP)
	mkdir -p $(TBBUILD)/$(TOP)
	$(VERILATOR) $(VFLAGS) --Mdir $(TBBUILD)/$(TOP) --top-module $(TOP) $(SRCS)
	cd $(TBBUILD)/$(TOP) && ./V$(TOP) $(if $(WAVES),+WAVES)
	-@$(MAKE) --no-print-directory tb_cov TOP=$(TOP)

# tb_cov: annotate the last run's coverage and list every cover directive with
#         its hit count. A zero-hit cover means the matching assertion never
#         evaluated on this run, so its pass proves nothing - hence the
#         non-zero exit, which makes this usable as a CI gate. Verilator does
#         not expose cover counts to SystemVerilog, so the verdict block inside
#         the testbench cannot make this check itself.
#         --annotate-min 1 marks only genuine zeros; the default of 10 would
#         flag a cover that hit three times as if it were dead.
tb_cov:
	@test -n "$(TOP)" || { echo "tb_cov needs TOP=<testbench top>"; exit 1; }
	@test -f $(TBBUILD)/$(TOP)/coverage.dat || { \
	    echo "no coverage.dat for '$(TOP)' - run the testbench first"; exit 1; }
	@rm -rf $(TBBUILD)/$(TOP)/annotated
	@verilator_coverage --annotate $(TBBUILD)/$(TOP)/annotated \
	    --annotate-all --annotate-min 1 \
	    $(TBBUILD)/$(TOP)/coverage.dat > /dev/null
	@echo "--------------------------------------------------"
	@echo "cover directives - $(TOP)"
	@echo "--------------------------------------------------"
	@grep -rh "cover property" $(TBBUILD)/$(TOP)/annotated/ \
	    | sed 's/^[[:space:]]*//' || true
	@echo "--------------------------------------------------"
	@if ! grep -rhq "cover property" $(TBBUILD)/$(TOP)/annotated/; then \
	    echo "NO COVER DIRECTIVES FOUND - nothing proves the assertions ran"; \
	    exit 1; \
	elif grep -rhq "%000000.*cover property" $(TBBUILD)/$(TOP)/annotated/; then \
	    echo "ZERO-HIT COVERS - the assertions above them proved nothing"; \
	    exit 1; \
	else \
	    echo "all cover directives hit"; \
	fi

tb_clean:
	rm -rf $(TBBUILD)