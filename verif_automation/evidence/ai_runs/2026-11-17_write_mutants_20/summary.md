# Mutants written by the AI step - 2026-11-17 - commit 743c83a

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 10; proposed: 6; accepted by the gate: 5; rejected: 1

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_soft_start_1 | 10 | ok | 6 proposed, 5 accepted, 1 rejected |  |

## Rejected by the gate

- `soft_start`: The step-window counter advances on every clock while the PWM is high, not once per switch - **the same edit as soft_start.126.SIB.1**
