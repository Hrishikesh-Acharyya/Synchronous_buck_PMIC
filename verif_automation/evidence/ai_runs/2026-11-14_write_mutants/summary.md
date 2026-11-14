# Mutants written by the AI step - 2026-11-14 - commit 664452d

Agent: Claude Code (claude -p), read-only; model(s): claude-fable-5-2
Modules: 1; mutants asked for: 6; proposed: 3; accepted by the gate: 1; rejected: 2

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_reset_sync_1 | 6 | ok | 3 proposed, 1 accepted, 2 rejected |  |

## Rejected by the gate

- `reset_sync`: The output stage loses its asynchronous clear: rst_n_exit is cleared by rst_n_enter only a - **make lint already catches it: make lint: SYNCASYNCNET**
- `reset_sync`: The first synchronizer stage is cleared only synchronously, so meta_ff survives a reset pu - **make lint already catches it: make lint: SYNCASYNCNET**
