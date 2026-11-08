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

## Running tests

| Command | What it does |
|---|---|
| `make` | every test in `test_pmic_top.py` (about 0.5 s simulated, a few minutes) |
| `make TESTCASE=<name>` | one test, e.g. `make TESTCASE=persistent_overcurrent_latches` |
| `make TELEMETRY_EN=0` | build the reduced design instead (the tests that use SPI need the full build) |

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

## The board model (`pmic_top_harness.sv`)

| Knob | Board part |
|---|---|
| `osc_on_clks` | modulator on-time in clocks, period 111 clocks (450 kHz); 0 stops it |
| `overcurrent` | the valley comparator reports through every low-side phase |
| `OTP_trig`, `UVLO_trig`, `PGOOD_comp` | the comparators |
| `en_from_switch` | the physical enable switch |
| `ovp_trip` | the analog OVP comparator; trips the SCR |
| `reset_button` | resets the CPLD and drains the SCR, as the board's single button does |

The clock and the board run in SV, so the simulation is not paced by Python. Each test programs short timers over SPI first (1 ms hiccup base, one cycle per ramp step, 100 ms clean window); the 20 ms switch debounce and the 9 ms PGOOD qualification are real.

## Files this folder produces

| File | From | Kept in git? |
|---|---|---|
| `sim_build/`, `results.xml`, `coverage.dat` | a run | no |
