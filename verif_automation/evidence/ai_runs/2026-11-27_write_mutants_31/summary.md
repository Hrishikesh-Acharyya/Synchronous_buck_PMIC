# Mutants written by the AI step - 2026-11-27 - commit 0ee549a

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 50; proposed: 10; accepted by the gate: 9; rejected: 1

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_supervisor_1 | 20 | ok | 1 proposed, 1 accepted, 0 rejected |  |
| 001_supervisor_2 | 20 | ok | 3 proposed, 3 accepted, 0 rejected |  |
| 001_supervisor_3 | 10 | ok | 6 proposed, 5 accepted, 1 rejected |  |

## Rejected by the gate

- `supervisor`: run_active drops on the clock window_trip fires, a clock before the FSM leaves S_RUN for S - **make lint already catches it: make lint: UNOPTFLAT**
