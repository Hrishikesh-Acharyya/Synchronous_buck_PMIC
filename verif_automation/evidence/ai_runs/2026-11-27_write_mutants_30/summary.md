# Mutants written by the AI step - 2026-11-27 - commit 0ee549a

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Modules: 1; mutants asked for: 50; proposed: 26; accepted by the gate: 21; rejected: 5

| Request | Asked for | Outcome | Result | Note |
|---|---:|---|---|---|
| 001_supervisor_1 | 20 | ok | 11 proposed, 6 accepted, 5 rejected |  |
| 001_supervisor_2 | 20 | ok | 9 proposed, 9 accepted, 0 rejected |  |
| 001_supervisor_3 | 10 | ok | 6 proposed, 6 accepted, 0 rejected |  |

## Rejected by the gate

- `supervisor`: An overcurrent window trip during soft start is treated as a hard fault and sends the FSM  - **the same edit as supervisor.163.ENM.1**
- `supervisor`: Reset puts the FSM in the S_HICCUP cool-down rather than S_OFF, as if power-up should wait - **the lines it replaces are not in the file**
- `supervisor`: S_HICCUP retries when the overcurrent window trip has cleared instead of when the cool-dow - **make lint already catches it: make lint: UNUSEDSIGNAL**
- `supervisor`: ss_active is also raised in S_HICCUP, as if the soft-start block had to be held active thr - **the lines it replaces are not in the file**
- `supervisor`: ss_active is decoded from next_state, so it rises a clock before the FSM registers S_SS an - **make lint already catches it: make lint: UNOPTFLAT**
