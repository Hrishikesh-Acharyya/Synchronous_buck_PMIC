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
#                   and every output lands there.
#
# Global variables: TB_DIR, REPO, SV_DIR, PKG, RTL_SRCS, SVA_SRCS, TB_SRCS,
#                   HOSTIF_DIR - sources and paths
#                   TELEMETRY_EN - the build under test
#                   SIM, TOPLEVEL_LANG, VERILOG_SOURCES, TOPLEVEL, MODULE,
#                   EXTRA_ARGS - cocotb's variables

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
