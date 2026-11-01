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
IVERILOG           ?= iverilog
VVP                ?= vvp

SCRIPTS := scripts

# TBBUILD: under $(HOME), not in the repo. This tree is a Windows mount and
#          Verilator writes hundreds of small files, each a 9p round trip.
#          Layout is $(TBBUILD)/<flow>/<top>, flow being sv or equiv.
TBBUILD ?= $(HOME)/build/sync_buck

# WAVEDIR: saved GTKWave selections, one <top>.gtkw per testbench. Outside
#          TBBUILD so tb_clean does not destroy them.
WAVEDIR ?= $(HOME)/gtkwave

# SYNDIR: inside the repo so the converted file is visible in the editor and
#         easy to inspect or hand to an ASIC flow. Slower over 9p, but conversion runs
#         rarely and the output is a deliverable rather than scratch.
SYNDIR    ?= ../Build
CONVERTED := $(SYNDIR)/pmic_full.v

# LIBERTY: sky130 high-density cells for real area numbers. Install with
#          `volare enable --pdk sky130 <version>`.
LIBERTY ?= $(HOME)/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# ============================================================
# Sources
# ============================================================
# SV_DIR: the SystemVerilog design source - what is edited.
# V_DIR:  the Verilog-2005 split of it - one .v per .sv, same layout, with the
#         comments sv2v discards carried over (see "Verilog split" below).
SV_DIR := ../rtl-systemverilog
V_DIR  := ../rtl-verilog

# Package first: it defines the widths and state_t every other file
# elaborates against.
RTL := $(SV_DIR)/pkg/pmic_types_pkg.sv \
       $(SV_DIR)/clk_rst/reset_sync.sv \
       $(SV_DIR)/inputs/input_sync.sv \
       $(SV_DIR)/inputs/input_debounce.sv \
       $(SV_DIR)/protect/soft_start.sv \
       $(SV_DIR)/protect/pwm_mask.sv \
       $(SV_DIR)/protect/fault_arbiter.sv \
       $(SV_DIR)/protect/hiccup_timer.sv \
       $(SV_DIR)/protect/strike_counter.sv \
       $(SV_DIR)/status/pgood_gen.sv \
       $(SV_DIR)/status/timestamp.sv \
       $(SV_DIR)/status/fault_LED.sv \
       $(SV_DIR)/telemetry/pwm_stats.sv \
       $(SV_DIR)/telemetry/reg_file.sv \
       $(SV_DIR)/telemetry/spi_slave.sv \
       $(SV_DIR)/telemetry/fault_cause.sv \
       $(SV_DIR)/supervisor.sv \
       $(SV_DIR)/pmic_top.sv

# PKG: inlined into the sv2v output and gone as a package there, but tb/ and
#      sva/ still import it, so equivalence runs compile it alongside the
#      converted RTL. Taken from RTL so the path has one owner.
PKG := $(firstword $(RTL))

# SPLIT=1: run the equiv flows against the commented split in $(V_DIR)
#          instead of the single-file conversion in ../Build. Results are
#          listed under the flow name "split".
SPLIT      ?= 0
SPLIT_SRCS := $(patsubst $(SV_DIR)/%.sv,$(V_DIR)/%.v,$(filter-out $(PKG),$(RTL)))
EQUIV_SRCS := $(if $(filter 1,$(SPLIT)),$(SPLIT_SRCS),$(CONVERTED))
EQUIV_FLOW := $(if $(filter 1,$(SPLIT)),split,equiv)

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
# SUITE_TOPS: what the suite tables list - every module testbench, then the
#             integration testbench
SUITE_TOPS := $(TB_TOPS) pmic_top_tb

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

