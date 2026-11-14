# Mutation record: input_sync

`rtl-systemverilog/inputs/input_sync.sv`. Written by `tools/mutation/record.py` from `input_sync.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 22 | 15 | 7 | 0 | 0 | 0 | 0 | 0 | 100.0% |
| AI-written | 5 | 5 | 0 | 0 | 0 | 0 | 0 | 0 | 100.0% |
| all | 27 | 20 | 7 | 0 | 0 | 0 | 0 | 0 | 100.0% |

Survivors: 0 - 0 decided equivalent, 0 accepted, 0 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 100.0%.
10 earlier mutants are not in these numbers: 10 AI-written ones the designer withdrew, 0 the generator no longer makes because the RTL changed. Their history is kept below.

## Survivors (0)

None.

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-14 20:33 | a625f66 | AI wrote mutants (claude-opus-5-5) | asked 6, proposed 4, accepted 3, rejected 1; `ai_runs/2026-11-14_write_mutants_6` |
| 2 | 2026-11-14 20:35 | a625f66 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 7, accepted 7, rejected 0; `ai_runs/2026-11-14_write_mutants_7` |
| 3 | 2026-11-14 20:37 | a625f66 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 5, accepted 5, rejected 0; `ai_runs/2026-11-14_write_mutants_8` |
| 4 | 2026-11-14 20:49 | 217b430 | designer withdrew AI-written mutants | input_sync.49.AIM.1, input_sync.48.AIM.2, input_sync.48.AIM.3, input_sync.54.AIM.9 - a mechanical operator already makes this fault: STK or VNG on the same assignment |
| 5 | 2026-11-14 20:49 | 217b430 | designer withdrew AI-written mutants | input_sync.55.AIM.6, input_sync.55.AIM.7, input_sync.54.AIM.12, input_sync.55.AIM.13, input_sync.55.AIM.14, input_sync.55.AIM.15 - a different circuit, not a slip a designer makes writing a two-flop synchroniser |
| 6 | 2026-11-14 20:54 | 217b430 | mutation run - every mutant of the module | 27 mutants: 20 killed, 7 lint; score 100.0% |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (15)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | reset_init | sync_out resets to a hard-coded 0 instead of RESET_VALUE; only meta_ff honours the parameter | withdrawn: a mechanical operator already makes this fault: STK or VNG on the same assignment |  |
| 2 | 1 | reset_init | meta_ff resets to a hard-coded 0 instead of RESET_VALUE, so the first stage forgets the safe value | withdrawn: a mechanical operator already makes this fault: STK or VNG on the same assignment |  |
| 3 | 1 | reset_init | meta_ff resets to the opposite of RESET_VALUE (safe level misremembered for the first stage) | withdrawn: a mechanical operator already makes this fault: STK or VNG on the same assignment |  |
| 4 | 2 | reset_init | meta_ff is pre-loaded with the live async_in during reset instead of the safe RESET_VALUE, as if reset should 'prime' the synchroniser with the real input | killed | a_one_clock_after_release |
| 5 | 2 | reset_init | sync_out follows the live async_in during reset instead of holding the safe RESET_VALUE | killed | a_sync_out_reads_RESET |
| 6 | 2 | other | The second stage becomes a two-sample agreement filter: sync_out takes meta_ff only when it equals the current async_in, otherwise it holds | withdrawn: a different circuit, not a slip a designer makes writing a two-flop synchroniser |  |
| 7 | 2 | other | sync_out is made a sticky latch: once a 1 has passed through it holds 1 until rst_n, as if every synchronised input were a latched fault flag | withdrawn: a different circuit, not a slip a designer makes writing a two-flop synchroniser |  |
| 8 | 2 | sequencing | A 'fast fault path': the safe/asserted level (RESET_VALUE) goes from async_in straight to sync_out, and only the release goes through meta_ff | killed | a_two_clock_latency |
| 9 | 2 | other | RESET_VALUE is read as an input-polarity setting, so the first stage stores async_in inverted whenever RESET_VALUE is 1 | withdrawn: a mechanical operator already makes this fault: STK or VNG on the same assignment |  |
| 10 | 2 | reset_init | During reset sync_out shifts in meta_ff instead of being forced to RESET_VALUE, so a stale first-stage sample survives reset entry and power-up leaves sync_out undefined until a clock edge | killed | a_sync_out_reads_RESET |
| 11 | 3 | other | A 'fast release' path: the non-safe (released) level goes from async_in straight to sync_out, and only a return to the safe RESET_VALUE goes through meta_ff | killed | a_one_clock_after_release, a_two_clock_latency |
| 12 | 3 | sequencing | The first stage waits for the second stage to catch up (handshake) before taking a new sample of async_in, instead of sampling every clock | withdrawn: a different circuit, not a slip a designer makes writing a two-flop synchroniser |  |
| 13 | 3 | other | 'Assume the worst' is applied every clock: whenever meta_ff and async_in disagree, sync_out is forced to the safe RESET_VALUE instead of taking meta_ff | withdrawn: a different circuit, not a slip a designer makes writing a two-flop synchroniser |  |
| 14 | 3 | other | The second stage is written as the receiving end of a toggle (pulse) synchroniser: sync_out flips whenever the first stage holds 1, instead of copying the level | withdrawn: a different circuit, not a slip a designer makes writing a two-flop synchroniser |  |
| 15 | 3 | wrong_event | The synchroniser output is turned into a rising-edge detector on the synchronised level: sync_out goes high for one clock when meta_ff rises, not for as long as async_in stays high | withdrawn: a different circuit, not a slip a designer makes writing a two-flop synchroniser |  |

Rejected by the gate in step 1 (1):

- sync_out samples async_in directly, bypassing meta_ff: a one-stage synchroniser with one clock less latency - **make lint already catches it: make lint: UNUSEDSIGNAL**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `input_sync.35.EDG.1` | posedge clk -> negedge clk | 6:killed | a_one_clock_after_release, a_two_clock_latency |
| `input_sync.46.BDL.1` | empty the 2-statement body of the if at line 46 | 6:killed | a_sync_out_reads_RESET, a_one_clock_after_release |
| `input_sync.46.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 6:killed | a_sync_out_reads_RESET, a_one_clock_after_release |
| `input_sync.46.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 6:killed | a_two_clock_latency |
| `input_sync.46.UOD.1` | drop the '!' before rst_n | 6:killed | a_sync_out_reads_RESET, a_two_clock_latency |
| `input_sync.48.AIM.4` | meta_ff is pre-loaded with the live async_in during reset instead of the safe RESET_VALUE, as if reset should 'prime' the synchroniser with the real input | 6:killed | a_one_clock_after_release |
| `input_sync.48.SDL.1` | delete 'meta_ff <= RESET_VALUE;' | 6:killed | a_one_clock_after_release |
| `input_sync.48.STK.1` | meta_ff stuck at all-zeros (was 'RESET_VALUE') | 6:killed | a_one_clock_after_release |
| `input_sync.48.STK.2` | meta_ff stuck at all-ones (was 'RESET_VALUE') | 6:killed | a_one_clock_after_release |
| `input_sync.48.VNG.1` | meta_ff inverted (was 'RESET_VALUE') | 6:killed | a_one_clock_after_release |
| `input_sync.49.AIM.10` | During reset sync_out shifts in meta_ff instead of being forced to RESET_VALUE, so a stale first-stage sample survives reset entry and power-up leaves sync_out undefined until a clock edge | 6:killed | a_sync_out_reads_RESET |
| `input_sync.49.AIM.5` | sync_out follows the live async_in during reset instead of holding the safe RESET_VALUE | 6:killed | a_sync_out_reads_RESET |
| `input_sync.49.SDL.1` | delete 'sync_out <= RESET_VALUE;' | 6:killed | a_sync_out_reads_RESET |
| `input_sync.49.STK.1` | sync_out stuck at all-zeros (was 'RESET_VALUE') | 6:killed | a_sync_out_reads_RESET |
| `input_sync.49.STK.2` | sync_out stuck at all-ones (was 'RESET_VALUE') | 6:killed | a_sync_out_reads_RESET |
| `input_sync.49.VNG.1` | sync_out inverted (was 'RESET_VALUE') | 6:killed | a_sync_out_reads_RESET |
| `input_sync.52.EDL.1` | delete the else branch at line 52 | 6:lint | make lint: UNUSEDSIGNAL |
| `input_sync.54.SDL.1` | delete 'meta_ff <= async_in;' | 6:lint | make lint: UNUSEDSIGNAL |
| `input_sync.54.STK.1` | meta_ff stuck at all-zeros (was 'async_in') | 6:lint | make lint: UNUSEDSIGNAL |
| `input_sync.54.STK.2` | meta_ff stuck at all-ones (was 'async_in') | 6:lint | make lint: UNUSEDSIGNAL |
| `input_sync.54.VNG.1` | meta_ff inverted (was 'async_in') | 6:killed | a_two_clock_latency |
| `input_sync.55.AIM.11` | A 'fast release' path: the non-safe (released) level goes from async_in straight to sync_out, and only a return to the safe RESET_VALUE goes through meta_ff | 6:killed | a_one_clock_after_release, a_two_clock_latency |
| `input_sync.55.AIM.8` | A 'fast fault path': the safe/asserted level (RESET_VALUE) goes from async_in straight to sync_out, and only the release goes through meta_ff | 6:killed | a_two_clock_latency |
| `input_sync.55.SDL.1` | delete 'sync_out <= meta_ff;' | 6:lint | make lint: UNUSEDSIGNAL |
| `input_sync.55.STK.1` | sync_out stuck at all-zeros (was 'meta_ff') | 6:lint | make lint: UNUSEDSIGNAL |
| `input_sync.55.STK.2` | sync_out stuck at all-ones (was 'meta_ff') | 6:lint | make lint: UNUSEDSIGNAL |
| `input_sync.55.VNG.1` | sync_out inverted (was 'meta_ff') | 6:killed | a_one_clock_after_release, a_two_clock_latency |
| `input_sync.48.AIM.3` | meta_ff resets to the opposite of RESET_VALUE (safe level misremembered for the first stage) | not run (withdrawn at step 4) |  |
| `input_sync.48.AIM.2` | meta_ff resets to a hard-coded 0 instead of RESET_VALUE, so the first stage forgets the safe value | not run (withdrawn at step 4) |  |
| `input_sync.49.AIM.1` | sync_out resets to a hard-coded 0 instead of RESET_VALUE; only meta_ff honours the parameter | not run (withdrawn at step 4) |  |
| `input_sync.54.AIM.12` | The first stage waits for the second stage to catch up (handshake) before taking a new sample of async_in, instead of sampling every clock | not run (withdrawn at step 5) |  |
| `input_sync.54.AIM.9` | RESET_VALUE is read as an input-polarity setting, so the first stage stores async_in inverted whenever RESET_VALUE is 1 | not run (withdrawn at step 4) |  |
| `input_sync.55.AIM.13` | 'Assume the worst' is applied every clock: whenever meta_ff and async_in disagree, sync_out is forced to the safe RESET_VALUE instead of taking meta_ff | not run (withdrawn at step 5) |  |
| `input_sync.55.AIM.14` | The second stage is written as the receiving end of a toggle (pulse) synchroniser: sync_out flips whenever the first stage holds 1, instead of copying the level | not run (withdrawn at step 5) |  |
| `input_sync.55.AIM.15` | The synchroniser output is turned into a rising-edge detector on the synchronised level: sync_out goes high for one clock when meta_ff rises, not for as long as async_in stays high | not run (withdrawn at step 5) |  |
| `input_sync.55.AIM.6` | The second stage becomes a two-sample agreement filter: sync_out takes meta_ff only when it equals the current async_in, otherwise it holds | not run (withdrawn at step 5) |  |
| `input_sync.55.AIM.7` | sync_out is made a sticky latch: once a 1 has passed through it holds 1 until rst_n, as if every synchronised input were a latched fault flag | not run (withdrawn at step 5) |  |
