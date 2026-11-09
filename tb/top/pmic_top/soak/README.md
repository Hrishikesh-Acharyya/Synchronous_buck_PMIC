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

Not run yet.

## Reproducing

```bash
cd tb/top/pmic_top
make soak SEEDS=30 EVENTS=150
```

A walk event averages about 5 ms of simulated time, so a 150-event run takes roughly 12 minutes and 30 runs about six hours.
