# pmic_top testbench — commands

cocotb testbench for the whole supervisor: `pmic_top` inside `pmic_top_harness`, a behavioural model of the board around it. Run from this folder with the venv active:

    source ~/venv-hdl/bin/activate
    cd tb/top/pmic_top

From `sim/`, `make tb_top_cocotb` / `make equiv_top_cocotb` run this whole suite on the SystemVerilog source / the converted Verilog and list it as `pmic_top_cocotb` in the result tables.

## What it checks

| Layer | Where | What |
|---|---|---|
| Wiring claims (I) | `sva/top/pmic_top_sva.sv`, bound | reset safe; En only in S_SS/S_RUN and only with every enable given and no hard fault; gate PWM only when the modulator asked; PGOOD only in S_RUN, `switch_supply` = PGOOD; MISO silent without telemetry |
| Every block's own claims | every checker in `sva/`, bound | as in the module testbenches, now with the real neighbours instead of driven inputs |
| Settled outcomes (M) | `supervisor_model.py`, `board.check()` | after each board event: En, PGOOD, LEDs, latch pins, and over SPI STATUS and STRIKE_LEVEL |
| Design intent (edge cases) | the edge-case tests below | what the blocks' contracts imply once wired together: window thresholds to the cycle, back-off timing, strikes that survive stops, debounce trade-offs, a stalled modulator |
| Functional coverage | `top_coverage.py`, sampled by `random_walk` | which combinations of board-level meaning the random walk reached |

The model keeps simulation time: each enabling input becomes effective after its own debounce, and the ramp follows the last of them, so it knows when the converter entered S_RUN. From that it predicts PGOOD (9 ms of good rail) and the clean-run clear of the strikes. Within 0.5 ms of either boundary it reports the field as unknown and `check()` skips that field only.

## Running tests

| Command | What it does |
|---|---|
| `make` | every test in `test_pmic_top.py` (about 0.5 s simulated, a few minutes) |
| `make TESTCASE=<name>` | one test, e.g. `make TESTCASE=persistent_overcurrent_latches` |
| `make TELEMETRY_EN=0` | build the reduced design instead (the tests that use SPI need the full build) |
| `make random` | `random_walk` once, `EVENTS` events (default 30), a new seed |
| `make quick` | `random_walk` once, 8 events - while editing |
| `make replay SEED=<n> EVENTS=<n>` | rerun the exact walk the log names |
| `make random_seeds` | `SEEDS` walks (default 5), stop at the first failure, merge SVA and covergroup coverage into `cov/` |
| `make cov_all` | the whole suite once plus `SEEDS` walks, merged; the summary goes to `coverage/summary.txt` (tracked) |
| `make soak SEEDS=<n> EVENTS=<n>` | unattended sweep that never stops on a failure; evidence in `soak/` (tracked), per-run files in `soak/raw/` |
| `make cov_summary` / `make cov_zero` | `pmic_top_sva` covers hit, and the ones at zero, in the newest merge (or `MERGED=<file>`) |
| `make clean_cov` | delete `cov/`'s files; soak evidence is kept |

A walk event costs 1 to 22 ms of simulated time (a switch or reset waits out the 20 ms debounce; a clean-run event about 100 ms), about 5 ms on average. At roughly 2 ms simulated per second, 30 events take a minute or two and a 200-event soak run about 10 minutes.

## Tests

| Test | Board events |
|---|---|
| `reset_is_safe` | reset: outputs safe, fail-safe fault LEDs until their release |
| `power_up_to_run_and_pgood` | switch on, ramp, S_RUN, PGOOD; rail out of window and back |
| `pwm_passed_and_capped` | gate pulse = modulator pulse; a long pulse cut to MAX_ON + 1 |
| `overcurrent_hiccup_and_retry` | one trip: hiccup, retry, one strike outstanding |
| `persistent_overcurrent_latches` | strikes to the latch; no restart; the reset button recovers |
| `otp_and_uvlo_stop_and_recover` | each fault from S_RUN and back |
| `host_disable_and_enable` | keyed host disable and enable over SPI |
| `analog_ovp_trip` | the SCR tripped by the board, not the CPLD |
| `switch_off_and_on` | the physical switch |
| `strikes_clear_after_clean_run` | a strike forgotten after the 100 ms clean window |

### Design-intent edge cases

