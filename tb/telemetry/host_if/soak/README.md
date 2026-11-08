# Soak evidence: host interface (spi_slave + reg_file)

Output of `make soak` in `tb/telemetry/host_if`: constrained-random `random_walk` runs, each with a new seed, checked by the scoreboard and reference model, with the bound SVA checkers active. A soak never stops on a failure, so every seed runs.

Only these five files are tracked. A new `make soak` replaces the last four; this README is never touched.

| File | Contents |
|---|---|
| `results.txt` | Start and end time, then one line per run: `PASS`/`FAIL` and its seed. Every line can be replayed with `make replay SEED=<seed> EVENTS=<events>`. |
| `summary.txt` | Covers hit vs. at zero for each checker (`reg_file_sva`, `spi_slave_sva`), then every cover that no run reached. |
| `all_events.csv` | Every event of every run under one header: seed, event number, kind, what was sent, and the DUT state after it. |
| `merged.dat` | The merged Verilator coverage of all runs, which `summary.txt` was computed from. `make cov_summary` and `make cov_zero` read it. |

Per-run files (`runN.log`, `events_runN.csv`, `cov_runN.dat`) are written to `raw/`. They stay on disk for digging into one run, but are gitignored.

## Latest soak

- **40 runs × 200 events = 8,000 random events**, 8 Nov 2026, about 1.5 hours.
- **40 of 40 runs passed**: no scoreboard mismatch and no assertion failure.
- **Event mix**: reads 1,891; threshold writes 1,560; raw writes 1,157; control writes 937; scratch 621; time 568; supervisor-state changes 522; status reads 513; switch events 231.
- **Coverage**: `reg_file_sva` 24 of 26 covers hit, `spi_slave_sva` 18 of 27.

The covers at zero are listed in `summary.txt`: SCK timeouts, mid-byte and short-frame aborts, a read closed mid-byte, truncated commands, the arm-key lapse and bus-error saturation. This soak predates the broken-frame events in `random_walk` and the directed tests that reach these cases. A soak runs `random_walk` only, so for the coverage of the whole testbench see `../coverage/summary.txt`, written by `make cov_all`.

## Reproducing

```bash
cd tb/telemetry/host_if
make soak SEEDS=40 EVENTS=200
```
