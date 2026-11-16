# Mutation record: pwm_stats

`rtl-systemverilog/telemetry/pwm_stats.sv`. Written by `tools/mutation/record.py` from `pwm_stats.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 100 | 86 | 10 | 0 | 0 | 4 | 0 | 0 | 96.0% |
| AI-written | 23 | 23 | 0 | 0 | 0 | 0 | 0 | 0 | 100.0% |
| all | 123 | 109 | 10 | 0 | 0 | 4 | 0 | 0 | 96.7% |

Survivors: 4 - 1 decided equivalent, 0 accepted, 3 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 97.5%.

## Survivors (4)

### `pwm_stats.84.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n) begin`
- after: `if(1'b0) begin`
- AI judgement (step 8): **plausible**, high confidence - With the reset branch at line 84 never taken, pwm_sync_d is no longer cleared and keeps tracking pwm_sync, including on the negedge of rst_n. If pwm_sync is 1 when reset is released, the original sees a rise (pwm_sync_d=0) and holds period_counter at 0 (lines 129-132), while the mutant sees no rise and counts to 1, so the next prev_period/duty_count capture is off by one; pwm_sync_d is also X at power-up.
- designer's decision (step 10): **gap** - pwm_sync_d reset untested: reset only at time zero with pwm_sync low; needs a reset released with pwm_sync high, which makes the first period one clock off

### `pwm_stats.86.CST.1` - 0 -> 1

- before: `pwm_sync_d <= 0;`
- after: `pwm_sync_d <= 1;`
- AI judgement (step 8): **plausible**, high confidence - With pwm_sync_d reset to 1, a pwm_sync that is high at the first clock after reset no longer produces pwm_rise (line 105). period_counter then increments to 1 instead of being cleared to 0 at line 132, so the next captured duty_count/prev_period is off by one.
- designer's decision (step 10): **gap** - pwm_sync_d reset untested: reset only at time zero with pwm_sync low; needs a reset released with pwm_sync high, which makes the first period one clock off

### `pwm_stats.86.SDL.1` - delete 'pwm_sync_d <= 0;'

- before: `pwm_sync_d <= 0;`
- after: `;`
- AI judgement (step 8): **plausible**, high confidence - Without line 86, pwm_sync_d keeps its pre-reset value (or X at power-up) through reset. If it was 1 and pwm_sync is 1 when reset is released, the pwm_rise at line 129 is missed and period_counter counts from 1 instead of 0. That changes the captured prev_period/duty_count values.
- designer's decision (step 10): **gap** - pwm_sync_d reset untested: reset only at time zero with pwm_sync low; needs a reset released with pwm_sync high, which makes the first period one clock off

### `pwm_stats.146.STK.2` - duty_count stuck at all-ones (was 'period_counter')

- before: `if (pwm_fall) duty_count <= period_counter;`
- after: `if (pwm_fall) duty_count <= '1;`
- AI judgement (step 8): **equivalent**, high confidence - Line 146 only runs inside the branch guarded by `period_counter == '1` at line 144. There period_counter is exactly all-ones at the full width CNT_W, which is also duty_count's width, so assigning '1 writes the same value. If period_counter is X, the condition is not true and the branch does not run in either version.
- designer's decision (step 9): **equivalent** - the branch runs only when period_counter == '1, the same width as duty_count, so '1 is the value it would copy

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-17 00:33 | 58da85b | AI wrote mutants (claude-opus-5-5) | asked 8, proposed 6, accepted 6, rejected 0; `ai_runs/2026-11-17_write_mutants_8` |
| 2 | 2026-11-17 00:35 | 58da85b | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 7, accepted 7, rejected 0; `ai_runs/2026-11-17_write_mutants_9` |
| 3 | 2026-11-17 00:37 | 58da85b | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 3, accepted 3, rejected 0; `ai_runs/2026-11-17_write_mutants_10` |
| 4 | 2026-11-17 00:40 | 58da85b | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 3, accepted 3, rejected 0; `ai_runs/2026-11-17_write_mutants_11` |
| 5 | 2026-11-17 00:41 | 58da85b | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 2, accepted 2, rejected 0; `ai_runs/2026-11-17_write_mutants_12` |
| 6 | 2026-11-17 00:43 | 58da85b | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 2, accepted 2, rejected 0; `ai_runs/2026-11-17_write_mutants_13` |
| 7 | 2026-11-17 00:48 | 58da85b | mutation run - every mutant of the module | 123 mutants: 109 killed, 10 lint, 4 survived; score 96.7% |
| 8 | 2026-11-17 00:49 | 58da85b | AI judged survivors (claude-opus-5-5) | 4 judged, 1 called equivalent with high confidence; `ai_runs/2026-11-17_judge_survivors_2` |
| 9 | 2026-11-17 00:51 | 58da85b | designer's decision: equivalent | pwm_stats.146.STK.2 - the branch runs only when period_counter == '1, the same width as duty_count, so '1 is the value it would copy |
| 10 | 2026-11-17 00:51 | 58da85b | designer's decision: gap | pwm_stats.84.CSK.1, pwm_stats.86.CST.1, pwm_stats.86.SDL.1 - pwm_sync_d reset untested: reset only at time zero with pwm_sync low; needs a reset released with pwm_sync high, which makes the first period one clock off |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (23)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | priority | The saturation hold takes precedence over pwm_rise, so a rising edge seen while period_counter is saturated neither captures prev_period nor restarts the counter. | killed | a_counter_clears_on_rise, a_duty_within_period +1 |
| 2 | 1 | priority | pwm_fall is handled before the saturation hold, so a falling edge on a saturated counter takes the normal fall branch and increments the counter past all-ones. | killed | a_counter_holds_at_ceiling, a_counter_never_wraps +1 |
| 3 | 1 | missing_case | Saturation applies only while PWM is high (the stall-high case named in the comment), and a stall with pwm_sync held low is forgotten. | killed | a_counter_holds_at_ceiling, a_counter_never_wraps +1 |
| 4 | 1 | boundary | The counter saturates at the nominal period CLKS_PER_SW (111) instead of the counter's all-ones limit, which forgets the drift headroom CNT_W was sized for. | killed | a_counter_advances_otherwise |
| 5 | 1 | reset_init | duty_count is cleared at the start of every switching period as if it were run state, but it is a held snapshot that should keep the last high-phase length. | killed | a_duty_count_stable_otherwise |
| 6 | 1 | boundary | prev_period adds one for the rise clock, so the period is counted differently from duty_count, which is taken from the same counter run without the +1. | killed | a_prev_period_captures_on_rise, a_duty_within_period |
| 7 | 2 | other | PWM polarity misremembered as active-low: the switching period is taken from falling edge to falling edge and the duty snapshot is taken on the rising edge, so duty_count measures the low (LS) phase instead of HS conduction. | killed | a_counter_clears_on_rise, a_duty_within_period +6 |
| 8 | 2 | wrong_event | The start-of-cycle detector fires on any PWM edge rather than only the rising edge, so the period counter is restarted at the end of HS conduction as well. | killed | a_counter_never_wraps, a_counter_advances_otherwise +3 |
| 9 | 2 | missing_case | A rising edge that ends a saturated (stalled) period is treated as invalid and does not update prev_period, so the all-ones out-of-range marker is never exported. | killed | a_duty_within_period, a_prev_period_captures_on_rise |
| 10 | 2 | boundary | The saturation test looks ahead at the next count, so the period counter stops one short at all-ones minus one instead of reaching the all-ones out-of-range marker. | killed | a_counter_advances_otherwise |
| 11 | 2 | wrong_event | When a stalled-high PWM finally falls, the saturated period counter is restarted at the fall as if measurement had recovered, rather than held until the next rising edge. | killed | a_counter_holds_at_ceiling, a_counter_never_wraps +1 |
| 12 | 2 | wrong_event | The duty snapshot is taken on the PWM low level instead of on the falling edge, so duty_count keeps being overwritten throughout the low phase. | killed | a_duty_count_stable_otherwise |
| 13 | 2 | sequencing | The falling-edge clock is counted as part of HS conduction, so duty_count is one higher than the count taken from the same counter run for prev_period. | killed | a_duty_count_captures_on_fall |
| 14 | 3 | boundary | The saturation test reads the extra drift-headroom MSB as an overflow flag, so the period counter stops at 2^(CNT_W-1) (128) instead of the all-ones out-of-range marker. | killed | a_counter_advances_otherwise |
| 15 | 3 | wrong_event | The prev_period snapshot is copied into the falling-edge branch too, so the period export is overwritten at the end of HS conduction as well as at the start of the cycle. | killed | a_prev_period_stable_otherwise |
| 16 | 3 | other | The period counter is gated by the PWM level, as if it were an on-time counter, so it stops during the LS phase and does not span the whole switching period. | killed | a_counter_advances_otherwise |
| 17 | 4 | field | The drift-headroom MSB of the period counter is treated as internal only and is dropped from the prev_period export, so the exported period is taken modulo 2^(CNT_W-1). | killed | a_duty_within_period, a_prev_period_captures_on_rise |
| 18 | 4 | missing_case | The saturation hold is applied only to a stall with pwm_sync held low (a dead modulator taken to mean PWM low). The stalled-high case named in the comment is left out, so the counter wraps. | killed | a_counter_holds_at_ceiling, a_counter_never_wraps |
| 19 | 4 | sequencing | The start-of-cycle strobe pwm_rise is registered, unlike pwm_fall, so the period counter is restarted one clock after the rising edge while the duty snapshot still uses the combinational fall. | killed | a_counter_clears_on_rise, a_prev_period_captures_on_rise +6 |
| 20 | 5 | sequencing | The out-of-range marker is published to prev_period as soon as period_counter saturates, mid-period, instead of when the next rising edge closes the stalled period. | killed | a_prev_period_stable_otherwise |
| 21 | 5 | wrong_event | 'Both captured from the same counter run' is misread as 'both captured at the same rising edge', so duty_count is also loaded with the full period count at every rising edge. | killed | a_duty_count_stable_otherwise |
| 22 | 6 | field | The duty snapshot is assumed never to exceed the nominal period (111 < 128), so the drift-headroom MSB of period_counter is dropped from duty_count and the high-phase length is exported modulo 2^(CNT_W-1). | killed | a_duty_count_captures_on_fall |
| 23 | 6 | reset_init | The out-of-range marker is made sticky: a rising edge that ends a saturated period captures all-ones into prev_period but does not restart period_counter, so the counter stays saturated until reset. | killed | a_counter_clears_on_rise |

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `pwm_stats.75.EDG.1` | posedge clk -> negedge clk | 7:killed | a_counter_clears_on_rise, a_prev_period_captures_on_rise +1 |
| `pwm_stats.84.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 7:survived |  |
| `pwm_stats.84.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 7:killed | a_counter_advances_otherwise, a_prev_period_stable_otherwise |
| `pwm_stats.84.UOD.1` | drop the '!' before rst_n | 7:killed | a_counter_advances_otherwise, a_prev_period_stable_otherwise +1 |
| `pwm_stats.86.CST.1` | 0 -> 1 | 7:survived |  |
| `pwm_stats.86.SDL.1` | delete 'pwm_sync_d <= 0;' | 7:survived |  |
| `pwm_stats.92.SDL.1` | delete 'pwm_sync_d <= pwm_sync;' | 7:killed | a_counter_advances_otherwise, a_prev_period_stable_otherwise |
| `pwm_stats.92.SIB.1` | pwm_sync -> pwm_fall | 7:killed | a_counter_advances_otherwise, a_prev_period_stable_otherwise |
| `pwm_stats.92.SIB.2` | pwm_sync -> pwm_rise | 7:killed | a_counter_never_wraps, a_counter_advances_otherwise +2 |
| `pwm_stats.92.STK.1` | pwm_sync_d stuck at all-zeros (was 'pwm_sync') | 7:killed | a_counter_advances_otherwise, a_prev_period_stable_otherwise |
| `pwm_stats.92.STK.2` | pwm_sync_d stuck at all-ones (was 'pwm_sync') | 7:killed | a_duty_count_stable_otherwise, a_counter_clears_on_rise +2 |
| `pwm_stats.92.VNG.1` | pwm_sync_d inverted (was 'pwm_sync') | 7:killed | a_duty_count_stable_otherwise, a_counter_clears_on_rise +6 |
| `pwm_stats.104.AIM.7` | PWM polarity misremembered as active-low: the switching period is taken from falling edge to falling edge and the duty snapshot is taken on the rising edge, so duty_count measures the low (LS) phase instead of HS conduction. | 7:killed | a_counter_clears_on_rise, a_duty_within_period +6 |
| `pwm_stats.104.CTD.1` | drop the term 'pwm_sync_d' | 7:killed | a_duty_count_stable_otherwise |
| `pwm_stats.104.CTD.2` | drop the term '~pwm_sync' | 7:killed | a_duty_count_stable_otherwise, a_duty_within_period |
| `pwm_stats.104.CTN.1` | negate the term 'pwm_sync_d' | 7:killed | a_duty_count_stable_otherwise, a_duty_count_captures_on_fall |
| `pwm_stats.104.DLY.1` | pwm_sync_d -> pwm_sync | 7:killed | a_duty_count_captures_on_fall |
| `pwm_stats.104.DLY.2` | pwm_sync -> pwm_sync_d | 7:killed | a_duty_count_captures_on_fall |
| `pwm_stats.104.LCR.1` | & -> \| | 7:killed | a_duty_count_stable_otherwise, a_duty_within_period |
| `pwm_stats.104.SDL.1` | delete 'pwm_fall = pwm_sync_d & ~pwm_sync;' | 7:lint | make lint: UNDRIVEN |
| `pwm_stats.104.SIB.1` | pwm_sync -> pwm_fall | 7:lint | make lint: ALWCOMBORDER, UNOPTFLAT |
| `pwm_stats.104.SIB.2` | pwm_sync -> pwm_rise | 7:killed | a_duty_count_stable_otherwise, a_duty_within_period |
| `pwm_stats.104.STK.1` | pwm_fall stuck at all-zeros (was 'pwm_sync_d & ~pwm_sync') | 7:killed | a_duty_count_captures_on_fall |
| `pwm_stats.104.STK.2` | pwm_fall stuck at all-ones (was 'pwm_sync_d & ~pwm_sync') | 7:killed | a_duty_count_stable_otherwise, a_duty_within_period |
| `pwm_stats.104.UOD.1` | drop the '~' before pwm_sync | 7:killed | a_duty_count_stable_otherwise, a_duty_within_period +1 |
| `pwm_stats.104.VNG.1` | pwm_fall inverted (was 'pwm_sync_d & ~pwm_sync') | 7:killed | a_duty_count_stable_otherwise, a_duty_within_period +1 |
| `pwm_stats.105.AIM.19` | The start-of-cycle strobe pwm_rise is registered, unlike pwm_fall, so the period counter is restarted one clock after the rising edge while the duty snapshot still uses the combinational fall. | 7:killed | a_counter_clears_on_rise, a_prev_period_captures_on_rise +6 |
| `pwm_stats.105.AIM.8` | The start-of-cycle detector fires on any PWM edge rather than only the rising edge, so the period counter is restarted at the end of HS conduction as well. | 7:killed | a_counter_never_wraps, a_counter_advances_otherwise +3 |
| `pwm_stats.105.CTD.1` | drop the term '~pwm_sync_d' | 7:killed | a_counter_advances_otherwise, a_prev_period_stable_otherwise |
| `pwm_stats.105.CTD.2` | drop the term 'pwm_sync' | 7:killed | a_counter_advances_otherwise, a_counter_never_wraps +3 |
| `pwm_stats.105.CTN.1` | negate the term 'pwm_sync' | 7:killed | a_counter_advances_otherwise, a_counter_clears_on_rise +4 |
| `pwm_stats.105.DLY.1` | pwm_sync_d -> pwm_sync | 7:killed | a_counter_clears_on_rise, a_prev_period_captures_on_rise +1 |
| `pwm_stats.105.DLY.2` | pwm_sync -> pwm_sync_d | 7:killed | a_counter_clears_on_rise, a_prev_period_captures_on_rise +1 |
| `pwm_stats.105.LCR.1` | & -> \| | 7:killed | a_counter_advances_otherwise, a_counter_never_wraps +1 |
| `pwm_stats.105.SDL.1` | delete 'pwm_rise = ~pwm_sync_d & pwm_sync;' | 7:lint | make lint: UNDRIVEN |
| `pwm_stats.105.SIB.1` | pwm_sync -> pwm_fall | 7:killed | a_counter_clears_on_rise, a_prev_period_captures_on_rise +1 |
| `pwm_stats.105.SIB.2` | pwm_sync -> pwm_rise | 7:lint | make lint: ALWCOMBORDER, UNOPTFLAT |
| `pwm_stats.105.STK.1` | pwm_rise stuck at all-zeros (was '~pwm_sync_d & pwm_sync') | 7:killed | a_counter_clears_on_rise, a_prev_period_captures_on_rise +1 |
| `pwm_stats.105.STK.2` | pwm_rise stuck at all-ones (was '~pwm_sync_d & pwm_sync') | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.105.UOD.1` | drop the '~' before pwm_sync_d | 7:killed | a_counter_clears_on_rise, a_prev_period_captures_on_rise +4 |
| `pwm_stats.105.VNG.1` | pwm_rise inverted (was '~pwm_sync_d & pwm_sync') | 7:killed | a_counter_advances_otherwise, a_counter_clears_on_rise +3 |
| `pwm_stats.107.EDG.1` | posedge clk -> negedge clk | 7:killed | a_counter_never_wraps, a_counter_advances_otherwise +6 |
| `pwm_stats.121.BDL.1` | empty the 3-statement body of the if at line 121 | 7:killed | a_outputs_zero_in_reset |
| `pwm_stats.121.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 7:killed | a_outputs_zero_in_reset |
| `pwm_stats.121.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.121.UOD.1` | drop the '!' before rst_n | 7:killed | a_outputs_zero_in_reset, a_counter_advances_otherwise |
| `pwm_stats.123.CST.1` | 0 -> 1 | 7:killed | a_outputs_zero_in_reset |
| `pwm_stats.123.SDL.1` | delete 'period_counter <= 0;' | 7:killed | a_outputs_zero_in_reset |
| `pwm_stats.124.CST.1` | 0 -> 1 | 7:killed | a_outputs_zero_in_reset |
| `pwm_stats.124.SDL.1` | delete 'duty_count <= 0;' | 7:killed | a_outputs_zero_in_reset |
| `pwm_stats.125.CST.1` | 0 -> 1 | 7:killed | a_outputs_zero_in_reset |
| `pwm_stats.125.SDL.1` | delete 'prev_period <= 0;' | 7:killed | a_outputs_zero_in_reset |
| `pwm_stats.129.AIM.1` | The saturation hold takes precedence over pwm_rise, so a rising edge seen while period_counter is saturated neither captures prev_period nor restarts the counter. | 7:killed | a_counter_clears_on_rise, a_duty_within_period +1 |
| `pwm_stats.129.BDL.1` | empty the 2-statement body of the if at line 129 | 7:killed | a_counter_clears_on_rise, a_prev_period_captures_on_rise +1 |
| `pwm_stats.129.CND.1` | if (pwm_rise) -> if (!(...)) | 7:killed | a_counter_advances_otherwise, a_counter_clears_on_rise +3 |
| `pwm_stats.129.CSK.1` | if (pwm_rise) -> if (1'b0): never taken | 7:lint | make lint: UNUSEDSIGNAL |
| `pwm_stats.129.CSK.2` | if (pwm_rise) -> if (1'b1): always taken | 7:lint | make lint: UNUSEDSIGNAL |
| `pwm_stats.129.EDL.1` | delete the else branch at line 129 | 7:lint | make lint: UNUSEDSIGNAL |
| `pwm_stats.129.SIB.1` | pwm_rise -> pwm_fall | 7:lint | make lint: UNUSEDSIGNAL |
| `pwm_stats.129.SIB.2` | pwm_rise -> pwm_sync | 7:lint | make lint: UNUSEDSIGNAL |
| `pwm_stats.131.AIM.17` | The drift-headroom MSB of the period counter is treated as internal only and is dropped from the prev_period export, so the exported period is taken modulo 2^(CNT_W-1). | 7:killed | a_duty_within_period, a_prev_period_captures_on_rise |
| `pwm_stats.131.AIM.6` | prev_period adds one for the rise clock, so the period is counted differently from duty_count, which is taken from the same counter run without the +1. | 7:killed | a_prev_period_captures_on_rise, a_duty_within_period |
| `pwm_stats.131.AIM.9` | A rising edge that ends a saturated (stalled) period is treated as invalid and does not update prev_period, so the all-ones out-of-range marker is never exported. | 7:killed | a_duty_within_period, a_prev_period_captures_on_rise |
| `pwm_stats.131.SDL.1` | delete 'prev_period <= period_counter;' | 7:killed | a_prev_period_captures_on_rise, a_duty_within_period |
| `pwm_stats.131.STK.1` | prev_period stuck at all-zeros (was 'period_counter') | 7:killed | a_prev_period_captures_on_rise, a_duty_within_period |
| `pwm_stats.131.STK.2` | prev_period stuck at all-ones (was 'period_counter') | 7:killed | a_prev_period_captures_on_rise |
| `pwm_stats.131.VNG.1` | prev_period inverted (was 'period_counter') | 7:killed | a_prev_period_captures_on_rise, a_duty_within_period |
| `pwm_stats.132.AIM.21` | 'Both captured from the same counter run' is misread as 'both captured at the same rising edge', so duty_count is also loaded with the full period count at every rising edge. | 7:killed | a_duty_count_stable_otherwise |
| `pwm_stats.132.AIM.23` | The out-of-range marker is made sticky: a rising edge that ends a saturated period captures all-ones into prev_period but does not restart period_counter, so the counter stays saturated until reset. | 7:killed | a_counter_clears_on_rise |
| `pwm_stats.132.CST.1` | 0 -> 1 | 7:killed | a_counter_clears_on_rise |
| `pwm_stats.132.SDL.1` | delete 'period_counter <= 0;' | 7:killed | a_counter_clears_on_rise |
| `pwm_stats.133.AIM.5` | duty_count is cleared at the start of every switching period as if it were run state, but it is a held snapshot that should keep the last high-phase length. | 7:killed | a_duty_count_stable_otherwise |
| `pwm_stats.144.AIM.10` | The saturation test looks ahead at the next count, so the period counter stops one short at all-ones minus one instead of reaching the all-ones out-of-range marker. | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.144.AIM.14` | The saturation test reads the extra drift-headroom MSB as an overflow flag, so the period counter stops at 2^(CNT_W-1) (128) instead of the all-ones out-of-range marker. | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.144.AIM.18` | The saturation hold is applied only to a stall with pwm_sync held low (a dead modulator taken to mean PWM low). The stalled-high case named in the comment is left out, so the counter wraps. | 7:killed | a_counter_holds_at_ceiling, a_counter_never_wraps |
| `pwm_stats.144.AIM.2` | pwm_fall is handled before the saturation hold, so a falling edge on a saturated counter takes the normal fall branch and increments the counter past all-ones. | 7:killed | a_counter_holds_at_ceiling, a_counter_never_wraps +1 |
| `pwm_stats.144.AIM.3` | Saturation applies only while PWM is high (the stall-high case named in the comment), and a stall with pwm_sync held low is forgotten. | 7:killed | a_counter_holds_at_ceiling, a_counter_never_wraps +1 |
| `pwm_stats.144.AIM.4` | The counter saturates at the nominal period CLKS_PER_SW (111) instead of the counter's all-ones limit, which forgets the drift headroom CNT_W was sized for. | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.144.CSK.1` | if (period_counter == '1) -> if (1'b0): never taken | 7:killed | a_counter_holds_at_ceiling, a_counter_never_wraps |
| `pwm_stats.144.CSK.2` | if (period_counter == '1) -> if (1'b1): always taken | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.144.CST.1` | '1 -> '0 | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.144.EDL.1` | delete the else branch at line 144 | 7:lint | make lint: UNUSEDSIGNAL |
| `pwm_stats.144.ROR.1` | == -> != | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.146.AIM.11` | When a stalled-high PWM finally falls, the saturated period counter is restarted at the fall as if measurement had recovered, rather than held until the next rising edge. | 7:killed | a_counter_holds_at_ceiling, a_counter_never_wraps +1 |
| `pwm_stats.146.AIM.22` | The duty snapshot is assumed never to exceed the nominal period (111 < 128), so the drift-headroom MSB of period_counter is dropped from duty_count and the high-phase length is exported modulo 2^(CNT_W-1). | 7:killed | a_duty_count_captures_on_fall |
| `pwm_stats.146.CND.1` | if (pwm_fall) -> if (!(...)) | 7:killed | a_duty_within_period, a_duty_count_stable_otherwise |
| `pwm_stats.146.CSK.1` | if (pwm_fall) -> if (1'b1): always taken | 7:killed | a_duty_within_period, a_duty_count_stable_otherwise |
| `pwm_stats.146.SDL.1` | delete 'duty_count <= period_counter;' | 7:killed | a_duty_count_captures_on_fall |
| `pwm_stats.146.SIB.1` | pwm_fall -> pwm_rise | 7:killed | a_duty_count_captures_on_fall |
| `pwm_stats.146.SIB.2` | pwm_fall -> pwm_sync | 7:killed | a_duty_within_period, a_duty_count_stable_otherwise |
| `pwm_stats.146.STK.1` | duty_count stuck at all-zeros (was 'period_counter') | 7:killed | a_duty_count_captures_on_fall |
| `pwm_stats.146.STK.2` | duty_count stuck at all-ones (was 'period_counter') | 7:survived |  |
| `pwm_stats.146.VNG.1` | duty_count inverted (was 'period_counter') | 7:killed | a_duty_count_captures_on_fall |
| `pwm_stats.147.AIM.20` | The out-of-range marker is published to prev_period as soon as period_counter saturates, mid-period, instead of when the next rising edge closes the stalled period. | 7:killed | a_prev_period_stable_otherwise |
| `pwm_stats.150.AIM.12` | The duty snapshot is taken on the PWM low level instead of on the falling edge, so duty_count keeps being overwritten throughout the low phase. | 7:killed | a_duty_count_stable_otherwise |
| `pwm_stats.150.BDL.1` | empty the 2-statement body of the if at line 150 | 7:killed | a_counter_advances_otherwise, a_duty_count_captures_on_fall |
| `pwm_stats.150.CND.1` | if (pwm_fall) -> if (!(...)) | 7:killed | a_duty_count_stable_otherwise, a_duty_within_period +1 |
| `pwm_stats.150.CSK.1` | if (pwm_fall) -> if (1'b0): never taken | 7:killed | a_duty_count_captures_on_fall |
| `pwm_stats.150.CSK.2` | if (pwm_fall) -> if (1'b1): always taken | 7:killed | a_duty_count_stable_otherwise, a_duty_within_period |
| `pwm_stats.150.EDL.1` | delete the else branch at line 150 | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.150.SIB.1` | pwm_fall -> pwm_rise | 7:killed | a_duty_count_captures_on_fall |
| `pwm_stats.150.SIB.2` | pwm_fall -> pwm_sync | 7:killed | a_duty_count_stable_otherwise, a_duty_within_period +1 |
| `pwm_stats.152.AIM.13` | The falling-edge clock is counted as part of HS conduction, so duty_count is one higher than the count taken from the same counter run for prev_period. | 7:killed | a_duty_count_captures_on_fall |
| `pwm_stats.152.SDL.1` | delete 'duty_count <= period_counter;' | 7:killed | a_duty_count_captures_on_fall |
| `pwm_stats.152.STK.1` | duty_count stuck at all-zeros (was 'period_counter') | 7:killed | a_duty_count_captures_on_fall |
| `pwm_stats.152.STK.2` | duty_count stuck at all-ones (was 'period_counter') | 7:killed | a_duty_count_captures_on_fall, a_duty_within_period |
| `pwm_stats.152.VNG.1` | duty_count inverted (was 'period_counter') | 7:killed | a_duty_count_captures_on_fall, a_duty_within_period |
| `pwm_stats.153.AIM.15` | The prev_period snapshot is copied into the falling-edge branch too, so the period export is overwritten at the end of HS conduction as well as at the start of the cycle. | 7:killed | a_prev_period_stable_otherwise |
| `pwm_stats.153.AOR.1` | + -> - | 7:killed | a_counter_never_wraps, a_counter_advances_otherwise |
| `pwm_stats.153.CST.1` | 1 -> 0 | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.153.CST.2` | 1 -> 2 | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.153.SDL.1` | delete 'period_counter <= period_counter + 1;' | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.153.STK.1` | period_counter stuck at all-zeros (was 'period_counter + 1') | 7:killed | a_counter_never_wraps, a_counter_advances_otherwise |
| `pwm_stats.153.STK.2` | period_counter stuck at all-ones (was 'period_counter + 1') | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.153.VNG.1` | period_counter inverted (was 'period_counter + 1') | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.159.AIM.16` | The period counter is gated by the PWM level, as if it were an on-time counter, so it stops during the LS phase and does not span the whole switching period. | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.159.AOR.1` | + -> - | 7:killed | a_counter_advances_otherwise, a_counter_never_wraps |
| `pwm_stats.159.CST.1` | 1 -> 0 | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.159.CST.2` | 1 -> 2 | 7:killed | a_counter_advances_otherwise, a_counter_never_wraps |
| `pwm_stats.159.SDL.1` | delete 'period_counter <= period_counter + 1;' | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.159.STK.1` | period_counter stuck at all-zeros (was 'period_counter + 1') | 7:killed | a_counter_advances_otherwise, a_counter_never_wraps |
| `pwm_stats.159.STK.2` | period_counter stuck at all-ones (was 'period_counter + 1') | 7:killed | a_counter_advances_otherwise |
| `pwm_stats.159.VNG.1` | period_counter inverted (was 'period_counter + 1') | 7:killed | a_counter_never_wraps, a_counter_advances_otherwise |
