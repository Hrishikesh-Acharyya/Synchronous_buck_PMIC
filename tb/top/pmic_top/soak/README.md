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

- **64 runs x 200 events, every checker bound** (`pmic_top_sva` and all 16 block checkers), 8 at a time, 10 Nov 2026 17:56 to 11 Nov 03:30 (9 h 34 min on the author's laptop, WSL on a Windows drive).
- **62 of 64 runs passed.** Runs 41 and 58 failed on a STATUS bit; both were the testbench's model, not the RTL (see below). The log holds 12,556 events.
- **Event mix**: trips 1,733; UVLO 1,682; OTP 1,624; host commands 1,533; waits 1,167; threshold writes 879; switch 876; glitches 864; rail 846; reset button 697; OVP 305; faults during a hiccup 200; persistent overcurrents 130; clean runs 20.
- **Covergroups**: **112 of 112 bins hit** - every event from every condition, every stop from S_RUN and mid-hiccup, every strike level under every MAX_STRIKES, every recovery path, both latch sources, every glitch (settled and mid-debounce), every PGOOD edge.
- **SVA covers**: `pmic_top_sva` 13 of 14. `c_pwm_truncated` (a modulator pulse cut at MAX_ON) needs the modulator above the ceiling, which the walk does not drive; the directed test `pwm_passed_and_capped` hits it.
- **Independent audit** (`make audit_soak`, `audit_soak.py`): every one of the 12,492 transitions checked against the supervisor's documented rules without the model - running only with every enable and no fault or latch; En and PGOOD consistent with the state; 658 strike rises, each on an overcurrent while running, one per trip; 438 strike clears, each by the reset button or a clean run; 503 latch sets and 492 clears, each by its own cause; 931 host disables and 925 restores, each by a host command, the reset button or the switch; every knob moved only by its own event. **No anomalies.** The audit was itself shown to fail on planted faults.

### The two failures

Both were replayed with every checker (`make replay`), with the model's timing printed, and reproduced on purpose in a probe test that the old model fails and the corrected one passes:

- **Run 41** - a check that ended 20 us after the switch's 20 ms debounce edge, which follows a reset button press. The design's STATUS byte is sampled during the SPI read, tens of microseconds before the check ends: it still showed the switch off, correctly. The model judged the switch at the end of the check. The switch bit and the host enable are now left unchecked within 0.5 ms of that edge, as PGOOD and the clean-run window already are.
- **Run 58** - a 15 ms switch blip that started before the switch's debounced rise after a reset. In the design the blip restarted the debounce, so the rise - and the host re-enable it carries - did not happen, correctly. The model caught up on time first, applying the rise, and only then handled the glitch. It now decides the glitch first.

The corrected model passes the full suite (22 of 22, every checker) and fresh walks; the two seeds are replayed with it to close the module.

## Reproducing

```bash
cd tb/top/pmic_top
make soak SEEDS=64 EVENTS=200
```

or, from `sim/`, `make soak_top_cocotb`. The soak binds every checker - `pmic_top_sva` and all 16 block checkers - and runs one seed per core. A 200-event run takes about 10 minutes here; on a laptop under WSL with all 8 cores busy, 64 runs took 9.5 hours. `SOAK_CHECKERS=top` binds `pmic_top_sva` alone, about ten times faster.
