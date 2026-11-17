# Mutation record: soft_start

`rtl-systemverilog/protect/soft_start.sv`. Written by `tools/mutation/record.py` from `soft_start.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 123 | 102 | 16 | 0 | 0 | 5 | 0 | 0 | 95.9% |
| AI-written | 50 | 45 | 1 | 0 | 0 | 4 | 0 | 0 | 92.0% |
| all | 173 | 147 | 17 | 0 | 0 | 9 | 0 | 0 | 94.8% |

Survivors: 9 - 1 decided equivalent, 3 accepted, 5 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 97.0%.
5 earlier mutants are not in these numbers: 5 AI-written ones the designer withdrew, 0 the generator no longer makes because the RTL changed. Their history is kept below.

## Survivors (9)

### `soft_start.44.CST.2` - localparam MIN_ON_CNT: 1 -> 2

- before: `localparam logic [ON_TIME_W-1:0] MIN_ON_CNT = MIN_ON_COUNTS[ON_TIME_W-1:0];`
- after: `localparam logic [ON_TIME_W-1:0] MIN_ON_CNT = MIN_ON_COUNTS[ON_TIME_W-2:0];`
- AI judgement (step 16): **equivalent**, high confidence - With the package values, MIN_ON_COUNTS = (50*240+999)/1000 = 12 and ON_TIME_W = $clog2(83+1) = 7. Bit 6 of 12 is 0, so MIN_ON_COUNTS[5:0] zero-extended to 7 bits is still 12, the same as [6:0]; pmic_top.sv:319 does not override the parameters, so MIN_ON_CNT (line 44) is unchanged.
- designer's decision (step 18): **equivalent** - MIN_ON_COUNTS is 12 and bit 6 of 12 is 0, so [5:0] and [6:0] give the same MIN_ON_CNT; pmic_top does not override the parameter

### `soft_start.62.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if (!rst_n) begin`
- after: `if (1'b0) begin`
- AI judgement (step 16): **plausible**, high confidence - With the asynchronous reset removed, pwm_sync_d is never cleared: it starts as X, or follows pwm_sync on clocks during reset. If pwm_sync is high just before reset releases and ss_active is high at once, pwm_fall (line 88) can fire on the first clock where the original gives 0, which shifts cycle_counter and the ramp steps.
- designer's decision (step 17): **gap** - reset values of pwm_sync_d, cycle_counter and SS_done untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run

### `soft_start.64.SDL.1` - delete 'pwm_sync_d <= 1'b0;'

- before: `pwm_sync_d <= 1'b0;`
- after: `;`
- AI judgement (step 16): **plausible**, high confidence - Without line 64, pwm_sync_d keeps its value from before reset (or X at power-up) instead of 0. A stale 1 makes a false pwm_fall on the first clock after reset if pwm_sync is 0 and ss_active is high, which changes cycle_counter and when max_on_counts steps.
- designer's decision (step 17): **gap** - reset values of pwm_sync_d, cycle_counter and SS_done untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run

### `soft_start.68.AIM.47` - The edge detector's delayed PWM copy is re-armed low outside S_SS, like the rest of the ramp state, instead of always tracking pwm_sync.

- before: `else begin`
- after: `else if (!ss_active) begin /  / pwm_sync_d <= 1'b0; /  / end /  / else begin`
- AI judgement (step 16): **plausible**, high confidence - On the first S_SS clock, pwm_sync_d is 0 in the mutant but holds the previous pwm_sync in the original. If PWM was high before S_SS and falls on that clock, the original sees pwm_fall and the mutant does not, so cycle_counter and step timing (lines 126-154) change.
- designer's decision (step 19): **accepted** - differ only when a PWM fall lands on the first clock of S_SS: the first step window is one switching cycle (about 2.2 us) longer or shorter, and the rest of the ramp is unchanged

### `soft_start.68.AIM.6` - The edge detector's delayed PWM copy is only updated in S_SS, so it holds a stale value from the previous soft start.

- before: `else begin`
- after: `else if (ss_active) begin`
- AI judgement (step 16): **plausible**, high confidence - Outside S_SS, pwm_sync_d stops updating and keeps a stale value, so on the first S_SS clock pwm_fall (line 88) can differ from the original: a missed fall, or a false one. That changes cycle_counter and when max_on_counts steps.
- designer's decision (step 19): **accepted** - differ only when a PWM fall lands on the first clock of S_SS: the first step window is one switching cycle (about 2.2 us) longer or shorter, and the rest of the ramp is unchanged

### `soft_start.115.SDL.1` - delete 'cycle_counter <= '0;'

- before: `cycle_counter <= '0;`
- after: `;`
- AI judgement (step 16): **plausible**, high confidence - Without line 115, reset leaves cycle_counter as it was (X at power-up, or a mid-ramp value). If ss_active goes high right after reset without passing through the clearing branch at line 176, which the header does not rule out, the step timing at lines 128/152 changes.
- designer's decision (step 17): **gap** - reset values of pwm_sync_d, cycle_counter and SS_done untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run

### `soft_start.117.SDL.1` - delete 'SS_done <= 1'b0;'

- before: `SS_done       <= 1'b0;`
- after: `;`
- AI judgement (step 16): **plausible**, high confidence - SS_done is an output port. Without line 117, an asserted SS_done stays 1 through reset instead of going to 0, and starts as X at power-up. Both are directly visible at the port.
- designer's decision (step 17): **gap** - reset values of pwm_sync_d, cycle_counter and SS_done untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run

### `soft_start.128.AIM.52` - The step-window counter wraps at or past its terminal count (the at-or-past form of the target test), while the ceiling-step test still requires the count to equal it.

- before: `if (cycle_counter == cycles_per_step - 1'b1) begin`
- after: `if (cycle_counter >= cycles_per_step - 1'b1) begin`
- AI judgement (step 16): **plausible**, high confidence - cycles_per_step is an input that can drop below the running cycle_counter mid-ramp. The mutant then wraps cycle_counter to 0 at once, while the original counts up to 127 and wraps. The step condition on line 152 then fires at different times, so max_on_counts changes.
- designer's decision (step 21): **accepted** - differs only after cycles_per_step is lowered below the running count mid-ramp: the mutant wraps at once, the original runs to 127 and wraps; both give one slower window, the safe direction

### `soft_start.152.AIM.43` - The ceiling-step test copies the at-or-past (>=) form of the target test, while the step-window counter still wraps only on equality. A cycles_per_step lowered below the running count therefore steps the ceiling on every switching cycle until the counter wraps.

- before: `else if (pwm_fall && (cycle_counter == cycles_per_step - 1'b1)) begin`
- after: `else if (pwm_fall && (cycle_counter >= cycles_per_step - 1'b1)) begin`
- AI judgement (step 16): **plausible**, high confidence - If cycles_per_step is lowered below the running cycle_counter, the mutant's >= test steps max_on_counts on every pwm_fall until the counter wraps. The original's == test does not step. This changes max_on_counts and SS_done timing at the ports.
- designer's decision (step 20): **gap** - no test lowers cycles_per_step below the running count mid-ramp; the mutant then steps the ceiling every switching cycle until the counter wraps, a fast ramp and more inrush; needs a check that the ceiling never steps twice within one programmed window

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-17 10:20 | 743c83a | AI wrote mutants (claude-opus-5-5) | asked 10, proposed 6, accepted 6, rejected 0; `ai_runs/2026-11-17_write_mutants_19` |
| 2 | 2026-11-17 16:16 | 743c83a | AI wrote mutants (claude-opus-5-5) | asked 10, proposed 6, accepted 5, rejected 1; `ai_runs/2026-11-17_write_mutants_20` |
| 3 | 2026-11-17 16:25 | 743c83a | AI wrote mutants (claude-opus-5-5) | asked 10, proposed 5, accepted 5, rejected 0; `ai_runs/2026-11-17_write_mutants_21` |
| 4 | 2026-11-17 16:29 | 743c83a | AI wrote mutants (claude-opus-5-5) | asked 10, proposed 5, accepted 5, rejected 0; `ai_runs/2026-11-17_write_mutants_22` |
| 5 | 2026-11-17 16:40 | 743c83a | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 10, accepted 10, rejected 0; `ai_runs/2026-11-17_write_mutants_23` |
| 6 | 2026-11-17 16:48 | 743c83a | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 8, accepted 8, rejected 0; `ai_runs/2026-11-17_write_mutants_24` |
| 7 | 2026-11-17 16:54 | 743c83a | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 3, accepted 3, rejected 0; `ai_runs/2026-11-17_write_mutants_25` |
| 8 | 2026-11-17 16:58 | 743c83a | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 3, accepted 3, rejected 0; `ai_runs/2026-11-17_write_mutants_26` |
| 9 | 2026-11-17 17:01 | 743c83a | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 4, accepted 4, rejected 0; `ai_runs/2026-11-17_write_mutants_27` |
| 10 | 2026-11-17 17:05 | 743c83a | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 3, accepted 3, rejected 0; `ai_runs/2026-11-17_write_mutants_28` |
| 11 | 2026-11-17 17:12 | 743c83a | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 2, accepted 2, rejected 0; `ai_runs/2026-11-17_write_mutants_29` |
| 12 | 2026-11-17 17:17 | 743c83a | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 1, accepted 1, rejected 0; `ai_runs/2026-11-17_write_mutants_30` |
| 13 | 2026-11-17 17:25 | 743c83a | designer withdrew AI-written mutants | soft_start.145.AIM.9 - AIM.51 and AIM.53 together: SS_done timing is the same as AIM.51 and the clamp timing the same as AIM.53, so any test that kills AIM.51 kills it |
| 14 | 2026-11-17 17:26 | 743c83a | designer withdrew AI-written mutants | soft_start.126.AIM.28, soft_start.148.AIM.44, soft_start.158.AIM.45, soft_start.166.AIM.55 - differ only if the ramp resumes after SS_done is set while still in S_SS, which needs max_on_limit raised in the single S_SS clock before the supervisor leaves on SS_done; before done SS_done is 0 anyway |
| 15 | 2026-11-17 17:40 | 743c83a | mutation run - every mutant of the module | 173 mutants: 147 killed, 17 lint, 9 survived; score 94.8% |
| 16 | 2026-11-17 17:42 | 743c83a | AI judged survivors (claude-opus-5-5) | 9 judged, 1 called equivalent with high confidence; `ai_runs/2026-11-17_judge_survivors_4` |
| 17 | 2026-11-17 17:44 | 743c83a | designer's decision: gap | soft_start.62.CSK.1, soft_start.64.SDL.1, soft_start.115.SDL.1, soft_start.117.SDL.1 - reset values of pwm_sync_d, cycle_counter and SS_done untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run |
| 18 | 2026-11-17 17:44 | 743c83a | designer's decision: equivalent | soft_start.44.CST.2 - MIN_ON_COUNTS is 12 and bit 6 of 12 is 0, so [5:0] and [6:0] give the same MIN_ON_CNT; pmic_top does not override the parameter |
| 19 | 2026-11-17 17:44 | 743c83a | designer's decision: accepted | soft_start.68.AIM.47, soft_start.68.AIM.6 - differ only when a PWM fall lands on the first clock of S_SS: the first step window is one switching cycle (about 2.2 us) longer or shorter, and the rest of the ramp is unchanged |
| 20 | 2026-11-17 17:45 | 743c83a | designer's decision: gap | soft_start.152.AIM.43 - no test lowers cycles_per_step below the running count mid-ramp; the mutant then steps the ceiling every switching cycle until the counter wraps, a fast ramp and more inrush; needs a check that the ceiling never steps twice within one programmed window |
| 21 | 2026-11-17 17:45 | 743c83a | designer's decision: accepted | soft_start.128.AIM.52 - differs only after cycles_per_step is lowered below the running count mid-ramp: the mutant wraps at once, the original runs to 127 and wraps; both give one slower window, the safe direction |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (55)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | wrong_event | The cycle boundary is taken on the rising edge of the PWM instead of the falling edge, so the ceiling steps at the start of a pulse rather than after it. | killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| 2 | 1 | missing_case | A max_on_limit lowered during S_RUN is clamped onto the held ceiling straight away, instead of being left until the next ramp. | killed | a_hold_in_run, a_ceiling_moves_by_known_path |
| 3 | 1 | wrong_event | The ceiling steps on the first switching cycle of each step window instead of its last. | killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| 4 | 1 | reset_init | SS_done is cleared on entry to S_RUN rather than held for all of S_RUN. | killed | a_done_falls_on_exit, a_hold_in_run |
| 5 | 1 | boundary | The look-ahead meant only for SS_done is also used in the target test, so the last step lands as soon as the ceiling is one below the limit, without waiting out its step window. | killed | a_ceiling_moves_by_known_path |
| 6 | 1 | sequencing | The edge detector's delayed PWM copy is only updated in S_SS, so it holds a stale value from the previous soft start. | survived |  |
| 7 | 2 | boundary | The target test checks for equality instead of at-or-past, so a ceiling already above a lowered max_on_limit is never clamped back down (the bug the header says >= was brought in to fix). | killed | a_ceiling_within_limit, a_done_follows_target +1 |
| 8 | 2 | priority | The ramp step is an independent if after the at-target clamp rather than its else branch, so on a step boundary the later step assignment wins over the clamp. | killed | a_ceiling_moves_by_known_path, a_ceiling_within_limit |
| 9 | 2 | wrong_event | The at-target clamp and SS_done are only acted on at a PWM falling edge, as if they were a ceiling update that has to wait for the pulse to end, instead of on any clock. | withdrawn: AIM.51 and AIM.53 together: SS_done timing is the same as AIM.51 and the clamp timing the same as AIM.53, so any test that kills AIM.51 kills it |  |
| 10 | 2 | reset_init | The hold condition also keeps the ceiling while SS_done is set, so a completed ramp is not reset to the floor when the supervisor leaves S_RUN for hiccup or idle. | killed | a_floor_when_idle, a_window_steps_ceiling |
| 11 | 2 | reset_init | Outside S_SS and S_RUN the ceiling is only reset to the floor if the ramp had finished, so a soft start aborted mid-ramp leaves its partial ceiling in place. | killed | a_floor_when_idle |
| 12 | 3 | sequencing | The SS_done look-ahead is tested on every clock below the target instead of only on the clock the last step lands, so SS_done rises as soon as the ceiling is one count below max_on_limit. | killed | a_done_rises_at_target |
| 13 | 3 | sequencing | On the at-target branch SS_done only counts as done when the ceiling already equals the limit, so a ceiling clamped down from above a lowered max_on_limit finishes one clock late. | killed | a_done_follows_target |
| 14 | 3 | reset_init | Outside S_SS and S_RUN the ceiling is reset to the target max_on_limit (a copy of the clamp line) instead of to the MIN_ON_CNT floor. | killed | a_floor_when_idle, a_ceiling_moves_by_known_path |
| 15 | 3 | wrong_event | The step-window counter advances on the PWM rising edge, while the ceiling step is still taken at the falling edge. | killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| 16 | 3 | boundary | The idle re-arm sets the ceiling one count above the MIN_ON_CNT floor, unlike the power-on reset, so a re-ramp starts at the first step instead of the floor. | killed | a_floor_when_idle, a_ceiling_moves_by_known_path |
| 17 | 4 | wrong_event | The cycle-boundary detector is written as a generic any-edge detector, so both the rising and the falling edge of each PWM pulse count as a switching-cycle boundary. | killed | a_ceiling_moves_by_known_path |
| 18 | 4 | wrong_event | The ceiling step is qualified by the PWM being low (the 'pulse is over' level) instead of by the one-clock falling-edge pulse. | killed | a_ceiling_moves_by_known_path |
| 19 | 4 | wrong_event | The return to the floor outside S_SS/S_RUN waits for a PWM falling edge, as if it were a ceiling update that must not land mid-pulse. | killed | a_floor_when_idle, a_window_steps_ceiling |
| 20 | 4 | reset_init | The idle re-arm loads the step-window counter with its terminal count instead of zero, so each soft start begins at the end of a step window. | killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| 21 | 4 | missing_case | The ramp branch is entered in S_RUN as well as S_SS, so the ramp keeps running under the regulating loop instead of the ceiling being held. | killed | a_hold_in_run, a_ceiling_moves_by_known_path |
| 22 | 5 | wrong_event | The ramp branch is gated off once SS_done is set, so the last S_SS clock after the ramp finishes falls through to the idle reset branch. | killed | a_done_follows_target, a_done_falls_on_exit +1 |
| 23 | 5 | missing_case | The at-target clamp is applied only while SS_done is still low, as if finishing the ramp needed acting on only once, so on the last S_SS clock after done the step branch is reachable again. | killed | a_ceiling_moves_by_known_path, a_ceiling_within_limit |
| 24 | 5 | other | In S_RUN the digital ceiling is opened to full scale, leaving only the analog duty clamp, instead of holding the ceiling the ramp reached as a backstop. | killed | a_hold_in_run, a_ceiling_moves_by_known_path |
| 25 | 5 | boundary | At the end of a step window the cycle counter wraps to 1 instead of 0, counting the wrapping cycle as the first of the next window, so every window after the first is one switching cycle short. | killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| 26 | 5 | sequencing | The SS_done look-ahead on a ramp step tests the current ceiling instead of the value about to land, so the last step does not raise SS_done itself. | killed | a_done_with_last_step |
| 27 | 5 | other | In S_RUN SS_done is treated as a live 'ceiling at target' status and recomputed against max_on_limit, instead of being held as the latched end of the ramp. | killed | a_done_falls_on_exit, a_hold_in_run |
| 28 | 5 | wrong_event | The step-window counter only runs while a ramp step is still owed, not on every switching cycle of S_SS as the design says, so it freezes once the ceiling reaches the target. | withdrawn: differ only if the ramp resumes after SS_done is set while still in S_SS, which needs max_on_limit raised in the single S_SS clock before the supervisor leaves on SS_done; before done SS_done is 0 anyway |  |
| 29 | 5 | missing_case | The step-window counter wraps at the package default CYCLES_PER_STEP_DEFAULT instead of at the host-programmed cycles_per_step, so the register only reaches the step test and not the window length. | killed | a_window_steps_ceiling, a_ceiling_moves_by_known_path |
| 30 | 5 | wrong_event | The ceiling step is taken on the PWM rising edge of the window's last cycle, while the step-window counter still counts falling edges, so the ceiling widens at the start of a pulse instead of after it. | killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| 31 | 5 | sequencing | The ceiling step tests the step-window counter's next value instead of its current value, so the step lands one switching cycle before the window ends. | killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| 32 | 6 | boundary | The SS_done look-ahead on a ramp step compares the landing ceiling with the package MAX_ON_COUNTS_DEFAULT (the 'MAX_ON_COUNTS' of the port comment) instead of the programmed max_on_limit. | killed | a_done_rises_at_target |
| 33 | 6 | boundary | The at-target test compares the ceiling with the package default MAX_ON_COUNTS_DEFAULT instead of the programmed max_on_limit, while the clamp still loads max_on_limit. | killed | a_ceiling_moves_by_known_path, a_done_follows_target |
| 34 | 6 | field | When the ramp reaches or passes its target, the ceiling is clamped to the package MAX_ON_COUNTS_DEFAULT instead of the programmed max_on_limit. | killed | a_ceiling_moves_by_known_path, a_ceiling_within_limit +1 |
| 35 | 6 | missing_case | The ceiling-step test compares the step-window counter with the package CYCLES_PER_STEP_DEFAULT instead of the programmed cycles_per_step, while the counter still wraps at cycles_per_step. | killed | a_window_steps_ceiling |
| 36 | 6 | other | When the ramp reaches or passes its target, the at-target branch loads the MIN_ON_CNT floor (a copy of the idle re-arm line) instead of clamping the ceiling to max_on_limit. | killed | a_ceiling_moves_by_known_path, a_done_rises_at_target |
| 37 | 6 | boundary | The at-target clamp treats max_on_limit as an exclusive bound and loads one count below it, so a finished ramp settles one count short of its target. | killed | a_ceiling_moves_by_known_path, a_done_rises_at_target |
| 38 | 6 | wrong_event | The step-window counter wraps on any clock that finds it at its terminal count, not only on a switching-cycle boundary, so it never waits at the terminal count for the PWM falling edge that should end the window. | killed | a_window_steps_ceiling |
| 39 | 6 | sequencing | The ramp stops on the latched SS_done flag instead of on the live ceiling-vs-max_on_limit comparison, so the at-target clamp acts only after the look-ahead has already finished the ramp. | killed | a_done_follows_target, a_ceiling_within_limit +1 |
| 40 | 7 | missing_case | The at-target test is suppressed while the ceiling is still at the MIN_ON_CNT floor, as if to stop the ramp finishing on S_SS entry. Because of that, a max_on_limit equal to the floor is not finished on the first clock, which the header requires. | killed | a_done_follows_target |
| 41 | 7 | reset_init | The idle re-arm loads the step-window counter with 1, counting cycles from one, instead of 0. The first step window of every soft start is therefore one switching cycle short. | killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| 42 | 7 | other | A ceiling found above a lowered max_on_limit is walked down one count per clock, as a gentle ramp-down, instead of being clamped to the limit at once. SS_done is still raised at once. | killed | a_ceiling_within_limit, a_done_rises_at_target +1 |
| 43 | 8 | boundary | The ceiling-step test copies the at-or-past (>=) form of the target test, while the step-window counter still wraps only on equality. A cycles_per_step lowered below the running count therefore steps the ceiling on every switching cycle until the counter wraps. | survived |  |
| 44 | 8 | reset_init | Reaching the target also clears the step-window counter, as if a finished ramp should re-arm its window. The window then restarts on every at-target clock instead of running on every switching cycle of S_SS. | withdrawn: differ only if the ramp resumes after SS_done is set while still in S_SS, which needs max_on_limit raised in the single S_SS clock before the supervisor leaves on SS_done; before done SS_done is 0 anyway |  |
| 45 | 8 | sequencing | On a ramp step SS_done is assigned from the look-ahead comparison instead of only being set by it. Each step that does not land on the target therefore clears a SS_done that was already latched in S_SS. | withdrawn: differ only if the ramp resumes after SS_done is set while still in S_SS, which needs max_on_limit raised in the single S_SS clock before the supervisor leaves on SS_done; before done SS_done is 0 anyway |  |
| 46 | 9 | wrong_event | The step-window counter is cleared when the ramp hands over to S_RUN instead of in the idle/hiccup branch, so it is only re-armed after a ramp that finished. | killed | a_window_steps_ceiling |
| 47 | 9 | reset_init | The edge detector's delayed PWM copy is re-armed low outside S_SS, like the rest of the ramp state, instead of always tracking pwm_sync. | survived |  |
| 48 | 9 | other | Each ramp step widens the ceiling by cycles_per_step counts instead of one count, mixing up the step period with the step size. | lint | Verilator: WIDTHTRUNC |
| 49 | 9 | sequencing | On the step that would land on max_on_limit, only SS_done is raised and the ceiling step itself is skipped, as if signalling done replaced the last step. | killed | a_window_steps_ceiling, a_done_rises_at_target |
| 50 | 10 | wrong_event | A max_on_limit raised during S_RUN widens the held ceiling at once, as if only a lowered limit had to wait for the next ramp, instead of every change being deferred to the next soft start. | killed | a_hold_in_run, a_ceiling_moves_by_known_path |
| 51 | 10 | sequencing | On the at-target branch SS_done waits for a PWM falling edge, as if it were a ceiling update that must land between pulses, while the clamp itself still acts on the clock it is found. | killed | a_done_follows_target |
| 52 | 10 | boundary | The step-window counter wraps at or past its terminal count (the at-or-past form of the target test), while the ceiling-step test still requires the count to equal it. | survived |  |
| 53 | 11 | sequencing | The clamp of a ceiling at or past max_on_limit waits for a PWM falling edge, treated like a ceiling update that must not land mid-pulse, but SS_done is still raised on the clock the target is found. | killed | a_ceiling_within_limit, a_done_rises_at_target |
| 54 | 11 | other | A ceiling found above a lowered max_on_limit is handled like an aborted ramp and sent back to the MIN_ON_CNT floor to re-ramp, instead of being clamped to the limit and finishing. | killed | a_done_follows_target, a_ceiling_moves_by_known_path |
| 55 | 12 | reset_init | In S_SS, SS_done is treated as a live 'ceiling at target' flag and cleared on any clock that finds the ceiling below max_on_limit with no step landing, instead of staying latched once the ramp has finished. | withdrawn: differ only if the ramp resumes after SS_done is set while still in S_SS, which needs max_on_limit raised in the single S_SS clock before the supervisor leaves on SS_done; before done SS_done is 0 anyway |  |

Rejected by the gate in step 2 (1):

- The step-window counter advances on every clock while the PWM is high, not once per switching cycle at the falling edge. - **the same edit as soft_start.126.SIB.1**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `soft_start.44.CST.1` | localparam MIN_ON_CNT: 1 -> 0 | 15:lint | make lint: WIDTHTRUNC |
| `soft_start.44.CST.2` | localparam MIN_ON_CNT: 1 -> 2 | 15:survived |  |
| `soft_start.44.CST.3` | localparam MIN_ON_CNT: 0 -> 1 | 15:killed | a_reset_floor, a_floor_when_idle +1 |
| `soft_start.53.EDG.1` | posedge clk -> negedge clk | 15:killed | a_window_steps_ceiling |
| `soft_start.62.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 15:survived |  |
| `soft_start.62.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 15:killed | a_window_steps_ceiling |
| `soft_start.62.UOD.1` | drop the '!' before rst_n | 15:killed | a_window_steps_ceiling |
| `soft_start.64.CST.1` | 1'b0 -> 1'b1 | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.64.SDL.1` | delete 'pwm_sync_d <= 1'b0;' | 15:survived |  |
| `soft_start.68.AIM.47` | The edge detector's delayed PWM copy is re-armed low outside S_SS, like the rest of the ramp state, instead of always tracking pwm_sync. | 15:survived |  |
| `soft_start.68.AIM.6` | The edge detector's delayed PWM copy is only updated in S_SS, so it holds a stale value from the previous soft start. | 15:survived |  |
| `soft_start.70.SDL.1` | delete 'pwm_sync_d <= pwm_sync;' | 15:killed | a_window_steps_ceiling |
| `soft_start.70.SIB.1` | pwm_sync -> pwm_fall | 15:killed | a_window_steps_ceiling |
| `soft_start.70.STK.1` | pwm_sync_d stuck at all-zeros (was 'pwm_sync') | 15:killed | a_window_steps_ceiling |
| `soft_start.70.STK.2` | pwm_sync_d stuck at all-ones (was 'pwm_sync') | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.70.VNG.1` | pwm_sync_d inverted (was 'pwm_sync') | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.88.AIM.1` | The cycle boundary is taken on the rising edge of the PWM instead of the falling edge, so the ceiling steps at the start of a pulse rather than after it. | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.88.AIM.17` | The cycle-boundary detector is written as a generic any-edge detector, so both the rising and the falling edge of each PWM pulse count as a switching-cycle boundary. | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.88.CTD.1` | drop the term 'pwm_sync_d' | 15:lint | make lint: UNUSEDSIGNAL |
| `soft_start.88.CTD.2` | drop the term '~pwm_sync' | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.88.CTN.1` | negate the term 'pwm_sync_d' | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.88.DLY.1` | pwm_sync_d -> pwm_sync | 15:lint | make lint: UNUSEDSIGNAL |
| `soft_start.88.DLY.2` | pwm_sync -> pwm_sync_d | 15:killed | a_window_steps_ceiling |
| `soft_start.88.LCR.1` | & -> \| | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.88.SDL.1` | delete 'pwm_fall = pwm_sync_d & ~pwm_sync;' | 15:lint | make lint: UNDRIVEN, UNUSEDSIGNAL |
| `soft_start.88.SIB.1` | pwm_sync -> pwm_fall | 15:lint | make lint: ALWCOMBORDER, UNOPTFLAT |
| `soft_start.88.STK.1` | pwm_fall stuck at all-zeros (was 'pwm_sync_d & ~pwm_sync') | 15:lint | make lint: UNUSEDSIGNAL |
| `soft_start.88.STK.2` | pwm_fall stuck at all-ones (was 'pwm_sync_d & ~pwm_sync') | 15:lint | make lint: UNUSEDSIGNAL |
| `soft_start.88.UOD.1` | drop the '~' before pwm_sync | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.88.VNG.1` | pwm_fall inverted (was 'pwm_sync_d & ~pwm_sync') | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.93.EDG.1` | posedge clk -> negedge clk | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling +5 |
| `soft_start.113.BDL.1` | empty the 3-statement body of the if at line 113 | 15:killed | a_reset_floor |
| `soft_start.113.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 15:killed | a_reset_floor |
| `soft_start.113.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 15:killed | a_window_steps_ceiling, a_done_follows_target |
| `soft_start.113.UOD.1` | drop the '!' before rst_n | 15:killed | a_window_steps_ceiling, a_done_follows_target |
| `soft_start.115.CST.1` | '0 -> '1 | 15:killed | a_window_steps_ceiling |
| `soft_start.115.SDL.1` | delete 'cycle_counter <= '0;' | 15:survived |  |
| `soft_start.116.SDL.1` | delete 'max_on_counts <= MIN_ON_CNT;' | 15:killed | a_reset_floor |
| `soft_start.116.STK.1` | max_on_counts stuck at all-zeros (was 'MIN_ON_CNT') | 15:killed | a_reset_floor |
| `soft_start.116.STK.2` | max_on_counts stuck at all-ones (was 'MIN_ON_CNT') | 15:killed | a_reset_floor |
| `soft_start.116.VNG.1` | max_on_counts inverted (was 'MIN_ON_CNT') | 15:killed | a_reset_floor |
| `soft_start.117.CST.1` | 1'b0 -> 1'b1 | 15:killed | a_reset_floor |
| `soft_start.117.SDL.1` | delete 'SS_done <= 1'b0;' | 15:survived |  |
| `soft_start.121.AIM.21` | The ramp branch is entered in S_RUN as well as S_SS, so the ramp keeps running under the regulating loop instead of the ceiling being held. | 15:killed | a_hold_in_run, a_ceiling_moves_by_known_path |
| `soft_start.121.AIM.22` | The ramp branch is gated off once SS_done is set, so the last S_SS clock after the ramp finishes falls through to the idle reset branch. | 15:killed | a_done_follows_target, a_done_falls_on_exit +1 |
| `soft_start.121.BDL.1` | empty the 2-statement body of the if at line 121 | 15:lint | make lint: UNUSEDSIGNAL |
| `soft_start.121.CND.1` | if (ss_active) -> if (!(...)) | 15:killed | a_done_rises_at_target, a_floor_when_idle +5 |
| `soft_start.121.CSK.1` | if (ss_active) -> if (1'b0): never taken | 15:lint | make lint: UNUSEDSIGNAL |
| `soft_start.121.CSK.2` | if (ss_active) -> if (1'b1): always taken | 15:lint | make lint: UNUSEDSIGNAL |
| `soft_start.121.EDL.1` | delete the else branch at line 121 | 15:lint | make lint: UNUSEDSIGNAL |
| `soft_start.121.SIB.1` | ss_active -> run_active | 15:lint | make lint: UNUSEDSIGNAL |
| `soft_start.126.AIM.15` | The step-window counter advances on the PWM rising edge, while the ceiling step is still taken at the falling edge. | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.126.AIM.38` | The step-window counter wraps on any clock that finds it at its terminal count, not only on a switching-cycle boundary, so it never waits at the terminal count for the PWM falling edge that should end the window. | 15:killed | a_window_steps_ceiling |
| `soft_start.126.CND.1` | if (pwm_fall) -> if (!(...)) | 15:killed | a_window_steps_ceiling, a_ceiling_moves_by_known_path |
| `soft_start.126.CSK.1` | if (pwm_fall) -> if (1'b0): never taken | 15:killed | a_window_steps_ceiling |
| `soft_start.126.CSK.2` | if (pwm_fall) -> if (1'b1): always taken | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.126.SIB.1` | pwm_fall -> pwm_sync | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.128.AIM.29` | The step-window counter wraps at the package default CYCLES_PER_STEP_DEFAULT instead of at the host-programmed cycles_per_step, so the register only reaches the step test and not the window length. | 15:killed | a_window_steps_ceiling, a_ceiling_moves_by_known_path |
| `soft_start.128.AIM.52` | The step-window counter wraps at or past its terminal count (the at-or-past form of the target test), while the ceiling-step test still requires the count to equal it. | 15:survived |  |
| `soft_start.128.AOR.1` | - -> + | 15:killed | a_window_steps_ceiling, a_ceiling_moves_by_known_path |
| `soft_start.128.CND.1` | if (cycle_counter == cycles_per_step - 1'b1) -> if (!(...)) | 15:killed | a_window_steps_ceiling |
| `soft_start.128.CSK.1` | if (cycle_counter == cycles_per_step - 1'b1) -> if (1'b0): never taken | 15:killed | a_window_steps_ceiling |
| `soft_start.128.CSK.2` | if (cycle_counter == cycles_per_step - 1'b1) -> if (1'b1): always taken | 15:killed | a_window_steps_ceiling |
| `soft_start.128.CST.1` | 1'b1 -> 1'b0 | 15:killed | a_window_steps_ceiling, a_ceiling_moves_by_known_path |
| `soft_start.128.ROR.1` | == -> != | 15:killed | a_window_steps_ceiling |
| `soft_start.130.AIM.25` | At the end of a step window the cycle counter wraps to 1 instead of 0, counting the wrapping cycle as the first of the next window, so every window after the first is one switching cycle short. | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.130.CST.1` | '0 -> '1 | 15:killed | a_window_steps_ceiling, a_ceiling_moves_by_known_path |
| `soft_start.130.SDL.1` | delete 'cycle_counter <= '0;' | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.136.AOR.1` | + -> - | 15:killed | a_window_steps_ceiling |
| `soft_start.136.CST.1` | 1 -> 0 | 15:killed | a_window_steps_ceiling |
| `soft_start.136.CST.2` | 1 -> 2 | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.136.SDL.1` | delete 'cycle_counter <= cycle_counter + 1;' | 15:killed | a_window_steps_ceiling |
| `soft_start.136.STK.1` | cycle_counter stuck at all-zeros (was 'cycle_counter + 1') | 15:killed | a_window_steps_ceiling |
| `soft_start.136.STK.2` | cycle_counter stuck at all-ones (was 'cycle_counter + 1') | 15:killed | a_window_steps_ceiling |
| `soft_start.136.VNG.1` | cycle_counter inverted (was 'cycle_counter + 1') | 15:killed | a_window_steps_ceiling |
| `soft_start.145.AIM.23` | The at-target clamp is applied only while SS_done is still low, as if finishing the ramp needed acting on only once, so on the last S_SS clock after done the step branch is reachable again. | 15:killed | a_ceiling_moves_by_known_path, a_ceiling_within_limit |
| `soft_start.145.AIM.33` | The at-target test compares the ceiling with the package default MAX_ON_COUNTS_DEFAULT instead of the programmed max_on_limit, while the clamp still loads max_on_limit. | 15:killed | a_ceiling_moves_by_known_path, a_done_follows_target |
| `soft_start.145.AIM.39` | The ramp stops on the latched SS_done flag instead of on the live ceiling-vs-max_on_limit comparison, so the at-target clamp acts only after the look-ahead has already finished the ramp. | 15:killed | a_done_follows_target, a_ceiling_within_limit +1 |
| `soft_start.145.AIM.40` | The at-target test is suppressed while the ceiling is still at the MIN_ON_CNT floor, as if to stop the ramp finishing on S_SS entry. Because of that, a max_on_limit equal to the floor is not finished on the first clock, which the header requires. | 15:killed | a_done_follows_target |
| `soft_start.145.AIM.5` | The look-ahead meant only for SS_done is also used in the target test, so the last step lands as soon as the ceiling is one below the limit, without waiting out its step window. | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.145.AIM.54` | A ceiling found above a lowered max_on_limit is handled like an aborted ramp and sent back to the MIN_ON_CNT floor to re-ramp, instead of being clamped to the limit and finishing. | 15:killed | a_done_follows_target, a_ceiling_moves_by_known_path |
| `soft_start.145.AIM.7` | The target test checks for equality instead of at-or-past, so a ceiling already above a lowered max_on_limit is never clamped back down (the bug the header says >= was brought in to fix). | 15:killed | a_ceiling_within_limit, a_done_follows_target +1 |
| `soft_start.145.BDL.1` | empty the 2-statement body of the if at line 145 | 15:killed | a_done_follows_target, a_ceiling_within_limit |
| `soft_start.145.CND.1` | if (max_on_counts >= max_on_limit) -> if (!(...)) | 15:killed | a_ceiling_moves_by_known_path, a_ceiling_within_limit +1 |
| `soft_start.145.CSK.1` | if (max_on_counts >= max_on_limit) -> if (1'b0): never taken | 15:killed | a_ceiling_moves_by_known_path, a_done_follows_target +1 |
| `soft_start.145.CSK.2` | if (max_on_counts >= max_on_limit) -> if (1'b1): always taken | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.145.ROR.1` | >= -> <= | 15:killed | a_ceiling_moves_by_known_path, a_ceiling_within_limit |
| `soft_start.145.ROR.2` | >= -> > | 15:killed | a_ceiling_moves_by_known_path, a_done_follows_target +1 |
| `soft_start.145.SIB.1` | max_on_counts -> max_on_limit | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.145.SIB.2` | max_on_limit -> max_on_counts | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.147.AIM.34` | When the ramp reaches or passes its target, the ceiling is clamped to the package MAX_ON_COUNTS_DEFAULT instead of the programmed max_on_limit. | 15:killed | a_ceiling_moves_by_known_path, a_ceiling_within_limit +1 |
| `soft_start.147.AIM.36` | When the ramp reaches or passes its target, the at-target branch loads the MIN_ON_CNT floor (a copy of the idle re-arm line) instead of clamping the ceiling to max_on_limit. | 15:killed | a_ceiling_moves_by_known_path, a_done_rises_at_target |
| `soft_start.147.AIM.37` | The at-target clamp treats max_on_limit as an exclusive bound and loads one count below it, so a finished ramp settles one count short of its target. | 15:killed | a_ceiling_moves_by_known_path, a_done_rises_at_target |
| `soft_start.147.AIM.42` | A ceiling found above a lowered max_on_limit is walked down one count per clock, as a gentle ramp-down, instead of being clamped to the limit at once. SS_done is still raised at once. | 15:killed | a_ceiling_within_limit, a_done_rises_at_target +1 |
| `soft_start.147.AIM.53` | The clamp of a ceiling at or past max_on_limit waits for a PWM falling edge, treated like a ceiling update that must not land mid-pulse, but SS_done is still raised on the clock the target is found. | 15:killed | a_ceiling_within_limit, a_done_rises_at_target |
| `soft_start.147.SDL.1` | delete 'max_on_counts <= max_on_limit;' | 15:killed | a_ceiling_within_limit, a_done_rises_at_target |
| `soft_start.147.STK.1` | max_on_counts stuck at all-zeros (was 'max_on_limit') | 15:killed | a_ceiling_moves_by_known_path, a_done_rises_at_target |
| `soft_start.147.STK.2` | max_on_counts stuck at all-ones (was 'max_on_limit') | 15:killed | a_ceiling_within_limit, a_ceiling_moves_by_known_path +1 |
| `soft_start.147.VNG.1` | max_on_counts inverted (was 'max_on_limit') | 15:killed | a_ceiling_moves_by_known_path, a_ceiling_within_limit +1 |
| `soft_start.148.AIM.13` | On the at-target branch SS_done only counts as done when the ceiling already equals the limit, so a ceiling clamped down from above a lowered max_on_limit finishes one clock late. | 15:killed | a_done_follows_target |
| `soft_start.148.AIM.51` | On the at-target branch SS_done waits for a PWM falling edge, as if it were a ceiling update that must land between pulses, while the clamp itself still acts on the clock it is found. | 15:killed | a_done_follows_target |
| `soft_start.148.CST.1` | 1'b1 -> 1'b0 | 15:killed | a_done_follows_target, a_done_falls_on_exit |
| `soft_start.148.SDL.1` | delete 'SS_done <= 1'b1;' | 15:killed | a_done_follows_target |
| `soft_start.152.AIM.12` | The SS_done look-ahead is tested on every clock below the target instead of only on the clock the last step lands, so SS_done rises as soon as the ceiling is one count below max_on_limit. | 15:killed | a_done_rises_at_target |
| `soft_start.152.AIM.18` | The ceiling step is qualified by the PWM being low (the 'pulse is over' level) instead of by the one-clock falling-edge pulse. | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.152.AIM.3` | The ceiling steps on the first switching cycle of each step window instead of its last. | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.152.AIM.30` | The ceiling step is taken on the PWM rising edge of the window's last cycle, while the step-window counter still counts falling edges, so the ceiling widens at the start of a pulse instead of after it. | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.152.AIM.31` | The ceiling step tests the step-window counter's next value instead of its current value, so the step lands one switching cycle before the window ends. | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.152.AIM.35` | The ceiling-step test compares the step-window counter with the package CYCLES_PER_STEP_DEFAULT instead of the programmed cycles_per_step, while the counter still wraps at cycles_per_step. | 15:killed | a_window_steps_ceiling |
| `soft_start.152.AIM.43` | The ceiling-step test copies the at-or-past (>=) form of the target test, while the step-window counter still wraps only on equality. A cycles_per_step lowered below the running count therefore steps the ceiling on every switching cycle until the counter wraps. | 15:survived |  |
| `soft_start.152.AIM.8` | The ramp step is an independent if after the at-target clamp rather than its else branch, so on a step boundary the later step assignment wins over the clamp. | 15:killed | a_ceiling_moves_by_known_path, a_ceiling_within_limit |
| `soft_start.152.AOR.1` | - -> + | 15:killed | a_window_steps_ceiling |
| `soft_start.152.BDL.1` | empty the 2-statement body of the if at line 152 | 15:killed | a_window_steps_ceiling |
| `soft_start.152.CND.1` | if (pwm_fall && (cycle_counter == cycles_per_step - 1') -> if (!(...)) | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.152.CSK.1` | if (pwm_fall && (cycle_counter == cycles_per_step - 1') -> if (1'b1): always taken | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.152.CST.1` | 1'b1 -> 1'b0 | 15:killed | a_window_steps_ceiling |
| `soft_start.152.CTD.1` | drop the term 'pwm_fall' | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.152.CTD.2` | drop the term '(cycle_counter == cycles_per_step - 1'b1' | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.152.CTN.1` | negate the term 'pwm_fall' | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.152.CTN.2` | negate the term '(cycle_counter == cycles_per_step - 1'b1' | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.152.EDL.1` | delete the else branch at line 152 | 15:killed | a_window_steps_ceiling |
| `soft_start.152.LCR.1` | && -> \|\| | 15:killed | a_ceiling_moves_by_known_path |
| `soft_start.152.ROR.1` | == -> != | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.152.SIB.1` | pwm_fall -> pwm_sync | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.154.AIM.48` | Each ramp step widens the ceiling by cycles_per_step counts instead of one count, mixing up the step period with the step size. | 15:lint | Verilator: WIDTHTRUNC |
| `soft_start.154.AIM.49` | On the step that would land on max_on_limit, only SS_done is raised and the ceiling step itself is skipped, as if signalling done replaced the last step. | 15:killed | a_window_steps_ceiling, a_done_rises_at_target |
| `soft_start.154.AOR.1` | + -> - | 15:killed | a_window_steps_ceiling, a_ceiling_moves_by_known_path +1 |
| `soft_start.154.CST.1` | 1 -> 0 | 15:killed | a_window_steps_ceiling, a_done_rises_at_target |
| `soft_start.154.CST.2` | 1 -> 2 | 15:killed | a_window_steps_ceiling, a_ceiling_moves_by_known_path +2 |
| `soft_start.154.SDL.1` | delete 'max_on_counts <= max_on_counts + 1;' | 15:killed | a_window_steps_ceiling, a_done_rises_at_target |
| `soft_start.154.SIB.1` | max_on_counts -> max_on_limit | 15:killed | a_ceiling_within_limit, a_window_steps_ceiling +1 |
| `soft_start.154.STK.1` | max_on_counts stuck at all-zeros (was 'max_on_counts + 1') | 15:killed | a_window_steps_ceiling, a_ceiling_moves_by_known_path |
| `soft_start.154.STK.2` | max_on_counts stuck at all-ones (was 'max_on_counts + 1') | 15:killed | a_ceiling_within_limit, a_window_steps_ceiling +1 |
| `soft_start.154.VNG.1` | max_on_counts inverted (was 'max_on_counts + 1') | 15:killed | a_ceiling_within_limit, a_window_steps_ceiling +2 |
| `soft_start.158.AIM.26` | The SS_done look-ahead on a ramp step tests the current ceiling instead of the value about to land, so the last step does not raise SS_done itself. | 15:killed | a_done_with_last_step |
| `soft_start.158.AIM.32` | The SS_done look-ahead on a ramp step compares the landing ceiling with the package MAX_ON_COUNTS_DEFAULT (the 'MAX_ON_COUNTS' of the port comment) instead of the programmed max_on_limit. | 15:killed | a_done_rises_at_target |
| `soft_start.158.AOR.1` | + -> - | 15:killed | a_done_with_last_step |
| `soft_start.158.CND.1` | if (max_on_counts + 1 == max_on_limit) -> if (!(...)) | 15:killed | a_done_rises_at_target |
| `soft_start.158.CSK.1` | if (max_on_counts + 1 == max_on_limit) -> if (1'b1): always taken | 15:killed | a_done_rises_at_target |
| `soft_start.158.CST.1` | 1 -> 0 | 15:killed | a_done_with_last_step |
| `soft_start.158.CST.2` | 1 -> 2 | 15:killed | a_done_rises_at_target |
| `soft_start.158.ROR.1` | == -> != | 15:killed | a_done_rises_at_target |
| `soft_start.158.SIB.1` | max_on_counts -> max_on_limit | 15:killed | a_done_with_last_step |
| `soft_start.158.SIB.2` | max_on_limit -> max_on_counts | 15:killed | a_done_with_last_step |
| `soft_start.160.CST.1` | 1'b1 -> 1'b0 | 15:killed | a_done_with_last_step |
| `soft_start.160.SDL.1` | delete 'SS_done <= 1'b1;' | 15:killed | a_done_with_last_step |
| `soft_start.168.AIM.10` | The hold condition also keeps the ceiling while SS_done is set, so a completed ramp is not reset to the floor when the supervisor leaves S_RUN for hiccup or idle. | 15:killed | a_floor_when_idle, a_window_steps_ceiling |
| `soft_start.168.CND.1` | if (run_active) -> if (!(...)) | 15:killed | a_floor_when_idle, a_done_falls_on_exit +3 |
| `soft_start.168.CSK.1` | if (run_active) -> if (1'b0): never taken | 15:lint | make lint: UNUSEDSIGNAL |
| `soft_start.168.CSK.2` | if (run_active) -> if (1'b1): always taken | 15:lint | make lint: UNUSEDSIGNAL |
| `soft_start.168.EDL.1` | delete the else branch at line 168 | 15:lint | make lint: UNUSEDSIGNAL |
| `soft_start.168.SIB.1` | run_active -> ss_active | 15:lint | make lint: UNUSEDSIGNAL |
| `soft_start.170.AIM.2` | A max_on_limit lowered during S_RUN is clamped onto the held ceiling straight away, instead of being left until the next ramp. | 15:killed | a_hold_in_run, a_ceiling_moves_by_known_path |
| `soft_start.170.AIM.4` | SS_done is cleared on entry to S_RUN rather than held for all of S_RUN. | 15:killed | a_done_falls_on_exit, a_hold_in_run |
| `soft_start.171.AIM.24` | In S_RUN the digital ceiling is opened to full scale, leaving only the analog duty clamp, instead of holding the ceiling the ramp reached as a backstop. | 15:killed | a_hold_in_run, a_ceiling_moves_by_known_path |
| `soft_start.171.AIM.27` | In S_RUN SS_done is treated as a live 'ceiling at target' status and recomputed against max_on_limit, instead of being held as the latched end of the ramp. | 15:killed | a_done_falls_on_exit, a_hold_in_run |
| `soft_start.171.AIM.50` | A max_on_limit raised during S_RUN widens the held ceiling at once, as if only a lowered limit had to wait for the next ramp, instead of every change being deferred to the next soft start. | 15:killed | a_hold_in_run, a_ceiling_moves_by_known_path |
| `soft_start.172.AIM.46` | The step-window counter is cleared when the ramp hands over to S_RUN instead of in the idle/hiccup branch, so it is only re-armed after a ramp that finished. | 15:killed | a_window_steps_ceiling |
| `soft_start.174.AIM.19` | The return to the floor outside S_SS/S_RUN waits for a PWM falling edge, as if it were a ceiling update that must not land mid-pulse. | 15:killed | a_floor_when_idle, a_window_steps_ceiling |
| `soft_start.174.EDL.1` | delete the else branch at line 174 | 15:killed | a_floor_when_idle, a_window_steps_ceiling |
| `soft_start.176.AIM.20` | The idle re-arm loads the step-window counter with its terminal count instead of zero, so each soft start begins at the end of a step window. | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.176.AIM.41` | The idle re-arm loads the step-window counter with 1, counting cycles from one, instead of 0. The first step window of every soft start is therefore one switching cycle short. | 15:killed | a_ceiling_moves_by_known_path, a_window_steps_ceiling |
| `soft_start.176.CST.1` | '0 -> '1 | 15:killed | a_window_steps_ceiling, a_ceiling_moves_by_known_path |
| `soft_start.176.SDL.1` | delete 'cycle_counter <= '0;' | 15:killed | a_window_steps_ceiling |
| `soft_start.177.AIM.11` | Outside S_SS and S_RUN the ceiling is only reset to the floor if the ramp had finished, so a soft start aborted mid-ramp leaves its partial ceiling in place. | 15:killed | a_floor_when_idle |
| `soft_start.177.AIM.14` | Outside S_SS and S_RUN the ceiling is reset to the target max_on_limit (a copy of the clamp line) instead of to the MIN_ON_CNT floor. | 15:killed | a_floor_when_idle, a_ceiling_moves_by_known_path |
| `soft_start.177.AIM.16` | The idle re-arm sets the ceiling one count above the MIN_ON_CNT floor, unlike the power-on reset, so a re-ramp starts at the first step instead of the floor. | 15:killed | a_floor_when_idle, a_ceiling_moves_by_known_path |
| `soft_start.177.SDL.1` | delete 'max_on_counts <= MIN_ON_CNT;' | 15:killed | a_floor_when_idle |
| `soft_start.177.STK.1` | max_on_counts stuck at all-zeros (was 'MIN_ON_CNT') | 15:killed | a_floor_when_idle, a_ceiling_moves_by_known_path |
| `soft_start.177.STK.2` | max_on_counts stuck at all-ones (was 'MIN_ON_CNT') | 15:killed | a_floor_when_idle, a_ceiling_moves_by_known_path |
| `soft_start.177.VNG.1` | max_on_counts inverted (was 'MIN_ON_CNT') | 15:killed | a_floor_when_idle, a_ceiling_moves_by_known_path |
| `soft_start.178.CST.1` | 1'b0 -> 1'b1 | 15:killed | a_done_rises_at_target, a_floor_when_idle |
| `soft_start.178.SDL.1` | delete 'SS_done <= 1'b0;' | 15:killed | a_floor_when_idle |
| `soft_start.126.AIM.28` | The step-window counter only runs while a ramp step is still owed, not on every switching cycle of S_SS as the design says, so it freezes once the ceiling reaches the target. | not run (withdrawn at step 14) |  |
| `soft_start.145.AIM.9` | The at-target clamp and SS_done are only acted on at a PWM falling edge, as if they were a ceiling update that has to wait for the pulse to end, instead of on any clock. | not run (withdrawn at step 13) |  |
| `soft_start.148.AIM.44` | Reaching the target also clears the step-window counter, as if a finished ramp should re-arm its window. The window then restarts on every at-target clock instead of running on every switching cycle of S_SS. | not run (withdrawn at step 14) |  |
| `soft_start.158.AIM.45` | On a ramp step SS_done is assigned from the look-ahead comparison instead of only being set by it. Each step that does not land on the target therefore clears a SS_done that was already latched in S_SS. | not run (withdrawn at step 14) |  |
| `soft_start.166.AIM.55` | In S_SS, SS_done is treated as a live 'ceiling at target' flag and cleared on any clock that finds the ceiling below max_on_limit with no step landing, instead of staying latched once the ramp has finished. | not run (withdrawn at step 14) |  |
