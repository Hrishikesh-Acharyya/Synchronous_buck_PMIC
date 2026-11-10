# Soak evidence: whole supervisor (pmic_top)

Output of `make soak` in `tb/top/pmic_top`: constrained-random `random_walk` runs, each with a new seed, checked against the supervisor model after every board event, with `pmic_top_sva` and every block's checker bound. A soak never stops on a failure, so every seed runs.

Only these six files are tracked. A new `make soak` replaces the last five; this README is never touched.

| File | Contents |
|---|---|
| `results.txt` | Start and end time, then one line per run: `PASS`/`FAIL` and its seed. Every line can be replayed with `make replay SEED=<seed> EVENTS=<events>`. |
| `summary.txt` | `pmic_top_sva` covers hit vs. at zero, every cover no run reached, then the covergroup report. |
| `all_events.csv` | Every event of every run under one header: seed, event number, kind, what was done, the condition it arrived in, and the settled state after it. |
| `merged.dat` | The merged Verilator coverage of all runs, which `summary.txt` was computed from. `make cov_summary` and `make cov_zero` read it. |
| `functional_coverage.xml` | The merged covergroups of all runs (cocotb-coverage); their readable report closes `summary.txt`. |

Per-run files (`runN.log`, `events_runN.csv`, `cov_runN.dat`, `fcov_runN.xml`) are written to `raw/`. They stay on disk for digging into one run, but are gitignored.

## Latest soak

Not run yet on the current testbench.

The first soak (10 Nov, 30 runs x 150 events) is not evidence. 21 of its 30 runs failed but were recorded as PASS: the soak judged a run by make's exit status, and cocotb 1.x exits 0 when a test fails. Its 109/109 covergroup bins came from the 9 runs that finished. All 21 failures were the testbench's model, not the RTL, missing two documented behaviours:

- a glitch that arrives while that input is still being debounced (the switch's 20 ms after a reset, typically) restarts the count, so the transition lands a full debounce after the glitch;
- a debounced switch turn-on re-enables the host enable, cancelling a host disable (reg_file applies `en_switch_rise` last).

The model now has both, `host_disable_and_enable` checks the second directly, and a run now passes only if its `results.xml` holds a test and no failure.

## Reproducing

```bash
cd tb/top/pmic_top
make soak SEEDS=64 EVENTS=200
```

or, from `sim/`, `make soak_top_cocotb`. The soak binds every checker - `pmic_top_sva` and all 16 block checkers - and runs one seed per core. A 200-event run takes about 10 minutes, so 64 runs on 8 cores take about 80 minutes. `SOAK_CHECKERS=top` binds `pmic_top_sva` alone, about ten times faster.
