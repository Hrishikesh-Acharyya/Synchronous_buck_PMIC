#
# Filename:         verilog.mk
#
# File Description: The Verilog-2005 split in rtl-verilog/ - one file per
#                   SystemVerilog module, same layout, with the comments sv2v
#                   discards carried over. Its code must always be exactly what
#                   sv2v produces from the current source.
#
#                     split          sv2v -w adjacent into a clean staging
#                                    tree. The package converts to two pragmas
#                                    and nothing else - its constants are
#                                    inlined into every consumer - so
#                                    pmic_types_pkg.v is dropped.
#                     verilog_check  rtl-verilog code-identical to that output
#                                    once comments and `timescale are stripped
#                                    (scripts/strip_compare.py).
#                     verilog        regenerate rtl-verilog from the source:
#                                    keep every comment, take every code token
#                                    from the fresh split
#                                    (scripts/transplant_comments.py). Refuses
#                                    a file if anything but a constant or a
#                                    path string changed - a new port or block
#                                    needs its comments written by hand - and
#                                    lists comments naming a clock frequency
#                                    for review. rtl-verilog is replaced only
#                                    if every file succeeds.
#
#                   Staging trees are scratch: verilog_check, verilog and
#                   verilog_notel delete theirs once they succeed, and keep it
#                   when they fail, because then it is what you diff against
#                   (KEEP_SPLIT=1 keeps it always). `make split` on its own
#                   keeps its output - producing it is the point.
#
#                   The SPI-less build (TELEMETRY_EN=0) is generated, never
#                   committed: verilog_notel writes Build/rtl-verilog-notel, the
#                   same files with the default flipped, and proves it against
#                   a split of the flipped source. bundle and bundle_notel zip a
#                   Verilog tree with the integration testbench, for a shuttle
#                   or a reviewer.
#
# Global variables: SPLITRAW, SPLITRAW_NOTEL, V_DIR_NOTEL, BUNDLE, KEEP_SPLIT

##@ Verilog split (rtl-verilog) and SPI-less variants

SPLITRAW       := $(SYNDIR)/split_raw
SPLITRAW_NOTEL := $(SYNDIR)/split_raw_notel
V_DIR_NOTEL    := $(SYNDIR)/rtl-verilog-notel
SV_NAME        := $(notdir $(SV_DIR))
BUNDLE         ?= sync_buck_pmic
KEEP_SPLIT     ?= 0

# drop_split: $(1) staging dir - removed after a success unless KEEP_SPLIT=1
drop_split = $(if $(filter 1,$(KEEP_SPLIT)),true,rm -rf $(1))

TEL_SV_ON  := parameter bit TELEMETRY_EN = 1'b1
TEL_SV_OFF := parameter bit TELEMETRY_EN = 1'b0

# do_split: $(1) staging dir, $(2) 1 to flip TELEMETRY_EN to 0 first.
#           One shell line, so a failing step stops the rest.
do_split = rm -rf $(1) && mkdir -p $(1) && cp -r $(SV_DIR) $(1)/ \
           $(if $(filter 1,$(2)),&& sed -i "s/$(TEL_SV_ON)/$(TEL_SV_OFF)/" $(1)/$(SV_NAME)/pmic_top.sv \
                                 && grep -qF "$(TEL_SV_OFF)" $(1)/$(SV_NAME)/pmic_top.sv) \
           && (cd $(1) && $(SV2V) -w adjacent $(patsubst ../%,%,$(RTL))) \
           && find $(1)/$(SV_NAME) -name '*.sv' -delete \
           && rm -f $(1)/$(SV_NAME)/pkg/pmic_types_pkg.v && rmdir $(1)/$(SV_NAME)/pkg

