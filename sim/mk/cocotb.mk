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
#                   The soaks run from here too (soak_host_if,
#                   soak_top_cocotb, soak_all): each calls its suite's own soak
#                   target, so the evidence lands in the suite's soak/ folder
#                   exactly as when run there. verify_all is the whole
#                   verification in one command - the CI regression, then both
#                   soaks. Each suite's other random-test targets (cov_all,
#                   replay, ...) stay in its own Makefile; see the COMMANDS.md
#                   in its folder.
#
# Global variables: HOSTIF_DIR, HOSTIF_EVENTS, HOSTIF_FLAGS, TOPCOCO_DIR,
#                   TOPCOCO_EVENTS, TOPCOCO_FLAGS, TOPCOCO_EQUIV_WAIVERS,
#                   COCOTB_FLAGS, FCOV_REPORT, run_cocotb,
#                   HOSTIF_SOAK_SEEDS, HOSTIF_SOAK_EVENTS, TOPCOCO_SOAK_SEEDS,
#                   TOPCOCO_SOAK_EVENTS, TOPCOCO_SOAK_CHECKERS, SOAK_JOBS

##@ cocotb suites (tb/telemetry/host_if, tb/top/pmic_top)

# HOSTIF_DIR / TOPCOCO_DIR: the suites' folders
HOSTIF_DIR  := $(abspath ../tb/telemetry/host_if)
TOPCOCO_DIR := $(abspath ../tb/top/pmic_top)

# HOSTIF_EVENTS: random_walk events inside the host-interface suite run. Large
#                enough that every SVA cover - including the rare ones only
#                random traffic reaches, such as an address wrap at 0x7F -
#                fires in one run.
HOSTIF_EVENTS ?= 400

# TOPCOCO_EVENTS: random_walk events inside the whole-supervisor suite run.
#                 Board events cost milliseconds of simulated time each, so
#                 this is kept small; the suite's own soak is the long run.
TOPCOCO_EVENTS ?= 12

# FCOV_REPORT: merges and reports cocotb-coverage exports - host_if's script,
#              shared by both suites
FCOV_REPORT := $(HOSTIF_DIR)/fcov_report.py

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
run_cocotb = SUITE_VARS='$(6)' COVER_FILTER='$(7)' FCOV_REPORT='$(FCOV_REPORT)' QUIET='$(QUIET)' NOFAIL='$(NOFAIL)' STRICT='$(STRICT)' \
             bash $(SCRIPTS)/run_cocotb.sh $(TBBUILD)/$(1)/$(2) $(1) $(2) $(3) '$(4)' $(5)

.PHONY: tb_host_if equiv_host_if tb_top_cocotb equiv_top_cocotb

tb_host_if:  ## cocotb host-interface suite on the SystemVerilog source
	@$(call run_cocotb,sv,host_if_tb,$(HOSTIF_DIR),$(HOSTIF_FLAGS),$(abspath $(RTL)),RANDOM_EVENTS=$(HOSTIF_EVENTS))

equiv_host_if: $(EQUIV_SRCS)  ## the same suite on the sv2v output (SPLIT=1: on rtl-verilog)
	@$(call run_cocotb,$(EQUIV_FLOW),host_if_tb,$(HOSTIF_DIR),$(HOSTIF_FLAGS) $(EQUIV_WAIVERS),$(abspath $(PKG) $(EQUIV_SRCS)),RANDOM_EVENTS=$(HOSTIF_EVENTS))

tb_top_cocotb:  ## cocotb whole-supervisor suite on the SystemVerilog source (~10 min)
	@$(call run_cocotb,sv,pmic_top_cocotb,$(TOPCOCO_DIR),$(TOPCOCO_FLAGS),$(abspath $(RTL)),RANDOM_EVENTS=$(TOPCOCO_EVENTS),pmic_top_sva)

