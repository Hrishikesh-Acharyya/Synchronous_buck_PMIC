# host_if testbench — commands

cocotb testbench for the host interface (spi_slave + reg_file through
host_if_wrapper). Run everything from this folder with the venv active:

    source ~/venv-hdl/bin/activate
    cd tb/telemetry/host_if

`make help` prints the target list below.

## Running tests

| Command | What it does |
|---|---|
| `make` | every test in `test_host_if.py`; random_walk runs at its default 30 events |
| `make TESTCASE=<name>` | one test by name, e.g. `make TESTCASE=threshold_writes_through_model` |
| `make random` | random_walk once, `EVENTS` events (default 30), new seed |
| `make quick` | random_walk once, 30 events — while editing the test |
| `make random EVENTS=500` | a longer soak run |

## When a random run fails

The first line of every random_walk log is the exact replay command:

    random_walk: 100 events - to replay this exact run: make replay SEED=1794138186 EVENTS=100

| Command | What it does |
|---|---|
| `make replay SEED=<n> EVENTS=<m>` | reruns that exact event sequence; `EVENTS` must match the failing run |
| `make replay SEED=<n> EVENTS=<m> EVERY=1` | same run, scoreboard after every event — pins the failure to one event (slow) |
| `make replay SEED=<n> EVENTS=<m> COCOTB_LOG_LEVEL=DEBUG` | also prints each event as it starts |

In the log, a failure belongs to the event AFTER the last `event N:` line, or
to the 10-event window before the last `scoreboard check` line.

## Several seeds and coverage

| Command | What it does |
|---|---|
| `make random_seeds` | `SEEDS` runs (default 5), stops at the first failure, merges coverage |
| `make random_seeds SEEDS=20 EVENTS=200` | a bigger sweep |
| `make soak SEEDS=40 EVENTS=200` | unattended sweep that never stops on a failure; evidence in `soak/` (see `soak/README.md`) |
| `make cov_summary` | per checker: covers hit vs at zero, across the merged runs |
| `make cov_zero` | the zero-hit cover lines themselves — the to-do list for stimulus |
| `make cov_summary MERGED=soak/merged.dat` | the same for a specific merge; by default the newer of `cov/` and `soak/` |
| `make clean_cov` | delete `random_seeds`' coverage in `cov/`; a soak's evidence is never cleaned |
| `make clean` | cocotb's clean: removes `sim_build` (forces a full rebuild) |

`coverage.dat` is overwritten by every run. `random_seeds` copies each run's
file to `cov/cov_runN.dat` and merges them into `cov/merged.dat`; a soak does
the same into `soak/raw/` and `soak/merged.dat`. Both merge with
`verilator_coverage --write`, so `cov_zero` reports what NO run reached.

## Variables

| Variable | Default | Meaning |
|---|---|---|
| `EVENTS` | 30 | random events per run |
| `SEEDS` | 5 | runs in `random_seeds` / `soak` |
| `SEED` | — | seed for `replay` |
| `EVERY` | 10 | full scoreboard every N events inside random_walk |
| `TESTCASE` | all | cocotb: which test(s) to run |
| `COCOTB_LOG_LEVEL` | INFO | `DEBUG` for more detail |

## Files this folder produces

| File | From | Kept in git? |
|---|---|---|
| `sim_build/` | Verilator build | no |
| `results.xml` | cocotb test report | no |
| `coverage.dat` | last run's covers | no |
| `cov/` | `random_seeds`: per-run coverage and its merge | no |
| `soak/README.md`, `results.txt`, `summary.txt`, `all_events.csv`, `merged.dat` | `make soak`: the evidence of the last soak | **yes** |
| `soak/raw/` | `make soak`: per-run logs, event CSVs and coverage | no |