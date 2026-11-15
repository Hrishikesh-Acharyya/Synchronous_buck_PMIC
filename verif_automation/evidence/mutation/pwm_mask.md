# Mutation record: pwm_mask

`rtl-systemverilog/protect/pwm_mask.sv`. Written by `tools/mutation/record.py` from `pwm_mask.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 60 | 27 | 10 | 7 | 0 | 16 | 0 | 0 | 73.3% |
| AI-written | 11 | 5 | 0 | 0 | 0 | 6 | 0 | 0 | 45.5% |
| all | 71 | 32 | 10 | 7 | 0 | 22 | 0 | 0 | 69.0% |

Survivors: 22 - 1 decided equivalent, 5 accepted, 16 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 75.4%.

## Survivors (22)

### `pwm_mask.65.BDL.1` - empty the 2-statement body of the if at line 65

- before: `if(!rst_n) begin`
- after: `if(!rst_n) begin end`
- AI judgement (step 5): **plausible**, high confidence - Emptying the reset body means lines 67-68 never run, so run_counter and pulse_allowed are undefined or stale after reset. If pwm_sync is high right after reset, pwm_out (line 125) and the truncation point change.
- designer's decision (step 7): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high
- designer's decision (step 11): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high

### `pwm_mask.65.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n) begin`
- after: `if(1'b0) begin`
- AI judgement (step 5): **plausible**, high confidence - Without the reset branch at line 65, run_counter and pulse_allowed are never initialised and keep updating during reset. pwm_out after reset (line 125) then depends on unknown or old state.
- designer's decision (step 7): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high
- designer's decision (step 11): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high

### `pwm_mask.67.CST.1` - 0 -> 1

- before: `run_counter <= 0;`
- after: `run_counter <= 1;`
- AI judgement (step 5): **plausible**, high confidence - Resetting run_counter to 1 means a pulse that is already high at reset release reaches max_on_counts at line 76 one clock earlier. With max_on_counts=0 it also takes a different path.
- designer's decision (step 7): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high
- designer's decision (step 11): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high

### `pwm_mask.67.SDL.1` - delete 'run_counter <= 0;'

- before: `run_counter <= 0;`
- after: `;`
- AI judgement (step 5): **plausible**, high confidence - run_counter is no longer cleared by reset. If pwm_sync is high when reset is released, counting starts from a stale or unknown value, which changes when line 76 closes the envelope.
- designer's decision (step 7): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high
- designer's decision (step 11): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high

### `pwm_mask.68.CST.1` - 1 -> 0

- before: `pulse_allowed <= 1;`
- after: `pulse_allowed <= 0;`
- AI judgement (step 5): **plausible**, high confidence - With pwm_sync high on the first edge after reset, line 125 registers pwm_out=0 instead of 1, cutting one clock off the pulse.
- designer's decision (step 7): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high
- designer's decision (step 11): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high

### `pwm_mask.68.SDL.1` - delete 'pulse_allowed <= 1;'

- before: `pulse_allowed <= 1;`
- after: `;`
- AI judgement (step 5): **plausible**, high confidence - pulse_allowed is not set by reset, so on the first clock after release pwm_out = pwm_sync & pulse_allowed (line 125) uses an unknown or stale value instead of 1.
- designer's decision (step 7): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high
- designer's decision (step 11): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high

### `pwm_mask.76.AIM.4` - The ceiling test is equality instead of less-than, so a ceiling lowered below the running count is missed

- before: `if(run_counter < max_on_counts) begin`
- after: `if(run_counter != max_on_counts) begin`
- AI judgement (step 5): **plausible**, high confidence - If max_on_counts is lowered below run_counter mid-pulse, != stays true, so line 78 keeps counting and pulse_allowed stays 1. The original closes the envelope there.
- designer's decision (step 9): **gap** - ceiling lowered below the elapsed count mid-pulse never tested; reachable in the design via a MAX_ON write during soft start
- designer's decision (step 13): **gap** - ceiling lowered below the elapsed count mid-pulse never tested; reachable in the design via a MAX_ON write during soft start

### `pwm_mask.76.AIM.9` - A zero on-time ceiling is treated as 'no limit', so pulses are passed through untruncated instead of being cut to one clock

- before: `if(run_counter < max_on_counts) begin`
- after: `if(run_counter < max_on_counts || max_on_counts == 0) begin`
- AI judgement (step 5): **plausible**, high confidence - With max_on_counts==0 the original takes the else branch (pulse_allowed<=0), but the mutant counts and keeps pulse_allowed=1. The pulse passes through untruncated.
- designer's decision (step 17): **accepted** - differs only at a ceiling of 0; the floor is MIN_ON_COUNTS and reg_file clamps MAX_ON to it

### `pwm_mask.78.AOR.1` - + -> -

- before: `run_counter <= run_counter + 1;`
- after: `run_counter <= run_counter - 1;`
- AI judgement (step 5): **plausible**, high confidence - Decrementing from 0 wraps to all-ones, so the ceiling compare at line 76 fails after one clock and pulses are truncated early.
- designer's decision (step 8): **gap** - truncation point checked only as an upper bound; needs a check that a pulse longer than the ceiling is cut at exactly max_on_counts+1 clocks and one shorter passes whole
- designer's decision (step 12): **gap** - truncation point checked only as an upper bound; needs a check that a pulse longer than the ceiling is cut at exactly max_on_counts+1 clocks and one shorter passes whole

### `pwm_mask.78.CST.2` - 1 -> 2

- before: `run_counter <= run_counter + 1;`
- after: `run_counter <= run_counter + 2;`
- AI judgement (step 5): **plausible**, high confidence - Counting by 2 reaches max_on_counts in about half the clocks, which shortens the enforced on-time.
- designer's decision (step 8): **gap** - truncation point checked only as an upper bound; needs a check that a pulse longer than the ceiling is cut at exactly max_on_counts+1 clocks and one shorter passes whole
- designer's decision (step 12): **gap** - truncation point checked only as an upper bound; needs a check that a pulse longer than the ceiling is cut at exactly max_on_counts+1 clocks and one shorter passes whole

### `pwm_mask.78.STK.2` - run_counter stuck at all-ones (was 'run_counter + 1')

- before: `run_counter <= run_counter + 1;`
- after: `run_counter <= '1;`
- AI judgement (step 5): **plausible**, high confidence - run_counter jumps straight to all-ones on the first high clock, so line 76 fails on the next clock and the pulse is cut almost immediately instead of after max_on_counts clocks.
- designer's decision (step 8): **gap** - truncation point checked only as an upper bound; needs a check that a pulse longer than the ceiling is cut at exactly max_on_counts+1 clocks and one shorter passes whole
- designer's decision (step 12): **gap** - truncation point checked only as an upper bound; needs a check that a pulse longer than the ceiling is cut at exactly max_on_counts+1 clocks and one shorter passes whole

### `pwm_mask.78.VNG.1` - run_counter inverted (was 'run_counter + 1')

- before: `run_counter <= run_counter + 1;`
- after: `run_counter <= ~(run_counter + 1);`
- AI judgement (step 5): **plausible**, high confidence - The inverted increment makes run_counter jump to a large value, which changes when line 76 fails and therefore the truncated pulse width.
- designer's decision (step 8): **gap** - truncation point checked only as an upper bound; needs a check that a pulse longer than the ceiling is cut at exactly max_on_counts+1 clocks and one shorter passes whole
- designer's decision (step 12): **gap** - truncation point checked only as an upper bound; needs a check that a pulse longer than the ceiling is cut at exactly max_on_counts+1 clocks and one shorter passes whole

### `pwm_mask.79.SDL.1` - delete 'pulse_allowed <= 1;'

- before: `pulse_allowed <= 1;`
- after: `;`
- AI judgement (step 5): **plausible**, high confidence - pulse_allowed can be 0 while pwm_sync is high and run_counter < max_on_counts if max_on_counts rises after line 85 has fired. The original re-opens at line 79; the mutant stays closed.
- designer's decision (step 15): **accepted** - differ only if max_on_counts rises during a pulse; soft_start raises it only at pwm_fall, between pulses

### `pwm_mask.84.AIM.1` - run_counter keeps counting past max_on_counts and wraps instead of saturating at the ceiling

- before: `run_counter <= run_counter;`
- after: `run_counter <= run_counter + 1;`
- AI judgement (step 5): **plausible**, high confidence - With pwm_sync stuck high, run_counter keeps counting in the saturation branch and eventually wraps below max_on_counts. Line 76 then re-opens the envelope, which the original prevents.
- designer's decision (step 14): **gap** - pwm_sync never held high long after truncation; needs a stuck-high input longer than the counter range, with a ceiling above half the range

### `pwm_mask.84.AIM.8` - The saturation branch clamps run_counter to the present ceiling instead of holding it, so a ceiling lowered mid-pulse pulls the elapsed count down to it

- before: `run_counter <= run_counter;`
- after: `run_counter <= max_on_counts;`
- AI judgement (step 5): **plausible**, high confidence - If max is lowered below run_counter, the mutant clamps run_counter down to it. If max is then raised but stays below the original held count, the mutant re-opens at lines 76/79 while the original stays closed.
- designer's decision (step 15): **accepted** - differ only if max_on_counts rises during a pulse; soft_start raises it only at pwm_fall, between pulses

### `pwm_mask.84.SDL.1` - delete 'run_counter <= run_counter;'

- before: `run_counter <= run_counter;`
- after: `;`
- AI judgement (step 5): **equivalent**, high confidence - In an always_ff, a register that is not assigned keeps its value. Deleting the self-assignment 'run_counter <= run_counter' at line 84 therefore leaves the same hold behaviour.
- designer's decision (step 6): **equivalent** - deleting the self-assignment leaves the register holding its value, as before
- designer's decision (step 10): **equivalent** - deleting the self-assignment leaves the register holding its value, as before

### `pwm_mask.84.STK.2` - run_counter stuck at all-ones (was 'run_counter')

- before: `run_counter <= run_counter;`
- after: `run_counter <= '1;`
- AI judgement (step 5): **plausible**, high confidence - Once saturated, run_counter becomes all-ones instead of holding. If max_on_counts is later raised above the held count but stays below all-ones, the original re-opens via line 76 and the mutant does not.
- designer's decision (step 15): **accepted** - differ only if max_on_counts rises during a pulse; soft_start raises it only at pwm_fall, between pulses

### `pwm_mask.84.VNG.1` - run_counter inverted (was 'run_counter')

- before: `run_counter <= run_counter;`
- after: `run_counter <= ~(run_counter);`
- AI judgement (step 5): **plausible**, high confidence - Inverting run_counter in the saturation branch can drop it below max_on_counts (e.g. ~max when max is large). Line 76 then re-opens the envelope mid-pulse, giving a double pulse.
- designer's decision (step 14): **gap** - pwm_sync never held high long after truncation; needs a stuck-high input longer than the counter range, with a ceiling above half the range

### `pwm_mask.85.AIM.10` - The envelope is closed only when the elapsed count equals the ceiling, so the case of a ceiling that has dropped below the elapsed count leaves pulse_allowed open

- before: `pulse_allowed <= 0;`
- after: `if(run_counter == max_on_counts) begin / pulse_allowed <= 0; / end`
- AI judgement (step 5): **plausible**, high confidence - If max_on_counts drops below run_counter mid-pulse, run_counter != max_on_counts, so pulse_allowed is not cleared and pwm_out stays high where the original truncates.
- designer's decision (step 9): **gap** - ceiling lowered below the elapsed count mid-pulse never tested; reachable in the design via a MAX_ON write during soft start
- designer's decision (step 13): **gap** - ceiling lowered below the elapsed count mid-pulse never tested; reachable in the design via a MAX_ON write during soft start

### `pwm_mask.94.AIM.6` - The envelope is re-armed only once run_counter has already been cleared, one clock into the low phase, not on its first clock

- before: `pulse_allowed <= 1;`
- after: `pulse_allowed <= (run_counter == 0);`
- AI judgement (step 5): **plausible**, high confidence - On the first low clock after a pulse, run_counter is still nonzero, so pulse_allowed becomes 0. If pwm_sync goes high again after a one-clock low gap, line 125 outputs 0 instead of 1.
- designer's decision (step 16): **accepted** - differs only for a one-clock low phase; the 70% analog duty clamp keeps every low phase above 6 clocks

### `pwm_mask.118.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n) begin`
- after: `if(1'b0) begin`
- AI judgement (step 5): **plausible**, high confidence - Without the reset branch, pwm_out is not forced to 0 during reset. It keeps following pwm_sync & pulse_allowed or stays undefined.
- designer's decision (step 7): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high
- designer's decision (step 11): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high

### `pwm_mask.120.SDL.1` - delete 'pwm_out <= 0;'

- before: `pwm_out <= 0;`
- after: `;`
- AI judgement (step 5): **plausible**, high confidence - pwm_out is no longer cleared by reset. If reset is asserted while pwm_out is high, it stays 1 through reset, and it is undefined at power-up.
- designer's decision (step 7): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high
- designer's decision (step 11): **gap** - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high

## Caught only by a lost cover (7)

Counted as caught, but no check failed: the behaviour is observed, not checked.

- `pwm_mask.65.CSK.2` - if (!rst_n) -> if (1'b1): always taken: `if(!rst_n) begin` -> `if(1'b1) begin`
- `pwm_mask.65.UOD.1` - drop the '!' before rst_n: `if(!rst_n) begin` -> `if(rst_n) begin`
- `pwm_mask.74.CSK.1` - if (pwm_sync) -> if (1'b0): never taken: `if(pwm_sync) begin` -> `if(1'b0) begin`
- `pwm_mask.76.BDL.1` - empty the 2-statement body of the if at line 76: `if(run_counter < max_on_counts) begin` -> `if(run_counter < max_on_counts) begin end`
- `pwm_mask.78.CST.1` - 1 -> 0: `run_counter <= run_counter + 1;` -> `run_counter <= run_counter + 0;`
- `pwm_mask.78.SDL.1` - delete 'run_counter <= run_counter + 1;': `run_counter <= run_counter + 1;` -> `;`
- `pwm_mask.78.STK.1` - run_counter stuck at all-zeros (was 'run_counter + 1'): `run_counter <= run_counter + 1;` -> `run_counter <= '0;`

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-15 14:46 | a1dc229 | AI wrote mutants (claude-opus-5-5) | asked 8, proposed 6, accepted 6, rejected 0; `ai_runs/2026-11-15_write_mutants_10` |
| 2 | 2026-11-15 14:49 | a1dc229 | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 3, accepted 3, rejected 0; `ai_runs/2026-11-15_write_mutants_11` |
| 3 | 2026-11-15 14:51 | a1dc229 | AI wrote mutants (claude-opus-5-5) | asked 8, proposed 2, accepted 2, rejected 0; `ai_runs/2026-11-15_write_mutants_12` |
| 4 | 2026-11-15 14:59 | e6d9ec9 | mutation run - every mutant of the module | 71 mutants: 32 killed, 10 lint, 7 covers, 22 survived; score 69.0% |
| 5 | 2026-11-15 15:00 | e6d9ec9 | AI judged survivors (claude-opus-5-5) | 22 judged, 1 called equivalent with high confidence; `ai_runs/2026-11-15_judge_survivors_3` |
| 6 | 2026-11-15 15:05 | e6d9ec9 | designer's decision: equivalent | pwm_mask.84.SDL.1 - deleting the self-assignment leaves the register holding its value, as before |
| 7 | 2026-11-15 15:05 | e6d9ec9 | designer's decision: gap | pwm_mask.65.BDL.1, pwm_mask.65.CSK.1, pwm_mask.67.CST.1, pwm_mask.67.SDL.1, pwm_mask.68.CST.1, pwm_mask.68.SDL.1, pwm_mask.118.CSK.1, pwm_mask.120.SDL.1 - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high |
| 8 | 2026-11-15 15:05 | e6d9ec9 | designer's decision: gap | pwm_mask.78.AOR.1, pwm_mask.78.CST.2, pwm_mask.78.STK.2, pwm_mask.78.VNG.1 - truncation point checked only as an upper bound; needs a check that a pulse longer than the ceiling is cut at exactly max_on_counts+1 clocks and one shorter passes whole |
| 9 | 2026-11-15 15:05 | e6d9ec9 | designer's decision: gap | pwm_mask.76.AIM.4, pwm_mask.85.AIM.10 - ceiling lowered below the elapsed count mid-pulse never tested; reachable in the design via a MAX_ON write during soft start |
| 10 | 2026-11-15 15:05 | e6d9ec9 | designer's decision: equivalent | pwm_mask.84.SDL.1 - deleting the self-assignment leaves the register holding its value, as before |
| 11 | 2026-11-15 15:05 | e6d9ec9 | designer's decision: gap | pwm_mask.65.BDL.1, pwm_mask.65.CSK.1, pwm_mask.67.CST.1, pwm_mask.67.SDL.1, pwm_mask.68.CST.1, pwm_mask.68.SDL.1, pwm_mask.118.CSK.1, pwm_mask.120.SDL.1 - reset values untested: reset only at time zero with pwm_sync low; needs a reset applied mid-pulse and released with pwm_sync high |
| 12 | 2026-11-15 15:05 | e6d9ec9 | designer's decision: gap | pwm_mask.78.AOR.1, pwm_mask.78.CST.2, pwm_mask.78.STK.2, pwm_mask.78.VNG.1 - truncation point checked only as an upper bound; needs a check that a pulse longer than the ceiling is cut at exactly max_on_counts+1 clocks and one shorter passes whole |
| 13 | 2026-11-15 15:05 | e6d9ec9 | designer's decision: gap | pwm_mask.76.AIM.4, pwm_mask.85.AIM.10 - ceiling lowered below the elapsed count mid-pulse never tested; reachable in the design via a MAX_ON write during soft start |
| 14 | 2026-11-15 15:06 | e6d9ec9 | designer's decision: gap | pwm_mask.84.AIM.1, pwm_mask.84.VNG.1 - pwm_sync never held high long after truncation; needs a stuck-high input longer than the counter range, with a ceiling above half the range |
| 15 | 2026-11-15 15:06 | e6d9ec9 | designer's decision: accepted | pwm_mask.79.SDL.1, pwm_mask.84.STK.2, pwm_mask.84.AIM.8 - differ only if max_on_counts rises during a pulse; soft_start raises it only at pwm_fall, between pulses |
| 16 | 2026-11-15 15:06 | e6d9ec9 | designer's decision: accepted | pwm_mask.94.AIM.6 - differs only for a one-clock low phase; the 70% analog duty clamp keeps every low phase above 6 clocks |
| 17 | 2026-11-15 15:06 | e6d9ec9 | designer's decision: accepted | pwm_mask.76.AIM.9 - differs only at a ceiling of 0; the floor is MIN_ON_COUNTS and reg_file clamps MAX_ON to it |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (11)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | boundary | run_counter keeps counting past max_on_counts and wraps instead of saturating at the ceiling | survived |  |
| 2 | 1 | wrong_event | The envelope is re-armed whenever the gated pulse ends, not only when pwm_sync goes low, so a truncated pulse re-arms while pwm_sync is still high | killed | a_long_pulses_truncated, a_pwm_out_cannot_go_back_up_once_truncated |
| 3 | 1 | priority | The saturated-hold branch wins over the low-phase re-arm, so a counter at the ceiling is never cleared | killed | a_counter_0_in_low_phase |
| 4 | 1 | boundary | The ceiling test is equality instead of less-than, so a ceiling lowered below the running count is missed | survived |  |
| 5 | 1 | sequencing | pulse_allowed is decided from the post-increment count instead of the pre-edge run_counter, which removes the documented +1 clk offset | killed | a_short_pulses_pass |
| 6 | 1 | sequencing | The envelope is re-armed only once run_counter has already been cleared, one clock into the low phase, not on its first clock | survived |  |
| 7 | 2 | reset_init | run_counter is cleared on the low phase only after a pulse that was truncated, so the on-time of a pulse that ended under the ceiling carries over into the next pulse | killed | a_counter_0_in_low_phase |
| 8 | 2 | boundary | The saturation branch clamps run_counter to the present ceiling instead of holding it, so a ceiling lowered mid-pulse pulls the elapsed count down to it | survived |  |
| 9 | 2 | boundary | A zero on-time ceiling is treated as 'no limit', so pulses are passed through untruncated instead of being cut to one clock | survived |  |
| 10 | 3 | missing_case | The envelope is closed only when the elapsed count equals the ceiling, so the case of a ceiling that has dropped below the elapsed count leaves pulse_allowed open | survived |  |
| 11 | 3 | wrong_event | The output takes 'pulse in progress' from run_counter being non-zero instead of from pwm_sync, so it follows the counter's one-clock-late view of the pulse | killed | a_short_pulses_pass, a_pwm_out_cannot_go_back_up_once_truncated +1 |

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `pwm_mask.41.EDG.1` | posedge clk -> negedge clk | 4:killed | a_counter_0_in_low_phase |
| `pwm_mask.65.BDL.1` | empty the 2-statement body of the if at line 65 | 4:survived |  |
| `pwm_mask.65.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 4:survived |  |
| `pwm_mask.65.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 4:covers | hit 4 SVA covers, the unmutated run 6 |
| `pwm_mask.65.UOD.1` | drop the '!' before rst_n | 4:covers | hit 4 SVA covers, the unmutated run 6 |
| `pwm_mask.67.CST.1` | 0 -> 1 | 4:survived |  |
| `pwm_mask.67.SDL.1` | delete 'run_counter <= 0;' | 4:survived |  |
| `pwm_mask.68.CST.1` | 1 -> 0 | 4:survived |  |
| `pwm_mask.68.CST.2` | 1 -> 2 | 4:lint | make lint: WIDTHTRUNC |
| `pwm_mask.68.SDL.1` | delete 'pulse_allowed <= 1;' | 4:survived |  |
| `pwm_mask.72.EDL.1` | delete the else branch at line 72 | 4:lint | make lint: UNUSEDSIGNAL |
| `pwm_mask.74.AIM.2` | The envelope is re-armed whenever the gated pulse ends, not only when pwm_sync goes low, so a truncated pulse re-arms while pwm_sync is still high | 4:killed | a_long_pulses_truncated, a_pwm_out_cannot_go_back_up_once_truncated |
| `pwm_mask.74.AIM.3` | The saturated-hold branch wins over the low-phase re-arm, so a counter at the ceiling is never cleared | 4:killed | a_counter_0_in_low_phase |
| `pwm_mask.74.CND.1` | if (pwm_sync) -> if (!(...)) | 4:killed | a_counter_0_in_low_phase |
| `pwm_mask.74.CSK.1` | if (pwm_sync) -> if (1'b0): never taken | 4:covers | hit 4 SVA covers, the unmutated run 6 |
| `pwm_mask.74.CSK.2` | if (pwm_sync) -> if (1'b1): always taken | 4:killed | a_counter_0_in_low_phase |
| `pwm_mask.74.SIB.1` | pwm_sync -> pwm_out | 4:killed | a_counter_0_in_low_phase, a_long_pulses_truncated +1 |
| `pwm_mask.76.AIM.4` | The ceiling test is equality instead of less-than, so a ceiling lowered below the running count is missed | 4:survived |  |
| `pwm_mask.76.AIM.5` | pulse_allowed is decided from the post-increment count instead of the pre-edge run_counter, which removes the documented +1 clk offset | 4:killed | a_short_pulses_pass |
| `pwm_mask.76.AIM.9` | A zero on-time ceiling is treated as 'no limit', so pulses are passed through untruncated instead of being cut to one clock | 4:survived |  |
| `pwm_mask.76.BDL.1` | empty the 2-statement body of the if at line 76 | 4:covers | hit 4 SVA covers, the unmutated run 6 |
| `pwm_mask.76.CND.1` | if (run_counter < max_on_counts) -> if (!(...)) | 4:killed | a_short_pulses_pass |
| `pwm_mask.76.CSK.1` | if (run_counter < max_on_counts) -> if (1'b0): never taken | 4:lint | make lint: UNUSEDSIGNAL |
| `pwm_mask.76.CSK.2` | if (run_counter < max_on_counts) -> if (1'b1): always taken | 4:lint | make lint: UNUSEDSIGNAL |
| `pwm_mask.76.ROR.1` | < -> <= | 4:killed | a_long_pulses_truncated |
| `pwm_mask.76.ROR.2` | < -> > | 4:killed | a_short_pulses_pass |
| `pwm_mask.78.AOR.1` | + -> - | 4:survived |  |
| `pwm_mask.78.CST.1` | 1 -> 0 | 4:covers | hit 4 SVA covers, the unmutated run 6 |
| `pwm_mask.78.CST.2` | 1 -> 2 | 4:survived |  |
| `pwm_mask.78.SDL.1` | delete 'run_counter <= run_counter + 1;' | 4:covers | hit 4 SVA covers, the unmutated run 6 |
| `pwm_mask.78.STK.1` | run_counter stuck at all-zeros (was 'run_counter + 1') | 4:covers | hit 4 SVA covers, the unmutated run 6 |
| `pwm_mask.78.STK.2` | run_counter stuck at all-ones (was 'run_counter + 1') | 4:survived |  |
| `pwm_mask.78.VNG.1` | run_counter inverted (was 'run_counter + 1') | 4:survived |  |
| `pwm_mask.79.CST.1` | 1 -> 0 | 4:killed | a_short_pulses_pass |
| `pwm_mask.79.CST.2` | 1 -> 2 | 4:lint | make lint: WIDTHTRUNC |
| `pwm_mask.79.SDL.1` | delete 'pulse_allowed <= 1;' | 4:survived |  |
| `pwm_mask.82.EDL.1` | delete the else branch at line 82 | 4:killed | a_long_pulses_truncated |
| `pwm_mask.84.AIM.1` | run_counter keeps counting past max_on_counts and wraps instead of saturating at the ceiling | 4:survived |  |
| `pwm_mask.84.AIM.8` | The saturation branch clamps run_counter to the present ceiling instead of holding it, so a ceiling lowered mid-pulse pulls the elapsed count down to it | 4:survived |  |
| `pwm_mask.84.SDL.1` | delete 'run_counter <= run_counter;' | 4:survived |  |
| `pwm_mask.84.STK.1` | run_counter stuck at all-zeros (was 'run_counter') | 4:killed | a_short_pulses_pass, a_pwm_out_cannot_go_back_up_once_truncated |
| `pwm_mask.84.STK.2` | run_counter stuck at all-ones (was 'run_counter') | 4:survived |  |
| `pwm_mask.84.VNG.1` | run_counter inverted (was 'run_counter') | 4:survived |  |
| `pwm_mask.85.AIM.10` | The envelope is closed only when the elapsed count equals the ceiling, so the case of a ceiling that has dropped below the elapsed count leaves pulse_allowed open | 4:survived |  |
| `pwm_mask.85.CST.1` | 0 -> 1 | 4:killed | a_long_pulses_truncated |
| `pwm_mask.85.SDL.1` | delete 'pulse_allowed <= 0;' | 4:killed | a_long_pulses_truncated |
| `pwm_mask.91.EDL.1` | delete the else branch at line 91 | 4:killed | a_counter_0_in_low_phase |
| `pwm_mask.93.AIM.7` | run_counter is cleared on the low phase only after a pulse that was truncated, so the on-time of a pulse that ended under the ceiling carries over into the next pulse | 4:killed | a_counter_0_in_low_phase |
| `pwm_mask.93.CST.1` | 0 -> 1 | 4:killed | a_counter_0_in_low_phase |
| `pwm_mask.93.SDL.1` | delete 'run_counter <= 0;' | 4:killed | a_counter_0_in_low_phase |
| `pwm_mask.94.AIM.6` | The envelope is re-armed only once run_counter has already been cleared, one clock into the low phase, not on its first clock | 4:survived |  |
| `pwm_mask.94.CST.1` | 1 -> 0 | 4:killed | a_short_pulses_pass, a_pwm_out_cannot_go_back_up_once_truncated |
| `pwm_mask.94.CST.2` | 1 -> 2 | 4:lint | make lint: WIDTHTRUNC |
| `pwm_mask.94.SDL.1` | delete 'pulse_allowed <= 1;' | 4:killed | a_short_pulses_pass, a_pwm_out_cannot_go_back_up_once_truncated |
| `pwm_mask.103.EDG.1` | posedge clk -> negedge clk | 4:killed | a_mask_doesnt_produce_pwm, a_short_pulses_pass |
| `pwm_mask.118.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 4:survived |  |
| `pwm_mask.118.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 4:killed | a_short_pulses_pass |
| `pwm_mask.118.UOD.1` | drop the '!' before rst_n | 4:killed | a_short_pulses_pass |
| `pwm_mask.120.CST.1` | 0 -> 1 | 4:killed | a_pwm_out_low_on_reset |
| `pwm_mask.120.SDL.1` | delete 'pwm_out <= 0;' | 4:survived |  |
| `pwm_mask.125.AIM.11` | The output takes 'pulse in progress' from run_counter being non-zero instead of from pwm_sync, so it follows the counter's one-clock-late view of the pulse | 4:killed | a_short_pulses_pass, a_pwm_out_cannot_go_back_up_once_truncated +1 |
| `pwm_mask.125.CTD.1` | drop the term 'pwm_sync' | 4:killed | a_mask_doesnt_produce_pwm |
| `pwm_mask.125.CTD.2` | drop the term 'pulse_allowed' | 4:lint | make lint: UNUSEDSIGNAL |
| `pwm_mask.125.CTN.1` | negate the term 'pwm_sync' | 4:killed | a_mask_doesnt_produce_pwm, a_short_pulses_pass |
| `pwm_mask.125.CTN.2` | negate the term 'pulse_allowed' | 4:killed | a_short_pulses_pass, a_long_pulses_truncated +1 |
| `pwm_mask.125.LCR.1` | & -> \| | 4:killed | a_mask_doesnt_produce_pwm, a_long_pulses_truncated |
| `pwm_mask.125.SDL.1` | delete 'pwm_out <= pwm_sync & pulse_allowed;' | 4:lint | make lint: UNUSEDSIGNAL |
| `pwm_mask.125.SIB.1` | pwm_sync -> pwm_out | 4:killed | a_short_pulses_pass |
| `pwm_mask.125.STK.1` | pwm_out stuck at all-zeros (was 'pwm_sync & pulse_allowed') | 4:lint | make lint: UNUSEDSIGNAL |
| `pwm_mask.125.STK.2` | pwm_out stuck at all-ones (was 'pwm_sync & pulse_allowed') | 4:lint | make lint: UNUSEDSIGNAL |
| `pwm_mask.125.VNG.1` | pwm_out inverted (was 'pwm_sync & pulse_allowed') | 4:killed | a_mask_doesnt_produce_pwm, a_short_pulses_pass +2 |
