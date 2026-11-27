# Mutants written by the AI step - 2026-11-27 - commit 13c1372

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 50; proposed: 15; accepted by the gate: 13; rejected: 2

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_fault_arbiter_1 | 20 | ok | 8 proposed, 7 accepted, 1 rejected |  |
| 001_fault_arbiter_2 | 20 | ok | 3 proposed, 3 accepted, 0 rejected |  |
| 001_fault_arbiter_3 | 10 | ok | 4 proposed, 3 accepted, 1 rejected |  |

## Rejected by the gate

- `fault_arbiter`: Blanking is applied only to the soft-start window: the S_RUN window and its count both tak - **the lines it replaces are not in the file**
- `fault_arbiter`: Blanking is applied only to the soft-start window: the S_RUN window and its count both tak - **the same edit as fault_arbiter.206.AIM.3**
