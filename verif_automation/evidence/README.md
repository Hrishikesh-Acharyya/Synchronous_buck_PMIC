# verif_automation/evidence

The results of `tools/` and `ai/`, kept as a dated record. Soak evidence for
the handwritten suites stays beside each suite (for example
`tb/top/pmic_top/soak/`).

So far: the lint reports and the RTL change requests. The agent runs and the
other tools are still being set up; their files appear when the first real
result does.

## Naming

Every saved result is named `<YYYY-MM-DD>_<what>.<ext>`, for example
`lint/2026-11-20_lint.txt`. The first line of each file gives the commit it
was run on. Times of day are not recorded; the date and commit are enough to
find the run. Two runs of the same thing on one day get a suffix:
`2026-11-20_lint_2.txt`.

## Layout

| Path | What it will hold |
|---|---|
| `lint/` | `sv_lint` reports (`make lint_evidence`), with a summary of each in `lint/README.md` |
| `mutation/` | mutation scores: each mutant, and which test or property killed it |
| `ai_runs/ledger.md` | one row per agent run (format below) |
| `ai_runs/findings.md` | everything an agent run found or got wrong (format below) |
| `ai_runs/<date>_<task>/` | the full record of one run: instructions sent, diff produced, gate output |
| `rtl_change_requests.md` | RTL changes proposed by a tool or by the agent, each waiting for the designer's decision (format below) |
| `traceability/` | the contract-to-property-to-test matrix |

## Formats

**`ai_runs/ledger.md`** has one row per run, in the order they ran:

| Run | Date | Commit | Task | Given | Produced | Gate | Verdict | Findings |
|---|---|---|---|---|---|---|---|---|

- **Run:** A1, A2, and so on.
- **Task:** the folder in `ai/tasks/`.
- **Given:** the inputs the agent was allowed to read.
- **Produced:** the files it wrote or changed.
- **Gate:** the checks run on its output, and their result.
- **Verdict:** accepted, partly accepted or rejected, and by whom.
- **Findings:** IDs in `findings.md`.

**`ai_runs/findings.md`** has one row per finding:

| ID | Run | Kind | What was found | Evidence | Outcome |
|---|---|---|---|---|---|

The kind is one of:

- **design bug:** the RTL is wrong. It is also raised in `rtl_change_requests.md`.
- **verification gap:** the handwritten suite missed something, such as a
  surviving mutant, an unchecked contract clause or an unreached bin.
- **agent error:** the agent's output was wrong: a property that fails on
  correct RTL, a wrong claim, or an attempt to write outside its allowed paths.
- **rejected:** output that was correct but not taken, with the reason.

**`rtl_change_requests.md`** has one row per request. A request is never
deleted; it is closed with its decision.

| ID | Date | Raised by | Files | Request | Why | Status |
|---|---|---|---|---|---|---|

The status is proposed, accepted, rejected, or done with the commit.
