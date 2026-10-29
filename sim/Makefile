# Simulation and lint for the CPLD supervisor.
#
#   make lint                     Verilator lint pass over the RTL  (CI runs this)
#   make sim                      ModelSim build + run of supervisor_tb  (local only)
#   make clean                    remove build outputs
#
#   make tb_<module>              build + run a Verilator testbench; exit status
#                                 is the verdict, cover hits printed after
#   make tb_<module> WAVES=1      same, plus a VCD for debug
#   make wave_<module>            build + run with WAVES=1, then open GTKWave
#   make tb_wave TOP=<top>        open the last VCD for that top
#   make tb_cov  TOP=<top>        re-list cover hits; fails on any zero-hit cover
#   make tb_clean                 remove all testbench build output
#   make tb_all                   run every testbench against the SV source
#
#   make equiv_all                tb_all, then every equivalence run
#   make convert                  sv2v the RTL to one Verilog-2005 file
#   make syn                      synthesise it, print cell and flop counts
#   make syn_area                 sky130-mapped area (needs LIBERTY)
#   make equiv                    run the SV testbenches against the converted RTL
#   make syn_clean                remove conversion and synthesis output
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

# EQUIV_WAIVERS: warnings that fire only on the converted file, never on the
#                SystemVerilog source. Kept separate from LINT_WAIVERS so the
#                pass over ../rtl stays strict.
#
# DECLFILENAME: sv2v emits every module into a single file, so all but one of
#               them disagree with the filename by construction.
# WIDTHTRUNC:   sv2v renders a SystemVerilog width cast as a generated
#               function sized to the target width, then passes the 32-bit int
#               parameter into it. The narrowing is exactly what the original
#               CNT_W'(ASSERT_CLKS) asked for, but Verilator sees a width
#               mismatch at the function boundary. Safe to waive here only
#               because the source is checked strictly - this is the warning
#               that caught the TARGET assignment in pgood_gen.
EQUIV_WAIVERS := -Wno-DECLFILENAME -Wno-WIDTHTRUNC

.PHONY: all lint sim clean

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

clean:
	rm -f transcript vsim.wlf
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
# --trace:         compile in VCD support. Without it $dumpvars is silently
#                  a no-op and WAVES=1 produces nothing.
# --assert:        default since Verilator 5.038; kept as documentation.
VFLAGS := --binary --timing --assert --no-stop-fail --coverage-user --trace -Wall \
          $(LINT_WAIVERS) $(TB_WAIVERS)
TBBUILD ?= $(HOME)/build/sync_buck
# WAVEDIR: saved GTKWave signal selections, one per testbench top. Kept outside
#          the build dir so tb_clean does not destroy them.
WAVEDIR ?= $(HOME)/gtkwave

.PHONY: tb_reset_sync tb_input_sync tb_input_debounce tb_pwm_mask \
        tb_pgood_gen tb_timestamp tb_fault_LED tb_pwm_stats

tb_reset_sync: TOP  := reset_sync_tb
tb_reset_sync: SRCS := $(RTL) $(SVA_SRCS) ../tb/clk_rst/reset_sync_tb.sv
tb_reset_sync: run_tb

tb_input_sync: TOP  := input_sync_tb
tb_input_sync: SRCS := $(RTL) $(SVA_SRCS) ../tb/inputs/input_sync_tb.sv
tb_input_sync: run_tb

tb_input_debounce: TOP  := input_debounce_tb
tb_input_debounce: SRCS := $(RTL) $(SVA_SRCS) ../tb/inputs/input_debounce_tb.sv
tb_input_debounce: run_tb

tb_pwm_mask: TOP  := pwm_mask_tb
tb_pwm_mask: SRCS := $(RTL) $(SVA_SRCS) ../tb/protect/pwm_mask_tb.sv
tb_pwm_mask: run_tb 

tb_pgood_gen: TOP  := pgood_gen_tb
tb_pgood_gen: SRCS := $(RTL) $(SVA_SRCS) ../tb/status/pgood_gen_tb.sv
tb_pgood_gen: run_tb 

tb_timestamp: TOP  := timestamp_tb
tb_timestamp: SRCS := $(RTL) $(SVA_SRCS) ../tb/status/timestamp_tb.sv
tb_timestamp: run_tb

