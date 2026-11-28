# Mutants written by the AI step - 2026-11-28 - commit 5948cd0

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 50; proposed: 18; accepted by the gate: 17; rejected: 1

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_pmic_top_1 | 20 | ok | 9 proposed, 9 accepted, 0 rejected |  |
| 001_pmic_top_2 | 20 | ok | 8 proposed, 7 accepted, 1 rejected |  |
| 001_pmic_top_3 | 10 | ok | 1 proposed, 1 accepted, 0 rejected |  |

## Rejected by the gate

- `pmic_top`: The rolling-window counts are cross-wired: FCOUNT_RUN (0x15) reports the soft-start window - **not legal code: %Error: pmic_top.sv:396:63: syntax error, unexpected '.', expecting ')'**
