# Mutants written by the AI step - 2026-11-27 - commit 8d82e7e

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 50; proposed: 11; accepted by the gate: 10; rejected: 1

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_fault_cause_1 | 20 | ok | 3 proposed, 2 accepted, 1 rejected |  |
| 001_fault_cause_2 | 20 | ok | 7 proposed, 7 accepted, 0 rejected |  |
| 001_fault_cause_3 | 10 | ok | 1 proposed, 1 accepted, 0 rejected |  |

## Rejected by the gate

- `fault_cause`: The episode start time is latched from the two low bytes of timestamp_ms only, as if the c - **make lint already catches it: make lint: UNUSEDSIGNAL**
