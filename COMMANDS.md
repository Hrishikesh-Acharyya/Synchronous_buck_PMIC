# Commands

Everything runs through `make` from the `sim/` folder:

```bash
cd sim
make help        # every target, grouped, in colour
make doctor      # which tools are installed, and what each missing one disables
```

`make` on its own runs `lint`. Add `-j8` (or `-j$(nproc)`) to any suite to run the testbenches in parallel.

The module testbenches take seconds; the integration testbench (`pmic_top_tb`) takes a couple of minutes - about a minute to build, one to two to run at 50 MHz. Under `-j` a target's output appears only when it finishes, so a `[RUNNING]` line is printed when it starts; it has not hung.

---

## Everyday loop

| What you want | Command |
|---|---|
| Lint the RTL | `make lint` |
| Run one module testbench | `make tb_pwm_mask` |
| Run it and open the waveform | `make wave_pwm_mask` |
| Run every testbench on the SV source | `make -j8 tb_all` |
| Run every testbench on the source **and** the converted Verilog (the gate) | `make -j8 equiv_all` |
| Reprint the last results table | `make report` |
| Run exactly what GitHub CI runs, before pushing | `make -j8 ci` |
| After editing the RTL: refresh the Verilog copies | `make convert verilog` |

---

## Module testbenches

One family of targets per entry in `TESTBENCHES` (top of `sim/Makefile`). `make list` shows them all.

| Command | What it does |
|---|---|
| `make tb_<m>` | build and run `tb/<group>/<m>_tb.sv` against the SystemVerilog source |
| `make equiv_<m>` | the same testbench and SVA checkers against the sv2v output |
| `make wave_<m>` | `tb_<m>` with a VCD, then open GTKWave |
| `make view_<m>` | open the last VCD without re-running |
| `make cov_<m>` | the cover table of the last run, every condition in full |
| `make new_tb M=<group>/<m>` | create `tb/<group>/<m>_tb.sv` from `tb/template_tb.sv` with the name filled in; it prints the line to add to `TESTBENCHES` |

What a single run prints: the build result (Verilator's output only if the build fails), the simulation output as it runs (failures in red, repeats of one failing assertion folded after `FAIL_SHOW` lines), the cover table (hits, a log-scale activity bar, each cover's condition), then a summary card - verdict and why, assertions armed and failed, procedural checks, covers hit, simulated time and the log paths. Suites print one status line per testbench, then a table per flow. Everything is still in `build.log` and `run.log` in the testbench's build directory.

Example: `make new_tb M=protect/soft_start`, fill in the markers, add `protect/soft_start` to `TESTBENCHES`, then `make tb_soft_start`.

### SVA checkers

| Command | What it does |
|---|---|
| `make new_sva M=<group>/<m>` | create `sva/<group>/<m>_sva.sv` from `sva/template_sva.sv`, with the module's parameters and ports copied in from its RTL header (outputs become checker inputs too), and print the `bind` line to add to `sva/bind_sva.sv` |

Every `sva/<group>/*.sv` is compiled into every testbench automatically, so a generated checker is written to compile as it stands - its example PAC group is commented out - and does nothing until its `bind` line is added. Then write one PAC group (property, assertion, cover) per claim from the module header, and read DUT internals through `dut_<signal>` ports, connected by name in the bind. A module with no group folder (`make new_sva M=supervisor`) gets `sva/top/`.

## Suites

| Command | What it does |
|---|---|
| `make -j8 tb_all` | every module testbench, the integration testbench and both cocotb suites on the SV source, then a table |
| `make -j8 equiv` | the same on the sv2v output (`SPLIT=1`: on the `rtl-verilog/` files instead) |
| `make -j8 equiv_all` | both of the above in one parallel run - what CI runs |
| `make report` | reprint the tables from the last runs |
| `make list` | list the registered testbenches and their files |

## Integration testbench (`tb/pmic_top_tb.v`)

