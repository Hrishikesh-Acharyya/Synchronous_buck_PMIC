#
# Filename:         cocotb.mk
#
# File Description: The cocotb suites, run from here like the module
#                   testbenches - in the SystemVerilog flow and the
#                   converted-Verilog flow - and listed in the same result
#                   tables:
#                     host_if_tb       tb/telemetry/host_if: spi_slave + reg_file,
#                                      a reference model and scoreboard,
#                                      constrained-random traffic, covergroups
#                     pmic_top_cocotb  tb/top/pmic_top: the whole supervisor in
#                                      a board model, checked against a
#                                      supervisor model, with every block's
#                                      checker and pmic_top_sva bound
#                   Each suite's own Makefile and random-test targets (soak,
#                   cov_all, replay) are unchanged; see the COMMANDS.md in its
#                   folder.
#
# Global variables: HOSTIF_DIR, HOSTIF_EVENTS, HOSTIF_FLAGS, TOPCOCO_DIR,
#                   TOPCOCO_FLAGS, TOPCOCO_EQUIV_WAIVERS, COCOTB_FLAGS, run_cocotb

##@ cocotb suites (tb/telemetry/host_if, tb/top/pmic_top)

# HOSTIF_DIR / TOPCOCO_DIR: the suites' folders
HOSTIF_DIR  := $(abspath ../tb/telemetry/host_if)
TOPCOCO_DIR := $(abspath ../tb/top/pmic_top)

# HOSTIF_EVENTS: random_walk events inside the host-interface suite run. Large
#                enough that every SVA cover - including the rare ones only
#                random traffic reaches, such as an address wrap at 0x7F -
#                fires in one run.
HOSTIF_EVENTS ?= 400

# COCOTB_FLAGS: Verilator flags common to both suites - the module
#               testbenches' lint level and waivers, without --binary
#               (cocotb supplies main)
COCOTB_FLAGS  := --assert --coverage-user -Wall $(LINT_WAIVERS) $(TB_WAIVERS)
HOSTIF_FLAGS  := $(COCOTB_FLAGS)
# TOPCOCO_FLAGS: the harness generates its clock (--timing) and only its own
#                ports are public, which keeps Verilator's optimisation
TOPCOCO_FLAGS := $(COCOTB_FLAGS) --timing --no-public-flat-rw --public-depth 1 -GTELEMETRY_EN=1
# TOPCOCO_EQUIV_WAIVERS: the converted file only. With the internal signals
#                        no longer public, sv2v's spi_slave shows an unread
#                        bit (tx_shift[7]) that the SystemVerilog source does
#                        not; the integration testbench's converted flow
#                        waives the same class (TOP_EQUIV_WAIVERS).
TOPCOCO_EQUIV_WAIVERS := $(EQUIV_WAIVERS) -Wno-UNUSEDSIGNAL

# run_cocotb: $(1) flow, $(2) result name, $(3) suite folder, $(4) Verilator
#             flags, $(5) sources - absolute, since the suite runs from its
#             build directory - $(6) extra make variables for the suite and
#             $(7) a regex on the checker files whose covers decide the verdict
run_cocotb = SUITE_VARS='$(6)' COVER_FILTER='$(7)' QUIET='$(QUIET)' NOFAIL='$(NOFAIL)' STRICT='$(STRICT)' \
             bash $(SCRIPTS)/run_cocotb.sh $(TBBUILD)/$(1)/$(2) $(1) $(2) $(3) '$(4)' $(5)

.PHONY: tb_host_if equiv_host_if tb_top_cocotb equiv_top_cocotb

tb_host_if:  ## cocotb host-interface suite on the SystemVerilog source
	@$(call run_cocotb,sv,host_if_tb,$(HOSTIF_DIR),$(HOSTIF_FLAGS),$(abspath $(RTL)),RANDOM_EVENTS=$(HOSTIF_EVENTS))

equiv_host_if: $(EQUIV_SRCS)  ## the same suite on the sv2v output (SPLIT=1: on rtl-verilog)
	@$(call run_cocotb,$(EQUIV_FLOW),host_if_tb,$(HOSTIF_DIR),$(HOSTIF_FLAGS) $(EQUIV_WAIVERS),$(abspath $(PKG) $(EQUIV_SRCS)),RANDOM_EVENTS=$(HOSTIF_EVENTS))

tb_top_cocotb:  ## cocotb whole-supervisor suite on the SystemVerilog source (~5 min)
	@$(call run_cocotb,sv,pmic_top_cocotb,$(TOPCOCO_DIR),$(TOPCOCO_FLAGS),$(abspath $(RTL)),,pmic_top_sva)

equiv_top_cocotb: $(EQUIV_SRCS)  ## the same suite on the sv2v output (SPLIT=1: on rtl-verilog)
	@$(call run_cocotb,$(EQUIV_FLOW),pmic_top_cocotb,$(TOPCOCO_DIR),$(TOPCOCO_FLAGS) $(TOPCOCO_EQUIV_WAIVERS),$(abspath $(PKG) $(EQUIV_SRCS)),,pmic_top_sva)
