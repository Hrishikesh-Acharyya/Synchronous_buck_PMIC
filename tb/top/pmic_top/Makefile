#
# Filename:         Makefile
#
# File Description: cocotb build-and-run for the whole supervisor - pmic_top
#                   inside pmic_top_harness, with a board model around it. Run
#                   from this folder with the venv active; a plain `make` runs
#                   every test in test_pmic_top.py. Compiles the same sources
#                   as sim/mk/sources.mk - the whole RTL and every bound
#                   checker - so every block's checker runs underneath as well
#                   as pmic_top_sva. SPI access reuses tb/telemetry/host_if's
#                   driver, so that folder is on PYTHONPATH too.
#
#                   Paths come from this file's own location, so sim/Makefile
#                   can run it from a build directory (make -f <this file>)
#                   and every output lands there. The targets after the
#                   cocotb include are shortcuts for the constrained-random
#                   test (random_walk) and its coverage, the same set as
#                   host_if's; `make help` lists them, COMMANDS.md in this
#                   folder explains them.
#
# Global variables: TB_DIR, REPO, SV_DIR, PKG, RTL_SRCS, SVA_SRCS, TB_SRCS,
#                   HOSTIF_DIR - sources and paths
#                   TELEMETRY_EN - the build under test
#                   SIM, TOPLEVEL_LANG, VERILOG_SOURCES, TOPLEVEL, MODULE,
#                   EXTRA_ARGS - cocotb's variables
#                   EVENTS, SEEDS, SEED, RANDOM_TEST, RANDOM_ARGS, FCOV,
#                   SVA_COVER_FILTER - random-test shortcuts
#                   COV_DIR, COVERAGE_DIR, SOAK_DIR, SOAK_RAW, MERGED - output
#                   folders and the merged coverage the reports read

# ==============================================================================
# Sources
# ==============================================================================

# TB_DIR: this testbench's folder, from the Makefile's own path
TB_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
# REPO: repository root, two levels up from tb/top/pmic_top/
REPO   := $(abspath $(TB_DIR)/../../..)
SV_DIR := $(REPO)/rtl-systemverilog

# PKG: must come first - every other file elaborates against its types
PKG      := $(SV_DIR)/pkg/pmic_types_pkg.sv
RTL_SRCS := $(PKG) $(filter-out $(PKG),$(wildcard $(SV_DIR)/*.sv $(SV_DIR)/*/*.sv))

