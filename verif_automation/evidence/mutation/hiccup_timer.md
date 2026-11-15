# Mutation record: hiccup_timer

`rtl-systemverilog/protect/hiccup_timer.sv`. Written by `tools/mutation/record.py` from `hiccup_timer.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 43 | 27 | 11 | 0 | 0 | 5 | 0 | 0 | 88.4% |
| AI-written | 12 | 11 | 0 | 0 | 0 | 1 | 0 | 0 | 91.7% |
| all | 55 | 38 | 11 | 0 | 0 | 6 | 0 | 0 | 89.1% |

Survivors: 6 - 5 decided equivalent, 0 accepted, 1 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 98.0%.

## Survivors (6)

### `hiccup_timer.56.AIM.1` - The cast to TIMER_W is applied after the shift, so base_clks << strike_level is evaluated at HICCUP_BASE_W width and its top bits are lost before widening

- before: `cool_down_target = TIMER_W'(base_clks)<<strike_level;`
- after: `cool_down_target = TIMER_W'(base_clks<<strike_level);`
- AI judgement (step 8): **plausible**, high confidence - Moving the cast inside the shift on line 56 can change how wide the shift is evaluated. Depending on the tool's sizing rules, the top bits of base_clks<<strike_level can be lost at HICCUP_BASE_W, which gives a smaller cool_down_target and changes when line 96 matches and hiccup_done rises.
- designer's decision (step 10): **equivalent** - a size cast evaluates its operand in an assignment context of the cast width (IEEE 1800 6.24.1), so the shift is TIMER_W wide either way; sv2v renders the cast as a function with a TIMER_W input, same result

### `hiccup_timer.85.SDL.1` - delete 'hiccup_done <= 0;'

- before: `hiccup_done <= 0;`
- after: `;`
- AI judgement (step 8): **plausible**, high confidence - Without line 85, the asynchronous reset no longer clears hiccup_done. At power-up it stays X, and a reset that arrives while it is 1 leaves it at 1, which shows on the output port.
- designer's decision (step 11): **gap** - hiccup_done reset untested: the testbench resets only at time zero, where a two-state simulator already holds 0; needs a reset applied while hiccup_done is 1

### `hiccup_timer.99.SDL.1` - delete 'cool_counter <= cool_counter;'

- before: `cool_counter <= cool_counter;   // hold`
- after: `;   // hold`
- AI judgement (step 8): **equivalent**, high confidence - Line 99 assigns cool_counter to itself inside an always_ff. Removing it leaves cool_counter unassigned on that path, so the flop keeps its value anyway and nothing changes.
- designer's decision (step 9): **equivalent** - line 99 runs only as hiccup_done is set; hiccup_done then stays 1 until reset or leaving S_HICCUP, both of which also clear cool_counter; cool_counter is not a port, so its held value never reaches an output

### `hiccup_timer.99.STK.1` - cool_counter stuck at all-zeros (was 'cool_counter')

- before: `cool_counter <= cool_counter;   // hold`
- after: `cool_counter <= '0;   // hold`
- AI judgement (step 8): **equivalent**, high confidence - Line 99 only runs in the same branch where line 98 sets hiccup_done to 1, so the first match happens at the same time as before. After that, hiccup_done can only be cleared by reset or !hiccup_active (lines 85 and 91), and both also clear cool_counter (lines 84 and 92). cool_counter is not a port, so the different value it holds until then is never seen, and hiccup_done is the only output.
- designer's decision (step 9): **equivalent** - line 99 runs only as hiccup_done is set; hiccup_done then stays 1 until reset or leaving S_HICCUP, both of which also clear cool_counter; cool_counter is not a port, so its held value never reaches an output

### `hiccup_timer.99.STK.2` - cool_counter stuck at all-ones (was 'cool_counter')

