#
# Filename:         syn.mk
#
# File Description: sv2v conversion to one Verilog-2005 file, and yosys
#                   synthesis of it: generic cell counts, sky130-mapped area
#                   (needs LIBERTY), the same for the SPI-less build, and a
#                   cell-count comparison against another git revision.
#
# Global variables: CONVERTED_NOTEL, BASE

##@ Conversion and synthesis

# ASIC flows take Verilog, so synthesis reads the sv2v output. The equiv_
# targets are the evidence the two are the same design.
#
# The SPI-less build needs no second conversion: sv2v keeps TELEMETRY_EN as a
# Verilog parameter and the generate blocks as Verilog generates, so yosys
# selects it with chparam. convert_notel writes a copy with the default
# flipped, for flows that cannot set a parameter.
CONVERTED_NOTEL := $(SYNDIR)/pmic_full_notel.v
TEL_V_ON  := parameter [0:0] TELEMETRY_EN = 1'b1;
TEL_V_OFF := parameter [0:0] TELEMETRY_EN = 1'b0;

.PHONY: convert convert_notel syn syn_area syn_notel syn_area_notel syn_both syn_compare syn_clean

convert: $(CONVERTED)  ## sv2v the RTL into one Verilog-2005 file (Build/pmic_full.v)

$(CONVERTED): $(RTL)
	@mkdir -p $(SYNDIR)
	$(SV2V) $(RTL) > $@
	@$(call ok,converted: $$(wc -l < $@) lines of Verilog-2005 in $@)

convert_notel: $(CONVERTED)  ## copy of it with TELEMETRY_EN defaulting to 0 (Build/pmic_full_notel.v)
	@grep -qF "$(TEL_V_ON)" $(CONVERTED) || { $(call err,TELEMETRY_EN default not found in $(CONVERTED)); exit 1; }
	@sed "s/parameter \[0:0\] TELEMETRY_EN = 1'b1;/$(TEL_V_OFF)/" $(CONVERTED) > $(CONVERTED_NOTEL)
	@grep -qF "$(TEL_V_OFF)" $(CONVERTED_NOTEL)
	@$(call ok,SPI-less conversion in $(CONVERTED_NOTEL))

# -flatten: area is a whole-design number; a module instantiated three times
#           counts once in the hierarchical stat.
# -l, tee -o: yosys writes the full log (-l) and the statistics table (tee -o)
#           to files itself rather than through a redirected stdout. The YoWASP
#           (WebAssembly) build of yosys truncates a redirected stdout, which
#           left a partial log and an empty table; files written by yosys are
#           exact with every build. -q keeps the terminal quiet.
syn: $(CONVERTED)  ## yosys synthesis, generic cell and flop counts
	@$(call say,synthesising pmic_top with yosys)
	@$(YOSYS) -q -l $(SYNDIR)/stat.txt -p "read_verilog $(CONVERTED); \
	             hierarchy -top pmic_top; \
	             synth -top pmic_top -flatten; \
	             tee -o $(SYNDIR)/stat_summary.txt stat" > /dev/null 2>&1 \
	    || { $(call err,yosys failed - see $(SYNDIR)/stat.txt); tail -20 $(SYNDIR)/stat.txt; exit 1; }
	@cat $(SYNDIR)/stat_summary.txt
	@$(call ok,full log: $(SYNDIR)/stat.txt)

# dfflibmap before abc: abc maps combinational logic only, so flops must be
# bound to library cells first or they contribute nothing to the area.
syn_area: $(CONVERTED)  ## sky130-mapped area (needs LIBERTY)
	@test -f $(LIBERTY) || { \
	    $(call err,no liberty file at $(LIBERTY)); \
	    $(call warn,set LIBERTY=path or run: volare enable --pdk sky130 version); \
	    exit 1; }
	@$(call say,mapping pmic_top to sky130_fd_sc_hd)
	@$(YOSYS) -q -l $(SYNDIR)/area.txt -p "read_verilog $(CONVERTED); \
	             hierarchy -top pmic_top; \
	             synth -top pmic_top -flatten; \
	             dfflibmap -liberty $(LIBERTY); \
	             abc -liberty $(LIBERTY); \
	             opt_clean; \
	             tee -o $(SYNDIR)/area_summary.txt stat -liberty $(LIBERTY)" > /dev/null 2>&1 \
	    || { tail -40 $(SYNDIR)/area.txt; exit 1; }
	@grep -E "Chip area|Number of cells|cells$$" $(SYNDIR)/area_summary.txt
	@$(PYTHON) $(SCRIPTS)/area_counts.py $(SYNDIR)/area_summary.txt syn_area
	@$(call ok,Silicluster v3 standard slot is 180 x 115 = 20700 um2)

