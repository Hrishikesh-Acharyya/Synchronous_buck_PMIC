# verif_ai

AI-assisted verification: an AI coding agent (a large language model run
from the command line) writes verification code and looks for gaps, and the
simulator decides whether its work holds. This folder holds what the agent is
asked to do and the scripts that run it. Everything it produces, accepted or
not, is recorded in `verif_evidence/ai_runs/`.

The agent runs on the designer's own machine, started by the scripts here.
Help with writing these scripts and tools is ordinary tooling work and is not
counted as an AI run; only runs of the agent through `verif_ai/` are.

## Ground rules

1. **The agent never edits RTL.** `rtl-systemverilog/` and `rtl-verilog/`
   are read-only to it, enforced by the run script's permission settings, not
   by asking. If it thinks the RTL is wrong, it writes a change request to
   `verif_evidence/rtl_change_requests.md`, and the designer decides.
2. **It writes only where its task allows.** Each task lists the paths it may
   write; every other path is denied.
3. **The simulator is the judge.** Nothing the agent writes is accepted on
   its own word. A new property must compile, pass on the real RTL and kill
   the mutants it was written for; a new test must pass and add coverage.
4. **Independence where it matters.** When the agent writes a checker or
   model, it is given the contract (module headers, `docs/`), not the RTL
   body, so it cannot copy the design's own mistakes.
5. **Everything is disclosed.** Every run is logged: what it was asked, what
   it was given, what it produced, what checks ran, what was accepted or
   rejected and why, and the agent's own mistakes. A rejected or wrong output
   is logged the same as an accepted one.

## How a run works

```
verif_ai/scripts/run_task.sh <task>
  1. records the date, commit and task in a new run folder
  2. runs the deterministic tool the task needs (mutation runner, contract
     extractor, coverage report) to produce the agent's input
  3. starts the agent non-interactively with the task's instructions and its
     allowed paths
  4. runs the acceptance gate (make targets named by the task)
  5. writes the run summary to verif_evidence/ai_runs/
```

The designer reviews the summary and the diff, then accepts or rejects. Only
accepted work is committed outside `verif_evidence/`.

## Layout

| Path | What it holds | Status |
|---|---|---|
| `tasks/<task>/TASK.md` | the instructions: goal, inputs given, paths it may write, acceptance gate | planned |
| `scripts/run_task.sh` | the runner described above | planned |
| `scripts/permissions.json` | the read/write allow and deny lists the runner passes to the agent | planned |

Planned tasks, in order:

| Task | The agent's job | Gate |
|---|---|---|
| `kill_mutants` | for each mutant that survived the handwritten suite, write the property or test that kills it, or argue it is equivalent | the mutant is killed and the real RTL still passes |
| `expand_checkers` | compare each module's checker against its extracted contract and add what is missing | new properties pass on the RTL and are covered |
| `shadow_model` | write an independent model of a module from its contract alone, for differential testing | differences are explained, and each one is a model error or a design bug |
| `close_coverage` | read the coverage holes and write tests or constraints to reach them | the bins are hit, and no existing test breaks |
| `mine_traces` | judge candidate invariants from `verif_tools/trace_mining` | accepted ones become properties that pass |