equiv_$(2): $$(EQUIV_SRCS)
	@$$(call run_tb,$(2)_tb,$$(EQUIV_FLOW),$$(PKG) $$(EQUIV_SRCS) $$(SVA_SRCS) ../tb/$(1)_tb.sv,$$(VFLAGS) $$(EQUIV_WAIVERS))

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
# Integration testbench
# ============================================================
# ../tb/pmic_top_tb.v exercises pmic_top as a whole: plain Verilog-2005, no
# SVA, self-checking, with its own coverage bins and two scoreboards. It runs in
# both flows like the module testbenches, and also under Icarus Verilog, the
# open-source simulator a reviewer is most likely to have:
#   tb_top     Verilator, SystemVerilog source
#   equiv_top  Verilator, converted Verilog
#   iv_top     Icarus Verilog, converted Verilog
# It joins tb_all / equiv / equiv_all, listed as pmic_top_tb with its coverage
# bins in the covers column. scripts/run_top_tb.sh takes the verdict from the
# testbench's last line, which is also what gives Icarus a non-zero exit on
# FAIL - vvp exits 0 from $stop.
TOP_TB      := ../tb/pmic_top_tb.v

# TOP_CLK_HZ: the testbench's own CLK_HZ parameter, which sets the clock it
#             drives and every time it expects. It must equal CLK_HZ in
#             pmic_types_pkg.sv; the testbench file defaults to 10 MHz (the
#             Silicluster clock), so the Makefile passes the package value.
TOP_CLK_HZ  ?= 50000000

# TOP_TB_WAIVERS: lint classes that fire on testbench code only, never on RTL.
#   BLKSEQ:       monitors and scoreboards use blocking assignments in clocked
#                 blocks on purpose - they compute, then compare, in order.
#   PROCASSINIT:  variables initialised at their declaration.
#   WIDTHTRUNC:   integer constants assigned into byte-wide registers.
#   ZERODLY:      delays computed at run time.
#   REALCVT:      pulse widths are rounded from real time to whole clocks.
#   UNUSEDSIGNAL: the discarded turnaround byte, and unused upper bits of
#                 integer task arguments.
#   MULTIDRIVEN:  the testbench's force/release of spi_state and wd_mark counts
#                 as a second writer of those registers. The force is the point:
#                 both states are unreachable by stimulus.
TOP_TB_WAIVERS := -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-WIDTHTRUNC -Wno-ZERODLY \
                  -Wno-REALCVT -Wno-UNUSEDSIGNAL -Wno-MULTIDRIVEN
# TOP_SV_WAIVERS: SystemVerilog source only.
#   ENUMVALUE: the testbench forces an illegal encoding into the spi_slave state
#              register to prove the FSM recovers. In the source that register
#              is an enum; in the converted Verilog it is a plain reg.
TOP_SV_WAIVERS := -Wno-ENUMVALUE
# TOP_EQUIV_WAIVERS: converted Verilog only.
#   TIMESCALEMOD: sv2v drops the `timescale every SV source carries, while the
#                 testbench keeps one. The RTL contains no delays, so the time
#                 unit it runs under is immaterial.
TOP_EQUIV_WAIVERS := $(EQUIV_WAIVERS) -Wno-TIMESCALEMOD
TOP_VFLAGS     := --binary --timing -Wall $(LINT_WAIVERS) $(TB_WAIVERS) $(TOP_TB_WAIVERS)
TOP_IVFLAGS    := -g2005
IV_FLOW := $(if $(filter 1,$(SPLIT)),iv_split,iv)

# run_top: $(1) simulator, $(2) flow, $(3) sources, $(4) Verilator flags
run_top = VERILATOR='$(VERILATOR)' IVERILOG='$(IVERILOG)' VVP='$(VVP)' \
          TOP_VFLAGS='$(4) -GCLK_HZ=$(TOP_CLK_HZ)' \
          TOP_IVFLAGS='$(TOP_IVFLAGS) -Ppmic_top_tb.CLK_HZ=$(TOP_CLK_HZ)' \
          QUIET='$(QUIET)' NOFAIL='$(NOFAIL)' WAVES='$(WAVES)' \
          bash $(SCRIPTS)/run_top_tb.sh $(1) $(TBBUILD)/$(2)/pmic_top_tb $(2) $(3)

.PHONY: tb_top equiv_top iv_top top_all

