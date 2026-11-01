#
# Filename:         config.mk
#
# File Description: Tools, paths, run modes and terminal colours for the sim/
#                   Makefile. Every value here is a default (?=), so any of
#                   them can be overridden on the command line or in the
#                   environment, e.g. `make syn YOSYS=yosys`.
#
# Global variables: COLOR - exported to the run scripts, see below
#                   C_* and the say/ok/warn/err helpers - used by every mk file

# ============================================================
# Tools
# ============================================================
VERILATOR          ?= verilator
VERILATOR_COVERAGE ?= verilator_coverage
VIEWER             ?= gtkwave
SV2V               ?= sv2v
YOSYS              ?= $(HOME)/oss-cad-suite/bin/yosys
IVERILOG           ?= iverilog
VVP                ?= vvp
PYTHON             ?= python3
SHELLCHECK         ?= shellcheck

# VJOBS: parallel C++ compile jobs inside each Verilator build
#        (--build-jobs). The run scripts start Verilator outside make's
#        jobserver, so without this its compile ran on one core - the
#        integration testbench's alone took over a minute.
VJOBS ?= $(shell nproc 2>/dev/null || echo 2)

# ============================================================
# Paths
# ============================================================
SCRIPTS := scripts

# SV_DIR: the SystemVerilog design source - what is edited.
# V_DIR:  its Verilog-2005 split - one .v per .sv, same layout, with the
#         comments sv2v discards carried over (mk/verilog.mk).
SV_DIR := ../rtl-systemverilog
V_DIR  := ../rtl-verilog

# TBBUILD: under $(HOME), not in the repo. This tree is a Windows mount and
#          Verilator writes hundreds of small files, each a 9p round trip.
#          Layout is $(TBBUILD)/<flow>/<top>, flow being sv, equiv, iv, ...
TBBUILD ?= $(HOME)/build/sync_buck

# WAVEDIR: saved GTKWave selections, one <top>.gtkw per testbench. Outside
#          TBBUILD so tb_clean does not destroy them.
WAVEDIR ?= $(HOME)/gtkwave

# SYNDIR: inside the repo so the converted file is visible in the editor and
#         easy to hand to an ASIC flow. Slower over 9p, but conversion runs
#         rarely and the output is committed rather than scratch.
SYNDIR    ?= ../Build
CONVERTED := $(SYNDIR)/pmic_full.v

# LIBERTY: sky130 high-density cells for real area numbers. Install with
#          `volare enable --pdk sky130 <version>`.
LIBERTY ?= $(HOME)/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# ============================================================
# Run modes - settable on the command line
# ============================================================
#   QUIET=1   logs to file only, one status line per testbench
#   STRICT=1  INCONCLUSIVE (a zero-hit cover) fails like FAIL does - for CI
#   NOFAIL=1  individual runs always exit 0; the suite report decides
#   WAVES=1   dump a VCD
# Suite targets set QUIET and NOFAIL themselves, and make passes
# target-specific values down to every prerequisite.
QUIET  ?= 0
STRICT ?= 0
NOFAIL ?= 0
WAVES  ?= 0

# Presentation only - none of these changes a verdict (scripts/ui.sh):
#   RAW=1        stream the simulation output untouched, without the filter
#                that colours it and folds repeated failures
#   FAIL_SHOW=n  failure lines shown per assertion or check label before
#                the rest are counted (default 5)
#   THIN=n       a cover hit fewer than n times is flagged as thinly
#                exercised (default 10)
# Exported so the run scripts see them; unset, they export empty and the
# scripts fall back to the defaults.
export RAW FAIL_SHOW THIN

# ============================================================
# Colours
# ============================================================
# COLOR: 1 = ANSI colour, 0 = plain text. Decided once, here, because recipes
#        run under --output-sync: their stdout is a temporary file, so the
#        scripts cannot ask whether they are writing to a terminal. Make's own
#        stderr still is one, so the test is on fd 2. Off when NO_COLOR is set
#        (https://no-color.org), when TERM is dumb or unset, and in CI, where
#        stderr is not a terminal - so job logs and summaries stay plain.
#        Force with COLOR=1 or COLOR=0. Exported, so run_tb.sh, run_top_tb.sh,
#        report.sh and the other scripts follow the same decision.
COLOR ?= $(shell if [ -t 2 ] && [ -z "$${NO_COLOR:-}" ] && [ -n "$${TERM:-}" ] && [ "$${TERM}" != dumb ]; then echo 1; else echo 0; fi)
export COLOR

ifeq ($(COLOR),1)
C_RED := \033[31m
C_GRN := \033[32m
C_YEL := \033[33m
C_BLU := \033[34m
C_CYN := \033[36m
C_BLD := \033[1m
C_OFF := \033[0m
else
C_RED :=
C_GRN :=
C_YEL :=
C_BLU :=
C_CYN :=
C_BLD :=
C_OFF :=
endif

# say / ok / warn / err: one-line status messages for recipes, as
#   @$(call ok,lint passed)
# The text goes through %s, never as a format string, so a % in it is safe.
# It sits in double quotes, so a shell variable ($$top) expands; keep double
# quotes and backticks out of it.
say  = printf '%b==>%b %s\n'  '$(C_BLU)$(C_BLD)' '$(C_OFF)' "$(1)"
ok   = printf '%b-- %s%b\n'   '$(C_GRN)' "$(1)" '$(C_OFF)'
warn = printf '%b!! %s%b\n'   '$(C_YEL)' "$(1)" '$(C_OFF)'
err  = printf '%bxx %s%b\n'   '$(C_RED)' "$(1)" '$(C_OFF)' >&2
