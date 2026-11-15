# Judgement of surviving mutants - 2026-11-15 - commit e6d9ec9

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Mutants listed: 22; passed lint and sent to triage: 22; judged: 22; judged equivalent with high confidence: 1; untriaged: 0

| Chunk | Mutants | Outcome | Note |
|---|---:|---|---|
| 001_pwm_mask | 22 | ok | 1 judged equivalent (high confidence) |

## Judged equivalent (high confidence)

- `pwm_mask.84.SDL.1`: In an always_ff, a register that is not assigned keeps its value. Deleting the self-assignment 'run_counter <= run_counter' at line 84 therefore leaves the same hold behaviour.

## Judged a real gap - the edit changes behaviour and no test noticed

- `pwm_mask.118.CSK.1` (high): Without the reset branch, pwm_out is not forced to 0 during reset. It keeps following pwm_sync & pulse_allowed or stays undefined.
- `pwm_mask.120.SDL.1` (high): pwm_out is no longer cleared by reset. If reset is asserted while pwm_out is high, it stays 1 through reset, and it is undefined at power-up.
- `pwm_mask.65.BDL.1` (high): Emptying the reset body means lines 67-68 never run, so run_counter and pulse_allowed are undefined or stale after reset. If pwm_sync is high right after reset, pwm_out (line 125) and the truncation point change.
- `pwm_mask.65.CSK.1` (high): Without the reset branch at line 65, run_counter and pulse_allowed are never initialised and keep updating during reset. pwm_out after reset (line 125) then depends on unknown or old state.
- `pwm_mask.67.CST.1` (high): Resetting run_counter to 1 means a pulse that is already high at reset release reaches max_on_counts at line 76 one clock earlier. With max_on_counts=0 it also takes a different path.
- `pwm_mask.67.SDL.1` (high): run_counter is no longer cleared by reset. If pwm_sync is high when reset is released, counting starts from a stale or unknown value, which changes when line 76 closes the envelope.
- `pwm_mask.68.CST.1` (high): With pwm_sync high on the first edge after reset, line 125 registers pwm_out=0 instead of 1, cutting one clock off the pulse.
- `pwm_mask.68.SDL.1` (high): pulse_allowed is not set by reset, so on the first clock after release pwm_out = pwm_sync & pulse_allowed (line 125) uses an unknown or stale value instead of 1.
- `pwm_mask.76.AIM.4` (high): If max_on_counts is lowered below run_counter mid-pulse, != stays true, so line 78 keeps counting and pulse_allowed stays 1. The original closes the envelope there.
- `pwm_mask.76.AIM.9` (high): With max_on_counts==0 the original takes the else branch (pulse_allowed<=0), but the mutant counts and keeps pulse_allowed=1. The pulse passes through untruncated.
- `pwm_mask.78.AOR.1` (high): Decrementing from 0 wraps to all-ones, so the ceiling compare at line 76 fails after one clock and pulses are truncated early.
- `pwm_mask.78.CST.2` (high): Counting by 2 reaches max_on_counts in about half the clocks, which shortens the enforced on-time.
- `pwm_mask.78.STK.2` (high): run_counter jumps straight to all-ones on the first high clock, so line 76 fails on the next clock and the pulse is cut almost immediately instead of after max_on_counts clocks.
- `pwm_mask.78.VNG.1` (high): The inverted increment makes run_counter jump to a large value, which changes when line 76 fails and therefore the truncated pulse width.
- `pwm_mask.79.SDL.1` (high): pulse_allowed can be 0 while pwm_sync is high and run_counter < max_on_counts if max_on_counts rises after line 85 has fired. The original re-opens at line 79; the mutant stays closed.
- `pwm_mask.84.AIM.1` (high): With pwm_sync stuck high, run_counter keeps counting in the saturation branch and eventually wraps below max_on_counts. Line 76 then re-opens the envelope, which the original prevents.
- `pwm_mask.84.AIM.8` (high): If max is lowered below run_counter, the mutant clamps run_counter down to it. If max is then raised but stays below the original held count, the mutant re-opens at lines 76/79 while the original stays closed.
- `pwm_mask.84.STK.2` (high): Once saturated, run_counter becomes all-ones instead of holding. If max_on_counts is later raised above the held count but stays below all-ones, the original re-opens via line 76 and the mutant does not.
- `pwm_mask.84.VNG.1` (high): Inverting run_counter in the saturation branch can drop it below max_on_counts (e.g. ~max when max is large). Line 76 then re-opens the envelope mid-pulse, giving a double pulse.
- `pwm_mask.85.AIM.10` (high): If max_on_counts drops below run_counter mid-pulse, run_counter != max_on_counts, so pulse_allowed is not cleared and pwm_out stays high where the original truncates.
- `pwm_mask.94.AIM.6` (high): On the first low clock after a pulse, run_counter is still nonzero, so pulse_allowed becomes 0. If pwm_sync goes high again after a one-clock low gap, line 125 outputs 0 instead of 1.
