# Mutants written by the AI step - 2026-11-14 - commit a625f66

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 6; proposed: 4; accepted by the gate: 3; rejected: 1

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_input_sync_1 | 6 | ok | 4 proposed, 3 accepted, 1 rejected |  |

## Rejected by the gate

- `input_sync`: sync_out samples async_in directly, bypassing meta_ff: a one-stage synchroniser with one c - **make lint already catches it: make lint: UNUSEDSIGNAL**
