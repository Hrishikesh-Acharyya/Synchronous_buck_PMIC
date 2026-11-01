#
# Filename:         top.mk
#
# File Description: The integration testbench ../tb/pmic_top_tb.v, which
#                   exercises pmic_top as a whole: plain Verilog-2005, no SVA,
#                   self-checking, with its own coverage bins and two
#                   scoreboards. It runs in three flows -
#                     tb_top     Verilator, SystemVerilog source
#                     equiv_top  Verilator, converted Verilog
#                     iv_top     Icarus Verilog, converted Verilog
#                   - and each has a _notel twin for the SPI-less build
#                   (TELEMETRY_EN=0), which runs the testbench's pins-only
#                   sequence on the default timers. tb_top and equiv_top join
#                   tb_all / equiv / equiv_all. scripts/run_top_tb.sh takes the
#                   verdict from the testbench's last line, which is also what
#                   gives Icarus a non-zero exit on FAIL - vvp exits 0 from
#                   $stop.
#
# Global variables: TOP_TB, TOP_CLK_HZ, TOP_TEL

##@ Integration testbench (tb/pmic_top_tb.v; _notel = SPI-less build)

TOP_TB := ../tb/pmic_top_tb.v

# TOP_CLK_HZ: the testbench's CLK_HZ parameter, which sets the clock it drives
#             and every time it expects. It must equal CLK_HZ in the package,
#             so it is read from there - change the clock in one place only.
TOP_CLK_HZ ?= $(shell sed -nE 's/^[[:space:]]*localparam int CLK_HZ[[:space:]]*=[[:space:]]*([0-9_]+);.*/\1/p' $(PKG) | tr -d _)

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
# --trace only when a VCD is wanted: it slows the long run noticeably.
TOP_VFLAGS  = --binary --timing --build-jobs $(VJOBS) -Wall $(LINT_WAIVERS) $(TB_WAIVERS) $(TOP_TB_WAIVERS) \
              $(if $(filter 1,$(WAVES)),--trace)
TOP_IVFLAGS := -g2005

# TOP_TEL: TELEMETRY_EN for the testbench, which passes it on to pmic_top, so
#          one value selects the build and the sequence that fits it: 1 the
#          full build and its SPI sequence, 0 the SPI-less build and its
#          pins-only sequence. The _notel targets set 0 and record under their
#          own flow names (sv_notel, equiv_notel, iv_notel).
TOP_TEL ?= 1
IV_FLOW := $(if $(filter 1,$(SPLIT)),iv_split,iv)

# run_top: $(1) simulator, $(2) flow, $(3) sources, $(4) Verilator flags
run_top = VERILATOR='$(VERILATOR)' IVERILOG='$(IVERILOG)' VVP='$(VVP)' \
          TOP_VFLAGS='$(4) -GCLK_HZ=$(TOP_CLK_HZ) -GTELEMETRY_EN=$(TOP_TEL)' \
          TOP_IVFLAGS='$(TOP_IVFLAGS) -Ppmic_top_tb.CLK_HZ=$(TOP_CLK_HZ) -Ppmic_top_tb.TELEMETRY_EN=$(TOP_TEL)' \
          QUIET='$(QUIET)' NOFAIL='$(NOFAIL)' WAVES='$(WAVES)' \
          bash $(SCRIPTS)/run_top_tb.sh $(1) $(TBBUILD)/$(2)/pmic_top_tb $(2) $(3)

.PHONY: tb_top equiv_top iv_top top_all wave_top view_top \
        tb_top_notel equiv_top_notel iv_top_notel top_notel top_both

tb_top:  ## Verilator on the SystemVerilog source
	@$(call run_top,verilator,sv,$(RTL) $(TOP_TB),$(TOP_VFLAGS) $(TOP_SV_WAIVERS))

equiv_top: $(EQUIV_SRCS)  ## Verilator on the converted Verilog (SPLIT=1: rtl-verilog)
	@$(call run_top,verilator,$(EQUIV_FLOW),$(EQUIV_SRCS) $(TOP_TB),$(TOP_VFLAGS) $(TOP_EQUIV_WAIVERS))

iv_top: $(EQUIV_SRCS)  ## Icarus Verilog on the converted Verilog (slow at 50 MHz)
	@$(call run_top,iverilog,$(IV_FLOW),$(EQUIV_SRCS) $(TOP_TB),)

top_all: QUIET  := 1
top_all: NOFAIL := 1
top_all: tb_top equiv_top iv_top  ## all three flows, then the table
	@rc=0; \
	for f in sv $(EQUIV_FLOW) $(IV_FLOW); do bash $(SCRIPTS)/report.sh $(TBBUILD) $$f pmic_top_tb || rc=1; done; \
	exit $$rc

wave_top: WAVES := 1
wave_top: tb_top  ## tb_top with a VCD (large: hundreds of ms simulated), then GTKWave
	@$(call open_wave,pmic_top_tb)

view_top:  ## open the last integration VCD without re-running
	@$(call open_wave,pmic_top_tb)

tb_top_notel: TOP_TEL := 0
tb_top_notel:  ## SPI-less build, Verilator, SystemVerilog source
	@$(call run_top,verilator,sv_notel,$(RTL) $(TOP_TB),$(TOP_VFLAGS) $(TOP_SV_WAIVERS))

equiv_top_notel: TOP_TEL := 0
equiv_top_notel: $(EQUIV_SRCS)  ## SPI-less build, Verilator, converted Verilog
	@$(call run_top,verilator,$(EQUIV_FLOW)_notel,$(EQUIV_SRCS) $(TOP_TB),$(TOP_VFLAGS) $(TOP_EQUIV_WAIVERS))

iv_top_notel: TOP_TEL := 0
iv_top_notel: $(EQUIV_SRCS)  ## SPI-less build, Icarus Verilog, converted Verilog
	@$(call run_top,iverilog,$(IV_FLOW)_notel,$(EQUIV_SRCS) $(TOP_TB),)

top_notel: QUIET  := 1
top_notel: NOFAIL := 1
top_notel: tb_top_notel equiv_top_notel iv_top_notel  ## SPI-less build in all three flows, then the table
	@rc=0; \
	for f in sv_notel $(EQUIV_FLOW)_notel $(IV_FLOW)_notel; do \
	    bash $(SCRIPTS)/report.sh $(TBBUILD) $$f pmic_top_tb || rc=1; done; \
	exit $$rc

top_both: top_all top_notel  ## both builds, all three flows