tb_fault_LED: TOP  := fault_LED_tb
tb_fault_LED: SRCS := $(RTL) $(SVA_SRCS) ../tb/status/fault_LED_tb.sv
tb_fault_LED: run_tb

tb_pwm_stats: TOP  := pwm_stats_tb
tb_pwm_stats: SRCS := $(RTL) $(SVA_SRCS) ../tb/telemetry/pwm_stats_tb.sv
tb_pwm_stats: run_tb


# run_tb: shared build-and-run recipe. Targets set TOP and SRCS and depend on
#         this, so adding a testbench is two lines rather than a copied recipe.
#         The cd puts coverage.dat and the VCD beside the model instead of in
#         sim/. Cover hits are printed after the verdict but do not fail the
#         build - a testbench under construction legitimately has covers not
#         yet reached. Use `make tb_cov TOP=...` for the strict check.
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
#         --annotate-all is required: by default verilator_coverage writes out
#         only files with MISSING coverage, so a fully-covered run produces an
#         empty directory and the grep finds nothing.
#         --annotate-min 1 marks only genuine zeros; the default of 10 would
#         flag a cover that hit three times as if it were dead.
.PHONY: tb_cov
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

# tb_wave: open the last VCD for a testbench top. Loads $(WAVEDIR)/<top>.gtkw
#          if it exists, so the signal selection, radix settings and zoom
#          survive between runs - save one from GTKWave with
#          File > Write Save File. Backgrounded so the shell returns at once;
#          stderr is dropped because WSLg emits a dconf warning on every
#          launch that has nothing to do with the trace.
.PHONY: tb_wave
tb_wave:
	@test -n "$(TOP)" || { echo "tb_wave needs TOP=<testbench top>"; exit 1; }
	@test -f $(TBBUILD)/$(TOP)/$(TOP).vcd || { \
	    echo "no VCD for '$(TOP)' - run with WAVES=1 first"; exit 1; }
	@$(VIEWER) $(TBBUILD)/$(TOP)/$(TOP).vcd \
	    $(if $(wildcard $(WAVEDIR)/$(TOP).gtkw),-a $(WAVEDIR)/$(TOP).gtkw) \
	    2>/dev/null &

# wave_<module>: build, run with tracing, and open the viewer in one command.
.PHONY: wave_reset_sync wave_input_sync wave_input_debounce wave_pwm_mask \
        wave_pgood_gen wave_timestamp wave_fault_LED wave_pwm_stats

wave_reset_sync:
	@$(MAKE) --no-print-directory tb_reset_sync WAVES=1
	@$(MAKE) --no-print-directory tb_wave TOP=reset_sync_tb

wave_input_sync:
	@$(MAKE) --no-print-directory tb_input_sync WAVES=1
	@$(MAKE) --no-print-directory tb_wave TOP=input_sync_tb

wave_input_debounce:
	@$(MAKE) --no-print-directory tb_input_debounce WAVES=1
	@$(MAKE) --no-print-directory tb_wave TOP=input_debounce_tb

wave_pwm_mask: 
	@$(MAKE) --no-print-directory tb_pwm_mask WAVES=1
	@$(MAKE) --no-print-directory tb_wave TOP=pwm_mask_tb

wave_pgood_gen: 
	@$(MAKE) --no-print-directory tb_pgood_gen WAVES=1
	@$(MAKE) --no-print-directory tb_wave TOP=pgood_gen_tb

wave_timestamp:
	@$(MAKE) --no-print-directory tb_timestamp WAVES=1
	@$(MAKE) --no-print-directory tb_wave TOP=timestamp_tb

wave_fault_LED:
	@$(MAKE) --no-print-directory tb_fault_LED WAVES=1
	@$(MAKE) --no-print-directory tb_wave TOP=fault_LED_tb

wave_pwm_stats:
	@$(MAKE) --no-print-directory tb_pwm_stats WAVES=1
	@$(MAKE) --no-print-directory tb_wave TOP=pwm_stats_tb

.PHONY: tb_clean
tb_clean:
	rm -rf $(TBBUILD)


