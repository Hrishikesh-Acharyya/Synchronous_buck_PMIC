# Judgement of surviving mutants - 2026-11-27 - commit 001df27

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Mutants listed: 44; passed lint and sent to triage: 44; judged: 44; judged equivalent with high confidence: 0; untriaged: 0

| Chunk | Mutants | Outcome | Note |
|---|---:|---|---|
| 001_fault_LED | 40 | ok | 0 judged equivalent (high confidence) |
| 002_fault_LED | 4 | ok | 0 judged equivalent (high confidence) |

## Judged equivalent (high confidence)

None.

## Judged a real gap - the edit changes behaviour and no test noticed

- `fault_LED.100.CST.1` (high): Resetting blink to 1 at line 100 inverts the blink phase. With strike_level non-zero right after reset, Red_LED1 (line 193) reads 1 where it should read 0.
- `fault_LED.100.SDL.1` (high): Without line 100, blink is not reset and stays unknown or stale. Red_LED1 follows it at line 193 whenever strike_level is non-zero.
- `fault_LED.133.AIM.57` (high): With uvlo_state=1, ss_active=1 and no other faults, the mutated line 133 gives currently_faulted=0, so Green_LED at line 149 lights where the original keeps it dark. The inputs are unconstrained.
- `fault_LED.149.AIM.35` (high): With strike_level non-zero, ss_active=run_active=0 and no fault, the mutant lights Green_LED and the original line 149 does not.
- `fault_LED.149.AIM.42` (high): Because && binds tighter than ||, ss_active=1 with a live fault lights Green_LED in the mutant, while the original line 149 gives 0.
- `fault_LED.149.AIM.63` (high): With ss_active=1, strike_level non-zero, run_active=0 and no fault, the mutant gives Green_LED=0 where the original line 149 gives 1.
- `fault_LED.149.AIM.75` (high): When ss_active and run_active both drop, the mutant keeps Green_LED at its old value (possibly 1), while the original line 149 clears it.
- `fault_LED.162.AIM.58` (high): When ss_active and run_active are both 0, the mutant holds pgood_LED while the original line 163 follows pgood, so a change in pgood is visible only in the original.
- `fault_LED.163.AIM.10` (high): With pgood=1 and run_active=0, the mutant drives pgood_LED to 0 where the original line 163 drives 1.
- `fault_LED.163.AIM.28` (high): After pgood goes 1 and then 0, the mutant keeps pgood_LED at 1 while the original line 163 clears it.
- `fault_LED.163.AIM.54` (high): With pgood=1 and ss_active=1, the mutant gives pgood_LED=0 where the original line 163 gives 1.
- `fault_LED.163.AIM.59` (high): With pgood=0 and run_active=1, the mutant lights pgood_LED where the original line 163 keeps it dark.
- `fault_LED.163.AIM.85` (high): If pgood drops while run_active=1 and pgood_LED is already 1, the mutant keeps the LED lit while the original line 163 clears it.
- `fault_LED.189.CSK.1` (high): With the reset at line 189 disabled, Red_LED1 is not cleared during reset; at negedge rst_n or on clocks during reset it takes the else branches instead, for example 1 if latch_state is high.
- `fault_LED.189.SDL.1` (high): Without the reset assignment at line 189, Red_LED1 keeps its unknown or previous value through reset instead of going to 0.
- `fault_LED.191.AIM.14` (high): With strike_level=3 and no latch, the mutant holds Red_LED1 solid at 1 while the original follows blink at line 193. strike_level is an unconstrained input.
- `fault_LED.191.AIM.55` (high): With latch_state=1 and strike_level=0, the original line 191 sets Red_LED1=1; the mutant falls through to line 195 and gives 0.
- `fault_LED.191.AIM.70` (high): After a latch lights Red_LED1 and the latch inputs then drop with strike_level=0, the mutant keeps the LED at 1 while the original line 195 clears it.
- `fault_LED.191.AIM.82` (high): With latch_state=1, otp_state=1 and strike_level=0, the mutant does not set Red_LED1 solid and drives 0 where the original line 191 drives 1.
- `fault_LED.193.AIM.15` (high): With strike_level non-zero, otp_state=1, no latch and blink=1, the mutant drives Red_LED1=0 where the original line 193 drives 1.
- `fault_LED.193.AIM.30` (high): With strike_level non-zero, blink=1 and ss_active=run_active=0, the mutant gives Red_LED1=0 where the original line 193 gives 1.
- `fault_LED.193.AIM.60` (high): With strike_level non-zero, blink=0 and the converter not switching, the mutant gives Red_LED1=1 where the original line 193 gives 0.
- `fault_LED.193.AIM.76` (high): With strike_level=2 and blink=1, the mutant falls through to line 195 and gives 0 where the original line 193 gives 1.
- `fault_LED.195.AIM.62` (high): If strike_level drops to 0 while Red_LED1=1 and blink=1, the mutant keeps the LED at 1 while the original line 195 clears it.
- `fault_LED.195.AIM.7` (high): Holding Red_LED1 at line 195 leaves it at 1 after the latch or strikes clear, while the original drives 0.
- `fault_LED.195.SDL.1` (high): Deleting the clear at line 195 makes Red_LED1 hold its value, so it stays at 1 after the latch or strikes clear, while the original drives 0.
- `fault_LED.209.AIM.49` (high): After otp_state goes 1 and then 0 with run_active=0, the mutant keeps Red_LED2=1 while the original line 210 clears it.
- `fault_LED.209.CSK.1` (high): With the reset at line 209 disabled, Red_LED2 follows otp_state during reset (and at negedge rst_n) instead of being held at 0.
- `fault_LED.209.SDL.1` (high): Without the reset assignment at line 209, Red_LED2 keeps its unknown or previous value through reset instead of 0.
- `fault_LED.210.AIM.45` (high): With otp_state=1 and latch_state=1, the mutant gives Red_LED2=0 where the original line 210 gives 1.
- `fault_LED.210.AIM.48` (high): With otp_state=1 and ss_active=run_active=0, the mutant gives Red_LED2=0 where the original line 210 gives 1.
- `fault_LED.210.AIM.71` (high): The mutant updates Red_LED2 only at the blink terminal count, so a change in otp_state shows up millions of cycles later than the per-clock update at line 210.
- `fault_LED.210.AIM.84` (high): After OTP lights Red_LED2, if otp_state drops while latch_state=1, the mutant keeps the LED at 1 while the original line 210 clears it.
- `fault_LED.210.AIM.86` (high): After OTP lights Red_LED2, if otp_state drops while strike_level is non-zero, the mutant keeps the LED at 1 while the original line 210 clears it.
- `fault_LED.224.CSK.1` (high): With the reset at line 224 disabled, Red_LED3 follows uvlo_state during reset instead of being held at 0.
- `fault_LED.224.SDL.1` (high): Without the reset assignment at line 224, Red_LED3 keeps its unknown or previous value through reset instead of 0.
- `fault_LED.225.AIM.24` (high): latch_state, latch_assert and uvlo_state are independent input ports, and the header does not rule out them being high together. With uvlo_state=1 and latch_state=1, the original line 225 sets Red_LED3 to 1 and the mutant sets it to 0.
- `fault_LED.225.AIM.27` (high): ss_active is an independent input, and nothing in the header rules out it being high together with uvlo_state. With uvlo_state=1 and ss_active=1, the original line 225 sets Red_LED3 to 1 and the mutant sets it to 0.
- `fault_LED.225.AIM.33` (high): With uvlo_state=1 and both ss_active and run_active low (the S_OFF case), the original line 225 sets Red_LED3 to 1 and the mutant sets it to 0.
- `fault_LED.225.AIM.41` (high): After uvlo_state goes high and then low again while run_active=0, the mutant keeps Red_LED3 at 1 through its own feedback term. The original line 225 drops it to 0.
- `fault_LED.87.EDG.1` (high): Moving the blink timebase at line 87 to negedge clk shifts when blink toggles by half a cycle relative to the posedge Red_LED1 register (line 193), so Red_LED1 can change on a different edge.
- `fault_LED.97.BDL.1` (high): With the reset body at lines 99-100 emptied, blink_counter and blink keep unknown or stale values after reset. That changes the blink phase seen on Red_LED1 at line 193.
- `fault_LED.97.CSK.1` (high): With the reset branch at line 97 disabled, blink_counter and blink are never initialised and the counter keeps running during reset. blink stays unknown or takes the wrong phase, which reaches Red_LED1 through line 193.
- `fault_LED.99.SDL.1` (high): Without line 99, blink_counter is not reset, so the first terminal count at line 104 comes at an unknown or different time. That changes when Red_LED1 blinks.
