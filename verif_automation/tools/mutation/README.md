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

1. Every mutant of the selected modules is listed (1,197 across 17 modules
   at the time of writing).
2. Each `sim/` target the run will use is run once on the unmutated RTL. A
   target that does not pass stops the run: mutation results on a failing
   baseline mean nothing.
3. For each mutant, in parallel:
   - the RTL tree is copied to `build/mutation/<run>/work/<id>/` and the one
     edit made there - the real `rtl-systemverilog/` is never written;
   - the module's own testbench runs against the copy, through the existing
     `sim/` target with `SV_DIR=` pointing at it and its own build folder;
   - the outcome is read from the run's `result.tsv` and logs.
4. `report.txt` and `results.json` are written to `build/mutation/<run>/`;
   with `make mutation_evidence`, copied to `evidence/mutation/`.

## Which testbench tests which module

| Module | Target |
|---|---|
| every module with a unit testbench | `tb_<module>` |
| `reg_file`, `spi_slave` | `tb_host_if`, the host-interface cocotb suite |
| `pmic_top` | `tb_top`, the integration testbench |

A mutant is run only against its own module's testbench, not the whole
regression, so the score measures each unit's own verification.

## Commands

From `verif_automation/`:

```
make mutants MODULE=input_debounce              # list, no simulation
make mutate MODULE=input_debounce               # one module, a minute or two
make mutate SAMPLE=50                           # a random 50 of all mutants
make mutation_evidence                          # everything, saved as evidence - hours
```

`JOBS=` sets the parallel runs (default: every core). Each run builds its own
Verilator model, so the first minutes are mostly compiling. The host_if suite
takes about a minute per mutant and covers `reg_file` and `spi_slave`, which
hold about half of all mutants - they dominate a full run.

## What it does not do

- It does not decide whether a survivor is a real gap or an equivalent
  mutant. That judgement is a later step.
- It does not write or change any checker or test.
