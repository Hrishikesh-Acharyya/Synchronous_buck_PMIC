# Judgement of surviving mutants - 2026-11-17 - commit 58da85b

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Mutants listed: 4; passed lint and sent to triage: 4; judged: 4; judged equivalent with high confidence: 1; untriaged: 0

| Chunk | Mutants | Outcome | Note |
|---|---:|---|---|
| 001_pwm_stats | 4 | ok | 1 judged equivalent (high confidence) |

## Judged equivalent (high confidence)

- `pwm_stats.146.STK.2`: Line 146 only runs inside the branch guarded by `period_counter == '1` at line 144. There period_counter is exactly all-ones at the full width CNT_W, which is also duty_count's width, so assigning '1 writes the same value. If period_counter is X, the condition is not true and the branch does not run in either version.

## Judged a real gap - the edit changes behaviour and no test noticed

- `pwm_stats.84.CSK.1` (high): With the reset branch at line 84 never taken, pwm_sync_d is no longer cleared and keeps tracking pwm_sync, including on the negedge of rst_n. If pwm_sync is 1 when reset is released, the original sees a rise (pwm_sync_d=0) and holds period_counter at 0 (lines 129-132), while the mutant sees no rise and counts to 1, so the next prev_period/duty_count capture is off by one; pwm_sync_d is also X at power-up.
- `pwm_stats.86.CST.1` (high): With pwm_sync_d reset to 1, a pwm_sync that is high at the first clock after reset no longer produces pwm_rise (line 105). period_counter then increments to 1 instead of being cleared to 0 at line 132, so the next captured duty_count/prev_period is off by one.
- `pwm_stats.86.SDL.1` (high): Without line 86, pwm_sync_d keeps its pre-reset value (or X at power-up) through reset. If it was 1 and pwm_sync is 1 when reset is released, the pwm_rise at line 129 is missed and period_counter counts from 1 instead of 0. That changes the captured prev_period/duty_count values.
