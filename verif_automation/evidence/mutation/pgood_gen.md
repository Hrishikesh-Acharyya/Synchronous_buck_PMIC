# Mutation record: pgood_gen

`rtl-systemverilog/status/pgood_gen.sv`. Written by `tools/mutation/record.py` from `pgood_gen.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 72 | 24 | 12 | 20 | 0 | 16 | 0 | 0 | 77.8% |
| AI-written | 18 | 12 | 0 | 1 | 0 | 5 | 0 | 0 | 72.2% |
| all | 90 | 36 | 12 | 21 | 0 | 21 | 0 | 0 | 76.7% |

Survivors: 21 - 1 decided equivalent, 3 accepted, 17 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 80.2%.
2 earlier mutants are not in these numbers: 2 AI-written ones the designer withdrew, 0 the generator no longer makes because the RTL changed. Their history is kept below.

## Survivors (21)

### `pgood_gen.64.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n) begin`
- after: `if(1'b0) begin`
- AI judgement (step 12): **plausible**, high confidence - Without the async reset at line 64, pwm_sync_d keeps tracking pwm_sync during reset (or stays X if no clock ran), instead of being forced to 0. If pwm_sync was 1 at the last edge before reset is released and is 0 at the first edge after, pwm_fall fires and the counter at line 140 advances one extra time, so PGOOD asserts a cycle earlier.
- designer's decision (step 15): **gap** - reset values untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-qualification and with pwm_sync high

### `pgood_gen.66.CST.1` - 0 -> 1

- before: `pwm_sync_d<=0;`
- after: `pwm_sync_d<=1;`
- AI judgement (step 12): **plausible**, high confidence - Resetting pwm_sync_d to 1 makes pwm_fall (line 89) pulse at the first edge after reset whenever pwm_sync is low. If run_active and pgood_comp are high, that pulse gives one extra count, so PGOOD asserts one switching cycle earlier.
- designer's decision (step 15): **gap** - reset values untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-qualification and with pwm_sync high

### `pgood_gen.66.SDL.1` - delete 'pwm_sync_d<=0;'

- before: `pwm_sync_d<=0;`
- after: `;`
- AI judgement (step 12): **plausible**, high confidence - With the reset assignment deleted, pwm_sync_d holds its value from before reset (X at power-up). A held 1 gives a pwm_fall pulse at the first edge after reset if pwm_sync is low, which advances qualify_counter (line 140) one extra time and moves PGOOD's assertion earlier.
- designer's decision (step 15): **gap** - reset values untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-qualification and with pwm_sync high

### `pgood_gen.70.AIM.13` - The delayed PWM copy is only tracked while the supervisor is in S_RUN, so on entry to S_RUN the cycle-boundary detector compares the live PWM with a stale sample

- before: `else begin`
- after: `else if (run_active) begin`
- AI judgement (step 12): **plausible**, high confidence - pwm_sync_d is frozen while run_active is low. At the first edge with run_active high, pwm_fall at line 89 compares the live pwm_sync with a stale sample, so it can produce a spurious count or miss a real one. That shifts when qualify_counter reaches TARGET and so when PGOOD rises.
- designer's decision (step 16): **accepted** - PGOOD qualification moves by at most one switching cycle (under 2.2 us) on a 9 ms delay; no consumer depends on that resolution

### `pgood_gen.72.STK.2` - pwm_sync_d stuck at all-ones (was 'pwm_sync')

- before: `pwm_sync_d <= pwm_sync;`
- after: `pwm_sync_d <= '1;`
- AI judgement (step 12): **plausible**, high confidence - With pwm_sync_d stuck at 1, pwm_fall at line 89 becomes ~pwm_sync. The counter then advances on every clock that PWM is low instead of once per cycle, so PGOOD asserts far sooner.
- designer's decision (step 13): **gap** - qualification time never measured from outside: the checker takes the cycle boundary and count from the module itself; needs PGOOD's rise timed in pwm_sync falling edges from the start of a good run (some of these qualify after one cycle)

### `pgood_gen.72.VNG.1` - pwm_sync_d inverted (was 'pwm_sync')

- before: `pwm_sync_d <= pwm_sync;`
- after: `pwm_sync_d <= ~(pwm_sync);`
- AI judgement (step 12): **plausible**, high confidence - pwm_fall becomes ~pwm_sync(previous) & ~pwm_sync, which is high on every clock where PWM has been low for two samples. The count rate changes, and so does PGOOD timing.
- designer's decision (step 13): **gap** - qualification time never measured from outside: the checker takes the cycle boundary and count from the module itself; needs PGOOD's rise timed in pwm_sync falling edges from the start of a good run (some of these qualify after one cycle)

### `pgood_gen.79.AIM.16` - The cycle-boundary pulse is registered instead of combinational, so the qualifying counter advances one clock after the PWM falling edge is seen rather than on it

- before: `always_comb begin /  / /* / Purpose: / --- / One-clk enable pulse marking the switching-cycle boundary, so the / qualifying counter below advances once per cycle rather than once per / clock. / */ /  / pwm_fall = pwm_sync_d & ~pwm_sync;`
- after: `always_ff @(posedge clk) begin /  / /* / Purpose: / --- / One-clk enable pulse marking the switching-cycle boundary, so the / qualifying counter below advances once per cycle rather than once per / clock. / */ /  / pwm_fall <= pwm_sync_d & ~pwm_sync;`
- AI judgement (step 12): **plausible**, high confidence - A registered pwm_fall lags by one clock and has no reset value. Line 124 is evaluated against the same-clock run_active and pgood_comp, so a delayed pulse can land on a clock where the clear condition holds (or not) differently than in the original, which changes the count. PGOOD timing changes, and an X after reset is also possible.
- designer's decision (step 16): **accepted** - PGOOD qualification moves by at most one switching cycle (under 2.2 us) on a 9 ms delay; no consumer depends on that resolution

### `pgood_gen.89.AIM.1` - The cycle-boundary pulse fires on both PWM edges, so the qualifying counter advances twice per switching cycle

- before: `pwm_fall = pwm_sync_d & ~pwm_sync;`
- after: `pwm_fall = pwm_sync_d ^ pwm_sync;`
- AI judgement (step 12): **plausible**, high confidence - XOR fires on both PWM edges, so qualify_counter advances twice per switching cycle and PGOOD asserts in roughly half the qualifying time.
- designer's decision (step 13): **gap** - qualification time never measured from outside: the checker takes the cycle boundary and count from the module itself; needs PGOOD's rise timed in pwm_sync falling edges from the start of a good run (some of these qualify after one cycle)

### `pgood_gen.89.AIM.2` - The cycle boundary is taken on the rising edge of the PWM, not the falling edge that ends the cycle

- before: `pwm_fall = pwm_sync_d & ~pwm_sync;`
- after: `pwm_fall = ~pwm_sync_d & pwm_sync;`
- AI judgement (step 12): **plausible**, high confidence - Counting on rising edges instead of falling edges moves each increment by the PWM high time. A pgood_comp dip or a run_active drop between the two edges then gives a different count, and the final increment (and PGOOD rise) lands on a different clock.
- designer's decision (step 16): **accepted** - PGOOD qualification moves by at most one switching cycle (under 2.2 us) on a 9 ms delay; no consumer depends on that resolution

### `pgood_gen.89.CTD.2` - drop the term '~pwm_sync'

- before: `pwm_fall = pwm_sync_d & ~pwm_sync;`
- after: `pwm_fall = pwm_sync_d;`
- AI judgement (step 12): **plausible**, high confidence - pwm_fall = pwm_sync_d is high on every clock after PWM has been high, so the counter at line 140 advances many times per switching cycle instead of once.
- designer's decision (step 13): **gap** - qualification time never measured from outside: the checker takes the cycle boundary and count from the module itself; needs PGOOD's rise timed in pwm_sync falling edges from the start of a good run (some of these qualify after one cycle)

### `pgood_gen.89.CTN.1` - negate the term 'pwm_sync_d'

- before: `pwm_fall = pwm_sync_d & ~pwm_sync;`
- after: `pwm_fall = ~(pwm_sync_d) & ~pwm_sync;`
- AI judgement (step 12): **plausible**, high confidence - ~pwm_sync_d & ~pwm_sync is high on every clock that PWM stays low. The counter advances many times per cycle and PGOOD asserts much earlier.
- designer's decision (step 13): **gap** - qualification time never measured from outside: the checker takes the cycle boundary and count from the module itself; needs PGOOD's rise timed in pwm_sync falling edges from the start of a good run (some of these qualify after one cycle)

### `pgood_gen.89.LCR.1` - & -> |

- before: `pwm_fall = pwm_sync_d & ~pwm_sync;`
- after: `pwm_fall = pwm_sync_d | ~pwm_sync;`
- AI judgement (step 12): **plausible**, high confidence - pwm_sync_d | ~pwm_sync is high on most clocks, so the counter advances far more often than once per cycle and PGOOD asserts early.
- designer's decision (step 13): **gap** - qualification time never measured from outside: the checker takes the cycle boundary and count from the module itself; needs PGOOD's rise timed in pwm_sync falling edges from the start of a good run (some of these qualify after one cycle)

### `pgood_gen.89.UOD.1` - drop the '~' before pwm_sync

- before: `pwm_fall = pwm_sync_d & ~pwm_sync;`
- after: `pwm_fall = pwm_sync_d & pwm_sync;`
- AI judgement (step 12): **plausible**, high confidence - pwm_sync_d & pwm_sync is high on every clock that PWM stays high, so the count rate changes and PGOOD asserts at a different time.
- designer's decision (step 13): **gap** - qualification time never measured from outside: the checker takes the cycle boundary and count from the module itself; needs PGOOD's rise timed in pwm_sync falling edges from the start of a good run (some of these qualify after one cycle)

### `pgood_gen.89.VNG.1` - pwm_fall inverted (was 'pwm_sync_d & ~pwm_sync')

- before: `pwm_fall = pwm_sync_d & ~pwm_sync;`
- after: `pwm_fall = ~(pwm_sync_d & ~pwm_sync);`
- AI judgement (step 12): **plausible**, high confidence - The inverted pwm_fall is high on almost every clock except the falling edge. The counter then advances nearly every clock and PGOOD timing changes drastically.
- designer's decision (step 13): **gap** - qualification time never measured from outside: the checker takes the cycle boundary and count from the module itself; needs PGOOD's rise timed in pwm_sync falling edges from the start of a good run (some of these qualify after one cycle)

### `pgood_gen.114.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n) begin`
- after: `if(1'b0) begin`
- AI judgement (step 12): **plausible**, high confidence - Without the async reset, qualify_counter is not cleared by rst_n and starts as X. If the counter was at TARGET and reset is asserted while run_active and pgood_comp are high (not ruled out by the header), PGOOD at line 169 stays 1 instead of 0.
- designer's decision (step 15): **gap** - reset values untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-qualification and with pwm_sync high

### `pgood_gen.116.CST.1` - 0 -> 1

- before: `qualify_counter <= 0;`
- after: `qualify_counter <= 1;`
- AI judgement (step 12): **plausible**, high confidence - Resetting the counter to 1 means it reaches TARGET (4050) one pwm_fall sooner after reset, so PGOOD asserts one switching cycle early.
- designer's decision (step 15): **gap** - reset values untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-qualification and with pwm_sync high

### `pgood_gen.116.SDL.1` - delete 'qualify_counter <= 0;'

- before: `qualify_counter <= 0;`
- after: `;`
- AI judgement (step 12): **plausible**, high confidence - With the reset assignment deleted, qualify_counter holds its value through reset. A counter at TARGET with run_active and pgood_comp high keeps PGOOD (line 169) high during and after reset, and the power-up value is X.
- designer's decision (step 15): **gap** - reset values untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-qualification and with pwm_sync high

### `pgood_gen.124.AIM.7` - The cycle-boundary increment takes priority over the synchronous clear, so a bad rail or a departure from S_RUN on the clock that pwm_fall fires advances the qualifying counter instead of restarting it

- before: `else if (!run_active ||  !pgood_comp) begin`
- after: `else if ((!run_active ||  !pgood_comp) && !pwm_fall) begin`
- AI judgement (step 12): **plausible**, high confidence - When pwm_fall coincides with pgood_comp or run_active being low, the counter increments instead of clearing. The good-cycle run is no longer required to be consecutive, so PGOOD can assert earlier.
- designer's decision (step 14): **gap** - a comparator dip or S_RUN exit on the same clock as pwm_fall is never tested; the count must restart, not advance

### `pgood_gen.132.CSK.2` - if (qualify_counter == TARGET) -> if (1'b1): always taken

- before: `if(qualify_counter == TARGET) begin`
- after: `if(1'b1) begin`
- AI judgement (step 12): **plausible**, high confidence - With the condition always true, the first pwm_fall loads TARGET directly, so PGOOD asserts after one good cycle instead of 4050.
- designer's decision (step 13): **gap** - qualification time never measured from outside: the checker takes the cycle boundary and count from the module itself; needs PGOOD's rise timed in pwm_sync falling edges from the start of a good run (some of these qualify after one cycle)

### `pgood_gen.134.SDL.1` - delete 'qualify_counter <= TARGET;'

- before: `qualify_counter <= TARGET;`
- after: `;`
- AI judgement (step 12): **equivalent**, high confidence - This branch runs only when qualify_counter == TARGET (line 132), so the deleted line wrote TARGET into a register that already holds TARGET. Without it, the register keeps the same value, and nothing else in the module depends on the assignment.
- designer's decision (step 17): **equivalent** - the branch runs only when qualify_counter == TARGET, so the deleted line rewrote the value already held

### `pgood_gen.140.AOR.1` - + -> -

- before: `qualify_counter <= qualify_counter + 1;`
- after: `qualify_counter <= qualify_counter - 1;`
- AI judgement (step 12): **plausible**, high confidence - Counting down from 0 wraps to 4095 (12-bit counter) and reaches TARGET = 4050 after 46 pwm_fall pulses instead of 4050, so PGOOD asserts far earlier.
- designer's decision (step 13): **gap** - qualification time never measured from outside: the checker takes the cycle boundary and count from the module itself; needs PGOOD's rise timed in pwm_sync falling edges from the start of a good run (some of these qualify after one cycle)

## Caught only by a lost cover (21)

Counted as caught, but no check failed: the behaviour is observed, not checked.

- `pgood_gen.54.EDG.1` - posedge clk -> negedge clk: `always_ff @(posedge clk or negedge rst_n) begin` -> `always_ff @(negedge clk or negedge rst_n) begin`
- `pgood_gen.64.CSK.2` - if (!rst_n) -> if (1'b1): always taken: `if(!rst_n) begin` -> `if(1'b1) begin`
- `pgood_gen.64.UOD.1` - drop the '!' before rst_n: `if(!rst_n) begin` -> `if(rst_n) begin`
- `pgood_gen.72.SDL.1` - delete 'pwm_sync_d <= pwm_sync;': `pwm_sync_d <= pwm_sync;` -> `;`
- `pgood_gen.72.SIB.1` - pwm_sync -> pwm_fall: `pwm_sync_d <= pwm_sync;` -> `pwm_sync_d <= pwm_fall;`
- `pgood_gen.72.STK.1` - pwm_sync_d stuck at all-zeros (was 'pwm_sync'): `pwm_sync_d <= pwm_sync;` -> `pwm_sync_d <= '0;`
- `pgood_gen.89.DLY.2` - pwm_sync -> pwm_sync_d: `pwm_fall = pwm_sync_d & ~pwm_sync;` -> `pwm_fall = pwm_sync_d & ~pwm_sync_d;`
- `pgood_gen.114.CSK.2` - if (!rst_n) -> if (1'b1): always taken: `if(!rst_n) begin` -> `if(1'b1) begin`
- `pgood_gen.114.UOD.1` - drop the '!' before rst_n: `if(!rst_n) begin` -> `if(rst_n) begin`
- `pgood_gen.124.CND.1` - if (!run_active || !pgood_comp) -> if (!(...)): `else if (!run_active ||  !pgood_comp) begin` -> `else if (!(!run_active ||  !pgood_comp)) begin`
- `pgood_gen.124.CSK.2` - if (!run_active || !pgood_comp) -> if (1'b1): always taken: `else if (!run_active ||  !pgood_comp) begin` -> `else if (1'b1) begin`
- `pgood_gen.124.UOD.1` - drop the '!' before run_active: `else if (!run_active ||  !pgood_comp) begin` -> `else if (run_active ||  !pgood_comp) begin`
- `pgood_gen.124.UOD.2` - drop the '!' before pgood_comp: `else if (!run_active ||  !pgood_comp) begin` -> `else if (!run_active ||  pgood_comp) begin`
- `pgood_gen.132.AIM.19` - The qualifying counter saturates one count short of TARGET, while PGOOD still compares against TARGET itself: `if(qualify_counter == TARGET) begin /  / qualify_counter <= TARGET;` -> `if(qualify_counter == TARGET - 1) begin /  / qualify_counter <= TARGET - 1;`
- `pgood_gen.140.CST.1` - 1 -> 0: `qualify_counter <= qualify_counter + 1;` -> `qualify_counter <= qualify_counter + 0;`
- `pgood_gen.140.CST.2` - 1 -> 2: `qualify_counter <= qualify_counter + 1;` -> `qualify_counter <= qualify_counter + 2;`
- `pgood_gen.140.SDL.1` - delete 'qualify_counter <= qualify_counter + 1;': `qualify_counter <= qualify_counter + 1;` -> `;`
- `pgood_gen.140.STK.1` - qualify_counter stuck at all-zeros (was 'qualify_counter + 1'): `qualify_counter <= qualify_counter + 1;` -> `qualify_counter <= '0;`
- `pgood_gen.140.STK.2` - qualify_counter stuck at all-ones (was 'qualify_counter + 1'): `qualify_counter <= qualify_counter + 1;` -> `qualify_counter <= '1;`
- `pgood_gen.140.VNG.1` - qualify_counter inverted (was 'qualify_counter + 1'): `qualify_counter <= qualify_counter + 1;` -> `qualify_counter <= ~(qualify_counter + 1);`
- `pgood_gen.169.STK.1` - PGOOD stuck at all-zeros (was '((qualify_counter == TARGET) & pgood_com'): `PGOOD = ((qualify_counter == TARGET) & pgood_comp & run_active);` -> `PGOOD = '0;`

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-17 00:00 | 34b8ec6 | AI wrote mutants (claude-opus-5-5) | asked 8, proposed 7, accepted 6, rejected 1; `ai_runs/2026-11-16_write_mutants` |
| 2 | 2026-11-17 00:02 | 34b8ec6 | AI wrote mutants (claude-opus-5-5) | asked 8, proposed 4, accepted 4, rejected 0; `ai_runs/2026-11-17_write_mutants` |
| 3 | 2026-11-17 00:06 | 34b8ec6 | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 3, accepted 2, rejected 1; `ai_runs/2026-11-17_write_mutants_2` |
| 4 | 2026-11-17 00:11 | 34b8ec6 | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 3, accepted 3, rejected 0; `ai_runs/2026-11-17_write_mutants_3` |
| 5 | 2026-11-17 00:12 | 34b8ec6 | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 1, accepted 1, rejected 0; `ai_runs/2026-11-17_write_mutants_4` |
| 6 | 2026-11-17 00:15 | 34b8ec6 | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 1, accepted 1, rejected 0; `ai_runs/2026-11-17_write_mutants_5` |
| 7 | 2026-11-17 00:16 | 34b8ec6 | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 2, accepted 2, rejected 0; `ai_runs/2026-11-17_write_mutants_6` |
| 8 | 2026-11-17 00:19 | 34b8ec6 | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 1, accepted 1, rejected 0; `ai_runs/2026-11-17_write_mutants_7` |
| 9 | 2026-11-17 00:23 | 34b8ec6 | designer withdrew AI-written mutants | pgood_gen.124.AIM.3 - the union of AIM.11 and AIM.12: both conditions cleared only at a cycle boundary; killed whenever those two are |
| 10 | 2026-11-17 00:23 | 34b8ec6 | designer withdrew AI-written mutants | pgood_gen.134.AIM.4 - same fault as AIM.9 at the output: the counter runs past TARGET and PGOOD drops one cycle after asserting; they differ only after 2**PGOOD_DELAY_W cycles |
| 11 | 2026-11-17 00:26 | 34b8ec6 | mutation run - every mutant of the module | 90 mutants: 36 killed, 12 lint, 21 covers, 21 survived; score 76.7% |
| 12 | 2026-11-17 00:27 | 34b8ec6 | AI judged survivors (claude-opus-5-5) | 21 judged, 1 called equivalent with high confidence; `ai_runs/2026-11-17_judge_survivors` |
| 13 | 2026-11-17 00:30 | 34b8ec6 | designer's decision: gap | pgood_gen.72.STK.2, pgood_gen.72.VNG.1, pgood_gen.89.AIM.1, pgood_gen.89.CTD.2, pgood_gen.89.CTN.1, pgood_gen.89.LCR.1, pgood_gen.89.UOD.1, pgood_gen.89.VNG.1, pgood_gen.132.CSK.2, pgood_gen.140.AOR.1 - qualification time never measured from outside: the checker takes the cycle boundary and count from the module itself; needs PGOOD's rise timed in pwm_sync falling edges from the start of a good run (some of these qualify after one cycle) |
| 14 | 2026-11-17 00:30 | 34b8ec6 | designer's decision: gap | pgood_gen.124.AIM.7 - a comparator dip or S_RUN exit on the same clock as pwm_fall is never tested; the count must restart, not advance |
| 15 | 2026-11-17 00:30 | 34b8ec6 | designer's decision: gap | pgood_gen.64.CSK.1, pgood_gen.66.CST.1, pgood_gen.66.SDL.1, pgood_gen.114.CSK.1, pgood_gen.116.CST.1, pgood_gen.116.SDL.1 - reset values untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-qualification and with pwm_sync high |
| 16 | 2026-11-17 00:30 | 34b8ec6 | designer's decision: accepted | pgood_gen.79.AIM.16, pgood_gen.89.AIM.2, pgood_gen.70.AIM.13 - PGOOD qualification moves by at most one switching cycle (under 2.2 us) on a 9 ms delay; no consumer depends on that resolution |
| 17 | 2026-11-17 00:30 | 34b8ec6 | designer's decision: equivalent | pgood_gen.134.SDL.1 - the branch runs only when qualify_counter == TARGET, so the deleted line rewrote the value already held |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (20)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | wrong_event | The cycle-boundary pulse fires on both PWM edges, so the qualifying counter advances twice per switching cycle | survived |  |
| 2 | 1 | wrong_event | The cycle boundary is taken on the rising edge of the PWM, not the falling edge that ends the cycle | survived |  |
| 3 | 1 | wrong_event | The qualifying counter is cleared only at a switching-cycle boundary, not on every clock where the rail is bad or the supervisor is not in S_RUN | withdrawn: the union of AIM.11 and AIM.12: both conditions cleared only at a cycle boundary; killed whenever those two are |  |
| 4 | 1 | boundary | The qualifying counter keeps incrementing past TARGET (wraps) instead of saturating there | withdrawn: same fault as AIM.9 at the output: the counter runs past TARGET and PGOOD drops one cycle after asserting; they differ only after 2**PGOOD_DELAY_W cycles |  |
| 5 | 1 | boundary | The qualifying target is one cycle short of PGOOD_DELAY_CYCLES (off-by-one in the counter's terminal value) | killed | a_pgood_assertion |
| 6 | 1 | sequencing | PGOOD is taken from the saturated counter alone, relying on the counter's synchronous clear for deassertion instead of gating it with the live conditions | killed | a_pgood_drops_immediately |
| 7 | 2 | priority | The cycle-boundary increment takes priority over the synchronous clear, so a bad rail or a departure from S_RUN on the clock that pwm_fall fires advances the qualifying counter instead of restarting it | survived |  |
| 8 | 2 | reset_init | The qualifying counter is restarted only while it is still qualifying; once at TARGET, a comparator dip or exit from S_RUN leaves it saturated, as though the live gating on PGOOD were enough | killed | a_qualify_counter_resets |
| 9 | 2 | boundary | The qualifying counter saturates at its all-ones value (as the package comment describes) instead of at TARGET, so it runs past the count PGOOD compares against | killed | a_qualify_counter_saturates |
| 10 | 2 | boundary | PGOOD treats the counter's top bit as the 'qualified' flag instead of comparing it with TARGET | killed | a_pgood_assertion |
| 11 | 3 | wrong_event | The comparator is sampled only at the switching-cycle boundary for the restart, so a comparator dip that recovers before the next PWM falling edge does not restart the qualifying count | killed | a_qualify_counter_resets |
| 12 | 3 | wrong_event | A departure from S_RUN restarts the qualifying count only if it is seen on a switching-cycle boundary, so leaving S_RUN between PWM falling edges (or while PWM is stopped) leaves the count intact | killed | a_qualify_counter_resets |
| 13 | 4 | wrong_event | The delayed PWM copy is only tracked while the supervisor is in S_RUN, so on entry to S_RUN the cycle-boundary detector compares the live PWM with a stale sample | survived |  |
| 14 | 4 | reset_init | Leaving S_RUN pauses the qualifying count instead of restarting it; only a comparator dip clears it | killed | a_qualify_counter_resets |
| 15 | 4 | boundary | PGOOD compares the counter with one less than the terminal value the counter saturates at, an off-by-one meant to make up for the counter's register delay | killed | a_pgood_assertion |
| 16 | 5 | sequencing | The cycle-boundary pulse is registered instead of combinational, so the qualifying counter advances one clock after the PWM falling edge is seen rather than on it | survived |  |
| 17 | 6 | sequencing | PGOOD looks ahead to the counter's next value: it asserts on the PWM falling edge that will take the counter to TARGET, instead of once the counter has reached it | killed | a_pgood_assertion |
| 18 | 7 | field | TARGET is taken from the package's PGOOD_DELAY_CYCLES instead of the module parameter, so a call-site override of the qualifying delay does not reach the saturation value or the PGOOD comparison | killed | a_pgood_assertion |
| 19 | 7 | boundary | The qualifying counter saturates one count short of TARGET, while PGOOD still compares against TARGET itself | covers | hit 3 SVA covers, the unmutated run 5 |
| 20 | 8 | boundary | PGOOD treats a qualifying count that has started (counter non-zero) as qualified, instead of one that has reached TARGET, which confuses 'qualifying' with 'qualified' | killed | a_pgood_assertion |

Rejected by the gate in step 1 (1):

- A comparator dip in S_RUN pauses the qualifying count instead of restarting it, so the good period is cumulative rather than consecutive - **changes 7 lines; at most 6**

Rejected by the gate in step 3 (1):

- The qualifying counter advances on every clock while the PWM is high, not once per switching cycle at the PWM falling edge - **the same edit as pgood_gen.130.SIB.1**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `pgood_gen.51.AIM.18` | TARGET is taken from the package's PGOOD_DELAY_CYCLES instead of the module parameter, so a call-site override of the qualifying delay does not reach the saturation value or the PGOOD comparison | 11:killed | a_pgood_assertion |
| `pgood_gen.51.AIM.5` | The qualifying target is one cycle short of PGOOD_DELAY_CYCLES (off-by-one in the counter's terminal value) | 11:killed | a_pgood_assertion |
| `pgood_gen.54.EDG.1` | posedge clk -> negedge clk | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.64.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 11:survived |  |
| `pgood_gen.64.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.64.UOD.1` | drop the '!' before rst_n | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.66.CST.1` | 0 -> 1 | 11:survived |  |
| `pgood_gen.66.SDL.1` | delete 'pwm_sync_d<=0;' | 11:survived |  |
| `pgood_gen.70.AIM.13` | The delayed PWM copy is only tracked while the supervisor is in S_RUN, so on entry to S_RUN the cycle-boundary detector compares the live PWM with a stale sample | 11:survived |  |
| `pgood_gen.72.SDL.1` | delete 'pwm_sync_d <= pwm_sync;' | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.72.SIB.1` | pwm_sync -> pwm_fall | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.72.STK.1` | pwm_sync_d stuck at all-zeros (was 'pwm_sync') | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.72.STK.2` | pwm_sync_d stuck at all-ones (was 'pwm_sync') | 11:survived |  |
| `pgood_gen.72.VNG.1` | pwm_sync_d inverted (was 'pwm_sync') | 11:survived |  |
| `pgood_gen.79.AIM.16` | The cycle-boundary pulse is registered instead of combinational, so the qualifying counter advances one clock after the PWM falling edge is seen rather than on it | 11:survived |  |
| `pgood_gen.89.AIM.1` | The cycle-boundary pulse fires on both PWM edges, so the qualifying counter advances twice per switching cycle | 11:survived |  |
| `pgood_gen.89.AIM.2` | The cycle boundary is taken on the rising edge of the PWM, not the falling edge that ends the cycle | 11:survived |  |
| `pgood_gen.89.CTD.1` | drop the term 'pwm_sync_d' | 11:lint | make lint: UNUSEDSIGNAL |
| `pgood_gen.89.CTD.2` | drop the term '~pwm_sync' | 11:survived |  |
| `pgood_gen.89.CTN.1` | negate the term 'pwm_sync_d' | 11:survived |  |
| `pgood_gen.89.DLY.1` | pwm_sync_d -> pwm_sync | 11:lint | make lint: UNUSEDSIGNAL |
| `pgood_gen.89.DLY.2` | pwm_sync -> pwm_sync_d | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.89.LCR.1` | & -> \| | 11:survived |  |
| `pgood_gen.89.SDL.1` | delete 'pwm_fall = pwm_sync_d & ~pwm_sync;' | 11:lint | make lint: UNDRIVEN, UNUSEDSIGNAL |
| `pgood_gen.89.SIB.1` | pwm_sync -> pwm_fall | 11:lint | make lint: ALWCOMBORDER, UNOPTFLAT |
| `pgood_gen.89.STK.1` | pwm_fall stuck at all-zeros (was 'pwm_sync_d & ~pwm_sync') | 11:lint | make lint: UNUSEDSIGNAL |
| `pgood_gen.89.STK.2` | pwm_fall stuck at all-ones (was 'pwm_sync_d & ~pwm_sync') | 11:lint | make lint: UNUSEDSIGNAL |
| `pgood_gen.89.UOD.1` | drop the '~' before pwm_sync | 11:survived |  |
| `pgood_gen.89.VNG.1` | pwm_fall inverted (was 'pwm_sync_d & ~pwm_sync') | 11:survived |  |
| `pgood_gen.94.EDG.1` | posedge clk -> negedge clk | 11:killed | a_run_counter_advances_on_pwm_fall, a_qualify_counter_saturates |
| `pgood_gen.114.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 11:survived |  |
| `pgood_gen.114.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.114.UOD.1` | drop the '!' before rst_n | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.116.CST.1` | 0 -> 1 | 11:survived |  |
| `pgood_gen.116.SDL.1` | delete 'qualify_counter <= 0;' | 11:survived |  |
| `pgood_gen.124.AIM.11` | The comparator is sampled only at the switching-cycle boundary for the restart, so a comparator dip that recovers before the next PWM falling edge does not restart the qualifying count | 11:killed | a_qualify_counter_resets |
| `pgood_gen.124.AIM.12` | A departure from S_RUN restarts the qualifying count only if it is seen on a switching-cycle boundary, so leaving S_RUN between PWM falling edges (or while PWM is stopped) leaves the count intact | 11:killed | a_qualify_counter_resets |
| `pgood_gen.124.AIM.14` | Leaving S_RUN pauses the qualifying count instead of restarting it; only a comparator dip clears it | 11:killed | a_qualify_counter_resets |
| `pgood_gen.124.AIM.7` | The cycle-boundary increment takes priority over the synchronous clear, so a bad rail or a departure from S_RUN on the clock that pwm_fall fires advances the qualifying counter instead of restarting it | 11:survived |  |
| `pgood_gen.124.AIM.8` | The qualifying counter is restarted only while it is still qualifying; once at TARGET, a comparator dip or exit from S_RUN leaves it saturated, as though the live gating on PGOOD were enough | 11:killed | a_qualify_counter_resets |
| `pgood_gen.124.CND.1` | if (!run_active \|\| !pgood_comp) -> if (!(...)) | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.124.CSK.1` | if (!run_active \|\| !pgood_comp) -> if (1'b0): never taken | 11:killed | a_qualify_counter_resets |
| `pgood_gen.124.CSK.2` | if (!run_active \|\| !pgood_comp) -> if (1'b1): always taken | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.124.CTD.1` | drop the term '!run_active' | 11:killed | a_qualify_counter_resets |
| `pgood_gen.124.CTD.2` | drop the term '!pgood_comp' | 11:killed | a_qualify_counter_resets |
| `pgood_gen.124.EDL.1` | delete the else branch at line 124 | 11:lint | make lint: UNUSEDSIGNAL |
| `pgood_gen.124.LCR.1` | \|\| -> && | 11:killed | a_qualify_counter_resets |
| `pgood_gen.124.UOD.1` | drop the '!' before run_active | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.124.UOD.2` | drop the '!' before pgood_comp | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.126.CST.1` | 0 -> 1 | 11:killed | a_run_counter_advances_on_pwm_fall, a_qualify_counter_resets |
| `pgood_gen.126.SDL.1` | delete 'qualify_counter <= 0;' | 11:killed | a_qualify_counter_resets |
| `pgood_gen.130.CND.1` | if (pwm_fall) -> if (!(...)) | 11:killed | a_run_counter_advances_on_pwm_fall |
| `pgood_gen.130.CSK.1` | if (pwm_fall) -> if (1'b0): never taken | 11:lint | make lint: UNUSEDSIGNAL |
| `pgood_gen.130.CSK.2` | if (pwm_fall) -> if (1'b1): always taken | 11:lint | make lint: UNUSEDSIGNAL |
| `pgood_gen.130.EDL.1` | delete the else branch at line 130 | 11:lint | make lint: UNUSEDSIGNAL |
| `pgood_gen.130.SIB.1` | pwm_fall -> pwm_sync | 11:lint | make lint: UNUSEDSIGNAL |
| `pgood_gen.132.AIM.19` | The qualifying counter saturates one count short of TARGET, while PGOOD still compares against TARGET itself | 11:covers | hit 3 SVA covers, the unmutated run 5 |
| `pgood_gen.132.AIM.9` | The qualifying counter saturates at its all-ones value (as the package comment describes) instead of at TARGET, so it runs past the count PGOOD compares against | 11:killed | a_qualify_counter_saturates |
| `pgood_gen.132.CSK.1` | if (qualify_counter == TARGET) -> if (1'b0): never taken | 11:killed | a_qualify_counter_saturates |
| `pgood_gen.132.CSK.2` | if (qualify_counter == TARGET) -> if (1'b1): always taken | 11:survived |  |
| `pgood_gen.132.ROR.1` | == -> != | 11:killed | a_qualify_counter_saturates |
| `pgood_gen.134.SDL.1` | delete 'qualify_counter <= TARGET;' | 11:survived |  |
| `pgood_gen.134.STK.1` | qualify_counter stuck at all-zeros (was 'TARGET') | 11:killed | a_qualify_counter_saturates |
| `pgood_gen.134.STK.2` | qualify_counter stuck at all-ones (was 'TARGET') | 11:killed | a_qualify_counter_saturates |
| `pgood_gen.134.VNG.1` | qualify_counter inverted (was 'TARGET') | 11:killed | a_qualify_counter_saturates |
| `pgood_gen.140.AOR.1` | + -> - | 11:survived |  |
| `pgood_gen.140.CST.1` | 1 -> 0 | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.140.CST.2` | 1 -> 2 | 11:covers | hit 3 SVA covers, the unmutated run 5 |
| `pgood_gen.140.SDL.1` | delete 'qualify_counter <= qualify_counter + 1;' | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.140.STK.1` | qualify_counter stuck at all-zeros (was 'qualify_counter + 1') | 11:covers | hit 2 SVA covers, the unmutated run 5 |
| `pgood_gen.140.STK.2` | qualify_counter stuck at all-ones (was 'qualify_counter + 1') | 11:covers | hit 3 SVA covers, the unmutated run 5 |
| `pgood_gen.140.VNG.1` | qualify_counter inverted (was 'qualify_counter + 1') | 11:covers | hit 3 SVA covers, the unmutated run 5 |
| `pgood_gen.169.AIM.10` | PGOOD treats the counter's top bit as the 'qualified' flag instead of comparing it with TARGET | 11:killed | a_pgood_assertion |
| `pgood_gen.169.AIM.15` | PGOOD compares the counter with one less than the terminal value the counter saturates at, an off-by-one meant to make up for the counter's register delay | 11:killed | a_pgood_assertion |
| `pgood_gen.169.AIM.17` | PGOOD looks ahead to the counter's next value: it asserts on the PWM falling edge that will take the counter to TARGET, instead of once the counter has reached it | 11:killed | a_pgood_assertion |
| `pgood_gen.169.AIM.20` | PGOOD treats a qualifying count that has started (counter non-zero) as qualified, instead of one that has reached TARGET, which confuses 'qualifying' with 'qualified' | 11:killed | a_pgood_assertion |
| `pgood_gen.169.AIM.6` | PGOOD is taken from the saturated counter alone, relying on the counter's synchronous clear for deassertion instead of gating it with the live conditions | 11:killed | a_pgood_drops_immediately |
| `pgood_gen.169.CTD.1` | drop the term '(qualify_counter == TARGET)' | 11:killed | a_pgood_assertion |
| `pgood_gen.169.CTD.2` | drop the term 'pgood_comp' | 11:killed | a_pgood_drops_immediately |
| `pgood_gen.169.CTD.3` | drop the term 'run_active' | 11:killed | a_pgood_drops_immediately |
| `pgood_gen.169.CTN.1` | negate the term '(qualify_counter == TARGET)' | 11:killed | a_pgood_assertion |
| `pgood_gen.169.CTN.2` | negate the term 'pgood_comp' | 11:killed | a_pgood_drops_immediately |
| `pgood_gen.169.CTN.3` | negate the term 'run_active' | 11:killed | a_pgood_drops_immediately |
| `pgood_gen.169.LCR.1` | & -> \| | 11:killed | a_pgood_assertion, a_pgood_drops_immediately |
| `pgood_gen.169.LCR.2` | & -> \| | 11:killed | a_pgood_assertion, a_pgood_drops_immediately |
| `pgood_gen.169.ROR.1` | == -> != | 11:killed | a_pgood_assertion |
| `pgood_gen.169.SDL.1` | delete 'PGOOD = ((qualify_counter == TARGET) & pgood_comp & run_acti' | 11:lint | make lint: UNDRIVEN |
| `pgood_gen.169.STK.1` | PGOOD stuck at all-zeros (was '((qualify_counter == TARGET) & pgood_com') | 11:covers | hit 4 SVA covers, the unmutated run 5 |
| `pgood_gen.169.STK.2` | PGOOD stuck at all-ones (was '((qualify_counter == TARGET) & pgood_com') | 11:killed | a_rst_n_mean_pgood_low, a_pgood_assertion +1 |
| `pgood_gen.169.VNG.1` | PGOOD inverted (was '((qualify_counter == TARGET) & pgood_com') | 11:killed | a_rst_n_mean_pgood_low, a_pgood_drops_immediately +1 |
| `pgood_gen.124.AIM.3` | The qualifying counter is cleared only at a switching-cycle boundary, not on every clock where the rail is bad or the supervisor is not in S_RUN | not run (withdrawn at step 9) |  |
| `pgood_gen.134.AIM.4` | The qualifying counter keeps incrementing past TARGET (wraps) instead of saturating there | not run (withdrawn at step 10) |  |
