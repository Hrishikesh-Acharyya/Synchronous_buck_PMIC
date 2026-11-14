# tools/mutation

Mutation testing: how much of the RTL's behaviour the verification actually
checks. Each mutant is one small edit to one RTL file - the kind of slip a
designer makes. If the module's testbench and bound checker still pass with
the edit in place, that behaviour is not being checked, or the edit changed
nothing.

| File | What it is |
|---|---|
| `mutants.py` | Finds the mutation sites and makes the mutants. The operators are in `OPERATORS.md`. |
| `run_mutation.py` | Runs the mutants and writes the report. |
| `record.py` | Keeps each module's mutation record: every step run on it, every mutant's outcome in every run. |
| `OPERATORS.md` | The operators, where they apply, and what each outcome means. |

## How a run works

1. Every mutant of the selected modules is listed (3,274 across 17 modules
   and the package at the time of writing, from 26 operators), together with
   the mutants the AI step has written (operator AIM - see "With the AI").
2. `make lint` and each `sim/` target the run will use are run once on the
   unmutated RTL. A failure there stops the run: mutation results on a
   failing baseline mean nothing.
3. For each mutant, in parallel:
   - the RTL tree is copied to a scratch folder and the one edit made there -
     the real `rtl-systemverilog/` is never written. The scratch copies and
     their builds go under `~/build/sync_buck/mutation/<run>/`, beside the
     `sim/` builds and outside the repository: a Verilator build writes
     hundreds of small files, which is slow on a Windows mount;
   - `make lint` screens the copy, in a fraction of a second; a mutant it
     rejects is caught already and is not simulated (about one in seven);
   - the module's own testbench runs against the copy, through the existing
     `sim/` target with `SV_DIR=` pointing at it and its own build folder;
   - the outcome is read from the run's `result.tsv` and logs. For a killed
     mutant, what killed it is read too: the assertions that fired, the
     cocotb tests that failed, the testbench checks that failed;
   - the outcome is appended to `build/mutation/<run>/progress.jsonl` at
     once, so nothing finished is ever lost.
4. `report.txt` and `results.json` are written to `build/mutation/<run>/`,
   and the run is added to the record of every module it touched (below).

## One module at a time, one record per module

The work goes module by module, and each module has one record that
everything is added to: `evidence/mutation/<module>.json`, with
`<module>.md` beside it - the same record written out to be read. Nothing in
a record is ever replaced:

- `make ai_mutants MODULE=m` adds the mutants the agent wrote, and every
  proposal the gate rejected with the check it failed. Run it again and the
  second run's are added beside the first's;
- `make mutate MODULE=m` adds each mutant's outcome. Run it again - after a
  checker is strengthened, say - and each mutant has two outcomes, oldest
  first;
- `make judge MODULE=m` adds the agent's judgement to each survivor you have
  not decided. Run again, it adds a second judgement;
- `make decide` adds your own decision on a survivor, with its reason.

The record's **Now** section is the present state - each mutant's newest
outcome, and the score over those. Its **History** lists every step in
order, with its date, commit and result, so every earlier score is there
too. A mutant is known by what it is (its operator and the line before and
after), not by its line number, so its history follows it when lines above
it move. If the RTL changes so that a mutant is no longer made, it is kept
and marked retired, out of the present score.

```
make ai_check                            # once: the agent is installed, logged in, read-only
make ai_mutants MODULE=fault_cause       # the agent writes design-aware mutants; again for more
make mutants_check MODULE=fault_cause    # every mutant is legal code
make mutate MODULE=fault_cause           # run them
make status MODULE=fault_cause           # the score, and the survivors still open
make judge MODULE=fault_cause            # the agent's opinion on each open survivor
make decide IDS=fault_cause.88.CTD.1 AS=equivalent WHY="the term is implied by the state"
make decide IDS=fault_cause.92.SDL.1 AS=gap WHY="the clear on re-entry is not checked"
#   ... add the property or test that closes the gap, then:
make mutate IDS=fault_cause.92.SDL.1     # killed now - added to that mutant's history
```

`AS=` is `equivalent` (the edit changes nothing that can be observed),
`accepted` (a real difference left open on purpose) or `gap` (real, still to
be closed). `evidence/mutation/README.md` shows every module's present state
in one table. Commit the records as you go.

`RECORD=0` on any of these leaves a run out of the records - for trying the
tools, not for testing the design. A run that is stopped is recorded when it
is continued and finishes.

## A run of hours

A full run is 3,274 mutants and takes hours, so it is built to be stopped
and to fail safely:

- **Stop and continue.** Ctrl-C, a closed terminal or a kill stops it
  cleanly: running simulations are ended, and the last line printed is the
  command that continues it - `make mutate RESUME=build/mutation/<run>`. A
  continued run keeps its own selection and seed, repeats nothing, and
  refuses to continue if the RTL, checkers or testbenches have changed since.
- **A hung simulation cannot stall it.** Each simulation runs in its own
  process group and has a time limit of ten times its testbench's unmutated
  run (two minutes at least). At the limit the whole group is killed and the
  mutant is recorded as `timeout`.
- **A crash is not a kill.** The report's WHAT KILLED THEM section counts the
  kills by what failed. A run that ended FAIL with no assertion, test or
  check named in its log is listed by name, to be looked at.
- **A failure of the tool is not a result.** If the tool itself fails on a
  mutant - the disk is full, a file cannot be copied - that mutant is
  recorded as `error`, left out of the score and listed, to be run again
  with `IDS=`.