The whole chip, in plain Verilog. `_notel` = the SPI-less build (`TELEMETRY_EN=0`), which runs the testbench's pins-only sequence.

| Full build | SPI-less build | Simulator, source |
|---|---|---|
| `make tb_top` | `make tb_top_notel` | Verilator, SystemVerilog source |
| `make equiv_top` | `make equiv_top_notel` | Verilator, converted Verilog |
| `make iv_top` | `make iv_top_notel` | Icarus Verilog, converted Verilog (slow at 50 MHz) |
| `make top_all` | `make top_notel` | all three, then a table |
| `make top_both` | | both builds, all three simulators |
| `make wave_top` / `make view_top` | | VCD of the full run (large) / reopen it |

The testbench's clock is read from `CLK_HZ` in `rtl-systemverilog/pkg/pmic_types_pkg.sv`, so changing the clock is a one-line edit there. `CYC_STEP_DEF` in the testbench must still match `CYCLES_PER_STEP_DEFAULT` in the package.

## Whole-supervisor suite (`tb/top/pmic_top`, cocotb)

`pmic_top` inside a board model (modulator, valley comparator, SCR latch, fault comparators, reset button), checked after every board event against a supervisor model, with `pmic_top_sva` and every block's checker bound. Directed tests, design-intent edge cases, a constrained-random board walk (`random_walk`) and covergroups. Listed as `pmic_top_cocotb`, with a `covergroups` line like `host_if_tb`. The suite's own random, replay, soak and coverage targets are in `tb/top/pmic_top/COMMANDS.md`.

| Command | What it does |
|---|---|
| `make tb_top_cocotb` | the whole cocotb suite on the SystemVerilog source (about 10 minutes) |
| `make equiv_top_cocotb` | the same suite on the sv2v output (`SPLIT=1`: on `rtl-verilog/`) |
| `make tb_top_cocotb TOPCOCO_EVENTS=40` | a longer `random_walk` inside the suite (default 12; each event costs milliseconds of simulated time) |

## Host-interface suite (`tb/telemetry/host_if`, cocotb)

`spi_slave` + `reg_file` through a wrapper, checked against a Python reference model with a scoreboard, the bound SVA checkers, constrained-random traffic (`random_walk`) and covergroups. Needs `cocotb` and `cocotb-coverage` in the Python environment. It runs in the suites like any other testbench and is listed as `host_if_tb`; a magenta `covergroups` line under each table gives its functional coverage (bins hit).

| Command | What it does |
|---|---|
| `make tb_host_if` | the whole cocotb suite on the SystemVerilog source |
| `make equiv_host_if` | the same suite on the sv2v output (`SPLIT=1`: on `rtl-verilog/`) |
| `make tb_host_if HOSTIF_EVENTS=1000` | a longer `random_walk` inside the suite (default 400) |

## Soaks and the complete verification

A soak is a long constrained-random sweep of one cocotb suite: many seeds, each a `random_walk` checked against the suite's model, run one seed per CPU core (`nproc` shows how many). A soak never stops on a failing seed; the target fails at the end if any seed did, and lists them. The evidence lands in the suite's `soak/` folder, exactly as when the soak is run from there (see its `soak/README.md`).

| Command | What it does |
|---|---|
| `make soak_host_if` | host_if soak, 100 seeds x 200 events (`HOSTIF_SOAK_SEEDS`, `HOSTIF_SOAK_EVENTS`) |
| `make soak_top_cocotb` | pmic_top soak, 64 seeds x 200 events with every checker bound (`TOPCOCO_SOAK_SEEDS`, `TOPCOCO_SOAK_EVENTS`; `TOPCOCO_SOAK_CHECKERS=top` binds `pmic_top_sva` alone, about ten times faster) |
| `make soak_all` | both soaks, one after the other - each already uses every core |
| `make verify_all` | **the complete verification in one command**: `make ci` (lint, conversion checks, every testbench in both flows - unit, integration, host_if, pmic_top), then `make soak_all`. Hours. |
| `... SOAK_JOBS=4` | on any soak target: use 4 cores instead of all, to keep the machine usable |

