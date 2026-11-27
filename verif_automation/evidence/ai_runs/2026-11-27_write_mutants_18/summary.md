# Mutants written by the AI step - 2026-11-27 - commit 13c1372

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 50; proposed: 15; accepted by the gate: 14; rejected: 1

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_fault_arbiter_1 | 20 | ok | 7 proposed, 6 accepted, 1 rejected |  |
| 001_fault_arbiter_2 | 20 | ok | 5 proposed, 5 accepted, 0 rejected |  |
| 001_fault_arbiter_3 | 10 | ok | 3 proposed, 3 accepted, 0 rejected |  |

## Rejected by the gate

- `fault_arbiter`: The S_RUN window and its count both take the blanked sample from the comparator BLANK_CLKS - **not legal code: %Error: protect/fault_arbiter.sv:210:3: syntax error, unexpected end**
