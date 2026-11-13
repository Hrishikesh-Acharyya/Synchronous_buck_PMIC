#
# Filename:         Makefile
#
# File Description: Commands for verif_automation/: the deterministic tools in
#                   tools/ and, later, the AI-assisted runs in ai/. Kept apart
#                   from sim/Makefile, which runs the verification suites;
#                   nothing here is part of CI.
#
#                   Run from this folder:  make help
#
# Global variables: PYTHON, SV_LINT, EVIDENCE, RULES, FILES - see below

# PYTHON: the interpreter for the tools (standard library only)
PYTHON   ?= python3
# SV_LINT: the house-style linter
SV_LINT  := tools/lint/sv_lint.py
# EVIDENCE: where dated results are saved
EVIDENCE := evidence
# RULES / FILES: optional - a comma-separated rule subset, and files or
#                folders to lint, written from the repository root
RULES    ?=
FILES    ?=

.DEFAULT_GOAL := help
.PHONY: help lint lint_report lint_evidence check_scripts

help:  ## list the commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-z_]+:.*## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# lint: every rule in tools/lint/RULES.md over the RTL, checkers and
#       testbenches; fails on any error. RULES=C1,S2 for a subset, FILES=sva
#       for part of the tree.
lint:  ## lint RTL, checkers and testbenches; fails on any error (RULES=, FILES=)
	@$(PYTHON) $(SV_LINT) $(if $(RULES),--rules $(RULES)) $(FILES)

lint_report:  ## the same report, always exit 0
	@$(PYTHON) $(SV_LINT) --report-only $(if $(RULES),--rules $(RULES)) $(FILES)

# lint_evidence: the full report saved as evidence/lint/<date>_lint.txt; the
#                report's first line names the commit it was run on
lint_evidence:  ## save the full report to evidence/lint/<date>_lint.txt
	@mkdir -p $(EVIDENCE)/lint
	@out=$(EVIDENCE)/lint/$$(date +%F)_lint.txt; \
	$(PYTHON) $(SV_LINT) --report-only > $$out && echo "lint report saved to $$out"

check_scripts:  ## syntax-check every script in this folder
	@rc=0; \
	for f in $$(find tools ai -name '*.py' 2>/dev/null); do \
	  $(PYTHON) -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$$f" || rc=1; \
	done; \
	for f in $$(find tools ai -name '*.sh' 2>/dev/null); do bash -n "$$f" || rc=1; done; \
	if [ $$rc = 0 ]; then echo "scripts check clean"; else echo "script check failed"; exit 1; fi
