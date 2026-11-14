# Mutation record: reset_sync

`rtl-systemverilog/clk_rst/reset_sync.sv`. Written by `tools/mutation/record.py` from `reset_sync.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 20 | 15 | 5 | 0 | 0 | 0 | 0 | 0 | 100.0% |
| AI-written | 2 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 100.0% |
| all | 22 | 17 | 5 | 0 | 0 | 0 | 0 | 0 | 100.0% |

Survivors: 0 - 0 decided equivalent, 0 accepted, 0 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 100.0%.

## Survivors (0)

None.

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-14 14:35 | 664452d | AI wrote mutants (claude-fable-5-2) | asked 6, proposed 3, accepted 1, rejected 2; `ai_runs/2026-11-14_write_mutants` |
| 2 | 2026-11-14 14:36 | 664452d | AI wrote mutants (claude-fable-5-2) | asked 6, proposed 2, accepted 1, rejected 1; `ai_runs/2026-11-14_write_mutants_2` |
| 3 | 2026-11-14 14:44 | 664452d | AI wrote mutants (claude-fable-5-2) | asked 15, proposed 2, accepted 0, rejected 2; `ai_runs/2026-11-14_write_mutants_5` |
| 4 | 2026-11-14 14:51 | 664452d | mutation run - every mutant of the module | 22 mutants: 17 killed, 5 lint; score 100.0% |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (2)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | wrong_event | The first stage's asynchronous event is the rising edge of rst_n_enter instead of the falling edge, so meta_ff is set at the moment of release rather than cleared at assertion. | killed | a_no_early_release |
| 2 | 2 | wrong_event | The second stage's asynchronous event is the rising edge of rst_n_enter instead of the falling edge, so rst_n_exit no longer asserts the instant rst_n_enter falls - it waits for the next clk edge. | killed | a_exit_low_in_reset |

Rejected by the gate in step 1 (2):

- The output stage loses its asynchronous clear: rst_n_exit is cleared by rst_n_enter only at a clock edge (a synchronous reset). - **make lint already catches it: make lint: SYNCASYNCNET**
- The first synchronizer stage is cleared only synchronously, so meta_ff survives a reset pulse that does not span a rising clock edge. - **make lint already catches it: make lint: SYNCASYNCNET**

Rejected by the gate in step 2 (1):

- The first stage clears synchronously only: meta_ff is not put back to 0 by a reset assertion that does not span a clk edge, so it keeps its 1 from before the reset. - **make lint already catches it: make lint: SYNCASYNCNET**

Rejected by the gate in step 3 (2):

- The first stage's clear is synchronous: meta_ff is cleared only if a clk edge samples rst_n_enter low, instead of the instant rst_n_enter falls. - **make lint already catches it: make lint: SYNCASYNCNET**
- The second stage's clear is synchronous: rst_n_exit asserts only on a clk edge, not asynchronously with the fall of rst_n_enter. - **make lint already catches it: make lint: SYNCASYNCNET**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `reset_sync.28.AIM.1` | The first stage's asynchronous event is the rising edge of rst_n_enter instead of the falling edge, so meta_ff is set at the moment of release rather than cleared at assertion. | 4:killed | a_no_early_release |
| `reset_sync.28.EDG.1` | posedge clk -> negedge clk | 4:killed | a_no_early_release |
| `reset_sync.38.CSK.1` | if (!rst_n_enter) -> if (1'b0): never taken | 4:killed | a_no_early_release |
| `reset_sync.38.CSK.2` | if (!rst_n_enter) -> if (1'b1): always taken | 4:killed | a_release_on_time |
| `reset_sync.38.SIB.1` | rst_n_enter -> rst_n_exit | 4:lint | make lint: SYNCASYNCNET |
| `reset_sync.38.UOD.1` | drop the '!' before rst_n_enter | 4:killed | a_no_early_release, a_release_on_time |
| `reset_sync.40.CST.1` | 1'b0 -> 1'b1 | 4:killed | a_no_early_release |
| `reset_sync.40.SDL.1` | delete 'meta_ff <= 1'b0;' | 4:killed | a_no_early_release |
| `reset_sync.45.CST.1` | 1'b1 -> 1'b0 | 4:killed | a_release_on_time |
| `reset_sync.45.SDL.1` | delete 'meta_ff <= 1'b1;' | 4:killed | a_release_on_time |
| `reset_sync.51.AIM.2` | The second stage's asynchronous event is the rising edge of rst_n_enter instead of the falling edge, so rst_n_exit no longer asserts the instant rst_n_enter falls - it waits for the next clk edge. | 4:killed | a_exit_low_in_reset |
| `reset_sync.51.EDG.1` | posedge clk -> negedge clk | 4:killed | a_no_early_release |
| `reset_sync.61.CSK.1` | if (!rst_n_enter) -> if (1'b0): never taken | 4:killed | a_exit_low_in_reset, a_no_early_release |
| `reset_sync.61.CSK.2` | if (!rst_n_enter) -> if (1'b1): always taken | 4:killed | a_release_on_time |
| `reset_sync.61.SIB.1` | rst_n_enter -> rst_n_exit | 4:lint | make lint: SYNCASYNCNET |
| `reset_sync.61.UOD.1` | drop the '!' before rst_n_enter | 4:killed | a_release_on_time, a_exit_low_in_reset +1 |
| `reset_sync.63.CST.1` | 1'b0 -> 1'b1 | 4:killed | a_exit_low_in_reset, a_no_early_release |
| `reset_sync.63.SDL.1` | delete 'rst_n_exit <= 1'b0;' | 4:killed | a_exit_low_in_reset, a_no_early_release |
| `reset_sync.68.SDL.1` | delete 'rst_n_exit <= meta_ff;' | 4:lint | make lint: UNUSEDSIGNAL |
| `reset_sync.68.STK.1` | rst_n_exit stuck at all-zeros (was 'meta_ff') | 4:lint | make lint: UNUSEDSIGNAL |
| `reset_sync.68.STK.2` | rst_n_exit stuck at all-ones (was 'meta_ff') | 4:lint | make lint: UNUSEDSIGNAL |
| `reset_sync.68.VNG.1` | rst_n_exit inverted (was 'meta_ff') | 4:killed | a_no_early_release, a_release_on_time |
