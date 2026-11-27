# Mutants written by the AI step - 2026-11-27 - commit 001df27

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 50; proposed: 11; accepted by the gate: 10; rejected: 1

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_fault_LED_1 | 20 | ok | 5 proposed, 4 accepted, 1 rejected |  |
| 001_fault_LED_2 | 20 | ok | 3 proposed, 3 accepted, 0 rejected |  |
| 001_fault_LED_3 | 10 | ok | 3 proposed, 3 accepted, 0 rejected |  |

## Rejected by the gate

- `fault_LED`: Running indication takes 'running' from the power-good comparator instead of run_active, m - **make lint already catches it: make lint: UNUSEDSIGNAL**
