# Mutation record: strike_counter

`rtl-systemverilog/protect/strike_counter.sv`. Written by `tools/mutation/record.py` from `strike_counter.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 118 | 76 | 28 | 0 | 0 | 14 | 0 | 0 | 88.1% |
| AI-written | 33 | 25 | 0 | 0 | 0 | 8 | 0 | 0 | 75.8% |
| all | 151 | 101 | 28 | 0 | 0 | 22 | 0 | 0 | 85.4% |

Survivors: 22 - 5 decided equivalent, 6 accepted, 11 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 92.1%.
2 earlier mutants are not in these numbers: 2 AI-written ones the designer withdrew, 0 the generator no longer makes because the RTL changed. Their history is kept below.

## Survivors (22)

### `strike_counter.63.BDL.1` - empty the 2-statement body of the if at line 63

- before: `if(!rst_n) begin`
- after: `if(!rst_n) begin end`
- AI judgement (step 9): **plausible**, high confidence - With the reset body empty, hiccup_active_d and pwm_sync_d keep their old or X power-up values instead of 0. So hiccup_entry (line 93) and pwm_fall (line 94) can differ on the first edges after reset, which changes strike_level and latch_assert.
- designer's decision (step 10): **gap** - reset values of the delay flops and clean counter untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run

### `strike_counter.63.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n) begin`
- after: `if(1'b0) begin`
- AI judgement (step 9): **plausible**, high confidence - With the reset branch at line 63 never taken, hiccup_active_d and pwm_sync_d are never forced to 0. They power up as X and follow their inputs during reset. If hiccup_active is high when reset releases, the entry pulse at line 93 is lost or becomes X, which changes strike_level and latch_assert.
- designer's decision (step 10): **gap** - reset values of the delay flops and clean counter untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run

### `strike_counter.65.CST.1` - 0 -> 1

- before: `hiccup_active_d <= 0;`
- after: `hiccup_active_d <= 1;`
- AI judgement (step 9): **plausible**, high confidence - If hiccup_active_d resets to 1 and hiccup_active is high on the first edge after reset, line 93 sees no entry. The original counts a strike there (lines 132-136).
- designer's decision (step 10): **gap** - reset values of the delay flops and clean counter untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run

### `strike_counter.65.SDL.1` - delete 'hiccup_active_d <= 0;'

- before: `hiccup_active_d <= 0;`
- after: `;`
- AI judgement (step 9): **plausible**, high confidence - hiccup_active_d is no longer reset. It is X at power-up, or keeps 1 across a mid-run reset. If hiccup_active is high on the first edge after reset, hiccup_entry (line 93) can be X or 0 instead of 1, which changes strike_level and latch_assert.
- designer's decision (step 10): **gap** - reset values of the delay flops and clean counter untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run

### `strike_counter.66.CST.1` - 0 -> 1

- before: `pwm_sync_d <= 0;`
- after: `pwm_sync_d <= 1;`
- AI judgement (step 9): **plausible**, medium confidence - With pwm_sync_d reset to 1, run_active=1 and pwm_sync=0 on the first edge after reset gives a false pwm_fall (line 94). clean_counter then increments one cycle early, which can move the strike clear at line 140.
- designer's decision (step 10): **gap** - reset values of the delay flops and clean counter untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run

### `strike_counter.66.SDL.1` - delete 'pwm_sync_d <= 0;'

- before: `pwm_sync_d <= 0;`
- after: `;`
- AI judgement (step 9): **plausible**, medium confidence - pwm_sync_d is X at power-up, or keeps 1 across a reset. If run_active is high and pwm_sync is 0 on the first edge after reset, pwm_fall (line 94) differs, so clean_counter (lines 182-191) and then the strike clear at line 140 differ. The header does not rule out run_active being high at that point.
- designer's decision (step 10): **gap** - reset values of the delay flops and clean counter untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run

### `strike_counter.72.AIM.19` - The PWM delay flop updates only in S_RUN, so on re-entry to S_RUN it compares against a stale PWM level from the previous run

- before: `pwm_sync_d <= pwm_sync;`
- after: `if (run_active) pwm_sync_d <= pwm_sync;`
- AI judgement (step 9): **plausible**, high confidence - pwm_sync_d stays frozen at its last S_RUN value. On the first edge of a new run, pwm_fall (line 94) compares pwm_sync with that stale level, not the previous clock's. This can add or drop a clean-cycle count at line 182 and shift the strike clear at line 140.
- designer's decision (step 15): **accepted** - shifts of one clock or one switching cycle: forgiveness on a 1 s window, or the latch 100 ns before the hiccup entry that sets it anyway

### `strike_counter.132.AIM.22` - The latch is armed on the run-window trip that leads to the final hiccup, one clock before that hiccup is entered

- before: `else if (hiccup_entry) begin`
- after: `else if (window_trip && strike_level >= max_strikes - 1'b1) begin /  / latch_assert <= 1'b1; /  / end /  / else if (hiccup_entry) begin`
- AI judgement (step 9): **plausible**, high confidence - latch_assert now sets on a window_trip with strike_level >= max_strikes-1, with no hiccup entry needed. It can rise earlier, or rise when no further hiccup ever happens, and it is a port.
- designer's decision (step 15): **accepted** - shifts of one clock or one switching cycle: forgiveness on a 1 s window, or the latch 100 ns before the hiccup entry that sets it anyway

### `strike_counter.140.AIM.28` - The strike clear fires when the clean count is at or above clean_run_target, while the clean-run counter itself saturates only on an exact match

- before: `else if (clean_counter == clean_run_target) begin`
- after: `else if (clean_counter >= clean_run_target) begin`
- AI judgement (step 9): **plausible**, high confidence - clean_run_target can be lowered below the running count while strike_level is nonzero, so clean_counter > target is reachable. The mutant then clears strike_level at once; the original waits for the wrap back to exact equality.
- designer's decision (step 14): **accepted** - differ only if clean_run_target is lowered below the running count; it changes only in S_OFF, where the counter is zero

### `strike_counter.140.AIM.29` - A window_trip on the clock the clean run completes cancels the strike forgiveness, although the run had already earned it

- before: `else if (clean_counter == clean_run_target) begin`
- after: `else if (clean_counter == clean_run_target && !window_trip) begin`
- AI judgement (step 9): **plausible**, high confidence - On an edge where clean_counter == clean_run_target and window_trip is high, the original clears strike_level and the mutant does not. clean_counter is then zeroed (line 176), so the strikes stay.
- designer's decision (step 12): **gap** - a window trip on the clock the clean run completes is never tested; the earned forgiveness must still clear the strikes

### `strike_counter.143.AIM.34` - A completed clean run clears latch_assert along with the strike count, as though forgiveness reset the whole protection state, although latch_assert is meant to be set-only and cleared by rst_n alone

- before: ``
- after: `latch_assert <= 1'b0; / `
- AI judgement (step 9): **plausible**, high confidence - A completed clean run (line 140) now also clears latch_assert. After latching, a later clean run in S_RUN would drop the latch_assert output, which only rst_n clears in the original.
- designer's decision (step 11): **gap** - latch_assert must be cleared by reset alone, but no test runs a clean window after the latch; needs a clean run after latching with latch_assert checked to stay high

### `strike_counter.165.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n) begin`
- after: `if(1'b0) begin`
- AI judgement (step 9): **plausible**, high confidence - clean_counter is never asynchronously reset. It is X at power-up until a synchronous clear, and keeps counting through reset if run_active is high. The comparison at line 140 can then go X or fire at a different time, which changes strike_level.
- designer's decision (step 10): **gap** - reset values of the delay flops and clean counter untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run

### `strike_counter.167.CST.1` - 0 -> 1

- before: `clean_counter <= 0;`
- after: `clean_counter <= 1;`
- AI judgement (step 9): **plausible**, high confidence - clean_counter resets to 1. With clean_run_target=1 the strike clear at line 140 condition is true immediately, and in general the count reaches target one cycle earlier if run_active is high from reset.
- designer's decision (step 10): **gap** - reset values of the delay flops and clean counter untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run

### `strike_counter.167.SDL.1` - delete 'clean_counter <= 0;'

- before: `clean_counter <= 0;`
- after: `;`
- AI judgement (step 9): **plausible**, high confidence - clean_counter keeps its value through rst_n (or is X at power-up). After reset it can reach clean_run_target earlier than from 0, or compare as X at line 140.
- designer's decision (step 10): **gap** - reset values of the delay flops and clean counter untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run

### `strike_counter.176.AIM.18` - A switching-cycle boundary outranks the streak break, so a PWM fall on the clock S_RUN is left still counts as a clean cycle

- before: `else if (!run_active || window_trip) begin`
- after: `else if ((!run_active || window_trip) && !pwm_fall) begin`
- AI judgement (step 9): **plausible**, high confidence - When run_active is low and pwm_fall is high, the mutant skips the clear and increments clean_counter. For example, on the hiccup-entry edge a run streak survives into the hiccup and can later clear strikes the original would keep.
- designer's decision (step 15): **accepted** - shifts of one clock or one switching cycle: forgiveness on a 1 s window, or the latch 100 ns before the hiccup entry that sets it anyway

### `strike_counter.184.AIM.10` - The clean-run counter saturates at all-ones, the old fixed terminal, instead of holding at clean_run_target

- before: `if(clean_counter == clean_run_target) begin`
- after: `if(&clean_counter) begin`
- AI judgement (step 9): **plausible**, high confidence - If clean_run_target is lowered below clean_counter while strikes are held, the original wraps and comes back to the target, clearing strike_level. The mutant saturates at all-ones and never equals the target, so line 140 never clears the strikes.
- designer's decision (step 14): **accepted** - differ only if clean_run_target is lowered below the running count; it changes only in S_OFF, where the counter is zero

### `strike_counter.184.AIM.25` - The clean-run counter holds at any count at or above clean_run_target, but the strike clear still waits for an exact match. So if the target is lowered below the running count, the counter freezes at a value that can never equal it.

- before: `if(clean_counter == clean_run_target) begin`
- after: `if(clean_counter >= clean_run_target) begin`
- AI judgement (step 9): **plausible**, high confidence - If clean_run_target is lowered below clean_counter while strike_level is nonzero, the mutant freezes the counter above target and line 140 never fires. The original keeps counting, wraps and reaches the target, which clears strike_level.
- designer's decision (step 14): **accepted** - differ only if clean_run_target is lowered below the running count; it changes only in S_OFF, where the counter is zero

### `strike_counter.184.CSK.1` - if (clean_counter == clean_run_target) -> if (1'b0): never taken

- before: `if(clean_counter == clean_run_target) begin`
- after: `if(1'b0) begin`
- AI judgement (step 9): **equivalent**, medium confidence - The versions first diverge on a pwm_fall edge in S_RUN with clean_counter == target. On that same edge line 140 clears strike_level in both, because hiccup_entry needs hiccup_active, which is exclusive with run_active per the header (lines 33-34). strike_level then stays 0 until a hiccup_entry, and that edge has run_active=0, so line 176 zeroes clean_counter in both and they reconverge.
- designer's decision (step 13): **equivalent** - after the count reaches clean_run_target the strikes are cleared; strike_level then changes only on hiccup entry, which requires leaving S_RUN, which clears the counter, so its later value never reaches an output

### `strike_counter.186.SDL.1` - delete 'clean_counter <= clean_counter;'

- before: `clean_counter <= clean_counter;`
- after: `;`
- AI judgement (step 9): **equivalent**, high confidence - In a clocked always_ff, assigning clean_counter to itself is the same as not assigning it. The flop holds its value either way.
- designer's decision (step 13): **equivalent** - after the count reaches clean_run_target the strikes are cleared; strike_level then changes only on hiccup entry, which requires leaving S_RUN, which clears the counter, so its later value never reaches an output

### `strike_counter.186.STK.1` - clean_counter stuck at all-zeros (was 'clean_counter')

- before: `clean_counter <= clean_counter;`
- after: `clean_counter <= '0;`
- AI judgement (step 9): **equivalent**, medium confidence - This line only runs on a pwm_fall edge in S_RUN with clean_counter == target. On that edge line 140 clears strike_level in both versions; no hiccup_entry is possible because hiccup_active and run_active are exclusive per lines 33-34. Strikes stay 0 until a hiccup_entry, which needs run_active=0, so line 176 resets clean_counter in both and the different counter values are never seen.
- designer's decision (step 13): **equivalent** - after the count reaches clean_run_target the strikes are cleared; strike_level then changes only on hiccup entry, which requires leaving S_RUN, which clears the counter, so its later value never reaches an output

### `strike_counter.186.STK.2` - clean_counter stuck at all-ones (was 'clean_counter')

- before: `clean_counter <= clean_counter;`
- after: `clean_counter <= '1;`
- AI judgement (step 9): **equivalent**, medium confidence - Same argument as the other line-186 edits. Divergence starts on an edge where line 140 already clears strike_level. strike_level is then 0 until a hiccup_entry, and that edge has run_active=0 (exclusive per lines 33-34), so line 176 zeroes clean_counter in both. The all-ones value never reaches a port.
- designer's decision (step 13): **equivalent** - after the count reaches clean_run_target the strikes are cleared; strike_level then changes only on hiccup entry, which requires leaving S_RUN, which clears the counter, so its later value never reaches an output

### `strike_counter.186.VNG.1` - clean_counter inverted (was 'clean_counter')

- before: `clean_counter <= clean_counter;`
- after: `clean_counter <= ~(clean_counter);`
- AI judgement (step 9): **equivalent**, medium confidence - Writing ~clean_counter only happens on an edge where clean_counter == target, and line 140 clears strike_level on that same edge in both versions. Until the next hiccup_entry (run_active=0, so line 176 clears the counter in both), the strike clear can only write 0 to a strike_level that is already 0.
- designer's decision (step 13): **equivalent** - after the count reaches clean_run_target the strikes are cleared; strike_level then changes only on hiccup entry, which requires leaving S_RUN, which clears the counter, so its later value never reaches an output

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-17 00:55 | 530e2fe | AI wrote mutants (claude-opus-5-5) | asked 10, proposed 8, accepted 6, rejected 2; `ai_runs/2026-11-17_write_mutants_14` |
| 2 | 2026-11-17 00:59 | 530e2fe | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 6, accepted 6, rejected 0; `ai_runs/2026-11-17_write_mutants_15` |
| 3 | 2026-11-17 01:03 | 530e2fe | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 7, accepted 7, rejected 0; `ai_runs/2026-11-17_write_mutants_16` |
| 4 | 2026-11-17 01:07 | 530e2fe | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 5, accepted 5, rejected 0; `ai_runs/2026-11-17_write_mutants_17` |
| 5 | 2026-11-17 01:25 | 530e2fe | AI wrote mutants (claude-opus-5-5) | asked 120, proposed 12, accepted 11, rejected 1; `ai_runs/2026-11-17_write_mutants_18` |
| 6 | 2026-11-17 07:09 | 530e2fe | designer withdrew AI-written mutants | strike_counter.140.AIM.9 - same output as AIM.17: the strike clear never fires, so strikes are never forgiven |
| 7 | 2026-11-17 07:10 | 530e2fe | designer withdrew AI-written mutants | strike_counter.176.AIM.30 - part of AIM.21: the count survives only the exit into S_HICCUP, which AIM.21 also does; any test that kills AIM.21 on a hiccup exit kills it |
| 8 | 2026-11-17 07:34 | 530e2fe | mutation run - every mutant of the module | 151 mutants: 101 killed, 28 lint, 22 survived; score 85.4% |
| 9 | 2026-11-17 08:22 | 530e2fe | AI judged survivors (claude-opus-5-5) | 22 judged, 1 called equivalent with high confidence; `ai_runs/2026-11-17_judge_survivors_3` |
| 10 | 2026-11-17 09:11 | 530e2fe | designer's decision: gap | strike_counter.63.BDL.1, strike_counter.63.CSK.1, strike_counter.65.CST.1, strike_counter.65.SDL.1, strike_counter.66.CST.1, strike_counter.66.SDL.1, strike_counter.165.CSK.1, strike_counter.167.CST.1, strike_counter.167.SDL.1 - reset values of the delay flops and clean counter untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run |
| 11 | 2026-11-17 09:11 | 530e2fe | designer's decision: gap | strike_counter.143.AIM.34 - latch_assert must be cleared by reset alone, but no test runs a clean window after the latch; needs a clean run after latching with latch_assert checked to stay high |
| 12 | 2026-11-17 09:11 | 530e2fe | designer's decision: gap | strike_counter.140.AIM.29 - a window trip on the clock the clean run completes is never tested; the earned forgiveness must still clear the strikes |
| 13 | 2026-11-17 09:11 | 530e2fe | designer's decision: equivalent | strike_counter.186.SDL.1, strike_counter.186.STK.1, strike_counter.186.STK.2, strike_counter.186.VNG.1, strike_counter.184.CSK.1 - after the count reaches clean_run_target the strikes are cleared; strike_level then changes only on hiccup entry, which requires leaving S_RUN, which clears the counter, so its later value never reaches an output |
| 14 | 2026-11-17 09:11 | 530e2fe | designer's decision: accepted | strike_counter.140.AIM.28, strike_counter.184.AIM.25, strike_counter.184.AIM.10 - differ only if clean_run_target is lowered below the running count; it changes only in S_OFF, where the counter is zero |
| 15 | 2026-11-17 09:11 | 530e2fe | designer's decision: accepted | strike_counter.176.AIM.18, strike_counter.72.AIM.19, strike_counter.132.AIM.22 - shifts of one clock or one switching cycle: forgiveness on a 1 s window, or the latch 100 ns before the hiccup entry that sets it anyway |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (35)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | wrong_event | A strike is counted when the supervisor leaves S_HICCUP instead of when it enters it | killed | a_strike_per_entry, a_level_moves_by_known_path +3 |
| 2 | 1 | wrong_event | The clean-run cycle boundary is taken on the PWM rising edge instead of the falling edge | killed | a_clear_earned, a_level_moves_by_known_path |
| 3 | 1 | boundary | The latch test matches MAX_STRIKES-1 exactly instead of at-or-above, so a limit lowered below the count already reached is missed | killed | a_last_strike_trips |
| 4 | 1 | other | window_trip pauses the clean-run count instead of restarting it | killed | a_clear_earned, a_level_moves_by_known_path |
| 5 | 1 | wrong_event | The latch also trips on the strike level alone, outside a hiccup entry | killed | a_latch_earned |
| 6 | 1 | reset_init | strike_level is zeroed when the latch trips, instead of keeping the count for telemetry | killed | a_strike_per_entry, a_level_moves_by_known_path |
| 7 | 2 | boundary | The latch test compares the post-increment strike count against MAX_STRIKES-1, so the -1 for the pre-increment value is applied twice | killed | a_latch_earned |
| 8 | 2 | wrong_event | The switching-cycle boundary is taken on both PWM edges, so each switching cycle counts twice toward the clean run | killed | a_clear_earned, a_level_moves_by_known_path |
| 9 | 2 | boundary | The strike clear still waits for the old all-ones terminal count instead of clean_run_target, although the counter now saturates at the target | withdrawn: same output as AIM.17: the strike clear never fires, so strikes are never forgiven |  |
| 10 | 2 | boundary | The clean-run counter saturates at all-ones, the old fixed terminal, instead of holding at clean_run_target | survived |  |
| 11 | 2 | sequencing | The strike clear waits for the next switching-cycle boundary after the clean run completes, instead of happening on the next clock | killed | a_clean_run_clears |
| 12 | 2 | other | A completed clean run forgives one strike instead of clearing the whole count, and keeps doing so while the clean count stays saturated | killed | a_clean_run_clears, a_level_moves_by_known_path +1 |
| 13 | 3 | wrong_event | A strike is counted on every change of hiccup_active, so both entering and leaving S_HICCUP add a strike | killed | a_level_moves_by_known_path, a_clear_earned +1 |
| 14 | 3 | boundary | strike_level is clamped at max_strikes-1, the deepest cool-down index, so the hiccup that trips the latch is not added to the count | killed | a_strike_per_entry |
| 15 | 3 | wrong_event | The latch is tested when the hiccup cool-down ends, on the post-increment count, instead of when the hiccup that reaches MAX_STRIKES begins | killed | a_last_strike_trips, a_latch_earned |
| 16 | 3 | boundary | The pre-increment -1 used by the latch test is copied into the clean-run clear, so strikes are forgiven one switching cycle before the clean run is complete | killed | a_clear_earned, a_level_moves_by_known_path |
| 17 | 3 | boundary | The clean-run counter saturates one cycle below clean_run_target, so it never reaches the value the strike clear waits for | killed | a_clean_run_clears |
| 18 | 3 | priority | A switching-cycle boundary outranks the streak break, so a PWM fall on the clock S_RUN is left still counts as a clean cycle | survived |  |
| 19 | 3 | sequencing | The PWM delay flop updates only in S_RUN, so on re-entry to S_RUN it compares against a stale PWM level from the previous run | survived |  |
| 20 | 4 | wrong_event | The clean-run streak is broken only on a switching-cycle boundary, so leaving S_RUN or a window trip between PWM falls leaves the saturated clean count standing | killed | a_clear_earned, a_level_moves_by_known_path |
| 21 | 4 | reset_init | Leaving S_RUN only pauses the clean-run count instead of clearing it; only window_trip restarts the streak | killed | a_clear_earned, a_level_moves_by_known_path |
| 22 | 4 | sequencing | The latch is armed on the run-window trip that leads to the final hiccup, one clock before that hiccup is entered | survived |  |
| 23 | 4 | boundary | The strike count saturates at MAX_STRIKES, so after the host lowers MAX_STRIKES below the count already reached, the latching hiccup is not counted | killed | a_strike_per_entry |
| 24 | 4 | boundary | A guard against the max_strikes-1 underflow is written with the wrong limit, so MAX_STRIKES=1 disables the latch | killed | a_last_strike_trips |
| 25 | 5 | boundary | The clean-run counter holds at any count at or above clean_run_target, but the strike clear still waits for an exact match. So if the target is lowered below the running count, the counter freezes at a value that can never equal it. | survived |  |
| 26 | 5 | reset_init | A completed clean run sets the strike count back to one strike, treated wrongly as the base cool-down level, instead of clearing it to no strikes. | killed | a_clean_run_clears, a_level_moves_by_known_path |
| 27 | 5 | wrong_event | The run-window trip is counted as a strike as well as the hiccup entry it causes, so every hiccup out of S_RUN adds two strikes | killed | a_clear_earned, a_level_moves_by_known_path |
| 28 | 5 | boundary | The strike clear fires when the clean count is at or above clean_run_target, while the clean-run counter itself saturates only on an exact match | survived |  |
| 29 | 5 | priority | A window_trip on the clock the clean run completes cancels the strike forgiveness, although the run had already earned it | survived |  |
| 30 | 5 | missing_case | The clean-run streak is broken by leaving S_RUN for any state except S_HICCUP, so a completed clean count survives into the cool-down | withdrawn: part of AIM.21: the count survives only the exit into S_HICCUP, which AIM.21 also does; any test that kills AIM.21 on a hiccup exit kills it |  |
| 31 | 5 | other | Copy-paste slip in the delay-flop block: pwm_sync_d is loaded from hiccup_active instead of pwm_sync, so the switching-cycle boundary pwm_fall only fires around a hiccup exit and never while the converter is in S_RUN | killed | a_clean_run_clears |
| 32 | 5 | other | Copy-paste slip in the delay-flop block: hiccup_active_d is loaded from pwm_sync instead of hiccup_active, so hiccup_entry is no longer a single pulse on entry into S_HICCUP | killed | a_level_moves_by_known_path, a_latch_earned +1 |
| 33 | 5 | sequencing | The strike clear tries to anticipate the clean-run counter reaching its target on the switching-cycle boundary, instead of waiting for the counter to actually hold clean_run_target | killed | a_clear_earned, a_level_moves_by_known_path |
| 34 | 5 | reset_init | A completed clean run clears latch_assert along with the strike count, as though forgiveness reset the whole protection state, although latch_assert is meant to be set-only and cleared by rst_n alone | survived |  |
| 35 | 5 | sequencing | The latch test is moved out of the hiccup-entry branch to a later point in the cool-down. It compares the count after it has landed with MAX_STRIKES while hiccup_active is high, instead of testing the count about to land on the entry clock. | killed | a_last_strike_trips, a_latch_earned |

Rejected by the gate in step 1 (2):

- The clean-run clear outranks hiccup entry, so a hiccup that ends a saturated clean run earns no strike - **changes 12 lines; at most 6**
- The clean-run streak is broken only by S_HICCUP, not by every exit from S_RUN, so cycles in soft-start count as clean - **make lint already catches it: make lint: UNUSEDSIGNAL**

Rejected by the gate in step 5 (1):

- The clean-run clear is nested inside hiccup_entry instead of being its sibling, so a completed clean run is forgiven only when the next hiccup begins (the count restarts at one strike) - **changes 8 lines; at most 6**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `strike_counter.54.EDG.1` | posedge clk -> negedge clk | 8:killed | a_strike_per_entry, a_last_strike_trips |
| `strike_counter.63.BDL.1` | empty the 2-statement body of the if at line 63 | 8:survived |  |
| `strike_counter.63.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 8:survived |  |
| `strike_counter.63.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 8:killed | a_level_moves_by_known_path, a_latch_earned +1 |
| `strike_counter.63.UOD.1` | drop the '!' before rst_n | 8:killed | a_level_moves_by_known_path, a_latch_earned +1 |
| `strike_counter.65.CST.1` | 0 -> 1 | 8:survived |  |
| `strike_counter.65.SDL.1` | delete 'hiccup_active_d <= 0;' | 8:survived |  |
| `strike_counter.66.CST.1` | 0 -> 1 | 8:survived |  |
| `strike_counter.66.SDL.1` | delete 'pwm_sync_d <= 0;' | 8:survived |  |
| `strike_counter.69.EDL.1` | delete the else branch at line 69 | 8:killed | a_level_moves_by_known_path, a_latch_earned +1 |
| `strike_counter.71.AIM.32` | Copy-paste slip in the delay-flop block: hiccup_active_d is loaded from pwm_sync instead of hiccup_active, so hiccup_entry is no longer a single pulse on entry into S_HICCUP | 8:killed | a_level_moves_by_known_path, a_latch_earned +1 |
| `strike_counter.71.SDL.1` | delete 'hiccup_active_d <= hiccup_active;' | 8:killed | a_level_moves_by_known_path, a_latch_earned +1 |
| `strike_counter.71.SIB.1` | hiccup_active -> hiccup_entry | 8:killed | a_level_moves_by_known_path, a_clear_earned +1 |
| `strike_counter.71.SIB.2` | hiccup_active -> run_active | 8:killed | a_level_moves_by_known_path, a_latch_earned +2 |
| `strike_counter.71.STK.1` | hiccup_active_d stuck at all-zeros (was 'hiccup_active') | 8:killed | a_level_moves_by_known_path, a_latch_earned +1 |
| `strike_counter.71.STK.2` | hiccup_active_d stuck at all-ones (was 'hiccup_active') | 8:killed | a_strike_per_entry, a_last_strike_trips |
| `strike_counter.71.VNG.1` | hiccup_active_d inverted (was 'hiccup_active') | 8:killed | a_strike_per_entry, a_level_moves_by_known_path +3 |
| `strike_counter.72.AIM.19` | The PWM delay flop updates only in S_RUN, so on re-entry to S_RUN it compares against a stale PWM level from the previous run | 8:survived |  |
| `strike_counter.72.AIM.31` | Copy-paste slip in the delay-flop block: pwm_sync_d is loaded from hiccup_active instead of pwm_sync, so the switching-cycle boundary pwm_fall only fires around a hiccup exit and never while the converter is in S_RUN | 8:killed | a_clean_run_clears |
| `strike_counter.72.SDL.1` | delete 'pwm_sync_d <= pwm_sync;' | 8:killed | a_clean_run_clears |
| `strike_counter.72.SIB.1` | pwm_sync -> pwm_fall | 8:killed | a_clean_run_clears |
| `strike_counter.72.STK.1` | pwm_sync_d stuck at all-zeros (was 'pwm_sync') | 8:killed | a_clean_run_clears |
| `strike_counter.72.STK.2` | pwm_sync_d stuck at all-ones (was 'pwm_sync') | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.72.VNG.1` | pwm_sync_d inverted (was 'pwm_sync') | 8:killed | a_clean_run_clears, a_clear_earned +1 |
| `strike_counter.93.AIM.1` | A strike is counted when the supervisor leaves S_HICCUP instead of when it enters it | 8:killed | a_strike_per_entry, a_level_moves_by_known_path +3 |
| `strike_counter.93.AIM.13` | A strike is counted on every change of hiccup_active, so both entering and leaving S_HICCUP add a strike | 8:killed | a_level_moves_by_known_path, a_clear_earned +1 |
| `strike_counter.93.CTD.1` | drop the term 'hiccup_active' | 8:killed | a_level_moves_by_known_path, a_latch_earned +2 |
| `strike_counter.93.CTD.2` | drop the term '~hiccup_active_d' | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.93.CTN.1` | negate the term 'hiccup_active' | 8:killed | a_level_moves_by_known_path, a_latch_earned +3 |
| `strike_counter.93.DLY.1` | hiccup_active -> hiccup_active_d | 8:killed | a_strike_per_entry, a_last_strike_trips |
| `strike_counter.93.DLY.2` | hiccup_active_d -> hiccup_active | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.93.LCR.1` | & -> \| | 8:killed | a_level_moves_by_known_path, a_latch_earned +2 |
| `strike_counter.93.SDL.1` | delete 'hiccup_entry = hiccup_active & ~hiccup_active_d;' | 8:lint | make lint: UNDRIVEN, UNUSEDSIGNAL |
| `strike_counter.93.SIB.1` | hiccup_active -> hiccup_entry | 8:lint | make lint: ALWCOMBORDER, UNOPTFLAT |
| `strike_counter.93.SIB.2` | hiccup_active -> run_active | 8:killed | a_strike_per_entry, a_last_strike_trips +4 |
| `strike_counter.93.STK.1` | hiccup_entry stuck at all-zeros (was 'hiccup_active & ~hiccup_active_d') | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.93.STK.2` | hiccup_entry stuck at all-ones (was 'hiccup_active & ~hiccup_active_d') | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.93.UOD.1` | drop the '~' before hiccup_active_d | 8:killed | a_strike_per_entry, a_level_moves_by_known_path +3 |
| `strike_counter.93.VNG.1` | hiccup_entry inverted (was 'hiccup_active & ~hiccup_active_d') | 8:killed | a_level_moves_by_known_path, a_latch_earned +3 |
| `strike_counter.94.AIM.2` | The clean-run cycle boundary is taken on the PWM rising edge instead of the falling edge | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.94.AIM.8` | The switching-cycle boundary is taken on both PWM edges, so each switching cycle counts twice toward the clean run | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.94.CTD.1` | drop the term 'pwm_sync_d' | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.94.CTD.2` | drop the term '~pwm_sync' | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.94.CTN.1` | negate the term 'pwm_sync_d' | 8:killed | a_clean_run_clears, a_clear_earned +1 |
| `strike_counter.94.DLY.1` | pwm_sync_d -> pwm_sync | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.94.DLY.2` | pwm_sync -> pwm_sync_d | 8:killed | a_clean_run_clears |
| `strike_counter.94.LCR.1` | & -> \| | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.94.SDL.1` | delete 'pwm_fall = pwm_sync_d & ~pwm_sync;' | 8:lint | make lint: UNDRIVEN, UNUSEDSIGNAL |
| `strike_counter.94.SIB.1` | pwm_sync -> pwm_fall | 8:lint | make lint: ALWCOMBORDER, UNOPTFLAT |
| `strike_counter.94.STK.1` | pwm_fall stuck at all-zeros (was 'pwm_sync_d & ~pwm_sync') | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.94.STK.2` | pwm_fall stuck at all-ones (was 'pwm_sync_d & ~pwm_sync') | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.94.UOD.1` | drop the '~' before pwm_sync | 8:killed | a_clean_run_clears, a_clear_earned +1 |
| `strike_counter.94.VNG.1` | pwm_fall inverted (was 'pwm_sync_d & ~pwm_sync') | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.99.EDG.1` | posedge clk -> negedge clk | 8:killed | a_level_moves_by_known_path, a_strike_per_entry +3 |
| `strike_counter.125.BDL.1` | empty the 2-statement body of the if at line 125 | 8:killed | a_reset_clears |
| `strike_counter.125.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 8:killed | a_reset_clears |
| `strike_counter.125.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 8:killed | a_strike_per_entry, a_last_strike_trips |
| `strike_counter.125.UOD.1` | drop the '!' before rst_n | 8:killed | a_strike_per_entry, a_last_strike_trips |
| `strike_counter.127.CST.1` | 1'b0 -> 1'b1 | 8:killed | a_reset_clears |
| `strike_counter.127.SDL.1` | delete 'latch_assert <= 1'b0;' | 8:killed | a_reset_clears |
| `strike_counter.128.CST.1` | '0 -> '1 | 8:killed | a_reset_clears |
| `strike_counter.128.SDL.1` | delete 'strike_level <= '0;' | 8:killed | a_reset_clears |
| `strike_counter.132.AIM.22` | The latch is armed on the run-window trip that leads to the final hiccup, one clock before that hiccup is entered | 8:survived |  |
| `strike_counter.132.AIM.27` | The run-window trip is counted as a strike as well as the hiccup entry it causes, so every hiccup out of S_RUN adds two strikes | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.132.BDL.1` | empty the 2-statement body of the if at line 132 | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.132.CND.1` | if (hiccup_entry) -> if (!(...)) | 8:killed | a_level_moves_by_known_path, a_latch_earned +3 |
| `strike_counter.132.CSK.1` | if (hiccup_entry) -> if (1'b0): never taken | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.132.CSK.2` | if (hiccup_entry) -> if (1'b1): always taken | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.132.EDL.1` | delete the else branch at line 132 | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.132.SIB.1` | hiccup_entry -> hiccup_active | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.134.AIM.14` | strike_level is clamped at max_strikes-1, the deepest cool-down index, so the hiccup that trips the latch is not added to the count | 8:killed | a_strike_per_entry |
| `strike_counter.134.AIM.23` | The strike count saturates at MAX_STRIKES, so after the host lowers MAX_STRIKES below the count already reached, the latching hiccup is not counted | 8:killed | a_strike_per_entry |
| `strike_counter.134.AOR.1` | + -> - | 8:killed | a_strike_per_entry, a_level_moves_by_known_path |
| `strike_counter.134.CST.1` | 1 -> 0 | 8:killed | a_strike_per_entry |
| `strike_counter.134.CST.2` | 1 -> 2 | 8:killed | a_strike_per_entry, a_level_moves_by_known_path |
| `strike_counter.134.SDL.1` | delete 'strike_level <= strike_level + 1;' | 8:killed | a_strike_per_entry |
| `strike_counter.134.STK.1` | strike_level stuck at all-zeros (was 'strike_level + 1') | 8:killed | a_strike_per_entry |
| `strike_counter.134.STK.2` | strike_level stuck at all-ones (was 'strike_level + 1') | 8:killed | a_strike_per_entry, a_level_moves_by_known_path |
| `strike_counter.134.VNG.1` | strike_level inverted (was 'strike_level + 1') | 8:killed | a_strike_per_entry, a_level_moves_by_known_path |
| `strike_counter.136.AIM.15` | The latch is tested when the hiccup cool-down ends, on the post-increment count, instead of when the hiccup that reaches MAX_STRIKES begins | 8:killed | a_last_strike_trips, a_latch_earned |
| `strike_counter.136.AIM.24` | A guard against the max_strikes-1 underflow is written with the wrong limit, so MAX_STRIKES=1 disables the latch | 8:killed | a_last_strike_trips |
| `strike_counter.136.AIM.3` | The latch test matches MAX_STRIKES-1 exactly instead of at-or-above, so a limit lowered below the count already reached is missed | 8:killed | a_last_strike_trips |
| `strike_counter.136.AIM.35` | The latch test is moved out of the hiccup-entry branch to a later point in the cool-down. It compares the count after it has landed with MAX_STRIKES while hiccup_active is high, instead of testing the count about to land on the entry clock. | 8:killed | a_last_strike_trips, a_latch_earned |
| `strike_counter.136.AIM.6` | strike_level is zeroed when the latch trips, instead of keeping the count for telemetry | 8:killed | a_strike_per_entry, a_level_moves_by_known_path |
| `strike_counter.136.AIM.7` | The latch test compares the post-increment strike count against MAX_STRIKES-1, so the -1 for the pre-increment value is applied twice | 8:killed | a_latch_earned |
| `strike_counter.136.AOR.1` | - -> + | 8:killed | a_latch_earned, a_last_strike_trips |
| `strike_counter.136.CND.1` | if (strike_level >= max_strikes - 1'b1) -> if (!(...)) | 8:killed | a_latch_earned, a_last_strike_trips |
| `strike_counter.136.CSK.1` | if (strike_level >= max_strikes - 1'b1) -> if (1'b1): always taken | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.136.CST.1` | 1'b1 -> 1'b0 | 8:killed | a_last_strike_trips |
| `strike_counter.136.CST.2` | 1'b1 -> 1'b0 | 8:killed | a_last_strike_trips |
| `strike_counter.136.ROR.1` | >= -> <= | 8:killed | a_latch_earned |
| `strike_counter.136.ROR.2` | >= -> > | 8:killed | a_last_strike_trips |
| `strike_counter.136.SDL.1` | delete 'latch_assert <= 1'b1;' | 8:killed | a_last_strike_trips |
| `strike_counter.140.AIM.11` | The strike clear waits for the next switching-cycle boundary after the clean run completes, instead of happening on the next clock | 8:killed | a_clean_run_clears |
| `strike_counter.140.AIM.16` | The pre-increment -1 used by the latch test is copied into the clean-run clear, so strikes are forgiven one switching cycle before the clean run is complete | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.140.AIM.28` | The strike clear fires when the clean count is at or above clean_run_target, while the clean-run counter itself saturates only on an exact match | 8:survived |  |
| `strike_counter.140.AIM.29` | A window_trip on the clock the clean run completes cancels the strike forgiveness, although the run had already earned it | 8:survived |  |
| `strike_counter.140.AIM.33` | The strike clear tries to anticipate the clean-run counter reaching its target on the switching-cycle boundary, instead of waiting for the counter to actually hold clean_run_target | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.140.CSK.1` | if (clean_counter == clean_run_target) -> if (1'b1): always taken | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.140.EDL.1` | delete the else branch at line 140 | 8:killed | a_clean_run_clears |
| `strike_counter.140.ROR.1` | == -> != | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.142.AIM.12` | A completed clean run forgives one strike instead of clearing the whole count, and keeps doing so while the clean count stays saturated | 8:killed | a_clean_run_clears, a_level_moves_by_known_path +1 |
| `strike_counter.142.AIM.26` | A completed clean run sets the strike count back to one strike, treated wrongly as the base cool-down level, instead of clearing it to no strikes. | 8:killed | a_clean_run_clears, a_level_moves_by_known_path |
| `strike_counter.142.CST.1` | '0 -> '1 | 8:killed | a_clean_run_clears, a_level_moves_by_known_path |
| `strike_counter.142.SDL.1` | delete 'strike_level <= '0;' | 8:killed | a_clean_run_clears |
| `strike_counter.143.AIM.34` | A completed clean run clears latch_assert along with the strike count, as though forgiveness reset the whole protection state, although latch_assert is meant to be set-only and cleared by rst_n alone | 8:survived |  |
| `strike_counter.144.AIM.5` | The latch also trips on the strike level alone, outside a hiccup entry | 8:killed | a_latch_earned |
| `strike_counter.150.EDG.1` | posedge clk -> negedge clk | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.165.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 8:survived |  |
| `strike_counter.165.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 8:killed | a_clean_run_clears |
| `strike_counter.165.UOD.1` | drop the '!' before rst_n | 8:killed | a_clean_run_clears |
| `strike_counter.167.CST.1` | 0 -> 1 | 8:survived |  |
| `strike_counter.167.SDL.1` | delete 'clean_counter <= 0;' | 8:survived |  |
| `strike_counter.176.AIM.18` | A switching-cycle boundary outranks the streak break, so a PWM fall on the clock S_RUN is left still counts as a clean cycle | 8:survived |  |
| `strike_counter.176.AIM.20` | The clean-run streak is broken only on a switching-cycle boundary, so leaving S_RUN or a window trip between PWM falls leaves the saturated clean count standing | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.176.AIM.21` | Leaving S_RUN only pauses the clean-run count instead of clearing it; only window_trip restarts the streak | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.176.AIM.4` | window_trip pauses the clean-run count instead of restarting it | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.176.CND.1` | if (!run_active \|\| window_trip) -> if (!(...)) | 8:killed | a_clean_run_clears |
| `strike_counter.176.CSK.1` | if (!run_active \|\| window_trip) -> if (1'b0): never taken | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.176.CSK.2` | if (!run_active \|\| window_trip) -> if (1'b1): always taken | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.176.CTD.1` | drop the term '!run_active' | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.176.CTD.2` | drop the term 'window_trip' | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.176.CTN.1` | negate the term 'window_trip' | 8:killed | a_clean_run_clears |
| `strike_counter.176.EDL.1` | delete the else branch at line 176 | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.176.LCR.1` | \|\| -> && | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.176.SIB.1` | run_active -> hiccup_active | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.176.UOD.1` | drop the '!' before run_active | 8:killed | a_clean_run_clears |
| `strike_counter.178.CST.1` | 0 -> 1 | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.178.SDL.1` | delete 'clean_counter <= 0;' | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.182.CND.1` | if (pwm_fall) -> if (!(...)) | 8:killed | a_clear_earned, a_level_moves_by_known_path |
| `strike_counter.182.CSK.1` | if (pwm_fall) -> if (1'b0): never taken | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.182.CSK.2` | if (pwm_fall) -> if (1'b1): always taken | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.182.EDL.1` | delete the else branch at line 182 | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.182.SIB.1` | pwm_fall -> pwm_sync | 8:lint | make lint: UNUSEDSIGNAL |
| `strike_counter.184.AIM.10` | The clean-run counter saturates at all-ones, the old fixed terminal, instead of holding at clean_run_target | 8:survived |  |
| `strike_counter.184.AIM.17` | The clean-run counter saturates one cycle below clean_run_target, so it never reaches the value the strike clear waits for | 8:killed | a_clean_run_clears |
| `strike_counter.184.AIM.25` | The clean-run counter holds at any count at or above clean_run_target, but the strike clear still waits for an exact match. So if the target is lowered below the running count, the counter freezes at a value that can never equal it. | 8:survived |  |
| `strike_counter.184.CSK.1` | if (clean_counter == clean_run_target) -> if (1'b0): never taken | 8:survived |  |
| `strike_counter.184.CSK.2` | if (clean_counter == clean_run_target) -> if (1'b1): always taken | 8:killed | a_clean_run_clears |
| `strike_counter.184.ROR.1` | == -> != | 8:killed | a_clean_run_clears |
| `strike_counter.186.SDL.1` | delete 'clean_counter <= clean_counter;' | 8:survived |  |
| `strike_counter.186.STK.1` | clean_counter stuck at all-zeros (was 'clean_counter') | 8:survived |  |
| `strike_counter.186.STK.2` | clean_counter stuck at all-ones (was 'clean_counter') | 8:survived |  |
| `strike_counter.186.VNG.1` | clean_counter inverted (was 'clean_counter') | 8:survived |  |
| `strike_counter.191.AOR.1` | + -> - | 8:killed | a_clean_run_clears |
| `strike_counter.191.CST.1` | 1 -> 0 | 8:killed | a_clean_run_clears |
| `strike_counter.191.CST.2` | 1 -> 2 | 8:killed | a_clean_run_clears, a_clear_earned +1 |
| `strike_counter.191.SDL.1` | delete 'clean_counter <= clean_counter + 1;' | 8:killed | a_clean_run_clears |
| `strike_counter.191.STK.1` | clean_counter stuck at all-zeros (was 'clean_counter + 1') | 8:killed | a_clean_run_clears |
| `strike_counter.191.STK.2` | clean_counter stuck at all-ones (was 'clean_counter + 1') | 8:killed | a_clean_run_clears |
| `strike_counter.191.VNG.1` | clean_counter inverted (was 'clean_counter + 1') | 8:killed | a_clean_run_clears |
| `strike_counter.140.AIM.9` | The strike clear still waits for the old all-ones terminal count instead of clean_run_target, although the counter now saturates at the target | not run (withdrawn at step 6) |  |
| `strike_counter.176.AIM.30` | The clean-run streak is broken by leaving S_RUN for any state except S_HICCUP, so a completed clean count survives into the cool-down | not run (withdrawn at step 7) |  |
