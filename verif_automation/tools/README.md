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
| `lint/` | `sv_lint.py`: house-style and rulebook linter for the RTL, checkers and testbenches. Rules are in `lint/RULES.md`, accepted exceptions in `lint/exemptions.txt` | in use |
| `contract/` | contract extractor: turns each module's header contract and the RTL ports into a machine-readable list of the behaviours a checker must cover | planned |
| `mutation/` | mutation runner: makes small, known edits to a scratch copy of the RTL (never the real files), reruns the module's testbench and checker, and reports which mutants survived | planned |
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
| `make check_scripts` | syntax check of every script under `tools/` and `ai/` |

## Language

Python, standard library only, so they run on any machine that runs the
cocotb suites. A tool that needs a real SystemVerilog parser (pyslang) will
say so in its README; that package is installed on the machine that runs the
tool, not vendored here.
