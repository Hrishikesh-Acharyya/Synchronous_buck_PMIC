# Mutants written by the AI step - 2026-11-27 - commit 0ee549a

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 50; proposed: 28; accepted by the gate: 23; rejected: 5

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_supervisor_1 | 20 | ok | 13 proposed, 8 accepted, 5 rejected |  |
| 001_supervisor_2 | 20 | ok | 7 proposed, 7 accepted, 0 rejected |  |
| 001_supervisor_3 | 10 | ok | 8 proposed, 8 accepted, 0 rejected |  |

## Rejected by the gate

- `supervisor`: In S_SS, SS_done is tested before window_trip_SS, so ramp completion outranks an overcurre - **changes 10 lines; at most 6**
- `supervisor`: In S_SS the overcurrent window trip is tested before the hard faults, so a shutdown is out - **changes 11 lines; at most 6**
- `supervisor`: In S_RUN the overcurrent window trip is tested before the hard faults - **changes 11 lines; at most 6**
- `supervisor`: In S_HICCUP the end of the cool-down is tested before the hard faults, so a retry outranks - **changes 11 lines; at most 6**
- `supervisor`: S_HICCUP exits on the soft-start handshake SS_done (copied from the S_SS block) instead of - **the same edit as supervisor.206.SIB.1**