tb_top:  ## integration testbench, Verilator, SystemVerilog source
	@$(call run_top,verilator,sv,$(RTL) $(TOP_TB),$(TOP_VFLAGS) $(TOP_SV_WAIVERS))

equiv_top: $(EQUIV_SRCS)  ## integration testbench, Verilator, converted Verilog
	@$(call run_top,verilator,$(EQUIV_FLOW),$(EQUIV_SRCS) $(TOP_TB),$(TOP_VFLAGS) $(TOP_EQUIV_WAIVERS))

iv_top: $(EQUIV_SRCS)  ## integration testbench, Icarus Verilog, converted Verilog
	@$(call run_top,iverilog,$(IV_FLOW),$(EQUIV_SRCS) $(TOP_TB),)

top_all: QUIET  := 1
top_all: NOFAIL := 1
top_all: tb_top equiv_top iv_top  ## integration testbench in all three flows
	@rc=0; \
	for f in sv $(EQUIV_FLOW) $(IV_FLOW); do bash $(SCRIPTS)/report.sh $(TBBUILD) $$f pmic_top_tb || rc=1; done; \
	exit $$rc

# ============================================================
# Suite targets
# ============================================================
.PHONY: tb_all equiv equiv_all report list

tb_all: QUIET  := 1
tb_all: NOFAIL := 1
tb_all: $(addprefix tb_,$(TB_MODULES)) tb_top  ## run every testbench (use -j), print the table
	@bash $(SCRIPTS)/report.sh $(TBBUILD) sv $(SUITE_TOPS)

equiv: QUIET  := 1
equiv: NOFAIL := 1
equiv: $(addprefix equiv_,$(TB_MODULES)) equiv_top  ## every testbench against the sv2v output (SPLIT=1: rtl-verilog)
	@bash $(SCRIPTS)/report.sh $(TBBUILD) $(EQUIV_FLOW) $(SUITE_TOPS)

# equiv_all: both flows as one parallel job graph, then both tables. Report
#            failures are collected so every table always prints.
equiv_all: QUIET  := 1
equiv_all: NOFAIL := 1
equiv_all: $(addprefix tb_,$(TB_MODULES)) $(addprefix equiv_,$(TB_MODULES)) tb_top equiv_top  ## the gate: tb_all + equiv
	@rc=0; \
	bash $(SCRIPTS)/report.sh $(TBBUILD) sv            $(SUITE_TOPS) || rc=1; \
	bash $(SCRIPTS)/report.sh $(TBBUILD) $(EQUIV_FLOW) $(SUITE_TOPS) || rc=1; \
	exit $$rc

report:  ## reprint both tables from the last results, without re-running
	@-bash $(SCRIPTS)/report.sh $(TBBUILD) sv    $(SUITE_TOPS)
	@-bash $(SCRIPTS)/report.sh $(TBBUILD) equiv $(SUITE_TOPS)

list:  ## list registered testbenches and their files
	@$(foreach t,$(TESTBENCHES),printf '%-18s ../tb/%s_tb.sv\n' $(notdir $(t)) $(t);)
	@printf '%-18s %s\n' pmic_top $(TOP_TB)

# ============================================================
# Lint
# ============================================================
.PHONY: lint lint_notel
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

# lint_notel: the TELEMETRY_EN=0 configuration, kept so the parameter stays
#             buildable. UNUSEDSIGNAL is waived for it alone:
#             with the host interface compiled out, the SCK and CS_n pins and
#             the nets that fed the telemetry blocks are legitimately unread.
#             Any other warning still fails.
lint_notel:  ## lint the TELEMETRY_EN=0 build (UNUSEDSIGNAL waived)
	$(VERILATOR) --lint-only -Wall $(LINT_WAIVERS) -Wno-UNUSEDSIGNAL $(RTL) \
	    --top-module pmic_top -GTELEMETRY_EN=0
	@echo "--- lint passed (TELEMETRY_EN=0) ---"

# ============================================================
# ASIC conversion and synthesis
# ============================================================
# ASIC flows take Verilog, so synthesis reads the sv2v output. The equiv_
# targets are the evidence the two are the same design.
.PHONY: convert syn syn_area syn_notel syn_area_notel syn_both