# ============================================================
# ASIC conversion and synthesis
# ============================================================
#   make convert        sv2v the RTL into one Verilog-2005 file
#   make syn            synthesise the converted file, print cell counts
#   make syn_area       same, mapped against the sky130 liberty (needs LIBERTY)
#   make equiv_<module> run an existing SV testbench against the CONVERTED
#                       Verilog instead of the SystemVerilog source
#   make syn_clean      remove conversion and synthesis output
#
# Silicluster v3 accepts Verilog only, for both RTL and testbench, so the
# submitted source is the sv2v output rather than the tree under ../rtl.
# The equiv_ targets are the evidence that the two are the same design:
# the testbenches bind the same checkers to the same module names, so a
# pass against the converted file is a pass against what gets submitted.

SV2V     ?= sv2v
YOSYS    ?= $(HOME)/oss-cad-suite/bin/yosys

# SYNDIR: inside the repo so the converted file is visible in the editor and
#         easy to attach to a submission. Slower than $(HOME) would be - this
#         tree is a Windows mount reached over 9p - but conversion runs rarely
#         and the output is a deliverable rather than scratch.
SYNDIR   ?= ../Build
CONVERTED := $(SYNDIR)/pmic_full.v

# PKG: the package is inlined into the sv2v output and no longer exists as a
#      package there, but ../tb and ../sva still import it. Equivalence runs
#      therefore compile the package source alongside the converted RTL.
#      Taken from $(RTL) rather than repeated, so the path has one owner.
PKG      := $(firstword $(RTL))

# LIBERTY: sky130 high-density standard cells, for real area numbers. Install
#          with `volare enable --pdk sky130 <version>`. Without it, `make syn`
#          still gives exact flop counts and generic gate counts, which is
#          enough to size the design to within about 20%.
LIBERTY  ?= $(HOME)/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

.PHONY: convert
convert: $(CONVERTED)

# Order matters here exactly as it does for the simulators: the package
# defines the widths every other file elaborates against.
$(CONVERTED): $(RTL)
	@mkdir -p $(SYNDIR)
	$(SV2V) $(RTL) > $@
	@echo "--- converted: $$(wc -l < $@) lines of Verilog-2005 ---"

# -flatten: area is a whole-design number, and the per-module breakdown is
#           misleading without it - a module instantiated three times counts
#           once in the hierarchical stat.
.PHONY: syn
syn: $(CONVERTED)
	$(YOSYS) -p "read_verilog $(CONVERTED); \
	             hierarchy -top pmic_top; \
	             synth -top pmic_top -flatten; \
	             stat" > $(SYNDIR)/stat.txt 2>&1
	@awk '/^4\. Printing statistics/,0' $(SYNDIR)/stat.txt
	@echo "--- full log: $(SYNDIR)/stat.txt ---"

# dfflibmap before abc: abc maps combinational logic only, so the flops have
#                       to be bound to library cells first or they are left as
#                       generic $_DFF_ and contribute nothing to the area.
.PHONY: syn_area
syn_area: $(CONVERTED)
	@test -f $(LIBERTY) || { \
	    echo "no liberty file at $(LIBERTY)"; \
	    echo "set LIBERTY=<path>, or run: volare enable --pdk sky130 <version>"; \
	    exit 1; }
	$(YOSYS) -p "read_verilog $(CONVERTED); \
	             hierarchy -top pmic_top; \
	             synth -top pmic_top -flatten; \
	             dfflibmap -liberty $(LIBERTY); \
	             abc -liberty $(LIBERTY); \
	             opt_clean; \
	             stat -liberty $(LIBERTY)" > $(SYNDIR)/area.txt 2>&1
	@grep -E "Chip area|Number of cells" $(SYNDIR)/area.txt || \
	    { tail -40 $(SYNDIR)/area.txt; exit 1; }
	@echo "--- Silicluster v3 standard slot is 180 x 115 = 20700 um2 ---"
	@echo "--- divide chip area by 0.55 for die area at realistic utilisation ---"

# equiv_<module>: identical to tb_<module> except that $(CONVERTED) replaces
#                 $(RTL). Same testbench, same checkers, different source.
#                 Any behavioural difference sv2v introduced shows up as an
#                 assertion failure here and nowhere else.
.PHONY: equiv_reset_sync equiv_input_sync equiv_input_debounce equiv_pwm_mask \
        equiv_pgood_gen equiv_timestamp equiv_fault_LED equiv_pwm_stats