# SVA_SRCS: same rule as sources.mk - sva_pkg first, bind_sva.sv last
SVA_SRCS := $(REPO)/sva/sva_pkg.sv \
            $(filter-out $(REPO)/sva/sva_pkg.sv $(REPO)/sva/bind_sva.sv,$(wildcard $(REPO)/sva/*/*.sv)) \
            $(REPO)/sva/bind_sva.sv

TB_SRCS  := $(TB_DIR)/pmic_top_harness.sv

# HOSTIF_DIR: the host-interface testbench, for its SPI driver and constants
HOSTIF_DIR := $(REPO)/tb/telemetry/host_if

# TELEMETRY_EN: 1 tests the full build. The reduced build (0) has no SPI, so
#               its run checks pins only; see COMMANDS.md.
TELEMETRY_EN ?= 1

# CHECKERS: the bound checkers the build carries.
#   all (default) - every block's checker plus pmic_top_sva, exactly as the
#                   sim/ flow builds it
#   top           - pmic_top_sva alone (bind_top_only.sv), about ten times
#                   faster: the block checkers cost ~90 % of the simulation.
#                   The soak's default (SOAK_CHECKERS); each block was closed
#                   by its own testbench, and every other target keeps all.
#   A top build gets its own SIM_BUILD, so the two never overwrite each other.
CHECKERS ?= all
ifeq ($(CHECKERS),top)
SVA_SRCS  := $(REPO)/sva/sva_pkg.sv $(REPO)/sva/top/pmic_top_sva.sv $(TB_DIR)/bind_top_only.sv
SIM_BUILD ?= sim_build_top
endif

# ==============================================================================
# cocotb
# ==============================================================================

SIM             ?= verilator
TOPLEVEL_LANG    = verilog
VERILOG_SOURCES  = $(RTL_SRCS) $(SVA_SRCS) $(TB_SRCS)
TOPLEVEL         = pmic_top_harness
MODULE           = test_pmic_top

# EXTRA_ARGS: passed to Verilator. Same lint level and waivers as the SV flow
#   (sim/mk/sources.mk). No --binary: cocotb supplies its own main.
#   --timing: the harness generates the clock with a delay.
#   --no-public-flat-rw --public-depth 1: cocotb makes every signal public by
#   default, which disables most of Verilator's optimisation; these tests
#   touch only the harness's ports, so only the top level stays public.
EXTRA_ARGS += --timing --assert --coverage-user -Wall \
              -Wno-WIDTHEXPAND -Wno-UNUSEDPARAM -Wno-SYNCASYNCNET \
              --no-public-flat-rw --public-depth 1 \
              -GTELEMETRY_EN=$(TELEMETRY_EN)
# the reduced build leaves the SPI pins unconnected by design (lint_notel
# waives the same)
ifeq ($(TELEMETRY_EN),0)
EXTRA_ARGS += -Wno-UNUSEDSIGNAL
endif

# PYTHONPATH: this folder first, then host_if for spi_driver / host_if_constants
export PYTHONPATH := $(TB_DIR):$(HOSTIF_DIR):$(PYTHONPATH)
# TB_TELEMETRY: tells the tests which build they are checking
export TB_TELEMETRY := $(TELEMETRY_EN)

include $(shell cocotb-config --makefiles)/Makefile.sim

# ==============================================================================
# Random-test and coverage shortcuts - the same targets as host_if's Makefile,
# run through a recursive make; nothing here changes what a plain `make` does.
# They sit AFTER the include so make's default goal stays cocotb's `sim`.
#
# Variables, overridable on the command line:
#   EVENTS  - random_walk events per run                     (default 30)
#   SEEDS   - how many seeds random_seeds / soak / cov_all run (default 5)
#   SEED    - the seed replay reproduces                     (no default)
#
# A random_walk event costs 1 to 22 ms of simulated time (a switch or reset
# waits out the 20 ms debounce; a clean-run event about 100 ms), roughly 5 ms
# on average - at about 2 ms simulated per second, 30 events take ~1.5 min.
# ==============================================================================

EVENTS ?= 30

# TESTS_PASSED: the verdict of the run just made, from cocotb's results.xml -
#   at least one test, and no failure or error. make's own exit status is not
#   enough: older cocotb (1.x) exits 0 even when a test fails, which once let
#   a soak record failing runs as PASS. RUN_FRESH removes the previous
#   results.xml first, so a run that writes none cannot borrow one.
RUN_FRESH    := rm -f results.xml;
TESTS_PASSED := { test -f results.xml && grep -q '<testcase' results.xml && ! grep -q -E '<failure|<error' results.xml; }
SEEDS  ?= 5

# SOAK_JOBS: soak runs simulated at once - every core by default; each run is
#            single-threaded
# SOAK_CHECKERS: the checker set the soak builds with (see CHECKERS) - top by
#            default, SOAK_CHECKERS=all for every block's checker as well
SOAK_JOBS     ?= $(shell nproc 2>/dev/null || echo 1)
SOAK_CHECKERS ?= top

# RANDOM_TEST: the constrained-random test's name
RANDOM_TEST := random_walk

# RANDOM_ARGS: the variables random_walk reads from the environment
RANDOM_ARGS = TESTCASE=$(RANDOM_TEST) RANDOM_EVENTS=$(EVENTS)

# FCOV: merge / report the covergroups - host_if's script, which reads any
#       cocotb-coverage export
FCOV := python3 $(HOSTIF_DIR)/fcov_report.py

# SVA_COVER_FILTER: the checker whose covers the coverage reports list - the
#                   top-level one; every block's own checker runs underneath,
#                   but its corner covers are its own testbench's job
SVA_COVER_FILTER := pmic_top_sva

.PHONY: help random quick replay random_seeds soak cov_all cov_zero cov_summary clean_cov check_merged

help:
	@echo "pmic_top cocotb targets:"
	@echo "  make                         all tests (random_walk at its built-in 12 events)"
	@echo "  make random                  random_walk once, EVENTS=$(EVENTS), new seed"
	@echo "  make quick                   random_walk once, 8 events - while editing"
	@echo "  make replay SEED=<n>         rerun random_walk with that seed (EVENTS must match)"
	@echo "  make random_seeds            SEEDS=$(SEEDS) runs, stop at first failure, merge coverage"
	@echo "  make soak                    unattended SEEDS x EVENTS sweep, SOAK_JOBS at a time (default every core), pmic_top_sva only (SOAK_CHECKERS=all for every checker); evidence in soak/"
	@echo "  make cov_all                 whole suite once + SEEDS random runs, merged; evidence in coverage/"
	@echo "  make cov_zero                list pmic_top_sva covers no merged run has reached"
	@echo "  make cov_summary             pmic_top_sva covers hit vs zero (newest merge, or MERGED=<file>)"
	@echo "  make clean_cov               delete the coverage in cov/; soak evidence is kept"

random:
	@$(MAKE) --no-print-directory -f $(TB_DIR)/Makefile $(RANDOM_ARGS)

quick:
	@$(MAKE) --no-print-directory -f $(TB_DIR)/Makefile $(RANDOM_ARGS) RANDOM_EVENTS=8

replay:
	@test -n "$(SEED)" || { echo "usage: make replay SEED=<seed> [EVENTS=<n>]"; exit 1; }
	@$(MAKE) --no-print-directory -f $(TB_DIR)/Makefile $(RANDOM_ARGS) RANDOM_SEED=$(SEED)

# Output folders, as in host_if: COV_DIR working coverage (gitignored),
# COVERAGE_DIR cov_all's tracked summary, SOAK_DIR a soak's tracked evidence,
# SOAK_RAW a soak's per-run files (gitignored). All under TB_DIR, so they are
# the same wherever make is run from.
COV_DIR      := $(TB_DIR)/cov
COVERAGE_DIR := $(TB_DIR)/coverage
SOAK_DIR     := $(TB_DIR)/soak
SOAK_RAW     := $(TB_DIR)/soak/raw
MERGED   ?= $(shell ls -t $(COV_DIR)/merged.dat $(COV_DIR)/merged_all.dat $(SOAK_DIR)/merged.dat 2>/dev/null | head -1)

random_seeds: clean_cov
	@mkdir -p $(COV_DIR)
	@for run in $$(seq 1 $(SEEDS)); do \
	    echo "==== random_seeds: run $$run of $(SEEDS) ===="; \
	    $(RUN_FRESH) $(MAKE) --no-print-directory -f $(TB_DIR)/Makefile $(RANDOM_ARGS) \
	        FCOV_XML=$(COV_DIR)/fcov_run$$run.xml && $(TESTS_PASSED) || exit 1; \
	    cp coverage.dat $(COV_DIR)/cov_run$$run.dat; \
	done
	@verilator_coverage --write $(COV_DIR)/merged.dat $(COV_DIR)/cov_run*.dat
	@echo "==== random_seeds: $(SEEDS) runs passed, coverage merged into $(COV_DIR)/merged.dat ===="
	@$(MAKE) --no-print-directory -f $(TB_DIR)/Makefile cov_summary MERGED=$(COV_DIR)/merged.dat
	@$(FCOV) merge $(COV_DIR)/fcov_all.xml $(COV_DIR)/fcov_run*.xml
	@$(FCOV) report $(COV_DIR)/fcov_all.xml

cov_all: clean_cov
	@mkdir -p $(COV_DIR) $(COVERAGE_DIR)
	@echo "==== cov_all: full suite ===="
	@$(RUN_FRESH) $(MAKE) --no-print-directory -f $(TB_DIR)/Makefile FCOV_XML=$(COV_DIR)/fcov_suite.xml && $(TESTS_PASSED) || exit 1
	@cp coverage.dat $(COV_DIR)/cov_suite.dat
	@for run in $$(seq 1 $(SEEDS)); do \
	    echo "==== cov_all: random run $$run of $(SEEDS) ===="; \
	    $(RUN_FRESH) $(MAKE) --no-print-directory -f $(TB_DIR)/Makefile $(RANDOM_ARGS) \
	        FCOV_XML=$(COV_DIR)/fcov_run$$run.xml && $(TESTS_PASSED) || exit 1; \
	    cp coverage.dat $(COV_DIR)/cov_run$$run.dat; \
	done
	@verilator_coverage --write $(COV_DIR)/merged_all.dat $(COV_DIR)/cov_suite.dat $(COV_DIR)/cov_run*.dat
	@{ echo "cov_all: full suite + $(SEEDS) random runs x $(EVENTS) events - $$(date)"; \
	   echo "result: every test passed (cov_all stops at the first failure)"; \
	   echo "covers hit:"; \
	   $(MAKE) --no-print-directory -f $(TB_DIR)/Makefile cov_summary MERGED=$(COV_DIR)/merged_all.dat; \
	   echo "zero-hit covers:"; \
	   $(MAKE) --no-print-directory -f $(TB_DIR)/Makefile cov_zero MERGED=$(COV_DIR)/merged_all.dat; \
	   echo "functional coverage (covergroups):"; \
	   $(FCOV) merge $(COV_DIR)/fcov_all.xml $(COV_DIR)/fcov_suite.xml $(COV_DIR)/fcov_run*.xml; \
	   $(FCOV) report $(COV_DIR)/fcov_all.xml; \
	 } > $(COVERAGE_DIR)/summary.txt
	@echo "==== cov_all: suite + $(SEEDS) random runs passed; summary in $(COVERAGE_DIR)/summary.txt ===="
	@cat $(COVERAGE_DIR)/summary.txt

# soak: every seed runs, failures included; evidence in SOAK_DIR (tracked),
# per-run logs, event CSVs, coverage and covergroups in SOAK_RAW (gitignored).
# A new soak replaces the previous one's files; SOAK_DIR/README.md is kept.
# Built with SOAK_CHECKERS (pmic_top_sva alone by default, ~10x faster). Run 1
# goes alone and builds SOAK_RAW/build; the rest run SOAK_JOBS at a time
# through soak_run.sh, each in its own folder with seed = start time + run
# number, so runs started together never share a seed. make replay rebuilds
# with every checker, so a failing seed is re-examined in full.
soak:
	@mkdir -p $(SOAK_RAW)
	@rm -f $(SOAK_RAW)/run*.log $(SOAK_RAW)/events_run*.csv $(SOAK_RAW)/cov_run*.dat \
	       $(SOAK_RAW)/fcov_run*.xml $(SOAK_RAW)/runs.txt $(SOAK_DIR)/results.txt \
	       $(SOAK_DIR)/summary.txt $(SOAK_DIR)/all_events.csv $(SOAK_DIR)/merged.dat \
	       $(SOAK_DIR)/functional_coverage.xml
	@echo "soak: $(SEEDS) runs x $(EVENTS) events, $(SOAK_JOBS) at a time, checkers: $(SOAK_CHECKERS) - started $$(date)" \
	    | tee $(SOAK_DIR)/results.txt
	@base=$$(date +%s); \
	export TB_DIR=$(TB_DIR) SOAK_RAW=$(SOAK_RAW) EVENTS=$(EVENTS) \
	       CHECKERS=$(SOAK_CHECKERS) SIM_BUILD=$(SOAK_RAW)/build; \
	echo "  run 1 builds the simulation first, then $(SOAK_JOBS) at a time"; \
	bash $(TB_DIR)/soak_run.sh 1 $$base | tee -a $(SOAK_RAW)/runs.txt; \
	seq 2 $(SEEDS) | xargs -r -P $(SOAK_JOBS) -I{} bash $(TB_DIR)/soak_run.sh {} $$base \
	    | tee -a $(SOAK_RAW)/runs.txt
	@sort -t' ' -k2,2n $(SOAK_RAW)/runs.txt >> $(SOAK_DIR)/results.txt
	@echo "soak: finished $$(date)" | tee -a $(SOAK_DIR)/results.txt
	@verilator_coverage --write $(SOAK_DIR)/merged.dat $(SOAK_RAW)/cov_run*.dat
	@$(MAKE) --no-print-directory -f $(TB_DIR)/Makefile cov_summary MERGED=$(SOAK_DIR)/merged.dat  > $(SOAK_DIR)/summary.txt
	@echo "zero-hit covers:"                                                                       >> $(SOAK_DIR)/summary.txt
	@$(MAKE) --no-print-directory -f $(TB_DIR)/Makefile cov_zero    MERGED=$(SOAK_DIR)/merged.dat >> $(SOAK_DIR)/summary.txt
	@awk 'FNR == 1 && NR != 1 { next } { print }' $$(ls $(SOAK_RAW)/events_run*.csv | sort -V) > $(SOAK_DIR)/all_events.csv
	@$(FCOV) merge $(SOAK_DIR)/functional_coverage.xml $(SOAK_RAW)/fcov_run*.xml
	@echo "functional coverage (covergroups):"                  >> $(SOAK_DIR)/summary.txt
	@$(FCOV) report $(SOAK_DIR)/functional_coverage.xml          >> $(SOAK_DIR)/summary.txt
	@echo "soak: $$(grep -c ': PASS' $(SOAK_DIR)/results.txt) passed, $$(grep -c ': FAIL' $(SOAK_DIR)/results.txt) failed - see $(SOAK_DIR)/"
	@cat $(SOAK_DIR)/summary.txt

check_merged:
	@test -n "$(MERGED)" -a -f "$(MERGED)" || \
	    { echo "no merged coverage yet - run 'make random_seeds', 'make cov_all' or 'make soak' first"; exit 1; }

# cov_zero: every pmic_top_sva cover no merged run hit, as
# "<hierarchy>.<cover>  (<checker file>:<line>)" - the same parser as host_if's
cov_zero: check_merged
	@zeros=$$(grep -E "$(SVA_COVER_FILTER)" $(MERGED) | awk '$$NF == 0 { \
	    n = split($$0, parts, "\001"); f = ""; l = ""; h = ""; \
	    for (i = 2; i <= n; i++) { \
	        split(parts[i], kv, "\002"); v = kv[2]; sub(/\047.*/, "", v); \
	        if (kv[1] == "f") { sub(/.*\//, "", v); f = v } \
	        if (kv[1] == "l") l = v; \
	        if (kv[1] == "h") h = v \
	    } \
	    printf "  %s  (%s:%s)\n", h, f, l }'); \
	if [ -n "$$zeros" ]; then echo "$$zeros"; else echo "  no zero-hit covers"; fi

cov_summary: check_merged
	@total=$$(grep -c "$(SVA_COVER_FILTER)" $(MERGED)); \
	zero=$$(grep "$(SVA_COVER_FILTER)" $(MERGED) | awk '$$NF == 0' | wc -l); \
	echo "  $(SVA_COVER_FILTER): $$((total - zero)) of $$total covers hit, $$zero at zero"

clean_cov:
	@rm -f $(COV_DIR)/cov_*.dat $(COV_DIR)/merged.dat $(COV_DIR)/merged_all.dat $(COV_DIR)/fcov_*.xml