convert: $(CONVERTED)  ## sv2v the RTL into one Verilog-2005 file

$(CONVERTED): $(RTL)
	@mkdir -p $(SYNDIR)
	$(SV2V) $(RTL) > $@
	@echo "--- converted: $$(wc -l < $@) lines of Verilog-2005 ---"

# -flatten: area is a whole-design number; a module instantiated three times
#           counts once in the hierarchical stat.
# -l, tee -o: yosys writes the full log (-l) and the statistics table (tee -o)
#           to files itself rather than through a redirected stdout. The YoWASP
#           (WebAssembly) build of yosys truncates a redirected stdout, which
#           left a partial log and an empty table; files written by yosys are
#           exact with every build. -q keeps the terminal quiet.
syn: $(CONVERTED)  ## yosys synthesis, generic cell and flop counts
	$(YOSYS) -q -l $(SYNDIR)/stat.txt -p "read_verilog $(CONVERTED); \
	             hierarchy -top pmic_top; \
	             synth -top pmic_top -flatten; \
	             tee -o $(SYNDIR)/stat_summary.txt stat" > /dev/null 2>&1
	@cat $(SYNDIR)/stat_summary.txt
	@echo "--- full log: $(SYNDIR)/stat.txt ---"

# dfflibmap before abc: abc maps combinational logic only, so flops must be
# bound to library cells first or they contribute nothing to the area.
syn_area: $(CONVERTED)  ## sky130-mapped area (needs LIBERTY)
	@test -f $(LIBERTY) || { \
	    echo "no liberty file at $(LIBERTY)"; \
	    echo "set LIBERTY=<path>, or run: volare enable --pdk sky130 <version>"; \
	    exit 1; }
	$(YOSYS) -q -l $(SYNDIR)/area.txt -p "read_verilog $(CONVERTED); \
	             hierarchy -top pmic_top; \
	             synth -top pmic_top -flatten; \
	             dfflibmap -liberty $(LIBERTY); \
	             abc -liberty $(LIBERTY); \
	             opt_clean; \
	             tee -o $(SYNDIR)/area_summary.txt stat -liberty $(LIBERTY)" > /dev/null 2>&1
	@grep -E "Chip area|Number of cells|cells$$" $(SYNDIR)/area_summary.txt || \
	    { tail -40 $(SYNDIR)/area.txt; exit 1; }
	@python3 $(SCRIPTS)/area_counts.py $(SYNDIR)/area_summary.txt syn_area
	@echo "--- Silicluster v3 standard slot is 180 x 115 = 20700 um2 ---"

# syn_notel / syn_area_notel: the same flows on the TELEMETRY_EN=0 build.
#   sv2v keeps TELEMETRY_EN as a Verilog parameter and the generate blocks as
#   Verilog generates, so the one converted file serves both configurations;
#   chparam selects before elaboration. Outputs carry a _notel suffix so the
#   default build's files are never overwritten. The default is
#   TELEMETRY_EN=1.
syn_notel: $(CONVERTED)  ## generic synthesis of the TELEMETRY_EN=0 build
	$(YOSYS) -q -l $(SYNDIR)/stat_notel.txt -p "read_verilog $(CONVERTED); \
	             chparam -set TELEMETRY_EN 0 pmic_top; \
	             hierarchy -top pmic_top; \
	             synth -top pmic_top -flatten; \
	             tee -o $(SYNDIR)/stat_notel_summary.txt stat" > /dev/null 2>&1
	@cat $(SYNDIR)/stat_notel_summary.txt

