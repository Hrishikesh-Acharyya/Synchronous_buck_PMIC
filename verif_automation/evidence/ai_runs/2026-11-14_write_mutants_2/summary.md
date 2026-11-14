# Mutants written by the AI step - 2026-11-14 - commit 664452d

Agent: Claude Code (claude -p), read-only; model(s): claude-fable-5-2
Modules: 1; mutants asked for: 6; proposed: 2; accepted by the gate: 1; rejected: 1

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_reset_sync_1 | 6 | ok | 2 proposed, 1 accepted, 1 rejected |  |

## Rejected by the gate

- `reset_sync`: The first stage clears synchronously only: meta_ff is not put back to 0 by a reset asserti - **make lint already catches it: make lint: SYNCASYNCNET**
