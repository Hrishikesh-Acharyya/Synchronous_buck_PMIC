#
# Filename:         Makefile
#
# File Description: Lint, simulation, equivalence and synthesis for the CPLD
#                   supervisor. Run from sim/. `make help` lists everything.
#
#                   Every testbench target is GENERATED from the one list in
#                   TESTBENCHES below - adding a module is one line there, not
#                   four hand-copied blocks. The build-run-gate logic lives in
#                   scripts/run_tb.sh, and the suite table in
#                   scripts/report.sh.
#
#                   Suite runs parallelise: `make -j8 tb_all`. Each testbench
#                   has its own build directory per flow, so tb_ and equiv_
#                   runs of the same module never collide.
#
# Global variables: TESTBENCHES - the module list every per-module target is
#                                 generated from
#                   QUIET, NOFAIL, STRICT, WAVES - run modes, passed to
#                                 run_tb.sh; see the TESTBENCHES section

SHELL := /bin/bash

# --output-sync: under -j, hold each target's output until it finishes so
#                parallel runs do not interleave line by line. No effect on
#                a serial run.
MAKEFLAGS += --output-sync=target --no-print-directory

# all: kept as the default goal so a bare `make` (and anything in CI that
#      calls it) still means lint, exactly as before the overhaul.
.DEFAULT_GOAL := all

# ============================================================
# Tools and paths
# ============================================================
VERILATOR          ?= verilator
VERILATOR_COVERAGE ?= verilator_coverage
VIEWER             ?= gtkwave
SV2V               ?= sv2v
YOSYS              ?= $(HOME)/oss-cad-suite/bin/yosys

SCRIPTS := scripts

# TBBUILD: under $(HOME), not in the repo. This tree is a Windows mount and
#          Verilator writes hundreds of small files, each a 9p round trip.
#          Layout is $(TBBUILD)/<flow>/<top>, flow being sv or equiv.
TBBUILD ?= $(HOME)/build/sync_buck

# WAVEDIR: saved GTKWave selections, one <top>.gtkw per testbench. Outside
#          TBBUILD so tb_clean does not destroy them.
WAVEDIR ?= $(HOME)/gtkwave

# SYNDIR: inside the repo so the converted file is visible in the editor and
#         easy to attach to a submission. Slower over 9p, but conversion runs
#         rarely and the output is a deliverable rather than scratch.
SYNDIR    ?= ../Build
CONVERTED := $(SYNDIR)/pmic_full.v

# LIBERTY: sky130 high-density cells for real area numbers. Install with
#          `volare enable --pdk sky130 <version>`.
LIBERTY ?= $(HOME)/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# ============================================================
# Sources
# ============================================================
# Package first: it defines the widths and state_t every other file
# elaborates against.
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

# PKG: inlined into the sv2v output and gone as a package there, but tb/ and
#      sva/ still import it, so equivalence runs compile it alongside the
#      converted RTL. Taken from RTL so the path has one owner.
PKG := $(firstword $(RTL))

