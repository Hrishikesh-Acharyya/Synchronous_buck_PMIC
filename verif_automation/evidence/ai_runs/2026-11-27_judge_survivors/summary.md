# Judgement of surviving mutants - 2026-11-27 - commit 8d82e7e

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Mutants listed: 38; passed lint and sent to triage: 38; judged: 38; judged equivalent with high confidence: 0; untriaged: 0

| Chunk | Mutants | Outcome | Note |
|---|---:|---|---|
| 001_fault_cause | 38 | ok | 0 judged equivalent (high confidence) |

## Judged equivalent (high confidence)

None.

## Judged a real gap - the edit changes behaviour and no test noticed

- `fault_cause.104.AIM.108` (high): With ss_active=run_active=0 and latch_state=1, the mutant opens the gate at line 104. Causes are then captured at lines 205-209 and fault_time is stamped at line 166, but the original records nothing while stopped.
- `fault_cause.104.AIM.86` (high): For one clock after ss_active/run_active fall, running_q keeps convertor_running high. A cause that appears on that clock is captured at lines 205-209 in the mutant only.
- `fault_cause.118.AIM.15` (high): While running, if latch_state=1, latch_assert=0 and window_trip=1, the mutant leaves ovp low. fault_reg[BIT_OVP] is then not set at line 208, so the output differs.
- `fault_cause.118.AIM.57` (high): While running, if latch_state=1, latch_assert=0 and uvlo_state=1, the mutant suppresses ovp. BIT_OVP is then missing from fault_reg (line 208).
- `fault_cause.118.AIM.60` (high): If fault_reg already holds a cause (say OTP), a later latch_state=1 with latch_assert=0 sets BIT_OVP in the original but not in the mutant.
- `fault_cause.118.AIM.90` (high): While running, if otp_state=1 together with latch_state=1 and latch_assert=0, the mutant does not infer ovp. BIT_OVP is not recorded at line 208.
- `fault_cause.138.AIM.17` (high): With fault_reg holding only BIT_OVP, a new live cause makes episode_start true in the mutant. Line 166 then re-stamps fault_time, which the original holds.
- `fault_cause.138.AIM.4` (high): If the episode is stamped when timestamp_ms=0, fault_time stays 0 while fault_reg is non-empty. A later cause then re-stamps fault_time in the mutant; it also stamps whenever fault_time is 0 even though fault_reg is non-empty.
- `fault_cause.138.AIM.70` (high): During ss_active with fault_reg already non-empty, a live cause re-stamps fault_time at line 166 in the mutant. The original holds the earlier stamp.
- `fault_cause.138.AIM.73` (high): With the converter stopped, fault_reg empty and ovp or latch_assert high, the mutant stamps fault_time from timestamp_ms. The original leaves it at 0.
- `fault_cause.138.AIM.84` (high): With fault_reg holding only BIT_LATCH and a cause still live while running, the mutant keeps asserting episode_start. It re-stamps fault_time on each such clock, which the original does not.
- `fault_cause.139.AIM.100` (high): With fault_reg empty, if UVLO is the only cause during ss_active, the mutant does not assert episode_start. fault_time stays 0 while fault_reg[BIT_UVLO] is set.
- `fault_cause.165.AIM.2` (high): fault_reg_read_done can pulse while fault_reg is empty and a cause is live while running. Then episode_start is also true and the mutant stamps fault_time where the original clears it.
- `fault_cause.165.AIM.96` (high): A read while the converter is stopped and fault_time is non-zero clears fault_time in the original. The mutant leaves it unchanged.
- `fault_cause.197.AIM.61` (high): A read while the converter is stopped and fault_reg is non-empty clears fault_reg in the original. The mutant does not clear it.
- `fault_cause.197.AIM.83` (high): A read while fault_reg is empty, the converter is running and a cause is live falls through to the capture branch in the mutant. fault_reg becomes non-zero where the original stays 0.
- `fault_cause.203.AIM.40` (high): With the converter stopped and latch_assert=1, the mutant captures latch_assert and any other live causes into fault_reg. The original records nothing.
- `fault_cause.205.AIM.115` (high): While running, if otp_state=1 and latch_state=1, the mutant does not set BIT_OTP.
- `fault_cause.205.AIM.46` (high): While running, if otp_state=1 and uvlo_state=1, the mutant does not set BIT_OTP.
- `fault_cause.205.AIM.56` (high): An OTP during ss_active with run_active=0 sets BIT_OTP in the original but not in the mutant.
- `fault_cause.205.AIM.87` (high): With BIT_OVP already recorded, a later OTP, UVLO or window trip is no longer set by the mutant. The original OR-accumulates every cause.
- `fault_cause.206.AIM.10` (high): If otp_state and uvlo_state are both high while running, the else-if chain records only BIT_OTP on that clock. A one-clock UVLO is lost.
- `fault_cause.206.AIM.18` (high): A UVLO that arrives after another cause is already recorded is dropped by the mutant, so BIT_UVLO differs.
- `fault_cause.206.AIM.63` (high): While running, if uvlo_state=1 and latch_state=1, the mutant does not set BIT_UVLO.
- `fault_cause.206.AIM.7` (high): A UVLO during ss_active only sets BIT_UVLO in the original but not in the mutant.
- `fault_cause.206.AIM.76` (high): While running, if uvlo_state is high together with window_trip or window_trip_SS, the mutant does not set BIT_UVLO.
- `fault_cause.206.AIM.93` (high): While running, if uvlo_state and otp_state are both high, the mutant does not set BIT_UVLO.
- `fault_cause.206.AIM.95` (high): Once BIT_UVLO is recorded, a later clock with ss_active=1 and uvlo_state=0 clears it in the mutant. The original never clears individual bits.
- `fault_cause.207.AIM.62` (high): While running, if a window trip happens together with latch_state=1 and latch_assert=0 (ovp=1), the mutant does not set BIT_OC.
- `fault_cause.207.AIM.94` (high): While running, if a window trip happens together with uvlo_state=1, the mutant does not set BIT_OC.
- `fault_cause.208.AIM.37` (high): An inferred ovp during ss_active only sets BIT_OVP in the original but not in the mutant.
- `fault_cause.209.AIM.16` (high): With BIT_OVP already recorded, a later latch_assert while running clears BIT_OVP in the mutant. The original keeps it set.
- `fault_cause.209.AIM.34` (high): A latch_assert during ss_active only sets BIT_LATCH in the original but not in the mutant.
- `fault_cause.209.AIM.53` (high): A latch_assert while running clears BIT_OC in the mutant, whether it was recorded earlier or set on the same clock. The original keeps it.
- `fault_cause.209.AIM.77` (high): With BIT_OC already recorded, a later latch_assert does not set BIT_LATCH in the mutant.
- `fault_cause.211.AIM.104` (high): With the converter stopped, no read pending and otp_state=0, the new else branch clears a recorded BIT_OTP. The original holds it.
- `fault_cause.211.AIM.52` (high): With the converter stopped and latch_state=1, latch_assert=0, the mutant sets BIT_OVP. The original records nothing while stopped.
- `fault_cause.211.AIM.67` (high): With the converter stopped and latch_assert=1, the mutant sets BIT_LATCH. The original records nothing while stopped.
