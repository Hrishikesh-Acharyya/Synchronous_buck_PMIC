# Mutants written by the AI step - 2026-11-26 - commit 219c651

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 50; proposed: 14; accepted by the gate: 13; rejected: 1

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_fault_cause_1 | 20 | ok | 5 proposed, 5 accepted, 0 rejected |  |
| 001_fault_cause_2 | 20 | ok | 6 proposed, 5 accepted, 1 rejected |  |
| 001_fault_cause_3 | 10 | ok | 3 proposed, 3 accepted, 0 rejected |  |

## Rejected by the gate

- `fault_cause`: The episode-start detector uses the debounced SCR readback latch_state where the accumulat - **the same edit as fault_cause.139.SIB.5**
