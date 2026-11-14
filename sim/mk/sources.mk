#
# Filename:         sources.mk
#
# File Description: Source lists and Verilator flags. The RTL file list, the
#                   bound checkers, the waivers with the reason for each, and
#                   the lists derived from TESTBENCHES (set in the Makefile).
#
# Global variables: RTL, PKG, SVA_SRCS, EQUIV_SRCS, VFLAGS and the waiver sets

# ============================================================
# Sources
# ============================================================
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
#          instead of the single-file conversion in $(SYNDIR). Results are
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

# Derived from TESTBENCHES (Makefile): the module names and testbench tops.
TB_MODULES := $(notdir $(TESTBENCHES))
TB_TOPS    := $(addsuffix _tb,$(TB_MODULES))
# SUITE_TOPS: what the suite tables list - every module testbench, then the
#             integration testbench
SUITE_TOPS := $(TB_TOPS) pmic_top_tb host_if_tb pmic_top_cocotb

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
#   --build-jobs:    parallel C++ compile, see VJOBS in config.mk.
VFLAGS := --binary --timing --assert --no-stop-fail --coverage-user --trace \
          --build-jobs $(VJOBS) -Wall $(LINT_WAIVERS) $(TB_WAIVERS)

# Single lint top: elaborating the whole hierarchy is the only way port
# width mismatches between modules get caught.
LINT_TOPS := pmic_top
