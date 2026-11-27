# Mutants written by the AI step - 2026-11-27 - commit 13c1372

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 50; proposed: 25; accepted by the gate: 24; rejected: 1

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_fault_arbiter_1 | 20 | ok | 13 proposed, 12 accepted, 1 rejected |  |
| 001_fault_arbiter_2 | 20 | ok | 8 proposed, 8 accepted, 0 rejected |  |
| 001_fault_arbiter_3 | 10 | ok | 4 proposed, 4 accepted, 0 rejected |  |

## Rejected by the gate

- `fault_arbiter`: The S_RUN threshold is truncated to the 5-bit run-count width instead of the count being w - **make lint already catches it: make lint: UNUSEDSIGNAL**
