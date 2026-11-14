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
#                   MODULE, OPERATORS, SAMPLE, SEED, JOBS, IDS, SIM_ARGS,
#                   TRIAGE, AUDIT, CHUNK, MODEL, EFFORT, RESUME, DRY, COUNT,
#                   RECORD, AS, WHY - see below

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
# CHUNK / MODEL / RESUME / DRY: optional AI-step settings - mutants per request
#                 (default 40), a model name passed to the agent, a stopped
#                 run's folder to continue, and DRY=1 to write the prompts
#                 and call nothing. RESUME= also continues a stopped make
#                 mutate (its folder in build/mutation/)
# MODEL / EFFORT: the agent's model and reasoning effort for every AI step -
#                  a model alias (opus, sonnet, fable) and low, medium, high,
#                  xhigh or max. MODEL=sonnet is the cheaper choice for the
#                  small modules; empty values leave the agent on its own
#                  defaults
CHUNK     ?=
MODEL     ?= opus
EFFORT    ?= medium
# AGENT_ARGS: the model and effort as script options
AGENT_ARGS = $(if $(MODEL),--model $(MODEL)) $(if $(EFFORT),--effort $(EFFORT))
RESUME    ?=
DRY       ?=
# COUNT: optional - how many mutants make ai_mutants asks for per module
#        (default: 40 for reg_file, 30 for spi_slave, fewer for the rest)
COUNT     ?=
# RECORD: every finished make ai_mutants, make mutate and make judge is added
#         to the record of each module it touched (evidence/mutation/
#         <module>.json and .md). RECORD=0 leaves a run out - for a trial of
#         the tools, not of the design
RECORD    ?= 1
# AS / WHY: for make decide - the decision (equivalent, accepted or gap) and
#           its reason
AS        ?=
WHY       ?=
# NO_RECORD: the option that leaves a run out of the records
NO_RECORD = $(if $(filter 0,$(RECORD)),--no-record)

# MUTATION_ARGS: the selectors as runner options
MUTATION_ARGS = $(if $(MODULE),--modules $(MODULE)) $(if $(OPERATORS),--operators $(OPERATORS)) \
                $(if $(SAMPLE),--sample $(SAMPLE)) --seed $(SEED) $(if $(JOBS),--jobs $(JOBS)) \
                $(if $(IDS),--ids $(IDS)) $(if $(SIM_ARGS),--sim-args "$(SIM_ARGS)") \
                $(if $(TRIAGE),--triage $(TRIAGE) --audit $(AUDIT)) $(if $(RESUME),--resume $(RESUME)) $(NO_RECORD)

# TRIAGE_ARGS: the triage settings as script options
TRIAGE_ARGS = $(if $(MODULE),--modules $(MODULE)) $(if $(CHUNK),--chunk $(CHUNK)) $(AGENT_ARGS) \
              $(if $(RESUME),--resume $(RESUME)) $(if $(DRY),--dry-run) $(if $(JOBS),--jobs $(JOBS)) $(NO_RECORD)

.DEFAULT_GOAL := help
# WRITE_ARGS: the ai_mutants settings as script options
WRITE_ARGS = $(if $(MODULE),--modules $(MODULE)) $(if $(COUNT),--count $(COUNT)) $(AGENT_ARGS) \
             $(if $(DRY),--dry-run) $(if $(JOBS),--jobs $(JOBS)) $(NO_RECORD)

.PHONY: help lint lint_report lint_evidence contract mutants mutants_check ai_check ai_mutants triage judge \
        mutate decide status setup_check check_scripts

help:  ## list the commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-z_]+:.*## / {printf "  %-21s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

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

# mutants: the mutation sites, listed without running anything - the
#          mechanical mutants and the AI-written ones (OPERATORS=AIM for those)
mutants:  ## list the mutants (MODULE=, OPERATORS=, SAMPLE=, SEED=)
	@$(PYTHON) $(MUTATION) --list $(MUTATION_ARGS)

# mutants_check: every mutant screened with make lint, none simulated - how
#                many are legal code, how many lint already catches. A few
#                minutes for all of them; stillborn should read 0.
mutants_check:  ## health check of the mutant generator: lint-screen every mutant, no simulation
	@$(PYTHON) $(MUTATION) --check $(MUTATION_ARGS)

