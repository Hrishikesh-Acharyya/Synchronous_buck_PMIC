#
# Filename:         lint.mk
#
# File Description: Verilator lint of the RTL in both TELEMETRY_EN builds, and a
#                   static check of the repository's own shell and Python
#                   scripts. The house-style linter has its own Makefile in
#                   verif_automation/.
#
# Global variables: none

##@ Lint

.PHONY: lint lint_notel lint_all check_scripts

# if/else rather than `command -v ... && ... || echo`: in that form a lint
# failure falls through to the fallback and make exits 0.
lint:  ## strict Verilator lint over the RTL (what CI runs)
	@if command -v $(VERILATOR) >/dev/null 2>&1; then \
	  for top in $(LINT_TOPS); do \
	    $(call say,linting $$top); \
	    $(VERILATOR) --lint-only -Wall $(LINT_WAIVERS) $(RTL) \
	      --top-module $$top || exit 1; \
	  done; \
	  $(call ok,lint passed); \
	else \
	  $(call warn,verilator not installed - skipping lint); \
	fi

# lint_notel: the TELEMETRY_EN=0 (SPI-less) configuration. UNUSEDSIGNAL is
#             waived for it alone: with the host interface compiled out, the
#             SCK and CS_n pins and the nets that fed the telemetry blocks are
#             legitimately unread. Any other warning still fails.
lint_notel:  ## lint the SPI-less build (TELEMETRY_EN=0; UNUSEDSIGNAL waived)
	@$(call say,linting pmic_top with TELEMETRY_EN=0)
	@$(VERILATOR) --lint-only -Wall $(LINT_WAIVERS) -Wno-UNUSEDSIGNAL $(RTL) \
	    --top-module pmic_top -GTELEMETRY_EN=0
	@$(call ok,lint passed (TELEMETRY_EN=0))

lint_all: lint lint_notel  ## both builds

# check_scripts: bash -n and shellcheck on every shell script, a compile of
#                every Python script. shellcheck is optional locally (it is
#                preinstalled on the GitHub runners); without it the syntax
#                check still runs.
check_scripts:  ## syntax-check the repo's shell and Python scripts (+ shellcheck if installed)
	@rc=0; \
	for f in $(SCRIPTS)/*.sh; do bash -n "$$f" || rc=1; done; \
	if command -v $(SHELLCHECK) >/dev/null 2>&1; then \
	  $(SHELLCHECK) -S warning $(SCRIPTS)/*.sh || rc=1; \
	else \
	  $(call warn,shellcheck not installed - bash -n only); \
	fi; \
	for f in $(SCRIPTS)/*.py ../.github/scripts/*.py; do \
	  $(PYTHON) -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$$f" || rc=1; \
	done; \
	if [ $$rc = 0 ]; then $(call ok,scripts check clean); else $(call err,script check failed); exit 1; fi
