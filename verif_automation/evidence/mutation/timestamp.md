# Mutation record: timestamp

`rtl-systemverilog/status/timestamp.sv`. Written by `tools/mutation/record.py` from `timestamp.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 41 | 37 | 0 | 0 | 0 | 4 | 0 | 0 | 90.2% |
| AI-written | 5 | 5 | 0 | 0 | 0 | 0 | 0 | 0 | 100.0% |
| all | 46 | 42 | 0 | 0 | 0 | 4 | 0 | 0 | 91.3% |

Survivors: 4 - 2 decided equivalent, 1 accepted, 1 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 97.7%.

## Survivors (4)

### `timestamp.62.EDG.1` - posedge clk -> negedge clk

- before: `always_ff @ (posedge clk or negedge rst_n) begin`
- after: `always_ff @ (negedge clk or negedge rst_n) begin`
- AI judgement (step 4): **plausible**, high confidence - Line 62 moves the prescaler update to the falling clock edge, while the timestamp_ms block (line 94) still runs on the rising edge. This shifts when line 113 sees the terminal count, so timestamp_ms increments on different clock edges.
- designer's decision (step 5): **accepted** - tick moves half a clock earlier relative to reset; period unchanged; a 50 ns shift on a 1 ms fault-log timestamp has no consumer

### `timestamp.72.SDL.1` - delete 'prescalar <= '0;'

- before: `prescalar <= '0;`
- after: `;`
- AI judgement (step 4): **plausible**, high confidence - Without line 72, reset leaves prescalar uninitialised (X in simulation, an arbitrary value in hardware). In simulation the compares on lines 78 and 113 and the add on line 86 then keep it X, so timestamp_ms never increments correctly; in hardware the first tick comes at a different time.
- designer's decision (step 6): **gap** - prescaler reset value untested: the testbench resets only at time zero, where a two-state simulator already holds 0; needs a mid-run reset with the prescaler non-zero

### `timestamp.78.SIB.1` - PRESCALAR_W -> TIMESTAMP_W

- before: `if(prescalar == PRESCALAR_W'(PRESCALE_VAL-1)) begin`
- after: `if(prescalar == TIMESTAMP_W'(PRESCALE_VAL-1)) begin`
- AI judgement (step 4): **equivalent**, medium confidence - With the defaults (PRESCALE_VAL=50000, PRESCALAR_W=16, TIMESTAMP_W=24), casting 49999 to 24 bits instead of 16 gives the same value, and the compare widens the 16-bit prescalar with zeros, so line 78 behaves the same. Confidence is only medium: the header (lines 34-45) says the testbench overrides both parameters, and if TIMESTAMP_W < PRESCALAR_W the cast cuts off high bits and changes the terminal count.
- designer's decision (step 7): **equivalent** - PRESCALE_VAL-1 fits in both widths in every configuration (design 16 vs 24 bits, testbench 3 vs 4), so the cast never changes the compared value

### `timestamp.113.SIB.1` - PRESCALAR_W -> TIMESTAMP_W

