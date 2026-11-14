# Mutants written by the AI step - 2026-11-14 - commit 664452d

Agent: Claude Code (claude -p), read-only; model(s): claude-fable-5-2
Modules: 1; mutants asked for: 15; proposed: 2; accepted by the gate: 0; rejected: 2

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_reset_sync_1 | 15 | ok | 2 proposed, 0 accepted, 2 rejected |  |

## Rejected by the gate

- `reset_sync`: The first stage's clear is synchronous: meta_ff is cleared only if a clk edge samples rst_ - **make lint already catches it: make lint: SYNCASYNCNET**
- `reset_sync`: The second stage's clear is synchronous: rst_n_exit asserts only on a clk edge, not asynch - **make lint already catches it: make lint: SYNCASYNCNET**
