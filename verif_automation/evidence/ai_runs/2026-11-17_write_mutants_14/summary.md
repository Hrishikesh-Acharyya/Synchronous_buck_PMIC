# Mutants written by the AI step - 2026-11-17 - commit 530e2fe

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 10; proposed: 8; accepted by the gate: 6; rejected: 2

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_strike_counter_1 | 10 | ok | 8 proposed, 6 accepted, 2 rejected |  |

## Rejected by the gate

- `strike_counter`: The clean-run clear outranks hiccup entry, so a hiccup that ends a saturated clean run ear - **changes 12 lines; at most 6**
- `strike_counter`: The clean-run streak is broken only by S_HICCUP, not by every exit from S_RUN, so cycles i - **make lint already catches it: make lint: UNUSEDSIGNAL**
