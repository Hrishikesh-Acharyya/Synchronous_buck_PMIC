# verif_automation/evidence

The results of `verif_automation/tools/` and `verif_automation/ai/`, kept as a dated record. Soak
evidence for the handwritten suites stays beside each suite (for example
`tb/top/pmic_top/soak/`).

## Naming

Every saved result is named `<YYYY-MM-DD>_<what>.<ext>`, for example
`lint/2026-11-12_lint.txt`. The first line of each file gives the commit it
was run on. Times of day are not recorded; the date and commit are enough to
find the run.

Two runs of the same thing on one day get a suffix: `2026-11-12_lint_2.txt`.

## Layout

| Path | What it holds | Status |
|---|---|---|
| `lint/` | `sv_lint` reports (`make lint_sv_evidence`) and a summary of each in `lint/README.md` | in use |
| `rtl_change_requests.md` | RTL changes proposed by a tool or by the agent, each waiting for the designer's decision | in use |
| `mutation/` | mutation scores: each mutant, and which test or property killed it | planned |
| `ai_runs/ledger.md` | one row per agent run: date, commit, task, inputs, outputs, checks, verdict | template ready |
| `ai_runs/findings.md` | everything an agent run found or got wrong: bugs, checker gaps, its own mistakes, rejected outputs | template ready |
| `ai_runs/<date>_<task>/` | the full record of one run: instructions sent, diff produced, gate output | planned |
| `traceability/` | the contract-to-property-to-test matrix | planned |
