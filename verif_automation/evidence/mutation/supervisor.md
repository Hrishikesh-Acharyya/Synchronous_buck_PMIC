# Mutation record: supervisor

`rtl-systemverilog/supervisor.sv`. Written by `tools/mutation/record.py` from `supervisor.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 209 | 156 | 41 | 0 | 0 | 12 | 0 | 0 | 94.3% |
| AI-written | 76 | 76 | 0 | 0 | 0 | 0 | 0 | 0 | 100.0% |
| all | 285 | 232 | 41 | 0 | 0 | 12 | 0 | 0 | 95.8% |

Survivors: 12 - 12 decided equivalent, 0 accepted, 0 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 100.0%.
3 earlier mutants are not in these numbers: 3 AI-written ones the designer withdrew, 0 the generator no longer makes because the RTL changed. Their history is kept below.

## Survivors (12)

### `supervisor.135.SDL.1` - delete 'next_state = state;'

- before: `next_state = state;`
- after: `;`
- AI judgement (step 10): **equivalent**, high confidence - Every branch of the case on lines 137-222, including the default on line 220, assigns next_state. So the default assignment on line 135 is always overwritten before anything reads it.
- designer's decision (step 11): **equivalent** - line 135 sets next_state = state and every case branch assigns next_state (the default too), so the opening default and the per-state 'stay here' assignments are redundant

### `supervisor.148.SDL.1` - delete 'next_state = S_OFF;'

- before: `next_state = S_OFF;`
- after: `;`
- AI judgement (step 10): **equivalent**, high confidence - This else branch only runs when state == S_OFF (line 139). Line 135 has already set next_state = state = S_OFF, so deleting the redundant assignment changes nothing.
- designer's decision (step 11): **equivalent** - line 135 sets next_state = state and every case branch assigns next_state (the default too), so the opening default and the per-state 'stay here' assignments are redundant

### `supervisor.173.SDL.1` - delete 'next_state = S_SS;'

- before: `next_state = S_SS;`
- after: `;`
- AI judgement (step 10): **equivalent**, high confidence - This branch only runs when state == S_SS (line 154). Line 135 has already set next_state = state = S_SS, so deleting the assignment leaves the same value.
- designer's decision (step 11): **equivalent** - line 135 sets next_state = state and every case branch assigns next_state (the default too), so the opening default and the per-state 'stay here' assignments are redundant

### `supervisor.193.SDL.1` - delete 'next_state = S_RUN;'

- before: `next_state = S_RUN;`
- after: `;`
- AI judgement (step 10): **equivalent**, high confidence - This branch only runs when state == S_RUN (line 179). Line 135 has already set next_state = S_RUN, so the deleted assignment was redundant.
- designer's decision (step 11): **equivalent** - line 135 sets next_state = state and every case branch assigns next_state (the default too), so the opening default and the per-state 'stay here' assignments are redundant

### `supervisor.213.SDL.1` - delete 'next_state = S_HICCUP;'

- before: `next_state = S_HICCUP;`
- after: `;`
- AI judgement (step 10): **equivalent**, high confidence - This branch only runs when state == S_HICCUP (line 199). Line 135 has already set next_state = S_HICCUP, so the deleted assignment was redundant.
- designer's decision (step 11): **equivalent** - line 135 sets next_state = state and every case branch assigns next_state (the default too), so the opening default and the per-state 'stay here' assignments are redundant

### `supervisor.220.ENM.1` - S_OFF -> S_SS

- before: `default: next_state = S_OFF;`
- after: `default: next_state = S_SS;`
- AI judgement (step 10): **equivalent**, medium confidence - The default branch on line 220 can't be reached: the four enum values cover every 2-bit encoding, and state only ever holds legal values from reset (line 104) or next_state. Its target only matters for an X state in simulation before reset.
- designer's decision (step 13): **equivalent** - state_t is 2 bits and S_OFF/S_SS/S_RUN/S_HICCUP use all four codes (00, 01, 10, 11), and state is only ever loaded from reset or next_state, so the default arms never run

### `supervisor.220.SDL.1` - delete 'next_state = S_OFF;'

- before: `default: next_state = S_OFF;`
- after: `default: ;`
- AI judgement (step 10): **equivalent**, medium confidence - state_t is a 2-bit enum, and S_OFF/S_SS/S_RUN/S_HICCUP use all four codes (pkg lines 310-313). Reset (line 104) and every next_state assignment load legal values, so the default on line 220 never runs once reset has been applied. The only possible difference is how an X state behaves in simulation before the first reset.
- designer's decision (step 13): **equivalent** - state_t is 2 bits and S_OFF/S_SS/S_RUN/S_HICCUP use all four codes (00, 01, 10, 11), and state is only ever loaded from reset or next_state, so the default arms never run

### `supervisor.237.CID.1` - delete the case item 'S_OFF': it takes the default branch

- before: `S_OFF:    en_from_state = 1'b0;`
- after: ``
- AI judgement (step 10): **equivalent**, high confidence - With the S_OFF item deleted, S_OFF falls into the default on line 241, which also assigns en_from_state = 1'b0. The result is identical.
- designer's decision (step 12): **equivalent** - the deleted S_OFF or S_HICCUP item falls to the default, which also assigns en_from_state = 0

### `supervisor.238.CIS.1` - case labels S_SS and S_RUN swapped

- before: `S_SS:     en_from_state = 1'b1;`
- after: `S_RUN:     en_from_state = 1'b1;`
- AI judgement (step 10): **plausible**, high confidence - Relabelling line 238 as S_RUN leaves S_SS with no item of its own, so S_SS takes the default on line 241 (en_from_state = 0). That forces en low during soft start (line 275), which is visible at the en port.
- designer's decision (step 14): **equivalent** - CIS swaps both labels, S_SS and S_RUN, and both items assign en_from_state = 1, so every state decodes as before; the AI judgement read it as relabelling one line only

### `supervisor.240.CID.1` - delete the case item 'S_HICCUP': it takes the default branch

- before: `S_HICCUP: en_from_state = 1'b0;`
- after: ``
- AI judgement (step 10): **equivalent**, high confidence - With the S_HICCUP item deleted, S_HICCUP falls into the default on line 241, which also assigns en_from_state = 1'b0. The result is identical.
- designer's decision (step 12): **equivalent** - the deleted S_OFF or S_HICCUP item falls to the default, which also assigns en_from_state = 0

### `supervisor.241.CST.1` - 1'b0 -> 1'b1

- before: `default:  en_from_state = 1'b0;`
- after: `default:  en_from_state = 1'b1;`
- AI judgement (step 10): **equivalent**, medium confidence - The default on line 241 can't be reached: S_OFF/S_SS/S_RUN/S_HICCUP use every 2-bit code, and state is always loaded with a legal value (lines 104, 109). Its constant only matters for an X state in simulation before reset.
- designer's decision (step 13): **equivalent** - state_t is 2 bits and S_OFF/S_SS/S_RUN/S_HICCUP use all four codes (00, 01, 10, 11), and state is only ever loaded from reset or next_state, so the default arms never run

### `supervisor.241.SDL.1` - delete 'en_from_state = 1'b0;'

