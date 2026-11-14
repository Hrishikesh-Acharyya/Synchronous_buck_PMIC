# Soak evidence: host interface (spi_slave + reg_file)

Output of `make soak` in `tb/telemetry/host_if`: constrained-random `random_walk` runs, each with a new seed, checked by the scoreboard and reference model, with the bound SVA checkers active. A soak never stops on a failure, so every seed runs.

Only these six files are tracked (and `make audit_soak` reads `all_events.csv`). A new `make soak` replaces the last five; this README is never touched.

| File | Contents |
|---|---|
| `results.txt` | Start and end time, then one line per run: `PASS`/`FAIL` and its seed. Every line can be replayed with `make replay SEED=<seed> EVENTS=<events>`. |
| `summary.txt` | Covers hit vs. at zero for each checker (`reg_file_sva`, `spi_slave_sva`), then every cover that no run reached. |
| `all_events.csv` | Every event of every run under one header: seed, event number, kind, what was sent, and the DUT state after it. |
| `merged.dat` | The merged Verilator coverage of all runs, which `summary.txt` was computed from. `make cov_summary` and `make cov_zero` read it. |
| `functional_coverage.xml` | The merged covergroups of all runs (cocotb-coverage); their readable report closes `summary.txt`. |

Per-run files (`runN.log`, `events_runN.csv`, `cov_runN.dat`) are written to `raw/`. They stay on disk for digging into one run, but are gitignored.

## Latest soak - the closing run for this module

- **200 runs x 200 events = 40,000 random events**, 10 Nov 2026, 01:06 to 15:27, one seed at a time, on the current RTL (the S_OFF write-back change included).
- **200 of 200 runs passed**: every seed reaches event 200 in `all_events.csv`, and every run log ends `FAIL=0` with no `SVA FAIL` line - no read, scoreboard or assertion failure in any run. (This soak predates the change that judges a run by its `results.xml`, so the logs were checked for the final scoreboard and SVA verdict: 200 of 200 `FAIL=0`, 0 logs with an SVA failure.)
- **Event mix**: reads 8,834; threshold writes 7,120; raw writes 5,380; control writes 4,183; SCRATCH 2,828; status-input changes 2,523; time steps 2,459; supervisor-state changes 2,429; broken writes 2,117; broken reads 1,096; switch pulses 1,031.
- **Covergroups**: **83 of 83 bins hit** - every threshold verdict, including the new `writeback` (889 frames written back through the S_OFF-only registers while the converter ran, all accepted) and `not_off` (735 refused for changing one), in every supervisor state; every way a frame can end; every threshold register committed below, at and between its bounds.
- **SVA covers**: `spi_slave_sva` 28 of 28; `reg_file_sva` 26 of 28. The two at zero, `c_arm_lapse` and `c_bus_err_saturated`, need a 1.4 ms SCK stall and 65,535 aborts; random traffic is not meant to produce either, and the directed tests `arm_key_lapses` and `bus_error_counter_saturates` hit both.
- **Independent audit** (`make audit_soak`, `audit_soak.py`): every one of the 39,800 transitions checked against the register-map rules without the model. 6,886 threshold frames recomputed from their bytes - 3,026 accepted, 3,860 rejected - every committed value and every `write_rejected` as the rules say; 558 disables, each from a keyed CONTROL write; 182 watchdog restores, each after host silence; every bad-CRC write counted one bus error; a broken read counts one exactly when cut inside its command byte (202 of 202), never after it (886 of 886). **No anomalies.** The audit was itself shown to fail on planted faults.

## Verification closure

| Evidence | What it shows |
|---|---|
| this soak | 40,000 random events, 200 of 200 runs passed, no anomaly in the audit; covergroups 83/83 |
| `../coverage/summary.txt` (`make cov_all`, 10 Nov, current RTL) | the directed tests plus random runs: SVA covers `reg_file_sva` 28/28, `spi_slave_sva` 28/28 |

Together with the bound checkers (every assertion shown able to fail) and the reference model compared on every read and scoreboard check, the host interface - `spi_slave` and `reg_file` - is verified. **Closed 10 Nov 2026.**

## Reproducing

```bash
cd tb/telemetry/host_if
make soak SEEDS=100 EVENTS=200
```

or, from `sim/`, `make soak_host_if`. Seeds run one per CPU core: a 200-event seed takes about 3 minutes, so 100 seeds on 8 cores take about 40 minutes (the closing soak above ran one seed at a time, 5 h 32 min).
