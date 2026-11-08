#
# Filename:         host_if.mk
#
# File Description: The cocotb host-interface suite (tb/telemetry/host_if:
#                   spi_slave + reg_file, a reference model, a scoreboard,
#                   constrained-random traffic and covergroups) run from here
#                   like the module testbenches, in the SystemVerilog flow and
#                   the converted-Verilog flow, and listed in the same result
#                   tables. The suite's own Makefile and its random-test
#                   targets (soak, cov_all, replay) are unchanged; see
#                   tb/telemetry/host_if/COMMANDS.md for those.
#
# Global variables: HOSTIF_DIR, HOSTIF_EVENTS, HOSTIF_FLAGS, run_cocotb

##@ Host-interface cocotb suite (tb/telemetry/host_if)

# HOSTIF_DIR: the suite's folder
HOSTIF_DIR := $(abspath ../tb/telemetry/host_if)

# HOSTIF_EVENTS: random_walk events inside the suite run. Large enough that
#                every SVA cover - including the rare ones only random traffic
#                reaches, such as an address wrap at 0x7F - fires in one run.
HOSTIF_EVENTS ?= 400

# HOSTIF_FLAGS: Verilator flags for the suite - the module testbenches' lint
#               level and waivers, without --binary (cocotb supplies main)
HOSTIF_FLAGS := --assert --coverage-user -Wall $(LINT_WAIVERS) $(TB_WAIVERS)

# run_cocotb: $(1) flow, $(2) Verilator flags, $(3) sources - absolute, since
#             the suite runs from its build directory
run_cocotb = HOSTIF_DIR='$(HOSTIF_DIR)' HOSTIF_EVENTS='$(HOSTIF_EVENTS)' \
             QUIET='$(QUIET)' NOFAIL='$(NOFAIL)' STRICT='$(STRICT)' \
             bash $(SCRIPTS)/run_cocotb.sh $(TBBUILD)/$(1)/host_if_tb $(1) '$(2)' $(3)

.PHONY: tb_host_if equiv_host_if

tb_host_if:  ## cocotb host-interface suite on the SystemVerilog source
	@$(call run_cocotb,sv,$(HOSTIF_FLAGS),$(abspath $(RTL)))

equiv_host_if: $(EQUIV_SRCS)  ## the same suite on the sv2v output (SPLIT=1: on rtl-verilog)
	@$(call run_cocotb,$(EQUIV_FLOW),$(HOSTIF_FLAGS) $(EQUIV_WAIVERS),$(abspath $(PKG) $(EQUIV_SRCS)))
