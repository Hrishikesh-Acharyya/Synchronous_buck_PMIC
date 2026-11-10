#
# Filename:         Makefile
#
# File Description: cocotb build-and-run for the host interface - spi_slave and
#                   reg_file through host_if_wrapper. Run from this folder with
#                   the venv active. A plain `make` runs every test in
#                   test_host_if.py. Compiles the same sources as
#                   sim/mk/sources.mk - the whole RTL and every bound checker -
#                   and lets TOPLEVEL decide what is elaborated, so binds to
#                   modules outside this build are inert, exactly as in the
#                   module testbenches. The targets after the cocotb include
#                   are shortcuts for the constrained-random test and its
#                   coverage; `make help` lists them, COMMANDS.md in this
#                   folder explains them.
#
# Global variables: TB_DIR, REPO, SV_DIR, PKG, RTL_SRCS, SVA_SRCS, TB_SRCS - sources
#                   SIM, TOPLEVEL_LANG, VERILOG_SOURCES, TOPLEVEL, MODULE,
#                   EXTRA_ARGS - cocotb's variables
#                   EVENTS, SEEDS, SEED, EVERY, RANDOM_TEST, RANDOM_ARGS,
#                   SVA_COVER_FILTER - random-test shortcuts
#                   COV_DIR, COVERAGE_DIR, SOAK_DIR, SOAK_RAW, MERGED - output
#                   folders and the merged coverage the reports read

# ==============================================================================
# Sources
# ==============================================================================

# TB_DIR: this testbench's folder, taken from the Makefile's own path rather
#         than the current directory, so sim/Makefile can run the suite from a
#         build directory (make -f <this file>) and every output - sim_build,
#         results.xml, coverage.dat - lands there, not here
TB_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
# REPO: repository root, three levels up from tb/telemetry/host_if/
REPO   := $(abspath $(TB_DIR)/../../..)
SV_DIR := $(REPO)/rtl-systemverilog

# PKG: must come first - every other file elaborates against its types
PKG      := $(SV_DIR)/pkg/pmic_types_pkg.sv
RTL_SRCS := $(PKG) $(filter-out $(PKG),$(wildcard $(SV_DIR)/*.sv $(SV_DIR)/*/*.sv))

