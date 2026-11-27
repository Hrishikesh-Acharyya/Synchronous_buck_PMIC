# Mutants written by the AI step - 2026-11-28 - commit 3b029b7

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 50; proposed: 13; accepted by the gate: 12; rejected: 1

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_pmic_top_1 | 20 | ok | 7 proposed, 6 accepted, 1 rejected |  |
| 001_pmic_top_2 | 20 | ok | 3 proposed, 3 accepted, 0 rejected |  |
| 001_pmic_top_3 | 10 | ok | 3 proposed, 3 accepted, 0 rejected |  |

## Rejected by the gate

- `pmic_top`: pgood_gen takes the raw asynchronous PGOOD_comp pin instead of its synchronised copy, brea - **make lint already catches it: make lint: UNUSEDSIGNAL**
