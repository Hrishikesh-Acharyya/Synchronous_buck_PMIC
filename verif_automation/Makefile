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
# Global variables: PYTHON, SV_LINT, CONTRACT, MUTATION, EVIDENCE, RULES, FILES,
#                   MODULE, OPERATORS, SAMPLE, SEED, JOBS - see below

# PYTHON: the interpreter for the tools (standard library only)
PYTHON   ?= python3
# SV_LINT: the house-style linter
SV_LINT  := tools/lint/sv_lint.py
# CONTRACT: the contract extractor
CONTRACT := tools/contract/extract_contract.py
# MUTATION: the mutation runner
MUTATION := tools/mutation/run_mutation.py
# EVIDENCE: where dated results are saved
EVIDENCE := evidence
# RULES / FILES: optional - a comma-separated rule subset, and files or
#                folders to lint, written from the repository root
RULES    ?=
FILES    ?=
# MODULE / OPERATORS / SAMPLE / SEED / JOBS: optional mutation selectors -
#            comma-separated modules and operators (tools/mutation/OPERATORS.md),
#            a random sample size and its seed, and parallel jobs (default: cores)
MODULE    ?=
OPERATORS ?=
SAMPLE    ?=
SEED      ?= 1
JOBS      ?=
# IDS / SIM_ARGS: optional - particular mutants by id (to re-run survivors),
#                 and extra make variables for the sim/ target, such as
#                 SIM_ARGS="HOSTIF_EVENTS=4000" for a longer random walk
IDS       ?=
SIM_ARGS  ?=
# TRIAGE / AUDIT: optional - the AI triage's output (make triage writes
#                 build/mutation/triage.json), and how many of the mutants it
#                 judged equivalent are simulated anyway: all (default), a
#                 number, or 0
TRIAGE    ?=
AUDIT     ?= all
# CHUNK / MODEL / RESUME / DRY: optional triage settings - mutants per request
#                 (default 40), a model name passed to the agent, a stopped
#                 run's folder to continue, and DRY=1 to write the prompts
#                 and call nothing
CHUNK     ?=
MODEL     ?=
RESUME    ?=
DRY       ?=

# MUTATION_ARGS: the selectors as runner options
MUTATION_ARGS = $(if $(MODULE),--modules $(MODULE)) $(if $(OPERATORS),--operators $(OPERATORS)) \
                $(if $(SAMPLE),--sample $(SAMPLE)) --seed $(SEED) $(if $(JOBS),--jobs $(JOBS)) \
                $(if $(IDS),--ids $(IDS)) $(if $(SIM_ARGS),--sim-args "$(SIM_ARGS)") \
                $(if $(TRIAGE),--triage $(TRIAGE) --audit $(AUDIT))

# TRIAGE_ARGS: the triage settings as script options
TRIAGE_ARGS = $(if $(MODULE),--modules $(MODULE)) $(if $(CHUNK),--chunk $(CHUNK)) $(if $(MODEL),--model $(MODEL)) \
              $(if $(RESUME),--resume $(RESUME)) $(if $(DRY),--dry-run) $(if $(JOBS),--jobs $(JOBS))

.DEFAULT_GOAL := help
.PHONY: help lint lint_report lint_evidence contract mutants mutants_check triage triage_evidence mutate mutation_evidence check_scripts

help:  ## list the commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-z_]+:.*## / {printf "  %-19s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

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

# contract: each module's header, parameters and ports - never its body - as
#           build/contract/<unit>.json and .md, with index.md and the gaps
contract:  ## extract every module's contract to build/contract/
	@$(PYTHON) $(CONTRACT)

# mutants: the mutation sites, listed without running anything
mutants:  ## list the mutants (MODULE=, OPERATORS=, SAMPLE=, SEED=)
	@$(PYTHON) $(MUTATION) --list $(MUTATION_ARGS)

# mutants_check: every mutant screened with make lint, none simulated - how
#                many are legal code, how many lint already catches. About a
#                minute for all of them; stillborn should read 0.
mutants_check:  ## health check of the mutant generator: lint-screen every mutant, no simulation
	@$(PYTHON) $(MUTATION) --check $(MUTATION_ARGS)

# triage: the AI step, before any simulation. Claude Code, run on this
#         machine read-only, judges each mutant that passes lint: can the edit
#         change the module's behaviour (plausible) or not (equivalent)? Writes
#         build/mutation/triage.json; nothing is taken on trust - see AUDIT.
#         Uses your Claude Code login; DRY=1 shows what would be sent.
triage:  ## AI triage of the mutants, read-only (MODULE=, CHUNK=, MODEL=, RESUME=, DRY=1)
	@$(PYTHON) ai/scripts/triage_mutants.py $(TRIAGE_ARGS)

triage_evidence:  ## the same, the run record saved to evidence/ai_runs/ and the ledger
	@$(PYTHON) ai/scripts/triage_mutants.py --evidence $(TRIAGE_ARGS)

# mutate: mutation testing - each mutant in a scratch copy of the RTL against
#         its module's own testbench. All 17 modules take hours: run it on
#         your machine. The report lands in build/mutation/<run>/.
mutate:  ## run mutation testing (MODULE=, OPERATORS=, SAMPLE=, SEED=, JOBS=, IDS=, SIM_ARGS=, TRIAGE=, AUDIT=) - hours for all
	@$(PYTHON) $(MUTATION) $(MUTATION_ARGS)

# mutation_evidence: the same, the report and results also saved as
#                    evidence/mutation/<date>_mutation.txt and .json
mutation_evidence:  ## run mutation testing and save the report to evidence/mutation/
	@$(PYTHON) $(MUTATION) --evidence $(MUTATION_ARGS)

check_scripts:  ## syntax-check every script in this folder
	@rc=0; \
	for f in $$(find tools ai -name '*.py' 2>/dev/null); do \
	  $(PYTHON) -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$$f" || rc=1; \
	done; \
	for f in $$(find tools ai -name '*.sh' 2>/dev/null); do bash -n "$$f" || rc=1; done; \
	if [ $$rc = 0 ]; then echo "scripts check clean"; else echo "script check failed"; exit 1; fi
