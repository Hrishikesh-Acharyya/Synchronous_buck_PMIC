# Mutation record: fault_LED

`rtl-systemverilog/status/fault_LED.sv`. Written by `tools/mutation/record.py` from `fault_LED.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 138 | 107 | 18 | 0 | 0 | 13 | 0 | 0 | 90.6% |
| AI-written | 86 | 55 | 0 | 0 | 0 | 31 | 0 | 0 | 64.0% |
| all | 224 | 162 | 18 | 0 | 0 | 44 | 0 | 0 | 80.4% |

Survivors: 44 - 0 decided equivalent, 1 accepted, 43 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 80.7%.
1 earlier mutants are not in these numbers: 1 AI-written ones the designer withdrew, 0 the generator no longer makes because the RTL changed. Their history is kept below.

## Survivors (44)

### `fault_LED.87.EDG.1` - posedge clk -> negedge clk

- before: `always_ff @ (posedge clk or negedge rst_n) begin`
- after: `always_ff @ (negedge clk or negedge rst_n) begin`
- AI judgement (step 10): **plausible**, high confidence - Moving the blink timebase at line 87 to negedge clk shifts when blink toggles by half a cycle relative to the posedge Red_LED1 register (line 193), so Red_LED1 can change on a different edge.
- designer's decision (step 13): **accepted** - moves the 4 Hz blink by half a clock (50 ns in a 125 ms half-period); no indicator depends on that phase

### `fault_LED.97.BDL.1` - empty the 2-statement body of the if at line 97

- before: `if(!rst_n) begin`
- after: `if(!rst_n) begin end`
- AI judgement (step 10): **plausible**, high confidence - With the reset body at lines 99-100 emptied, blink_counter and blink keep unknown or stale values after reset. That changes the blink phase seen on Red_LED1 at line 193.
- designer's decision (step 11): **gap** - reset values of the blink timebase and the red LEDs untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run with the LEDs lit

### `fault_LED.97.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n) begin`
- after: `if(1'b0) begin`
- AI judgement (step 10): **plausible**, high confidence - With the reset branch at line 97 disabled, blink_counter and blink are never initialised and the counter keeps running during reset. blink stays unknown or takes the wrong phase, which reaches Red_LED1 through line 193.
- designer's decision (step 11): **gap** - reset values of the blink timebase and the red LEDs untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run with the LEDs lit

### `fault_LED.99.SDL.1` - delete 'blink_counter <= '0;'

- before: `blink_counter <= '0;`
- after: `;`
- AI judgement (step 10): **plausible**, high confidence - Without line 99, blink_counter is not reset, so the first terminal count at line 104 comes at an unknown or different time. That changes when Red_LED1 blinks.
- designer's decision (step 11): **gap** - reset values of the blink timebase and the red LEDs untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run with the LEDs lit

### `fault_LED.100.CST.1` - 1'b0 -> 1'b1

- before: `blink         <= 1'b0;`
- after: `blink         <= 1'b1;`
- AI judgement (step 10): **plausible**, high confidence - Resetting blink to 1 at line 100 inverts the blink phase. With strike_level non-zero right after reset, Red_LED1 (line 193) reads 1 where it should read 0.
- designer's decision (step 12): **gap** - the blink phase after reset is not checked: no test looks at whether Red_LED1 starts on a dark or a lit half-period

### `fault_LED.100.SDL.1` - delete 'blink <= 1'b0;'

- before: `blink         <= 1'b0;`
- after: `;`
- AI judgement (step 10): **plausible**, high confidence - Without line 100, blink is not reset and stays unknown or stale. Red_LED1 follows it at line 193 whenever strike_level is non-zero.
- designer's decision (step 11): **gap** - reset values of the blink timebase and the red LEDs untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run with the LEDs lit

### `fault_LED.133.AIM.57` - Green's fault summary ignores input undervoltage during soft-start, treating an input sag under start-up inrush as expected rather than a live fault

- before: `currently_faulted = (otp_state || uvlo_state || latch_state || latch_assert);`
- after: `currently_faulted = (otp_state || (uvlo_state && !ss_active) || latch_state || latch_assert);`
- AI judgement (step 10): **plausible**, high confidence - With uvlo_state=1, ss_active=1 and no other faults, the mutated line 133 gives currently_faulted=0, so Green_LED at line 149 lights where the original keeps it dark. The inputs are unconstrained.
- designer's decision (step 17): **gap** - Green_LED is checked only in S_RUN: a fault live during soft start, a retry soft start with strikes outstanding, the hiccup off-time with strikes, and Green going dark when the converter stops are untested

### `fault_LED.149.AIM.35` - Running indication treats outstanding strikes as an active state, so Green stays lit through the hiccup off-time instead of going dark in S_HICCUP

- before: `else       Green_LED <= (ss_active || run_active) && !currently_faulted;`
- after: `else       Green_LED <= (ss_active || run_active || (strike_level != '0)) && !currently_faulted;`
- AI judgement (step 10): **plausible**, high confidence - With strike_level non-zero, ss_active=run_active=0 and no fault, the mutant lights Green_LED and the original line 149 does not.
- designer's decision (step 17): **gap** - Green_LED is checked only in S_RUN: a fault live during soft start, a retry soft start with strikes outstanding, the hiccup off-time with strikes, and Green going dark when the converter stops are untested

### `fault_LED.149.AIM.42` - Parentheses lost around the active-state term, so the live-fault mask applies only to S_RUN and Green stays lit through soft-start whatever fault is live

- before: `else       Green_LED <= (ss_active || run_active) && !currently_faulted;`
- after: `else       Green_LED <= ss_active || run_active && !currently_faulted;`
- AI judgement (step 10): **plausible**, high confidence - Because && binds tighter than ||, ss_active=1 with a live fault lights Green_LED in the mutant, while the original line 149 gives 0.
- designer's decision (step 17): **gap** - Green_LED is checked only in S_RUN: a fault live during soft start, a retry soft start with strikes outstanding, the hiccup off-time with strikes, and Green going dark when the converter stops are untested

### `fault_LED.149.AIM.63` - Running indication is held dark during a retry soft-start while strikes are outstanding, as if a retry were not yet 'running', though Green must be lit in S_SS and S_RUN whenever no fault is live

- before: `else       Green_LED <= (ss_active || run_active) && !currently_faulted;`
- after: `else       Green_LED <= ((ss_active && (strike_level == '0)) || run_active) && !currently_faulted;`
- AI judgement (step 10): **plausible**, high confidence - With ss_active=1, strike_level non-zero, run_active=0 and no fault, the mutant gives Green_LED=0 where the original line 149 gives 1.
- designer's decision (step 17): **gap** - Green_LED is checked only in S_RUN: a fault live during soft start, a retry soft start with strikes outstanding, the hiccup off-time with strikes, and Green going dark when the converter stops are untested

### `fault_LED.149.AIM.75` - Green_LED is updated only while the converter is switching and keeps its last value in S_OFF, S_HICCUP and S_LATCHED, instead of going dark whenever the converter is not switching

- before: `else       Green_LED <= (ss_active || run_active) && !currently_faulted;`
- after: `else if (ss_active || run_active) Green_LED <= !currently_faulted;`
- AI judgement (step 10): **plausible**, high confidence - When ss_active and run_active both drop, the mutant keeps Green_LED at its old value (possibly 1), while the original line 149 clears it.
- designer's decision (step 17): **gap** - Green_LED is checked only in S_RUN: a fault live during soft start, a retry soft start with strikes outstanding, the hiccup off-time with strikes, and Green going dark when the converter stops are untested

### `fault_LED.162.AIM.58` - Power-good LED samples the comparator only while the converter is switching and holds its last reading otherwise, as if the comparator were meaningless with the converter off, instead of following it in every state

- before: `if(!rst_n) pgood_LED <= 1'b0; / else       pgood_LED <= pgood;`
- after: `if(!rst_n)                        pgood_LED <= 1'b0; / else if (ss_active || run_active) pgood_LED <= pgood;`
- AI judgement (step 10): **plausible**, high confidence - When ss_active and run_active are both 0, the mutant holds pgood_LED while the original line 163 follows pgood, so a change in pgood is visible only in the original.
- designer's decision (step 18): **gap** - pgood_LED must follow pgood in every state, but no test drops pgood in S_RUN, raises it in S_OFF or S_SS, or toggles it after it was lit

### `fault_LED.163.AIM.10` - Power-good LED is gated by run_active, so it ignores the comparator in every state except S_RUN

- before: `else       pgood_LED <= pgood;`
- after: `else       pgood_LED <= pgood && run_active;`
- AI judgement (step 10): **plausible**, high confidence - With pgood=1 and run_active=0, the mutant drives pgood_LED to 0 where the original line 163 drives 1.
- designer's decision (step 18): **gap** - pgood_LED must follow pgood in every state, but no test drops pgood in S_RUN, raises it in S_OFF or S_SS, or toggles it after it was lit

### `fault_LED.163.AIM.28` - Power-good LED latches on once regulation is first reached and is cleared only by reset, instead of following the comparator

- before: `else       pgood_LED <= pgood;`
- after: `else       pgood_LED <= pgood || pgood_LED;`
- AI judgement (step 10): **plausible**, high confidence - After pgood goes 1 and then 0, the mutant keeps pgood_LED at 1 while the original line 163 clears it.
- designer's decision (step 18): **gap** - pgood_LED must follow pgood in every state, but no test drops pgood in S_RUN, raises it in S_OFF or S_SS, or toggles it after it was lit

### `fault_LED.163.AIM.54` - Power-good LED is held dark during soft-start, as if the comparator could not be trusted until the ramp finishes, instead of following it in every state

- before: `else       pgood_LED <= pgood;`
- after: `else       pgood_LED <= pgood && !ss_active;`
- AI judgement (step 10): **plausible**, high confidence - With pgood=1 and ss_active=1, the mutant gives pgood_LED=0 where the original line 163 gives 1.
- designer's decision (step 18): **gap** - pgood_LED must follow pgood in every state, but no test drops pgood in S_RUN, raises it in S_OFF or S_SS, or toggles it after it was lit

### `fault_LED.163.AIM.59` - Power-good LED is also lit for the whole of S_RUN, on the belief that the supervisor only reaches S_RUN once the rail is in regulation, instead of following the comparator alone

- before: `else       pgood_LED <= pgood;`
- after: `else       pgood_LED <= pgood || run_active;`
- AI judgement (step 10): **plausible**, high confidence - With pgood=0 and run_active=1, the mutant lights pgood_LED where the original line 163 keeps it dark.
- designer's decision (step 18): **gap** - pgood_LED must follow pgood in every state, but no test drops pgood in S_RUN, raises it in S_OFF or S_SS, or toggles it after it was lit

### `fault_LED.163.AIM.85` - Once pgood_LED is lit, it stays lit through comparator dropouts for as long as the supervisor is in S_RUN. The designer assumed the supervisor's window trip would catch a real loss of regulation, so the LED goes dark only on leaving S_RUN instead of following the comparator.

- before: `else       pgood_LED <= pgood;`
- after: `else       pgood_LED <= pgood || (pgood_LED && run_active);`
- AI judgement (step 10): **plausible**, high confidence - If pgood drops while run_active=1 and pgood_LED is already 1, the mutant keeps the LED lit while the original line 163 clears it.
- designer's decision (step 18): **gap** - pgood_LED must follow pgood in every state, but no test drops pgood in S_RUN, raises it in S_OFF or S_SS, or toggles it after it was lit

### `fault_LED.189.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n)                            Red_LED1 <= 1'b0;`
- after: `if(1'b0)                            Red_LED1 <= 1'b0;`
- AI judgement (step 10): **plausible**, high confidence - With the reset at line 189 disabled, Red_LED1 is not cleared during reset; at negedge rst_n or on clocks during reset it takes the else branches instead, for example 1 if latch_state is high.
- designer's decision (step 11): **gap** - reset values of the blink timebase and the red LEDs untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run with the LEDs lit

### `fault_LED.189.SDL.1` - delete 'Red_LED1 <= 1'b0;'

- before: `if(!rst_n)                            Red_LED1 <= 1'b0;`
- after: `if(!rst_n)                            ;`
- AI judgement (step 10): **plausible**, high confidence - Without the reset assignment at line 189, Red_LED1 keeps its unknown or previous value through reset instead of going to 0.
- designer's decision (step 11): **gap** - reset values of the blink timebase and the red LEDs untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run with the LEDs lit

### `fault_LED.191.AIM.14` - Strike level at its maximum is treated as a latched trip and shown solid instead of blinking

- before: `else if (latch_state || latch_assert) Red_LED1 <= 1'b1;`
- after: `else if (latch_state || latch_assert || strike_level == STRIKE_W'(MAX_STRIKES_DEFAULT)) Red_LED1 <= 1'b1;`
- AI judgement (step 10): **plausible**, high confidence - With strike_level=3 and no latch, the mutant holds Red_LED1 solid at 1 while the original follows blink at line 193. strike_level is an unconstrained input.
- designer's decision (step 15): **gap** - the solid latch indication is tested only with strikes outstanding and no other fault: a latch with strike_level 0 (an analog OVP trip), a latch with OTP live, and strike_level 3 under a raised MAX_STRIKES with no latch are untested

### `fault_LED.191.AIM.55` - Latched-trip solid indication is shown only while strikes are outstanding, misreading 'after a latch strike_level stays non-zero' as 'every latch comes with strikes', so a latch tripped by the hardware OVP path with no hiccup history is not shown

- before: `else if (latch_state || latch_assert) Red_LED1 <= 1'b1;`
- after: `else if ((latch_state || latch_assert) && strike_level != '0) Red_LED1 <= 1'b1;`
- AI judgement (step 10): **plausible**, high confidence - With latch_state=1 and strike_level=0, the original line 191 sets Red_LED1=1; the mutant falls through to line 195 and gives 0.
- designer's decision (step 15): **gap** - the solid latch indication is tested only with strikes outstanding and no other fault: a latch with strike_level 0 (an analog OVP trip), a latch with OTP live, and strike_level 3 under a raised MAX_STRIKES with no latch are untested

### `fault_LED.191.AIM.70` - Latched-trip solid indication is made sticky until reset (the SCR 'cannot be un-tripped'), so once Red_LED1 is lit with no strikes outstanding it never clears from the latch inputs

- before: `else if (latch_state || latch_assert) Red_LED1 <= 1'b1;`
- after: `else if (latch_state || latch_assert || (Red_LED1 && strike_level == '0)) Red_LED1 <= 1'b1;`
- AI judgement (step 10): **plausible**, high confidence - After a latch lights Red_LED1 and the latch inputs then drop with strike_level=0, the mutant keeps the LED at 1 while the original line 195 clears it.
- designer's decision (step 14): **gap** - Red_LED1 is never checked to go dark again: no test clears the strikes (or the latch) while Red_LED1 is lit and checks it falls on the next clock

### `fault_LED.191.AIM.82` - The latched-trip solid indication gives way to a live over-temperature, as if a thermal latch were already explained by Red_LED2, so Red_LED1 is not solid while OTP is live

- before: `else if (latch_state || latch_assert) Red_LED1 <= 1'b1;`
- after: `else if ((latch_state || latch_assert) && !otp_state) Red_LED1 <= 1'b1;`
- AI judgement (step 10): **plausible**, high confidence - With latch_state=1, otp_state=1 and strike_level=0, the mutant does not set Red_LED1 solid and drives 0 where the original line 191 drives 1.
- designer's decision (step 15): **gap** - the solid latch indication is tested only with strikes outstanding and no other fault: a latch with strike_level 0 (an analog OVP trip), a latch with OTP live, and strike_level 3 under a raised MAX_STRIKES with no latch are untested

### `fault_LED.193.AIM.15` - Strike blink is suppressed while an OTP or UVLO fault is live, though strikes are still outstanding

- before: `else if (strike_level != '0)          Red_LED1 <= blink;`
- after: `else if (strike_level != '0 && !currently_faulted) Red_LED1 <= blink;`
- AI judgement (step 10): **plausible**, high confidence - With strike_level non-zero, otp_state=1, no latch and blink=1, the mutant drives Red_LED1=0 where the original line 193 drives 1.
- designer's decision (step 16): **gap** - the strike blink is checked in one state with one strike: blink during the hiccup off-time and in S_SS/S_RUN, with strike_level 2 or 3, and with OTP or UVLO live are untested

### `fault_LED.193.AIM.30` - Strike blink is shown only while the converter is switching, so Red_LED1 goes dark during the hiccup off-time though strikes are outstanding

- before: `else if (strike_level != '0)          Red_LED1 <= blink;`
- after: `else if (strike_level != '0)          Red_LED1 <= blink && (ss_active || run_active);`
- AI judgement (step 10): **plausible**, high confidence - With strike_level non-zero, blink=1 and ss_active=run_active=0, the mutant gives Red_LED1=0 where the original line 193 gives 1.
- designer's decision (step 16): **gap** - the strike blink is checked in one state with one strike: blink during the hiccup off-time and in S_SS/S_RUN, with strike_level 2 or 3, and with OTP or UVLO live are untested

### `fault_LED.193.AIM.60` - Outstanding strikes are shown solid while the converter is not switching (hiccup off-time, S_OFF) and blink only during the retry and run, so Red_LED1 looks like a latched trip during every hiccup

- before: `else if (strike_level != '0)          Red_LED1 <= blink;`
- after: `else if (strike_level != '0)          Red_LED1 <= (ss_active || run_active) ? blink : 1'b1;`
- AI judgement (step 10): **plausible**, high confidence - With strike_level non-zero, blink=0 and the converter not switching, the mutant gives Red_LED1=1 where the original line 193 gives 0.
- designer's decision (step 16): **gap** - the strike blink is checked in one state with one strike: blink during the hiccup off-time and in S_SS/S_RUN, with strike_level 2 or 3, and with OTP or UVLO live are untested

### `fault_LED.193.AIM.76` - Strike blink is shown only while exactly one strike is outstanding, as if strike_level were a single strike flag rather than a count

- before: `else if (strike_level != '0)          Red_LED1 <= blink;`
- after: `else if (strike_level == STRIKE_W'(1)) Red_LED1 <= blink;`
- AI judgement (step 10): **plausible**, high confidence - With strike_level=2 and blink=1, the mutant falls through to line 195 and gives 0 where the original line 193 gives 1.
- designer's decision (step 16): **gap** - the strike blink is checked in one state with one strike: blink during the hiccup off-time and in S_SS/S_RUN, with strike_level 2 or 3, and with OTP or UVLO live are untested

### `fault_LED.195.AIM.62` - When strikes clear, Red_LED1 stays lit to the end of the current lit blink half-period, to 'finish the pattern cleanly', instead of going dark on the next clock

- before: `else                                  Red_LED1 <= 1'b0;`
- after: `else                                  Red_LED1 <= Red_LED1 && blink;`
- AI judgement (step 10): **plausible**, high confidence - If strike_level drops to 0 while Red_LED1=1 and blink=1, the mutant keeps the LED at 1 while the original line 195 clears it.
- designer's decision (step 14): **gap** - Red_LED1 is never checked to go dark again: no test clears the strikes (or the latch) while Red_LED1 is lit and checks it falls on the next clock

### `fault_LED.195.AIM.7` - Red_LED1 holds its last value when neither a latch nor strikes are present, instead of being cleared

- before: `else                                  Red_LED1 <= 1'b0;`
- after: `else                                  Red_LED1 <= Red_LED1;`
- AI judgement (step 10): **plausible**, high confidence - Holding Red_LED1 at line 195 leaves it at 1 after the latch or strikes clear, while the original drives 0.
- designer's decision (step 14): **gap** - Red_LED1 is never checked to go dark again: no test clears the strikes (or the latch) while Red_LED1 is lit and checks it falls on the next clock

### `fault_LED.195.SDL.1` - delete 'Red_LED1 <= 1'b0;'

- before: `else                                  Red_LED1 <= 1'b0;`
- after: `else                                  ;`
- AI judgement (step 10): **plausible**, high confidence - Deleting the clear at line 195 makes Red_LED1 hold its value, so it stays at 1 after the latch or strikes clear, while the original drives 0.
- designer's decision (step 14): **gap** - Red_LED1 is never checked to go dark again: no test clears the strikes (or the latch) while Red_LED1 is lit and checks it falls on the next clock

### `fault_LED.209.AIM.49` - Over-temperature indicator is cleared only when the converter is back in S_RUN, treating it as a thermal-shutdown history to keep until restart, instead of showing the live OTP condition

- before: `if(!rst_n) Red_LED2 <= 1'b0; / else       Red_LED2 <= otp_state;`
- after: `if(!rst_n)           Red_LED2 <= 1'b0; / else if (otp_state)  Red_LED2 <= 1'b1; / else if (run_active) Red_LED2 <= 1'b0;`
- AI judgement (step 10): **plausible**, high confidence - After otp_state goes 1 and then 0 with run_active=0, the mutant keeps Red_LED2=1 while the original line 210 clears it.
- designer's decision (step 19): **gap** - Red_LED2 is checked only with the converter running and OTP alone: OTP while stopped, OTP with the latch set or strikes outstanding, OTP clearing while stopped, and a change between blink terminal counts are untested

### `fault_LED.209.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n) Red_LED2 <= 1'b0;`
- after: `if(1'b0) Red_LED2 <= 1'b0;`
- AI judgement (step 10): **plausible**, high confidence - With the reset at line 209 disabled, Red_LED2 follows otp_state during reset (and at negedge rst_n) instead of being held at 0.
- designer's decision (step 11): **gap** - reset values of the blink timebase and the red LEDs untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run with the LEDs lit

### `fault_LED.209.SDL.1` - delete 'Red_LED2 <= 1'b0;'

- before: `if(!rst_n) Red_LED2 <= 1'b0;`
- after: `if(!rst_n) ;`
- AI judgement (step 10): **plausible**, high confidence - Without the reset assignment at line 209, Red_LED2 keeps its unknown or previous value through reset instead of 0.
- designer's decision (step 11): **gap** - reset values of the blink timebase and the red LEDs untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run with the LEDs lit

### `fault_LED.210.AIM.45` - Over-temperature indicator is suppressed while the latch is set, as if the latched-trip display outranked every other red indicator

- before: `else       Red_LED2 <= otp_state;`
- after: `else       Red_LED2 <= otp_state && !(latch_state || latch_assert);`
- AI judgement (step 10): **plausible**, high confidence - With otp_state=1 and latch_state=1, the mutant gives Red_LED2=0 where the original line 210 gives 1.
- designer's decision (step 19): **gap** - Red_LED2 is checked only with the converter running and OTP alone: OTP while stopped, OTP with the latch set or strikes outstanding, OTP clearing while stopped, and a change between blink terminal counts are untested

### `fault_LED.210.AIM.48` - Over-temperature indicator is shown only while the converter is soft-starting or running, so an OTP that holds the converter off in S_OFF or S_HICCUP leaves Red_LED2 dark

- before: `else       Red_LED2 <= otp_state;`
- after: `else       Red_LED2 <= otp_state && (ss_active || run_active);`
- AI judgement (step 10): **plausible**, high confidence - With otp_state=1 and ss_active=run_active=0, the mutant gives Red_LED2=0 where the original line 210 gives 1.
- designer's decision (step 19): **gap** - Red_LED2 is checked only with the converter running and OTP alone: OTP while stopped, OTP with the latch set or strikes outstanding, OTP clearing while stopped, and a change between blink terminal counts are untested

### `fault_LED.210.AIM.71` - Over-temperature indicator is updated only at each blink half-period terminal count, to keep it in step with the panel blink, instead of following the live OTP condition on every clock

- before: `else       Red_LED2 <= otp_state;`
- after: `else if (blink_counter == BLINK_W'(LED_BLINK_HALF_CLKS-1)) Red_LED2 <= otp_state;`
- AI judgement (step 10): **plausible**, high confidence - The mutant updates Red_LED2 only at the blink terminal count, so a change in otp_state shows up millions of cycles later than the per-clock update at line 210.
- designer's decision (step 19): **gap** - Red_LED2 is checked only with the converter running and OTP alone: OTP while stopped, OTP with the latch set or strikes outstanding, OTP clearing while stopped, and a change between blink terminal counts are untested

### `fault_LED.210.AIM.84` - Over-temperature indicator is held lit after the board cools for as long as the SCR readback is set, to keep a thermal latch's cause on the panel, which mixes up the fault_cause history with the live condition

- before: `else       Red_LED2 <= otp_state;`
- after: `else       Red_LED2 <= otp_state || (Red_LED2 && latch_state);`
- AI judgement (step 10): **plausible**, high confidence - After OTP lights Red_LED2, if otp_state drops while latch_state=1, the mutant keeps the LED at 1 while the original line 210 clears it.
- designer's decision (step 19): **gap** - Red_LED2 is checked only with the converter running and OTP alone: OTP while stopped, OTP with the latch set or strikes outstanding, OTP clearing while stopped, and a change between blink terminal counts are untested

### `fault_LED.210.AIM.86` - Red_LED2 (over-temperature) stays lit after OTP clears for as long as hiccup strikes are outstanding. The 'recently troubled' persistence meant for the Red_LED1 strike blink is applied to the thermal indicator as well, instead of showing only the live OTP condition.

- before: `else       Red_LED2 <= otp_state;`
- after: `else       Red_LED2 <= otp_state || (Red_LED2 && (strike_level != '0));`
- AI judgement (step 10): **plausible**, high confidence - After OTP lights Red_LED2, if otp_state drops while strike_level is non-zero, the mutant keeps the LED at 1 while the original line 210 clears it.
- designer's decision (step 19): **gap** - Red_LED2 is checked only with the converter running and OTP alone: OTP while stopped, OTP with the latch set or strikes outstanding, OTP clearing while stopped, and a change between blink terminal counts are untested

### `fault_LED.224.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n) Red_LED3 <= 1'b0;`
- after: `if(1'b0) Red_LED3 <= 1'b0;`
- AI judgement (step 10): **plausible**, high confidence - With the reset at line 224 disabled, Red_LED3 follows uvlo_state during reset instead of being held at 0.
- designer's decision (step 11): **gap** - reset values of the blink timebase and the red LEDs untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run with the LEDs lit

### `fault_LED.224.SDL.1` - delete 'Red_LED3 <= 1'b0;'

- before: `if(!rst_n) Red_LED3 <= 1'b0;`
- after: `if(!rst_n) ;`
- AI judgement (step 10): **plausible**, high confidence - Without the reset assignment at line 224, Red_LED3 keeps its unknown or previous value through reset instead of 0.
- designer's decision (step 11): **gap** - reset values of the blink timebase and the red LEDs untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run with the LEDs lit

### `fault_LED.225.AIM.24` - Undervoltage indicator is suppressed while the latch is set, as if the latched-trip display outranked it the way it outranks the strike blink

- before: `else       Red_LED3 <= uvlo_state;`
- after: `else       Red_LED3 <= uvlo_state && !(latch_state || latch_assert);`
- AI judgement (step 10): **plausible**, high confidence - latch_state, latch_assert and uvlo_state are independent input ports, and the header does not rule out them being high together. With uvlo_state=1 and latch_state=1, the original line 225 sets Red_LED3 to 1 and the mutant sets it to 0.
- designer's decision (step 20): **gap** - Red_LED3 is checked only in one state with UVLO alone: UVLO in S_OFF, in S_SS, with the latch set, and UVLO clearing while stopped are untested

### `fault_LED.225.AIM.27` - Undervoltage indicator is masked during soft-start, as if an input sag during start-up inrush were expected and not worth showing

- before: `else       Red_LED3 <= uvlo_state;`
- after: `else       Red_LED3 <= uvlo_state && !ss_active;`
- AI judgement (step 10): **plausible**, high confidence - ss_active is an independent input, and nothing in the header rules out it being high together with uvlo_state. With uvlo_state=1 and ss_active=1, the original line 225 sets Red_LED3 to 1 and the mutant sets it to 0.
- designer's decision (step 20): **gap** - Red_LED3 is checked only in one state with UVLO alone: UVLO in S_OFF, in S_SS, with the latch set, and UVLO clearing while stopped are untested

### `fault_LED.225.AIM.33` - Undervoltage indicator is shown only while the converter is soft-starting or running, so the case UVLO most often produces - a converter held off in S_OFF - is left dark

- before: `else       Red_LED3 <= uvlo_state;`
- after: `else       Red_LED3 <= uvlo_state && (ss_active || run_active);`
- AI judgement (step 10): **plausible**, high confidence - With uvlo_state=1 and both ss_active and run_active low (the S_OFF case), the original line 225 sets Red_LED3 to 1 and the mutant sets it to 0.
- designer's decision (step 20): **gap** - Red_LED3 is checked only in one state with UVLO alone: UVLO in S_OFF, in S_SS, with the latch set, and UVLO clearing while stopped are untested

### `fault_LED.225.AIM.41` - Undervoltage indicator is stretched until the converter is running again, as though the UVLO comparator needed stretching, instead of showing the live condition

- before: `else       Red_LED3 <= uvlo_state;`
- after: `else       Red_LED3 <= uvlo_state || (Red_LED3 && !run_active);`
- AI judgement (step 10): **plausible**, high confidence - After uvlo_state goes high and then low again while run_active=0, the mutant keeps Red_LED3 at 1 through its own feedback term. The original line 225 drops it to 0.
- designer's decision (step 20): **gap** - Red_LED3 is checked only in one state with UVLO alone: UVLO in S_OFF, in S_SS, with the latch set, and UVLO clearing while stopped are untested

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-27 09:12 | 001df27 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 25, accepted 24, rejected 1; `ai_runs/2026-11-27_write_mutants_9` |
| 2 | 2026-11-27 09:17 | 001df27 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 17, accepted 17, rejected 0; `ai_runs/2026-11-27_write_mutants_10` |
| 3 | 2026-11-27 09:21 | 001df27 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 13, accepted 13, rejected 0; `ai_runs/2026-11-27_write_mutants_11` |
| 4 | 2026-11-27 09:25 | 001df27 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 9, accepted 9, rejected 0; `ai_runs/2026-11-27_write_mutants_12` |
| 5 | 2026-11-27 09:30 | 001df27 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 10, accepted 10, rejected 0; `ai_runs/2026-11-27_write_mutants_13` |
| 6 | 2026-11-27 09:33 | 001df27 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 4, accepted 4, rejected 0; `ai_runs/2026-11-27_write_mutants_14` |
| 7 | 2026-11-27 09:38 | 001df27 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 11, accepted 10, rejected 1; `ai_runs/2026-11-27_write_mutants_15` |
| 8 | 2026-11-27 09:40 | 001df27 | designer withdrew AI-written mutants | fault_LED.111.AIM.73 - equivalent on the board: while the latch is set Red_LED1 is solid whatever blink does, and the latch (SCR and latch_assert) clears only through the drain button wired to rst_n, which also resets the blink timebase, so the frozen count never reaches an output |
| 9 | 2026-11-27 09:42 | 001df27 | mutation run - every mutant of the module | 224 mutants: 162 killed, 18 lint, 44 survived; score 80.4% |
| 10 | 2026-11-27 09:43 | 001df27 | AI judged survivors (claude-opus-5-5) | 44 judged, 0 called equivalent with high confidence; `ai_runs/2026-11-27_judge_survivors_2` |
| 11 | 2026-11-27 09:44 | 001df27 | designer's decision: gap | fault_LED.97.BDL.1, fault_LED.97.CSK.1, fault_LED.99.SDL.1, fault_LED.100.SDL.1, fault_LED.189.CSK.1, fault_LED.189.SDL.1, fault_LED.209.CSK.1, fault_LED.209.SDL.1, fault_LED.224.CSK.1, fault_LED.224.SDL.1 - reset values of the blink timebase and the red LEDs untested: reset only at time zero, where a two-state simulator holds 0; needs a reset applied mid-run with the LEDs lit |
| 12 | 2026-11-27 09:44 | 001df27 | designer's decision: gap | fault_LED.100.CST.1 - the blink phase after reset is not checked: no test looks at whether Red_LED1 starts on a dark or a lit half-period |
| 13 | 2026-11-27 09:44 | 001df27 | designer's decision: accepted | fault_LED.87.EDG.1 - moves the 4 Hz blink by half a clock (50 ns in a 125 ms half-period); no indicator depends on that phase |
| 14 | 2026-11-27 09:44 | 001df27 | designer's decision: gap | fault_LED.195.SDL.1, fault_LED.195.AIM.7, fault_LED.195.AIM.62, fault_LED.191.AIM.70 - Red_LED1 is never checked to go dark again: no test clears the strikes (or the latch) while Red_LED1 is lit and checks it falls on the next clock |
| 15 | 2026-11-27 09:44 | 001df27 | designer's decision: gap | fault_LED.191.AIM.55, fault_LED.191.AIM.82, fault_LED.191.AIM.14 - the solid latch indication is tested only with strikes outstanding and no other fault: a latch with strike_level 0 (an analog OVP trip), a latch with OTP live, and strike_level 3 under a raised MAX_STRIKES with no latch are untested |
| 16 | 2026-11-27 09:44 | 001df27 | designer's decision: gap | fault_LED.193.AIM.15, fault_LED.193.AIM.30, fault_LED.193.AIM.60, fault_LED.193.AIM.76 - the strike blink is checked in one state with one strike: blink during the hiccup off-time and in S_SS/S_RUN, with strike_level 2 or 3, and with OTP or UVLO live are untested |
| 17 | 2026-11-27 09:44 | 001df27 | designer's decision: gap | fault_LED.133.AIM.57, fault_LED.149.AIM.35, fault_LED.149.AIM.42, fault_LED.149.AIM.63, fault_LED.149.AIM.75 - Green_LED is checked only in S_RUN: a fault live during soft start, a retry soft start with strikes outstanding, the hiccup off-time with strikes, and Green going dark when the converter stops are untested |
| 18 | 2026-11-27 09:44 | 001df27 | designer's decision: gap | fault_LED.162.AIM.58, fault_LED.163.AIM.10, fault_LED.163.AIM.28, fault_LED.163.AIM.54, fault_LED.163.AIM.59, fault_LED.163.AIM.85 - pgood_LED must follow pgood in every state, but no test drops pgood in S_RUN, raises it in S_OFF or S_SS, or toggles it after it was lit |
| 19 | 2026-11-27 09:44 | 001df27 | designer's decision: gap | fault_LED.209.AIM.49, fault_LED.210.AIM.45, fault_LED.210.AIM.48, fault_LED.210.AIM.71, fault_LED.210.AIM.84, fault_LED.210.AIM.86 - Red_LED2 is checked only with the converter running and OTP alone: OTP while stopped, OTP with the latch set or strikes outstanding, OTP clearing while stopped, and a change between blink terminal counts are untested |
| 20 | 2026-11-27 09:44 | 001df27 | designer's decision: gap | fault_LED.225.AIM.24, fault_LED.225.AIM.27, fault_LED.225.AIM.33, fault_LED.225.AIM.41 - Red_LED3 is checked only in one state with UVLO alone: UVLO in S_OFF, in S_SS, with the latch set, and UVLO clearing while stopped are untested |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (87)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | wrong_event | Blink timebase is held in reset while no strikes are outstanding, so it is started by the first strike instead of running freely | killed | a_blink_counter_advances |
| 2 | 1 | boundary | Blink counter is not reloaded at the half-period terminal count and wraps at 2^BLINK_W, so only the first half-period is the right length | killed | a_blink_counter_in_range, a_blink_counter_wraps |
| 3 | 1 | missing_case | Loss of power-good is treated as a live fault, which puts out the running indicator | killed | a_green_shows_healthy_running |
| 4 | 1 | other | Green LED is turned off while strikes are outstanding, against the rule that Green and Red_LED1 are both lit during the clean-run window | killed | a_green_shows_healthy_running |
| 5 | 1 | priority | Strike blink outranks the latched-trip solid indication | killed | a_red1_solid_on_latch |
| 6 | 1 | wrong_event | Strike blink is shown only while the converter is not switching, not for the whole time strikes are outstanding | killed | a_red1_blinks_on_strikes |
| 7 | 1 | reset_init | Red_LED1 holds its last value when neither a latch nor strikes are present, instead of being cleared | survived |  |
| 8 | 1 | other | Over-temperature indicator is made sticky until reset, like a fault_cause history bit, instead of showing the live condition | killed | a_red2_follows_otp |
| 9 | 1 | priority | Undervoltage indicator is chained after over-temperature and suppressed while OTP is live, instead of being independent | killed | a_red3_follows_uvlo |
| 10 | 1 | missing_case | Power-good LED is gated by run_active, so it ignores the comparator in every state except S_RUN | survived |  |
| 11 | 1 | boundary | Blink terminal count is taken from the full blink period instead of the half-period, so each half of the square wave lasts the whole period | killed | a_blink_counter_in_range, a_blink_counter_wraps +2 |
| 12 | 1 | boundary | Blink counter is reloaded to 1 instead of 0 at the half-period terminal count, so every half-period after the first is one clock short | killed | a_blink_counter_wraps |
| 13 | 1 | wrong_event | Red_LED1 solid indication is driven by any live fault instead of only a latched trip | killed | a_red1_dark_when_clean |
| 14 | 1 | other | Strike level at its maximum is treated as a latched trip and shown solid instead of blinking | survived |  |
| 15 | 1 | missing_case | Strike blink is suppressed while an OTP or UVLO fault is live, though strikes are still outstanding | survived |  |
| 16 | 1 | missing_case | Running indication additionally requires power-good, conflating 'switching' with 'in regulation', so Green stays dark through soft-start | killed | a_green_shows_healthy_running |
| 17 | 1 | other | Power-good LED is masked by any live fault instead of following the comparator directly | killed | a_pgood_led_follows_pgood |
| 18 | 1 | missing_case | Over-temperature indicator is shown only once the converter has left S_RUN, not for the whole time OTP is live | killed | a_red2_follows_otp |
| 19 | 1 | field | Undervoltage indicator is driven by the coarse any-fault summary instead of the UVLO condition alone | killed | a_red3_follows_uvlo |
| 20 | 1 | sequencing | Green's fault summary reads the registered over-temperature and undervoltage indicators instead of the live OTP/UVLO conditions, so it uses values one clock old | killed | a_green_shows_healthy_running |
| 21 | 1 | boundary | Strike blink starts only from the second outstanding strike, as if strike_level counted from one hiccup before the first | killed | a_red1_blinks_on_strikes |
| 22 | 1 | wrong_event | Strike blink is also shown during every soft-start, treating a normal start-up like recovery from a fault | killed | a_red1_dark_when_clean |
| 23 | 1 | other | Over-temperature indicator is also lit by the SCR latch readback, as if every latched trip were thermal | killed | a_red2_follows_otp |
| 24 | 1 | priority | Undervoltage indicator is suppressed while the latch is set, as if the latched-trip display outranked it the way it outranks the strike blink | survived |  |
| 25 | 2 | field | Red_LED1 patterns swapped: a latched trip blinks and outstanding strikes show solid, the indicator map misremembered | killed | a_red1_blinks_on_strikes, a_red1_solid_on_latch |
| 26 | 2 | field | Green's fault summary takes the latch term from the Red_LED1 indicator instead of the live latch_state/latch_assert inputs | killed | a_green_shows_healthy_running |
| 27 | 2 | missing_case | Undervoltage indicator is masked during soft-start, as if an input sag during start-up inrush were expected and not worth showing | survived |  |
| 28 | 2 | reset_init | Power-good LED latches on once regulation is first reached and is cleared only by reset, instead of following the comparator | survived |  |
| 29 | 2 | other | Blink is made a one-clock tick at each half-period terminal count instead of a square wave toggled there | killed | a_blink_stable_otherwise |
| 30 | 2 | missing_case | Strike blink is shown only while the converter is switching, so Red_LED1 goes dark during the hiccup off-time though strikes are outstanding | survived |  |
| 31 | 2 | wrong_event | Strike blink stops once the rail is back in regulation, as if power-good meant the strikes were resolved, instead of lasting until clean_run_target clears them | killed | a_red1_blinks_on_strikes |
| 32 | 2 | missing_case | Power-good LED is held off while strikes are outstanding, as if regulation did not count until the board had earned its clear | killed | a_pgood_led_follows_pgood |
| 33 | 2 | missing_case | Undervoltage indicator is shown only while the converter is soft-starting or running, so the case UVLO most often produces - a converter held off in S_OFF - is left dark | survived |  |
| 34 | 2 | other | Undervoltage indicator is also lit by loss of output power-good, confusing input undervoltage with an output rail out of regulation | killed | a_red3_follows_uvlo |
| 35 | 2 | missing_case | Running indication treats outstanding strikes as an active state, so Green stays lit through the hiccup off-time instead of going dark in S_HICCUP | survived |  |
| 36 | 2 | field | Over-temperature indicator blinks with the strike timebase instead of being lit solid, the indicator map misremembered | killed | a_red2_follows_otp |
| 37 | 2 | priority | The CPLD's own trip into the latch is shown blinking until the SCR readback confirms it, instead of solid from the moment latch_assert rises | killed | a_red1_solid_on_latch |
| 38 | 2 | wrong_event | Blink timebase is held in reset through every soft-start so the retry's pattern 'starts on a fresh period', which freezes the blink phase for the whole of S_SS | killed | a_blink_toggles_on_wrap, a_blink_counter_advances |
| 39 | 2 | reset_init | Blink phase is cleared to dark while no strikes are outstanding, so the timebase is no longer a free-running square wave and the first strike always starts on a dark half | killed | a_blink_stable_otherwise |
| 40 | 2 | priority | Over-temperature indicator is suppressed while input undervoltage is live, as if UVLO outranked OTP on the panel, when the two indicators are meant to be independent | killed | a_red2_follows_otp |
| 41 | 2 | other | Undervoltage indicator is stretched until the converter is running again, as though the UVLO comparator needed stretching, instead of showing the live condition | survived |  |
| 42 | 3 | priority | Parentheses lost around the active-state term, so the live-fault mask applies only to S_RUN and Green stays lit through soft-start whatever fault is live | survived |  |
| 43 | 3 | missing_case | Green's fault summary leaves out OTP and UVLO, misapplying the window-trip argument that the supervisor leaves S_RUN on its own | killed | a_green_shows_healthy_running |
| 44 | 3 | missing_case | Green's fault summary leaves out the latch terms, as if Red_LED1 showing the latch made masking Green unnecessary | killed | a_green_shows_healthy_running |
| 45 | 3 | priority | Over-temperature indicator is suppressed while the latch is set, as if the latched-trip display outranked every other red indicator | survived |  |
| 46 | 3 | boundary | The half-period is halved a second time (as if LED_BLINK_HALF_CLKS were the full period), so the blink square wave toggles every quarter of the intended period and runs at 8 Hz | killed | a_blink_counter_advances, a_blink_stable_otherwise |
| 47 | 3 | wrong_event | Blink timebase only advances while strikes are outstanding and is frozen (not cleared) otherwise, so it is no longer free-running and keeps its phase from one strike episode to the next | killed | a_blink_counter_advances |
| 48 | 3 | missing_case | Over-temperature indicator is shown only while the converter is soft-starting or running, so an OTP that holds the converter off in S_OFF or S_HICCUP leaves Red_LED2 dark | survived |  |
| 49 | 3 | wrong_event | Over-temperature indicator is cleared only when the converter is back in S_RUN, treating it as a thermal-shutdown history to keep until restart, instead of showing the live OTP condition | survived |  |
| 50 | 3 | reset_init | Undervoltage indicator is made a brown-out history bit, set by UVLO and cleared only by reset, instead of following the live input-undervoltage condition | killed | a_red3_follows_uvlo |
| 51 | 3 | field | Strike blink is taken from the half-period counter's MSB instead of from the toggled blink square wave, so the pattern repeats every half-period with an uneven duty cycle | killed | a_red1_blinks_on_strikes |
| 52 | 3 | sequencing | Blink is toggled as the counter leaves zero, at the start of each half-period instead of at its terminal count, so the first half-period after reset lasts one clock | killed | a_blink_toggles_on_wrap, a_blink_stable_otherwise |
| 53 | 3 | wrong_event | Blink timebase only counts while the converter is switching (S_SS or S_RUN), as if it shared the converter's enable, so it stops in S_OFF and S_HICCUP instead of running freely | killed | a_blink_counter_advances |
| 54 | 3 | missing_case | Power-good LED is held dark during soft-start, as if the comparator could not be trusted until the ramp finishes, instead of following it in every state | survived |  |
| 55 | 4 | missing_case | Latched-trip solid indication is shown only while strikes are outstanding, misreading 'after a latch strike_level stays non-zero' as 'every latch comes with strikes', so a latch tripped by the hardware OVP path with no hiccup history is not shown | survived |  |
| 56 | 4 | other | Green_LED blinks with the strike timebase during soft-start instead of being lit solid whenever the converter is switching unfaulted, the indicator map misremembered | killed | a_green_shows_healthy_running |
| 57 | 4 | missing_case | Green's fault summary ignores input undervoltage during soft-start, treating an input sag under start-up inrush as expected rather than a live fault | survived |  |
| 58 | 4 | wrong_event | Power-good LED samples the comparator only while the converter is switching and holds its last reading otherwise, as if the comparator were meaningless with the converter off, instead of following it in every state | survived |  |
| 59 | 4 | other | Power-good LED is also lit for the whole of S_RUN, on the belief that the supervisor only reaches S_RUN once the rail is in regulation, instead of following the comparator alone | survived |  |
| 60 | 4 | missing_case | Outstanding strikes are shown solid while the converter is not switching (hiccup off-time, S_OFF) and blink only during the retry and run, so Red_LED1 looks like a latched trip during every hiccup | survived |  |
| 61 | 4 | field | Undervoltage indicator blinks with the strike timebase instead of being lit solid while input UVLO is live, the indicator map misremembered | killed | a_red3_follows_uvlo |
| 62 | 4 | sequencing | When strikes clear, Red_LED1 stays lit to the end of the current lit blink half-period, to 'finish the pattern cleanly', instead of going dark on the next clock | survived |  |
| 63 | 4 | missing_case | Running indication is held dark during a retry soft-start while strikes are outstanding, as if a retry were not yet 'running', though Green must be lit in S_SS and S_RUN whenever no fault is live | survived |  |
| 64 | 5 | other | While strikes are outstanding, Green_LED flashes in antiphase with the Red_LED1 strike blink instead of staying solid, because the designer read 'show both' as 'alternate them' | killed | a_green_shows_healthy_running |
| 65 | 5 | missing_case | Over-temperature indicator is driven by the coarse any-fault summary instead of the OTP condition alone | killed | a_red2_follows_otp |
| 66 | 5 | missing_case | Undervoltage indicator is also lit by the SCR latch readback, as if a latched board had lost its input | killed | a_red3_follows_uvlo |
| 67 | 5 | wrong_event | Power-good LED samples the comparator only at each blink half-period terminal count, to hide chatter, instead of following it on every clock | killed | a_pgood_led_follows_pgood |
| 68 | 5 | wrong_event | Strike blink stops as soon as the supervisor re-enters S_RUN, as if a successful retry ended the strikes, instead of lasting through the clean-run window until clean_run_target clears strike_level | killed | a_red1_blinks_on_strikes |
| 69 | 5 | missing_case | Undervoltage indicator is suppressed while the output is in regulation, as if an input UVLO with the rail still good had to be a comparator glitch | killed | a_red3_follows_uvlo |
| 70 | 5 | reset_init | Latched-trip solid indication is made sticky until reset (the SCR 'cannot be un-tripped'), so once Red_LED1 is lit with no strikes outstanding it never clears from the latch inputs | survived |  |
| 71 | 5 | sequencing | Over-temperature indicator is updated only at each blink half-period terminal count, to keep it in step with the panel blink, instead of following the live OTP condition on every clock | survived |  |
| 72 | 5 | missing_case | Power-good LED is held dark while the latch is set or being asserted, as if a board that has given up could not be in regulation, instead of following the comparator straight through | killed | a_pgood_led_follows_pgood |
| 73 | 5 | wrong_event | Blink timebase is frozen while the latch is set, on the reasoning that the solid latched indication masks the blink anyway, so it no longer runs freely | withdrawn: equivalent on the board: while the latch is set Red_LED1 is solid whatever blink does, and the latch (SCR and latch_assert) clears only through the drain button wired to rst_n, which also resets the blink timebase, so the frozen count never reaches an output |  |
| 74 | 6 | missing_case | Outstanding strikes are shown solid while the converter is switching (the retry soft-start and the clean-run window) and blink only during the hiccup off-time, because the designer read 'working through a problem' as the hiccup itself | killed | a_red1_blinks_on_strikes |
| 75 | 6 | missing_case | Green_LED is updated only while the converter is switching and keeps its last value in S_OFF, S_HICCUP and S_LATCHED, instead of going dark whenever the converter is not switching | survived |  |
| 76 | 6 | boundary | Strike blink is shown only while exactly one strike is outstanding, as if strike_level were a single strike flag rather than a count | survived |  |
| 77 | 6 | sequencing | The strike blink takes the blink wave's next value (it looks ahead at the half-period terminal count) to 'make up for' Red_LED1's register stage, so the displayed pattern runs one clock ahead of the blink timebase | killed | a_red1_blinks_on_strikes |
| 78 | 7 | sequencing | Latched-trip solid indication waits until the supervisor has left the switching states, as if a latch only counted once the converter had stopped, so the CPLD's own trip in S_SS/S_RUN is not shown solid at once | killed | a_red1_solid_on_latch |
| 79 | 7 | missing_case | Undervoltage indicator is shown only while the converter is not switching, as if input UVLO only mattered once it was holding the converter off | killed | a_red3_follows_uvlo |
| 80 | 7 | missing_case | Live-fault mask on Green is applied only during soft-start, because the designer stretched the window-trip argument ('a fault takes the supervisor out of S_RUN on the next edge') to cover every fault in S_RUN | killed | a_green_shows_healthy_running |
| 81 | 7 | missing_case | Over-temperature is treated as a terminal latched trip and lights Red_LED1 solid, as if a thermal shutdown always fired the SCR | killed | a_red1_dark_when_clean |
| 82 | 7 | priority | The latched-trip solid indication gives way to a live over-temperature, as if a thermal latch were already explained by Red_LED2, so Red_LED1 is not solid while OTP is live | survived |  |
| 83 | 7 | reset_init | Green_LED, once dark in S_RUN, is relit only by a new soft-start, as if 'running unfaulted' meant 'unfaulted since the last start' instead of 'no fault live now' | killed | a_green_shows_healthy_running |
| 84 | 7 | field | Over-temperature indicator is held lit after the board cools for as long as the SCR readback is set, to keep a thermal latch's cause on the panel, which mixes up the fault_cause history with the live condition | survived |  |
| 85 | 7 | wrong_event | Once pgood_LED is lit, it stays lit through comparator dropouts for as long as the supervisor is in S_RUN. The designer assumed the supervisor's window trip would catch a real loss of regulation, so the LED goes dark only on leaving S_RUN instead of following the comparator. | survived |  |
| 86 | 7 | reset_init | Red_LED2 (over-temperature) stays lit after OTP clears for as long as hiccup strikes are outstanding. The 'recently troubled' persistence meant for the Red_LED1 strike blink is applied to the thermal indicator as well, instead of showing only the live OTP condition. | survived |  |
| 87 | 7 | missing_case | The strike blink is turned off whenever Green_LED is lit, so a board that is visibly running shows only one indicator. This breaks the header rule that Green and Red_LED1 are both lit during the clean-run window. | killed | a_red1_blinks_on_strikes |

Rejected by the gate in step 1 (1):

- Outstanding strikes are detected from the LSB of strike_level alone, so a level of 2 counts as no strikes - **make lint already catches it: make lint: UNUSEDSIGNAL**

Rejected by the gate in step 7 (1):

- Running indication takes 'running' from the power-good comparator instead of run_active, mixing up 'output in regulation' with 'converter switching' - **make lint already catches it: make lint: UNUSEDSIGNAL**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `fault_LED.87.EDG.1` | posedge clk -> negedge clk | 9:survived |  |
| `fault_LED.97.BDL.1` | empty the 2-statement body of the if at line 97 | 9:survived |  |
| `fault_LED.97.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 9:survived |  |
| `fault_LED.97.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 9:killed | a_blink_counter_advances |
| `fault_LED.97.UOD.1` | drop the '!' before rst_n | 9:killed | a_blink_counter_advances |
| `fault_LED.99.CST.1` | '0 -> '1 | 9:killed | a_blink_counter_in_range |
| `fault_LED.99.SDL.1` | delete 'blink_counter <= '0;' | 9:survived |  |
| `fault_LED.100.CST.1` | 1'b0 -> 1'b1 | 9:survived |  |
| `fault_LED.100.SDL.1` | delete 'blink <= 1'b0;' | 9:survived |  |
| `fault_LED.104.AIM.11` | Blink terminal count is taken from the full blink period instead of the half-period, so each half of the square wave lasts the whole period | 9:killed | a_blink_counter_in_range, a_blink_counter_wraps +2 |
| `fault_LED.104.AIM.38` | Blink timebase is held in reset through every soft-start so the retry's pattern 'starts on a fresh period', which freezes the blink phase for the whole of S_SS | 9:killed | a_blink_toggles_on_wrap, a_blink_counter_advances |
| `fault_LED.104.AIM.46` | The half-period is halved a second time (as if LED_BLINK_HALF_CLKS were the full period), so the blink square wave toggles every quarter of the intended period and runs at 8 Hz | 9:killed | a_blink_counter_advances, a_blink_stable_otherwise |
| `fault_LED.104.AOR.1` | - -> + | 9:killed | a_blink_counter_in_range, a_blink_counter_wraps +3 |
| `fault_LED.104.BDL.1` | empty the 2-statement body of the if at line 104 | 9:killed | a_blink_counter_wraps, a_blink_toggles_on_wrap |
| `fault_LED.104.CSK.1` | if (blink_counter == BLINK_W'(LED_BLINK_HALF_CLKS-1)) -> if (1'b0): never taken | 9:killed | a_blink_counter_in_range, a_blink_counter_wraps +1 |
| `fault_LED.104.CSK.2` | if (blink_counter == BLINK_W'(LED_BLINK_HALF_CLKS-1)) -> if (1'b1): always taken | 9:killed | a_blink_counter_advances, a_blink_stable_otherwise |
| `fault_LED.104.CST.1` | 1 -> 0 | 9:killed | a_blink_counter_in_range, a_blink_counter_wraps +3 |
| `fault_LED.104.CST.2` | 1 -> 2 | 9:killed | a_blink_counter_advances, a_blink_stable_otherwise |
| `fault_LED.104.EDL.1` | delete the else branch at line 104 | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.104.ROR.1` | == -> != | 9:killed | a_blink_counter_advances, a_blink_stable_otherwise |
| `fault_LED.106.AIM.12` | Blink counter is reloaded to 1 instead of 0 at the half-period terminal count, so every half-period after the first is one clock short | 9:killed | a_blink_counter_wraps |
| `fault_LED.106.AIM.2` | Blink counter is not reloaded at the half-period terminal count and wraps at 2^BLINK_W, so only the first half-period is the right length | 9:killed | a_blink_counter_in_range, a_blink_counter_wraps |
| `fault_LED.106.CST.1` | '0 -> '1 | 9:killed | a_blink_counter_in_range, a_blink_counter_wraps |
| `fault_LED.106.SDL.1` | delete 'blink_counter <= '0;' | 9:killed | a_blink_counter_wraps |
| `fault_LED.107.AIM.29` | Blink is made a one-clock tick at each half-period terminal count instead of a square wave toggled there | 9:killed | a_blink_stable_otherwise |
| `fault_LED.107.AIM.52` | Blink is toggled as the counter leaves zero, at the start of each half-period instead of at its terminal count, so the first half-period after reset lasts one clock | 9:killed | a_blink_toggles_on_wrap, a_blink_stable_otherwise |
| `fault_LED.107.SDL.1` | delete 'blink <= ~blink;' | 9:killed | a_blink_toggles_on_wrap |
| `fault_LED.107.STK.1` | blink stuck at all-zeros (was '~blink') | 9:killed | a_blink_toggles_on_wrap |
| `fault_LED.107.STK.2` | blink stuck at all-ones (was '~blink') | 9:killed | a_blink_toggles_on_wrap |
| `fault_LED.107.UOD.1` | drop the '~' before blink | 9:killed | a_blink_toggles_on_wrap |
| `fault_LED.111.AIM.1` | Blink timebase is held in reset while no strikes are outstanding, so it is started by the first strike instead of running freely | 9:killed | a_blink_counter_advances |
| `fault_LED.111.AIM.39` | Blink phase is cleared to dark while no strikes are outstanding, so the timebase is no longer a free-running square wave and the first strike always starts on a dark half | 9:killed | a_blink_stable_otherwise |
| `fault_LED.111.AIM.47` | Blink timebase only advances while strikes are outstanding and is frozen (not cleared) otherwise, so it is no longer free-running and keeps its phase from one strike episode to the next | 9:killed | a_blink_counter_advances |
| `fault_LED.111.AIM.53` | Blink timebase only counts while the converter is switching (S_SS or S_RUN), as if it shared the converter's enable, so it stops in S_OFF and S_HICCUP instead of running freely | 9:killed | a_blink_counter_advances |
| `fault_LED.111.AOR.1` | + -> - | 9:killed | a_blink_counter_in_range, a_blink_counter_advances |
| `fault_LED.111.CST.1` | 1'b1 -> 1'b0 | 9:killed | a_blink_counter_advances |
| `fault_LED.111.SDL.1` | delete 'blink_counter <= blink_counter + 1'b1;' | 9:killed | a_blink_counter_advances |
| `fault_LED.111.STK.1` | blink_counter stuck at all-zeros (was 'blink_counter + 1'b1') | 9:killed | a_blink_counter_advances |
| `fault_LED.111.STK.2` | blink_counter stuck at all-ones (was 'blink_counter + 1'b1') | 9:killed | a_blink_counter_in_range, a_blink_counter_advances |
| `fault_LED.111.VNG.1` | blink_counter inverted (was 'blink_counter + 1'b1') | 9:killed | a_blink_counter_in_range, a_blink_counter_advances |
| `fault_LED.133.AIM.20` | Green's fault summary reads the registered over-temperature and undervoltage indicators instead of the live OTP/UVLO conditions, so it uses values one clock old | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.AIM.26` | Green's fault summary takes the latch term from the Red_LED1 indicator instead of the live latch_state/latch_assert inputs | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.AIM.3` | Loss of power-good is treated as a live fault, which puts out the running indicator | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.AIM.43` | Green's fault summary leaves out OTP and UVLO, misapplying the window-trip argument that the supervisor leaves S_RUN on its own | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.AIM.44` | Green's fault summary leaves out the latch terms, as if Red_LED1 showing the latch made masking Green unnecessary | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.AIM.57` | Green's fault summary ignores input undervoltage during soft-start, treating an input sag under start-up inrush as expected rather than a live fault | 9:survived |  |
| `fault_LED.133.CTD.1` | drop the term 'otp_state' | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.CTD.2` | drop the term 'uvlo_state' | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.CTD.3` | drop the term 'latch_state' | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.CTD.4` | drop the term 'latch_assert' | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.CTN.1` | negate the term 'otp_state' | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.CTN.2` | negate the term 'uvlo_state' | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.CTN.3` | negate the term 'latch_state' | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.CTN.4` | negate the term 'latch_assert' | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.LCR.1` | \|\| -> && | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.LCR.2` | \|\| -> && | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.LCR.3` | \|\| -> && | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.SDL.1` | delete 'currently_faulted = (otp_state \|\| uvlo_state \|\| latch_state ' | 9:lint | make lint: UNDRIVEN |
| `fault_LED.133.SIB.1` | otp_state -> latch_state | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.SIB.2` | otp_state -> uvlo_state | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.SIB.3` | uvlo_state -> latch_state | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.SIB.4` | uvlo_state -> otp_state | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.SIB.5` | latch_state -> otp_state | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.SIB.6` | latch_state -> uvlo_state | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.SIB.7` | latch_assert -> latch_state | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.STK.1` | currently_faulted stuck at all-zeros (was '(otp_state \|\| uvlo_state \|\| latch_state ') | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.STK.2` | currently_faulted stuck at all-ones (was '(otp_state \|\| uvlo_state \|\| latch_state ') | 9:killed | a_green_shows_healthy_running |
| `fault_LED.133.VNG.1` | currently_faulted inverted (was '(otp_state \|\| uvlo_state \|\| latch_state ') | 9:killed | a_green_shows_healthy_running |
| `fault_LED.138.EDG.1` | posedge clk -> negedge clk | 9:killed | a_green_shows_healthy_running |
| `fault_LED.148.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 9:killed | a_all_leds_dark_in_reset |
| `fault_LED.148.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 9:killed | a_green_shows_healthy_running |
| `fault_LED.148.CST.1` | 1'b0 -> 1'b1 | 9:killed | a_all_leds_dark_in_reset |
| `fault_LED.148.SDL.1` | delete 'Green_LED <= 1'b0;' | 9:killed | a_all_leds_dark_in_reset |
| `fault_LED.148.UOD.1` | drop the '!' before rst_n | 9:killed | a_green_shows_healthy_running, a_all_leds_dark_in_reset |
| `fault_LED.149.AIM.16` | Running indication additionally requires power-good, conflating 'switching' with 'in regulation', so Green stays dark through soft-start | 9:killed | a_green_shows_healthy_running |
| `fault_LED.149.AIM.35` | Running indication treats outstanding strikes as an active state, so Green stays lit through the hiccup off-time instead of going dark in S_HICCUP | 9:survived |  |
| `fault_LED.149.AIM.4` | Green LED is turned off while strikes are outstanding, against the rule that Green and Red_LED1 are both lit during the clean-run window | 9:killed | a_green_shows_healthy_running |
| `fault_LED.149.AIM.42` | Parentheses lost around the active-state term, so the live-fault mask applies only to S_RUN and Green stays lit through soft-start whatever fault is live | 9:survived |  |
| `fault_LED.149.AIM.56` | Green_LED blinks with the strike timebase during soft-start instead of being lit solid whenever the converter is switching unfaulted, the indicator map misremembered | 9:killed | a_green_shows_healthy_running |
| `fault_LED.149.AIM.63` | Running indication is held dark during a retry soft-start while strikes are outstanding, as if a retry were not yet 'running', though Green must be lit in S_SS and S_RUN whenever no fault is live | 9:survived |  |
| `fault_LED.149.AIM.64` | While strikes are outstanding, Green_LED flashes in antiphase with the Red_LED1 strike blink instead of staying solid, because the designer read 'show both' as 'alternate them' | 9:killed | a_green_shows_healthy_running |
| `fault_LED.149.AIM.75` | Green_LED is updated only while the converter is switching and keeps its last value in S_OFF, S_HICCUP and S_LATCHED, instead of going dark whenever the converter is not switching | 9:survived |  |
| `fault_LED.149.AIM.80` | Live-fault mask on Green is applied only during soft-start, because the designer stretched the window-trip argument ('a fault takes the supervisor out of S_RUN on the next edge') to cover every fault in S_RUN | 9:killed | a_green_shows_healthy_running |
| `fault_LED.149.AIM.83` | Green_LED, once dark in S_RUN, is relit only by a new soft-start, as if 'running unfaulted' meant 'unfaulted since the last start' instead of 'no fault live now' | 9:killed | a_green_shows_healthy_running |
| `fault_LED.149.CTD.1` | drop the term '(ss_active \|\| run_active)' | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.149.CTD.2` | drop the term 'ss_active' | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.149.CTD.3` | drop the term 'run_active' | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.149.CTD.4` | drop the term '!currently_faulted' | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.149.CTN.1` | negate the term '(ss_active \|\| run_active)' | 9:killed | a_green_shows_healthy_running |
| `fault_LED.149.CTN.2` | negate the term 'ss_active' | 9:killed | a_green_shows_healthy_running |
| `fault_LED.149.CTN.3` | negate the term 'run_active' | 9:killed | a_green_shows_healthy_running |
| `fault_LED.149.LCR.1` | \|\| -> && | 9:killed | a_green_shows_healthy_running |
| `fault_LED.149.LCR.2` | && -> \|\| | 9:killed | a_green_shows_healthy_running |
| `fault_LED.149.SDL.1` | delete 'Green_LED <= (ss_active \|\| run_active) && !currently_faulted' | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.149.SIB.1` | ss_active -> run_active | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.149.SIB.2` | run_active -> ss_active | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.149.STK.1` | Green_LED stuck at all-zeros (was '(ss_active \|\| run_active) && !currently_') | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.149.STK.2` | Green_LED stuck at all-ones (was '(ss_active \|\| run_active) && !currently_') | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.149.UOD.1` | drop the '!' before currently_faulted | 9:killed | a_green_shows_healthy_running |
| `fault_LED.149.VNG.1` | Green_LED inverted (was '(ss_active \|\| run_active) && !currently_') | 9:killed | a_green_shows_healthy_running |
| `fault_LED.154.EDG.1` | posedge clk -> negedge clk | 9:killed | a_pgood_led_follows_pgood |
| `fault_LED.162.AIM.58` | Power-good LED samples the comparator only while the converter is switching and holds its last reading otherwise, as if the comparator were meaningless with the converter off, instead of following it in every state | 9:survived |  |
| `fault_LED.162.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 9:killed | a_all_leds_dark_in_reset |
| `fault_LED.162.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 9:killed | a_pgood_led_follows_pgood |
| `fault_LED.162.CST.1` | 1'b0 -> 1'b1 | 9:killed | a_all_leds_dark_in_reset |
| `fault_LED.162.SDL.1` | delete 'pgood_LED <= 1'b0;' | 9:killed | a_all_leds_dark_in_reset |
| `fault_LED.162.UOD.1` | drop the '!' before rst_n | 9:killed | a_pgood_led_follows_pgood, a_all_leds_dark_in_reset |
| `fault_LED.163.AIM.10` | Power-good LED is gated by run_active, so it ignores the comparator in every state except S_RUN | 9:survived |  |
| `fault_LED.163.AIM.17` | Power-good LED is masked by any live fault instead of following the comparator directly | 9:killed | a_pgood_led_follows_pgood |
| `fault_LED.163.AIM.28` | Power-good LED latches on once regulation is first reached and is cleared only by reset, instead of following the comparator | 9:survived |  |
| `fault_LED.163.AIM.32` | Power-good LED is held off while strikes are outstanding, as if regulation did not count until the board had earned its clear | 9:killed | a_pgood_led_follows_pgood |
| `fault_LED.163.AIM.54` | Power-good LED is held dark during soft-start, as if the comparator could not be trusted until the ramp finishes, instead of following it in every state | 9:survived |  |
| `fault_LED.163.AIM.59` | Power-good LED is also lit for the whole of S_RUN, on the belief that the supervisor only reaches S_RUN once the rail is in regulation, instead of following the comparator alone | 9:survived |  |
| `fault_LED.163.AIM.67` | Power-good LED samples the comparator only at each blink half-period terminal count, to hide chatter, instead of following it on every clock | 9:killed | a_pgood_led_follows_pgood |
| `fault_LED.163.AIM.72` | Power-good LED is held dark while the latch is set or being asserted, as if a board that has given up could not be in regulation, instead of following the comparator straight through | 9:killed | a_pgood_led_follows_pgood |
| `fault_LED.163.AIM.85` | Once pgood_LED is lit, it stays lit through comparator dropouts for as long as the supervisor is in S_RUN. The designer assumed the supervisor's window trip would catch a real loss of regulation, so the LED goes dark only on leaving S_RUN instead of following the comparator. | 9:survived |  |
| `fault_LED.163.SDL.1` | delete 'pgood_LED <= pgood;' | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.163.STK.1` | pgood_LED stuck at all-zeros (was 'pgood') | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.163.STK.2` | pgood_LED stuck at all-ones (was 'pgood') | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.163.VNG.1` | pgood_LED inverted (was 'pgood') | 9:killed | a_pgood_led_follows_pgood |
| `fault_LED.168.EDG.1` | posedge clk -> negedge clk | 9:killed | a_red1_blinks_on_strikes, a_red1_solid_on_latch |
| `fault_LED.189.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 9:survived |  |
| `fault_LED.189.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 9:killed | a_red1_blinks_on_strikes, a_red1_solid_on_latch |
| `fault_LED.189.CST.1` | 1'b0 -> 1'b1 | 9:killed | a_all_leds_dark_in_reset |
| `fault_LED.189.SDL.1` | delete 'Red_LED1 <= 1'b0;' | 9:survived |  |
| `fault_LED.189.UOD.1` | drop the '!' before rst_n | 9:killed | a_red1_blinks_on_strikes, a_red1_solid_on_latch |
| `fault_LED.191.AIM.13` | Red_LED1 solid indication is driven by any live fault instead of only a latched trip | 9:killed | a_red1_dark_when_clean |
| `fault_LED.191.AIM.14` | Strike level at its maximum is treated as a latched trip and shown solid instead of blinking | 9:survived |  |
| `fault_LED.191.AIM.25` | Red_LED1 patterns swapped: a latched trip blinks and outstanding strikes show solid, the indicator map misremembered | 9:killed | a_red1_blinks_on_strikes, a_red1_solid_on_latch |
| `fault_LED.191.AIM.37` | The CPLD's own trip into the latch is shown blinking until the SCR readback confirms it, instead of solid from the moment latch_assert rises | 9:killed | a_red1_solid_on_latch |
| `fault_LED.191.AIM.5` | Strike blink outranks the latched-trip solid indication | 9:killed | a_red1_solid_on_latch |
| `fault_LED.191.AIM.55` | Latched-trip solid indication is shown only while strikes are outstanding, misreading 'after a latch strike_level stays non-zero' as 'every latch comes with strikes', so a latch tripped by the hardware OVP path with no hiccup history is not shown | 9:survived |  |
| `fault_LED.191.AIM.70` | Latched-trip solid indication is made sticky until reset (the SCR 'cannot be un-tripped'), so once Red_LED1 is lit with no strikes outstanding it never clears from the latch inputs | 9:survived |  |
| `fault_LED.191.AIM.78` | Latched-trip solid indication waits until the supervisor has left the switching states, as if a latch only counted once the converter had stopped, so the CPLD's own trip in S_SS/S_RUN is not shown solid at once | 9:killed | a_red1_solid_on_latch |
| `fault_LED.191.AIM.81` | Over-temperature is treated as a terminal latched trip and lights Red_LED1 solid, as if a thermal shutdown always fired the SCR | 9:killed | a_red1_dark_when_clean |
| `fault_LED.191.AIM.82` | The latched-trip solid indication gives way to a live over-temperature, as if a thermal latch were already explained by Red_LED2, so Red_LED1 is not solid while OTP is live | 9:survived |  |
| `fault_LED.191.CND.1` | if (latch_state \|\| latch_assert) -> if (!(...)) | 9:killed | a_red1_dark_when_clean, a_red1_blinks_on_strikes +1 |
| `fault_LED.191.CSK.1` | if (latch_state \|\| latch_assert) -> if (1'b0): never taken | 9:killed | a_red1_solid_on_latch |
| `fault_LED.191.CSK.2` | if (latch_state \|\| latch_assert) -> if (1'b1): always taken | 9:killed | a_red1_dark_when_clean, a_red1_blinks_on_strikes |
| `fault_LED.191.CST.1` | 1'b1 -> 1'b0 | 9:killed | a_red1_solid_on_latch |
| `fault_LED.191.CTD.1` | drop the term 'latch_state' | 9:killed | a_red1_solid_on_latch |
| `fault_LED.191.CTD.2` | drop the term 'latch_assert' | 9:killed | a_red1_solid_on_latch |
| `fault_LED.191.CTN.1` | negate the term 'latch_state' | 9:killed | a_red1_dark_when_clean, a_red1_blinks_on_strikes +1 |
| `fault_LED.191.CTN.2` | negate the term 'latch_assert' | 9:killed | a_red1_dark_when_clean, a_red1_blinks_on_strikes +1 |
| `fault_LED.191.EDL.1` | delete the else branch at line 191 | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.191.LCR.1` | \|\| -> && | 9:killed | a_red1_solid_on_latch |
| `fault_LED.191.SDL.1` | delete 'Red_LED1 <= 1'b1;' | 9:killed | a_red1_solid_on_latch |
| `fault_LED.191.SIB.1` | latch_state -> otp_state | 9:killed | a_red1_dark_when_clean, a_red1_solid_on_latch |
| `fault_LED.191.SIB.2` | latch_state -> uvlo_state | 9:killed | a_red1_dark_when_clean, a_red1_solid_on_latch |
| `fault_LED.191.SIB.3` | latch_assert -> latch_state | 9:killed | a_red1_solid_on_latch |
| `fault_LED.193.AIM.15` | Strike blink is suppressed while an OTP or UVLO fault is live, though strikes are still outstanding | 9:survived |  |
| `fault_LED.193.AIM.21` | Strike blink starts only from the second outstanding strike, as if strike_level counted from one hiccup before the first | 9:killed | a_red1_blinks_on_strikes |
| `fault_LED.193.AIM.22` | Strike blink is also shown during every soft-start, treating a normal start-up like recovery from a fault | 9:killed | a_red1_dark_when_clean |
| `fault_LED.193.AIM.30` | Strike blink is shown only while the converter is switching, so Red_LED1 goes dark during the hiccup off-time though strikes are outstanding | 9:survived |  |
| `fault_LED.193.AIM.31` | Strike blink stops once the rail is back in regulation, as if power-good meant the strikes were resolved, instead of lasting until clean_run_target clears them | 9:killed | a_red1_blinks_on_strikes |
| `fault_LED.193.AIM.51` | Strike blink is taken from the half-period counter's MSB instead of from the toggled blink square wave, so the pattern repeats every half-period with an uneven duty cycle | 9:killed | a_red1_blinks_on_strikes |
| `fault_LED.193.AIM.6` | Strike blink is shown only while the converter is not switching, not for the whole time strikes are outstanding | 9:killed | a_red1_blinks_on_strikes |
| `fault_LED.193.AIM.60` | Outstanding strikes are shown solid while the converter is not switching (hiccup off-time, S_OFF) and blink only during the retry and run, so Red_LED1 looks like a latched trip during every hiccup | 9:survived |  |
| `fault_LED.193.AIM.68` | Strike blink stops as soon as the supervisor re-enters S_RUN, as if a successful retry ended the strikes, instead of lasting through the clean-run window until clean_run_target clears strike_level | 9:killed | a_red1_blinks_on_strikes |
| `fault_LED.193.AIM.74` | Outstanding strikes are shown solid while the converter is switching (the retry soft-start and the clean-run window) and blink only during the hiccup off-time, because the designer read 'working through a problem' as the hiccup itself | 9:killed | a_red1_blinks_on_strikes |
| `fault_LED.193.AIM.76` | Strike blink is shown only while exactly one strike is outstanding, as if strike_level were a single strike flag rather than a count | 9:survived |  |
| `fault_LED.193.AIM.77` | The strike blink takes the blink wave's next value (it looks ahead at the half-period terminal count) to 'make up for' Red_LED1's register stage, so the displayed pattern runs one clock ahead of the blink timebase | 9:killed | a_red1_blinks_on_strikes |
| `fault_LED.193.AIM.87` | The strike blink is turned off whenever Green_LED is lit, so a board that is visibly running shows only one indicator. This breaks the header rule that Green and Red_LED1 are both lit during the clean-run window. | 9:killed | a_red1_blinks_on_strikes |
| `fault_LED.193.CSK.1` | if (strike_level != '0) -> if (1'b0): never taken | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.193.CSK.2` | if (strike_level != '0) -> if (1'b1): always taken | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.193.CST.1` | '0 -> '1 | 9:killed | a_red1_dark_when_clean |
| `fault_LED.193.EDL.1` | delete the else branch at line 193 | 9:lint | make lint: UNUSEDSIGNAL |
| `fault_LED.193.ROR.1` | != -> == | 9:killed | a_red1_dark_when_clean, a_red1_blinks_on_strikes |
| `fault_LED.193.SDL.1` | delete 'Red_LED1 <= blink;' | 9:killed | a_red1_blinks_on_strikes |
| `fault_LED.193.STK.1` | Red_LED1 stuck at all-zeros (was 'blink') | 9:killed | a_red1_blinks_on_strikes |
| `fault_LED.193.STK.2` | Red_LED1 stuck at all-ones (was 'blink') | 9:killed | a_red1_blinks_on_strikes |
| `fault_LED.193.VNG.1` | Red_LED1 inverted (was 'blink') | 9:killed | a_red1_blinks_on_strikes |
| `fault_LED.195.AIM.62` | When strikes clear, Red_LED1 stays lit to the end of the current lit blink half-period, to 'finish the pattern cleanly', instead of going dark on the next clock | 9:survived |  |
| `fault_LED.195.AIM.7` | Red_LED1 holds its last value when neither a latch nor strikes are present, instead of being cleared | 9:survived |  |
| `fault_LED.195.CST.1` | 1'b0 -> 1'b1 | 9:killed | a_red1_dark_when_clean |
| `fault_LED.195.SDL.1` | delete 'Red_LED1 <= 1'b0;' | 9:survived |  |
| `fault_LED.200.EDG.1` | posedge clk -> negedge clk | 9:killed | a_red2_follows_otp |
| `fault_LED.209.AIM.49` | Over-temperature indicator is cleared only when the converter is back in S_RUN, treating it as a thermal-shutdown history to keep until restart, instead of showing the live OTP condition | 9:survived |  |
| `fault_LED.209.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 9:survived |  |
| `fault_LED.209.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 9:killed | a_red2_follows_otp |
| `fault_LED.209.CST.1` | 1'b0 -> 1'b1 | 9:killed | a_all_leds_dark_in_reset |
| `fault_LED.209.SDL.1` | delete 'Red_LED2 <= 1'b0;' | 9:survived |  |
| `fault_LED.209.UOD.1` | drop the '!' before rst_n | 9:killed | a_red2_follows_otp |
| `fault_LED.210.AIM.18` | Over-temperature indicator is shown only once the converter has left S_RUN, not for the whole time OTP is live | 9:killed | a_red2_follows_otp |
| `fault_LED.210.AIM.23` | Over-temperature indicator is also lit by the SCR latch readback, as if every latched trip were thermal | 9:killed | a_red2_follows_otp |
| `fault_LED.210.AIM.36` | Over-temperature indicator blinks with the strike timebase instead of being lit solid, the indicator map misremembered | 9:killed | a_red2_follows_otp |
| `fault_LED.210.AIM.40` | Over-temperature indicator is suppressed while input undervoltage is live, as if UVLO outranked OTP on the panel, when the two indicators are meant to be independent | 9:killed | a_red2_follows_otp |
| `fault_LED.210.AIM.45` | Over-temperature indicator is suppressed while the latch is set, as if the latched-trip display outranked every other red indicator | 9:survived |  |
| `fault_LED.210.AIM.48` | Over-temperature indicator is shown only while the converter is soft-starting or running, so an OTP that holds the converter off in S_OFF or S_HICCUP leaves Red_LED2 dark | 9:survived |  |
| `fault_LED.210.AIM.65` | Over-temperature indicator is driven by the coarse any-fault summary instead of the OTP condition alone | 9:killed | a_red2_follows_otp |
| `fault_LED.210.AIM.71` | Over-temperature indicator is updated only at each blink half-period terminal count, to keep it in step with the panel blink, instead of following the live OTP condition on every clock | 9:survived |  |
| `fault_LED.210.AIM.8` | Over-temperature indicator is made sticky until reset, like a fault_cause history bit, instead of showing the live condition | 9:killed | a_red2_follows_otp |
| `fault_LED.210.AIM.84` | Over-temperature indicator is held lit after the board cools for as long as the SCR readback is set, to keep a thermal latch's cause on the panel, which mixes up the fault_cause history with the live condition | 9:survived |  |
| `fault_LED.210.AIM.86` | Red_LED2 (over-temperature) stays lit after OTP clears for as long as hiccup strikes are outstanding. The 'recently troubled' persistence meant for the Red_LED1 strike blink is applied to the thermal indicator as well, instead of showing only the live OTP condition. | 9:survived |  |
| `fault_LED.210.SDL.1` | delete 'Red_LED2 <= otp_state;' | 9:killed | a_red2_follows_otp |
| `fault_LED.210.SIB.1` | otp_state -> latch_state | 9:killed | a_red2_follows_otp |
| `fault_LED.210.SIB.2` | otp_state -> uvlo_state | 9:killed | a_red2_follows_otp |
| `fault_LED.210.STK.1` | Red_LED2 stuck at all-zeros (was 'otp_state') | 9:killed | a_red2_follows_otp |
| `fault_LED.210.STK.2` | Red_LED2 stuck at all-ones (was 'otp_state') | 9:killed | a_red2_follows_otp |
| `fault_LED.210.VNG.1` | Red_LED2 inverted (was 'otp_state') | 9:killed | a_red2_follows_otp |
| `fault_LED.215.EDG.1` | posedge clk -> negedge clk | 9:killed | a_red3_follows_uvlo |
| `fault_LED.224.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 9:survived |  |
| `fault_LED.224.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 9:killed | a_red3_follows_uvlo |
| `fault_LED.224.CST.1` | 1'b0 -> 1'b1 | 9:killed | a_all_leds_dark_in_reset |
| `fault_LED.224.SDL.1` | delete 'Red_LED3 <= 1'b0;' | 9:survived |  |
| `fault_LED.224.UOD.1` | drop the '!' before rst_n | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.AIM.19` | Undervoltage indicator is driven by the coarse any-fault summary instead of the UVLO condition alone | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.AIM.24` | Undervoltage indicator is suppressed while the latch is set, as if the latched-trip display outranked it the way it outranks the strike blink | 9:survived |  |
| `fault_LED.225.AIM.27` | Undervoltage indicator is masked during soft-start, as if an input sag during start-up inrush were expected and not worth showing | 9:survived |  |
| `fault_LED.225.AIM.33` | Undervoltage indicator is shown only while the converter is soft-starting or running, so the case UVLO most often produces - a converter held off in S_OFF - is left dark | 9:survived |  |
| `fault_LED.225.AIM.34` | Undervoltage indicator is also lit by loss of output power-good, confusing input undervoltage with an output rail out of regulation | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.AIM.41` | Undervoltage indicator is stretched until the converter is running again, as though the UVLO comparator needed stretching, instead of showing the live condition | 9:survived |  |
| `fault_LED.225.AIM.50` | Undervoltage indicator is made a brown-out history bit, set by UVLO and cleared only by reset, instead of following the live input-undervoltage condition | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.AIM.61` | Undervoltage indicator blinks with the strike timebase instead of being lit solid while input UVLO is live, the indicator map misremembered | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.AIM.66` | Undervoltage indicator is also lit by the SCR latch readback, as if a latched board had lost its input | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.AIM.69` | Undervoltage indicator is suppressed while the output is in regulation, as if an input UVLO with the rail still good had to be a comparator glitch | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.AIM.79` | Undervoltage indicator is shown only while the converter is not switching, as if input UVLO only mattered once it was holding the converter off | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.AIM.9` | Undervoltage indicator is chained after over-temperature and suppressed while OTP is live, instead of being independent | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.SDL.1` | delete 'Red_LED3 <= uvlo_state;' | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.SIB.1` | uvlo_state -> latch_state | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.SIB.2` | uvlo_state -> otp_state | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.STK.1` | Red_LED3 stuck at all-zeros (was 'uvlo_state') | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.STK.2` | Red_LED3 stuck at all-ones (was 'uvlo_state') | 9:killed | a_red3_follows_uvlo |
| `fault_LED.225.VNG.1` | Red_LED3 inverted (was 'uvlo_state') | 9:killed | a_red3_follows_uvlo |
| `fault_LED.111.AIM.73` | Blink timebase is frozen while the latch is set, on the reasoning that the solid latched indication masks the blink anyway, so it no longer runs freely | not run (withdrawn at step 8) |  |