- before: `default:  en_from_state = 1'b0;`
- after: `default:  ;`
- AI judgement (step 10): **equivalent**, medium confidence - Lines 237-240 already cover all four 2-bit state encodings, and state only ever holds legal values after reset, so the default on line 241 never runs. Deleting it only creates an inferred latch that is never exercised. The only difference would be how an X state behaves in simulation before reset.
- designer's decision (step 13): **equivalent** - state_t is 2 bits and S_OFF/S_SS/S_RUN/S_HICCUP use all four codes (00, 01, 10, 11), and state is only ever loaded from reset or next_state, so the default arms never run

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-27 20:00 | 0ee549a | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 28, accepted 23, rejected 5; `ai_runs/2026-11-27_write_mutants_29` |
| 2 | 2026-11-27 20:11 | 0ee549a | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 26, accepted 21, rejected 5; `ai_runs/2026-11-27_write_mutants_30` |
| 3 | 2026-11-27 20:17 | 0ee549a | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 10, accepted 9, rejected 1; `ai_runs/2026-11-27_write_mutants_31` |
| 4 | 2026-11-27 20:25 | 0ee549a | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 11, accepted 11, rejected 0; `ai_runs/2026-11-27_write_mutants_32` |
| 5 | 2026-11-27 20:31 | 0ee549a | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 13, accepted 13, rejected 0; `ai_runs/2026-11-27_write_mutants_33` |
| 6 | 2026-11-27 20:38 | 0ee549a | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 2, accepted 2, rejected 0; `ai_runs/2026-11-27_write_mutants_34` |
| 7 | 2026-11-27 22:07 | 0ee549a | designer withdrew AI-written mutants | supervisor.88.AIM.41, supervisor.88.AIM.76 - the per-state enable mutants combined: a host (AIM.41) or switch (AIM.76) disable ignored in S_SS, S_RUN and S_HICCUP gives the same wrong state as AIM.46/15/47 or AIM.55/50/56, so any test that kills one of those kills it |
| 8 | 2026-11-27 22:07 | 0ee549a | designer withdrew AI-written mutants | supervisor.201.AIM.1 - the per-fault S_HICCUP mutants combined: a hard fault or disable that leaves the FSM in S_HICCUP, as AIM.39, AIM.40, AIM.57, AIM.58 and AIM.67 each do for one input, so any test that kills one of those kills it |
| 9 | 2026-11-27 22:25 | 0ee549a | mutation run - every mutant of the module | 285 mutants: 232 killed, 41 lint, 12 survived; score 95.8% |
| 10 | 2026-11-27 22:26 | 0ee549a | AI judged survivors (claude-opus-5-5) | 12 judged, 7 called equivalent with high confidence; `ai_runs/2026-11-27_judge_survivors_4` |
| 11 | 2026-11-27 22:30 | 0ee549a | designer's decision: equivalent | supervisor.135.SDL.1, supervisor.148.SDL.1, supervisor.173.SDL.1, supervisor.193.SDL.1, supervisor.213.SDL.1 - line 135 sets next_state = state and every case branch assigns next_state (the default too), so the opening default and the per-state 'stay here' assignments are redundant |
| 12 | 2026-11-27 22:30 | 0ee549a | designer's decision: equivalent | supervisor.237.CID.1, supervisor.240.CID.1 - the deleted S_OFF or S_HICCUP item falls to the default, which also assigns en_from_state = 0 |
| 13 | 2026-11-27 22:30 | 0ee549a | designer's decision: equivalent | supervisor.220.ENM.1, supervisor.220.SDL.1, supervisor.241.CST.1, supervisor.241.SDL.1 - state_t is 2 bits and S_OFF/S_SS/S_RUN/S_HICCUP use all four codes (00, 01, 10, 11), and state is only ever loaded from reset or next_state, so the default arms never run |
| 14 | 2026-11-27 22:30 | 0ee549a | designer's decision: equivalent | supervisor.238.CIS.1 - CIS swaps both labels, S_SS and S_RUN, and both items assign en_from_state = 1, so every state decodes as before; the AI judgement read it as relabelling one line only |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (79)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | missing_case | S_HICCUP has no hard-fault exit: the designer relied on the gate drive already being off and only waits for hiccup_done | withdrawn: the per-fault S_HICCUP mutants combined: a hard fault or disable that leaves the FSM in S_HICCUP, as AIM.39, AIM.40, AIM.57, AIM.58 and AIM.67 each do for one input, so any test that kills one of those kills it |  |
| 2 | 1 | missing_case | Start-up from S_OFF checks only the enable and none of the hard faults, relying on en being fault-gated | killed | a_off_holds_on_fault |
| 3 | 1 | other | S_OFF starts straight into S_RUN when SS_done is still high, skipping the re-ramp | killed | a_off_to_ss |
| 4 | 1 | sequencing | The power-stage enable is decoded from next_state instead of the registered state | killed | a_en_only_in_ss_or_run, a_en_high_when_allowed |
| 5 | 1 | sequencing | Telemetry state_out shows the next state instead of the present registered state | killed | a_ss_active_decode, a_en_high_when_allowed +6 |
| 6 | 1 | missing_case | run_active is decoded as 'power stage switching' and so is also high in S_SS | killed | a_run_active_decode |
| 7 | 1 | sequencing | The gate-drive enable relies on the state alone for the hard faults, dropping the combinational fault gating | killed | a_hard_fault_holds_en_low |
| 8 | 1 | boundary | ss_active is dropped as soon as the ramp reports done, a clock before the FSM leaves S_SS | killed | a_ss_active_decode |
| 9 | 1 | wrong_event | An overcurrent window trip in S_RUN re-ramps straight into S_SS instead of first serving the S_HICCUP cool-down | killed | a_run_to_hiccup |
| 10 | 1 | sequencing | At the end of the cool-down S_HICCUP returns to S_OFF and relies on S_OFF to restart, instead of retrying directly into S_SS | killed | a_hiccup_to_ss |
| 11 | 1 | sequencing | hiccup_active is decoded from next_state, so it leads the registered S_HICCUP state by one clock | killed | a_hiccup_active_decode |
| 12 | 1 | other | run_active is taken as 'regulating and gate drive on', so the combinational fault gating of en also drops it | killed | a_run_active_decode |
| 13 | 1 | missing_case | hiccup_active is decoded as 'power stage held off by the state', so it is also high in S_OFF | killed | a_hiccup_active_decode |
| 14 | 1 | other | The overcurrent window trips are treated as hard fault inputs in the combinational gating of en | killed | a_en_high_when_allowed |
| 15 | 1 | missing_case | In S_RUN only the physical switch is checked for disable: a host disable over SPI gates en but does not send the FSM to S_OFF | killed | a_hard_fault_to_off |
| 16 | 1 | priority | In S_SS ramp completion outranks the overcurrent window trip: window_trip_SS is only honoured while SS_done is low | killed | a_ss_to_hiccup |
| 17 | 1 | priority | In S_SS an overcurrent window trip outranks a hard fault, so a coincident shutdown is first sent through S_HICCUP | killed | a_hard_fault_to_off |
| 18 | 1 | priority | In S_RUN the overcurrent window trip outranks a hard fault, so a coincident shutdown goes to S_HICCUP first | killed | a_hard_fault_to_off |
| 19 | 1 | priority | In S_HICCUP the end of the cool-down outranks a hard fault, so a retry into S_SS wins over a shutdown | killed | a_hard_fault_to_off |
| 20 | 1 | priority | In S_SS ramp completion outranks the hard faults, so a fault at the end of the ramp still promotes the FSM to S_RUN | killed | a_hard_fault_to_off |
| 21 | 1 | sequencing | The combinational en gating uses the physical switch alone, so a host disable over SPI waits for the FSM to reach S_OFF | killed | a_hard_fault_holds_en_low |
| 22 | 1 | sequencing | hiccup_active is dropped as soon as the cool-down reports done, a clock before the FSM leaves S_HICCUP | killed | a_hiccup_active_decode |
| 23 | 1 | missing_case | Start-up from S_OFF checks only the physical switch and forgets the host enable over SPI | killed | a_off_holds_on_fault |
| 24 | 2 | missing_case | In S_RUN either overcurrent window trip sends the FSM to S_HICCUP: the soft-start trip window_trip_SS is honoured outside S_SS | killed | a_run_holds |
| 25 | 2 | other | Over-temperature in S_RUN is treated as a recoverable fault and sent through the S_HICCUP cool-down instead of straight to S_OFF | killed | a_hard_fault_to_off |
| 26 | 2 | missing_case | At the end of the cool-down S_HICCUP retries straight into S_RUN when the soft-start handshake SS_done is still high, skipping the re-ramp | killed | a_hiccup_to_ss |
| 27 | 2 | sequencing | The state register is clock-enabled by the converter enable, so it freezes instead of loading S_OFF when the enable is lost | killed | a_hard_fault_to_off |
| 28 | 2 | sequencing | The gate drive is re-enabled on the clock hiccup_done rises in S_HICCUP, a clock before the FSM has registered the retry into S_SS | killed | a_en_only_in_ss_or_run |
| 29 | 2 | sequencing | The gate drive is enabled in S_OFF as soon as the converter is enabled, a clock before the FSM has registered S_SS | killed | a_en_only_in_ss_or_run |
| 30 | 2 | missing_case | In S_SS either overcurrent window trip sends the FSM to S_HICCUP: the run-state trip window_trip is also honoured during soft start | killed | a_ss_holds, a_ss_to_run |
| 31 | 2 | other | S_HICCUP retries only when the cool-down has elapsed and the run overcurrent trip has also cleared, as if a retry had to wait for the fault to go away | killed | a_hiccup_to_ss |
| 32 | 2 | missing_case | S_RUN is treated as valid only while the soft-start handshake SS_done is held, and drops back to S_SS when SS_done falls | killed | a_run_holds |
| 33 | 2 | reset_init | Reset puts the FSM in the S_HICCUP cool-down instead of S_OFF, as if power-up had to wait out a cool-down before the first start | killed | a_reset_means_off |
| 34 | 2 | wrong_event | ss_active is decoded as 'power stage may switch', so it is also high in S_RUN | killed | a_ss_active_decode |
| 35 | 2 | other | UVLO during soft start is treated as a recoverable inrush brown-out and sent through the S_HICCUP cool-down instead of straight to S_OFF | killed | a_hard_fault_to_off |
| 36 | 2 | other | latch_assert in S_RUN is treated as one more strike and sent to the S_HICCUP cool-down instead of forcing S_OFF | killed | a_hard_fault_to_off |
| 37 | 2 | other | Start-up from S_OFF counts the overcurrent window trips as faults that must be absent, reading 'no fault present' as including them | killed | a_off_to_ss |
| 38 | 2 | sequencing | Start-up from S_OFF waits for the soft-start handshake SS_done to be low, as if the ramp had to report its reset first | killed | a_off_to_ss |
| 39 | 2 | missing_case | In S_HICCUP latch_assert only blocks the retry instead of forcing S_OFF, as if a strike-latched converter just stayed in the cool-down | killed | a_hard_fault_to_off |
| 40 | 2 | missing_case | Over-temperature during S_HICCUP is treated as part of the cool-down: the FSM stays in S_HICCUP until OTP clears instead of going to S_OFF | killed | a_hard_fault_to_off |
| 41 | 2 | wrong_event | The host enable over SPI is treated as a start request checked only in S_OFF, so a host disable while ramping, running or in hiccup is ignored | withdrawn: the per-state enable mutants combined: a host (AIM.41) or switch (AIM.76) disable ignored in S_SS, S_RUN and S_HICCUP gives the same wrong state as AIM.46/15/47 or AIM.55/50/56, so any test that kills one of those kills it |  |
| 42 | 2 | sequencing | run_active is raised on the clock the ramp reports SS_done, a clock before the FSM has registered S_RUN | killed | a_run_active_decode |
| 43 | 2 | sequencing | ss_active is raised on the clock the cool-down reports hiccup_done, a clock before the FSM has registered the retry into S_SS | killed | a_ss_active_decode |
| 44 | 2 | sequencing | hiccup_active is held until the cool-down timer drops hiccup_done, as if leaving S_HICCUP had to wait for the timer's acknowledge | killed | a_hiccup_active_decode |
| 45 | 3 | other | An overcurrent window trip during soft start only pauses the promotion to S_RUN and keeps the FSM ramping in S_SS, as if high current while the output capacitor charges were expected, instead of sending the converter into the S_HICCUP cool-down | killed | a_ss_to_hiccup |
| 46 | 3 | missing_case | In S_SS only the physical switch is checked for disable, so a host disable over SPI during soft start gates en but leaves the FSM ramping in S_SS | killed | a_hard_fault_to_off |
| 47 | 3 | missing_case | In S_HICCUP only the physical switch is checked for disable, so a host disable over SPI during the cool-down does not send the FSM to S_OFF and it still retries into S_SS | killed | a_hard_fault_to_off |
| 48 | 3 | missing_case | Input undervoltage in S_RUN is treated as a recoverable brown-out under load and sent through the S_HICCUP cool-down instead of straight to S_OFF | killed | a_hard_fault_to_off |
| 49 | 3 | missing_case | Start-up from S_OFF checks only the host enable over SPI and forgets the physical switch en_SW | killed | a_off_holds_on_fault |
| 50 | 3 | missing_case | In S_RUN only a host disable over SPI is checked: turning off the physical switch gates en but does not send the FSM to S_OFF | killed | a_hard_fault_to_off |
| 51 | 3 | sequencing | The combinational en gating applies only the host enable, so turning off the physical switch waits for the FSM to register S_OFF | killed | a_hard_fault_holds_en_low |
| 52 | 3 | field | Telemetry state_out reports S_OFF as soon as a hard fault gates en, instead of the registered present state | killed | a_ss_active_decode, a_off_to_ss +4 |
| 53 | 3 | missing_case | A start request blocked in S_OFF by OTP or UVLO is treated as a recoverable fault and sent into the S_HICCUP cool-down instead of holding S_OFF | killed | a_off_holds_on_fault |
| 54 | 4 | missing_case | Over-temperature during soft start is treated as a recoverable start-up stress and sent through the S_HICCUP cool-down instead of straight to S_OFF | killed | a_hard_fault_to_off |
| 55 | 4 | missing_case | In S_SS only a host disable over SPI is checked: turning off the physical switch during soft start gates en but leaves the FSM ramping in S_SS | killed | a_hard_fault_to_off |
| 56 | 4 | missing_case | In S_HICCUP only a host disable over SPI is checked: turning off the physical switch during the cool-down does not send the FSM to S_OFF | killed | a_hard_fault_to_off |
| 57 | 4 | wrong_event | Losing the enable during the cool-down only holds off the retry: the FSM waits in S_HICCUP until it is re-enabled instead of going to S_OFF | killed | a_hard_fault_to_off |
| 58 | 4 | missing_case | Input undervoltage during the cool-down is treated as extending the cool-down: the FSM stays in S_HICCUP until UVLO clears instead of going to S_OFF | killed | a_hard_fault_to_off |
| 59 | 4 | missing_case | ss_active is decoded as 'a soft-start sequence is under way', so it is also high during the S_HICCUP cool-down that leads into the re-ramp | killed | a_ss_active_decode |
| 60 | 4 | missing_case | run_active treats the hiccup cool-down as a pause inside regulation, so it is also high in S_HICCUP | killed | a_run_active_decode |
| 61 | 4 | missing_case | hiccup_active is decoded as 'a hiccup retry is in progress', so it also covers the re-ramp in S_SS, including the first start from S_OFF | killed | a_hiccup_active_decode |
| 62 | 4 | wrong_event | Losing the enable in S_RUN is handled like an overcurrent trip and sent through S_HICCUP, as if a disable under load had to cool down before turning off | killed | a_hard_fault_to_off |
| 63 | 4 | missing_case | During soft start the latch read-back latch_state is treated as an overvoltage overshoot of the ramp, a recoverable event sent to the S_HICCUP cool-down, instead of a hard fault forcing S_OFF | killed | a_hard_fault_to_off |
| 64 | 4 | sequencing | The gate drive in S_SS is decoded as 'ramp still in progress', so it drops on the clock the ramp reports SS_done, before the FSM has registered S_RUN | killed | a_en_high_when_allowed |
| 65 | 5 | field | Telemetry state_out reports the hiccup cool-down as S_OFF, because the power stage is off in both, instead of the registered present state | killed | a_hiccup_active_decode, a_run_to_hiccup +2 |
| 66 | 5 | missing_case | In S_RUN the latch read-back latch_state is treated as a recoverable overshoot from a load step and sent to the S_HICCUP cool-down instead of forcing S_OFF | killed | a_hard_fault_to_off |
| 67 | 5 | missing_case | In S_HICCUP the latch read-back latch_state only holds off the retry, as if the latch were left over from the fault being cooled down, instead of forcing S_OFF | killed | a_hard_fault_to_off |
| 68 | 5 | sequencing | ss_active is raised in S_OFF as soon as the converter is enabled, as a start request to soft start, a clock before the FSM has registered S_SS | killed | a_ss_active_decode |
| 69 | 5 | other | In S_RUN the gate drive is made to depend on the soft-start handshake SS_done, as if regulation were allowed to switch only while the ramp still reports done | killed | a_en_high_when_allowed |
| 70 | 5 | wrong_event | Losing the enable during soft start is handled like a soft-start overcurrent trip and sent through S_HICCUP, as if an aborted ramp had to cool down before turning off | killed | a_hard_fault_to_off |
| 71 | 5 | other | Start-up from S_OFF tests the gated gate-drive enable en instead of the combined converter enable g_en, confusing the output enable with the enable request | killed | a_off_to_ss |
| 72 | 5 | other | The disable test in S_HICCUP uses the gated gate-drive enable en instead of the converter enable g_en, so the cool-down's own gate-drive-off reads as a disable | killed | a_hiccup_holds, a_hiccup_to_ss |
| 73 | 5 | sequencing | ss_active is decoded as 'ramping with the gate drive on', so the combinational fault gating of en also drops it before the FSM leaves S_SS | killed | a_ss_active_decode |
| 74 | 5 | sequencing | hiccup_active is decoded as 'cool-down still running', so a hard fault or disable drops it combinationally before the FSM leaves S_HICCUP | killed | a_hiccup_active_decode |
| 75 | 5 | sequencing | Every start from S_OFF goes through the S_HICCUP cool-down before soft start, as if each restart after a shutdown needed the same off-time as a fault retry | killed | a_off_to_ss |
| 76 | 5 | wrong_event | The physical switch en_SW is treated as a start request checked only in S_OFF, so turning it off while ramping, running or in hiccup is ignored | withdrawn: the per-state enable mutants combined: a host (AIM.41) or switch (AIM.76) disable ignored in S_SS, S_RUN and S_HICCUP gives the same wrong state as AIM.46/15/47 or AIM.55/50/56, so any test that kills one of those kills it |  |
| 77 | 5 | sequencing | Telemetry state_out reports S_RUN as soon as the ramp reports SS_done, instead of the registered present state | killed | a_ss_active_decode, a_run_active_decode +4 |
| 78 | 6 | sequencing | The combined converter enable g_en is registered instead of combinational, so the switch and host enables reach the gate drive and the FSM a clock late | killed | a_off_holds_on_fault, a_off_to_ss +6 |
| 79 | 6 | sequencing | The LM5106 enable en is registered to give a glitch-free gate drive, so it follows the state and the fault inputs one clock late | killed | a_en_high_when_allowed, a_hard_fault_holds_en_low +1 |

