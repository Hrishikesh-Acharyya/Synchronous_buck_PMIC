# Mutants written by the AI step - 2026-11-27 - commit 13c1372

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 50; proposed: 22; accepted by the gate: 21; rejected: 1

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_fault_arbiter_1 | 20 | ok | 8 proposed, 8 accepted, 0 rejected |  |
| 001_fault_arbiter_2 | 20 | ok | 7 proposed, 7 accepted, 0 rejected |  |
| 001_fault_arbiter_3 | 10 | ok | 7 proposed, 6 accepted, 1 rejected |  |

## Rejected by the gate

- `fault_arbiter`: The bit leaving the run window is copied across the whole count width instead of zero-exte - **not legal code: %Error: protect/fault_arbiter.sv:207:87: syntax error, unexpected ')'**
