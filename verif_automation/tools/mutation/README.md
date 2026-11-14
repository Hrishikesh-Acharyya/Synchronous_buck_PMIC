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
| `OPERATORS.md` | The operators, where they apply, and what each outcome means. |

## How a run works

1. Every mutant of the selected modules is listed (3,274 across 17 modules
   and the package at the time of writing, from 26 operators), together with
   the mutants the AI step has written (operator AIM - see "With the AI").
2. `make lint` and each `sim/` target the run will use are run once on the
   unmutated RTL. A failure there stops the run: mutation results on a
   failing baseline mean nothing.
3. For each mutant, in parallel:
   - the RTL tree is copied to `build/mutation/<run>/work/<id>/` and the one
     edit made there - the real `rtl-systemverilog/` is never written;
   - `make lint` screens the copy, in a fraction of a second; a mutant it
     rejects is caught already and is not simulated (about one in seven);
   - the module's own testbench runs against the copy, through the existing
     `sim/` target with `SV_DIR=` pointing at it and its own build folder;
   - the outcome is read from the run's `result.tsv` and logs.
4. `report.txt` and `results.json` are written to `build/mutation/<run>/`;
   with `make mutation_evidence`, copied to `evidence/mutation/` and the run
   added as a row to `evidence/mutation/README.md`.

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
make mutation_evidence                          # everything, saved as evidence - hours
make mutate IDS=reg_file.554.TRN.1 SIM_ARGS="HOSTIF_EVENTS=4000"
                                                # re-run survivors against a longer random walk
```

`JOBS=` sets the parallel runs (default: every core). Each run builds its own
Verilator model, so the first minutes are mostly compiling. The host_if suite
takes about a minute per mutant and covers `reg_file` and `spi_slave`, which
hold over half of all mutants (1,764 of 3,274) - they dominate a full run.

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
each survivor: a real gap, or an edit that changes nothing. This is the
recommended order - the agent sees only the hundred or so mutants that need
a judgement.

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

## What it does not do

- It does not decide whether a survivor is a real gap or an equivalent
  mutant. That judgement is a later step.
- It does not write or change any checker or test.
- It does not call the AI. The AI-written mutants it runs are a file in the
  repository, the same on every run.
