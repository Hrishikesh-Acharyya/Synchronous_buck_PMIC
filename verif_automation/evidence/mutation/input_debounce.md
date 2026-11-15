# Mutation record: input_debounce

`rtl-systemverilog/inputs/input_debounce.sv`. Written by `tools/mutation/record.py` from `input_debounce.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 69 | 59 | 3 | 0 | 0 | 7 | 0 | 0 | 89.9% |
| AI-written | 16 | 14 | 0 | 2 | 0 | 0 | 0 | 0 | 100.0% |
| all | 85 | 73 | 3 | 2 | 0 | 7 | 0 | 0 | 91.8% |

Survivors: 7 - 3 decided equivalent, 0 accepted, 4 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 95.1%.
1 earlier mutants are not in these numbers: 1 AI-written ones the designer withdrew, 0 the generator no longer makes because the RTL changed. Their history is kept below.

## Survivors (7)

### `input_debounce.84.CST.1` - localparam CNT_W: 1 -> 0

- before: `localparam int CNT_W = $clog2(CNT_MAX+1);`
- after: `localparam int CNT_W = $clog2(CNT_MAX+0);`
- AI judgement (step 7): **equivalent**, high confidence - With defaults CNT_MAX=max(50000,10000)=50000 (CLK_HZ=50e6, pkg lines 258/261), and $clog2(50000)=$clog2(50001)=16, so CNT_W and every signal width are unchanged. (Also holds for pmic_top overrides: 1e6 gives 20 either way; for 8 the width drops to 3 but target_clks-1'b1 wraps 0-1 to 7 in 3-bit context on lines 132/176, identical to the original 7.)
- designer's decision (step 8): **equivalent** - CNT_W changes only for a power-of-two CNT_MAX (+0) or CNT_MAX+1 (+2); the only case is the SPI filter (8), where target_clks-1 wraps to 7 in the 3-bit compare, the same count

### `input_debounce.84.CST.2` - localparam CNT_W: 1 -> 2

- before: `localparam int CNT_W = $clog2(CNT_MAX+1);`
- after: `localparam int CNT_W = $clog2(CNT_MAX+2);`
- AI judgement (step 7): **equivalent**, high confidence - $clog2(50002)=$clog2(50001)=16 for the default CNT_MAX=50000, so CNT_W on line 84 is unchanged; a wider counter would in any case only zero-extend values that never exceed CNT_MAX-1.
- designer's decision (step 8): **equivalent** - CNT_W changes only for a power-of-two CNT_MAX (+0) or CNT_MAX+1 (+2); the only case is the SPI filter (8), where target_clks-1 wraps to 7 in the 3-bit compare, the same count

### `input_debounce.124.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n) begin`
- after: `if(1'b0) begin`
- AI judgement (step 7): **plausible**, high confidence - With the reset branch at line 124 never taken, disagree_counter is not initialised (X out of power-up) and an asynchronous reset mid-operation no longer clears it, so the flag_out qualification on line 176 can differ after reset.
- designer's decision (step 10): **gap** - counter reset value untested: reset only at time zero, where a two-state simulator holds 0; and the first qualification after reset is not timed to the clock

### `input_debounce.126.CST.1` - 0 -> 1

- before: `disagree_counter <= 0;`
- after: `disagree_counter <= 1;`
- AI judgement (step 7): **plausible**, high confidence - Resetting disagree_counter to 1 means that if flag_in differs from RESET_VALUE right after reset, the line 176 compare is reached one clock early, so flag_out flips a cycle sooner.
- designer's decision (step 10): **gap** - counter reset value untested: reset only at time zero, where a two-state simulator holds 0; and the first qualification after reset is not timed to the clock

### `input_debounce.126.SDL.1` - delete 'disagree_counter <= 0;'

- before: `disagree_counter <= 0;`
- after: `;`
- AI judgement (step 7): **plausible**, high confidence - Without line 126 the counter holds its stale or uninitialised value through reset, so after reset release flag_out (line 176) can flip earlier than the full qualification time, or go X.
- designer's decision (step 10): **gap** - counter reset value untested: reset only at time zero, where a two-state simulator holds 0; and the first qualification after reset is not timed to the clock

### `input_debounce.139.CST.1` - 0 -> 1

- before: `disagree_counter <= 0;`
- after: `disagree_counter <= 1;`
- AI judgement (step 7): **plausible**, high confidence - On the qualifying edge flag_out flips (line 178) and the counter gets 1 instead of 0; if flag_in reverses on the next clock, line 130 keeps counting from 1, so the reverse transition qualifies one clock early.
- designer's decision (step 11): **gap** - a reversal on the clock after a flip may qualify one clock early: the checker starts its hold count at 1 on the flip, so its lower bound is one clock loose in that case

### `input_debounce.176.CTD.1` - drop the term '(flag_in != flag_out)'

- before: `else if ((flag_in != flag_out) && (disagree_counter >= target_clks - 1'b1)) begin`
- after: `else if ((disagree_counter >= target_clks - 1'b1)) begin`
- AI judgement (step 7): **equivalent**, high confidence - The only extra case the mutant allows is flag_in == flag_out, where line 178 assigns flag_out <= flag_in, the value flag_out already holds, so the register never changes.
- designer's decision (step 9): **equivalent** - the extra case is flag_in == flag_out, where flag_out <= flag_in assigns the value it already holds

## Caught only by a lost cover (2)

Counted as caught, but no check failed: the behaviour is observed, not checked.

- `input_debounce.103.AIM.4` - target_clks is written as a terminal count (qualification time minus one), while both compares still subtract one again, so every transition qualifies one clock early: `target_clks = flag_in ?CNT_W'(ASSERT_CLKS) : CNT_W'(RELEASE_CLKS);` -> `target_clks = flag_in ?CNT_W'(ASSERT_CLKS - 1) : CNT_W'(RELEASE_CLKS - 1);`
- `input_debounce.103.AIM.12` - The release qualification time is written as a terminal count (RELEASE_CLKS-1), but the assert time is not, so only a release qualifies one clock early: `target_clks = flag_in ?CNT_W'(ASSERT_CLKS) : CNT_W'(RELEASE_CLKS);` -> `target_clks = flag_in ?CNT_W'(ASSERT_CLKS) : CNT_W'(RELEASE_CLKS - 1);`

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-15 15:33 | f71cb1f | AI wrote mutants (claude-opus-5-5) | asked 8, proposed 4, accepted 4, rejected 0; `ai_runs/2026-11-15_write_mutants_14` |
| 2 | 2026-11-15 15:37 | f71cb1f | AI wrote mutants (claude-opus-5-5) | asked 8, proposed 4, accepted 4, rejected 0; `ai_runs/2026-11-15_write_mutants_15` |
| 3 | 2026-11-15 15:40 | f71cb1f | AI wrote mutants (claude-opus-5-5) | asked 8, proposed 2, accepted 2, rejected 0; `ai_runs/2026-11-15_write_mutants_16` |
| 4 | 2026-11-15 15:45 | f71cb1f | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 7, accepted 7, rejected 0; `ai_runs/2026-11-15_write_mutants_17` |
| 5 | 2026-11-15 15:59 | f71cb1f | designer withdrew AI-written mutants | input_debounce.132.AIM.2 - same fault as AIM.17: the count is not restarted on the edge a release qualifies; the next qualification differs by one clock |
| 6 | 2026-11-15 16:02 | f71cb1f | mutation run - every mutant of the module | 85 mutants: 73 killed, 3 lint, 2 covers, 7 survived; score 91.8% |
| 7 | 2026-11-15 16:03 | f71cb1f | AI judged survivors (claude-opus-5-5) | 7 judged, 3 called equivalent with high confidence; `ai_runs/2026-11-15_judge_survivors_4` |
| 8 | 2026-11-15 16:05 | f71cb1f | designer's decision: equivalent | input_debounce.84.CST.1, input_debounce.84.CST.2 - CNT_W changes only for a power-of-two CNT_MAX (+0) or CNT_MAX+1 (+2); the only case is the SPI filter (8), where target_clks-1 wraps to 7 in the 3-bit compare, the same count |
| 9 | 2026-11-15 16:05 | f71cb1f | designer's decision: equivalent | input_debounce.176.CTD.1 - the extra case is flag_in == flag_out, where flag_out <= flag_in assigns the value it already holds |
| 10 | 2026-11-15 16:05 | f71cb1f | designer's decision: gap | input_debounce.124.CSK.1, input_debounce.126.SDL.1, input_debounce.126.CST.1 - counter reset value untested: reset only at time zero, where a two-state simulator holds 0; and the first qualification after reset is not timed to the clock |
| 11 | 2026-11-15 16:05 | f71cb1f | designer's decision: gap | input_debounce.139.CST.1 - a reversal on the clock after a flip may qualify one clock early: the checker starts its hold count at 1 on the flip, so its lower bound is one clock loose in that case |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (17)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | missing_case | flag_out flip compares the disagreement count against the counter's sizing limit CNT_MAX (the assert time) instead of the target for the pending direction, so the release direction is forgotten | killed | a_ASSERT_and_RELEASE_work |
| 2 | 1 | boundary | The disagreement counter's clear-on-qualify limit uses CNT_MAX instead of the selected target, so the count is not restarted on the edge a release qualifies | withdrawn: same fault as AIM.17: the count is not restarted on the edge a release qualifies; the next qualification differs by one clock |  |
| 3 | 1 | missing_case | The restart on agreement is applied only when flag_in is high, so an aborted assert attempt (flag_in back low while flag_out is low) leaves its partial count in place | killed | a_window_abandoned, a_flag_out_qualified |
| 4 | 1 | sequencing | target_clks is written as a terminal count (qualification time minus one), while both compares still subtract one again, so every transition qualifies one clock early | covers | hit 4 SVA covers, the unmutated run 6 |
| 5 | 2 | reset_init | The clear-on-qualify restart only happens when a release qualifies; on the edge an assert qualifies the disagreement count is left at ASSERT_CLKS-1 | killed | a_flag_out_qualified |
| 6 | 2 | missing_case | The flag_out flip compares the disagreement count against the release time for both directions, so the longer assert qualification is forgotten | killed | a_flag_out_qualified |
| 7 | 2 | boundary | The counter's clear-on-qualify limit is hard-coded to the release time, so during an assert attempt the count restarts every RELEASE_CLKS clocks and never reaches the assert target | killed | a_ASSERT_and_RELEASE_work |
| 8 | 2 | missing_case | The flip rule is written for the assert direction only (flag_in high while flag_out low), so a qualified release never updates flag_out | killed | a_ASSERT_and_RELEASE_work |
| 9 | 3 | reset_init | The restart on agreement is applied only when flag_in is low, so an aborted release attempt (flag_in dips low while flag_out is high, then returns high) leaves its partial count in the disagreement counter | killed | a_window_abandoned, a_flag_out_qualified |
| 10 | 3 | sequencing | The flip compare adds a one-clock lookahead (counter+1) to make up for flag_out being registered, so flag_out flips one clock before the counter reaches its target and restarts | killed | a_flag_out_qualified |
| 11 | 4 | wrong_event | The disagreement counter measures flag_in against the fail-safe reset level RESET_VALUE instead of the believed state flag_out, so it counts time away from reset rather than time disagreeing with flag_out | killed | a_ASSERT_and_RELEASE_work, a_window_abandoned |
| 12 | 4 | boundary | The release qualification time is written as a terminal count (RELEASE_CLKS-1), but the assert time is not, so only a release qualifies one clock early | covers | hit 5 SVA covers, the unmutated run 6 |
| 13 | 4 | missing_case | The disagreement counter only counts the release direction (flag_in low while flag_out is high), the move away from the high reset state, so an assert attempt never builds a count | killed | a_ASSERT_and_RELEASE_work |
| 14 | 4 | reset_init | The disagreement counter is preloaded to a full count in reset, so the first input level seen after reset is accepted without debouncing | killed | a_flag_out_qualified |
| 15 | 4 | missing_case | The disagreement counter only counts an assert attempt (flag_in high while flag_out is low), so the release direction never builds a count | killed | a_ASSERT_and_RELEASE_work |
| 16 | 4 | missing_case | flag_out is only allowed to flip when flag_in moves away from the fail-safe RESET_VALUE, so a return to the reset level (a re-asserted fault, with the default RESET_VALUE of 1) never updates flag_out | killed | a_ASSERT_and_RELEASE_work |
| 17 | 4 | reset_init | The clear-on-qualify restart only happens when an assert qualifies. On the edge a release qualifies, the disagreement count is left at RELEASE_CLKS-1 | killed | a_flag_out_qualified |

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `input_debounce.84.CST.1` | localparam CNT_W: 1 -> 0 | 6:survived |  |
| `input_debounce.84.CST.2` | localparam CNT_W: 1 -> 2 | 6:survived |  |
| `input_debounce.103.AIM.12` | The release qualification time is written as a terminal count (RELEASE_CLKS-1), but the assert time is not, so only a release qualifies one clock early | 6:covers | hit 5 SVA covers, the unmutated run 6 |
| `input_debounce.103.AIM.4` | target_clks is written as a terminal count (qualification time minus one), while both compares still subtract one again, so every transition qualifies one clock early | 6:covers | hit 4 SVA covers, the unmutated run 6 |
| `input_debounce.103.SDL.1` | delete 'target_clks = flag_in ?CNT_W'(ASSERT_CLKS) : CNT_W'(RELEASE_' | 6:lint | make lint: UNDRIVEN |
| `input_debounce.103.SIB.1` | flag_in -> flag_out | 6:killed | a_ASSERT_and_RELEASE_work, a_flag_out_qualified |
| `input_debounce.103.SIB.2` | CNT_W -> CNT_MAX | 6:lint | make lint: WIDTHTRUNC |
| `input_debounce.103.SIB.3` | ASSERT_CLKS -> RELEASE_CLKS | 6:killed | a_flag_out_qualified |
| `input_debounce.103.SIB.4` | CNT_W -> CNT_MAX | 6:lint | make lint: WIDTHTRUNC |
| `input_debounce.103.SIB.5` | RELEASE_CLKS -> ASSERT_CLKS | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.103.STK.1` | target_clks stuck at all-zeros (was 'flag_in ?CNT_W'(ASSERT_CLKS) : CNT_W'(RE') | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.103.STK.2` | target_clks stuck at all-ones (was 'flag_in ?CNT_W'(ASSERT_CLKS) : CNT_W'(RE') | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.103.TRN.1` | swap the branches of ?: | 6:killed | a_ASSERT_and_RELEASE_work, a_flag_out_qualified |
| `input_debounce.103.VNG.1` | target_clks inverted (was 'flag_in ?CNT_W'(ASSERT_CLKS) : CNT_W'(RE') | 6:killed | a_ASSERT_and_RELEASE_work, a_flag_out_qualified |
| `input_debounce.108.EDG.1` | posedge clk -> negedge clk | 6:killed | a_window_abandoned, a_flag_out_qualified |
| `input_debounce.124.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 6:survived |  |
| `input_debounce.124.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.124.UOD.1` | drop the '!' before rst_n | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.126.AIM.14` | The disagreement counter is preloaded to a full count in reset, so the first input level seen after reset is accepted without debouncing | 6:killed | a_flag_out_qualified |
| `input_debounce.126.CST.1` | 0 -> 1 | 6:survived |  |
| `input_debounce.126.SDL.1` | delete 'disagree_counter <= 0;' | 6:survived |  |
| `input_debounce.130.AIM.11` | The disagreement counter measures flag_in against the fail-safe reset level RESET_VALUE instead of the believed state flag_out, so it counts time away from reset rather than time disagreeing with flag_out | 6:killed | a_ASSERT_and_RELEASE_work, a_window_abandoned |
| `input_debounce.130.AIM.13` | The disagreement counter only counts the release direction (flag_in low while flag_out is high), the move away from the high reset state, so an assert attempt never builds a count | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.130.AIM.15` | The disagreement counter only counts an assert attempt (flag_in high while flag_out is low), so the release direction never builds a count | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.130.CSK.1` | if (flag_in != flag_out) -> if (1'b0): never taken | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.130.CSK.2` | if (flag_in != flag_out) -> if (1'b1): always taken | 6:killed | a_flag_out_qualified, a_window_abandoned |
| `input_debounce.130.EDL.1` | delete the else branch at line 130 | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.130.ROR.1` | != -> == | 6:killed | a_window_abandoned, a_ASSERT_and_RELEASE_work +1 |
| `input_debounce.130.SIB.1` | flag_in -> flag_out | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.130.SIB.2` | flag_out -> flag_in | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.132.AIM.7` | The counter's clear-on-qualify limit is hard-coded to the release time, so during an assert attempt the count restarts every RELEASE_CLKS clocks and never reaches the assert target | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.132.AOR.1` | - -> + | 6:killed | a_flag_out_qualified |
| `input_debounce.132.CND.1` | if (disagree_counter < target_clks - 1'b1) -> if (!(...)) | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.132.CSK.1` | if (disagree_counter < target_clks - 1'b1) -> if (1'b0): never taken | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.132.CSK.2` | if (disagree_counter < target_clks - 1'b1) -> if (1'b1): always taken | 6:killed | a_flag_out_qualified |
| `input_debounce.132.CST.1` | 1'b1 -> 1'b0 | 6:killed | a_flag_out_qualified |
| `input_debounce.132.ROR.1` | < -> <= | 6:killed | a_flag_out_qualified |
| `input_debounce.132.ROR.2` | < -> > | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.134.AOR.1` | + -> - | 6:killed | a_flag_out_qualified, a_ASSERT_and_RELEASE_work |
| `input_debounce.134.CST.1` | 1 -> 0 | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.134.CST.2` | 1 -> 2 | 6:killed | a_flag_out_qualified |
| `input_debounce.134.SDL.1` | delete 'disagree_counter <= disagree_counter + 1;' | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.134.STK.1` | disagree_counter stuck at all-zeros (was 'disagree_counter + 1') | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.134.STK.2` | disagree_counter stuck at all-ones (was 'disagree_counter + 1') | 6:killed | a_flag_out_qualified, a_ASSERT_and_RELEASE_work |
| `input_debounce.134.VNG.1` | disagree_counter inverted (was 'disagree_counter + 1') | 6:killed | a_flag_out_qualified, a_ASSERT_and_RELEASE_work |
| `input_debounce.137.AIM.17` | The clear-on-qualify restart only happens when an assert qualifies. On the edge a release qualifies, the disagreement count is left at RELEASE_CLKS-1 | 6:killed | a_flag_out_qualified |
| `input_debounce.137.AIM.5` | The clear-on-qualify restart only happens when a release qualifies; on the edge an assert qualifies the disagreement count is left at ASSERT_CLKS-1 | 6:killed | a_flag_out_qualified |
| `input_debounce.139.CST.1` | 0 -> 1 | 6:survived |  |
| `input_debounce.139.SDL.1` | delete 'disagree_counter <= 0;' | 6:killed | a_flag_out_qualified |
| `input_debounce.145.AIM.3` | The restart on agreement is applied only when flag_in is high, so an aborted assert attempt (flag_in back low while flag_out is low) leaves its partial count in place | 6:killed | a_window_abandoned, a_flag_out_qualified |
| `input_debounce.145.AIM.9` | The restart on agreement is applied only when flag_in is low, so an aborted release attempt (flag_in dips low while flag_out is high, then returns high) leaves its partial count in the disagreement counter | 6:killed | a_window_abandoned, a_flag_out_qualified |
| `input_debounce.147.CST.1` | 0 -> 1 | 6:killed | a_window_abandoned |
| `input_debounce.147.SDL.1` | delete 'disagree_counter <= 0;' | 6:killed | a_window_abandoned, a_flag_out_qualified |
| `input_debounce.154.EDG.1` | posedge clk -> negedge clk | 6:killed | a_flag_out_qualified |
| `input_debounce.170.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 6:killed | a_flag_out_takes_RESET |
| `input_debounce.170.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.170.UOD.1` | drop the '!' before rst_n | 6:killed | a_flag_out_takes_RESET, a_flag_out_qualified +1 |
| `input_debounce.172.SDL.1` | delete 'flag_out <= RESET_VALUE;' | 6:killed | a_flag_out_takes_RESET |
| `input_debounce.172.STK.1` | flag_out stuck at all-zeros (was 'RESET_VALUE') | 6:killed | a_flag_out_takes_RESET |
| `input_debounce.172.STK.2` | flag_out stuck at all-ones (was 'RESET_VALUE') | 6:killed | a_flag_out_takes_RESET |
| `input_debounce.172.VNG.1` | flag_out inverted (was 'RESET_VALUE') | 6:killed | a_flag_out_takes_RESET |
| `input_debounce.176.AIM.1` | flag_out flip compares the disagreement count against the counter's sizing limit CNT_MAX (the assert time) instead of the target for the pending direction, so the release direction is forgotten | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.176.AIM.10` | The flip compare adds a one-clock lookahead (counter+1) to make up for flag_out being registered, so flag_out flips one clock before the counter reaches its target and restarts | 6:killed | a_flag_out_qualified |
| `input_debounce.176.AIM.16` | flag_out is only allowed to flip when flag_in moves away from the fail-safe RESET_VALUE, so a return to the reset level (a re-asserted fault, with the default RESET_VALUE of 1) never updates flag_out | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.176.AIM.6` | The flag_out flip compares the disagreement count against the release time for both directions, so the longer assert qualification is forgotten | 6:killed | a_flag_out_qualified |
| `input_debounce.176.AIM.8` | The flip rule is written for the assert direction only (flag_in high while flag_out low), so a qualified release never updates flag_out | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.176.AOR.1` | - -> + | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.176.CND.1` | if ((flag_in != flag_out) && (disagree_counter >= targ) -> if (!(...)) | 6:killed | a_flag_out_qualified |
| `input_debounce.176.CSK.1` | if ((flag_in != flag_out) && (disagree_counter >= targ) -> if (1'b1): always taken | 6:killed | a_flag_out_qualified |
| `input_debounce.176.CST.1` | 1'b1 -> 1'b0 | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.176.CTD.1` | drop the term '(flag_in != flag_out)' | 6:survived |  |
| `input_debounce.176.CTD.2` | drop the term '(disagree_counter >= target_clks - 1'b1)' | 6:killed | a_flag_out_qualified |
| `input_debounce.176.CTN.1` | negate the term '(flag_in != flag_out)' | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.176.CTN.2` | negate the term '(disagree_counter >= target_clks - 1'b1)' | 6:killed | a_flag_out_qualified |
| `input_debounce.176.EDL.1` | delete the else branch at line 176 | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.176.LCR.1` | && -> \|\| | 6:killed | a_flag_out_qualified |
| `input_debounce.176.ROR.1` | != -> == | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.176.ROR.2` | >= -> <= | 6:killed | a_flag_out_qualified |
| `input_debounce.176.ROR.3` | >= -> > | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.176.SIB.1` | flag_in -> flag_out | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.176.SIB.2` | flag_out -> flag_in | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.178.SDL.1` | delete 'flag_out <= flag_in;' | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.178.STK.1` | flag_out stuck at all-zeros (was 'flag_in') | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.178.STK.2` | flag_out stuck at all-ones (was 'flag_in') | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.178.VNG.1` | flag_out inverted (was 'flag_in') | 6:killed | a_ASSERT_and_RELEASE_work |
| `input_debounce.132.AIM.2` | The disagreement counter's clear-on-qualify limit uses CNT_MAX instead of the selected target, so the count is not restarted on the edge a release qualifies | not run (withdrawn at step 5) |  |