- before: `cool_counter <= cool_counter;   // hold`
- after: `cool_counter <= '1;   // hold`
- AI judgement (step 8): **equivalent**, high confidence - Line 99 only runs as hiccup_done is set to 1 on line 98, and hiccup_done stays 1 until reset or !hiccup_active, which also clear cool_counter (lines 84 and 92). Setting the internal counter to all-ones in between, or letting it wrap from there, never changes hiccup_done, the only output.
- designer's decision (step 9): **equivalent** - line 99 runs only as hiccup_done is set; hiccup_done then stays 1 until reset or leaving S_HICCUP, both of which also clear cool_counter; cool_counter is not a port, so its held value never reaches an output

### `hiccup_timer.99.VNG.1` - cool_counter inverted (was 'cool_counter')

- before: `cool_counter <= cool_counter;   // hold`
- after: `cool_counter <= ~(cool_counter);   // hold`
- AI judgement (step 8): **equivalent**, high confidence - The inverted counter on line 99 is written only once hiccup_done has been set to 1 (line 98). hiccup_done cannot drop until reset or !hiccup_active (lines 82-92), and those branches also set cool_counter to 0, so the changed counter never reaches the output.
- designer's decision (step 9): **equivalent** - line 99 runs only as hiccup_done is set; hiccup_done then stays 1 until reset or leaving S_HICCUP, both of which also clear cool_counter; cool_counter is not a port, so its held value never reaches an output

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-15 14:20 | a1dc229 | AI wrote mutants (claude-opus-5-5) | asked 8, proposed 6, accepted 5, rejected 1; `ai_runs/2026-11-15_write_mutants_4` |
| 2 | 2026-11-15 14:22 | a1dc229 | AI wrote mutants (claude-opus-5-5) | asked 8, proposed 3, accepted 2, rejected 1; `ai_runs/2026-11-15_write_mutants_5` |
| 3 | 2026-11-15 14:24 | a1dc229 | AI wrote mutants (claude-opus-5-5) | asked 8, proposed 1, accepted 1, rejected 0; `ai_runs/2026-11-15_write_mutants_6` |
| 4 | 2026-11-15 14:26 | a1dc229 | AI wrote mutants (claude-opus-5-5) | asked 8, proposed 3, accepted 2, rejected 1; `ai_runs/2026-11-15_write_mutants_7` |
| 5 | 2026-11-15 14:29 | a1dc229 | AI wrote mutants (claude-opus-5-5) | asked 8, proposed 2, accepted 1, rejected 1; `ai_runs/2026-11-15_write_mutants_8` |
| 6 | 2026-11-15 14:31 | a1dc229 | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 2, accepted 1, rejected 1; `ai_runs/2026-11-15_write_mutants_9` |
| 7 | 2026-11-15 14:38 | a1dc229 | mutation run - every mutant of the module | 55 mutants: 38 killed, 11 lint, 6 survived; score 89.1% |
| 8 | 2026-11-15 14:38 | a1dc229 | AI judged survivors (claude-opus-5-5) | 6 judged, 4 called equivalent with high confidence; `ai_runs/2026-11-15_judge_survivors_2` |
| 9 | 2026-11-15 14:42 | a1dc229 | designer's decision: equivalent | hiccup_timer.99.SDL.1, hiccup_timer.99.STK.1, hiccup_timer.99.STK.2, hiccup_timer.99.VNG.1 - line 99 runs only as hiccup_done is set; hiccup_done then stays 1 until reset or leaving S_HICCUP, both of which also clear cool_counter; cool_counter is not a port, so its held value never reaches an output |
| 10 | 2026-11-15 14:42 | a1dc229 | designer's decision: equivalent | hiccup_timer.56.AIM.1 - a size cast evaluates its operand in an assignment context of the cast width (IEEE 1800 6.24.1), so the shift is TIMER_W wide either way; sv2v renders the cast as a function with a TIMER_W input, same result |
| 11 | 2026-11-15 14:42 | a1dc229 | designer's decision: gap | hiccup_timer.85.SDL.1 - hiccup_done reset untested: the testbench resets only at time zero, where a two-state simulator already holds 0; needs a reset applied while hiccup_done is 1 |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (12)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | boundary | The cast to TIMER_W is applied after the shift, so base_clks << strike_level is evaluated at HICCUP_BASE_W width and its top bits are lost before widening | survived |  |
| 2 | 1 | boundary | Strike numbering misremembered as 1-based: the interval is base_clks doubled once even at strike level 0 | killed | a_done_on_time, a_done_not_early |
| 3 | 1 | other | Escalation made linear (base * (level+1)) instead of doubling per strike | killed | a_done_not_early |
| 4 | 1 | reset_init | The counter and flag are cleared on leaving S_HICCUP only if the cool-down had finished; an early exit (g_en low, UVLO, OTP) leaves the counter running | killed | a_done_not_early, a_done_cleared_outside |
| 5 | 1 | sequencing | hiccup_done is raised when the counter is about to reach the target instead of when it has reached it | killed | a_done_not_early |
| 6 | 2 | other | The shift subtracts one strike to make up for strike_counter incrementing on entry, so a cool-down at strike level L lasts base_clks<<(L-1): the first hiccup gets the base interval and every later one gets half its intended length | killed | a_done_on_time, a_done_not_early |
| 7 | 2 | reset_init | Outside S_HICCUP the counter is parked at the live target instead of being cleared to zero (a misreading of 'held at target rather than reset'), so every cool-down starts already finished | killed | a_done_not_early |
| 8 | 3 | sequencing | The cool-down is treated as finished only once the counter has gone past the target instead of reaching it, so the counter runs on to target+1 and hiccup_done is raised one clock late | killed | a_done_on_time, a_done_not_early |
| 9 | 4 | boundary | The escalation is capped one strike early: the shift saturates at MAX_STRIKES_DEFAULT-2 instead of following strike_level up to the level the timer was sized for | killed | a_done_not_early |
| 10 | 4 | priority | The interval-reached test wins over the leave-S_HICCUP clear, so a cool-down that finished is not re-armed when the supervisor leaves S_HICCUP | killed | a_done_cleared_outside |
| 11 | 5 | boundary | 'Doubles each strike' misread as a shift of two per strike, so the cool-down quadruples with each strike instead of doubling | killed | a_done_on_time, a_done_not_early |
| 12 | 6 | sequencing | On leaving S_HICCUP, hiccup_done is cleared only once the counter has already been re-armed to zero, so the flag is dropped one clock after the counter instead of together with it | killed | a_done_cleared_outside |