equiv_reset_sync: TOP  := reset_sync_tb
equiv_reset_sync: SRCS := $(PKG) $(CONVERTED) $(SVA_SRCS) ../tb/clk_rst/reset_sync_tb.sv
equiv_reset_sync: VFLAGS += $(EQUIV_WAIVERS)
equiv_reset_sync: $(CONVERTED) run_tb

equiv_input_sync: TOP  := input_sync_tb
equiv_input_sync: SRCS := $(PKG) $(CONVERTED) $(SVA_SRCS) ../tb/inputs/input_sync_tb.sv
equiv_input_sync: VFLAGS += $(EQUIV_WAIVERS)
equiv_input_sync: $(CONVERTED) run_tb

equiv_input_debounce: TOP  := input_debounce_tb
equiv_input_debounce: SRCS := $(PKG) $(CONVERTED) $(SVA_SRCS) ../tb/inputs/input_debounce_tb.sv
equiv_input_debounce: VFLAGS += $(EQUIV_WAIVERS)
equiv_input_debounce: $(CONVERTED) run_tb

equiv_pwm_mask: TOP  := pwm_mask_tb
equiv_pwm_mask: SRCS := $(PKG) $(CONVERTED) $(SVA_SRCS) ../tb/protect/pwm_mask_tb.sv
equiv_pwm_mask: VFLAGS += $(EQUIV_WAIVERS)
equiv_pwm_mask: $(CONVERTED) run_tb

equiv_pgood_gen: TOP  := pgood_gen_tb
equiv_pgood_gen: SRCS := $(PKG) $(CONVERTED) $(SVA_SRCS) ../tb/status/pgood_gen_tb.sv
equiv_pgood_gen: VFLAGS += $(EQUIV_WAIVERS)
equiv_pgood_gen: $(CONVERTED) run_tb

equiv_timestamp: TOP  := timestamp_tb
equiv_timestamp: SRCS := $(PKG) $(CONVERTED) $(SVA_SRCS) ../tb/status/timestamp_tb.sv
equiv_timestamp: VFLAGS += $(EQUIV_WAIVERS)
equiv_timestamp: $(CONVERTED) run_tb

equiv_fault_LED: TOP  := fault_LED_tb
equiv_fault_LED: SRCS := $(PKG) $(CONVERTED) $(SVA_SRCS) ../tb/status/fault_LED_tb.sv
equiv_fault_LED: VFLAGS += $(EQUIV_WAIVERS)
equiv_fault_LED: $(CONVERTED) run_tb

equiv_pwm_stats: TOP  := pwm_stats_tb
equiv_pwm_stats: SRCS := $(PKG) $(CONVERTED) $(SVA_SRCS) ../tb/telemetry/pwm_stats_tb.sv
equiv_pwm_stats: VFLAGS += $(EQUIV_WAIVERS)
equiv_pwm_stats: $(CONVERTED) run_tb

# equiv: every equivalence run in sequence. Recursive rather than a
#        prerequisite list: run_tb is phony, so Make would build it once and
#        skip it for every target after the first.
.PHONY: equiv
equiv:
	@for t in equiv_reset_sync equiv_input_sync equiv_input_debounce \
	          equiv_pwm_mask equiv_pgood_gen equiv_timestamp equiv_fault_LED equiv_pwm_stats; do \
	    echo "=== $$t ==="; \
	    $(MAKE) --no-print-directory $$t || exit 1; \
	done
	@echo "--- all equivalence runs passed ---"

# tb_all: the same for the SystemVerilog source runs.
.PHONY: tb_all
tb_all:
	@for t in tb_reset_sync tb_input_sync tb_input_debounce \
	          tb_pwm_mask tb_pgood_gen tb_timestamp tb_fault_LED tb_pwm_stats; do \
	    echo "=== $$t ==="; \
	    $(MAKE) --no-print-directory $$t || exit 1; \
	done
	@echo "--- all testbenches passed ---"

# equiv_all: both, for the pre-submission gate.
.PHONY: equiv_all
equiv_all: tb_all equiv