# do_bundle: $(1) Verilog tree, $(2) zip name, $(3) TELEMETRY_EN default
do_bundle = rm -rf $(SYNDIR)/$(2) $(SYNDIR)/$(2).zip && mkdir -p $(SYNDIR)/$(2)/tb \
            && cp -r $(1) $(SYNDIR)/$(2)/rtl \
            && sed "s/^parameter \[0:0\] TELEMETRY_EN = 1'b1;/parameter [0:0] TELEMETRY_EN = 1'b$(3);/" \
                   $(TOP_TB) > $(SYNDIR)/$(2)/tb/pmic_top_tb.v \
            && (cd $(SYNDIR) && $(PYTHON) -m zipfile -c $(2).zip $(2)) \
            && rm -rf $(SYNDIR)/$(2)

.PHONY: split verilog_check verilog split_notel verilog_notel bundle bundle_notel

split:  ## sv2v -w adjacent into a clean staging tree (Build/split_raw)
	@$(call do_split,$(SPLITRAW),0)
	@$(call ok,raw split: $$(find $(SPLITRAW)/$(SV_NAME) -name '*.v' | wc -l) files in $(SPLITRAW))

verilog_check: split  ## prove rtl-verilog code-identical to fresh sv2v output
	@$(PYTHON) $(SCRIPTS)/strip_compare.py $(SPLITRAW)/$(SV_NAME) $(V_DIR) \
	    || { $(call err,rtl-verilog is out of step with the source - run make verilog); \
	         $(call warn,fresh split kept in $(SPLITRAW) for diffing); exit 1; }
	@$(call drop_split,$(SPLITRAW))

verilog: split  ## regenerate rtl-verilog from the source, keeping its comments
	@rm -rf $(SPLITRAW)/new
	@$(PYTHON) $(SCRIPTS)/transplant_comments.py $(SPLITRAW)/$(SV_NAME) $(V_DIR) $(SPLITRAW)/new \
	    || { $(call err,refused - merge the files listed above by hand; rtl-verilog unchanged); exit 1; }
	@$(PYTHON) $(SCRIPTS)/strip_compare.py $(SPLITRAW)/$(SV_NAME) $(SPLITRAW)/new > /dev/null
	@rm -rf $(V_DIR) && mv $(SPLITRAW)/new $(V_DIR)
	@$(call drop_split,$(SPLITRAW))
	@$(call ok,$(V_DIR) regenerated - review any comments listed above)

split_notel:  ## split of the SPI-less source (Build/split_raw_notel)
	@$(call do_split,$(SPLITRAW_NOTEL),1)
	@$(call ok,SPI-less raw split in $(SPLITRAW_NOTEL))

verilog_notel: split_notel  ## commented SPI-less Verilog in Build/rtl-verilog-notel, proven against sv2v
	@rm -rf $(V_DIR_NOTEL) && cp -r $(V_DIR) $(V_DIR_NOTEL)
	@sed -i "s/parameter \[0:0\] TELEMETRY_EN = 1'b1;/parameter [0:0] TELEMETRY_EN = 1'b0;/" $(V_DIR_NOTEL)/pmic_top.v
	@grep -qF "parameter [0:0] TELEMETRY_EN = 1'b0;" $(V_DIR_NOTEL)/pmic_top.v
	@out=$$($(PYTHON) $(SCRIPTS)/strip_compare.py $(SPLITRAW_NOTEL)/$(SV_NAME) $(V_DIR_NOTEL)) \
	    || { echo "$$out"; $(call err,SPI-less tree does not match its sv2v split); exit 1; }; \
	 echo "$$out" | tail -1
	@$(call drop_split,$(SPLITRAW_NOTEL))
	@$(call ok,SPI-less Verilog in $(V_DIR_NOTEL))

bundle: verilog_check  ## zip rtl-verilog + tb/pmic_top_tb.v (Build/sync_buck_pmic.zip)
	@$(call do_bundle,$(V_DIR),$(BUNDLE),1)
	@$(call ok,$(SYNDIR)/$(BUNDLE).zip)

bundle_notel: verilog_notel  ## the same for the SPI-less build (Build/sync_buck_pmic_notel.zip)
	@$(call do_bundle,$(V_DIR_NOTEL),$(BUNDLE)_notel,0)
	@$(call ok,$(SYNDIR)/$(BUNDLE)_notel.zip)
