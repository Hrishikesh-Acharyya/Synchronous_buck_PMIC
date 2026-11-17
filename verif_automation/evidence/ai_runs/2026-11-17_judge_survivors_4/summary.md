# Judgement of surviving mutants - 2026-11-17 - commit 743c83a

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Mutants listed: 9; passed lint and sent to triage: 9; judged: 9; judged equivalent with high confidence: 1; untriaged: 0

| Chunk | Mutants | Outcome | Note |
|---|---:|---|---|
| 001_soft_start | 9 | ok | 1 judged equivalent (high confidence) |

## Judged equivalent (high confidence)

- `soft_start.44.CST.2`: With the package values, MIN_ON_COUNTS = (50*240+999)/1000 = 12 and ON_TIME_W = $clog2(83+1) = 7. Bit 6 of 12 is 0, so MIN_ON_COUNTS[5:0] zero-extended to 7 bits is still 12, the same as [6:0]; pmic_top.sv:319 does not override the parameters, so MIN_ON_CNT (line 44) is unchanged.

## Judged a real gap - the edit changes behaviour and no test noticed

- `soft_start.115.SDL.1` (high): Without line 115, reset leaves cycle_counter as it was (X at power-up, or a mid-ramp value). If ss_active goes high right after reset without passing through the clearing branch at line 176, which the header does not rule out, the step timing at lines 128/152 changes.
- `soft_start.117.SDL.1` (high): SS_done is an output port. Without line 117, an asserted SS_done stays 1 through reset instead of going to 0, and starts as X at power-up. Both are directly visible at the port.
- `soft_start.128.AIM.52` (high): cycles_per_step is an input that can drop below the running cycle_counter mid-ramp. The mutant then wraps cycle_counter to 0 at once, while the original counts up to 127 and wraps. The step condition on line 152 then fires at different times, so max_on_counts changes.
- `soft_start.152.AIM.43` (high): If cycles_per_step is lowered below the running cycle_counter, the mutant's >= test steps max_on_counts on every pwm_fall until the counter wraps. The original's == test does not step. This changes max_on_counts and SS_done timing at the ports.
- `soft_start.62.CSK.1` (high): With the asynchronous reset removed, pwm_sync_d is never cleared: it starts as X, or follows pwm_sync on clocks during reset. If pwm_sync is high just before reset releases and ss_active is high at once, pwm_fall (line 88) can fire on the first clock where the original gives 0, which shifts cycle_counter and the ramp steps.
- `soft_start.64.SDL.1` (high): Without line 64, pwm_sync_d keeps its value from before reset (or X at power-up) instead of 0. A stale 1 makes a false pwm_fall on the first clock after reset if pwm_sync is 0 and ss_active is high, which changes cycle_counter and when max_on_counts steps.
- `soft_start.68.AIM.47` (high): On the first S_SS clock, pwm_sync_d is 0 in the mutant but holds the previous pwm_sync in the original. If PWM was high before S_SS and falls on that clock, the original sees pwm_fall and the mutant does not, so cycle_counter and step timing (lines 126-154) change.
- `soft_start.68.AIM.6` (high): Outside S_SS, pwm_sync_d stops updating and keeps a stale value, so on the first S_SS clock pwm_fall (line 88) can differ from the original: a missed fall, or a false one. That changes cycle_counter and when max_on_counts steps.