- Every five minutes it prints the time gone and an estimate of the time
  left.

For scale: on a 4-core machine the host_if suite takes about 25 seconds a
mutant and the integration testbench about two minutes, four at a time -
roughly five hours for everything, as an estimate from short runs. `JOBS=` defaults to every core.

The random tests inside a suite - the host_if suite's random walk - run with
one fixed seed (`SEED=`, default 1), the same for the baseline and every
mutant. A mutant's outcome is therefore the same every time it is run.

## Which testbench tests which module

| Module | Target |
|---|---|
| every module with a unit testbench | `tb_<module>` |
| `reg_file`, `spi_slave` | `tb_host_if`, the host-interface cocotb suite |
| `pmic_top`, and the package's functions | `tb_top`, the integration testbench |

A mutant is run only against its own module's testbench, not the whole
regression, so the score measures each unit's own verification.

## Commands

From `verif_automation/`:

```
make mutants MODULE=input_debounce              # list, no simulation
make mutants_check                              # lint-screen all, no simulation - a few minutes
make mutate MODULE=input_debounce               # one module, a minute or two
make mutate SAMPLE=50                           # a random 50 of all mutants
make mutate RESUME=build/mutation/<run>         # continue a run that was stopped
make mutate IDS=reg_file.554.TRN.1 SIM_ARGS="HOSTIF_EVENTS=4000"
                                                # re-run survivors against a longer random walk
```

`JOBS=` sets the parallel runs (default: every core). Each run builds its own
Verilator model, so the first minutes are mostly compiling. The host_if suite
takes about a minute per mutant and covers `reg_file` and `spi_slave`, which
hold over half of all mutants (1,764 of 3,274) - they dominate a full run.

## What survives on purpose

One class of survivor comes from the simulator, not from the checkers:
Verilator is a two-state simulator and starts every register at 0. A mutant
that removes a reset to 0, or never takes the reset branch, behaves the same
unless the reset is applied again later with the register away from 0.
Decide each as `gap` and add a mid-run reset to the testbench, or as
`accepted` with that reason.

## With the AI

Before a run, `make ai_mutants` has an AI agent write the mutants the
operators cannot: faults that need the design's meaning. The agent only
proposes; a deterministic gate decides what is stored in `../../ai/mutants/`,
and this runner loads what is there as operator AIM - listed, screened,
simulated and scored exactly like the rest (`OPERATORS=AIM` selects them).
Each is kept as the lines it replaces and the lines it puts there, so it is
found again when the file's line numbers move. If the lines themselves have
changed, the mutant can no longer be placed: it is left out, and the list and
the report say so by name.

After a run, `make judge` (see `../../ai/README.md`) has an AI agent judge
each survivor in the records that you have not decided: a real gap, or an
edit that changes nothing. This is the recommended order - the agent sees
only the mutants that need a judgement. Its judgement is an opinion added to
the record; the decision is yours (`make decide`).

The other order is possible too. `make triage` has the agent judge every
mutant before simulation, and `make mutate TRIAGE=build/mutation/triage.json`
then uses those verdicts. With `AUDIT=all`, the default, every mutant is
still simulated, and the report's AI TRIAGE section lists each mutant the
agent called equivalent that a test killed - a triage error. With a smaller
`AUDIT=`, the unaudited ones are not simulated and are left out of the score
(`ai_equiv`). The agent's reason is printed beside every survivor.

## Reading the result

A run gives a score and a list. The score is the share of mutants the
verification caught; the list is every survivor, with its line before and
after the edit. A survivor is one of two things, and the tool does not say
which:

- a **gap**: the edit changed the design's behaviour and nothing noticed.
  Closed by adding the property or test that notices, then re-running that
  mutant (`IDS=`) to see it killed;
- an **equivalent mutant**: the edit changed nothing that can be observed -
  unreachable code, a redundant condition. Closed by recording why.

A survivor that hits fewer SVA covers than the unmutated run is marked: the
edit took a scenario away, which usually means it is not equivalent.

## What score to aim for

Not 100%. Some mutants change nothing that can be observed - the edited code
never runs, or the two forms are the same under an invariant of the module -
and no test can ever kill those. A raw score of 100% would mean a test had
been bent to fail on a design that still works.

The aim is **no unexplained survivor**. Every survivor ends as one of:

1. **killed** - a property or test was added or strengthened, and the mutant
   re-run with `IDS=` now dies. This is a gap closed;
2. **equivalent** - with the reason written down: which line never runs, or
   which invariant makes the two forms the same;
3. **accepted** - a real difference that the verification leaves open on
   purpose, with the reason: behaviour outside the conditions the module's
   header allows, say.

What to read besides the total:

- **the score per module**, not only overall. A unit-tested module should
  end in the high nineties, its remainder all in group 2. `pmic_top` is
  tested through the integration testbench alone and will sit lower;
- **CAUGHT ONLY BY A LOST COVER** - counted as caught, but no check failed:
  the behaviour is observed, not checked. Treat each as a survivor;
- **the AIM row** - the AI-written mutants are the faults a designer would
  really make. A survivor there is the first to look at;
- **WHAT KILLED THEM** - a module whose kills come from tests and never from
  its bound checker has a checker that states little.

Do not raise the score by removing mutants or operators. A first run in the
eighties is normal; the work that follows is the result, not the number.

## What it does not do

- It does not decide whether a survivor is a real gap or an equivalent
  mutant. That judgement is a later step.
- It does not write or change any checker or test.
- It does not call the AI. The AI-written mutants it runs are a file in the
  repository, the same on every run.