equiv_top_cocotb: $(EQUIV_SRCS)  ## the same suite on the sv2v output (SPLIT=1: on rtl-verilog)
	@$(call run_cocotb,$(EQUIV_FLOW),pmic_top_cocotb,$(TOPCOCO_DIR),$(TOPCOCO_FLAGS) $(TOPCOCO_EQUIV_WAIVERS),$(abspath $(PKG) $(EQUIV_SRCS)),RANDOM_EVENTS=$(TOPCOCO_EVENTS),pmic_top_sva)

# ------------------------------------------------------------------
# Soaks: long constrained-random sweeps, run one seed per core
# ------------------------------------------------------------------
# HOSTIF_SOAK_SEEDS / HOSTIF_SOAK_EVENTS: the host_if soak's size - the size
#                     of its closing soak
HOSTIF_SOAK_SEEDS   ?= 100
HOSTIF_SOAK_EVENTS  ?= 200
# TOPCOCO_SOAK_SEEDS / TOPCOCO_SOAK_EVENTS: the pmic_top soak's size. A board
#                     event costs ~3 s with every checker bound, so 64 x 200
#                     is about 10 minutes per seed, 64 seeds over the cores.
TOPCOCO_SOAK_SEEDS  ?= 64
TOPCOCO_SOAK_EVENTS ?= 200
# TOPCOCO_SOAK_CHECKERS: all - every block checker as well as pmic_top_sva;
#                     top - pmic_top_sva alone, about ten times faster
TOPCOCO_SOAK_CHECKERS ?= all
# SOAK_JOBS: seeds simulated at once, in either soak - every core by default
SOAK_JOBS ?= $(shell nproc 2>/dev/null || echo 1)

.PHONY: soak_host_if soak_top_cocotb soak_all verify_all

soak_host_if:  ## host_if soak, one seed per core; evidence in tb/telemetry/host_if/soak/
	@$(call say,host_if soak - $(HOSTIF_SOAK_SEEDS) seeds x $(HOSTIF_SOAK_EVENTS) events - $(SOAK_JOBS) at a time)
	@env -u MAKEFLAGS -u MFLAGS -u MAKELEVEL $(MAKE) -C $(HOSTIF_DIR) soak \
	    SEEDS=$(HOSTIF_SOAK_SEEDS) EVENTS=$(HOSTIF_SOAK_EVENTS) SOAK_JOBS=$(SOAK_JOBS)
	@bash $(SCRIPTS)/soak_verdict.sh $(HOSTIF_DIR)/soak/results.txt

soak_top_cocotb:  ## pmic_top soak, every checker, one seed per core; evidence in tb/top/pmic_top/soak/
	@$(call say,pmic_top soak - $(TOPCOCO_SOAK_SEEDS) seeds x $(TOPCOCO_SOAK_EVENTS) events - checkers $(TOPCOCO_SOAK_CHECKERS) - $(SOAK_JOBS) at a time)
	@env -u MAKEFLAGS -u MFLAGS -u MAKELEVEL $(MAKE) -C $(TOPCOCO_DIR) soak \
	    SEEDS=$(TOPCOCO_SOAK_SEEDS) EVENTS=$(TOPCOCO_SOAK_EVENTS) \
	    SOAK_CHECKERS=$(TOPCOCO_SOAK_CHECKERS) SOAK_JOBS=$(SOAK_JOBS)
	@bash $(SCRIPTS)/soak_verdict.sh $(TOPCOCO_DIR)/soak/results.txt

# soak_all: one after the other - each already uses every core. Both run even
# if the first has failing seeds; the target fails at the end if either did.
soak_all:  ## both soaks, one after the other (hours); fails if any seed failed
	@rc=0; \
	$(MAKE) --no-print-directory soak_host_if    || rc=1; \
	$(MAKE) --no-print-directory soak_top_cocotb || rc=1; \
	exit $$rc

verify_all:  ## the complete verification: make ci (every testbench, both flows), then soak_all
	@$(call say,verify_all 1/2 - CI regression) && $(MAKE) --no-print-directory ci
	@$(call say,verify_all 2/2 - soaks) && $(MAKE) --no-print-directory soak_all
	@$(call ok,verify_all: the CI regression and every soak seed passed)