syn_notel: $(CONVERTED)  ## generic synthesis of the SPI-less build
	@$(call say,synthesising pmic_top with TELEMETRY_EN=0)
	@$(YOSYS) -q -l $(SYNDIR)/stat_notel.txt -p "read_verilog $(CONVERTED); \
	             chparam -set TELEMETRY_EN 0 pmic_top; \
	             hierarchy -top pmic_top; \
	             synth -top pmic_top -flatten; \
	             tee -o $(SYNDIR)/stat_notel_summary.txt stat" > /dev/null 2>&1 \
	    || { tail -20 $(SYNDIR)/stat_notel.txt; exit 1; }
	@cat $(SYNDIR)/stat_notel_summary.txt

syn_area_notel: $(CONVERTED)  ## sky130-mapped area of the SPI-less build (needs LIBERTY)
	@test -f $(LIBERTY) || { $(call err,no liberty file at $(LIBERTY)); exit 1; }
	@$(call say,mapping pmic_top with TELEMETRY_EN=0 to sky130_fd_sc_hd)
	@$(YOSYS) -q -l $(SYNDIR)/area_notel.txt -p "read_verilog $(CONVERTED); \
	             chparam -set TELEMETRY_EN 0 pmic_top; \
	             hierarchy -top pmic_top; \
	             synth -top pmic_top -flatten; \
	             dfflibmap -liberty $(LIBERTY); \
	             abc -liberty $(LIBERTY); \
	             opt_clean; \
	             tee -o $(SYNDIR)/area_notel_summary.txt stat -liberty $(LIBERTY)" > /dev/null 2>&1 \
	    || { tail -40 $(SYNDIR)/area_notel.txt; exit 1; }
	@$(PYTHON) $(SCRIPTS)/area_counts.py $(SYNDIR)/area_notel_summary.txt syn_area_notel

syn_both: syn_area syn_area_notel  ## sky130 area of both builds (needs LIBERTY)

# syn_compare: the local twin of the synth.yml PR comment. The base revision
#              is checked out into a temporary worktree under TBBUILD (never
#              the working copy), synthesised there with its own Makefile, and
#              ../.github/scripts/syn_stats.py prints the cell-count table.
BASE ?= origin/main
syn_compare: syn  ## cell counts here vs another revision (BASE=origin/main by default)
	@base_dir=$(TBBUILD)/syn_base; rm -rf $$base_dir; \
	$(call say,synthesising $(BASE) in $$base_dir); \
	git worktree add --detach -q $$base_dir $(BASE) || exit 1; \
	$(MAKE) -C $$base_dir/sim -B syn YOSYS='$(YOSYS)' SYNDIR=$$base_dir/syn > /dev/null 2>&1 \
	    || $(call warn,$(BASE) did not synthesise - showing this tree alone); \
	$(PYTHON) ../.github/scripts/syn_stats.py --head $(SYNDIR)/stat.txt --base $$base_dir/syn/stat.txt; rc=$$?; \
	git worktree remove --force $$base_dir; exit $$rc

syn_clean:  ## remove conversion and synthesis output
	rm -f $(CONVERTED) $(CONVERTED_NOTEL) $(SYNDIR)/stat.txt $(SYNDIR)/area.txt \
	      $(SYNDIR)/stat_summary.txt $(SYNDIR)/area_summary.txt \
	      $(SYNDIR)/stat_notel*.txt $(SYNDIR)/area_notel*.txt
