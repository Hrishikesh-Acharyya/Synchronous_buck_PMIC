#
# Filename:         submission.mk
#
# File Description: The two Silicluster v3 submission packages, kept in the
#                   repository as they are sent:
#                     submissions_full/     the whole supervisor, TELEMETRY_EN = 1
#                     submissions_trimmed/  the protection-only chip that fits
#                                           one standard slot, TELEMETRY_EN = 0
#                   Each holds rtl/ (Verilog-2005, one file per module),
#                   tb/pmic_top_tb.v and SILICLUSTER_README.md. Their rtl/ is
#                   rtl-verilog; the trimmed package differs from the full one
#                   in two lines - the TELEMETRY_EN default in rtl/pmic_top.v
#                   and in tb/pmic_top_tb.v.
#
#                     submissions        write both packages from rtl-verilog
#                                        and tb/pmic_top_tb.v (the READMEs are
#                                        left alone)
#                     submissions_check  prove both packages code-identical to
#                                        a fresh sv2v conversion of the source
#                                        (comments and `timescale apart), and
#                                        their testbenches identical to
#                                        tb/pmic_top_tb.v but for the default
#                     signoff            submissions_check, then each package
#                                        simulated from its own files only -
#                                        its rtl/ under its tb/ - in Verilator
#                                        and in Icarus Verilog; ends in
#                                        SIGNOFF OK or fails
#                     zip                one zip per package in Build/
#
# Global variables: SUB_FULL, SUB_TRIM, SUB_ZIP

##@ Silicluster v3 submission packages

# SUB_FULL / SUB_TRIM: the package folders
SUB_FULL := ../submissions_full
SUB_TRIM := ../submissions_trimmed
# SUB_ZIP: stem of the zip names in $(SYNDIR)
SUB_ZIP  := sync_buck_pmic_silicluster_v3

# tb_default: $(1) TELEMETRY_EN default - tb/pmic_top_tb.v with that default
tb_default = sed "s/^parameter \[0:0\] TELEMETRY_EN = 1'b1;/parameter [0:0] TELEMETRY_EN = 1'b$(1);/" $(TOP_TB)

# do_package: $(1) Verilog tree, $(2) package folder, $(3) TELEMETRY_EN default.
#             Only the package's own rtl and tb folders are replaced.
do_package = $(PYTHON) $(SCRIPTS)/replace_tree.py $(1) $(2)/rtl && mkdir -p $(2)/tb \
             && $(call tb_default,$(3)) > $(2)/tb/pmic_top_tb.v \
             && grep -q "^parameter \[0:0\] TELEMETRY_EN = 1'b$(3);" $(2)/tb/pmic_top_tb.v

.PHONY: submissions submissions_check signoff zip

submissions: verilog_check verilog_notel  ## write submissions_full/ and submissions_trimmed/ from rtl-verilog and the testbench
	@$(call do_package,$(V_DIR),$(SUB_FULL),1)
	@$(call do_package,$(V_DIR_NOTEL),$(SUB_TRIM),0)
	@$(call ok,$(SUB_FULL) and $(SUB_TRIM) written - run make signoff)

submissions_check: split split_notel  ## prove both packages code-identical to fresh sv2v output, testbenches in step
	@$(PYTHON) $(SCRIPTS)/strip_compare.py $(SPLITRAW)/$(SV_NAME) $(SUB_FULL)/rtl | tail -1
	@$(PYTHON) $(SCRIPTS)/strip_compare.py $(SPLITRAW_NOTEL)/$(SV_NAME) $(SUB_TRIM)/rtl | tail -1
	@$(PYTHON) $(SCRIPTS)/strip_compare.py $(SPLITRAW)/$(SV_NAME) $(SUB_FULL)/rtl > /dev/null
	@$(PYTHON) $(SCRIPTS)/strip_compare.py $(SPLITRAW_NOTEL)/$(SV_NAME) $(SUB_TRIM)/rtl > /dev/null
	@$(call tb_default,1) | cmp -s - $(SUB_FULL)/tb/pmic_top_tb.v \
	    || { $(call err,$(SUB_FULL)/tb/pmic_top_tb.v is not tb/pmic_top_tb.v - run make submissions); exit 1; }
	@$(call tb_default,0) | cmp -s - $(SUB_TRIM)/tb/pmic_top_tb.v \
	    || { $(call err,$(SUB_TRIM)/tb/pmic_top_tb.v is not tb/pmic_top_tb.v with TELEMETRY_EN = 0 - run make submissions); exit 1; }
	@n=$$(diff -r $(SUB_FULL)/rtl $(SUB_TRIM)/rtl | grep -c '^[<>]'); test "$$n" = 2 \
	    || { $(call err,the two packages differ in $$n rtl lines - expected the one TELEMETRY_EN default); exit 1; }
	@$(call drop_split,$(SPLITRAW)); $(call drop_split,$(SPLITRAW_NOTEL))
	@$(call ok,both packages are the source converted - nothing added and nothing lost)

# Each package is simulated from its own files only: SPLIT=1 points the
# converted-Verilog flows at the package's rtl/, and TOP_TB at its testbench.
signoff: submissions_check  ## ship check: each package simulated from its own files, Verilator and Icarus
	@$(call say,full package - Verilator and Icarus Verilog)
	@$(MAKE) --no-print-directory equiv_top iv_top SPLIT=1 V_DIR=$(SUB_FULL)/rtl \
	    TOP_TB=$(SUB_FULL)/tb/pmic_top_tb.v TBBUILD=$(TBBUILD)/signoff_full QUIET=1 NOFAIL=1
	@$(call say,trimmed package - Verilator and Icarus Verilog)
	@$(MAKE) --no-print-directory equiv_top_notel iv_top_notel SPLIT=1 V_DIR=$(SUB_TRIM)/rtl \
	    TOP_TB=$(SUB_TRIM)/tb/pmic_top_tb.v TBBUILD=$(TBBUILD)/signoff_trimmed QUIET=1 NOFAIL=1
	@rc=0; \
	 for d in $(TBBUILD)/signoff_full $(TBBUILD)/signoff_trimmed; do \
	   for f in $$(ls $$d); do bash $(SCRIPTS)/report.sh $$d $$f pmic_top_tb || rc=1; done; \
	 done; \
	 if [ $$rc = 0 ]; then $(call ok,SIGNOFF OK - both packages pass from their own files in both simulators); \
	 else $(call err,SIGNOFF FAILED); exit 1; fi

zip: submissions_check  ## one Silicluster zip per package (Build/sync_buck_pmic_silicluster_v3_full.zip, _trimmed.zip)
	@$(PYTHON) $(SCRIPTS)/zip_package.py $(SUB_FULL) $(SYNDIR)/$(SUB_ZIP)_full.zip $(SUB_ZIP)_full
	@$(PYTHON) $(SCRIPTS)/zip_package.py $(SUB_TRIM) $(SYNDIR)/$(SUB_ZIP)_trimmed.zip $(SUB_ZIP)_trimmed
	@$(call ok,$(SYNDIR)/$(SUB_ZIP)_full.zip and $(SYNDIR)/$(SUB_ZIP)_trimmed.zip)