| Test | What it pins down |
|---|---|
| `window_thresholds_exact` | `oc_per16` faults N of every 16 cycles: in S_RUN 11 never trips and 12 does; in S_SS 13 per 16 (26 of 32) ramps through and 14 (28) trips |
| `overcurrent_seen_above_ceiling` | a modulator pulse of 108/111 leaves 3 clocks of its own low phase, less than the 5-clock lookback; the sample lands in pwm_mask's cut, where the low-side FET conducts, and still trips |
| `hiccup_backoff_doubles` | trip within 14 cycles of a persistent overcurrent; cool-downs 2 ms then 4 ms (base doubled per strike, level after the increment); the third entry latches and En never returns |
| `strikes_survive_stops` | a host disable or an OTP stop does not clear the strikes; three separate episodes latch |
| `max_strikes_lowered_live` | MAX_STRIKES written 0 reads back 1; it acts at the next hiccup entry, not at once; strike 2 then latches |
| `max_on_lowered_while_running` | MAX_ON lowered in S_RUN reads back at once but reaches the gate at the next soft start; until then the gate keeps the ceiling the last ramp reached (deliberate: the ceiling only moves through a ramp) |
| `fault_during_hiccup` | UVLO or a host disable during the cool-down ends in S_OFF with no retry and the strike kept |
| `short_glitches_filtered` | 0.8 ms OTP/UVLO pulses, OTP chattering 0.9 ms on / 0.05 ms off, a 15 ms switch drop-out, a 0.1 ms release of a live OTP: none changes anything |
| `modulator_stall` | modulator stopped: enabled into S_SS and waits there; stuck high: one pulse at MAX_ON + 1, then no gate drive |
| `reset_mid_run` | outputs low within 3 clocks; strikes and programmed timers back to reset values; restarts by itself on the reset timers |
| `latched_and_faulted_while_off` | OVP and OTP before the switch: nothing starts; reset drains the SCR but not a live OTP |

`power_up_to_run_and_pgood` also drops the rail comparator for a single clock: PGOOD falls at once and requalifies over the full 9 ms. That case found a bug in `pgood_gen_sva` (its saturation check read `pgood_comp` a clock late); the checker is fixed and pgood_gen's module testbench now drives the same one-clock drop-out.

### `random_walk`

From a settled S_RUN, `RANDOM_EVENTS` events (12 inside `make` and the outer flow), each applied to the board and the model, settled and checked:

| Event | What |
|---|---|
| `switch`, `otp`, `uvlo`, `host`, `rail` | toggle that input |
| `trip` | one overcurrent episode, also while off or latched, where it must do nothing |
| `persist` | an overcurrent that never clears, through every retry to the latch |
| `ovp` | the analog OVP trips the SCR |
| `reset` | the reset button, then the fast timers again |
| `wait` | 1 to 12 ms of steady board |
| `thresholds` | a live write of TRIP_RUN, TRIP_SS, MAX_STRIKES, raw values including out-of-range ones |
| `glitch` | a sub-debounce disturbance the model is not told about |
| `fault_in_hiccup` | a trip, then OTP, UVLO, a host disable, the OVP or the reset button during the cool-down |
| `clean_run` | run past the clean-run window, so the strikes clear |

Covergroups (`top_coverage.py`):

| Covergroup | Bins |
|---|---|
| `pmic_top.event` | every event kind from every condition (off, running, latched) |
| `pmic_top.stop` | switch, host, OTP, UVLO, OVP, strike latch, reset - from S_RUN and from mid-hiccup |
| `pmic_top.strike` | strike level 1-3 under MAX_STRIKES 1-3, latched or not |
| `pmic_top.recovery` | hiccup retry, fault cleared, host enable, switch on, reset button, strikes forgotten |
| `pmic_top.latch` | SCR tripped by the strike count or the OVP, running or off |
| `pmic_top.filter` | every glitch kind rejected |
| `pmic_top.pgood` | PGOOD qualified, dropped by the rail, dropped by leaving S_RUN |

## The board model (`pmic_top_harness.sv`)

| Knob | Board part |
|---|---|
| `osc_on_clks` | modulator on-time in clocks, period 111 clocks (450 kHz); 0 stops it |
| `overcurrent` | every cycle faulted: the valley comparator reports while the low-side FET conducts (En high, PWM_out low) |
| `oc_per16` | the first N cycles of every 16 faulted - exact window counts for the threshold tests |
| `OTP_trig`, `UVLO_trig`, `PGOOD_comp` | the comparators |
| `en_from_switch` | the physical enable switch |
| `ovp_trip` | the analog OVP comparator; trips the SCR |
| `reset_button` | resets the CPLD and drains the SCR, as the board's single button does |

The clock and the board run in SV, so the simulation is not paced by Python. Each test programs short timers over SPI first (1 ms hiccup base, one cycle per ramp step, 100 ms clean window); the 20 ms switch debounce and the 9 ms PGOOD qualification are real.

## Files this folder produces

| File | From | Kept in git? |
|---|---|---|
| `sim_build/`, `results.xml`, `coverage.dat` | a run | no |
| `cov/` | `random_seeds`, `cov_all` | no |
| `coverage/summary.txt` | `cov_all` | yes |
| `soak/README.md`, `results.txt`, `summary.txt`, `all_events.csv`, `merged.dat`, `functional_coverage.xml` | `soak` (README written by hand) | yes |
| `soak/raw/` | `soak`: per-run logs, event CSVs, coverage | no |
