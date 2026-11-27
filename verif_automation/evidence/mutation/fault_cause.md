# Mutation record: fault_cause

`rtl-systemverilog/telemetry/fault_cause.sv`. Written by `tools/mutation/record.py` from `fault_cause.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | - |
| AI-written | 61 | 0 | 0 | 0 | 0 | 0 | 0 | 61 | - |
| all | 61 | 0 | 0 | 0 | 0 | 0 | 0 | 61 | - |

Survivors: 0 - 0 decided equivalent, 0 accepted, 0 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: -.

## Survivors (0)

None.

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-14 14:38 | 664452d | AI wrote mutants (claude-fable-5-2) | asked 15, proposed 13, accepted 13, rejected 0; `ai_runs/2026-11-14_write_mutants_3` |
| 2 | 2026-11-14 14:41 | 664452d | AI wrote mutants (claude-fable-5-2) | asked 15, proposed 10, accepted 10, rejected 0; `ai_runs/2026-11-14_write_mutants_4` |
| 3 | 2026-11-26 21:26 | 219c651 | AI wrote mutants (claude-opus-5-5) | asked 10, proposed 3, accepted 3, rejected 0; `ai_runs/2026-11-26_write_mutants` |
| 4 | 2026-11-26 21:37 | 219c651 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 14, accepted 13, rejected 1; `ai_runs/2026-11-26_write_mutants_2` |
| 5 | 2026-11-26 22:03 | 219c651 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 9, accepted 9, rejected 0; `ai_runs/2026-11-26_write_mutants_3` |
| 6 | 2026-11-26 22:30 | 219c651 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 13, accepted 13, rejected 0; `ai_runs/2026-11-26_write_mutants_4` |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (61)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | priority | On a host read, capture wins over clear: fault_reg is loaded with the causes live on that clock instead of being emptied | not run |  |
| 2 | 1 | priority | fault_time capture takes priority over its clear-on-read, the opposite of fault_reg | not run |  |
| 3 | 1 | sequencing | Episode start is detected from fault_reg having gone non-empty rather than from the capture conditions, so fault_time is latched one clock after the first cause | not run |  |
| 4 | 1 | boundary | The episode is judged empty by fault_time being zero instead of fault_reg being zero | not run |  |
| 5 | 1 | field | OVP is inferred against the recorded LATCH bit instead of the live latch_assert | not run |  |
| 6 | 1 | missing_case | Over-temperature bypasses the capture gate: with otp_state high, causes are recorded even while the converter is stopped | not run |  |
| 7 | 1 | missing_case | UVLO is recorded only in S_RUN; a UVLO that interrupts soft start is forgotten | not run |  |
| 8 | 1 | reset_init | The clear-on-read leaves the OVP bit set; only the four lower cause bits are cleared | not run |  |
| 9 | 1 | reset_init | A host read clears only the recorded causes that have gone away; a recorded cause still asserted survives the read, even with the converter stopped | not run |  |
| 10 | 1 | priority | Causes are captured through a priority chain, one per clock, instead of independently accumulated | not run |  |
| 11 | 1 | wrong_event | The OVERCURRENT bit follows the live window trips while running instead of being set and held | not run |  |
| 12 | 1 | wrong_event | A host read clears fault_reg only when the converter is stopped; a read during S_SS or S_RUN does not clear it | not run |  |
| 13 | 1 | field | latch_assert also sets the OVERCURRENT bit, on the assumption that every CPLD latch trip is an overcurrent | not run |  |
| 14 | 2 | missing_case | The episode start is detected only in S_RUN: a first cause captured during soft start does not latch fault_time | not run |  |
| 15 | 2 | missing_case | OVP inference is suppressed while an overcurrent window trip is live, on the assumption that the latch trip then belongs to the overcurrent | not run |  |
| 16 | 2 | field | Recording LATCH_ASSERT withdraws an already recorded OVP bit, treating the two latch origins as mutually exclusive in the record | not run |  |
| 17 | 2 | boundary | The record is judged empty from the four lower cause bits only; a recorded OVP does not count as an open episode | not run |  |
| 18 | 2 | wrong_event | UVLO is recorded only as the first cause of an episode; a UVLO that follows another recorded cause is treated as a consequence and dropped | not run |  |
| 19 | 2 | sequencing | LATCH_ASSERT is recorded only once the debounced SCR readback confirms it, not when the CPLD asserts the trip | not run |  |
| 20 | 2 | reset_init | fault_time is cleared by a host read only when the converter is stopped; a read during S_SS or S_RUN clears fault_reg but leaves the old start time | not run |  |
| 21 | 2 | field | The three bytes of timestamp_ms are latched into fault_time in reversed order | not run |  |
| 22 | 2 | reset_init | fault_time is cleared when the converter stops, instead of being held until the host reads the record | not run |  |
| 23 | 2 | other | OVP is inferred from any disagreement between latch_state and latch_assert, not only from the latch set without the CPLD's trip | not run |  |
| 24 | 3 | wrong_event | fault_time is re-latched every time a cause not yet in the record is captured, so it holds the time of the most recent new cause instead of the start of the episode | not run |  |
| 25 | 3 | missing_case | The capture gate only scopes the start of an episode: once fault_reg holds a cause, further causes are added even after the converter has stopped | not run |  |
| 26 | 3 | missing_case | Episode start leaves out the overcurrent window trips, on the assumption that an overcurrent episode only starts when latch_assert trips, so the accumulator and the episode detector disagree | not run |  |
| 27 | 4 | wrong_event | fault_time records when the converter stopped with a non-empty record (the shutdown) instead of when the first cause of the episode was captured | not run |  |
| 28 | 4 | wrong_event | A host read stamps fault_time with the read time instead of clearing it, so an empty record reports when it was last read | not run |  |
| 29 | 4 | field | Cause bit positions laid out LSB-first (OVP in bit 0, OVERCURRENT in bit 4), with the priority order misremembered as LSB highest | not run |  |
| 30 | 4 | reset_init | fault_reg is cleared when the converter stops, like the supervisor's window state, instead of being held until the host reads it | not run |  |
| 31 | 4 | other | While running, any live cause overwrites the record with a snapshot of the currently live causes instead of OR-accumulating into it | not run |  |
| 32 | 4 | missing_case | The accumulator's capture gate is S_RUN only, while episode_start still uses convertor_running (S_SS or S_RUN), so the two blocks no longer agree during soft start | not run |  |
| 33 | 4 | missing_case | OVERCURRENT is recorded only when the window trip has already led to a CPLD latch trip, as if an overcurrent only counts once strikes reach the trip | not run |  |
| 34 | 4 | missing_case | LATCH_ASSERT is recorded only in S_RUN, on the assumption that the CPLD trips the latch only from run-time strikes, so a latch trip during soft start is forgotten | not run |  |
| 35 | 4 | field | A soft-start overcurrent window trip is filed under the LATCH_ASSERT (OCP/SCP) bit instead of the OVERCURRENT bit | not run |  |
| 36 | 4 | field | The OTP and UVLO cause bits are laid out in swapped positions, with the priority order between them misremembered | not run |  |
| 37 | 4 | missing_case | OVP is recorded only in S_RUN, on the assumption that overvoltage can only occur once the output is regulated, so an OVP overshoot during soft start is not recorded | not run |  |
| 38 | 4 | field | The OVP and LATCH_ASSERT cause bits are laid out in swapped positions, with the CPLD's measured trip misremembered as outranking the inferred OVP | not run |  |
| 39 | 4 | other | OVP is inferred with the two latch signals confused: CPLD trip asserted while the SCR readback is still clear, instead of readback set without a CPLD trip | not run |  |
| 40 | 5 | missing_case | The capture gate is held open while the CPLD's latch trip is asserted, so the trip that stops the converter is sure to be seen. Because latch_assert is held until reset, the gate never closes after a latch trip. | not run |  |
| 41 | 5 | reset_init | A host read clears fault_time only when no cause is live. The episode is treated as still open while any cause persists, so its start time survives the read even though fault_reg is cleared. | not run |  |
| 42 | 5 | missing_case | The LATCH_ASSERT bit is set whenever the protection latch reads back set, so an analog OVP trip is recorded as both OVP and LATCH_ASSERT (OCP/SCP) | not run |  |
| 43 | 5 | wrong_event | OVP is inferred as a latch trip with no recorded overcurrent, as if every CPLD trip is shown by a recorded window trip, instead of a latch trip without the CPLD's latch_assert | not run |  |
| 44 | 5 | wrong_event | fault_time is re-latched whenever a live cause outranks every cause already recorded, so it gives the time of the highest-priority cause instead of the start of the episode | not run |  |
| 45 | 5 | reset_init | fault_reg is cleared all through soft start, as if each restart began a new record, as well as on a host read | not run |  |
| 46 | 5 | priority | OTP is recorded only when UVLO is not live, as if a brown-out made the OTP reading unreliable and UVLO took precedence | not run |  |
| 47 | 5 | field | The UVLO and OVERCURRENT cause bits are laid out in swapped positions, so overcurrent is ranked above UVLO | not run |  |
| 48 | 5 | sequencing | fault_time is cleared when it sees the record empty, instead of on the host-read pulse itself, so it is cleared one clock after fault_reg | not run |  |
| 49 | 6 | field | The LATCH_ASSERT and OTP cause bits are laid out in swapped positions, so OTP is ranked above the CPLD's latch trip | not run |  |
| 50 | 6 | missing_case | The capture gate closes as soon as the protection latch reads back set, treating a set latch as a converter that has already stopped | not run |  |
| 51 | 6 | other | The OVP bit is recorded from the raw latch readback instead of the inferred ovp, so every CPLD-originated latch trip is also recorded as OVP | not run |  |
| 52 | 6 | missing_case | OVP is recorded even while the converter is stopped, on the assumption that the analog comparator can trip the latch at any time and should always be logged | not run |  |
| 53 | 6 | other | Recording the LATCH_ASSERT (OCP/SCP) trip withdraws the OVERCURRENT bit, on the assumption that the latch bit already covers the window trips that led to it | not run |  |
| 54 | 6 | other | The capture gate is closed whenever UVLO is live, so every UVLO is treated as a routine power-down rather than only the ones that come after the converter has stopped | not run |  |
| 55 | 6 | missing_case | UVLO is recorded only during soft start, on the belief that a UVLO in S_RUN is the routine power-down the capture gate is there to ignore | not run |  |
| 56 | 6 | missing_case | OTP is recorded only in S_RUN, on the assumption that the board can only overheat under regulated load current, so an over-temperature during soft start is forgotten | not run |  |
| 57 | 6 | other | OVP inference is suppressed while UVLO is live, on the assumption that the SCR readback is not trustworthy during a brown-out | not run |  |
| 58 | 6 | missing_case | The capture gate is held open while UVLO is asserted, so the brown-out that stops the converter is sure to be recorded. The side effect is that every routine power-down is logged as a UVLO episode. | not run |  |
| 59 | 6 | reset_init | fault_time is cleared all through soft start, as if each restart opened a new episode, while fault_reg keeps its record until the host reads it | not run |  |
| 60 | 6 | missing_case | OVP is inferred only into an empty record, on the belief that an analog latch trip after any other recorded cause must be a consequence of that cause | not run |  |
| 61 | 6 | wrong_event | A host read clears fault_reg only while the converter is running, so the cause of a shutdown cannot be read away until the converter restarts | not run |  |

Rejected by the gate in step 4 (1):

- The episode-start detector uses the debounced SCR readback latch_state where the accumulator uses the CPLD's latch_assert, so a CPLD trip opens no episode until the readback follows - **the same edit as fault_cause.139.SIB.5**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `fault_cause.82.AIM.29` | Cause bit positions laid out LSB-first (OVP in bit 0, OVERCURRENT in bit 4), with the priority order misremembered as LSB highest | not run |  |
| `fault_cause.82.AIM.38` | The OVP and LATCH_ASSERT cause bits are laid out in swapped positions, with the CPLD's measured trip misremembered as outranking the inferred OVP | not run |  |
| `fault_cause.83.AIM.49` | The LATCH_ASSERT and OTP cause bits are laid out in swapped positions, so OTP is ranked above the CPLD's latch trip | not run |  |
| `fault_cause.84.AIM.36` | The OTP and UVLO cause bits are laid out in swapped positions, with the priority order between them misremembered | not run |  |
| `fault_cause.85.AIM.47` | The UVLO and OVERCURRENT cause bits are laid out in swapped positions, so overcurrent is ranked above UVLO | not run |  |
| `fault_cause.104.AIM.54` | The capture gate is closed whenever UVLO is live, so every UVLO is treated as a routine power-down rather than only the ones that come after the converter has stopped | not run |  |
| `fault_cause.104.AIM.58` | The capture gate is held open while UVLO is asserted, so the brown-out that stops the converter is sure to be recorded. The side effect is that every routine power-down is logged as a UVLO episode. | not run |  |
| `fault_cause.118.AIM.15` | OVP inference is suppressed while an overcurrent window trip is live, on the assumption that the latch trip then belongs to the overcurrent | not run |  |
| `fault_cause.118.AIM.23` | OVP is inferred from any disagreement between latch_state and latch_assert, not only from the latch set without the CPLD's trip | not run |  |
| `fault_cause.118.AIM.39` | OVP is inferred with the two latch signals confused: CPLD trip asserted while the SCR readback is still clear, instead of readback set without a CPLD trip | not run |  |
| `fault_cause.118.AIM.43` | OVP is inferred as a latch trip with no recorded overcurrent, as if every CPLD trip is shown by a recorded window trip, instead of a latch trip without the CPLD's latch_assert | not run |  |
| `fault_cause.118.AIM.5` | OVP is inferred against the recorded LATCH bit instead of the live latch_assert | not run |  |
| `fault_cause.118.AIM.57` | OVP inference is suppressed while UVLO is live, on the assumption that the SCR readback is not trustworthy during a brown-out | not run |  |
| `fault_cause.118.AIM.60` | OVP is inferred only into an empty record, on the belief that an analog latch trip after any other recorded cause must be a consequence of that cause | not run |  |
| `fault_cause.138.AIM.14` | The episode start is detected only in S_RUN: a first cause captured during soft start does not latch fault_time | not run |  |
| `fault_cause.138.AIM.17` | The record is judged empty from the four lower cause bits only; a recorded OVP does not count as an open episode | not run |  |
| `fault_cause.138.AIM.24` | fault_time is re-latched every time a cause not yet in the record is captured, so it holds the time of the most recent new cause instead of the start of the episode | not run |  |
| `fault_cause.138.AIM.27` | fault_time records when the converter stopped with a non-empty record (the shutdown) instead of when the first cause of the episode was captured | not run |  |
| `fault_cause.138.AIM.3` | Episode start is detected from fault_reg having gone non-empty rather than from the capture conditions, so fault_time is latched one clock after the first cause | not run |  |
| `fault_cause.138.AIM.4` | The episode is judged empty by fault_time being zero instead of fault_reg being zero | not run |  |
| `fault_cause.138.AIM.44` | fault_time is re-latched whenever a live cause outranks every cause already recorded, so it gives the time of the highest-priority cause instead of the start of the episode | not run |  |
| `fault_cause.139.AIM.26` | Episode start leaves out the overcurrent window trips, on the assumption that an overcurrent episode only starts when latch_assert trips, so the accumulator and the episode detector disagree | not run |  |
| `fault_cause.165.AIM.2` | fault_time capture takes priority over its clear-on-read, the opposite of fault_reg | not run |  |
| `fault_cause.165.AIM.20` | fault_time is cleared by a host read only when the converter is stopped; a read during S_SS or S_RUN clears fault_reg but leaves the old start time | not run |  |
| `fault_cause.165.AIM.28` | A host read stamps fault_time with the read time instead of clearing it, so an empty record reports when it was last read | not run |  |
| `fault_cause.165.AIM.41` | A host read clears fault_time only when no cause is live. The episode is treated as still open while any cause persists, so its start time survives the read even though fault_reg is cleared. | not run |  |
| `fault_cause.165.AIM.48` | fault_time is cleared when it sees the record empty, instead of on the host-read pulse itself, so it is cleared one clock after fault_reg | not run |  |
| `fault_cause.165.AIM.59` | fault_time is cleared all through soft start, as if each restart opened a new episode, while fault_reg keeps its record until the host reads it | not run |  |
| `fault_cause.166.AIM.21` | The three bytes of timestamp_ms are latched into fault_time in reversed order | not run |  |
| `fault_cause.166.AIM.22` | fault_time is cleared when the converter stops, instead of being held until the host reads the record | not run |  |
| `fault_cause.197.AIM.12` | A host read clears fault_reg only when the converter is stopped; a read during S_SS or S_RUN does not clear it | not run |  |
| `fault_cause.197.AIM.45` | fault_reg is cleared all through soft start, as if each restart began a new record, as well as on a host read | not run |  |
| `fault_cause.197.AIM.61` | A host read clears fault_reg only while the converter is running, so the cause of a shutdown cannot be read away until the converter restarts | not run |  |
| `fault_cause.199.AIM.1` | On a host read, capture wins over clear: fault_reg is loaded with the causes live on that clock instead of being emptied | not run |  |
| `fault_cause.199.AIM.8` | The clear-on-read leaves the OVP bit set; only the four lower cause bits are cleared | not run |  |
| `fault_cause.199.AIM.9` | A host read clears only the recorded causes that have gone away; a recorded cause still asserted survives the read, even with the converter stopped | not run |  |
| `fault_cause.203.AIM.25` | The capture gate only scopes the start of an episode: once fault_reg holds a cause, further causes are added even after the converter has stopped | not run |  |
| `fault_cause.203.AIM.30` | fault_reg is cleared when the converter stops, like the supervisor's window state, instead of being held until the host reads it | not run |  |
| `fault_cause.203.AIM.32` | The accumulator's capture gate is S_RUN only, while episode_start still uses convertor_running (S_SS or S_RUN), so the two blocks no longer agree during soft start | not run |  |
| `fault_cause.203.AIM.40` | The capture gate is held open while the CPLD's latch trip is asserted, so the trip that stops the converter is sure to be seen. Because latch_assert is held until reset, the gate never closes after a latch trip. | not run |  |
| `fault_cause.203.AIM.50` | The capture gate closes as soon as the protection latch reads back set, treating a set latch as a converter that has already stopped | not run |  |
| `fault_cause.203.AIM.6` | Over-temperature bypasses the capture gate: with otp_state high, causes are recorded even while the converter is stopped | not run |  |
| `fault_cause.205.AIM.31` | While running, any live cause overwrites the record with a snapshot of the currently live causes instead of OR-accumulating into it | not run |  |
| `fault_cause.205.AIM.46` | OTP is recorded only when UVLO is not live, as if a brown-out made the OTP reading unreliable and UVLO took precedence | not run |  |
| `fault_cause.205.AIM.56` | OTP is recorded only in S_RUN, on the assumption that the board can only overheat under regulated load current, so an over-temperature during soft start is forgotten | not run |  |
| `fault_cause.206.AIM.10` | Causes are captured through a priority chain, one per clock, instead of independently accumulated | not run |  |
| `fault_cause.206.AIM.18` | UVLO is recorded only as the first cause of an episode; a UVLO that follows another recorded cause is treated as a consequence and dropped | not run |  |
| `fault_cause.206.AIM.55` | UVLO is recorded only during soft start, on the belief that a UVLO in S_RUN is the routine power-down the capture gate is there to ignore | not run |  |
| `fault_cause.206.AIM.7` | UVLO is recorded only in S_RUN; a UVLO that interrupts soft start is forgotten | not run |  |
| `fault_cause.207.AIM.11` | The OVERCURRENT bit follows the live window trips while running instead of being set and held | not run |  |
| `fault_cause.207.AIM.13` | latch_assert also sets the OVERCURRENT bit, on the assumption that every CPLD latch trip is an overcurrent | not run |  |
| `fault_cause.207.AIM.33` | OVERCURRENT is recorded only when the window trip has already led to a CPLD latch trip, as if an overcurrent only counts once strikes reach the trip | not run |  |
| `fault_cause.207.AIM.35` | A soft-start overcurrent window trip is filed under the LATCH_ASSERT (OCP/SCP) bit instead of the OVERCURRENT bit | not run |  |
| `fault_cause.208.AIM.37` | OVP is recorded only in S_RUN, on the assumption that overvoltage can only occur once the output is regulated, so an OVP overshoot during soft start is not recorded | not run |  |
| `fault_cause.208.AIM.51` | The OVP bit is recorded from the raw latch readback instead of the inferred ovp, so every CPLD-originated latch trip is also recorded as OVP | not run |  |
| `fault_cause.209.AIM.16` | Recording LATCH_ASSERT withdraws an already recorded OVP bit, treating the two latch origins as mutually exclusive in the record | not run |  |
| `fault_cause.209.AIM.19` | LATCH_ASSERT is recorded only once the debounced SCR readback confirms it, not when the CPLD asserts the trip | not run |  |
| `fault_cause.209.AIM.34` | LATCH_ASSERT is recorded only in S_RUN, on the assumption that the CPLD trips the latch only from run-time strikes, so a latch trip during soft start is forgotten | not run |  |
| `fault_cause.209.AIM.42` | The LATCH_ASSERT bit is set whenever the protection latch reads back set, so an analog OVP trip is recorded as both OVP and LATCH_ASSERT (OCP/SCP) | not run |  |
| `fault_cause.209.AIM.53` | Recording the LATCH_ASSERT (OCP/SCP) trip withdraws the OVERCURRENT bit, on the assumption that the latch bit already covers the window trips that led to it | not run |  |
| `fault_cause.211.AIM.52` | OVP is recorded even while the converter is stopped, on the assumption that the analog comparator can trip the latch at any time and should always be logged | not run |  |
