# verif_automation/tools

Deterministic verification tools. No AI is involved here: each tool is a
script with fixed rules, run from `make` or CI, and gives the same answer on
the same input every time. Their reports go to `verif_automation/evidence/`.

The handwritten verification (testbenches in `tb/`, bound checkers in
`sva/`) stays where it is. These tools check that work, or produce inputs for
it. They never replace it.

## Layout

| Folder | Tool | Status |
|---|---|---|
| `lint/` | `sv_lint.py`: house-style linter for the RTL, checkers and testbenches. Rules are in `lint/RULES.md`, accepted exceptions in `lint/exemptions.txt` | in use |
| `common/` | `svparse.py`: the SystemVerilog reader the other tools share - tokens, headers, parameters and ports with their comments, a statement tree of every procedural block, and every module instance with its connections | in use |
| `contract/` | `extract_contract.py`: each module's contract - header, parameters, ports, never its body - as JSON and Markdown in `build/contract/`, with the gaps (anything undescribed) | in use |
| `mutation/` | `mutants.py` finds the mutation sites (operators in `mutation/OPERATORS.md`); `run_mutation.py` makes each mutant in a scratch copy of the RTL (never the real files), runs the module's own testbench and checker on it, and reports what survived | in use |
| `traceability/` | traceability matrix: contract clause, then the property or cover that checks it, then the test that exercises it | planned |
| `trace_mining/` | trace mining: reads the waveforms of passing runs and lists candidate invariants for a person to judge | planned |

Each tool gets its own folder with its script(s), a `RULES.md` or `README.md`
saying what it checks and what it does not, and any configuration it needs.

## Commands

From `verif_automation/`, which has its own Makefile, separate from
`sim/Makefile` (that one runs the verification suites):

| Command | What it does |
|---|---|
| `make help` | list the commands |
| `make lint` | lint; fails on any error. `RULES=H1,C1` runs a subset; `FILES=` names files or folders from the repository root |
| `make lint_report` | the same report, always exit 0 (for reading the backlog) |
| `make lint_evidence` | save the full report as `evidence/lint/<date>_lint.txt` |
| `make contract` | extract every module's contract to `build/contract/` |
| `make mutants` | list the mutants without running them (`MODULE=`, `OPERATORS=`, `SAMPLE=`, `SEED=`) |
| `make mutants_check` | health check of the mutant generator: every mutant lint-screened, none simulated |
| `make mutate` | mutation testing; all modules take hours (`MODULE=`, `OPERATORS=`, `SAMPLE=`, `SEED=`, `JOBS=`) |
| `make mutation_evidence` | the same, with the report saved to `evidence/mutation/<date>_mutation.txt` and `.json` |
| `make check_scripts` | syntax check of every script under `tools/` and `ai/` |

Generated output (contracts, mutation runs) goes to `verif_automation/build/`,
which is not committed; anything kept as a record is copied into `evidence/`.

## Language

Python, standard library only, so they run on any machine that runs the
cocotb suites. A tool that needs a real SystemVerilog parser (pyslang) will
say so in its README; that package is installed on the machine that runs the
tool, not vendored here.
