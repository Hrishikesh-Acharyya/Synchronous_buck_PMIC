# Mutation record: fault_cause

`rtl-systemverilog/telemetry/fault_cause.sv`. Written by `tools/mutation/record.py` from `fault_cause.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 136 | 114 | 22 | 0 | 0 | 0 | 0 | 0 | 100.0% |
| AI-written | 110 | 72 | 0 | 0 | 0 | 38 | 0 | 0 | 65.5% |
| all | 246 | 186 | 22 | 0 | 0 | 38 | 0 | 0 | 84.6% |

Survivors: 38 - 0 decided equivalent, 7 accepted, 31 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 87.0%.
8 earlier mutants are not in these numbers: 8 AI-written ones the designer withdrew, 0 the generator no longer makes because the RTL changed. Their history is kept below.

## Survivors (38)

### `fault_cause.104.AIM.108` - The capture gate is held open while the protection latch reads back set, so that the analog OVP trip that stops the converter is sure to be recorded

- before: `always_comb convertor_running = (ss_active||run_active);`
- after: `always_comb convertor_running = (ss_active||run_active||latch_state);`
- AI judgement (step 17): **plausible**, high confidence - With ss_active=run_active=0 and latch_state=1, the mutant opens the gate at line 104. Causes are then captured at lines 205-209 and fault_time is stamped at line 166, but the original records nothing while stopped.
- designer's decision (step 21): **gap** - nothing is raised while the converter is stopped: the header says a fault asserting while stopped is not captured and the record holds until read, but no test raises latch_state, latch_assert or OTP (or lets OTP clear) with the converter stopped and checks fault_reg and fault_time stay as they were

### `fault_cause.104.AIM.86` - The capture gate is held open one clock after the converter stops, so the trip that stopped it is sure to be seen, but it also captures a cause that only appears after the stop

- before: `always_comb convertor_running = (ss_active||run_active);`
- after: `logic  running_q; / always_ff @ (posedge clk or negedge rst_n) begin / if(!rst_n) running_q <= 1'b0; / else       running_q <= (ss_active||run_active); / end / always_comb convertor_running = (ss_active||run_active||running_q);`
- AI judgement (step 17): **plausible**, high confidence - For one clock after ss_active/run_active fall, running_q keeps convertor_running high. A cause that appears on that clock is captured at lines 205-209 in the mutant only.
- designer's decision (step 25): **accepted** - widens the capture gate by one clock (100 ns) after the converter stops; only a cause rising on exactly that clock differs, and the stopping cause was already captured on the clock before

### `fault_cause.118.AIM.15` - OVP inference is suppressed while an overcurrent window trip is live, on the assumption that the latch trip then belongs to the overcurrent