# SVA_SRCS: same rule as sources.mk - sva_pkg first, bind_sva.sv last
SVA_SRCS := $(REPO)/sva/sva_pkg.sv \
            $(filter-out $(REPO)/sva/sva_pkg.sv $(REPO)/sva/bind_sva.sv,$(wildcard $(REPO)/sva/*/*.sv)) \
            $(REPO)/sva/bind_sva.sv

TB_SRCS  := $(TB_DIR)/host_if_wrapper.sv

# ==============================================================================
# cocotb
# ==============================================================================

SIM             ?= verilator
TOPLEVEL_LANG    = verilog
VERILOG_SOURCES  = $(RTL_SRCS) $(SVA_SRCS) $(TB_SRCS)
TOPLEVEL         = host_if_wrapper
MODULE           = test_host_if

# EXTRA_ARGS: passed to Verilator. Same lint level and waivers as the SV flow
#   (sim/mk/sources.mk), so a warning means the same thing in both. No
#   --binary: cocotb supplies its own main.
EXTRA_ARGS += --assert --coverage-user -Wall \
              -Wno-WIDTHEXPAND -Wno-UNUSEDPARAM -Wno-SYNCASYNCNET

# PYTHONPATH: let the tests import their sibling modules (spi_driver, tb_utils, ...)
export PYTHONPATH := $(TB_DIR):$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim

# ==============================================================================
# Random-test and coverage shortcuts. Everything below runs the cocotb flow
# above through a recursive make; nothing here changes what a plain `make`
# does. These targets sit AFTER the include on purpose: make's default goal is
# the first target in the file, which must stay cocotb's `sim`.
#
# Variables, overridable on the command line:
#   EVENTS  - random events per run                         (default 30)
#   SEEDS   - how many seeds random_seeds / soak / cov_all run (default 5)
#   SEED    - the seed replay reproduces                    (no default)
#   EVERY   - scoreboard interval inside random_walk        (default 10)
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
EVERY  ?= 10

# SOAK_JOBS: soak runs simulated at once - every core by default; each run is
#            single-threaded
# SOAK_RUN: one soak run, shared with pmic_top's soak
SOAK_JOBS ?= $(shell nproc 2>/dev/null || echo 1)
SOAK_RUN  := $(REPO)/sim/scripts/soak_run.sh

# RANDOM_TEST: the constrained-random test's name, used by every target below
RANDOM_TEST := random_walk

# RANDOM_ARGS: the variables random_walk reads from the environment
RANDOM_ARGS = TESTCASE=$(RANDOM_TEST) RANDOM_EVENTS=$(EVENTS) SCOREBOARD_EVERY=$(EVERY)

# SVA_COVER_FILTER: the checkers whose covers the coverage reports list
SVA_COVER_FILTER := reg_file_sva|spi_slave_sva

.PHONY: help random quick replay random_seeds soak cov_all cov_zero cov_summary clean_cov check_merged audit_soak

help:
	@echo "host_if cocotb targets:"
	@echo "  make                         all tests (random_walk at its built-in 30 events)"
	@echo "  make random                  random_walk once, EVENTS=$(EVENTS), new seed"
	@echo "  make quick                   random_walk once, 30 events - while editing"
	@echo "  make replay SEED=<n>         rerun random_walk with that seed (EVENTS must match)"
	@echo "  make random_seeds            SEEDS=$(SEEDS) runs, stop at first failure, merge coverage"
	@echo "  make soak                    unattended SEEDS x EVENTS sweep, SOAK_JOBS at a time (default every core), never stops; evidence in soak/"
	@echo "  make audit_soak              check every soak transaction against the register-map rules, independently of the model"
	@echo "  make cov_all                 whole suite once + SEEDS random runs, merged - the true coverage picture; evidence in coverage/"
	@echo "  make cov_zero                list covers no merged run has reached (newest merge, or MERGED=<file>)"
	@echo "  make cov_summary             covers hit vs zero, per checker (newest merge, or MERGED=<file>)"
	@echo "  make clean_cov               delete the coverage in cov/; soak evidence is kept"

# random: one random_walk run with a fresh seed
random:
	@$(MAKE) --no-print-directory $(RANDOM_ARGS)

# quick: a short run while editing the test
quick:
	@$(MAKE) --no-print-directory $(RANDOM_ARGS) RANDOM_EVENTS=30

# replay: the exact run that produced SEED - EVENTS must match the failing run
replay:
	@test -n "$(SEED)" || { echo "usage: make replay SEED=<seed> [EVENTS=<n>]"; exit 1; }
	@$(MAKE) --no-print-directory $(RANDOM_ARGS) RANDOM_SEED=$(SEED)

# ------------------------------------------------------------------
# Output folders. Nothing generated is written to this folder itself.
# ------------------------------------------------------------------
# COV_DIR:  random_seeds' and cov_all's per-run coverage and merges -
#           working files, gitignored. random_seeds merges into merged.dat,
#           cov_all into merged_all.dat, so neither overwrites the other.
# SOAK_DIR: a soak's EVIDENCE, tracked in git: README.md, results.txt,
#           summary.txt, all_events.csv, merged.dat
# SOAK_RAW: a soak's per-run logs, event CSVs and coverage - kept on disk
#           for digging into one run, gitignored
# COVERAGE_DIR: cov_all's EVIDENCE, tracked in git: summary.txt, the coverage
#           picture of the last full run (suite + random)
# MERGED:   the merged coverage cov_zero / cov_summary read; by default the
#           newest of the three merges, so any sweep can be followed by them
COV_DIR      := cov
COVERAGE_DIR := coverage
SOAK_DIR     := soak
SOAK_RAW     := soak/raw
MERGED   ?= $(shell ls -t $(COV_DIR)/merged.dat $(COV_DIR)/merged_all.dat $(SOAK_DIR)/merged.dat 2>/dev/null | head -1)

# random_seeds: SEEDS runs, each a new seed; stops at the first failing run so
# its replay line is the last one in the terminal. Each run's coverage.dat is
# kept in COV_DIR and all of them are merged into COV_DIR/merged.dat.
random_seeds: clean_cov
	@mkdir -p $(COV_DIR)
	@for run in $$(seq 1 $(SEEDS)); do \
	    echo "==== random_seeds: run $$run of $(SEEDS) ===="; \
	    $(RUN_FRESH) $(MAKE) --no-print-directory $(RANDOM_ARGS) && $(TESTS_PASSED) || exit 1; \
	    cp coverage.dat $(COV_DIR)/cov_run$$run.dat; \
	done
	@verilator_coverage --write $(COV_DIR)/merged.dat $(COV_DIR)/cov_run*.dat
	@echo "==== random_seeds: $(SEEDS) runs passed, coverage merged into $(COV_DIR)/merged.dat ===="
	@$(MAKE) --no-print-directory cov_summary MERGED=$(COV_DIR)/merged.dat

# cov_all: the whole suite once (every directed test, plus random_walk at its
# built-in event count), then SEEDS random runs, all merged. random_seeds and
# soak run random_walk only, so they miss what the directed tests reach; this
# is the real coverage picture. Stops at the first failing run, so a summary
# is only ever written for a run in which every test passed. The summary is
# the tracked evidence in COVERAGE_DIR; the per-run files stay in COV_DIR.
cov_all: clean_cov
	@mkdir -p $(COV_DIR) $(COVERAGE_DIR)
	@echo "==== cov_all: full suite ===="
	@$(RUN_FRESH) $(MAKE) --no-print-directory FCOV_XML=$(CURDIR)/$(COV_DIR)/fcov_suite.xml && $(TESTS_PASSED) || exit 1
	@cp coverage.dat $(COV_DIR)/cov_suite.dat
	@for run in $$(seq 1 $(SEEDS)); do \
	    echo "==== cov_all: random run $$run of $(SEEDS) ===="; \
	    $(RUN_FRESH) $(MAKE) --no-print-directory $(RANDOM_ARGS) FCOV_XML=$(CURDIR)/$(COV_DIR)/fcov_run$$run.xml && $(TESTS_PASSED) || exit 1; \
	    cp coverage.dat $(COV_DIR)/cov_run$$run.dat; \
	done
	@verilator_coverage --write $(COV_DIR)/merged_all.dat $(COV_DIR)/cov_suite.dat $(COV_DIR)/cov_run*.dat
	@{ echo "cov_all: full suite + $(SEEDS) random runs x $(EVENTS) events - $$(date)"; \
	   echo "result: every test passed (cov_all stops at the first failure)"; \
	   echo "covers hit per checker:"; \
	   $(MAKE) --no-print-directory cov_summary MERGED=$(COV_DIR)/merged_all.dat; \
	   echo "zero-hit covers:"; \
	   $(MAKE) --no-print-directory cov_zero MERGED=$(COV_DIR)/merged_all.dat; \
	   echo "functional coverage (covergroups):"; \
	   python3 $(TB_DIR)/fcov_report.py merge $(COV_DIR)/fcov_all.xml $(COV_DIR)/fcov_suite.xml $(COV_DIR)/fcov_run*.xml; \
	   python3 $(TB_DIR)/fcov_report.py report $(COV_DIR)/fcov_all.xml; \
	 } > $(COVERAGE_DIR)/summary.txt
	@echo "==== cov_all: suite + $(SEEDS) random runs passed; summary in $(COVERAGE_DIR)/summary.txt ===="
	@cat $(COVERAGE_DIR)/summary.txt

# soak: an unattended sweep. Unlike random_seeds it does NOT stop on a failure:
# every seed runs. The evidence a reviewer needs lands in SOAK_DIR (tracked):
#   results.txt     every run's PASS/FAIL and seed - each line is replayable
#   summary.txt     covers hit vs zero per checker, plus the zero-hit covers
#   all_events.csv  every event of every run under one header
#   merged.dat      the merged coverage the summary was computed from
#   functional_coverage.xml  the merged covergroups (cocotb-coverage); its
#                   readable report is the end of summary.txt
# Per-run files - runN.log, events_runN.csv, cov_runN.dat and fcov_runN.xml
# (the run's functional coverage) - go to SOAK_RAW
# (gitignored, kept on disk). A new soak replaces the previous soak's files;
# SOAK_DIR/README.md is never touched. Run 1 goes alone and builds
# SOAK_RAW/build; the rest run SOAK_JOBS at a time through
# sim/scripts/soak_run.sh, each in its own folder with seed = start time + run
# number, so runs started together never share a seed.
soak:
	@mkdir -p $(SOAK_RAW)
	@rm -f $(SOAK_RAW)/run*.log $(SOAK_RAW)/events_run*.csv $(SOAK_RAW)/cov_run*.dat \
	       $(SOAK_RAW)/fcov_run*.xml $(SOAK_RAW)/runs.txt \
	       $(SOAK_DIR)/results.txt $(SOAK_DIR)/summary.txt $(SOAK_DIR)/all_events.csv \
	       $(SOAK_DIR)/merged.dat $(SOAK_DIR)/functional_coverage.xml
	@echo "soak: $(SEEDS) runs x $(EVENTS) events, $(SOAK_JOBS) at a time - started $$(date)" \
	    | tee $(SOAK_DIR)/results.txt
	@base=$$(date +%s); \
	export SUITE_MAKEFILE=$(TB_DIR)/Makefile SOAK_RAW=$(abspath $(SOAK_RAW)) \
	       SIM_BUILD=$(abspath $(SOAK_RAW))/build SOAK_ARGS="$(RANDOM_ARGS)"; \
	echo "  run 1 builds the simulation first, then $(SOAK_JOBS) at a time"; \
	bash $(SOAK_RUN) 1 $$base | tee $(SOAK_RAW)/runs.txt; \
	seq 2 $(SEEDS) | xargs -r -P $(SOAK_JOBS) -I{} bash $(SOAK_RUN) {} $$base \
	    | tee -a $(SOAK_RAW)/runs.txt
	@sort -t' ' -k2,2n $(SOAK_RAW)/runs.txt >> $(SOAK_DIR)/results.txt
	@echo "soak: finished $$(date)" | tee -a $(SOAK_DIR)/results.txt
	@verilator_coverage --write $(SOAK_DIR)/merged.dat $(SOAK_RAW)/cov_run*.dat
	@$(MAKE) --no-print-directory cov_summary MERGED=$(SOAK_DIR)/merged.dat  > $(SOAK_DIR)/summary.txt
	@echo "zero-hit covers:"                                                 >> $(SOAK_DIR)/summary.txt
	@$(MAKE) --no-print-directory cov_zero    MERGED=$(SOAK_DIR)/merged.dat >> $(SOAK_DIR)/summary.txt
	@awk 'FNR == 1 && NR != 1 { next } { print }' $$(ls $(SOAK_RAW)/events_run*.csv | sort -V) > $(SOAK_DIR)/all_events.csv
	@python3 $(TB_DIR)/fcov_report.py merge $(SOAK_DIR)/functional_coverage.xml $(SOAK_RAW)/fcov_run*.xml
	@echo "functional coverage (covergroups):"                                >> $(SOAK_DIR)/summary.txt
	@python3 $(TB_DIR)/fcov_report.py report $(SOAK_DIR)/functional_coverage.xml >> $(SOAK_DIR)/summary.txt
	@echo "soak: $$(grep -c ': PASS' $(SOAK_DIR)/results.txt) passed, $$(grep -c ': FAIL' $(SOAK_DIR)/results.txt) failed - see $(SOAK_DIR)/"
	@cat $(SOAK_DIR)/summary.txt

# audit_soak: audit_soak.py over the soak's transaction log - every event of
# every run checked against the register map's rules, independently of the
# model (see the script's header). Fails on any anomaly.
audit_soak:
	@test -f $(SOAK_DIR)/all_events.csv || { echo "no $(SOAK_DIR)/all_events.csv - run 'make soak' first"; exit 1; }
	@python3 $(TB_DIR)/audit_soak.py $(SOAK_DIR)/all_events.csv

# check_merged: cov_zero / cov_summary need a merge to read
check_merged:
	@test -n "$(MERGED)" -a -f "$(MERGED)" || \
	    { echo "no merged coverage yet - run 'make random_seeds', 'make cov_all' or 'make soak' first"; exit 1; }

# cov_zero: every cover in the listed checkers that NO merged run hit, one per
# line as "<hierarchy>.<cover>  (<checker file>:<line>)". A coverage record is
# \001key\002value fields; the awk keeps the file name (f), line (l) and
# hierarchy (h) and drops the absolute path, so the output is the same on
# every machine. The lines are captured first and tested for emptiness: a
# pipeline's exit status is awk's, which succeeds even when it prints nothing.
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

# cov_summary: hit / zero counts per checker in the merged coverage
cov_summary: check_merged
	@for checker in reg_file_sva spi_slave_sva; do \
	    total=$$(grep -c "$$checker" $(MERGED)); \
	    zero=$$(grep "$$checker" $(MERGED) | awk '$$NF == 0' | wc -l); \
	    echo "  $$checker: $$((total - zero)) of $$total covers hit, $$zero at zero"; \
	done

# clean_cov: the coverage in COV_DIR only (random_seeds' and cov_all's). A
# soak's evidence is never cleaned by a target - the next soak replaces it.
# cocotb's own 'make clean' removes sim_build.
clean_cov:
	@rm -f cov/cov_*.dat cov/merged.dat cov/merged_all.dat cov/fcov_*.xml