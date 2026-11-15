# Judgement of surviving mutants - 2026-11-15 - commit f71cb1f

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Mutants listed: 7; passed lint and sent to triage: 7; judged: 7; judged equivalent with high confidence: 3; untriaged: 0

| Chunk | Mutants | Outcome | Note |
|---|---:|---|---|
| 001_input_debounce | 7 | ok | 3 judged equivalent (high confidence) |

## Judged equivalent (high confidence)

- `input_debounce.176.CTD.1`: The only extra case the mutant allows is flag_in == flag_out, where line 178 assigns flag_out <= flag_in, the value flag_out already holds, so the register never changes.
- `input_debounce.84.CST.1`: With defaults CNT_MAX=max(50000,10000)=50000 (CLK_HZ=50e6, pkg lines 258/261), and $clog2(50000)=$clog2(50001)=16, so CNT_W and every signal width are unchanged. (Also holds for pmic_top overrides: 1e6 gives 20 either way; for 8 the width drops to 3 but target_clks-1'b1 wraps 0-1 to 7 in 3-bit context on lines 132/176, identical to the original 7.)
- `input_debounce.84.CST.2`: $clog2(50002)=$clog2(50001)=16 for the default CNT_MAX=50000, so CNT_W on line 84 is unchanged; a wider counter would in any case only zero-extend values that never exceed CNT_MAX-1.

## Judged a real gap - the edit changes behaviour and no test noticed

- `input_debounce.124.CSK.1` (high): With the reset branch at line 124 never taken, disagree_counter is not initialised (X out of power-up) and an asynchronous reset mid-operation no longer clears it, so the flag_out qualification on line 176 can differ after reset.
- `input_debounce.126.CST.1` (high): Resetting disagree_counter to 1 means that if flag_in differs from RESET_VALUE right after reset, the line 176 compare is reached one clock early, so flag_out flips a cycle sooner.
- `input_debounce.126.SDL.1` (high): Without line 126 the counter holds its stale or uninitialised value through reset, so after reset release flag_out (line 176) can flip earlier than the full qualification time, or go X.
- `input_debounce.139.CST.1` (high): On the qualifying edge flag_out flips (line 178) and the counter gets 1 instead of 0; if flag_in reverses on the next clock, line 130 keeps counting from 1, so the reverse transition qualifies one clock early.