- before: `if(latch_state & ~latch_assert) ovp = 1'b1;`
- after: `if(latch_state & ~latch_assert & ~(window_trip | window_trip_SS)) ovp = 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - While running, if latch_state=1, latch_assert=0 and window_trip=1, the mutant leaves ovp low. fault_reg[BIT_OVP] is then not set at line 208, so the output differs.
- designer's decision (step 18): **gap** - no test raises two causes on the same clock: each cause is recorded alone, so a cause masked by another live cause goes unseen; needs simultaneous pairs of causes with every bit checked

### `fault_cause.118.AIM.57` - OVP inference is suppressed while UVLO is live, on the assumption that the SCR readback is not trustworthy during a brown-out

- before: `if(latch_state & ~latch_assert) ovp = 1'b1;`
- after: `if(latch_state & ~latch_assert & ~uvlo_state) ovp = 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - While running, if latch_state=1, latch_assert=0 and uvlo_state=1, the mutant suppresses ovp. BIT_OVP is then missing from fault_reg (line 208).
- designer's decision (step 18): **gap** - no test raises two causes on the same clock: each cause is recorded alone, so a cause masked by another live cause goes unseen; needs simultaneous pairs of causes with every bit checked

### `fault_cause.118.AIM.60` - OVP is inferred only into an empty record, on the belief that an analog latch trip after any other recorded cause must be a consequence of that cause

- before: `if(latch_state & ~latch_assert) ovp = 1'b1;`
- after: `if(latch_state & ~latch_assert & (fault_reg == '0)) ovp = 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - If fault_reg already holds a cause (say OTP), a later latch_state=1 with latch_assert=0 sets BIT_OVP in the original but not in the mutant.
- designer's decision (step 19): **gap** - no test adds a cause after another is already recorded in the orders that matter (UVLO second, a lower-priority cause after a higher one, OVP after any cause); needs causes arriving in several orders, each checked to be added

### `fault_cause.118.AIM.90` - OVP inference is suppressed while OTP is live, as if the over-temperature comparator were a third trip source of the shared protection latch

- before: `if(latch_state & ~latch_assert) ovp = 1'b1;`
- after: `if(latch_state & ~latch_assert & ~otp_state) ovp = 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - While running, if otp_state=1 together with latch_state=1 and latch_assert=0, the mutant does not infer ovp. BIT_OVP is not recorded at line 208.
- designer's decision (step 18): **gap** - no test raises two causes on the same clock: each cause is recorded alone, so a cause masked by another live cause goes unseen; needs simultaneous pairs of causes with every bit checked

### `fault_cause.138.AIM.17` - The record is judged empty from the four lower cause bits only; a recorded OVP does not count as an open episode

- before: `episode_start = convertor_running && (fault_reg == '0)`
- after: `episode_start = convertor_running && (fault_reg[BIT_LATCH:0] == '0)`
- AI judgement (step 17): **plausible**, high confidence - With fault_reg holding only BIT_OVP, a new live cause makes episode_start true in the mutant. Line 166 then re-stamps fault_time, which the original holds.
- designer's decision (step 23): **gap** - an episode opened by OVP alone and a UVLO record surviving a later soft start are untested; needs an OVP-only record followed by a second cause (fault_time held), and a restart after a recorded UVLO

### `fault_cause.138.AIM.4` - The episode is judged empty by fault_time being zero instead of fault_reg being zero

- before: `episode_start = convertor_running && (fault_reg == '0)`
- after: `episode_start = convertor_running && (fault_time == '0)`
- AI judgement (step 17): **plausible**, high confidence - If the episode is stamped when timestamp_ms=0, fault_time stays 0 while fault_reg is non-empty. A later cause then re-stamps fault_time in the mutant; it also stamps whenever fault_time is 0 even though fault_reg is non-empty.
- designer's decision (step 24): **accepted** - differs only for an episode stamped while timestamp_ms is 0: the 24-bit ms counter is 0 for 1 ms after reset (the converter cannot be running yet) and for 1 ms every 4.66 h after it wraps

### `fault_cause.138.AIM.70` - Each soft-start retry is treated as a new episode: a cause captured during S_SS re-stamps fault_time even when the record already holds causes

- before: `episode_start = convertor_running && (fault_reg == '0)`
- after: `episode_start = convertor_running && ((fault_reg == '0) || ss_active)`
- AI judgement (step 17): **plausible**, high confidence - During ss_active with fault_reg already non-empty, a live cause re-stamps fault_time at line 166 in the mutant. The original holds the earlier stamp.
- designer's decision (step 20): **gap** - no cause is raised during soft start: OTP, UVLO and OVP captured in S_SS, the episode stamp from S_SS and a second cause in S_SS are untested; needs causes in S_SS with fault_reg and fault_time checked

### `fault_cause.138.AIM.73` - Episode start lets the latch causes (inferred OVP and latch_assert) bypass the capture gate, on the belief that a latch trip always marks an episode, while the accumulator still gates them, so the two blocks disagree once the converter has stopped

- before: `episode_start = convertor_running && (fault_reg == '0) / && (otp_state || uvlo_state || ovp || latch_assert / || window_trip || window_trip_SS);`
- after: `episode_start = (fault_reg == '0) / && ((convertor_running && (otp_state || uvlo_state / || window_trip || window_trip_SS)) || ovp || latch_assert);`
- AI judgement (step 17): **plausible**, high confidence - With the converter stopped, fault_reg empty and ovp or latch_assert high, the mutant stamps fault_time from timestamp_ms. The original leaves it at 0.
- designer's decision (step 21): **gap** - nothing is raised while the converter is stopped: the header says a fault asserting while stopped is not captured and the record holds until read, but no test raises latch_state, latch_assert or OTP (or lets OTP clear) with the converter stopped and checks fault_reg and fault_time stay as they were

### `fault_cause.138.AIM.84` - When deciding whether the record is empty, the episode detector ignores the LATCH_ASSERT bit, as if the sticky CPLD trip were background state rather than an open episode

- before: `episode_start = convertor_running && (fault_reg == '0)`
- after: `episode_start = convertor_running && (fault_reg[BIT_OVP] == 1'b0) && (fault_reg[BIT_OTP:BIT_OC] == '0)`
- AI judgement (step 17): **plausible**, high confidence - With fault_reg holding only BIT_LATCH and a cause still live while running, the mutant keeps asserting episode_start. It re-stamps fault_time on each such clock, which the original does not.
- designer's decision (step 26): **accepted** - need latch_assert high while the converter runs, which never happens on the chip: strike_counter raises latch_assert on hiccup entry, after S_RUN has been left, and the supervisor then never restarts while it is high (top-level soak: c_capture_latch never hit). The LATCH_ASSERT bit is therefore never set on the chip - a design note, see the finding

### `fault_cause.139.AIM.100` - UVLO opens an episode only in S_RUN: a Vin dip during soft start is treated as inrush sag and does not stamp fault_time, although the accumulator still records it

- before: `&& (otp_state || uvlo_state || ovp || latch_assert`
- after: `&& (otp_state || (uvlo_state && run_active) || ovp || latch_assert`
- AI judgement (step 17): **plausible**, high confidence - With fault_reg empty, if UVLO is the only cause during ss_active, the mutant does not assert episode_start. fault_time stays 0 while fault_reg[BIT_UVLO] is set.
- designer's decision (step 20): **gap** - no cause is raised during soft start: OTP, UVLO and OVP captured in S_SS, the episode stamp from S_SS and a second cause in S_SS are untested; needs causes in S_SS with fault_reg and fault_time checked

### `fault_cause.165.AIM.2` - fault_time capture takes priority over its clear-on-read, the opposite of fault_reg

- before: `else if (fault_reg_read_done)     fault_time <= '0; / else if (episode_start)           fault_time <= timestamp_ms;`
- after: `else if (episode_start)           fault_time <= timestamp_ms; / else if (fault_reg_read_done)     fault_time <= '0;`
- AI judgement (step 17): **plausible**, high confidence - fault_reg_read_done can pulse while fault_reg is empty and a cause is live while running. Then episode_start is also true and the mutant stamps fault_time where the original clears it.
- designer's decision (step 22): **gap** - host reads are only tested while running with causes gone: a read on the clock the first cause is captured, a read while stopped, and a read of an empty record with a cause live are untested

### `fault_cause.165.AIM.96` - A host read clears fault_time only while the converter is in S_SS or S_RUN. A read after a shutdown clears fault_reg but leaves the old episode start time.

- before: `else if (fault_reg_read_done)     fault_time <= '0;`
- after: `else if (fault_reg_read_done && convertor_running)     fault_time <= '0;`
- AI judgement (step 17): **plausible**, high confidence - A read while the converter is stopped and fault_time is non-zero clears fault_time in the original. The mutant leaves it unchanged.
- designer's decision (step 22): **gap** - host reads are only tested while running with causes gone: a read on the clock the first cause is captured, a read while stopped, and a read of an empty record with a cause live are untested

### `fault_cause.197.AIM.61` - A host read clears fault_reg only while the converter is running, so the cause of a shutdown cannot be read away until the converter restarts

- before: `else if (fault_reg_read_done) begin`
- after: `else if (fault_reg_read_done && convertor_running) begin`
- AI judgement (step 17): **plausible**, high confidence - A read while the converter is stopped and fault_reg is non-empty clears fault_reg in the original. The mutant does not clear it.
- designer's decision (step 22): **gap** - host reads are only tested while running with causes gone: a read on the clock the first cause is captured, a read while stopped, and a read of an empty record with a cause live are untested

### `fault_cause.197.AIM.83` - A host read clears fault_reg only when the record is non-empty, on the belief that an empty record has nothing to clear, so a cause live on the read clock is captured through the read instead of losing to the clear

- before: `else if (fault_reg_read_done) begin`
- after: `else if (fault_reg_read_done && (fault_reg != '0)) begin`
- AI judgement (step 17): **plausible**, high confidence - A read while fault_reg is empty, the converter is running and a cause is live falls through to the capture branch in the mutant. fault_reg becomes non-zero where the original stays 0.
- designer's decision (step 22): **gap** - host reads are only tested while running with causes gone: a read on the clock the first cause is captured, a read while stopped, and a read of an empty record with a cause live are untested

### `fault_cause.203.AIM.40` - The capture gate is held open while the CPLD's latch trip is asserted, so the trip that stops the converter is sure to be seen. Because latch_assert is held until reset, the gate never closes after a latch trip.

- before: `else if(convertor_running) begin`
- after: `else if(convertor_running || latch_assert) begin`
- AI judgement (step 17): **plausible**, high confidence - With the converter stopped and latch_assert=1, the mutant captures latch_assert and any other live causes into fault_reg. The original records nothing.
- designer's decision (step 21): **gap** - nothing is raised while the converter is stopped: the header says a fault asserting while stopped is not captured and the record holds until read, but no test raises latch_state, latch_assert or OTP (or lets OTP clear) with the converter stopped and checks fault_reg and fault_time stay as they were

### `fault_cause.205.AIM.115` - OTP is not recorded while the protection latch reads back set, on the belief that a latched converter is no longer heating the board, so any over-temperature then is not part of the fault

- before: `if(otp_state)                       fault_reg[BIT_OTP]   <= 1'b1;`
- after: `if(otp_state && !latch_state)       fault_reg[BIT_OTP]   <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - While running, if otp_state=1 and latch_state=1, the mutant does not set BIT_OTP.
- designer's decision (step 18): **gap** - no test raises two causes on the same clock: each cause is recorded alone, so a cause masked by another live cause goes unseen; needs simultaneous pairs of causes with every bit checked

### `fault_cause.205.AIM.46` - OTP is recorded only when UVLO is not live, as if a brown-out made the OTP reading unreliable and UVLO took precedence

- before: `if(otp_state)                       fault_reg[BIT_OTP]   <= 1'b1;`
- after: `if(otp_state && !uvlo_state)        fault_reg[BIT_OTP]   <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - While running, if otp_state=1 and uvlo_state=1, the mutant does not set BIT_OTP.
- designer's decision (step 18): **gap** - no test raises two causes on the same clock: each cause is recorded alone, so a cause masked by another live cause goes unseen; needs simultaneous pairs of causes with every bit checked

### `fault_cause.205.AIM.56` - OTP is recorded only in S_RUN, on the assumption that the board can only overheat under regulated load current, so an over-temperature during soft start is forgotten

- before: `if(otp_state)                       fault_reg[BIT_OTP]   <= 1'b1;`
- after: `if(otp_state && run_active)         fault_reg[BIT_OTP]   <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - An OTP during ss_active with run_active=0 sets BIT_OTP in the original but not in the mutant.
- designer's decision (step 20): **gap** - no cause is raised during soft start: OTP, UVLO and OVP captured in S_SS, the episode stamp from S_SS and a second cause in S_SS are untested; needs causes in S_SS with fault_reg and fault_time checked

### `fault_cause.205.AIM.87` - The bit-position priority is applied to recording: once a higher-priority cause is recorded, every lower-priority cause is dropped as its consequence, instead of all causes being OR-accumulated

- before: `if(otp_state)                       fault_reg[BIT_OTP]   <= 1'b1; / if(uvlo_state)                      fault_reg[BIT_UVLO]  <= 1'b1; / if(window_trip || window_trip_SS)   fault_reg [BIT_OC]   <= 1'b1; / if(ovp)                             fault_reg[BIT_OVP]   <= 1'b1; / if(latch_assert)                    fault_reg[BIT_LATCH] <= 1'b1;`
- after: `if(otp_state && (fault_reg[BIT_OVP:BIT_LATCH] == '0))  fault_reg[BIT_OTP]   <= 1'b1; / if(uvlo_state && (fault_reg[BIT_OVP:BIT_OTP] == '0))   fault_reg[BIT_UVLO]  <= 1'b1; / if((window_trip || window_trip_SS) && (fault_reg[BIT_OVP:BIT_UVLO] == '0))   fault_reg [BIT_OC]   <= 1'b1; / if(ovp)                             fault_reg[BIT_OVP]   <= 1'b1; / if(latch_assert && !fault_reg[BIT_OVP])                fault_reg[BIT_LATCH] <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - With BIT_OVP already recorded, a later OTP, UVLO or window trip is no longer set by the mutant. The original OR-accumulates every cause.
- designer's decision (step 19): **gap** - no test adds a cause after another is already recorded in the orders that matter (UVLO second, a lower-priority cause after a higher one, OVP after any cause); needs causes arriving in several orders, each checked to be added

### `fault_cause.206.AIM.10` - Causes are captured through a priority chain, one per clock, instead of independently accumulated

- before: `if(uvlo_state)                      fault_reg[BIT_UVLO]  <= 1'b1; / if(window_trip || window_trip_SS)   fault_reg [BIT_OC]   <= 1'b1; / if(ovp)                             fault_reg[BIT_OVP]   <= 1'b1; / if(latch_assert)                    fault_reg[BIT_LATCH] <= 1'b1;`
- after: `else if(uvlo_state)                 fault_reg[BIT_UVLO]  <= 1'b1; / else if(window_trip || window_trip_SS) fault_reg [BIT_OC] <= 1'b1; / else if(ovp)                        fault_reg[BIT_OVP]   <= 1'b1; / else if(latch_assert)               fault_reg[BIT_LATCH] <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - If otp_state and uvlo_state are both high while running, the else-if chain records only BIT_OTP on that clock. A one-clock UVLO is lost.
- designer's decision (step 18): **gap** - no test raises two causes on the same clock: each cause is recorded alone, so a cause masked by another live cause goes unseen; needs simultaneous pairs of causes with every bit checked

### `fault_cause.206.AIM.18` - UVLO is recorded only as the first cause of an episode; a UVLO that follows another recorded cause is treated as a consequence and dropped

- before: `if(uvlo_state)                      fault_reg[BIT_UVLO]  <= 1'b1;`
- after: `if(uvlo_state && (fault_reg == '0)) fault_reg[BIT_UVLO]  <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - A UVLO that arrives after another cause is already recorded is dropped by the mutant, so BIT_UVLO differs.
- designer's decision (step 19): **gap** - no test adds a cause after another is already recorded in the orders that matter (UVLO second, a lower-priority cause after a higher one, OVP after any cause); needs causes arriving in several orders, each checked to be added

### `fault_cause.206.AIM.63` - UVLO is not recorded while the protection latch reads back set, on the belief that an input droop after a latch trip is caused by the trip

- before: `if(uvlo_state)                      fault_reg[BIT_UVLO]  <= 1'b1;`
- after: `if(uvlo_state && !latch_state)      fault_reg[BIT_UVLO]  <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - While running, if uvlo_state=1 and latch_state=1, the mutant does not set BIT_UVLO.
- designer's decision (step 18): **gap** - no test raises two causes on the same clock: each cause is recorded alone, so a cause masked by another live cause goes unseen; needs simultaneous pairs of causes with every bit checked

### `fault_cause.206.AIM.7` - UVLO is recorded only in S_RUN; a UVLO that interrupts soft start is forgotten

- before: `if(uvlo_state)                      fault_reg[BIT_UVLO]  <= 1'b1;`
- after: `if(uvlo_state && run_active)        fault_reg[BIT_UVLO]  <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - A UVLO during ss_active only sets BIT_UVLO in the original but not in the mutant.
- designer's decision (step 20): **gap** - no cause is raised during soft start: OTP, UVLO and OVP captured in S_SS, the episode stamp from S_SS and a second cause in S_SS are untested; needs causes in S_SS with fault_reg and fault_time checked

### `fault_cause.206.AIM.76` - UVLO is not recorded while an overcurrent window trip is live, on the belief that an input droop under overcurrent is caused by the load current

- before: `if(uvlo_state)                      fault_reg[BIT_UVLO]  <= 1'b1;`
- after: `if(uvlo_state && !(window_trip || window_trip_SS)) fault_reg[BIT_UVLO]  <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - While running, if uvlo_state is high together with window_trip or window_trip_SS, the mutant does not set BIT_UVLO.
- designer's decision (step 18): **gap** - no test raises two causes on the same clock: each cause is recorded alone, so a cause masked by another live cause goes unseen; needs simultaneous pairs of causes with every bit checked

### `fault_cause.206.AIM.93` - UVLO is not recorded while OTP is live, as if over-temperature outranked and explained a simultaneous input brown-out

- before: `if(uvlo_state)                      fault_reg[BIT_UVLO]  <= 1'b1;`
- after: `if(uvlo_state && !otp_state)        fault_reg[BIT_UVLO]  <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - While running, if uvlo_state and otp_state are both high, the mutant does not set BIT_UVLO.
- designer's decision (step 18): **gap** - no test raises two causes on the same clock: each cause is recorded alone, so a cause masked by another live cause goes unseen; needs simultaneous pairs of causes with every bit checked

### `fault_cause.206.AIM.95` - The UVLO bit is withdrawn during soft start once Vin is back. A restart after a recovered brown-out is taken to mean the UVLO was a routine power cycle and not a fault.

- before: `if(uvlo_state)                      fault_reg[BIT_UVLO]  <= 1'b1;`
- after: `if(uvlo_state)                      fault_reg[BIT_UVLO]  <= 1'b1; / else if(ss_active)                  fault_reg[BIT_UVLO]  <= 1'b0;`
- AI judgement (step 17): **plausible**, high confidence - Once BIT_UVLO is recorded, a later clock with ss_active=1 and uvlo_state=0 clears it in the mutant. The original never clears individual bits.
- designer's decision (step 23): **gap** - an episode opened by OVP alone and a UVLO record surviving a later soft start are untested; needs an OVP-only record followed by a second cause (fault_time held), and a restart after a recorded UVLO

### `fault_cause.207.AIM.62` - The OVERCURRENT bit is not recorded while an OVP is inferred, on the belief that a window trip during an analog overvoltage is only a consequence of the overshoot

- before: `if(window_trip || window_trip_SS)   fault_reg [BIT_OC]   <= 1'b1;`
- after: `if((window_trip || window_trip_SS) && !ovp) fault_reg [BIT_OC]   <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - While running, if a window trip happens together with latch_state=1 and latch_assert=0 (ovp=1), the mutant does not set BIT_OC.
- designer's decision (step 18): **gap** - no test raises two causes on the same clock: each cause is recorded alone, so a cause masked by another live cause goes unseen; needs simultaneous pairs of causes with every bit checked

### `fault_cause.207.AIM.94` - The OVERCURRENT bit is not recorded while UVLO is live, on the belief that a window trip during a brown-out is only the input-current surge the droop causes

- before: `if(window_trip || window_trip_SS)   fault_reg [BIT_OC]   <= 1'b1;`
- after: `if((window_trip || window_trip_SS) && !uvlo_state)   fault_reg [BIT_OC]   <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - While running, if a window trip happens together with uvlo_state=1, the mutant does not set BIT_OC.
- designer's decision (step 18): **gap** - no test raises two causes on the same clock: each cause is recorded alone, so a cause masked by another live cause goes unseen; needs simultaneous pairs of causes with every bit checked

### `fault_cause.208.AIM.37` - OVP is recorded only in S_RUN, on the assumption that overvoltage can only occur once the output is regulated, so an OVP overshoot during soft start is not recorded

- before: `if(ovp)                             fault_reg[BIT_OVP]   <= 1'b1;`
- after: `if(ovp && run_active)               fault_reg[BIT_OVP]   <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - An inferred ovp during ss_active only sets BIT_OVP in the original but not in the mutant.
- designer's decision (step 20): **gap** - no cause is raised during soft start: OTP, UVLO and OVP captured in S_SS, the episode stamp from S_SS and a second cause in S_SS are untested; needs causes in S_SS with fault_reg and fault_time checked

### `fault_cause.209.AIM.16` - Recording LATCH_ASSERT withdraws an already recorded OVP bit, treating the two latch origins as mutually exclusive in the record

- before: `if(latch_assert)                    fault_reg[BIT_LATCH] <= 1'b1;`
- after: `if(latch_assert) begin / fault_reg[BIT_LATCH] <= 1'b1; / fault_reg[BIT_OVP]   <= 1'b0; / end`
- AI judgement (step 17): **plausible**, high confidence - With BIT_OVP already recorded, a later latch_assert while running clears BIT_OVP in the mutant. The original keeps it set.
- designer's decision (step 26): **accepted** - need latch_assert high while the converter runs, which never happens on the chip: strike_counter raises latch_assert on hiccup entry, after S_RUN has been left, and the supervisor then never restarts while it is high (top-level soak: c_capture_latch never hit). The LATCH_ASSERT bit is therefore never set on the chip - a design note, see the finding

### `fault_cause.209.AIM.34` - LATCH_ASSERT is recorded only in S_RUN, on the assumption that the CPLD trips the latch only from run-time strikes, so a latch trip during soft start is forgotten

- before: `if(latch_assert)                    fault_reg[BIT_LATCH] <= 1'b1;`
- after: `if(latch_assert && run_active)      fault_reg[BIT_LATCH] <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - A latch_assert during ss_active only sets BIT_LATCH in the original but not in the mutant.
- designer's decision (step 26): **accepted** - need latch_assert high while the converter runs, which never happens on the chip: strike_counter raises latch_assert on hiccup entry, after S_RUN has been left, and the supervisor then never restarts while it is high (top-level soak: c_capture_latch never hit). The LATCH_ASSERT bit is therefore never set on the chip - a design note, see the finding

### `fault_cause.209.AIM.53` - Recording the LATCH_ASSERT (OCP/SCP) trip withdraws the OVERCURRENT bit, on the assumption that the latch bit already covers the window trips that led to it

- before: `if(latch_assert)                    fault_reg[BIT_LATCH] <= 1'b1;`
- after: `if(latch_assert) begin / fault_reg[BIT_LATCH] <= 1'b1; / fault_reg[BIT_OC]    <= 1'b0; / end`
- AI judgement (step 17): **plausible**, high confidence - A latch_assert while running clears BIT_OC in the mutant, whether it was recorded earlier or set on the same clock. The original keeps it.
- designer's decision (step 26): **accepted** - need latch_assert high while the converter runs, which never happens on the chip: strike_counter raises latch_assert on hiccup entry, after S_RUN has been left, and the supervisor then never restarts while it is high (top-level soak: c_capture_latch never hit). The LATCH_ASSERT bit is therefore never set on the chip - a design note, see the finding

### `fault_cause.209.AIM.77` - LATCH_ASSERT is not recorded once OVERCURRENT is in the record, on the belief that the window trip already explains the CPLD's latch trip

- before: `if(latch_assert)                    fault_reg[BIT_LATCH] <= 1'b1;`
- after: `if(latch_assert && !fault_reg[BIT_OC]) fault_reg[BIT_LATCH] <= 1'b1;`
- AI judgement (step 17): **plausible**, high confidence - With BIT_OC already recorded, a later latch_assert does not set BIT_LATCH in the mutant.
- designer's decision (step 26): **accepted** - need latch_assert high while the converter runs, which never happens on the chip: strike_counter raises latch_assert on hiccup entry, after S_RUN has been left, and the supervisor then never restarts while it is high (top-level soak: c_capture_latch never hit). The LATCH_ASSERT bit is therefore never set on the chip - a design note, see the finding

### `fault_cause.211.AIM.104` - Once the converter has stopped, the OTP bit is withdrawn as soon as the board cools, as if a self-clearing over-temperature should clear its own record before the next start

- before: `end`
- after: `end /  / else begin / if(!otp_state)                      fault_reg[BIT_OTP]   <= 1'b0; / end`
- AI judgement (step 17): **plausible**, high confidence - With the converter stopped, no read pending and otp_state=0, the new else branch clears a recorded BIT_OTP. The original holds it.
- designer's decision (step 21): **gap** - nothing is raised while the converter is stopped: the header says a fault asserting while stopped is not captured and the record holds until read, but no test raises latch_state, latch_assert or OTP (or lets OTP clear) with the converter stopped and checks fault_reg and fault_time stay as they were

### `fault_cause.211.AIM.52` - OVP is recorded even while the converter is stopped, on the assumption that the analog comparator can trip the latch at any time and should always be logged

- before: `end`
- after: `end /  / else if(ovp) begin /  / fault_reg[BIT_OVP] <= 1'b1; /  / end`
- AI judgement (step 17): **plausible**, high confidence - With the converter stopped and latch_state=1, latch_assert=0, the mutant sets BIT_OVP. The original records nothing while stopped.
- designer's decision (step 21): **gap** - nothing is raised while the converter is stopped: the header says a fault asserting while stopped is not captured and the record holds until read, but no test raises latch_state, latch_assert or OTP (or lets OTP clear) with the converter stopped and checks fault_reg and fault_time stay as they were

### `fault_cause.211.AIM.67` - The LATCH_ASSERT bit bypasses the capture gate on the assumption that the CPLD's latch trip is always worth logging. It is recorded even while the converter is stopped, unlike every other cause.

- before: `end`
- after: `end /  / else if(latch_assert) begin / fault_reg[BIT_LATCH] <= 1'b1; / end`
- AI judgement (step 17): **plausible**, high confidence - With the converter stopped and latch_assert=1, the mutant sets BIT_LATCH. The original records nothing while stopped.
- designer's decision (step 21): **gap** - nothing is raised while the converter is stopped: the header says a fault asserting while stopped is not captured and the record holds until read, but no test raises latch_state, latch_assert or OTP (or lets OTP clear) with the converter stopped and checks fault_reg and fault_time stay as they were

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-14 14:38 | 664452d | AI wrote mutants (claude-fable-5-2) | asked 15, proposed 13, accepted 13, rejected 0; `ai_runs/2026-11-14_write_mutants_3` |
| 2 | 2026-11-14 14:41 | 664452d | AI wrote mutants (claude-fable-5-2) | asked 15, proposed 10, accepted 10, rejected 0; `ai_runs/2026-11-14_write_mutants_4` |
| 3 | 2026-11-26 21:26 | 219c651 | AI wrote mutants (claude-opus-5-5) | asked 10, proposed 3, accepted 3, rejected 0; `ai_runs/2026-11-26_write_mutants` |
| 4 | 2026-11-26 21:37 | 219c651 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 14, accepted 13, rejected 1; `ai_runs/2026-11-26_write_mutants_2` |
| 5 | 2026-11-26 22:03 | 219c651 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 9, accepted 9, rejected 0; `ai_runs/2026-11-26_write_mutants_3` |
| 6 | 2026-11-26 22:30 | 219c651 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 13, accepted 13, rejected 0; `ai_runs/2026-11-26_write_mutants_4` |
| 7 | 2026-11-27 08:28 | 8d82e7e | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 11, accepted 11, rejected 0; `ai_runs/2026-11-27_write_mutants` |
| 8 | 2026-11-27 08:33 | 8d82e7e | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 11, accepted 10, rejected 1; `ai_runs/2026-11-27_write_mutants_2` |
| 9 | 2026-11-27 08:38 | 8d82e7e | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 6, accepted 6, rejected 0; `ai_runs/2026-11-27_write_mutants_3` |
| 10 | 2026-11-27 08:44 | 8d82e7e | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 8, accepted 8, rejected 0; `ai_runs/2026-11-27_write_mutants_4` |
| 11 | 2026-11-27 08:50 | 8d82e7e | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 9, accepted 9, rejected 0; `ai_runs/2026-11-27_write_mutants_5` |
| 12 | 2026-11-27 08:56 | 8d82e7e | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 8, accepted 8, rejected 0; `ai_runs/2026-11-27_write_mutants_6` |
| 13 | 2026-11-27 09:01 | 8d82e7e | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 5, accepted 5, rejected 0; `ai_runs/2026-11-27_write_mutants_7` |
| 14 | 2026-11-27 09:04 | 8d82e7e | designer withdrew AI-written mutants | fault_cause.165.AIM.74 - equivalent: fault_reg and fault_time are set on the same clock (episode_start is the accumulator's first capture) and cleared on the same read, so an empty fault_reg always has fault_time 0 and skipping its clear changes nothing |
| 15 | 2026-11-27 09:04 | 8d82e7e | designer withdrew AI-written mutants | fault_cause.82.AIM.29, fault_cause.82.AIM.79, fault_cause.82.AIM.80, fault_cause.82.AIM.81, fault_cause.82.AIM.85, fault_cause.84.AIM.97, fault_cause.83.AIM.98 - another relabelling of the cause bit map; the adjacent swaps AIM.36, AIM.38, AIM.47 and AIM.49 already move every cause, and any test that checks each cause on its own bit kills them all |
| 16 | 2026-11-27 09:08 | 8d82e7e | mutation run - every mutant of the module | 246 mutants: 186 killed, 22 lint, 38 survived; score 84.6% |
| 17 | 2026-11-27 09:08 | 8d82e7e | AI judged survivors (claude-opus-5-5) | 38 judged, 0 called equivalent with high confidence; `ai_runs/2026-11-27_judge_survivors` |
| 18 | 2026-11-27 09:09 | 8d82e7e | designer's decision: gap | fault_cause.118.AIM.15, fault_cause.118.AIM.57, fault_cause.118.AIM.90, fault_cause.205.AIM.115, fault_cause.205.AIM.46, fault_cause.206.AIM.10, fault_cause.206.AIM.63, fault_cause.206.AIM.76, fault_cause.206.AIM.93, fault_cause.207.AIM.62, fault_cause.207.AIM.94 - no test raises two causes on the same clock: each cause is recorded alone, so a cause masked by another live cause goes unseen; needs simultaneous pairs of causes with every bit checked |
| 19 | 2026-11-27 09:09 | 8d82e7e | designer's decision: gap | fault_cause.118.AIM.60, fault_cause.205.AIM.87, fault_cause.206.AIM.18 - no test adds a cause after another is already recorded in the orders that matter (UVLO second, a lower-priority cause after a higher one, OVP after any cause); needs causes arriving in several orders, each checked to be added |
| 20 | 2026-11-27 09:09 | 8d82e7e | designer's decision: gap | fault_cause.205.AIM.56, fault_cause.206.AIM.7, fault_cause.208.AIM.37, fault_cause.139.AIM.100, fault_cause.138.AIM.70 - no cause is raised during soft start: OTP, UVLO and OVP captured in S_SS, the episode stamp from S_SS and a second cause in S_SS are untested; needs causes in S_SS with fault_reg and fault_time checked |
| 21 | 2026-11-27 09:09 | 8d82e7e | designer's decision: gap | fault_cause.104.AIM.108, fault_cause.203.AIM.40, fault_cause.211.AIM.52, fault_cause.211.AIM.67, fault_cause.138.AIM.73, fault_cause.211.AIM.104 - nothing is raised while the converter is stopped: the header says a fault asserting while stopped is not captured and the record holds until read, but no test raises latch_state, latch_assert or OTP (or lets OTP clear) with the converter stopped and checks fault_reg and fault_time stay as they were |
| 22 | 2026-11-27 09:09 | 8d82e7e | designer's decision: gap | fault_cause.165.AIM.2, fault_cause.165.AIM.96, fault_cause.197.AIM.61, fault_cause.197.AIM.83 - host reads are only tested while running with causes gone: a read on the clock the first cause is captured, a read while stopped, and a read of an empty record with a cause live are untested |
| 23 | 2026-11-27 09:09 | 8d82e7e | designer's decision: gap | fault_cause.138.AIM.17, fault_cause.206.AIM.95 - an episode opened by OVP alone and a UVLO record surviving a later soft start are untested; needs an OVP-only record followed by a second cause (fault_time held), and a restart after a recorded UVLO |
| 24 | 2026-11-27 09:09 | 8d82e7e | designer's decision: accepted | fault_cause.138.AIM.4 - differs only for an episode stamped while timestamp_ms is 0: the 24-bit ms counter is 0 for 1 ms after reset (the converter cannot be running yet) and for 1 ms every 4.66 h after it wraps |
| 25 | 2026-11-27 09:09 | 8d82e7e | designer's decision: accepted | fault_cause.104.AIM.86 - widens the capture gate by one clock (100 ns) after the converter stops; only a cause rising on exactly that clock differs, and the stopping cause was already captured on the clock before |
| 26 | 2026-11-27 09:09 | 8d82e7e | designer's decision: accepted | fault_cause.209.AIM.34, fault_cause.209.AIM.16, fault_cause.209.AIM.53, fault_cause.209.AIM.77, fault_cause.138.AIM.84 - need latch_assert high while the converter runs, which never happens on the chip: strike_counter raises latch_assert on hiccup entry, after S_RUN has been left, and the supervisor then never restarts while it is high (top-level soak: c_capture_latch never hit). The LATCH_ASSERT bit is therefore never set on the chip - a design note, see the finding |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (118)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | priority | On a host read, capture wins over clear: fault_reg is loaded with the causes live on that clock instead of being emptied | killed | a_read_clears |
| 2 | 1 | priority | fault_time capture takes priority over its clear-on-read, the opposite of fault_reg | survived |  |
| 3 | 1 | sequencing | Episode start is detected from fault_reg having gone non-empty rather than from the capture conditions, so fault_time is latched one clock after the first cause | killed | a_time_at_episode_start, a_time_moves_by_known_path |
| 4 | 1 | boundary | The episode is judged empty by fault_time being zero instead of fault_reg being zero | survived |  |
| 5 | 1 | field | OVP is inferred against the recorded LATCH bit instead of the live latch_assert | killed | a_capture_while_running |
| 6 | 1 | missing_case | Over-temperature bypasses the capture gate: with otp_state high, causes are recorded even while the converter is stopped | killed | a_hold_when_stopped, a_time_at_episode_start |
| 7 | 1 | missing_case | UVLO is recorded only in S_RUN; a UVLO that interrupts soft start is forgotten | survived |  |
| 8 | 1 | reset_init | The clear-on-read leaves the OVP bit set; only the four lower cause bits are cleared | killed | a_read_clears |
| 9 | 1 | reset_init | A host read clears only the recorded causes that have gone away; a recorded cause still asserted survives the read, even with the converter stopped | killed | a_read_clears |
| 10 | 1 | priority | Causes are captured through a priority chain, one per clock, instead of independently accumulated | survived |  |
| 11 | 1 | wrong_event | The OVERCURRENT bit follows the live window trips while running instead of being set and held | killed | a_capture_while_running |
| 12 | 1 | wrong_event | A host read clears fault_reg only when the converter is stopped; a read during S_SS or S_RUN does not clear it | killed | a_read_clears |
| 13 | 1 | field | latch_assert also sets the OVERCURRENT bit, on the assumption that every CPLD latch trip is an overcurrent | killed | a_capture_while_running |
| 14 | 2 | missing_case | The episode start is detected only in S_RUN: a first cause captured during soft start does not latch fault_time | killed | a_time_at_episode_start |
| 15 | 2 | missing_case | OVP inference is suppressed while an overcurrent window trip is live, on the assumption that the latch trip then belongs to the overcurrent | survived |  |
| 16 | 2 | field | Recording LATCH_ASSERT withdraws an already recorded OVP bit, treating the two latch origins as mutually exclusive in the record | survived |  |
| 17 | 2 | boundary | The record is judged empty from the four lower cause bits only; a recorded OVP does not count as an open episode | survived |  |
| 18 | 2 | wrong_event | UVLO is recorded only as the first cause of an episode; a UVLO that follows another recorded cause is treated as a consequence and dropped | survived |  |
| 19 | 2 | sequencing | LATCH_ASSERT is recorded only once the debounced SCR readback confirms it, not when the CPLD asserts the trip | killed | a_capture_while_running |
| 20 | 2 | reset_init | fault_time is cleared by a host read only when the converter is stopped; a read during S_SS or S_RUN clears fault_reg but leaves the old start time | killed | a_read_clears |
| 21 | 2 | field | The three bytes of timestamp_ms are latched into fault_time in reversed order | killed | a_time_at_episode_start, a_time_moves_by_known_path |
| 22 | 2 | reset_init | fault_time is cleared when the converter stops, instead of being held until the host reads the record | killed | a_time_moves_by_known_path |
| 23 | 2 | other | OVP is inferred from any disagreement between latch_state and latch_assert, not only from the latch set without the CPLD's trip | killed | a_capture_while_running |
| 24 | 3 | wrong_event | fault_time is re-latched every time a cause not yet in the record is captured, so it holds the time of the most recent new cause instead of the start of the episode | killed | a_time_moves_by_known_path |
| 25 | 3 | missing_case | The capture gate only scopes the start of an episode: once fault_reg holds a cause, further causes are added even after the converter has stopped | killed | a_hold_when_stopped |
| 26 | 3 | missing_case | Episode start leaves out the overcurrent window trips, on the assumption that an overcurrent episode only starts when latch_assert trips, so the accumulator and the episode detector disagree | killed | a_time_at_episode_start |
| 27 | 4 | wrong_event | fault_time records when the converter stopped with a non-empty record (the shutdown) instead of when the first cause of the episode was captured | killed | a_time_at_episode_start, a_time_moves_by_known_path |
| 28 | 4 | wrong_event | A host read stamps fault_time with the read time instead of clearing it, so an empty record reports when it was last read | killed | a_read_clears, a_time_moves_by_known_path |
| 29 | 4 | field | Cause bit positions laid out LSB-first (OVP in bit 0, OVERCURRENT in bit 4), with the priority order misremembered as LSB highest | withdrawn: another relabelling of the cause bit map; the adjacent swaps AIM.36, AIM.38, AIM.47 and AIM.49 already move every cause, and any test that checks each cause on its own bit kills them all |  |
| 30 | 4 | reset_init | fault_reg is cleared when the converter stops, like the supervisor's window state, instead of being held until the host reads it | killed | a_hold_when_stopped |
| 31 | 4 | other | While running, any live cause overwrites the record with a snapshot of the currently live causes instead of OR-accumulating into it | killed | a_capture_while_running |
| 32 | 4 | missing_case | The accumulator's capture gate is S_RUN only, while episode_start still uses convertor_running (S_SS or S_RUN), so the two blocks no longer agree during soft start | killed | a_capture_while_running |
| 33 | 4 | missing_case | OVERCURRENT is recorded only when the window trip has already led to a CPLD latch trip, as if an overcurrent only counts once strikes reach the trip | killed | a_capture_while_running |
| 34 | 4 | missing_case | LATCH_ASSERT is recorded only in S_RUN, on the assumption that the CPLD trips the latch only from run-time strikes, so a latch trip during soft start is forgotten | survived |  |
| 35 | 4 | field | A soft-start overcurrent window trip is filed under the LATCH_ASSERT (OCP/SCP) bit instead of the OVERCURRENT bit | killed | a_capture_while_running |
| 36 | 4 | field | The OTP and UVLO cause bits are laid out in swapped positions, with the priority order between them misremembered | killed | a_capture_while_running |
| 37 | 4 | missing_case | OVP is recorded only in S_RUN, on the assumption that overvoltage can only occur once the output is regulated, so an OVP overshoot during soft start is not recorded | survived |  |
| 38 | 4 | field | The OVP and LATCH_ASSERT cause bits are laid out in swapped positions, with the CPLD's measured trip misremembered as outranking the inferred OVP | killed | a_capture_while_running |
| 39 | 4 | other | OVP is inferred with the two latch signals confused: CPLD trip asserted while the SCR readback is still clear, instead of readback set without a CPLD trip | killed | a_capture_while_running |
| 40 | 5 | missing_case | The capture gate is held open while the CPLD's latch trip is asserted, so the trip that stops the converter is sure to be seen. Because latch_assert is held until reset, the gate never closes after a latch trip. | survived |  |
| 41 | 5 | reset_init | A host read clears fault_time only when no cause is live. The episode is treated as still open while any cause persists, so its start time survives the read even though fault_reg is cleared. | killed | a_read_clears |
| 42 | 5 | missing_case | The LATCH_ASSERT bit is set whenever the protection latch reads back set, so an analog OVP trip is recorded as both OVP and LATCH_ASSERT (OCP/SCP) | killed | a_capture_while_running |
| 43 | 5 | wrong_event | OVP is inferred as a latch trip with no recorded overcurrent, as if every CPLD trip is shown by a recorded window trip, instead of a latch trip without the CPLD's latch_assert | killed | a_capture_while_running |
| 44 | 5 | wrong_event | fault_time is re-latched whenever a live cause outranks every cause already recorded, so it gives the time of the highest-priority cause instead of the start of the episode | killed | a_time_moves_by_known_path |
| 45 | 5 | reset_init | fault_reg is cleared all through soft start, as if each restart began a new record, as well as on a host read | killed | a_capture_while_running |
| 46 | 5 | priority | OTP is recorded only when UVLO is not live, as if a brown-out made the OTP reading unreliable and UVLO took precedence | survived |  |
| 47 | 5 | field | The UVLO and OVERCURRENT cause bits are laid out in swapped positions, so overcurrent is ranked above UVLO | killed | a_capture_while_running |
| 48 | 5 | sequencing | fault_time is cleared when it sees the record empty, instead of on the host-read pulse itself, so it is cleared one clock after fault_reg | killed | a_read_clears, a_time_moves_by_known_path |
| 49 | 6 | field | The LATCH_ASSERT and OTP cause bits are laid out in swapped positions, so OTP is ranked above the CPLD's latch trip | killed | a_capture_while_running |
| 50 | 6 | missing_case | The capture gate closes as soon as the protection latch reads back set, treating a set latch as a converter that has already stopped | killed | a_capture_while_running |
| 51 | 6 | other | The OVP bit is recorded from the raw latch readback instead of the inferred ovp, so every CPLD-originated latch trip is also recorded as OVP | killed | a_capture_while_running |
| 52 | 6 | missing_case | OVP is recorded even while the converter is stopped, on the assumption that the analog comparator can trip the latch at any time and should always be logged | survived |  |
| 53 | 6 | other | Recording the LATCH_ASSERT (OCP/SCP) trip withdraws the OVERCURRENT bit, on the assumption that the latch bit already covers the window trips that led to it | survived |  |
| 54 | 6 | other | The capture gate is closed whenever UVLO is live, so every UVLO is treated as a routine power-down rather than only the ones that come after the converter has stopped | killed | a_capture_while_running |
| 55 | 6 | missing_case | UVLO is recorded only during soft start, on the belief that a UVLO in S_RUN is the routine power-down the capture gate is there to ignore | killed | a_capture_while_running |
| 56 | 6 | missing_case | OTP is recorded only in S_RUN, on the assumption that the board can only overheat under regulated load current, so an over-temperature during soft start is forgotten | survived |  |
| 57 | 6 | other | OVP inference is suppressed while UVLO is live, on the assumption that the SCR readback is not trustworthy during a brown-out | survived |  |
| 58 | 6 | missing_case | The capture gate is held open while UVLO is asserted, so the brown-out that stops the converter is sure to be recorded. The side effect is that every routine power-down is logged as a UVLO episode. | killed | a_hold_when_stopped, a_time_moves_by_known_path |
| 59 | 6 | reset_init | fault_time is cleared all through soft start, as if each restart opened a new episode, while fault_reg keeps its record until the host reads it | killed | a_time_at_episode_start |
| 60 | 6 | missing_case | OVP is inferred only into an empty record, on the belief that an analog latch trip after any other recorded cause must be a consequence of that cause | survived |  |
| 61 | 6 | wrong_event | A host read clears fault_reg only while the converter is running, so the cause of a shutdown cannot be read away until the converter restarts | survived |  |
| 62 | 7 | missing_case | The OVERCURRENT bit is not recorded while an OVP is inferred, on the belief that a window trip during an analog overvoltage is only a consequence of the overshoot | survived |  |
| 63 | 7 | missing_case | UVLO is not recorded while the protection latch reads back set, on the belief that an input droop after a latch trip is caused by the trip | survived |  |
| 64 | 7 | missing_case | The capture gate is closed during a soft-start overcurrent window trip, treating a soft-start hiccup retry as routine rather than as a fault that interrupted operation | killed | a_capture_while_running |
| 65 | 7 | wrong_event | A host read is ignored by fault_reg while any cause is still live, as if a fault still asserted kept the whole record open, instead of always clearing and letting live causes re-set their own bits | killed | a_read_clears |
| 66 | 7 | wrong_event | An episode is treated as over once none of its recorded causes is still live, so a new cause after a quiet interval re-stamps fault_time instead of merging into the earlier episode as the header specifies | killed | a_time_moves_by_known_path |
| 67 | 7 | missing_case | The LATCH_ASSERT bit bypasses the capture gate on the assumption that the CPLD's latch trip is always worth logging. It is recorded even while the converter is stopped, unlike every other cause. | survived |  |
| 68 | 7 | missing_case | Episode start leaves out the latch causes (inferred OVP and latch_assert), on the belief that a latch trip always follows a window trip that has already opened the episode | killed | a_time_at_episode_start |
| 69 | 7 | missing_case | Episode start leaves out the environmental causes (OTP and UVLO), as if only faults the converter itself causes could open an episode | killed | a_time_at_episode_start |
| 70 | 7 | wrong_event | Each soft-start retry is treated as a new episode: a cause captured during S_SS re-stamps fault_time even when the record already holds causes | survived |  |
| 71 | 7 | wrong_event | fault_time follows timestamp_ms whenever the record is empty and freezes once the first cause is captured, instead of being latched only at episode start | killed | a_time_moves_by_known_path |
| 72 | 7 | reset_init | The LATCH_ASSERT bit survives a host read and is made sticky until reset, like the CPLD's latch_assert, instead of being cleared with the rest of the record | killed | a_read_clears |
| 73 | 8 | missing_case | Episode start lets the latch causes (inferred OVP and latch_assert) bypass the capture gate, on the belief that a latch trip always marks an episode, while the accumulator still gates them, so the two blocks disagree once the converter has stopped | survived |  |
| 74 | 8 | wrong_event | fault_time is cleared by a host read only when the record is non-empty, on the belief that an empty record has no start time to clear | withdrawn: equivalent: fault_reg and fault_time are set on the same clock (episode_start is the accumulator's first capture) and cleared on the same read, so an empty fault_reg always has fault_time 0 and skipping its clear changes nothing |  |
| 75 | 8 | field | While the converter runs, the OTP bit follows the live comparator instead of being set and held | killed | a_capture_while_running |
| 76 | 8 | missing_case | UVLO is not recorded while an overcurrent window trip is live, on the belief that an input droop under overcurrent is caused by the load current | survived |  |
| 77 | 8 | missing_case | LATCH_ASSERT is not recorded once OVERCURRENT is in the record, on the belief that the window trip already explains the CPLD's latch trip | survived |  |
| 78 | 8 | wrong_event | fault_time stamps the converter's soft start, read as the start of an operating episode, instead of the capture of the first fault cause | killed | a_time_at_episode_start, a_time_moves_by_known_path |
| 79 | 8 | field | Over-voltage and over-current are confused in the bit map: OVP is placed in bit 0 and OVERCURRENT in bit 4 | withdrawn: another relabelling of the cause bit map; the adjacent swaps AIM.36, AIM.38, AIM.47 and AIM.49 already move every cause, and any test that checks each cause on its own bit kills them all |  |
| 80 | 8 | field | The two overcurrent-related causes are confused in the bit map: LATCH_ASSERT (OCP/SCP) is placed in bit 0 and the window-trip OVERCURRENT in bit 3 | withdrawn: another relabelling of the cause bit map; the adjacent swaps AIM.36, AIM.38, AIM.47 and AIM.49 already move every cause, and any test that checks each cause on its own bit kills them all |  |
| 81 | 8 | field | Over-voltage and under-voltage are confused in the bit map: OVP is placed in bit 1 and UVLO in bit 4 | withdrawn: another relabelling of the cause bit map; the adjacent swaps AIM.36, AIM.38, AIM.47 and AIM.49 already move every cause, and any test that checks each cause on its own bit kills them all |  |
| 82 | 8 | missing_case | When deciding whether the record is empty, the episode detector ignores the OVERCURRENT bit, as if a recorded soft-start hiccup were routine and did not open an episode | killed | a_time_moves_by_known_path |
| 83 | 9 | priority | A host read clears fault_reg only when the record is non-empty, on the belief that an empty record has nothing to clear, so a cause live on the read clock is captured through the read instead of losing to the clear | survived |  |
| 84 | 9 | missing_case | When deciding whether the record is empty, the episode detector ignores the LATCH_ASSERT bit, as if the sticky CPLD trip were background state rather than an open episode | survived |  |
| 85 | 9 | field | OVP and OTP, acronyms one letter apart, are swapped in the bit map: over-temperature is reported in bit 4 and the inferred overvoltage in bit 2 | withdrawn: another relabelling of the cause bit map; the adjacent swaps AIM.36, AIM.38, AIM.47 and AIM.49 already move every cause, and any test that checks each cause on its own bit kills them all |  |
| 86 | 9 | sequencing | The capture gate is held open one clock after the converter stops, so the trip that stopped it is sure to be seen, but it also captures a cause that only appears after the stop | survived |  |
| 87 | 9 | priority | The bit-position priority is applied to recording: once a higher-priority cause is recorded, every lower-priority cause is dropped as its consequence, instead of all causes being OR-accumulated | survived |  |
| 88 | 9 | missing_case | UVLO bypasses the capture gate and is recorded even while the converter is stopped, on the belief that the debounced UVLO always arrives after the supervisor has already stopped the converter | killed | a_hold_when_stopped, a_time_at_episode_start |
| 89 | 10 | missing_case | When deciding whether the record is empty, the episode detector ignores the UVLO bit, as if a recorded UVLO were the routine power-down the capture gate is there to ignore and did not open an episode | killed | a_time_moves_by_known_path |
| 90 | 10 | other | OVP inference is suppressed while OTP is live, as if the over-temperature comparator were a third trip source of the shared protection latch | survived |  |
| 91 | 10 | missing_case | OTP is not recorded once OVERCURRENT is in the record, on the belief that an over-temperature after an overcurrent is only the heating the overcurrent caused | killed | a_capture_while_running |
| 92 | 10 | missing_case | When deciding whether the record is empty, the episode detector ignores the OTP bit, as if a self-clearing over-temperature that has cooled off did not hold an episode open | killed | a_time_moves_by_known_path |
| 93 | 10 | priority | UVLO is not recorded while OTP is live, as if over-temperature outranked and explained a simultaneous input brown-out | survived |  |
| 94 | 10 | missing_case | The OVERCURRENT bit is not recorded while UVLO is live, on the belief that a window trip during a brown-out is only the input-current surge the droop causes | survived |  |
| 95 | 10 | reset_init | The UVLO bit is withdrawn during soft start once Vin is back. A restart after a recovered brown-out is taken to mean the UVLO was a routine power cycle and not a fault. | survived |  |
| 96 | 10 | wrong_event | A host read clears fault_time only while the converter is in S_SS or S_RUN. A read after a shutdown clears fault_reg but leaves the old episode start time. | survived |  |
| 97 | 11 | field | Over-temperature (OT) and over-current (OC) are confused in the bit map: OTP is placed in bit 0 and OVERCURRENT in bit 2 | withdrawn: another relabelling of the cause bit map; the adjacent swaps AIM.36, AIM.38, AIM.47 and AIM.49 already move every cause, and any test that checks each cause on its own bit kills them all |  |
| 98 | 11 | field | The two lock-type causes are confused in the bit map: the CPLD latch trip (LATCH_ASSERT) is placed in bit 1 and under-voltage lockout (UVLO) in bit 3 | withdrawn: another relabelling of the cause bit map; the adjacent swaps AIM.36, AIM.38, AIM.47 and AIM.49 already move every cause, and any test that checks each cause on its own bit kills them all |  |
| 99 | 11 | priority | A host read acknowledges only the highest-priority recorded cause and leaves the lower-priority causes in the record, instead of clearing the whole record | killed | a_read_clears |
| 100 | 11 | missing_case | UVLO opens an episode only in S_RUN: a Vin dip during soft start is treated as inrush sag and does not stamp fault_time, although the accumulator still records it | survived |  |
| 101 | 11 | missing_case | The capture gate is held open while the over-temperature comparator is asserted, so that an OTP the supervisor stops on is sure to be recorded. The gate then stays open after the stop for as long as the board stays hot. | killed | a_hold_when_stopped, a_time_moves_by_known_path |
| 102 | 11 | reset_init | A host read leaves the UVLO bit in place, as if it were a sticky brown-out status flag that only rst_n clears, while every other cause bit is cleared. | killed | a_read_clears |
| 103 | 11 | reset_init | The OVERCURRENT bit is cleared whenever the converter is stopped, copying the fault_arbiter window's reset on leaving S_RUN/S_SS into the record, so an overcurrent that stopped the converter is gone from the record | killed | a_hold_when_stopped |
| 104 | 11 | reset_init | Once the converter has stopped, the OTP bit is withdrawn as soon as the board cools, as if a self-clearing over-temperature should clear its own record before the next start | survived |  |
| 105 | 11 | reset_init | A host read leaves the OTP bit in place, treating it as a latched thermal-shutdown flag that only rst_n clears, while every other cause bit is cleared | killed | a_read_clears |
| 106 | 12 | missing_case | The capture gate closes as soon as the CPLD asserts latch_assert, treating the CPLD's own trip into the latch as a converter that has already stopped | killed | a_capture_while_running |
| 107 | 12 | reset_init | A host read leaves the OVERCURRENT bit in place, treating the window-trip record like the strike history that only a long clean run or rst_n clears, while every other cause bit is cleared | killed | a_read_clears |
| 108 | 12 | missing_case | The capture gate is held open while the protection latch reads back set, so that the analog OVP trip that stops the converter is sure to be recorded | survived |  |
| 109 | 12 | sequencing | fault_reg is cleared when it sees fault_time already cleared and the record non-empty, so its clear follows the read pulse through fault_time instead of using the pulse itself | killed | a_read_clears, a_capture_while_running |
| 110 | 12 | wrong_event | Causes are recorded only on the clock the episode opens. A cause that appears later in the same episode is never added to fault_reg. | killed | a_capture_while_running |
| 111 | 12 | field | While the converter runs, the UVLO bit follows the live debounced UVLO instead of being set and held | killed | a_capture_while_running |
| 112 | 12 | other | The over-temperature and over-voltage trips are confused: an inferred analog OVP trip is also recorded as OTP | killed | a_capture_while_running |
| 113 | 12 | missing_case | Every S_RUN window trip is also recorded as LATCH_ASSERT (OCP/SCP), as if each window trip were an OCP trip into the latch | killed | a_capture_while_running |
| 114 | 13 | missing_case | Each overcurrent window trip is qualified with the other trip's supervisor state: the S_RUN window_trip is accepted only during soft start and window_trip_SS only in S_RUN | killed | a_capture_while_running |
| 115 | 13 | missing_case | OTP is not recorded while the protection latch reads back set, on the belief that a latched converter is no longer heating the board, so any over-temperature then is not part of the fault | survived |  |
| 116 | 13 | missing_case | OVP is recorded only during soft start, on the belief that an analog overvoltage can only be the overshoot at the end of the soft-start ramp, so an OVP trip in S_RUN (a load dump, say) is not recorded | killed | a_capture_while_running |
| 117 | 13 | field | A host read clears only the top byte of fault_time (FTIME_2, the byte whose read raises the pulse), so the two low bytes keep the old episode start time | killed | a_read_clears |
| 118 | 13 | missing_case | Episode start is detected only during soft start, as if every fault episode began with a failed start-up, so a first cause captured in S_RUN does not stamp fault_time | killed | a_time_at_episode_start |

Rejected by the gate in step 4 (1):

- The episode-start detector uses the debounced SCR readback latch_state where the accumulator uses the CPLD's latch_assert, so a CPLD trip opens no episode until the readback follows - **the same edit as fault_cause.139.SIB.5**

Rejected by the gate in step 8 (1):

- The episode start time is latched from the two low bytes of timestamp_ms only, as if the counter were 16 bits wide, so the top byte of fault_time is always zero - **make lint already catches it: make lint: UNUSEDSIGNAL**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `fault_cause.82.AIM.38` | The OVP and LATCH_ASSERT cause bits are laid out in swapped positions, with the CPLD's measured trip misremembered as outranking the inferred OVP | 16:killed | a_capture_while_running |
| `fault_cause.82.CST.1` | localparam BIT_OVP: 4 -> 3 | 16:killed | a_capture_while_running |
| `fault_cause.82.CST.2` | localparam BIT_OVP: 4 -> 5 | 16:lint | make lint: SELRANGE |
| `fault_cause.83.AIM.49` | The LATCH_ASSERT and OTP cause bits are laid out in swapped positions, so OTP is ranked above the CPLD's latch trip | 16:killed | a_capture_while_running |
| `fault_cause.83.CST.1` | localparam BIT_LATCH: 3 -> 2 | 16:killed | a_capture_while_running |
| `fault_cause.83.CST.2` | localparam BIT_LATCH: 3 -> 4 | 16:killed | a_capture_while_running |
| `fault_cause.84.AIM.36` | The OTP and UVLO cause bits are laid out in swapped positions, with the priority order between them misremembered | 16:killed | a_capture_while_running |
| `fault_cause.84.CST.1` | localparam BIT_OTP: 2 -> 1 | 16:killed | a_capture_while_running |
| `fault_cause.84.CST.2` | localparam BIT_OTP: 2 -> 3 | 16:killed | a_capture_while_running |
| `fault_cause.85.AIM.47` | The UVLO and OVERCURRENT cause bits are laid out in swapped positions, so overcurrent is ranked above UVLO | 16:killed | a_capture_while_running |
| `fault_cause.85.CST.1` | localparam BIT_UVLO: 1 -> 0 | 16:killed | a_capture_while_running |
| `fault_cause.85.CST.2` | localparam BIT_UVLO: 1 -> 2 | 16:killed | a_capture_while_running |
| `fault_cause.86.CST.1` | localparam BIT_OC: 0 -> 1 | 16:killed | a_capture_while_running |
| `fault_cause.104.AIM.101` | The capture gate is held open while the over-temperature comparator is asserted, so that an OTP the supervisor stops on is sure to be recorded. The gate then stays open after the stop for as long as the board stays hot. | 16:killed | a_hold_when_stopped, a_time_moves_by_known_path |
| `fault_cause.104.AIM.106` | The capture gate closes as soon as the CPLD asserts latch_assert, treating the CPLD's own trip into the latch as a converter that has already stopped | 16:killed | a_capture_while_running |
| `fault_cause.104.AIM.108` | The capture gate is held open while the protection latch reads back set, so that the analog OVP trip that stops the converter is sure to be recorded | 16:survived |  |
| `fault_cause.104.AIM.54` | The capture gate is closed whenever UVLO is live, so every UVLO is treated as a routine power-down rather than only the ones that come after the converter has stopped | 16:killed | a_capture_while_running |
| `fault_cause.104.AIM.58` | The capture gate is held open while UVLO is asserted, so the brown-out that stops the converter is sure to be recorded. The side effect is that every routine power-down is logged as a UVLO episode. | 16:killed | a_hold_when_stopped, a_time_moves_by_known_path |
| `fault_cause.104.AIM.64` | The capture gate is closed during a soft-start overcurrent window trip, treating a soft-start hiccup retry as routine rather than as a fault that interrupted operation | 16:killed | a_capture_while_running |
| `fault_cause.104.AIM.86` | The capture gate is held open one clock after the converter stops, so the trip that stopped it is sure to be seen, but it also captures a cause that only appears after the stop | 16:survived |  |
| `fault_cause.104.CTD.1` | drop the term 'ss_active' | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.104.CTD.2` | drop the term 'run_active' | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.104.CTN.1` | negate the term 'ss_active' | 16:killed | a_hold_when_stopped, a_time_moves_by_known_path +1 |
| `fault_cause.104.CTN.2` | negate the term 'run_active' | 16:killed | a_hold_when_stopped, a_time_moves_by_known_path +1 |
| `fault_cause.104.LCR.1` | \|\| -> && | 16:killed | a_capture_while_running |
| `fault_cause.104.SDL.1` | delete 'convertor_running = (ss_active\|\|run_active);' | 16:lint | make lint: UNDRIVEN, UNUSEDSIGNAL |
| `fault_cause.104.SIB.1` | ss_active -> run_active | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.104.SIB.2` | run_active -> ss_active | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.104.STK.1` | convertor_running stuck at all-zeros (was '(ss_active\|\|run_active)') | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.104.STK.2` | convertor_running stuck at all-ones (was '(ss_active\|\|run_active)') | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.104.VNG.1` | convertor_running inverted (was '(ss_active\|\|run_active)') | 16:killed | a_hold_when_stopped, a_time_moves_by_known_path +1 |
| `fault_cause.118.AIM.15` | OVP inference is suppressed while an overcurrent window trip is live, on the assumption that the latch trip then belongs to the overcurrent | 16:survived |  |
| `fault_cause.118.AIM.23` | OVP is inferred from any disagreement between latch_state and latch_assert, not only from the latch set without the CPLD's trip | 16:killed | a_capture_while_running |
| `fault_cause.118.AIM.39` | OVP is inferred with the two latch signals confused: CPLD trip asserted while the SCR readback is still clear, instead of readback set without a CPLD trip | 16:killed | a_capture_while_running |
| `fault_cause.118.AIM.43` | OVP is inferred as a latch trip with no recorded overcurrent, as if every CPLD trip is shown by a recorded window trip, instead of a latch trip without the CPLD's latch_assert | 16:killed | a_capture_while_running |
| `fault_cause.118.AIM.5` | OVP is inferred against the recorded LATCH bit instead of the live latch_assert | 16:killed | a_capture_while_running |
| `fault_cause.118.AIM.57` | OVP inference is suppressed while UVLO is live, on the assumption that the SCR readback is not trustworthy during a brown-out | 16:survived |  |
| `fault_cause.118.AIM.60` | OVP is inferred only into an empty record, on the belief that an analog latch trip after any other recorded cause must be a consequence of that cause | 16:survived |  |
| `fault_cause.118.AIM.90` | OVP inference is suppressed while OTP is live, as if the over-temperature comparator were a third trip source of the shared protection latch | 16:survived |  |
| `fault_cause.118.CND.1` | if (latch_state & ~latch_assert) -> if (!(...)) | 16:killed | a_capture_while_running, a_time_moves_by_known_path |
| `fault_cause.118.CSK.1` | if (latch_state & ~latch_assert) -> if (1'b0): never taken | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.118.CSK.2` | if (latch_state & ~latch_assert) -> if (1'b1): always taken | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.118.CST.1` | 1'b1 -> 1'b0 | 16:killed | a_capture_while_running |
| `fault_cause.118.CTD.1` | drop the term 'latch_state' | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.118.CTD.2` | drop the term '~latch_assert' | 16:killed | a_capture_while_running |
| `fault_cause.118.CTN.1` | negate the term 'latch_state' | 16:killed | a_capture_while_running, a_time_moves_by_known_path |
| `fault_cause.118.LCR.1` | & -> \| | 16:killed | a_capture_while_running, a_time_moves_by_known_path |
| `fault_cause.118.SDL.1` | delete 'ovp = 1'b1;' | 16:lint | make lint: LATCH |
| `fault_cause.118.SIB.1` | latch_state -> otp_state | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.118.SIB.2` | latch_state -> uvlo_state | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.118.SIB.3` | latch_assert -> latch_state | 16:killed | a_capture_while_running |
| `fault_cause.118.UOD.1` | drop the '~' before latch_assert | 16:killed | a_capture_while_running |
| `fault_cause.119.CST.1` | 1'b0 -> 1'b1 | 16:killed | a_capture_while_running, a_time_moves_by_known_path |
| `fault_cause.119.SDL.1` | delete 'ovp = 1'b0;' | 16:lint | make lint: LATCH |
| `fault_cause.138.AIM.118` | Episode start is detected only during soft start, as if every fault episode began with a failed start-up, so a first cause captured in S_RUN does not stamp fault_time | 16:killed | a_time_at_episode_start |
| `fault_cause.138.AIM.14` | The episode start is detected only in S_RUN: a first cause captured during soft start does not latch fault_time | 16:killed | a_time_at_episode_start |
| `fault_cause.138.AIM.17` | The record is judged empty from the four lower cause bits only; a recorded OVP does not count as an open episode | 16:survived |  |
| `fault_cause.138.AIM.24` | fault_time is re-latched every time a cause not yet in the record is captured, so it holds the time of the most recent new cause instead of the start of the episode | 16:killed | a_time_moves_by_known_path |
| `fault_cause.138.AIM.27` | fault_time records when the converter stopped with a non-empty record (the shutdown) instead of when the first cause of the episode was captured | 16:killed | a_time_at_episode_start, a_time_moves_by_known_path |
| `fault_cause.138.AIM.3` | Episode start is detected from fault_reg having gone non-empty rather than from the capture conditions, so fault_time is latched one clock after the first cause | 16:killed | a_time_at_episode_start, a_time_moves_by_known_path |
| `fault_cause.138.AIM.4` | The episode is judged empty by fault_time being zero instead of fault_reg being zero | 16:survived |  |
| `fault_cause.138.AIM.44` | fault_time is re-latched whenever a live cause outranks every cause already recorded, so it gives the time of the highest-priority cause instead of the start of the episode | 16:killed | a_time_moves_by_known_path |
| `fault_cause.138.AIM.66` | An episode is treated as over once none of its recorded causes is still live, so a new cause after a quiet interval re-stamps fault_time instead of merging into the earlier episode as the header specifies | 16:killed | a_time_moves_by_known_path |
| `fault_cause.138.AIM.70` | Each soft-start retry is treated as a new episode: a cause captured during S_SS re-stamps fault_time even when the record already holds causes | 16:survived |  |
| `fault_cause.138.AIM.73` | Episode start lets the latch causes (inferred OVP and latch_assert) bypass the capture gate, on the belief that a latch trip always marks an episode, while the accumulator still gates them, so the two blocks disagree once the converter has stopped | 16:survived |  |
| `fault_cause.138.AIM.78` | fault_time stamps the converter's soft start, read as the start of an operating episode, instead of the capture of the first fault cause | 16:killed | a_time_at_episode_start, a_time_moves_by_known_path |
| `fault_cause.138.AIM.82` | When deciding whether the record is empty, the episode detector ignores the OVERCURRENT bit, as if a recorded soft-start hiccup were routine and did not open an episode | 16:killed | a_time_moves_by_known_path |
| `fault_cause.138.AIM.84` | When deciding whether the record is empty, the episode detector ignores the LATCH_ASSERT bit, as if the sticky CPLD trip were background state rather than an open episode | 16:survived |  |
| `fault_cause.138.AIM.89` | When deciding whether the record is empty, the episode detector ignores the UVLO bit, as if a recorded UVLO were the routine power-down the capture gate is there to ignore and did not open an episode | 16:killed | a_time_moves_by_known_path |
| `fault_cause.138.AIM.92` | When deciding whether the record is empty, the episode detector ignores the OTP bit, as if a self-clearing over-temperature that has cooled off did not hold an episode open | 16:killed | a_time_moves_by_known_path |
| `fault_cause.138.CST.1` | '0 -> '1 | 16:killed | a_time_at_episode_start |
| `fault_cause.138.CTD.1` | drop the term 'convertor_running' | 16:killed | a_time_moves_by_known_path |
| `fault_cause.138.CTD.2` | drop the term '(fault_reg == '0)' | 16:killed | a_time_moves_by_known_path |
| `fault_cause.138.CTD.3` | drop the term '(otp_state \|\| uvlo_state \|\| ovp \|\| latch' | 16:killed | a_time_moves_by_known_path |
| `fault_cause.138.CTN.1` | negate the term 'convertor_running' | 16:killed | a_time_moves_by_known_path, a_time_at_episode_start |
| `fault_cause.138.CTN.2` | negate the term '(fault_reg == '0)' | 16:killed | a_time_at_episode_start, a_time_moves_by_known_path |
| `fault_cause.138.LCR.1` | && -> \|\| | 16:killed | a_time_moves_by_known_path |
| `fault_cause.138.ROR.1` | == -> != | 16:killed | a_time_at_episode_start, a_time_moves_by_known_path |
| `fault_cause.138.SDL.1` | delete 'episode_start = convertor_running && (fault_reg == '0) && (o' | 16:lint | make lint: UNDRIVEN |
| `fault_cause.138.STK.1` | episode_start stuck at all-zeros (was 'convertor_running && (fault_reg == '0) &') | 16:killed | a_time_at_episode_start |
| `fault_cause.138.STK.2` | episode_start stuck at all-ones (was 'convertor_running && (fault_reg == '0) &') | 16:killed | a_time_moves_by_known_path |
| `fault_cause.138.VNG.1` | episode_start inverted (was 'convertor_running && (fault_reg == '0) &') | 16:killed | a_time_moves_by_known_path, a_time_at_episode_start |
| `fault_cause.139.AIM.100` | UVLO opens an episode only in S_RUN: a Vin dip during soft start is treated as inrush sag and does not stamp fault_time, although the accumulator still records it | 16:survived |  |
| `fault_cause.139.AIM.26` | Episode start leaves out the overcurrent window trips, on the assumption that an overcurrent episode only starts when latch_assert trips, so the accumulator and the episode detector disagree | 16:killed | a_time_at_episode_start |
| `fault_cause.139.AIM.68` | Episode start leaves out the latch causes (inferred OVP and latch_assert), on the belief that a latch trip always follows a window trip that has already opened the episode | 16:killed | a_time_at_episode_start |
| `fault_cause.139.AIM.69` | Episode start leaves out the environmental causes (OTP and UVLO), as if only faults the converter itself causes could open an episode | 16:killed | a_time_at_episode_start |
| `fault_cause.139.CTD.1` | drop the term 'otp_state' | 16:killed | a_time_at_episode_start |
| `fault_cause.139.CTD.2` | drop the term 'uvlo_state' | 16:killed | a_time_at_episode_start |
| `fault_cause.139.CTD.3` | drop the term 'ovp' | 16:killed | a_time_at_episode_start |
| `fault_cause.139.CTD.4` | drop the term 'latch_assert' | 16:killed | a_time_at_episode_start |
| `fault_cause.139.CTD.5` | drop the term 'window_trip' | 16:killed | a_time_at_episode_start |
| `fault_cause.139.CTN.1` | negate the term '(otp_state \|\| uvlo_state \|\| ovp \|\| latch' | 16:killed | a_time_moves_by_known_path, a_time_at_episode_start |
| `fault_cause.139.CTN.2` | negate the term 'otp_state' | 16:killed | a_time_moves_by_known_path, a_time_at_episode_start |
| `fault_cause.139.CTN.3` | negate the term 'uvlo_state' | 16:killed | a_time_moves_by_known_path |
| `fault_cause.139.CTN.4` | negate the term 'ovp' | 16:killed | a_time_moves_by_known_path |
| `fault_cause.139.CTN.5` | negate the term 'latch_assert' | 16:killed | a_time_moves_by_known_path |
| `fault_cause.139.LCR.1` | && -> \|\| | 16:killed | a_time_moves_by_known_path |
| `fault_cause.139.LCR.2` | \|\| -> && | 16:killed | a_time_at_episode_start |
| `fault_cause.139.LCR.3` | \|\| -> && | 16:killed | a_time_at_episode_start |
| `fault_cause.139.LCR.4` | \|\| -> && | 16:killed | a_time_at_episode_start |
| `fault_cause.139.SIB.1` | otp_state -> latch_state | 16:killed | a_time_at_episode_start |
| `fault_cause.139.SIB.2` | otp_state -> uvlo_state | 16:killed | a_time_at_episode_start |
| `fault_cause.139.SIB.3` | uvlo_state -> latch_state | 16:killed | a_time_at_episode_start |
| `fault_cause.139.SIB.4` | uvlo_state -> otp_state | 16:killed | a_time_at_episode_start |
| `fault_cause.139.SIB.5` | latch_assert -> latch_state | 16:killed | a_time_at_episode_start |
| `fault_cause.140.CTD.1` | drop the term 'window_trip_SS' | 16:killed | a_time_at_episode_start |
| `fault_cause.140.CTN.1` | negate the term 'window_trip' | 16:killed | a_time_moves_by_known_path |
| `fault_cause.140.CTN.2` | negate the term 'window_trip_SS' | 16:killed | a_time_moves_by_known_path |
| `fault_cause.140.LCR.1` | \|\| -> && | 16:killed | a_time_at_episode_start |
| `fault_cause.140.LCR.2` | \|\| -> && | 16:killed | a_time_at_episode_start |
| `fault_cause.144.EDG.1` | posedge clk -> negedge clk | 16:killed | a_time_moves_by_known_path, a_read_clears |
| `fault_cause.164.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 16:killed | a_reset_clears |
| `fault_cause.164.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 16:killed | a_time_at_episode_start |
| `fault_cause.164.CST.1` | '0 -> '1 | 16:killed | a_reset_clears |
| `fault_cause.164.SDL.1` | delete 'fault_time <= '0;' | 16:killed | a_reset_clears |
| `fault_cause.164.UOD.1` | drop the '!' before rst_n | 16:killed | a_time_at_episode_start |
| `fault_cause.165.AIM.117` | A host read clears only the top byte of fault_time (FTIME_2, the byte whose read raises the pulse), so the two low bytes keep the old episode start time | 16:killed | a_read_clears |
| `fault_cause.165.AIM.2` | fault_time capture takes priority over its clear-on-read, the opposite of fault_reg | 16:survived |  |
| `fault_cause.165.AIM.20` | fault_time is cleared by a host read only when the converter is stopped; a read during S_SS or S_RUN clears fault_reg but leaves the old start time | 16:killed | a_read_clears |
| `fault_cause.165.AIM.28` | A host read stamps fault_time with the read time instead of clearing it, so an empty record reports when it was last read | 16:killed | a_read_clears, a_time_moves_by_known_path |
| `fault_cause.165.AIM.41` | A host read clears fault_time only when no cause is live. The episode is treated as still open while any cause persists, so its start time survives the read even though fault_reg is cleared. | 16:killed | a_read_clears |
| `fault_cause.165.AIM.48` | fault_time is cleared when it sees the record empty, instead of on the host-read pulse itself, so it is cleared one clock after fault_reg | 16:killed | a_read_clears, a_time_moves_by_known_path |
| `fault_cause.165.AIM.59` | fault_time is cleared all through soft start, as if each restart opened a new episode, while fault_reg keeps its record until the host reads it | 16:killed | a_time_at_episode_start |
| `fault_cause.165.AIM.96` | A host read clears fault_time only while the converter is in S_SS or S_RUN. A read after a shutdown clears fault_reg but leaves the old episode start time. | 16:survived |  |
| `fault_cause.165.CND.1` | if (fault_reg_read_done) -> if (!(...)) | 16:killed | a_time_at_episode_start |
| `fault_cause.165.CSK.1` | if (fault_reg_read_done) -> if (1'b0): never taken | 16:killed | a_read_clears |
| `fault_cause.165.CSK.2` | if (fault_reg_read_done) -> if (1'b1): always taken | 16:killed | a_time_at_episode_start |
| `fault_cause.165.CST.1` | '0 -> '1 | 16:killed | a_read_clears, a_time_moves_by_known_path |
| `fault_cause.165.EDL.1` | delete the else branch at line 165 | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.165.SDL.1` | delete 'fault_time <= '0;' | 16:killed | a_read_clears |
| `fault_cause.166.AIM.21` | The three bytes of timestamp_ms are latched into fault_time in reversed order | 16:killed | a_time_at_episode_start, a_time_moves_by_known_path |
| `fault_cause.166.AIM.22` | fault_time is cleared when the converter stops, instead of being held until the host reads the record | 16:killed | a_time_moves_by_known_path |
| `fault_cause.166.AIM.71` | fault_time follows timestamp_ms whenever the record is empty and freezes once the first cause is captured, instead of being latched only at episode start | 16:killed | a_time_moves_by_known_path |
| `fault_cause.166.CND.1` | if (episode_start) -> if (!(...)) | 16:killed | a_time_moves_by_known_path, a_time_at_episode_start |
| `fault_cause.166.CSK.1` | if (episode_start) -> if (1'b1): always taken | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.166.EDL.1` | delete the else branch at line 166 | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.166.SDL.1` | delete 'fault_time <= timestamp_ms;' | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.166.STK.1` | fault_time stuck at all-zeros (was 'timestamp_ms') | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.166.STK.2` | fault_time stuck at all-ones (was 'timestamp_ms') | 16:lint | make lint: UNUSEDSIGNAL |
| `fault_cause.166.VNG.1` | fault_time inverted (was 'timestamp_ms') | 16:killed | a_time_at_episode_start, a_time_moves_by_known_path |
| `fault_cause.170.EDG.1` | posedge clk -> negedge clk | 16:killed | a_time_at_episode_start, a_capture_while_running +2 |
| `fault_cause.190.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 16:killed | a_reset_clears |
| `fault_cause.190.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 16:killed | a_capture_while_running |
| `fault_cause.190.UOD.1` | drop the '!' before rst_n | 16:killed | a_capture_while_running |
| `fault_cause.192.CST.1` | '0 -> '1 | 16:killed | a_reset_clears |
| `fault_cause.192.SDL.1` | delete 'fault_reg <= '0;' | 16:killed | a_reset_clears |
| `fault_cause.197.AIM.109` | fault_reg is cleared when it sees fault_time already cleared and the record non-empty, so its clear follows the read pulse through fault_time instead of using the pulse itself | 16:killed | a_read_clears, a_capture_while_running |
| `fault_cause.197.AIM.12` | A host read clears fault_reg only when the converter is stopped; a read during S_SS or S_RUN does not clear it | 16:killed | a_read_clears |
| `fault_cause.197.AIM.45` | fault_reg is cleared all through soft start, as if each restart began a new record, as well as on a host read | 16:killed | a_capture_while_running |
| `fault_cause.197.AIM.61` | A host read clears fault_reg only while the converter is running, so the cause of a shutdown cannot be read away until the converter restarts | 16:survived |  |
| `fault_cause.197.AIM.65` | A host read is ignored by fault_reg while any cause is still live, as if a fault still asserted kept the whole record open, instead of always clearing and letting live causes re-set their own bits | 16:killed | a_read_clears |
| `fault_cause.197.AIM.83` | A host read clears fault_reg only when the record is non-empty, on the belief that an empty record has nothing to clear, so a cause live on the read clock is captured through the read instead of losing to the clear | 16:survived |  |
| `fault_cause.197.CND.1` | if (fault_reg_read_done) -> if (!(...)) | 16:killed | a_capture_while_running, a_time_at_episode_start +1 |
| `fault_cause.197.CSK.1` | if (fault_reg_read_done) -> if (1'b0): never taken | 16:killed | a_read_clears |
| `fault_cause.197.CSK.2` | if (fault_reg_read_done) -> if (1'b1): always taken | 16:killed | a_capture_while_running |
| `fault_cause.197.EDL.1` | delete the else branch at line 197 | 16:killed | a_capture_while_running |
| `fault_cause.199.AIM.1` | On a host read, capture wins over clear: fault_reg is loaded with the causes live on that clock instead of being emptied | 16:killed | a_read_clears |
| `fault_cause.199.AIM.102` | A host read leaves the UVLO bit in place, as if it were a sticky brown-out status flag that only rst_n clears, while every other cause bit is cleared. | 16:killed | a_read_clears |
| `fault_cause.199.AIM.107` | A host read leaves the OVERCURRENT bit in place, treating the window-trip record like the strike history that only a long clean run or rst_n clears, while every other cause bit is cleared | 16:killed | a_read_clears |
| `fault_cause.199.AIM.72` | The LATCH_ASSERT bit survives a host read and is made sticky until reset, like the CPLD's latch_assert, instead of being cleared with the rest of the record | 16:killed | a_read_clears |
| `fault_cause.199.AIM.8` | The clear-on-read leaves the OVP bit set; only the four lower cause bits are cleared | 16:killed | a_read_clears |
| `fault_cause.199.AIM.9` | A host read clears only the recorded causes that have gone away; a recorded cause still asserted survives the read, even with the converter stopped | 16:killed | a_read_clears |
| `fault_cause.199.AIM.99` | A host read acknowledges only the highest-priority recorded cause and leaves the lower-priority causes in the record, instead of clearing the whole record | 16:killed | a_read_clears |
| `fault_cause.199.CST.1` | '0 -> '1 | 16:killed | a_read_clears |
| `fault_cause.199.SDL.1` | delete 'fault_reg <= '0;' | 16:killed | a_read_clears |
| `fault_cause.200.AIM.105` | A host read leaves the OTP bit in place, treating it as a latched thermal-shutdown flag that only rst_n clears, while every other cause bit is cleared | 16:killed | a_read_clears |
| `fault_cause.203.AIM.110` | Causes are recorded only on the clock the episode opens. A cause that appears later in the same episode is never added to fault_reg. | 16:killed | a_capture_while_running |
| `fault_cause.203.AIM.25` | The capture gate only scopes the start of an episode: once fault_reg holds a cause, further causes are added even after the converter has stopped | 16:killed | a_hold_when_stopped |
| `fault_cause.203.AIM.30` | fault_reg is cleared when the converter stops, like the supervisor's window state, instead of being held until the host reads it | 16:killed | a_hold_when_stopped |
| `fault_cause.203.AIM.32` | The accumulator's capture gate is S_RUN only, while episode_start still uses convertor_running (S_SS or S_RUN), so the two blocks no longer agree during soft start | 16:killed | a_capture_while_running |
| `fault_cause.203.AIM.40` | The capture gate is held open while the CPLD's latch trip is asserted, so the trip that stops the converter is sure to be seen. Because latch_assert is held until reset, the gate never closes after a latch trip. | 16:survived |  |
| `fault_cause.203.AIM.50` | The capture gate closes as soon as the protection latch reads back set, treating a set latch as a converter that has already stopped | 16:killed | a_capture_while_running |
| `fault_cause.203.AIM.6` | Over-temperature bypasses the capture gate: with otp_state high, causes are recorded even while the converter is stopped | 16:killed | a_hold_when_stopped, a_time_at_episode_start |
| `fault_cause.203.BDL.1` | empty the 5-statement body of the if at line 203 | 16:killed | a_capture_while_running |
| `fault_cause.203.CND.1` | if (convertor_running) -> if (!(...)) | 16:killed | a_hold_when_stopped, a_time_at_episode_start +1 |
| `fault_cause.203.CSK.1` | if (convertor_running) -> if (1'b1): always taken | 16:killed | a_hold_when_stopped, a_time_at_episode_start |
| `fault_cause.203.EDL.1` | delete the else branch at line 203 | 16:killed | a_capture_while_running |
| `fault_cause.205.AIM.112` | The over-temperature and over-voltage trips are confused: an inferred analog OVP trip is also recorded as OTP | 16:killed | a_capture_while_running |
| `fault_cause.205.AIM.115` | OTP is not recorded while the protection latch reads back set, on the belief that a latched converter is no longer heating the board, so any over-temperature then is not part of the fault | 16:survived |  |
| `fault_cause.205.AIM.31` | While running, any live cause overwrites the record with a snapshot of the currently live causes instead of OR-accumulating into it | 16:killed | a_capture_while_running |
| `fault_cause.205.AIM.46` | OTP is recorded only when UVLO is not live, as if a brown-out made the OTP reading unreliable and UVLO took precedence | 16:survived |  |
| `fault_cause.205.AIM.56` | OTP is recorded only in S_RUN, on the assumption that the board can only overheat under regulated load current, so an over-temperature during soft start is forgotten | 16:survived |  |
| `fault_cause.205.AIM.75` | While the converter runs, the OTP bit follows the live comparator instead of being set and held | 16:killed | a_capture_while_running |
| `fault_cause.205.AIM.87` | The bit-position priority is applied to recording: once a higher-priority cause is recorded, every lower-priority cause is dropped as its consequence, instead of all causes being OR-accumulated | 16:survived |  |
| `fault_cause.205.AIM.91` | OTP is not recorded once OVERCURRENT is in the record, on the belief that an over-temperature after an overcurrent is only the heating the overcurrent caused | 16:killed | a_capture_while_running |
| `fault_cause.205.CND.1` | if (otp_state) -> if (!(...)) | 16:killed | a_time_at_episode_start, a_capture_while_running |
| `fault_cause.205.CSK.1` | if (otp_state) -> if (1'b1): always taken | 16:killed | a_time_at_episode_start, a_capture_while_running |
| `fault_cause.205.CST.1` | 1'b1 -> 1'b0 | 16:killed | a_capture_while_running |
| `fault_cause.205.SDL.1` | delete 'fault_reg[BIT_OTP] <= 1'b1;' | 16:killed | a_capture_while_running |
| `fault_cause.205.SIB.1` | otp_state -> latch_state | 16:killed | a_capture_while_running |
| `fault_cause.205.SIB.2` | otp_state -> uvlo_state | 16:killed | a_capture_while_running |
| `fault_cause.206.AIM.10` | Causes are captured through a priority chain, one per clock, instead of independently accumulated | 16:survived |  |
| `fault_cause.206.AIM.111` | While the converter runs, the UVLO bit follows the live debounced UVLO instead of being set and held | 16:killed | a_capture_while_running |
| `fault_cause.206.AIM.18` | UVLO is recorded only as the first cause of an episode; a UVLO that follows another recorded cause is treated as a consequence and dropped | 16:survived |  |
| `fault_cause.206.AIM.55` | UVLO is recorded only during soft start, on the belief that a UVLO in S_RUN is the routine power-down the capture gate is there to ignore | 16:killed | a_capture_while_running |
| `fault_cause.206.AIM.63` | UVLO is not recorded while the protection latch reads back set, on the belief that an input droop after a latch trip is caused by the trip | 16:survived |  |
| `fault_cause.206.AIM.7` | UVLO is recorded only in S_RUN; a UVLO that interrupts soft start is forgotten | 16:survived |  |
| `fault_cause.206.AIM.76` | UVLO is not recorded while an overcurrent window trip is live, on the belief that an input droop under overcurrent is caused by the load current | 16:survived |  |
| `fault_cause.206.AIM.93` | UVLO is not recorded while OTP is live, as if over-temperature outranked and explained a simultaneous input brown-out | 16:survived |  |
| `fault_cause.206.AIM.95` | The UVLO bit is withdrawn during soft start once Vin is back. A restart after a recovered brown-out is taken to mean the UVLO was a routine power cycle and not a fault. | 16:survived |  |
| `fault_cause.206.CND.1` | if (uvlo_state) -> if (!(...)) | 16:killed | a_time_at_episode_start, a_capture_while_running |
| `fault_cause.206.CSK.1` | if (uvlo_state) -> if (1'b1): always taken | 16:killed | a_time_at_episode_start, a_capture_while_running |
| `fault_cause.206.CST.1` | 1'b1 -> 1'b0 | 16:killed | a_capture_while_running |
| `fault_cause.206.SDL.1` | delete 'fault_reg[BIT_UVLO] <= 1'b1;' | 16:killed | a_capture_while_running |
| `fault_cause.206.SIB.1` | uvlo_state -> latch_state | 16:killed | a_capture_while_running |
| `fault_cause.206.SIB.2` | uvlo_state -> otp_state | 16:killed | a_capture_while_running |
| `fault_cause.207.AIM.11` | The OVERCURRENT bit follows the live window trips while running instead of being set and held | 16:killed | a_capture_while_running |
| `fault_cause.207.AIM.114` | Each overcurrent window trip is qualified with the other trip's supervisor state: the S_RUN window_trip is accepted only during soft start and window_trip_SS only in S_RUN | 16:killed | a_capture_while_running |
| `fault_cause.207.AIM.13` | latch_assert also sets the OVERCURRENT bit, on the assumption that every CPLD latch trip is an overcurrent | 16:killed | a_capture_while_running |
| `fault_cause.207.AIM.33` | OVERCURRENT is recorded only when the window trip has already led to a CPLD latch trip, as if an overcurrent only counts once strikes reach the trip | 16:killed | a_capture_while_running |
| `fault_cause.207.AIM.35` | A soft-start overcurrent window trip is filed under the LATCH_ASSERT (OCP/SCP) bit instead of the OVERCURRENT bit | 16:killed | a_capture_while_running |
| `fault_cause.207.AIM.62` | The OVERCURRENT bit is not recorded while an OVP is inferred, on the belief that a window trip during an analog overvoltage is only a consequence of the overshoot | 16:survived |  |
| `fault_cause.207.AIM.94` | The OVERCURRENT bit is not recorded while UVLO is live, on the belief that a window trip during a brown-out is only the input-current surge the droop causes | 16:survived |  |
| `fault_cause.207.CND.1` | if (window_trip \|\| window_trip_SS) -> if (!(...)) | 16:killed | a_time_at_episode_start, a_capture_while_running |
| `fault_cause.207.CSK.1` | if (window_trip \|\| window_trip_SS) -> if (1'b1): always taken | 16:killed | a_time_at_episode_start, a_capture_while_running |
| `fault_cause.207.CST.1` | 1'b1 -> 1'b0 | 16:killed | a_capture_while_running |
| `fault_cause.207.CTD.1` | drop the term 'window_trip' | 16:killed | a_capture_while_running |
| `fault_cause.207.CTD.2` | drop the term 'window_trip_SS' | 16:killed | a_capture_while_running |
| `fault_cause.207.CTN.1` | negate the term 'window_trip' | 16:killed | a_time_at_episode_start, a_capture_while_running |
| `fault_cause.207.CTN.2` | negate the term 'window_trip_SS' | 16:killed | a_time_at_episode_start, a_capture_while_running |
| `fault_cause.207.LCR.1` | \|\| -> && | 16:killed | a_capture_while_running |
| `fault_cause.207.SDL.1` | delete 'fault_reg [BIT_OC] <= 1'b1;' | 16:killed | a_capture_while_running |
| `fault_cause.208.AIM.116` | OVP is recorded only during soft start, on the belief that an analog overvoltage can only be the overshoot at the end of the soft-start ramp, so an OVP trip in S_RUN (a load dump, say) is not recorded | 16:killed | a_capture_while_running |
| `fault_cause.208.AIM.37` | OVP is recorded only in S_RUN, on the assumption that overvoltage can only occur once the output is regulated, so an OVP overshoot during soft start is not recorded | 16:survived |  |
| `fault_cause.208.AIM.51` | The OVP bit is recorded from the raw latch readback instead of the inferred ovp, so every CPLD-originated latch trip is also recorded as OVP | 16:killed | a_capture_while_running |
| `fault_cause.208.CND.1` | if (ovp) -> if (!(...)) | 16:killed | a_time_at_episode_start, a_capture_while_running |
| `fault_cause.208.CSK.1` | if (ovp) -> if (1'b1): always taken | 16:killed | a_time_at_episode_start, a_capture_while_running |
| `fault_cause.208.CST.1` | 1'b1 -> 1'b0 | 16:killed | a_capture_while_running |
| `fault_cause.208.SDL.1` | delete 'fault_reg[BIT_OVP] <= 1'b1;' | 16:killed | a_capture_while_running |
| `fault_cause.209.AIM.113` | Every S_RUN window trip is also recorded as LATCH_ASSERT (OCP/SCP), as if each window trip were an OCP trip into the latch | 16:killed | a_capture_while_running |
| `fault_cause.209.AIM.16` | Recording LATCH_ASSERT withdraws an already recorded OVP bit, treating the two latch origins as mutually exclusive in the record | 16:survived |  |
| `fault_cause.209.AIM.19` | LATCH_ASSERT is recorded only once the debounced SCR readback confirms it, not when the CPLD asserts the trip | 16:killed | a_capture_while_running |
| `fault_cause.209.AIM.34` | LATCH_ASSERT is recorded only in S_RUN, on the assumption that the CPLD trips the latch only from run-time strikes, so a latch trip during soft start is forgotten | 16:survived |  |
| `fault_cause.209.AIM.42` | The LATCH_ASSERT bit is set whenever the protection latch reads back set, so an analog OVP trip is recorded as both OVP and LATCH_ASSERT (OCP/SCP) | 16:killed | a_capture_while_running |
| `fault_cause.209.AIM.53` | Recording the LATCH_ASSERT (OCP/SCP) trip withdraws the OVERCURRENT bit, on the assumption that the latch bit already covers the window trips that led to it | 16:survived |  |
| `fault_cause.209.AIM.77` | LATCH_ASSERT is not recorded once OVERCURRENT is in the record, on the belief that the window trip already explains the CPLD's latch trip | 16:survived |  |
| `fault_cause.209.CND.1` | if (latch_assert) -> if (!(...)) | 16:killed | a_time_at_episode_start, a_capture_while_running |
| `fault_cause.209.CSK.1` | if (latch_assert) -> if (1'b1): always taken | 16:killed | a_time_at_episode_start, a_capture_while_running |
| `fault_cause.209.CST.1` | 1'b1 -> 1'b0 | 16:killed | a_capture_while_running |
| `fault_cause.209.SDL.1` | delete 'fault_reg[BIT_LATCH] <= 1'b1;' | 16:killed | a_capture_while_running |
| `fault_cause.209.SIB.1` | latch_assert -> latch_state | 16:killed | a_capture_while_running |
| `fault_cause.211.AIM.103` | The OVERCURRENT bit is cleared whenever the converter is stopped, copying the fault_arbiter window's reset on leaving S_RUN/S_SS into the record, so an overcurrent that stopped the converter is gone from the record | 16:killed | a_hold_when_stopped |
| `fault_cause.211.AIM.104` | Once the converter has stopped, the OTP bit is withdrawn as soon as the board cools, as if a self-clearing over-temperature should clear its own record before the next start | 16:survived |  |
| `fault_cause.211.AIM.52` | OVP is recorded even while the converter is stopped, on the assumption that the analog comparator can trip the latch at any time and should always be logged | 16:survived |  |
| `fault_cause.211.AIM.67` | The LATCH_ASSERT bit bypasses the capture gate on the assumption that the CPLD's latch trip is always worth logging. It is recorded even while the converter is stopped, unlike every other cause. | 16:survived |  |
| `fault_cause.211.AIM.88` | UVLO bypasses the capture gate and is recorded even while the converter is stopped, on the belief that the debounced UVLO always arrives after the supervisor has already stopped the converter | 16:killed | a_hold_when_stopped, a_time_at_episode_start |
| `fault_cause.82.AIM.29` | Cause bit positions laid out LSB-first (OVP in bit 0, OVERCURRENT in bit 4), with the priority order misremembered as LSB highest | not run (withdrawn at step 15) |  |
| `fault_cause.82.AIM.79` | Over-voltage and over-current are confused in the bit map: OVP is placed in bit 0 and OVERCURRENT in bit 4 | not run (withdrawn at step 15) |  |
| `fault_cause.82.AIM.81` | Over-voltage and under-voltage are confused in the bit map: OVP is placed in bit 1 and UVLO in bit 4 | not run (withdrawn at step 15) |  |
| `fault_cause.82.AIM.85` | OVP and OTP, acronyms one letter apart, are swapped in the bit map: over-temperature is reported in bit 4 and the inferred overvoltage in bit 2 | not run (withdrawn at step 15) |  |
| `fault_cause.83.AIM.80` | The two overcurrent-related causes are confused in the bit map: LATCH_ASSERT (OCP/SCP) is placed in bit 0 and the window-trip OVERCURRENT in bit 3 | not run (withdrawn at step 15) |  |
| `fault_cause.83.AIM.98` | The two lock-type causes are confused in the bit map: the CPLD latch trip (LATCH_ASSERT) is placed in bit 1 and under-voltage lockout (UVLO) in bit 3 | not run (withdrawn at step 15) |  |
| `fault_cause.84.AIM.97` | Over-temperature (OT) and over-current (OC) are confused in the bit map: OTP is placed in bit 0 and OVERCURRENT in bit 2 | not run (withdrawn at step 15) |  |
| `fault_cause.165.AIM.74` | fault_time is cleared by a host read only when the record is non-empty, on the belief that an empty record has no start time to clear | not run (withdrawn at step 14) |  |
