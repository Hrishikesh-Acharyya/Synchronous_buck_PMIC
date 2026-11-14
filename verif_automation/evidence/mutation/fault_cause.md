# Mutation record: fault_cause

`rtl-systemverilog/telemetry/fault_cause.sv`. Written by `tools/mutation/record.py` from `fault_cause.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | - |
| AI-written | 23 | 0 | 0 | 0 | 0 | 0 | 0 | 23 | - |
| all | 23 | 0 | 0 | 0 | 0 | 0 | 0 | 23 | - |

Survivors: 0 - 0 decided equivalent, 0 accepted, 0 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: -.

## Survivors (0)

None.

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-14 14:38 | 664452d | AI wrote mutants (claude-fable-5-2) | asked 15, proposed 13, accepted 13, rejected 0; `ai_runs/2026-11-14_write_mutants_3` |
| 2 | 2026-11-14 14:41 | 664452d | AI wrote mutants (claude-fable-5-2) | asked 15, proposed 10, accepted 10, rejected 0; `ai_runs/2026-11-14_write_mutants_4` |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (23)

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

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `fault_cause.118.AIM.15` | OVP inference is suppressed while an overcurrent window trip is live, on the assumption that the latch trip then belongs to the overcurrent | not run |  |
| `fault_cause.118.AIM.23` | OVP is inferred from any disagreement between latch_state and latch_assert, not only from the latch set without the CPLD's trip | not run |  |
| `fault_cause.118.AIM.5` | OVP is inferred against the recorded LATCH bit instead of the live latch_assert | not run |  |
| `fault_cause.138.AIM.14` | The episode start is detected only in S_RUN: a first cause captured during soft start does not latch fault_time | not run |  |
| `fault_cause.138.AIM.17` | The record is judged empty from the four lower cause bits only; a recorded OVP does not count as an open episode | not run |  |
| `fault_cause.138.AIM.3` | Episode start is detected from fault_reg having gone non-empty rather than from the capture conditions, so fault_time is latched one clock after the first cause | not run |  |
| `fault_cause.138.AIM.4` | The episode is judged empty by fault_time being zero instead of fault_reg being zero | not run |  |
| `fault_cause.165.AIM.2` | fault_time capture takes priority over its clear-on-read, the opposite of fault_reg | not run |  |
| `fault_cause.165.AIM.20` | fault_time is cleared by a host read only when the converter is stopped; a read during S_SS or S_RUN clears fault_reg but leaves the old start time | not run |  |
| `fault_cause.166.AIM.21` | The three bytes of timestamp_ms are latched into fault_time in reversed order | not run |  |
| `fault_cause.166.AIM.22` | fault_time is cleared when the converter stops, instead of being held until the host reads the record | not run |  |
| `fault_cause.197.AIM.12` | A host read clears fault_reg only when the converter is stopped; a read during S_SS or S_RUN does not clear it | not run |  |
| `fault_cause.199.AIM.1` | On a host read, capture wins over clear: fault_reg is loaded with the causes live on that clock instead of being emptied | not run |  |
| `fault_cause.199.AIM.8` | The clear-on-read leaves the OVP bit set; only the four lower cause bits are cleared | not run |  |
| `fault_cause.199.AIM.9` | A host read clears only the recorded causes that have gone away; a recorded cause still asserted survives the read, even with the converter stopped | not run |  |
| `fault_cause.203.AIM.6` | Over-temperature bypasses the capture gate: with otp_state high, causes are recorded even while the converter is stopped | not run |  |
| `fault_cause.206.AIM.10` | Causes are captured through a priority chain, one per clock, instead of independently accumulated | not run |  |
| `fault_cause.206.AIM.18` | UVLO is recorded only as the first cause of an episode; a UVLO that follows another recorded cause is treated as a consequence and dropped | not run |  |
| `fault_cause.206.AIM.7` | UVLO is recorded only in S_RUN; a UVLO that interrupts soft start is forgotten | not run |  |
| `fault_cause.207.AIM.11` | The OVERCURRENT bit follows the live window trips while running instead of being set and held | not run |  |
| `fault_cause.207.AIM.13` | latch_assert also sets the OVERCURRENT bit, on the assumption that every CPLD latch trip is an overcurrent | not run |  |
| `fault_cause.209.AIM.16` | Recording LATCH_ASSERT withdraws an already recorded OVP bit, treating the two latch origins as mutually exclusive in the record | not run |  |
| `fault_cause.209.AIM.19` | LATCH_ASSERT is recorded only once the debounced SCR readback confirms it, not when the CPLD asserts the trip | not run |  |