- before: `if(prescalar == PRESCALAR_W'(PRESCALE_VAL-1)) timestamp_ms <= timestamp_ms + 1'b1;`
- after: `if(prescalar == TIMESTAMP_W'(PRESCALE_VAL-1)) timestamp_ms <= timestamp_ms + 1'b1;`
- AI judgement (step 4): **equivalent**, medium confidence - With the defaults (PRESCALAR_W=16, TIMESTAMP_W=24), TIMESTAMP_W'(49999) equals PRESCALAR_W'(49999), and the 16-bit prescalar is widened with zeros for the compare, so the increment condition on line 113 does not change. Confidence is only medium: with a simulation override where TIMESTAMP_W < $clog2(PRESCALE_VAL+1), the cast cuts off high bits and the tick condition differs.
- designer's decision (step 7): **equivalent** - PRESCALE_VAL-1 fits in both widths in every configuration (design 16 vs 24 bits, testbench 3 vs 4), so the cast never changes the compared value

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-15 13:59 | 05405e5 | AI wrote mutants (claude-opus-5-5) | asked 6, proposed 3, accepted 3, rejected 0; `ai_runs/2026-11-15_write_mutants` |
| 2 | 2026-11-15 14:00 | 05405e5 | AI wrote mutants (claude-opus-5-5) | asked 10, proposed 3, accepted 2, rejected 1; `ai_runs/2026-11-15_write_mutants_2` |
| 3 | 2026-11-15 14:05 | 05405e5 | mutation run - every mutant of the module | 46 mutants: 42 killed, 4 survived; score 91.3% |
| 4 | 2026-11-15 14:07 | 05405e5 | AI judged survivors (claude-opus-5-5) | 4 judged, 0 called equivalent with high confidence; `ai_runs/2026-11-15_judge_survivors` |
| 5 | 2026-11-15 14:14 | 05405e5 | designer's decision: accepted | timestamp.62.EDG.1 - tick moves half a clock earlier relative to reset; period unchanged; a 50 ns shift on a 1 ms fault-log timestamp has no consumer |
| 6 | 2026-11-15 14:16 | 05405e5 | designer's decision: gap | timestamp.72.SDL.1 - prescaler reset value untested: the testbench resets only at time zero, where a two-state simulator already holds 0; needs a mid-run reset with the prescaler non-zero |
| 7 | 2026-11-15 14:16 | 05405e5 | designer's decision: equivalent | timestamp.78.SIB.1, timestamp.113.SIB.1 - PRESCALE_VAL-1 fits in both widths in every configuration (design 16 vs 24 bits, testbench 3 vs 4), so the cast never changes the compared value |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (5)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | wrong_event | The millisecond tick is taken when the prescaler starts a period (count 0) and not when it reaches terminal count | killed | a_timestamp_increments_on_wrap, a_timestamp_stable_otherwise |
| 2 | 1 | boundary | The millisecond counter saturates at all-ones and does not wrap at 2**TIMESTAMP_W as the header requires | killed | a_timestamp_increments_on_wrap |
| 3 | 1 | boundary | The prescaler reloads to 1 on terminal count, as if it counted 1..N, so every period after the first is one clock short | killed | a_prescalar_wraps_to_zero |
| 4 | 2 | reset_init | The prescaler resets to its terminal count instead of 0, so the first millisecond tick comes on the first clock after reset instead of after a full PRESCALE_VAL period | killed | a_counters_zero_in_reset |
| 5 | 2 | reset_init | The millisecond counter resets to 1, as if the first millisecond were numbered 1, instead of 0 | killed | a_counters_zero_in_reset |

Rejected by the gate in step 2 (1):

