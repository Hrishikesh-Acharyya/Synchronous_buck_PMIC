# Judgement of surviving mutants - 2026-11-17 - commit 34b8ec6

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Mutants listed: 21; passed lint and sent to triage: 21; judged: 21; judged equivalent with high confidence: 1; untriaged: 0

| Chunk | Mutants | Outcome | Note |
|---|---:|---|---|
| 001_pgood_gen | 21 | ok | 1 judged equivalent (high confidence) |

## Judged equivalent (high confidence)

- `pgood_gen.134.SDL.1`: This branch runs only when qualify_counter == TARGET (line 132), so the deleted line wrote TARGET into a register that already holds TARGET. Without it, the register keeps the same value, and nothing else in the module depends on the assignment.

## Judged a real gap - the edit changes behaviour and no test noticed

- `pgood_gen.114.CSK.1` (high): Without the async reset, qualify_counter is not cleared by rst_n and starts as X. If the counter was at TARGET and reset is asserted while run_active and pgood_comp are high (not ruled out by the header), PGOOD at line 169 stays 1 instead of 0.
- `pgood_gen.116.CST.1` (high): Resetting the counter to 1 means it reaches TARGET (4050) one pwm_fall sooner after reset, so PGOOD asserts one switching cycle early.
- `pgood_gen.116.SDL.1` (high): With the reset assignment deleted, qualify_counter holds its value through reset. A counter at TARGET with run_active and pgood_comp high keeps PGOOD (line 169) high during and after reset, and the power-up value is X.
- `pgood_gen.124.AIM.7` (high): When pwm_fall coincides with pgood_comp or run_active being low, the counter increments instead of clearing. The good-cycle run is no longer required to be consecutive, so PGOOD can assert earlier.
- `pgood_gen.132.CSK.2` (high): With the condition always true, the first pwm_fall loads TARGET directly, so PGOOD asserts after one good cycle instead of 4050.
- `pgood_gen.140.AOR.1` (high): Counting down from 0 wraps to 4095 (12-bit counter) and reaches TARGET = 4050 after 46 pwm_fall pulses instead of 4050, so PGOOD asserts far earlier.
- `pgood_gen.64.CSK.1` (high): Without the async reset at line 64, pwm_sync_d keeps tracking pwm_sync during reset (or stays X if no clock ran), instead of being forced to 0. If pwm_sync was 1 at the last edge before reset is released and is 0 at the first edge after, pwm_fall fires and the counter at line 140 advances one extra time, so PGOOD asserts a cycle earlier.
- `pgood_gen.66.CST.1` (high): Resetting pwm_sync_d to 1 makes pwm_fall (line 89) pulse at the first edge after reset whenever pwm_sync is low. If run_active and pgood_comp are high, that pulse gives one extra count, so PGOOD asserts one switching cycle earlier.
- `pgood_gen.66.SDL.1` (high): With the reset assignment deleted, pwm_sync_d holds its value from before reset (X at power-up). A held 1 gives a pwm_fall pulse at the first edge after reset if pwm_sync is low, which advances qualify_counter (line 140) one extra time and moves PGOOD's assertion earlier.
- `pgood_gen.70.AIM.13` (high): pwm_sync_d is frozen while run_active is low. At the first edge with run_active high, pwm_fall at line 89 compares the live pwm_sync with a stale sample, so it can produce a spurious count or miss a real one. That shifts when qualify_counter reaches TARGET and so when PGOOD rises.
- `pgood_gen.72.STK.2` (high): With pwm_sync_d stuck at 1, pwm_fall at line 89 becomes ~pwm_sync. The counter then advances on every clock that PWM is low instead of once per cycle, so PGOOD asserts far sooner.
- `pgood_gen.72.VNG.1` (high): pwm_fall becomes ~pwm_sync(previous) & ~pwm_sync, which is high on every clock where PWM has been low for two samples. The count rate changes, and so does PGOOD timing.
- `pgood_gen.79.AIM.16` (high): A registered pwm_fall lags by one clock and has no reset value. Line 124 is evaluated against the same-clock run_active and pgood_comp, so a delayed pulse can land on a clock where the clear condition holds (or not) differently than in the original, which changes the count. PGOOD timing changes, and an X after reset is also possible.
- `pgood_gen.89.AIM.1` (high): XOR fires on both PWM edges, so qualify_counter advances twice per switching cycle and PGOOD asserts in roughly half the qualifying time.
- `pgood_gen.89.AIM.2` (high): Counting on rising edges instead of falling edges moves each increment by the PWM high time. A pgood_comp dip or a run_active drop between the two edges then gives a different count, and the final increment (and PGOOD rise) lands on a different clock.
- `pgood_gen.89.CTD.2` (high): pwm_fall = pwm_sync_d is high on every clock after PWM has been high, so the counter at line 140 advances many times per switching cycle instead of once.
- `pgood_gen.89.CTN.1` (high): ~pwm_sync_d & ~pwm_sync is high on every clock that PWM stays low. The counter advances many times per cycle and PGOOD asserts much earlier.
- `pgood_gen.89.LCR.1` (high): pwm_sync_d | ~pwm_sync is high on most clocks, so the counter advances far more often than once per cycle and PGOOD asserts early.
- `pgood_gen.89.UOD.1` (high): pwm_sync_d & pwm_sync is high on every clock that PWM stays high, so the count rate changes and PGOOD asserts at a different time.
- `pgood_gen.89.VNG.1` (high): The inverted pwm_fall is high on almost every clock except the falling edge. The counter then advances nearly every clock and PGOOD timing changes drastically.
