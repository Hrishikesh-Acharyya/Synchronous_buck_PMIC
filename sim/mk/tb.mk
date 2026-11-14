#
# Filename:         tb.mk
#
# File Description: The module testbenches and the suite targets. Every
#                   per-module target is generated from TESTBENCHES (set in
#                   the Makefile) - adding a module is one line there. The
#                   build-run-gate logic lives in scripts/run_tb.sh and the
#                   suite table in scripts/report.sh.
#
# Global variables: run_tb, open_wave, TB_RULES - used by top.mk as well

##@ Module testbenches (one family per entry in TESTBENCHES - see `make list`)
##- tb_<m>      build + run against the SV source, e.g. make tb_pwm_mask
##- equiv_<m>   the same testbench and checkers against the sv2v output
##- wave_<m>    tb_<m> with a VCD, then open GTKWave
##- view_<m>    open the last VCD without re-running
##- cov_<m>     re-list the last run's covers, conditions in full

# run_tb: $(1) top, $(2) flow, $(3) sources, $(4) Verilator flags.
#         `bash script` rather than executing it, so a lost exec bit on the
#         Windows mount cannot break the build.
run_tb = VERILATOR='$(VERILATOR)' VERILATOR_COVERAGE='$(VERILATOR_COVERAGE)' \
         VFLAGS='$(4)' QUIET='$(QUIET)' WAVES='$(WAVES)' \
         NOFAIL='$(NOFAIL)' STRICT='$(STRICT)' \
         bash $(SCRIPTS)/run_tb.sh $(1) $(TBBUILD)/$(2)/$(1) $(2) $(3)

# open_wave: $(1) top. Loads $(WAVEDIR)/<top>.gtkw if it exists, so signal
#            selection and zoom survive between runs. Backgrounded; stderr
#            dropped because WSLg emits a dconf warning on every launch.
open_wave = vcd=$(TBBUILD)/sv/$(1)/$(1).vcd; \
            test -f $$vcd || { $(call err,no VCD yet for $(1) - run its wave_ target first); exit 1; }; \
            $(VIEWER) $$vcd $(if $(wildcard $(WAVEDIR)/$(1).gtkw),-a $(WAVEDIR)/$(1).gtkw) \
                2>/dev/null &

# TB_RULES: $(1) <subfolder>/<module>, $(2) <module>. Each target carries its
#           own recipe rather than depending on a shared phony one - a phony
#           prerequisite is built once per make run, which is why the old
#           tb_all had to recurse.
#   tb_<m>     build + run against the SV source
#   equiv_<m>  same testbench + checkers against the sv2v output
#   wave_<m>   tb_<m> with a VCD, then open GTKWave
#   view_<m>   open the last VCD without re-running
#   cov_<m>    re-list the last run's covers, conditions in full
define TB_RULES
.PHONY: tb_$(2) equiv_$(2) wave_$(2) view_$(2) cov_$(2)

tb_$(2):
	@$$(call run_tb,$(2)_tb,sv,$$(RTL) $$(SVA_SRCS) ../tb/$(1)_tb.sv,$$(VFLAGS))

equiv_$(2): $$(EQUIV_SRCS)
	@$$(call run_tb,$(2)_tb,$$(EQUIV_FLOW),$$(PKG) $$(EQUIV_SRCS) $$(SVA_SRCS) ../tb/$(1)_tb.sv,$$(VFLAGS) $$(EQUIV_WAIVERS))

wave_$(2): WAVES := 1
wave_$(2): tb_$(2)
	@$$(call open_wave,$(2)_tb)

view_$(2):
	@$$(call open_wave,$(2)_tb)

cov_$(2):
	@test -s $$(TBBUILD)/sv/$(2)_tb/covers.tsv \
	    && bash $$(SCRIPTS)/covers.sh table $$(TBBUILD)/sv/$(2)_tb full \
	    || { $$(call warn,no cover listing for $(2)_tb - run tb_$(2) first); }
endef

$(foreach t,$(TESTBENCHES),$(eval $(call TB_RULES,$(t),$(notdir $(t)))))

##@ Suites

.PHONY: tb_all equiv equiv_all report list tb_clean

tb_all: QUIET  := 1
tb_all: NOFAIL := 1
tb_all: $(addprefix tb_,$(TB_MODULES)) tb_top  ## every testbench on the SV source (use -j), then the table
	@bash $(SCRIPTS)/report.sh $(TBBUILD) sv $(SUITE_TOPS)

equiv: QUIET  := 1
equiv: NOFAIL := 1
equiv: $(addprefix equiv_,$(TB_MODULES)) equiv_top  ## every testbench on the sv2v output (SPLIT=1: on rtl-verilog)
	@bash $(SCRIPTS)/report.sh $(TBBUILD) $(EQUIV_FLOW) $(SUITE_TOPS)

# equiv_all: both flows as one parallel job graph, then both tables. Report
#            failures are collected so every table always prints.
equiv_all: QUIET  := 1
equiv_all: NOFAIL := 1
equiv_all: $(addprefix tb_,$(TB_MODULES)) $(addprefix equiv_,$(TB_MODULES)) tb_top equiv_top  ## the gate: tb_all + equiv in one parallel run (what CI runs)
	@rc=0; \
	bash $(SCRIPTS)/report.sh $(TBBUILD) sv            $(SUITE_TOPS) || rc=1; \
	bash $(SCRIPTS)/report.sh $(TBBUILD) $(EQUIV_FLOW) $(SUITE_TOPS) || rc=1; \
	exit $$rc

report:  ## reprint the result tables from the last runs, without re-running
	@-bash $(SCRIPTS)/report.sh $(TBBUILD) sv    $(SUITE_TOPS)
	@-bash $(SCRIPTS)/report.sh $(TBBUILD) equiv $(SUITE_TOPS)

list:  ## list the registered testbenches and their files
	@$(foreach t,$(TESTBENCHES),printf '  %-18s ../tb/%s_tb.sv\n' $(notdir $(t)) $(t);)
	@printf '  %-18s %s\n' pmic_top $(TOP_TB)

tb_clean:  ## remove all testbench build output
	rm -rf $(TBBUILD)