Wall time depends heavily on the machine: with every core busy each simulation runs well below its single-run speed. Measured on an 8-core laptop under WSL (repository on the Windows drive): the host_if soak, 200 x 200 one seed at a time, 14 h; the pmic_top soak, 64 x 200 with every checker, 8 at a time, 9.5 h. `TOPCOCO_SOAK_CHECKERS=top` is about ten times faster; cloning the repository inside WSL's own filesystem (`~/`) instead of `/mnt/e` also helps.

The suite's own random-test targets - `soak`, `cov_all`, `replay` - are run from `tb/telemetry/host_if`; see its `COMMANDS.md`.

## Lint and script checks

| Command | What it does |
|---|---|
| `make lint` | strict Verilator lint of the RTL, from `pmic_top` |
| `make lint_notel` | the same for the SPI-less build |
| `make lint_all` | both |
| `make check_scripts` | `bash -n` + shellcheck (if installed) on `sim/scripts/*.sh`, syntax check of every Python script |
| `make lint_sv` | house-style and rulebook lint of the RTL, checkers and testbenches (`verif_automation/tools/lint`); fails on any error. `RULES=H1,C1` for a subset, `FILES=` for files or folders |
| `make lint_sv_report` | the same report, always exit 0 |
| `make lint_sv_evidence` | save the full report as `verif_automation/evidence/lint/<date>_lint.txt` |

## Conversion and synthesis

| Command | What it does |
|---|---|
| `make convert` | sv2v the RTL into one file, `Build/pmic_full.v` (committed) |
| `make convert_notel` | a copy with `TELEMETRY_EN` defaulting to 0, `Build/pmic_full_notel.v` (not committed) |
| `make syn` | yosys synthesis: generic cell and flop counts |
| `make syn_notel` | the same for the SPI-less build |
| `make syn_area` / `make syn_area_notel` / `make syn_both` | sky130-mapped area - needs the liberty file (`LIBERTY=path`) |
| `make syn_compare` | cell counts of this tree vs `origin/main` (`BASE=<branch, tag or commit>` to pick another) - the same table CI posts on a pull request |

## The Verilog copy (`rtl-verilog/`)

`rtl-verilog/` holds one Verilog-2005 file per SystemVerilog module, with the comments sv2v throws away carried over. Its code must always be exactly what sv2v makes from the current source - CI checks this.

| Command | What it does |
|---|---|
| `make verilog` | regenerate `rtl-verilog/` from the source, keeping every comment. Refuses a file if more than a constant or a path changed (a new port or block needs its comments written by hand) and lists comments that mention a clock frequency, for you to review |
| `make verilog_check` | prove `rtl-verilog/` matches a fresh sv2v split |
| `make split` | just the fresh split, without comments, in `Build/split_raw/` |

The staging folders (`Build/split_raw*`) are scratch: `verilog`, `verilog_check` and `verilog_notel` delete theirs when they succeed and keep it when they fail, so you can diff against it. `KEEP_SPLIT=1` keeps it always.

**After any RTL edit:** `make convert verilog`, review the listed comments, commit `Build/pmic_full.v` and `rtl-verilog/` with the change.

## SPI-less (TELEMETRY_EN=0) versions, on demand

Nothing here is committed; each command regenerates its output in `Build/`.

| Command | Output |
|---|---|
| `make verilog_notel` | commented SPI-less Verilog in `Build/rtl-verilog-notel/`, proven against a split of the flipped source |
| `make convert_notel` | `Build/pmic_full_notel.v` |
| `make bundle_notel` | `Build/sync_buck_pmic_notel.zip`: SPI-less Verilog + the testbench set to the SPI-less sequence |
| `make bundle` | `Build/sync_buck_pmic.zip`: the full build, the same way |
| `make ci_notel` | the SPI-less CI job: lint + integration testbench on source and converted |

`BUNDLE=<name>` renames the zips.

## Housekeeping