Rejected by the gate in step 1 (5):

- In S_SS, SS_done is tested before window_trip_SS, so ramp completion outranks an overcurrent trip - **changes 10 lines; at most 6**
- In S_SS the overcurrent window trip is tested before the hard faults, so a shutdown is outranked by a hiccup - **changes 11 lines; at most 6**
- In S_RUN the overcurrent window trip is tested before the hard faults - **changes 11 lines; at most 6**
- In S_HICCUP the end of the cool-down is tested before the hard faults, so a retry outranks a shutdown - **changes 11 lines; at most 6**
- S_HICCUP exits on the soft-start handshake SS_done (copied from the S_SS block) instead of on hiccup_done - **the same edit as supervisor.206.SIB.1**

Rejected by the gate in step 2 (5):

- An overcurrent window trip during soft start is treated as a hard fault and sends the FSM to S_OFF instead of into the S_HICCUP cool-down - **the same edit as supervisor.163.ENM.1**
- Reset puts the FSM in the S_HICCUP cool-down rather than S_OFF, as if power-up should wait a cool-down before the first start - **the lines it replaces are not in the file**
- S_HICCUP retries when the overcurrent window trip has cleared instead of when the cool-down timer reports hiccup_done - **make lint already catches it: make lint: UNUSEDSIGNAL**
- ss_active is also raised in S_HICCUP, as if the soft-start block had to be held active through the cool-down - **the lines it replaces are not in the file**
- ss_active is decoded from next_state, so it rises a clock before the FSM registers S_SS and falls a clock before it leaves - **make lint already catches it: make lint: UNOPTFLAT**