syn_area_notel: $(CONVERTED)  ## sky130-mapped area of the TELEMETRY_EN=0 build
	@test -f $(LIBERTY) || { echo "no liberty file at $(LIBERTY)"; exit 1; }
	$(YOSYS) -q -l $(SYNDIR)/area_notel.txt -p "read_verilog $(CONVERTED); \
	             chparam -set TELEMETRY_EN 0 pmic_top; \
	             hierarchy -top pmic_top; \
	             synth -top pmic_top -flatten; \
	             dfflibmap -liberty $(LIBERTY); \
	             abc -liberty $(LIBERTY); \
	             opt_clean; \
	             tee -o $(SYNDIR)/area_notel_summary.txt stat -liberty $(LIBERTY)" > /dev/null 2>&1
	@python3 $(SCRIPTS)/area_counts.py $(SYNDIR)/area_notel_summary.txt syn_area_notel

# syn_both: the area of both TELEMETRY_EN builds, side by side
syn_both: syn_area syn_area_notel  ## sky130 area of both TELEMETRY_EN builds

# ============================================================
# Verilog split (rtl-verilog)
# ============================================================
# $(V_DIR) holds one Verilog-2005 file per SystemVerilog module, in the same
# layout as $(SV_DIR), with the comments sv2v discards carried over from the
# previous version. Its code must always be exactly what sv2v produces from
# the current source:
#   split          sv2v -w adjacent into a clean staging tree, $(SPLITRAW).
#                  The package converts to two pragmas and nothing else - its
#                  constants are inlined into every consumer - so
#                  pmic_types_pkg.v is dropped.
#   verilog_check  every file in $(V_DIR) must be code-identical to that fresh
#                  output once comments and `timescale are stripped.
#   verilog        regenerate $(V_DIR) from the current source: keep every
#                  comment, take every code token from the fresh split.
#                  Refuses a file if anything but a constant changed (a new
#                  port or block needs comments written by hand), and lists
#                  comments that name a clock frequency for review.
#                  $(V_DIR) is replaced only if every file succeeds.
SPLITRAW := $(SYNDIR)/split_raw
SV_NAME  := $(notdir $(SV_DIR))

.PHONY: split verilog_check verilog

split:  ## sv2v -w adjacent into a clean staging tree (Build/split_raw)
	@rm -rf $(SPLITRAW)
	@mkdir -p $(SPLITRAW)
	@cp -r $(SV_DIR) $(SPLITRAW)/
	cd $(SPLITRAW) && $(SV2V) -w adjacent $(patsubst ../%,%,$(RTL))
	@find $(SPLITRAW)/$(SV_NAME) -name '*.sv' -delete
	@rm -f $(SPLITRAW)/$(SV_NAME)/pkg/pmic_types_pkg.v
	@rmdir $(SPLITRAW)/$(SV_NAME)/pkg
	@echo "--- raw split: $$(find $(SPLITRAW)/$(SV_NAME) -name '*.v' | wc -l) files ---"

verilog_check: split  ## rtl-verilog code-identical to fresh sv2v output
	@python3 $(SCRIPTS)/strip_compare.py $(SPLITRAW)/$(SV_NAME) $(V_DIR)

verilog: split  ## regenerate rtl-verilog from the source, keeping its comments
	@rm -rf $(SPLITRAW)/new
	@python3 $(SCRIPTS)/transplant_comments.py $(SPLITRAW)/$(SV_NAME) $(V_DIR) $(SPLITRAW)/new
	@python3 $(SCRIPTS)/strip_compare.py $(SPLITRAW)/$(SV_NAME) $(SPLITRAW)/new > /dev/null
	@rm -rf $(V_DIR) && mv $(SPLITRAW)/new $(V_DIR)
	@echo "--- $(V_DIR) regenerated; review any comments listed above ---"

# ============================================================
# Housekeeping
# ============================================================
.PHONY: all tb_clean syn_clean clean help

all: lint  ## default goal: lint

tb_clean:  ## remove all testbench build output
	rm -rf $(TBBUILD)

syn_clean:  ## remove conversion and synthesis output
	rm -f $(CONVERTED) $(SYNDIR)/stat.txt $(SYNDIR)/area.txt \
	      $(SYNDIR)/stat_summary.txt $(SYNDIR)/area_summary.txt \
	      $(SYNDIR)/stat_notel*.txt $(SYNDIR)/area_notel*.txt
	rm -rf $(SPLITRAW)

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