# SVA_SRCS: bound checkers, compiled into every testbench. Order matters -
#           sva_pkg defines note_failure() and must come first; bind_sva.sv
#           names the checkers and must come last. Never in any lint or
#           synthesis path: the point of bind is that RTL carries no SVA.
SVA_SRCS := ../sva/sva_pkg.sv \
            $(filter-out ../sva/sva_pkg.sv ../sva/bind_sva.sv,$(wildcard ../sva/*/*.sv)) \
            ../sva/bind_sva.sv

# ============================================================
# Verilator flags and waivers
# ============================================================
# LINT_WAIVERS: applied to the strict RTL lint and to every simulation.
#   WIDTHEXPAND: benign zero-extension of 1-bit operands into wider counters
#                and of int parameters into sized comparisons. TODO: size
#                the operands and drop this waiver.
#   UNUSEDPARAM: package parameters whose consumers are out of scope under
#                per-module tops.
LINT_WAIVERS := -Wno-WIDTHEXPAND -Wno-UNUSEDPARAM

# TB_WAIVERS: artefacts of simulation-only code, kept out of the RTL lint.
#   SYNCASYNCNET: rst_n is async in the RTL and sampled synchronously by the
#                 checkers. A bound checker is an observer, not hardware.
TB_WAIVERS := -Wno-SYNCASYNCNET

# EQUIV_WAIVERS: fire only on the converted file, never on the SV source.
#   DECLFILENAME: sv2v emits every module into one file by construction.
#   WIDTHTRUNC:   sv2v renders a width cast as a generated function and
#                 passes the 32-bit parameter into it. Safe to waive here only
#                 because the source is checked strictly - this is the
#                 warning that caught the TARGET assignment in pgood_gen.
EQUIV_WAIVERS := -Wno-DECLFILENAME -Wno-WIDTHTRUNC

# VFLAGS:
#   --no-stop-fail:  the runtime error limit defaults to 1; without this the
#                    first assertion failure ends the run.
#   --coverage-user: cover property hits into coverage.dat.
#   --trace:         VCD support; without it $dumpvars is silently a no-op.
#   --assert:        default since 5.038, kept as documentation.
VFLAGS := --binary --timing --assert --no-stop-fail --coverage-user --trace \
          -Wall $(LINT_WAIVERS) $(TB_WAIVERS)

# Single lint top: elaborating the whole hierarchy is the only way port
# width mismatches between modules get caught.
LINT_TOPS := pmic_top

# ============================================================
# TESTBENCHES - the single source of truth
# ============================================================
# One entry per module, as <rtl subfolder>/<module>. From each entry the
# Makefile derives the testbench file ../tb/<entry>_tb.sv, the top
# <module>_tb, and these targets:
#
#   tb_<module>     build + run against the SV source
#   equiv_<module>  same testbench + checkers against the sv2v output
#   wave_<module>   tb_<module> with a VCD, then open GTKWave
#   view_<module>   open the last VCD without re-running
#   cov_<module>    re-list the last run's cover hits
#
# Run modes, settable on the command line:
#   QUIET=1   logs to file only, one status line per testbench
#   STRICT=1  INCONCLUSIVE (a zero-hit cover) fails like FAIL does - for CI
#   NOFAIL=1  individual runs always exit 0; the suite report decides
#   WAVES=1   dump a VCD
# Suite targets set QUIET and NOFAIL themselves, and make passes
# target-specific values down to every prerequisite.
TESTBENCHES := clk_rst/reset_sync \
               inputs/input_sync \
               inputs/input_debounce \
               protect/pwm_mask \
               status/pgood_gen \
               status/timestamp \
               status/fault_LED \
               telemetry/pwm_stats

QUIET  ?= 0
STRICT ?= 0
NOFAIL ?= 0
WAVES  ?= 0

TB_MODULES := $(notdir $(TESTBENCHES))
TB_TOPS    := $(addsuffix _tb,$(TB_MODULES))

# run_tb: $(1) top, $(2) flow, $(3) sources, $(4) Verilator flags.
#         `bash script` rather than executing it, so a lost exec bit on the
#         Windows mount cannot break the build.
run_tb = VERILATOR='$(VERILATOR)' VERILATOR_COVERAGE='$(VERILATOR_COVERAGE)' \
         VFLAGS='$(4)' QUIET='$(QUIET)' WAVES='$(WAVES)' \
         NOFAIL='$(NOFAIL)' STRICT='$(STRICT)' \
         bash $(SCRIPTS)/run_tb.sh $(1) $(TBBUILD)/$(2)/$(1) $(2) $(3)

# open_wave: $(1) top. Loads $(WAVEDIR)/<top>.gtkw if it exists, so signal
#            selection and zoom survive between runs. Backgrounded; stderr
#            dropped because WSLg emits a dconf warning on every launch.
open_wave = vcd=$(TBBUILD)/sv/$(1)/$(1).vcd; \
            test -f $$vcd || { echo "no VCD at $$vcd - run wave_ first"; exit 1; }; \
            $(VIEWER) $$vcd $(if $(wildcard $(WAVEDIR)/$(1).gtkw),-a $(WAVEDIR)/$(1).gtkw) \
                2>/dev/null &

# TB_RULES: $(1) <subfolder>/<module>, $(2) <module>. Each target carries its
#           own recipe rather than depending on a shared phony one - a phony
#           prerequisite is built once per make run, which is why the old
#           tb_all had to recurse.
define TB_RULES
.PHONY: tb_$(2) equiv_$(2) wave_$(2) view_$(2) cov_$(2)

tb_$(2):
	@$$(call run_tb,$(2)_tb,sv,$$(RTL) $$(SVA_SRCS) ../tb/$(1)_tb.sv,$$(VFLAGS))

equiv_$(2): $$(CONVERTED)
	@$$(call run_tb,$(2)_tb,equiv,$$(PKG) $$(CONVERTED) $$(SVA_SRCS) ../tb/$(1)_tb.sv,$$(VFLAGS) $$(EQUIV_WAIVERS))

wave_$(2): WAVES := 1
wave_$(2): tb_$(2)
	@$$(call open_wave,$(2)_tb)

view_$(2):
	@$$(call open_wave,$(2)_tb)

cov_$(2):
	@cat $$(TBBUILD)/sv/$(2)_tb/covers.txt 2>/dev/null \
	    || echo "no cover listing for $(2)_tb - run tb_$(2) first"
endef

$(foreach t,$(TESTBENCHES),$(eval $(call TB_RULES,$(t),$(notdir $(t)))))

# ============================================================
# Suite targets
# ============================================================
.PHONY: tb_all equiv equiv_all report list

tb_all: QUIET  := 1
tb_all: NOFAIL := 1
tb_all: $(addprefix tb_,$(TB_MODULES))  ## run every testbench (use -j), print the table
	@bash $(SCRIPTS)/report.sh $(TBBUILD) sv $(TB_TOPS)

equiv: QUIET  := 1
equiv: NOFAIL := 1
equiv: $(addprefix equiv_,$(TB_MODULES))  ## every testbench against the sv2v output
	@bash $(SCRIPTS)/report.sh $(TBBUILD) equiv $(TB_TOPS)

# equiv_all: both flows as one parallel job graph, then both tables. Report
#            failures are collected so the second table always prints.
equiv_all: QUIET  := 1
equiv_all: NOFAIL := 1
equiv_all: $(addprefix tb_,$(TB_MODULES)) $(addprefix equiv_,$(TB_MODULES))  ## pre-submission gate: tb_all + equiv
	@rc=0; \
	bash $(SCRIPTS)/report.sh $(TBBUILD) sv    $(TB_TOPS) || rc=1; \
	bash $(SCRIPTS)/report.sh $(TBBUILD) equiv $(TB_TOPS) || rc=1; \
	exit $$rc

report:  ## reprint both tables from the last results, without re-running
	@-bash $(SCRIPTS)/report.sh $(TBBUILD) sv    $(TB_TOPS)
	@-bash $(SCRIPTS)/report.sh $(TBBUILD) equiv $(TB_TOPS)

list:  ## list registered testbenches and their files
	@$(foreach t,$(TESTBENCHES),printf '%-18s ../tb/%s_tb.sv\n' $(notdir $(t)) $(t);)

# ============================================================
# Lint
# ============================================================
.PHONY: lint
# if/else rather than `command -v ... && ... || echo`: in that form a lint
# failure falls through to the fallback and make exits 0.
lint:  ## strict Verilator lint over the RTL (what CI runs)
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

# ============================================================
# ASIC conversion and synthesis
# ============================================================
# Silicluster v3 accepts Verilog only, so the submitted source is the sv2v
# output. The equiv_ targets are the evidence the two are the same design.
.PHONY: convert syn syn_area

convert: $(CONVERTED)  ## sv2v the RTL into one Verilog-2005 file

$(CONVERTED): $(RTL)
	@mkdir -p $(SYNDIR)
	$(SV2V) $(RTL) > $@
	@echo "--- converted: $$(wc -l < $@) lines of Verilog-2005 ---"

# -flatten: area is a whole-design number; a module instantiated three times
#           counts once in the hierarchical stat.
syn: $(CONVERTED)  ## yosys synthesis, generic cell and flop counts
	$(YOSYS) -p "read_verilog $(CONVERTED); \
	             hierarchy -top pmic_top; \
	             synth -top pmic_top -flatten; \
	             stat" > $(SYNDIR)/stat.txt 2>&1
	@awk '/^4\. Printing statistics/,0' $(SYNDIR)/stat.txt
	@echo "--- full log: $(SYNDIR)/stat.txt ---"

# dfflibmap before abc: abc maps combinational logic only, so flops must be
# bound to library cells first or they contribute nothing to the area.
syn_area: $(CONVERTED)  ## sky130-mapped area (needs LIBERTY)
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

# ============================================================
# Housekeeping
# ============================================================
.PHONY: all tb_clean syn_clean clean help

all: lint  ## default goal: lint

tb_clean:  ## remove all testbench build output
	rm -rf $(TBBUILD)

syn_clean:  ## remove conversion and synthesis output
	rm -f $(CONVERTED) $(SYNDIR)/stat.txt $(SYNDIR)/area.txt

clean: tb_clean syn_clean  ## both of the above

# help: every target with a `## description` on its rule line, then the
#       generated per-module family, which has no rule line to annotate.
help:  ## this list
	@echo "Targets:"
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
	    | sed -E 's/^([a-zA-Z_-]+):.*## (.*)/\1|\2/' \
	    | awk -F'|' '{ printf "  %-14s %s\n", $$1, $$2 }'
	@echo
	@echo "Per module (generated from TESTBENCHES - see 'make list'):"
	@echo "    tb_<m>         build + run against the SV source"
	@echo "    equiv_<m>      same, against the sv2v output"
	@echo "    wave_<m>       run with a VCD, open GTKWave"
	@echo "    view_<m>       open the last VCD"
	@echo "    cov_<m>        re-list the last cover hits"
	@echo
	@echo "Modes: QUIET=1  STRICT=1 (zero-hit cover fails)  NOFAIL=1  WAVES=1"
	@echo "Parallel suite: make -j\$$(nproc) tb_all"