Rejected by the gate in step 3 (1):

- run_active drops on the clock window_trip fires, a clock before the FSM leaves S_RUN for S_HICCUP - **make lint already catches it: make lint: UNOPTFLAT**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `supervisor.79.AIM.78` | The combined converter enable g_en is registered instead of combinational, so the switch and host enables reach the gate drive and the FSM a clock late | 9:killed | a_off_holds_on_fault, a_off_to_ss +6 |
| `supervisor.88.CTD.1` | drop the term 'spi_enable' | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.88.CTD.2` | drop the term 'en_SW' | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.88.CTN.1` | negate the term 'spi_enable' | 9:killed | a_hard_fault_holds_en_low, a_off_holds_on_fault +2 |
| `supervisor.88.CTN.2` | negate the term 'en_SW' | 9:killed | a_hard_fault_holds_en_low, a_off_holds_on_fault +6 |
| `supervisor.88.LCR.1` | & -> \| | 9:killed | a_hard_fault_holds_en_low, a_off_holds_on_fault +1 |
| `supervisor.88.SDL.1` | delete 'g_en = spi_enable & en_SW;' | 9:lint | make lint: UNDRIVEN, UNUSEDSIGNAL |
| `supervisor.88.STK.1` | g_en stuck at all-zeros (was 'spi_enable & en_SW') | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.88.STK.2` | g_en stuck at all-ones (was 'spi_enable & en_SW') | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.88.VNG.1` | g_en inverted (was 'spi_enable & en_SW') | 9:killed | a_hard_fault_holds_en_low, a_off_holds_on_fault +6 |
| `supervisor.93.EDG.1` | posedge clk -> negedge clk | 9:killed | a_off_holds_on_fault, a_ss_holds +6 |
| `supervisor.102.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 9:killed | nothing named in the log |
| `supervisor.102.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 9:killed | a_off_to_ss |
| `supervisor.102.UOD.1` | drop the '!' before rst_n | 9:killed | a_off_to_ss, a_ss_holds |
| `supervisor.104.AIM.33` | Reset puts the FSM in the S_HICCUP cool-down instead of S_OFF, as if power-up had to wait out a cool-down before the first start | 9:killed | a_reset_means_off |
| `supervisor.104.ENM.1` | S_OFF -> S_SS | 9:killed | a_reset_means_off |
| `supervisor.104.SDL.1` | delete 'state <= S_OFF;' | 9:killed | nothing named in the log |
| `supervisor.107.AIM.27` | The state register is clock-enabled by the converter enable, so it freezes instead of loading S_OFF when the enable is lost | 9:killed | a_hard_fault_to_off |
| `supervisor.109.SDL.1` | delete 'state <= next_state;' | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.135.SDL.1` | delete 'next_state = state;' | 9:survived |  |
| `supervisor.139.CID.1` | delete the case item 'S_OFF': it takes the default branch | 9:killed | a_off_to_ss |
| `supervisor.139.CIS.1` | case labels S_OFF and S_SS swapped | 9:killed | a_ss_to_run, a_ss_to_hiccup +1 |
| `supervisor.141.AIM.2` | Start-up from S_OFF checks only the enable and none of the hard faults, relying on en being fault-gated | 9:killed | a_off_holds_on_fault |
| `supervisor.141.AIM.23` | Start-up from S_OFF checks only the physical switch and forgets the host enable over SPI | 9:killed | a_off_holds_on_fault |
| `supervisor.141.AIM.37` | Start-up from S_OFF counts the overcurrent window trips as faults that must be absent, reading 'no fault present' as including them | 9:killed | a_off_to_ss |
| `supervisor.141.AIM.38` | Start-up from S_OFF waits for the soft-start handshake SS_done to be low, as if the ramp had to report its reset first | 9:killed | a_off_to_ss |
| `supervisor.141.AIM.49` | Start-up from S_OFF checks only the host enable over SPI and forgets the physical switch en_SW | 9:killed | a_off_holds_on_fault |
| `supervisor.141.AIM.71` | Start-up from S_OFF tests the gated gate-drive enable en instead of the combined converter enable g_en, confusing the output enable with the enable request | 9:killed | a_off_to_ss |
| `supervisor.141.CND.1` | if (g_en & ~latch_state & ~OTP & ~UVLO & ~latch_assert) -> if (!(...)) | 9:killed | a_off_holds_on_fault, a_off_to_ss |
| `supervisor.141.CSK.1` | if (g_en & ~latch_state & ~OTP & ~UVLO & ~latch_assert) -> if (1'b0): never taken | 9:killed | a_off_to_ss |
| `supervisor.141.CSK.2` | if (g_en & ~latch_state & ~OTP & ~UVLO & ~latch_assert) -> if (1'b1): always taken | 9:killed | a_off_holds_on_fault |
| `supervisor.141.CTD.1` | drop the term 'g_en' | 9:killed | a_off_holds_on_fault |
| `supervisor.141.CTD.2` | drop the term '~latch_state' | 9:killed | a_off_holds_on_fault |
| `supervisor.141.CTD.3` | drop the term '~OTP' | 9:killed | a_off_holds_on_fault |
| `supervisor.141.CTD.4` | drop the term '~UVLO' | 9:killed | a_off_holds_on_fault |
| `supervisor.141.CTD.5` | drop the term '~latch_assert' | 9:killed | a_off_holds_on_fault |
| `supervisor.141.CTN.1` | negate the term 'g_en' | 9:killed | a_off_holds_on_fault, a_off_to_ss |
| `supervisor.141.LCR.1` | & -> \| | 9:killed | a_off_holds_on_fault |
| `supervisor.141.LCR.2` | & -> \| | 9:killed | a_off_holds_on_fault |
| `supervisor.141.LCR.3` | & -> \| | 9:killed | a_off_holds_on_fault |
| `supervisor.141.LCR.4` | & -> \| | 9:killed | a_off_holds_on_fault |
| `supervisor.141.SIB.1` | latch_state -> latch_assert | 9:killed | a_off_holds_on_fault |
| `supervisor.141.SIB.2` | latch_assert -> latch_state | 9:killed | a_off_holds_on_fault |
| `supervisor.141.UOD.1` | drop the '~' before latch_state | 9:killed | a_off_holds_on_fault, a_off_to_ss |
| `supervisor.141.UOD.2` | drop the '~' before OTP | 9:killed | a_off_holds_on_fault, a_off_to_ss |
| `supervisor.141.UOD.3` | drop the '~' before UVLO | 9:killed | a_off_holds_on_fault, a_off_to_ss |
| `supervisor.141.UOD.4` | drop the '~' before latch_assert | 9:killed | a_off_holds_on_fault, a_off_to_ss |
| `supervisor.143.AIM.3` | S_OFF starts straight into S_RUN when SS_done is still high, skipping the re-ramp | 9:killed | a_off_to_ss |
| `supervisor.143.AIM.75` | Every start from S_OFF goes through the S_HICCUP cool-down before soft start, as if each restart after a shutdown needed the same off-time as a fault retry | 9:killed | a_off_to_ss |
| `supervisor.143.ENM.1` | S_SS -> S_RUN | 9:killed | a_off_to_ss |
| `supervisor.143.SDL.1` | delete 'next_state = S_SS;' | 9:killed | a_off_to_ss |
| `supervisor.146.AIM.53` | A start request blocked in S_OFF by OTP or UVLO is treated as a recoverable fault and sent into the S_HICCUP cool-down instead of holding S_OFF | 9:killed | a_off_holds_on_fault |
| `supervisor.148.ENM.1` | S_OFF -> S_SS | 9:killed | a_off_holds_on_fault |
| `supervisor.148.SDL.1` | delete 'next_state = S_OFF;' | 9:survived |  |
| `supervisor.154.CID.1` | delete the case item 'S_SS': it takes the default branch | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.154.CIS.1` | case labels S_SS and S_RUN swapped | 9:killed | a_ss_holds, a_run_holds +3 |
| `supervisor.156.AIM.17` | In S_SS an overcurrent window trip outranks a hard fault, so a coincident shutdown is first sent through S_HICCUP | 9:killed | a_hard_fault_to_off |
| `supervisor.156.AIM.20` | In S_SS ramp completion outranks the hard faults, so a fault at the end of the ramp still promotes the FSM to S_RUN | 9:killed | a_hard_fault_to_off |
| `supervisor.156.AIM.35` | UVLO during soft start is treated as a recoverable inrush brown-out and sent through the S_HICCUP cool-down instead of straight to S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.156.AIM.46` | In S_SS only the physical switch is checked for disable, so a host disable over SPI during soft start gates en but leaves the FSM ramping in S_SS | 9:killed | a_hard_fault_to_off |
| `supervisor.156.AIM.54` | Over-temperature during soft start is treated as a recoverable start-up stress and sent through the S_HICCUP cool-down instead of straight to S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.156.AIM.55` | In S_SS only a host disable over SPI is checked: turning off the physical switch during soft start gates en but leaves the FSM ramping in S_SS | 9:killed | a_hard_fault_to_off |
| `supervisor.156.AIM.63` | During soft start the latch read-back latch_state is treated as an overvoltage overshoot of the ramp, a recoverable event sent to the S_HICCUP cool-down, instead of a hard fault forcing S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.156.AIM.70` | Losing the enable during soft start is handled like a soft-start overcurrent trip and sent through S_HICCUP, as if an aborted ramp had to cool down before turning off | 9:killed | a_hard_fault_to_off |
| `supervisor.156.CND.1` | if (~g_en \| OTP \| latch_state \| UVLO \| latch_assert) -> if (!(...)) | 9:killed | a_ss_holds, a_hard_fault_to_off +2 |
| `supervisor.156.CSK.1` | if (~g_en \| OTP \| latch_state \| UVLO \| latch_assert) -> if (1'b0): never taken | 9:killed | a_hard_fault_to_off |
| `supervisor.156.CSK.2` | if (~g_en \| OTP \| latch_state \| UVLO \| latch_assert) -> if (1'b1): always taken | 9:killed | a_ss_holds, a_ss_to_run +1 |
| `supervisor.156.CTD.1` | drop the term '~g_en' | 9:killed | a_hard_fault_to_off |
| `supervisor.156.CTD.2` | drop the term 'OTP' | 9:killed | a_hard_fault_to_off |
| `supervisor.156.CTD.3` | drop the term 'latch_state' | 9:killed | a_hard_fault_to_off |
| `supervisor.156.CTD.4` | drop the term 'UVLO' | 9:killed | a_hard_fault_to_off |
| `supervisor.156.CTD.5` | drop the term 'latch_assert' | 9:killed | a_hard_fault_to_off |
| `supervisor.156.CTN.1` | negate the term 'OTP' | 9:killed | a_ss_holds, a_ss_to_run +2 |
| `supervisor.156.CTN.2` | negate the term 'latch_state' | 9:killed | a_ss_holds, a_ss_to_run +2 |
| `supervisor.156.CTN.3` | negate the term 'UVLO' | 9:killed | a_ss_holds, a_ss_to_run +2 |
| `supervisor.156.CTN.4` | negate the term 'latch_assert' | 9:killed | a_ss_holds, a_ss_to_run +2 |
| `supervisor.156.LCR.1` | \| -> & | 9:killed | a_hard_fault_to_off |
| `supervisor.156.LCR.2` | \| -> & | 9:killed | a_hard_fault_to_off |
| `supervisor.156.LCR.3` | \| -> & | 9:killed | a_hard_fault_to_off |
| `supervisor.156.LCR.4` | \| -> & | 9:killed | a_hard_fault_to_off |
| `supervisor.156.SIB.1` | latch_state -> latch_assert | 9:killed | a_hard_fault_to_off |
| `supervisor.156.SIB.2` | latch_assert -> latch_state | 9:killed | a_hard_fault_to_off |
| `supervisor.156.UOD.1` | drop the '~' before g_en | 9:killed | a_ss_holds, a_hard_fault_to_off +2 |
| `supervisor.158.ENM.1` | S_OFF -> S_SS | 9:killed | a_hard_fault_to_off |
| `supervisor.158.SDL.1` | delete 'next_state = S_OFF;' | 9:killed | a_hard_fault_to_off |
| `supervisor.161.AIM.16` | In S_SS ramp completion outranks the overcurrent window trip: window_trip_SS is only honoured while SS_done is low | 9:killed | a_ss_to_hiccup |
| `supervisor.161.AIM.30` | In S_SS either overcurrent window trip sends the FSM to S_HICCUP: the run-state trip window_trip is also honoured during soft start | 9:killed | a_ss_holds, a_ss_to_run |
| `supervisor.161.CND.1` | if (window_trip_SS) -> if (!(...)) | 9:killed | a_ss_holds, a_ss_to_run +1 |
| `supervisor.161.CSK.1` | if (window_trip_SS) -> if (1'b0): never taken | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.161.CSK.2` | if (window_trip_SS) -> if (1'b1): always taken | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.161.EDL.1` | delete the else branch at line 161 | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.163.AIM.45` | An overcurrent window trip during soft start only pauses the promotion to S_RUN and keeps the FSM ramping in S_SS, as if high current while the output capacitor charges were expected, instead of sending the converter into the S_HICCUP cool-down | 9:killed | a_ss_to_hiccup |
| `supervisor.163.ENM.1` | S_HICCUP -> S_OFF | 9:killed | a_ss_to_hiccup |
| `supervisor.163.SDL.1` | delete 'next_state = S_HICCUP;' | 9:killed | a_ss_to_hiccup |
| `supervisor.166.CND.1` | if (SS_done) -> if (!(...)) | 9:killed | a_ss_holds, a_ss_to_run |
| `supervisor.166.CSK.1` | if (SS_done) -> if (1'b0): never taken | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.166.CSK.2` | if (SS_done) -> if (1'b1): always taken | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.166.EDL.1` | delete the else branch at line 166 | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.166.SIB.1` | SS_done -> hiccup_done | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.168.ENM.1` | S_RUN -> S_HICCUP | 9:killed | a_ss_to_run |
| `supervisor.168.SDL.1` | delete 'next_state = S_RUN;' | 9:killed | a_ss_to_run |
| `supervisor.173.ENM.1` | S_SS -> S_RUN | 9:killed | a_ss_holds |
| `supervisor.173.SDL.1` | delete 'next_state = S_SS;' | 9:survived |  |
| `supervisor.179.CID.1` | delete the case item 'S_RUN': it takes the default branch | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.179.CIS.1` | case labels S_RUN and S_HICCUP swapped | 9:killed | a_run_holds, a_hiccup_holds +2 |
| `supervisor.181.AIM.15` | In S_RUN only the physical switch is checked for disable: a host disable over SPI gates en but does not send the FSM to S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.181.AIM.18` | In S_RUN the overcurrent window trip outranks a hard fault, so a coincident shutdown goes to S_HICCUP first | 9:killed | a_hard_fault_to_off |
| `supervisor.181.AIM.25` | Over-temperature in S_RUN is treated as a recoverable fault and sent through the S_HICCUP cool-down instead of straight to S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.181.AIM.36` | latch_assert in S_RUN is treated as one more strike and sent to the S_HICCUP cool-down instead of forcing S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.181.AIM.48` | Input undervoltage in S_RUN is treated as a recoverable brown-out under load and sent through the S_HICCUP cool-down instead of straight to S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.181.AIM.50` | In S_RUN only a host disable over SPI is checked: turning off the physical switch gates en but does not send the FSM to S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.181.AIM.62` | Losing the enable in S_RUN is handled like an overcurrent trip and sent through S_HICCUP, as if a disable under load had to cool down before turning off | 9:killed | a_hard_fault_to_off |
| `supervisor.181.AIM.66` | In S_RUN the latch read-back latch_state is treated as a recoverable overshoot from a load step and sent to the S_HICCUP cool-down instead of forcing S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.181.CND.1` | if (~g_en \| latch_state \| OTP \| UVLO \| latch_assert) -> if (!(...)) | 9:killed | a_run_holds, a_run_to_hiccup +1 |
| `supervisor.181.CSK.1` | if (~g_en \| latch_state \| OTP \| UVLO \| latch_assert) -> if (1'b0): never taken | 9:killed | a_hard_fault_to_off |
| `supervisor.181.CSK.2` | if (~g_en \| latch_state \| OTP \| UVLO \| latch_assert) -> if (1'b1): always taken | 9:killed | a_run_holds, a_run_to_hiccup |
| `supervisor.181.CTD.1` | drop the term '~g_en' | 9:killed | a_hard_fault_to_off |
| `supervisor.181.CTD.2` | drop the term 'latch_state' | 9:killed | a_hard_fault_to_off |
| `supervisor.181.CTD.3` | drop the term 'OTP' | 9:killed | a_hard_fault_to_off |
| `supervisor.181.CTD.4` | drop the term 'UVLO' | 9:killed | a_hard_fault_to_off |
| `supervisor.181.CTD.5` | drop the term 'latch_assert' | 9:killed | a_hard_fault_to_off |
| `supervisor.181.CTN.1` | negate the term 'latch_state' | 9:killed | a_run_holds, a_run_to_hiccup +1 |
| `supervisor.181.CTN.2` | negate the term 'OTP' | 9:killed | a_run_holds, a_run_to_hiccup +1 |
| `supervisor.181.CTN.3` | negate the term 'UVLO' | 9:killed | a_run_holds, a_run_to_hiccup +1 |
| `supervisor.181.CTN.4` | negate the term 'latch_assert' | 9:killed | a_run_holds, a_run_to_hiccup +1 |
| `supervisor.181.LCR.1` | \| -> & | 9:killed | a_hard_fault_to_off |
| `supervisor.181.LCR.2` | \| -> & | 9:killed | a_hard_fault_to_off |
| `supervisor.181.LCR.3` | \| -> & | 9:killed | a_hard_fault_to_off |
| `supervisor.181.LCR.4` | \| -> & | 9:killed | a_hard_fault_to_off |
| `supervisor.181.SIB.1` | latch_state -> latch_assert | 9:killed | a_hard_fault_to_off |
| `supervisor.181.SIB.2` | latch_assert -> latch_state | 9:killed | a_hard_fault_to_off |
| `supervisor.181.UOD.1` | drop the '~' before g_en | 9:killed | a_run_holds, a_run_to_hiccup +1 |
| `supervisor.183.ENM.1` | S_OFF -> S_SS | 9:killed | a_hard_fault_to_off |
| `supervisor.183.SDL.1` | delete 'next_state = S_OFF;' | 9:killed | a_hard_fault_to_off |
| `supervisor.186.AIM.24` | In S_RUN either overcurrent window trip sends the FSM to S_HICCUP: the soft-start trip window_trip_SS is honoured outside S_SS | 9:killed | a_run_holds |
| `supervisor.186.CND.1` | if (window_trip) -> if (!(...)) | 9:killed | a_run_holds, a_run_to_hiccup |
| `supervisor.186.CSK.1` | if (window_trip) -> if (1'b0): never taken | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.186.CSK.2` | if (window_trip) -> if (1'b1): always taken | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.186.EDL.1` | delete the else branch at line 186 | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.188.AIM.9` | An overcurrent window trip in S_RUN re-ramps straight into S_SS instead of first serving the S_HICCUP cool-down | 9:killed | a_run_to_hiccup |
| `supervisor.188.ENM.1` | S_HICCUP -> S_OFF | 9:killed | a_run_to_hiccup |
| `supervisor.188.SDL.1` | delete 'next_state = S_HICCUP;' | 9:killed | a_run_to_hiccup |
| `supervisor.190.AIM.32` | S_RUN is treated as valid only while the soft-start handshake SS_done is held, and drops back to S_SS when SS_done falls | 9:killed | a_run_holds |
| `supervisor.193.ENM.1` | S_RUN -> S_HICCUP | 9:killed | a_run_holds |
| `supervisor.193.SDL.1` | delete 'next_state = S_RUN;' | 9:survived |  |
| `supervisor.199.CID.1` | delete the case item 'S_HICCUP': it takes the default branch | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.201.AIM.19` | In S_HICCUP the end of the cool-down outranks a hard fault, so a retry into S_SS wins over a shutdown | 9:killed | a_hard_fault_to_off |
| `supervisor.201.AIM.39` | In S_HICCUP latch_assert only blocks the retry instead of forcing S_OFF, as if a strike-latched converter just stayed in the cool-down | 9:killed | a_hard_fault_to_off |
| `supervisor.201.AIM.40` | Over-temperature during S_HICCUP is treated as part of the cool-down: the FSM stays in S_HICCUP until OTP clears instead of going to S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.201.AIM.47` | In S_HICCUP only the physical switch is checked for disable, so a host disable over SPI during the cool-down does not send the FSM to S_OFF and it still retries into S_SS | 9:killed | a_hard_fault_to_off |
| `supervisor.201.AIM.56` | In S_HICCUP only a host disable over SPI is checked: turning off the physical switch during the cool-down does not send the FSM to S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.201.AIM.57` | Losing the enable during the cool-down only holds off the retry: the FSM waits in S_HICCUP until it is re-enabled instead of going to S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.201.AIM.58` | Input undervoltage during the cool-down is treated as extending the cool-down: the FSM stays in S_HICCUP until UVLO clears instead of going to S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.201.AIM.67` | In S_HICCUP the latch read-back latch_state only holds off the retry, as if the latch were left over from the fault being cooled down, instead of forcing S_OFF | 9:killed | a_hard_fault_to_off |
| `supervisor.201.AIM.72` | The disable test in S_HICCUP uses the gated gate-drive enable en instead of the converter enable g_en, so the cool-down's own gate-drive-off reads as a disable | 9:killed | a_hiccup_holds, a_hiccup_to_ss |
| `supervisor.201.CND.1` | if (~g_en \| latch_state \| OTP \| latch_assert \| UVLO) -> if (!(...)) | 9:killed | a_hiccup_holds, a_hard_fault_to_off +1 |
| `supervisor.201.CSK.1` | if (~g_en \| latch_state \| OTP \| latch_assert \| UVLO) -> if (1'b0): never taken | 9:killed | a_hard_fault_to_off |
| `supervisor.201.CSK.2` | if (~g_en \| latch_state \| OTP \| latch_assert \| UVLO) -> if (1'b1): always taken | 9:killed | a_hiccup_holds, a_hiccup_to_ss |
| `supervisor.201.CTD.1` | drop the term '~g_en' | 9:killed | a_hard_fault_to_off |
| `supervisor.201.CTD.2` | drop the term 'latch_state' | 9:killed | a_hard_fault_to_off |
| `supervisor.201.CTD.3` | drop the term 'OTP' | 9:killed | a_hard_fault_to_off |
| `supervisor.201.CTD.4` | drop the term 'latch_assert' | 9:killed | a_hard_fault_to_off |
| `supervisor.201.CTD.5` | drop the term 'UVLO' | 9:killed | a_hard_fault_to_off |
| `supervisor.201.CTN.1` | negate the term 'latch_state' | 9:killed | a_hiccup_holds, a_hard_fault_to_off +1 |
| `supervisor.201.CTN.2` | negate the term 'OTP' | 9:killed | a_hiccup_holds, a_hard_fault_to_off +1 |
| `supervisor.201.CTN.3` | negate the term 'latch_assert' | 9:killed | a_hiccup_holds, a_hard_fault_to_off +1 |
| `supervisor.201.CTN.4` | negate the term 'UVLO' | 9:killed | a_hiccup_holds, a_hard_fault_to_off +1 |
| `supervisor.201.LCR.1` | \| -> & | 9:killed | a_hard_fault_to_off |
| `supervisor.201.LCR.2` | \| -> & | 9:killed | a_hard_fault_to_off |
| `supervisor.201.LCR.3` | \| -> & | 9:killed | a_hard_fault_to_off |
| `supervisor.201.LCR.4` | \| -> & | 9:killed | a_hard_fault_to_off |
| `supervisor.201.SIB.1` | latch_state -> latch_assert | 9:killed | a_hard_fault_to_off |
| `supervisor.201.SIB.2` | latch_assert -> latch_state | 9:killed | a_hard_fault_to_off |
| `supervisor.201.UOD.1` | drop the '~' before g_en | 9:killed | a_hiccup_holds, a_hard_fault_to_off +1 |
| `supervisor.203.ENM.1` | S_OFF -> S_SS | 9:killed | a_hard_fault_to_off |
| `supervisor.203.SDL.1` | delete 'next_state = S_OFF;' | 9:killed | a_hard_fault_to_off |
| `supervisor.206.AIM.31` | S_HICCUP retries only when the cool-down has elapsed and the run overcurrent trip has also cleared, as if a retry had to wait for the fault to go away | 9:killed | a_hiccup_to_ss |
| `supervisor.206.CND.1` | if (hiccup_done) -> if (!(...)) | 9:killed | a_hiccup_holds, a_hiccup_to_ss |
| `supervisor.206.CSK.1` | if (hiccup_done) -> if (1'b0): never taken | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.206.CSK.2` | if (hiccup_done) -> if (1'b1): always taken | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.206.EDL.1` | delete the else branch at line 206 | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.206.SIB.1` | hiccup_done -> SS_done | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.206.SIB.2` | hiccup_done -> hiccup_active | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.208.AIM.10` | At the end of the cool-down S_HICCUP returns to S_OFF and relies on S_OFF to restart, instead of retrying directly into S_SS | 9:killed | a_hiccup_to_ss |
| `supervisor.208.AIM.26` | At the end of the cool-down S_HICCUP retries straight into S_RUN when the soft-start handshake SS_done is still high, skipping the re-ramp | 9:killed | a_hiccup_to_ss |
| `supervisor.208.ENM.1` | S_SS -> S_RUN | 9:killed | a_hiccup_to_ss |
| `supervisor.208.SDL.1` | delete 'next_state = S_SS;' | 9:killed | a_hiccup_to_ss |
| `supervisor.213.ENM.1` | S_HICCUP -> S_OFF | 9:killed | a_hiccup_holds |
| `supervisor.213.SDL.1` | delete 'next_state = S_HICCUP;' | 9:survived |  |
| `supervisor.220.ENM.1` | S_OFF -> S_SS | 9:survived |  |
| `supervisor.220.SDL.1` | delete 'next_state = S_OFF;' | 9:survived |  |
| `supervisor.236.AIM.4` | The power-stage enable is decoded from next_state instead of the registered state | 9:killed | a_en_only_in_ss_or_run, a_en_high_when_allowed |
| `supervisor.237.AIM.29` | The gate drive is enabled in S_OFF as soon as the converter is enabled, a clock before the FSM has registered S_SS | 9:killed | a_en_only_in_ss_or_run |
| `supervisor.237.CID.1` | delete the case item 'S_OFF': it takes the default branch | 9:survived |  |
| `supervisor.237.CIS.1` | case labels S_OFF and S_SS swapped | 9:killed | a_en_only_in_ss_or_run, a_en_high_when_allowed |
| `supervisor.237.CST.1` | 1'b0 -> 1'b1 | 9:killed | a_en_only_in_ss_or_run |
| `supervisor.237.SDL.1` | delete 'en_from_state = 1'b0;' | 9:lint | make lint: LATCH |
| `supervisor.238.AIM.64` | The gate drive in S_SS is decoded as 'ramp still in progress', so it drops on the clock the ramp reports SS_done, before the FSM has registered S_RUN | 9:killed | a_en_high_when_allowed |
| `supervisor.238.CID.1` | delete the case item 'S_SS': it takes the default branch | 9:killed | a_en_high_when_allowed |
| `supervisor.238.CIS.1` | case labels S_SS and S_RUN swapped | 9:survived |  |
| `supervisor.238.CST.1` | 1'b1 -> 1'b0 | 9:killed | a_en_high_when_allowed |
| `supervisor.238.SDL.1` | delete 'en_from_state = 1'b1;' | 9:lint | make lint: LATCH |
| `supervisor.239.AIM.69` | In S_RUN the gate drive is made to depend on the soft-start handshake SS_done, as if regulation were allowed to switch only while the ramp still reports done | 9:killed | a_en_high_when_allowed |
| `supervisor.239.CID.1` | delete the case item 'S_RUN': it takes the default branch | 9:killed | a_en_high_when_allowed |
| `supervisor.239.CIS.1` | case labels S_RUN and S_HICCUP swapped | 9:killed | a_en_high_when_allowed, a_en_only_in_ss_or_run |
| `supervisor.239.CST.1` | 1'b1 -> 1'b0 | 9:killed | a_en_high_when_allowed |
| `supervisor.239.SDL.1` | delete 'en_from_state = 1'b1;' | 9:lint | make lint: LATCH |
| `supervisor.240.AIM.28` | The gate drive is re-enabled on the clock hiccup_done rises in S_HICCUP, a clock before the FSM has registered the retry into S_SS | 9:killed | a_en_only_in_ss_or_run |
| `supervisor.240.CID.1` | delete the case item 'S_HICCUP': it takes the default branch | 9:survived |  |
| `supervisor.240.CST.1` | 1'b0 -> 1'b1 | 9:killed | a_en_only_in_ss_or_run |
| `supervisor.240.SDL.1` | delete 'en_from_state = 1'b0;' | 9:lint | make lint: LATCH |
| `supervisor.241.CST.1` | 1'b0 -> 1'b1 | 9:survived |  |
| `supervisor.241.SDL.1` | delete 'en_from_state = 1'b0;' | 9:survived |  |
| `supervisor.257.AIM.34` | ss_active is decoded as 'power stage may switch', so it is also high in S_RUN | 9:killed | a_ss_active_decode |
| `supervisor.257.AIM.43` | ss_active is raised on the clock the cool-down reports hiccup_done, a clock before the FSM has registered the retry into S_SS | 9:killed | a_ss_active_decode |
| `supervisor.257.AIM.59` | ss_active is decoded as 'a soft-start sequence is under way', so it is also high during the S_HICCUP cool-down that leads into the re-ramp | 9:killed | a_ss_active_decode |
| `supervisor.257.AIM.68` | ss_active is raised in S_OFF as soon as the converter is enabled, as a start request to soft start, a clock before the FSM has registered S_SS | 9:killed | a_ss_active_decode |
| `supervisor.257.AIM.73` | ss_active is decoded as 'ramping with the gate drive on', so the combinational fault gating of en also drops it before the FSM leaves S_SS | 9:killed | a_ss_active_decode |
| `supervisor.257.AIM.8` | ss_active is dropped as soon as the ramp reports done, a clock before the FSM leaves S_SS | 9:killed | a_ss_active_decode |
| `supervisor.257.ENM.1` | S_SS -> S_RUN | 9:killed | a_ss_active_decode |
| `supervisor.257.ROR.1` | == -> != | 9:killed | a_ss_active_decode |
| `supervisor.257.SDL.1` | delete 'ss_active = (state == S_SS);' | 9:lint | make lint: UNDRIVEN |
| `supervisor.257.SIB.1` | assigns to hiccup_active instead of ss_active | 9:lint | make lint: UNDRIVEN |
| `supervisor.257.SIB.2` | assigns to run_active instead of ss_active | 9:lint | make lint: UNDRIVEN |
| `supervisor.257.STK.1` | ss_active stuck at all-zeros (was '(state == S_SS)') | 9:killed | a_ss_active_decode |
| `supervisor.257.STK.2` | ss_active stuck at all-ones (was '(state == S_SS)') | 9:killed | a_ss_active_decode |
| `supervisor.257.VNG.1` | ss_active inverted (was '(state == S_SS)') | 9:killed | a_ss_active_decode |
| `supervisor.258.AIM.12` | run_active is taken as 'regulating and gate drive on', so the combinational fault gating of en also drops it | 9:killed | a_run_active_decode |
| `supervisor.258.AIM.42` | run_active is raised on the clock the ramp reports SS_done, a clock before the FSM has registered S_RUN | 9:killed | a_run_active_decode |
| `supervisor.258.AIM.6` | run_active is decoded as 'power stage switching' and so is also high in S_SS | 9:killed | a_run_active_decode |
| `supervisor.258.AIM.60` | run_active treats the hiccup cool-down as a pause inside regulation, so it is also high in S_HICCUP | 9:killed | a_run_active_decode |
| `supervisor.258.ENM.1` | S_RUN -> S_HICCUP | 9:killed | a_run_active_decode |
| `supervisor.258.ROR.1` | == -> != | 9:killed | a_run_active_decode |
| `supervisor.258.SDL.1` | delete 'run_active = (state == S_RUN);' | 9:lint | make lint: UNDRIVEN |
| `supervisor.258.SIB.1` | assigns to hiccup_active instead of run_active | 9:lint | make lint: UNDRIVEN |
| `supervisor.258.SIB.2` | assigns to ss_active instead of run_active | 9:lint | make lint: UNDRIVEN |
| `supervisor.258.STK.1` | run_active stuck at all-zeros (was '(state == S_RUN)') | 9:killed | a_run_active_decode |
| `supervisor.258.STK.2` | run_active stuck at all-ones (was '(state == S_RUN)') | 9:killed | a_run_active_decode |
| `supervisor.258.VNG.1` | run_active inverted (was '(state == S_RUN)') | 9:killed | a_run_active_decode |
| `supervisor.259.AIM.11` | hiccup_active is decoded from next_state, so it leads the registered S_HICCUP state by one clock | 9:killed | a_hiccup_active_decode |
| `supervisor.259.AIM.13` | hiccup_active is decoded as 'power stage held off by the state', so it is also high in S_OFF | 9:killed | a_hiccup_active_decode |
| `supervisor.259.AIM.22` | hiccup_active is dropped as soon as the cool-down reports done, a clock before the FSM leaves S_HICCUP | 9:killed | a_hiccup_active_decode |
| `supervisor.259.AIM.44` | hiccup_active is held until the cool-down timer drops hiccup_done, as if leaving S_HICCUP had to wait for the timer's acknowledge | 9:killed | a_hiccup_active_decode |
| `supervisor.259.AIM.61` | hiccup_active is decoded as 'a hiccup retry is in progress', so it also covers the re-ramp in S_SS, including the first start from S_OFF | 9:killed | a_hiccup_active_decode |
| `supervisor.259.AIM.74` | hiccup_active is decoded as 'cool-down still running', so a hard fault or disable drops it combinationally before the FSM leaves S_HICCUP | 9:killed | a_hiccup_active_decode |
| `supervisor.259.ENM.1` | S_HICCUP -> S_OFF | 9:killed | a_hiccup_active_decode |
| `supervisor.259.ROR.1` | == -> != | 9:killed | a_hiccup_active_decode |
| `supervisor.259.SDL.1` | delete 'hiccup_active = (state == S_HICCUP);' | 9:lint | make lint: UNDRIVEN |
| `supervisor.259.SIB.1` | assigns to run_active instead of hiccup_active | 9:lint | make lint: UNDRIVEN |
| `supervisor.259.STK.1` | hiccup_active stuck at all-zeros (was '(state == S_HICCUP)') | 9:killed | a_hiccup_active_decode |
| `supervisor.259.STK.2` | hiccup_active stuck at all-ones (was '(state == S_HICCUP)') | 9:killed | a_hiccup_active_decode |
| `supervisor.259.VNG.1` | hiccup_active inverted (was '(state == S_HICCUP)') | 9:killed | a_hiccup_active_decode |
| `supervisor.260.AIM.5` | Telemetry state_out shows the next state instead of the present registered state | 9:killed | a_ss_active_decode, a_en_high_when_allowed +6 |
| `supervisor.260.AIM.52` | Telemetry state_out reports S_OFF as soon as a hard fault gates en, instead of the registered present state | 9:killed | a_ss_active_decode, a_off_to_ss +4 |
| `supervisor.260.AIM.65` | Telemetry state_out reports the hiccup cool-down as S_OFF, because the power stage is off in both, instead of the registered present state | 9:killed | a_hiccup_active_decode, a_run_to_hiccup +2 |
| `supervisor.260.AIM.77` | Telemetry state_out reports S_RUN as soon as the ramp reports SS_done, instead of the registered present state | 9:killed | a_ss_active_decode, a_run_active_decode +4 |
| `supervisor.260.SDL.1` | delete 'state_out = state;' | 9:lint | make lint: UNDRIVEN |
| `supervisor.265.AIM.79` | The LM5106 enable en is registered to give a glitch-free gate drive, so it follows the state and the fault inputs one clock late | 9:killed | a_en_high_when_allowed, a_hard_fault_holds_en_low +1 |
| `supervisor.275.AIM.14` | The overcurrent window trips are treated as hard fault inputs in the combinational gating of en | 9:killed | a_en_high_when_allowed |
| `supervisor.275.AIM.21` | The combinational en gating uses the physical switch alone, so a host disable over SPI waits for the FSM to reach S_OFF | 9:killed | a_hard_fault_holds_en_low |
| `supervisor.275.AIM.51` | The combinational en gating applies only the host enable, so turning off the physical switch waits for the FSM to register S_OFF | 9:killed | a_hard_fault_holds_en_low |
| `supervisor.275.AIM.7` | The gate-drive enable relies on the state alone for the hard faults, dropping the combinational fault gating | 9:killed | a_hard_fault_holds_en_low |
| `supervisor.275.CTD.1` | drop the term 'g_en' | 9:killed | a_hard_fault_holds_en_low |
| `supervisor.275.CTD.2` | drop the term 'en_from_state' | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.275.CTD.3` | drop the term '~OTP' | 9:killed | a_hard_fault_holds_en_low |
| `supervisor.275.CTD.4` | drop the term '~latch_state' | 9:killed | a_hard_fault_holds_en_low |
| `supervisor.275.CTD.5` | drop the term '~UVLO' | 9:killed | a_hard_fault_holds_en_low |
| `supervisor.275.CTD.6` | drop the term '~latch_assert' | 9:killed | a_hard_fault_holds_en_low |
| `supervisor.275.CTN.1` | negate the term 'g_en' | 9:killed | a_en_high_when_allowed, a_hard_fault_holds_en_low |
| `supervisor.275.CTN.2` | negate the term 'en_from_state' | 9:killed | a_en_only_in_ss_or_run, a_en_high_when_allowed |
| `supervisor.275.LCR.1` | & -> \| | 9:killed | a_hard_fault_holds_en_low, a_en_only_in_ss_or_run |
| `supervisor.275.LCR.2` | & -> \| | 9:killed | a_reset_means_off, a_hard_fault_holds_en_low +1 |
| `supervisor.275.LCR.3` | & -> \| | 9:killed | a_reset_means_off, a_hard_fault_holds_en_low +1 |
| `supervisor.275.LCR.4` | & -> \| | 9:killed | a_reset_means_off, a_hard_fault_holds_en_low +1 |
| `supervisor.275.LCR.5` | & -> \| | 9:killed | a_reset_means_off, a_hard_fault_holds_en_low +1 |
| `supervisor.275.SDL.1` | delete 'en = g_en & en_from_state & ~OTP & ~latch_state & ~UVLO & ~l' | 9:lint | make lint: UNDRIVEN, UNUSEDSIGNAL |
| `supervisor.275.SIB.1` | latch_state -> latch_assert | 9:killed | a_hard_fault_holds_en_low |
| `supervisor.275.SIB.2` | latch_assert -> latch_state | 9:killed | a_hard_fault_holds_en_low |
| `supervisor.275.STK.1` | en stuck at all-zeros (was 'g_en & en_from_state & ~OTP & ~latch_sta') | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.275.STK.2` | en stuck at all-ones (was 'g_en & en_from_state & ~OTP & ~latch_sta') | 9:lint | make lint: UNUSEDSIGNAL |
| `supervisor.275.UOD.1` | drop the '~' before OTP | 9:killed | a_en_high_when_allowed, a_hard_fault_holds_en_low |
| `supervisor.275.UOD.2` | drop the '~' before latch_state | 9:killed | a_en_high_when_allowed, a_hard_fault_holds_en_low |
| `supervisor.275.UOD.3` | drop the '~' before UVLO | 9:killed | a_en_high_when_allowed, a_hard_fault_holds_en_low |
| `supervisor.275.UOD.4` | drop the '~' before latch_assert | 9:killed | a_en_high_when_allowed, a_hard_fault_holds_en_low |
| `supervisor.275.VNG.1` | en inverted (was 'g_en & en_from_state & ~OTP & ~latch_sta') | 9:killed | a_reset_means_off, a_hard_fault_holds_en_low +2 |
| `supervisor.88.AIM.41` | The host enable over SPI is treated as a start request checked only in S_OFF, so a host disable while ramping, running or in hiccup is ignored | not run (withdrawn at step 7) |  |
| `supervisor.88.AIM.76` | The physical switch en_SW is treated as a start request checked only in S_OFF, so turning it off while ramping, running or in hiccup is ignored | not run (withdrawn at step 7) |  |
| `supervisor.201.AIM.1` | S_HICCUP has no hard-fault exit: the designer relied on the gate drive already being off and only waits for hiccup_done | not run (withdrawn at step 8) |  |