- An explicit wrap of the millisecond counter compares against all-ones minus one, so it wraps from 2**TIMESTAMP_W-2 back to 0 and never shows all-ones - **changes 7 lines; at most 6**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `timestamp.62.EDG.1` | posedge clk -> negedge clk | 3:survived |  |
| `timestamp.70.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 3:killed | a_counters_zero_in_reset |
| `timestamp.70.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 3:killed | a_prescalar_advances_by_one |
| `timestamp.70.UOD.1` | drop the '!' before rst_n | 3:killed | a_counters_zero_in_reset, a_prescalar_advances_by_one |
| `timestamp.72.AIM.4` | The prescaler resets to its terminal count instead of 0, so the first millisecond tick comes on the first clock after reset instead of after a full PRESCALE_VAL period | 3:killed | a_counters_zero_in_reset |
| `timestamp.72.CST.1` | '0 -> '1 | 3:killed | a_counters_zero_in_reset, a_prescalar_in_range |
| `timestamp.72.SDL.1` | delete 'prescalar <= '0;' | 3:survived |  |
| `timestamp.76.EDL.1` | delete the else branch at line 76 | 3:killed | a_prescalar_advances_by_one |
| `timestamp.78.AOR.1` | - -> + | 3:killed | a_prescalar_in_range, a_prescalar_wraps_to_zero +1 |
| `timestamp.78.CSK.1` | if (prescalar == PRESCALAR_W'(PRESCALE_VAL-1)) -> if (1'b0): never taken | 3:killed | a_prescalar_in_range, a_prescalar_wraps_to_zero |
| `timestamp.78.CSK.2` | if (prescalar == PRESCALAR_W'(PRESCALE_VAL-1)) -> if (1'b1): always taken | 3:killed | a_prescalar_advances_by_one |
| `timestamp.78.CST.1` | 1 -> 0 | 3:killed | a_prescalar_in_range, a_prescalar_wraps_to_zero +1 |
| `timestamp.78.CST.2` | 1 -> 2 | 3:killed | a_prescalar_advances_by_one |
| `timestamp.78.ROR.1` | == -> != | 3:killed | a_prescalar_advances_by_one |
| `timestamp.78.SIB.1` | PRESCALAR_W -> TIMESTAMP_W | 3:survived |  |
| `timestamp.80.AIM.3` | The prescaler reloads to 1 on terminal count, as if it counted 1..N, so every period after the first is one clock short | 3:killed | a_prescalar_wraps_to_zero |
| `timestamp.80.CST.1` | '0 -> '1 | 3:killed | a_prescalar_in_range, a_prescalar_wraps_to_zero |
| `timestamp.80.SDL.1` | delete 'prescalar <= '0;' | 3:killed | a_prescalar_wraps_to_zero |
| `timestamp.86.AOR.1` | + -> - | 3:killed | a_prescalar_in_range, a_prescalar_advances_by_one |
| `timestamp.86.CST.1` | 1'b1 -> 1'b0 | 3:killed | a_prescalar_advances_by_one |
| `timestamp.86.SDL.1` | delete 'prescalar <= prescalar + 1'b1;' | 3:killed | a_prescalar_advances_by_one |
| `timestamp.86.STK.1` | prescalar stuck at all-zeros (was 'prescalar + 1'b1') | 3:killed | a_prescalar_advances_by_one |
| `timestamp.86.STK.2` | prescalar stuck at all-ones (was 'prescalar + 1'b1') | 3:killed | a_prescalar_in_range, a_prescalar_advances_by_one |
| `timestamp.86.VNG.1` | prescalar inverted (was 'prescalar + 1'b1') | 3:killed | a_prescalar_in_range, a_prescalar_advances_by_one |
| `timestamp.94.EDG.1` | posedge clk -> negedge clk | 3:killed | a_timestamp_stable_otherwise, a_timestamp_increments_on_wrap |
| `timestamp.105.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 3:killed | a_counters_zero_in_reset |
| `timestamp.105.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 3:killed | a_timestamp_increments_on_wrap |
| `timestamp.105.UOD.1` | drop the '!' before rst_n | 3:killed | a_timestamp_increments_on_wrap |
| `timestamp.107.AIM.5` | The millisecond counter resets to 1, as if the first millisecond were numbered 1, instead of 0 | 3:killed | a_counters_zero_in_reset |
| `timestamp.107.CST.1` | '0 -> '1 | 3:killed | a_counters_zero_in_reset |
| `timestamp.107.SDL.1` | delete 'timestamp_ms <= '0;' | 3:killed | a_counters_zero_in_reset |
| `timestamp.111.EDL.1` | delete the else branch at line 111 | 3:killed | a_timestamp_increments_on_wrap |
| `timestamp.113.AIM.1` | The millisecond tick is taken when the prescaler starts a period (count 0) and not when it reaches terminal count | 3:killed | a_timestamp_increments_on_wrap, a_timestamp_stable_otherwise |
| `timestamp.113.AIM.2` | The millisecond counter saturates at all-ones and does not wrap at 2**TIMESTAMP_W as the header requires | 3:killed | a_timestamp_increments_on_wrap |
| `timestamp.113.AOR.1` | - -> + | 3:killed | a_timestamp_increments_on_wrap |
| `timestamp.113.AOR.2` | + -> - | 3:killed | a_timestamp_increments_on_wrap |
| `timestamp.113.CSK.1` | if (prescalar == PRESCALAR_W'(PRESCALE_VAL-1)) -> if (1'b1): always taken | 3:killed | a_timestamp_stable_otherwise |
| `timestamp.113.CST.1` | 1 -> 0 | 3:killed | a_timestamp_increments_on_wrap |
| `timestamp.113.CST.2` | 1 -> 2 | 3:killed | a_timestamp_stable_otherwise, a_timestamp_increments_on_wrap |
| `timestamp.113.CST.3` | 1'b1 -> 1'b0 | 3:killed | a_timestamp_increments_on_wrap |
| `timestamp.113.ROR.1` | == -> != | 3:killed | a_timestamp_stable_otherwise, a_timestamp_increments_on_wrap |
| `timestamp.113.SDL.1` | delete 'timestamp_ms <= timestamp_ms + 1'b1;' | 3:killed | a_timestamp_increments_on_wrap |
| `timestamp.113.SIB.1` | PRESCALAR_W -> TIMESTAMP_W | 3:survived |  |
| `timestamp.113.STK.1` | timestamp_ms stuck at all-zeros (was 'timestamp_ms + 1'b1') | 3:killed | a_timestamp_increments_on_wrap |
| `timestamp.113.STK.2` | timestamp_ms stuck at all-ones (was 'timestamp_ms + 1'b1') | 3:killed | a_timestamp_increments_on_wrap |
| `timestamp.113.VNG.1` | timestamp_ms inverted (was 'timestamp_ms + 1'b1') | 3:killed | a_timestamp_increments_on_wrap |