Rejected by the gate in step 1 (1):

- The interval-reached check is given priority over the leave-S_HICCUP clear, so a finished cool-down is never re-armed - **too large: replaces 13 lines with 13**

Rejected by the gate in step 2 (1):

- hiccup_done is made a one-clock pulse: on reaching the target the counter re-arms to zero and the counting branch clears the flag, so done is not held until the supervisor leaves S_HICCUP - **changes 7 lines; at most 6**

Rejected by the gate in step 4 (1):

- The per-strike escalation is left out: every cool-down uses base_clks whatever the strike level - **make lint already catches it: make lint: UNUSEDSIGNAL**

Rejected by the gate in step 5 (1):

- The counter and hiccup_done are re-armed when the cool-down finishes instead of when the supervisor leaves S_HICCUP - **make lint already catches it: make lint: UNUSEDSIGNAL**

Rejected by the gate in step 6 (1):

- hiccup_done is cleared on the next entry into S_HICCUP (first active clock with the counter re-armed) instead of on leaving S_HICCUP - **changes 7 lines; at most 6**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `hiccup_timer.56.AIM.1` | The cast to TIMER_W is applied after the shift, so base_clks << strike_level is evaluated at HICCUP_BASE_W width and its top bits are lost before widening | 7:survived |  |
| `hiccup_timer.56.AIM.11` | 'Doubles each strike' misread as a shift of two per strike, so the cool-down quadruples with each strike instead of doubling | 7:killed | a_done_on_time, a_done_not_early |
| `hiccup_timer.56.AIM.2` | Strike numbering misremembered as 1-based: the interval is base_clks doubled once even at strike level 0 | 7:killed | a_done_on_time, a_done_not_early |
| `hiccup_timer.56.AIM.3` | Escalation made linear (base * (level+1)) instead of doubling per strike | 7:killed | a_done_not_early |
| `hiccup_timer.56.AIM.6` | The shift subtracts one strike to make up for strike_counter incrementing on entry, so a cool-down at strike level L lasts base_clks<<(L-1): the first hiccup gets the base interval and every later one gets half its intended length | 7:killed | a_done_on_time, a_done_not_early |
| `hiccup_timer.56.AIM.9` | The escalation is capped one strike early: the shift saturates at MAX_STRIKES_DEFAULT-2 instead of following strike_level up to the level the timer was sized for | 7:killed | a_done_not_early |
| `hiccup_timer.56.SDL.1` | delete 'cool_down_target = TIMER_W'(base_clks)<<strike_level;' | 7:lint | make lint: UNDRIVEN, UNUSEDSIGNAL |
| `hiccup_timer.56.SHF.1` | << -> >> | 7:killed | a_done_not_early, a_done_on_time |
| `hiccup_timer.56.SIB.1` | TIMER_W -> STRIKE_W | 7:lint | make lint: UNUSEDSIGNAL |
| `hiccup_timer.56.STK.1` | cool_down_target stuck at all-zeros (was 'TIMER_W'(base_clks)<<strike_level') | 7:lint | make lint: UNUSEDSIGNAL |
| `hiccup_timer.56.STK.2` | cool_down_target stuck at all-ones (was 'TIMER_W'(base_clks)<<strike_level') | 7:lint | make lint: UNUSEDSIGNAL |
| `hiccup_timer.56.VNG.1` | cool_down_target inverted (was 'TIMER_W'(base_clks)<<strike_level') | 7:killed | a_done_on_time, a_done_not_early |
| `hiccup_timer.61.EDG.1` | posedge clk -> negedge clk | 7:killed | a_done_not_early, a_done_held |
| `hiccup_timer.82.BDL.1` | empty the 2-statement body of the if at line 82 | 7:killed | a_done_not_early |
| `hiccup_timer.82.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 7:killed | a_done_not_early |
| `hiccup_timer.82.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 7:killed | a_done_on_time |
| `hiccup_timer.82.UOD.1` | drop the '!' before rst_n | 7:killed | a_done_on_time |
| `hiccup_timer.84.CST.1` | 0 -> 1 | 7:killed | a_done_not_early |
| `hiccup_timer.84.SDL.1` | delete 'cool_counter <= 0;' | 7:killed | a_done_not_early |
| `hiccup_timer.85.CST.1` | 0 -> 1 | 7:killed | a_reset_done_low |
| `hiccup_timer.85.SDL.1` | delete 'hiccup_done <= 0;' | 7:survived |  |
| `hiccup_timer.89.AIM.10` | The interval-reached test wins over the leave-S_HICCUP clear, so a cool-down that finished is not re-armed when the supervisor leaves S_HICCUP | 7:killed | a_done_cleared_outside |
| `hiccup_timer.89.AIM.4` | The counter and flag are cleared on leaving S_HICCUP only if the cool-down had finished; an early exit (g_en low, UVLO, OTP) leaves the counter running | 7:killed | a_done_not_early, a_done_cleared_outside |
| `hiccup_timer.89.BDL.1` | empty the 2-statement body of the if at line 89 | 7:killed | a_done_cleared_outside, a_done_not_early |
| `hiccup_timer.89.CSK.1` | if (!hiccup_active) -> if (1'b0): never taken | 7:lint | make lint: UNUSEDSIGNAL |
| `hiccup_timer.89.CSK.2` | if (!hiccup_active) -> if (1'b1): always taken | 7:lint | make lint: UNUSEDSIGNAL |
| `hiccup_timer.89.EDL.1` | delete the else branch at line 89 | 7:lint | make lint: UNUSEDSIGNAL |
| `hiccup_timer.89.SIB.1` | hiccup_active -> hiccup_done | 7:lint | make lint: UNUSEDSIGNAL |
| `hiccup_timer.89.UOD.1` | drop the '!' before hiccup_active | 7:killed | a_done_on_time, a_done_cleared_outside +2 |
| `hiccup_timer.91.AIM.12` | On leaving S_HICCUP, hiccup_done is cleared only once the counter has already been re-armed to zero, so the flag is dropped one clock after the counter instead of together with it | 7:killed | a_done_cleared_outside |
| `hiccup_timer.91.CST.1` | 1'b0 -> 1'b1 | 7:killed | a_done_cleared_outside, a_done_not_early |
| `hiccup_timer.91.SDL.1` | delete 'hiccup_done <= 1'b0;' | 7:killed | a_done_cleared_outside |
| `hiccup_timer.92.AIM.7` | Outside S_HICCUP the counter is parked at the live target instead of being cleared to zero (a misreading of 'held at target rather than reset'), so every cool-down starts already finished | 7:killed | a_done_not_early |
| `hiccup_timer.92.CST.1` | 0 -> 1 | 7:killed | a_done_not_early |
| `hiccup_timer.92.SDL.1` | delete 'cool_counter <= 0;' | 7:killed | a_done_not_early, a_done_on_time |
| `hiccup_timer.96.AIM.5` | hiccup_done is raised when the counter is about to reach the target instead of when it has reached it | 7:killed | a_done_not_early |
| `hiccup_timer.96.AIM.8` | The cool-down is treated as finished only once the counter has gone past the target instead of reaching it, so the counter runs on to target+1 and hiccup_done is raised one clock late | 7:killed | a_done_on_time, a_done_not_early |
| `hiccup_timer.96.BDL.1` | empty the 2-statement body of the if at line 96 | 7:killed | a_done_on_time |
| `hiccup_timer.96.CSK.1` | if (cool_counter == cool_down_target) -> if (1'b0): never taken | 7:lint | make lint: UNUSEDSIGNAL |
| `hiccup_timer.96.CSK.2` | if (cool_counter == cool_down_target) -> if (1'b1): always taken | 7:lint | make lint: UNUSEDSIGNAL |
| `hiccup_timer.96.EDL.1` | delete the else branch at line 96 | 7:lint | make lint: UNUSEDSIGNAL |
| `hiccup_timer.96.ROR.1` | == -> != | 7:killed | a_done_not_early |
| `hiccup_timer.98.CST.1` | 1'b1 -> 1'b0 | 7:killed | a_done_on_time |
| `hiccup_timer.98.SDL.1` | delete 'hiccup_done <= 1'b1;' | 7:killed | a_done_on_time |
| `hiccup_timer.99.SDL.1` | delete 'cool_counter <= cool_counter;' | 7:survived |  |
| `hiccup_timer.99.STK.1` | cool_counter stuck at all-zeros (was 'cool_counter') | 7:survived |  |
| `hiccup_timer.99.STK.2` | cool_counter stuck at all-ones (was 'cool_counter') | 7:survived |  |
| `hiccup_timer.99.VNG.1` | cool_counter inverted (was 'cool_counter') | 7:survived |  |
| `hiccup_timer.104.AOR.1` | + -> - | 7:killed | a_done_on_time, a_done_not_early |
| `hiccup_timer.104.CST.1` | 1 -> 0 | 7:killed | a_done_on_time |
| `hiccup_timer.104.CST.2` | 1 -> 2 | 7:killed | a_done_on_time, a_done_not_early |
| `hiccup_timer.104.SDL.1` | delete 'cool_counter <= cool_counter + 1;' | 7:killed | a_done_on_time |
| `hiccup_timer.104.STK.1` | cool_counter stuck at all-zeros (was 'cool_counter + 1') | 7:killed | a_done_on_time |
| `hiccup_timer.104.STK.2` | cool_counter stuck at all-ones (was 'cool_counter + 1') | 7:killed | a_done_on_time, a_done_not_early |
| `hiccup_timer.104.VNG.1` | cool_counter inverted (was 'cool_counter + 1') | 7:killed | a_done_on_time |
