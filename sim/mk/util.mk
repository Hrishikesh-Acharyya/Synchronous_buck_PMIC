#
# Filename:         util.mk
#
# File Description: Everyday helpers: a toolchain check, a local replay of
#                   what CI runs, a testbench scaffold, cleaning, and the
#                   grouped help screen built from the `##@` and `##` notes in
#                   every mk file.
#
# Global variables: M - module for new_tb / new_sva, as <group>/<module>

##@ Helpers

.PHONY: all doctor ci ci_notel new_tb new_sva clean help

all: lint  ## default goal: lint

doctor:  ## check which tools are installed, their versions, and the paths in use
	@VERILATOR='$(VERILATOR)' VERILATOR_COVERAGE='$(VERILATOR_COVERAGE)' SV2V='$(SV2V)' \
	 YOSYS='$(YOSYS)' IVERILOG='$(IVERILOG)' VVP='$(VVP)' VIEWER='$(VIEWER)' \
	 PYTHON='$(PYTHON)' SHELLCHECK='$(SHELLCHECK)' LIBERTY='$(LIBERTY)' \
	 TBBUILD='$(TBBUILD)' SYNDIR='$(SYNDIR)' WAVEDIR='$(WAVEDIR)' \
	 bash $(SCRIPTS)/doctor.sh

# ci: the same steps, in the same order, as .github/workflows/rtl.yml, so a
#     push is not the first time they run. Each step is a separate make so the
#     first failure stops the rest and is easy to spot.
ci:  ## run locally what CI runs: lint, script check, rtl-verilog sync, full regression
	@$(call say,1/5 lint - both builds) && $(MAKE) lint_all
	@$(call say,2/5 script check) && $(MAKE) check_scripts
	@$(call say,3/5 convert) && $(MAKE) -B convert
	@$(call say,4/5 rtl-verilog in step with the source) && $(MAKE) verilog_check
	@$(call say,5/5 every testbench - source and converted) && $(MAKE) equiv_all STRICT=1
	@$(call ok,all CI steps passed)

ci_notel:  ## the CI job for the SPI-less build: lint and the integration testbench, both flows
	@$(call say,1/2 lint TELEMETRY_EN=0) && $(MAKE) lint_notel
	@$(call say,2/2 integration testbench TELEMETRY_EN=0) && $(MAKE) tb_top_notel equiv_top_notel QUIET=1 NOFAIL=1
	@rc=0; for f in sv_notel equiv_notel; do bash $(SCRIPTS)/report.sh $(TBBUILD) $$f pmic_top_tb || rc=1; done; exit $$rc

# new_tb: copies tb/template_tb.sv to tb/<group>/<module>_tb.sv with the module
#         name filled in. Registering it is one line in the Makefile's
#         TESTBENCHES list, which the script prints rather than editing.
new_tb:  ## scaffold tb/<group>/<module>_tb.sv from the template: make new_tb M=status/foo
	@test -n "$(M)" || { $(call err,usage: make new_tb M=group/module); exit 1; }
	@bash $(SCRIPTS)/new_tb.sh "$(M)"

# clean also sweeps the staging trees of the old Silicluster flow
# (Build/package_raw, Build/package_raw_trimmed), left behind by `make package`.
# new_sva: copies sva/template_sva.sv to sva/<group>/<module>_sva.sv with the
#          DUT's parameters and ports filled in from its RTL header, and prints
#          the bind line for sva/bind_sva.sv rather than editing that file.
new_sva:  ## scaffold sva/<group>/<module>_sva.sv from the RTL header: make new_sva M=protect/soft_start
	@test -n "$(M)" || { $(call err,usage: make new_sva M=group/module); exit 1; }
	@$(PYTHON) $(SCRIPTS)/new_sva.py "$(M)"

clean: tb_clean syn_clean  ## remove testbench output, synthesis output and every generated tree
	rm -rf $(SPLITRAW) $(SPLITRAW_NOTEL) $(V_DIR_NOTEL) $(SYNDIR)/*.zip \
	       $(SYNDIR)/package_raw $(SYNDIR)/package_raw_trimmed

# help: every target with a `## description` on its rule line, grouped under
#       the `##@ heading` before it, in the order the mk files are included.
help:  ## this screen
	@awk -v c_hd='$(C_BLD)$(C_CYN)' -v c_tg='$(C_GRN)' -v c_off='$(C_OFF)' \
	    -f $(SCRIPTS)/help.awk $(MAKEFILE_LIST)
	@printf '\n%bModes%b  QUIET=1  STRICT=1 (zero-hit cover fails)  NOFAIL=1  WAVES=1  SPLIT=1 (equiv on rtl-verilog)\n' '$(C_BLD)' '$(C_OFF)'
	@printf '%bColour%b on in a terminal; COLOR=0 or NO_COLOR=1 turns it off\n' '$(C_BLD)' '$(C_OFF)'
	@printf '%bAll commands, with examples:%b ../COMMANDS.md\n' '$(C_BLD)' '$(C_OFF)'
