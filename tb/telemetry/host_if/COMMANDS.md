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
| `make soak SEEDS=40 EVENTS=200` | unattended sweep that never stops on a failure; evidence in `soak/` (see `soak/README.md`). A run is PASS only if its `results.xml` has a test and no failure - cocotb 1.x exits 0 even when a test fails |
| `make cov_all` | the whole suite once, plus `SEEDS` random runs, merged into `cov/merged_all.dat`. This is the real coverage picture; target: no zero-hit covers. Its summary - SVA covers and covergroups - is written to `coverage/summary.txt` |
| `make cov_summary` | per checker: covers hit vs at zero, across the merged runs |
| `make cov_zero` | the zero-hit covers, one per line as `<hierarchy>.<cover>  (<checker>.sv:<line>)` — the to-do list for stimulus |
| `make cov_summary MERGED=soak/merged.dat` | the same for a specific merge; by default the newest of `cov/merged.dat`, `cov/merged_all.dat` and `soak/merged.dat` |
| `make clean_cov` | delete the coverage in `cov/`; the evidence in `coverage/` and `soak/` is never cleaned |
| `make clean` | cocotb's clean: removes `sim_build` (forces a full rebuild) |

`coverage.dat` is overwritten by every run. `random_seeds` copies each run's
file to `cov/cov_runN.dat` and merges them into `cov/merged.dat`; `cov_all`
adds the suite run as `cov/cov_suite.dat` and merges into
`cov/merged_all.dat`; a soak does the same into `soak/raw/` and
`soak/merged.dat`. All merge with `verilator_coverage --write`, so `cov_zero`
reports what NO run reached.

`random_seeds` and `soak` run random_walk only, so they miss what the directed
tests reach; quote `cov_all` for coverage.

## Functional coverage (covergroups)

`random_walk` samples three covergroups (`functional_coverage.py`): why each threshold frame was accepted or refused, crossed with the supervisor state; how each transaction ended; and which part of its range each committed threshold fell in. With `FCOV_XML=<file>` a run exports them. `soak` and `cov_all` do this for every run and merge the results, and `fcov_report.py` turns a merge into a readable list of bins hit and bins still empty:

    python3 fcov_report.py merge <merged.xml> <run.xml>...
    python3 fcov_report.py report <merged.xml>

From `sim/`, `make tb_host_if` / `equiv_host_if` run this whole suite and show the covergroups under the result table.

## Variables

| Variable | Default | Meaning |
|---|---|---|
| `EVENTS` | 30 | random events per run |
| `SEEDS` | 5 | random runs in `random_seeds` / `soak` / `cov_all` |
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
| `cov/` | `random_seeds` and `cov_all`: per-run coverage and the merges | no |
| `coverage/summary.txt` | `make cov_all`: covers hit per checker and the zero-hit list, for the last full run | **yes** |
| `soak/README.md`, `results.txt`, `summary.txt`, `all_events.csv`, `merged.dat`, `functional_coverage.xml` | `make soak`: the evidence of the last soak | **yes** |
| `soak/raw/` | `make soak`: per-run logs, event CSVs and coverage | no |