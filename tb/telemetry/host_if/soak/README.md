# Soak evidence: host interface (spi_slave + reg_file)

Output of `make soak` in `tb/telemetry/host_if`: constrained-random `random_walk` runs, each with a new seed, checked by the scoreboard and reference model, with the bound SVA checkers active. A soak never stops on a failure, so every seed runs.

Only these six files are tracked. A new `make soak` replaces the last five; this README is never touched.

| File | Contents |
|---|---|
| `results.txt` | Start and end time, then one line per run: `PASS`/`FAIL` and its seed. Every line can be replayed with `make replay SEED=<seed> EVENTS=<events>`. |
| `summary.txt` | Covers hit vs. at zero for each checker (`reg_file_sva`, `spi_slave_sva`), then every cover that no run reached. |
| `all_events.csv` | Every event of every run under one header: seed, event number, kind, what was sent, and the DUT state after it. |
| `merged.dat` | The merged Verilator coverage of all runs, which `summary.txt` was computed from. `make cov_summary` and `make cov_zero` read it. |
| `functional_coverage.xml` | The merged covergroups of all runs (cocotb-coverage); their readable report closes `summary.txt`. |

Per-run files (`runN.log`, `events_runN.csv`, `cov_runN.dat`) are written to `raw/`. They stay on disk for digging into one run, but are gitignored.

## Latest soak - the closing run for this module

> Recorded before the S_OFF write-back change: `reg_file` now accepts the S_OFF-only registers (`hiccup_base`, `cycles_per_step`, `clean_run_target`) written back with their present value in any state, and refuses only a change. That added a `writeback` threshold reason (covergroups now 83 bins) and two `reg_file_sva` covers. The figures below are the last soak's; a new `make soak` is needed to close the module again.

- **100 runs × 200 events = 20,000 random events**, 9 Nov 2026, 02:22 to 07:55 (5 h 32 min).
- **100 of 100 runs passed**: no scoreboard mismatch, no read mismatch and no assertion failure in any run.
- **Event mix**: reads 4,367; threshold writes 3,538; raw writes 2,655; control writes 2,165; SCRATCH 1,449; time steps 1,260; status-input changes 1,239; supervisor-state changes 1,218; broken writes 1,101; switch pulses 522; broken reads 486.
- **Covergroups**: **79 of 79 bins hit** - every threshold verdict in every supervisor state, every way a frame can end, and every threshold register committed below, at and between its bounds.
- **SVA covers**: `spi_slave_sva` 28 of 28; `reg_file_sva` 24 of 26. The two at zero, `c_arm_lapse` and `c_bus_err_saturated`, need a 1.4 ms SCK stall and 65,535 aborts; random traffic is not meant to produce either, and the directed tests `arm_key_lapses` and `bus_error_counter_saturates` hit both.

## Verification closure

Every SVA cover and every covergroup bin is hit by at least one recorded run:

| Evidence | What it shows |
|---|---|
| this soak | 20,000 random events with no failure; covergroups 79/79 |
| `../coverage/summary.txt` (`make cov_all`) | the directed tests plus random runs: SVA covers `reg_file_sva` 26/26, `spi_slave_sva` 28/28 |

Together with the bound checkers (every assertion shown able to fail) and the reference model compared on every read and scoreboard check, the host interface - `spi_slave` and `reg_file` - is verified.

## Reproducing

```bash
cd tb/telemetry/host_if
make soak SEEDS=100 EVENTS=200
```

or, from `sim/`, `make soak_host_if`. Seeds run one per CPU core: a 200-event seed takes about 3 minutes, so 100 seeds on 8 cores take about 40 minutes (the closing soak above ran one seed at a time, 5 h 32 min).