# ai_mutants: the AI step that writes mutants. Claude Code, run on this machine
#             read-only, reads one module at a time and proposes faults that
#             need the design's meaning - the ones no mechanical operator can
#             make. Each proposal passes a deterministic gate (the lines exist,
#             the edit is small and real, not a mutant already made, legal
#             code that lint accepts) before it is stored in ai/mutants/, from
#             where make mutate runs it beside the mechanical ones as operator
#             AIM. Run it again to add more. Simulates nothing.
ai_mutants:  ## AI-written, design-aware mutants, gated and stored in ai/mutants/ (MODULE=, COUNT=, MODEL=, EFFORT=, DRY=1)
	@$(PYTHON) ai/scripts/write_mutants.py $(WRITE_ARGS)

# ai_check: is the agent ready? One small request with the same command, tools
#           and permission settings as the real tasks: checks the login, that
#           the answer comes back as structured data, that the RTL can be read
#           and that the testbenches cannot. Costs a few thousand tokens.
ai_check:  ## check that Claude Code is installed, logged in and held to read-only by the settings (MODEL=, EFFORT=)
	@$(PYTHON) ai/scripts/check_agent.py $(AGENT_ARGS)

# triage: the AI step, before any simulation. Claude Code, run on this
#         machine read-only, judges each mutant that passes lint: can the edit
#         change the module's behaviour (plausible) or not (equivalent)? Writes
#         build/mutation/triage.json; nothing is taken on trust - see AUDIT.
#         Uses your Claude Code login; DRY=1 shows what would be sent.
triage:  ## AI triage of the mutants before the tests, read-only (MODULE=, CHUNK=, MODEL=, RESUME=, DRY=1)
	@$(PYTHON) ai/scripts/triage_mutants.py $(TRIAGE_ARGS)

# judge: the AI step after the tests (the recommended order). The survivors
#        in the module records that the designer has not decided are judged:
#        a real gap, or an edit that changes nothing. Each judgement is added
#        to its mutant in the record, beside any earlier one.
judge:  ## AI judgement of the surviving mutants in the records, read-only (MODULE=, MODEL=, EFFORT=, RESUME=, DRY=1)
	@$(PYTHON) ai/scripts/triage_mutants.py --judge $(TRIAGE_ARGS)

# decide: the designer's decision on survivors, added to the record with its
#         reason: equivalent (changes nothing that can be observed), accepted
#         (a real difference left open on purpose), or gap (real, still to be
#         closed by a property or test).
decide:  ## record your decision on survivors: IDS=<id>,<id> AS=equivalent|accepted|gap WHY="the reason"
	@$(PYTHON) tools/mutation/record.py decide --ids "$(IDS)" $(if $(AS),--as $(AS)) --why "$(WHY)"

# status: each module's record in a few lines - the score, and the survivors
#         still to be decided or closed
status:  ## the present state of each module's mutation record (MODULE=)
	@$(PYTHON) tools/mutation/record.py show $(if $(MODULE),--modules $(MODULE))

# setup_check: is everything these commands need installed? Reads only.
setup_check:  ## check that the tools these commands need are installed
	@$(PYTHON) tools/setup_check.py

# mutate: mutation testing - each mutant in a scratch copy of the RTL against
#         its module's own testbench. All 17 modules take hours: run it on
#         your machine, a module at a time if you like. The report lands in
#         build/mutation/<run>/, and each mutant's outcome is added to its
#         module's record in evidence/mutation/.
mutate:  ## run mutation testing (MODULE=, OPERATORS=, SAMPLE=, SEED=, JOBS=, IDS=, SIM_ARGS=, RESUME=) - hours for all
	@$(PYTHON) $(MUTATION) $(MUTATION_ARGS)

check_scripts:  ## syntax-check every script in this folder
	@rc=0; \
	for f in $$(find tools ai -name '*.py' 2>/dev/null); do \
	  $(PYTHON) -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$$f" || rc=1; \
	done; \
	for f in $$(find tools ai -name '*.sh' 2>/dev/null); do bash -n "$$f" || rc=1; done; \
	if [ $$rc = 0 ]; then echo "scripts check clean"; else echo "script check failed"; exit 1; fi