| Command | What it does |
|---|---|
| `make doctor` | tools found / missing with versions, liberty file, output paths, colour setting |
| `make tb_clean` | delete testbench build output (`~/build/sync_buck`) |
| `make syn_clean` | delete conversion and synthesis output |
| `make clean` | both, plus every generated tree and bundle, and the `Build/package_raw*` folders the old Silicluster flow left behind. Note: like `main`'s version, it also deletes the committed `Build/pmic_full.v` and `Build/stat*.txt` - `make convert syn` brings them back |

---

## Options

Put them after the target, e.g. `make tb_all QUIET=0` or `make syn YOSYS=yosys`.

| Variable | Default | Meaning |
|---|---|---|
| `QUIET=1` | 0 (suites set 1) | log to file only, one status line per testbench |
| `STRICT=1` | 0 | a testbench whose covers never fired fails instead of reading INCONCLUSIVE (CI uses this) |
| `NOFAIL=1` | 0 (suites set 1) | single runs always exit 0; the suite table decides |
| `WAVES=1` | 0 | dump a VCD |
| `RAW=1` | 0 | stream the simulation output untouched (no colouring, no folding of repeated failures) |
| `FAIL_SHOW=` | 5 | failure lines shown per assertion or check before the rest are only counted (all are in `run.log`) |
| `THIN=` | 10 | covers hit fewer times than this are marked as thinly exercised in the cover table |
| `SPLIT=1` | 0 | run the `equiv` flows on `rtl-verilog/` instead of `Build/pmic_full.v` |
| `COLOR=0` / `NO_COLOR=1` | colour in a terminal | plain output; `COLOR=1` forces colour |
| `TBBUILD=` | `~/build/sync_buck` | where testbench builds go (outside the repo: faster on the WSL mount) |
| `YOSYS=` | `~/oss-cad-suite/bin/yosys` | yosys binary |
| `LIBERTY=` | sky130 hd tt via volare | liberty file for the area targets |
| `BASE=` | `origin/main` | revision `syn_compare` compares against |
| `BUNDLE=` | `sync_buck_pmic` | zip name for `bundle` / `bundle_notel` |
| `KEEP_SPLIT=1` | 0 | keep the `Build/split_raw*` staging trees after a successful check |
| `VJOBS=` | all cores (`nproc`) | parallel C++ compile jobs inside each Verilator build |
| `M=` | - | `<group>/<module>` for `new_tb` |
| `HOSTIF_EVENTS=` | 400 | `random_walk` events in the host-interface suite run (`tb_host_if`, `equiv_host_if`) |

## CI (GitHub Actions)

| Workflow | When | What |
|---|---|---|
| RTL (`rtl.yml`) | every pull request, pushes to main | lint (both builds) + script check; `rtl-verilog` sync check + `equiv_all` (including the cocotb host-interface suite); SPI-less integration testbench |
| Synthesis trend (`synth.yml`) | pull requests touching the RTL or the Makefile | yosys cell counts, base vs head, posted as a PR comment |
| Full regression (`full.yml`) | Actions tab > Run workflow, and weekly on main | everything above, plus Icarus in both builds, synthesis of both builds, and the two Verilog bundles as a downloadable artifact |

`make ci` and `make ci_notel` run the RTL workflow's steps locally.

## Where things live

```
rtl-systemverilog/   the design, SystemVerilog - what you edit
rtl-verilog/         its Verilog-2005 copy, one file per module (make verilog)
tb/                  module testbenches (*_tb.sv), template_tb.sv, pmic_top_tb.v
sva/                 bound assertion checkers
sim/Makefile         TESTBENCHES list + includes
sim/mk/              the Makefile, by topic (config, sources, tb, top, lint, syn, verilog, util)
sim/scripts/         the scripts behind the targets
Build/               pmic_full.v and synthesis records (committed); generated trees and zips (ignored)
verif_automation/    tools/ (lint, mutation, ...), ai/ (AI agent tasks and run scripts), evidence/ (dated results)
```
