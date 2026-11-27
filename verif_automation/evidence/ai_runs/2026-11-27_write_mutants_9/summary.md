# Mutants written by the AI step - 2026-11-27 - commit 001df27

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 50; proposed: 25; accepted by the gate: 24; rejected: 1

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_fault_LED_1 | 20 | ok | 11 proposed, 10 accepted, 1 rejected |  |
| 001_fault_LED_2 | 20 | ok | 9 proposed, 9 accepted, 0 rejected |  |
| 001_fault_LED_3 | 10 | ok | 5 proposed, 5 accepted, 0 rejected |  |

## Rejected by the gate

- `fault_LED`: Outstanding strikes are detected from the LSB of strike_level alone, so a level of 2 count - **make lint already catches it: make lint: UNUSEDSIGNAL**
