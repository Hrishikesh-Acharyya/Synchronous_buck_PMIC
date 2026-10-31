# Changelog - Silicluster v3 submission branch

Every change made on this branch, newest at the bottom, with a UTC timestamp,
the files touched, why, and how to undo it. `main` is never touched.

Branch: the Silicluster v3 submission branch, cut from `main` at `a70e4a9`.

## How to undo a change

Each entry is exactly one commit. To back one out without disturbing the
others:

```bash
git revert <commit>
```

Then rerun the gate (`cd sim && make lint && make -B convert && make -j4 equiv_all`)
because the RTL entries regenerate `Build/pmic_full.v`, and a revert of an RTL
commit restores the previous converted file along with it. Entries that depend
on an earlier one say so - revert the later one first.

The commit hash of each entry is listed in the table at the end. A commit
cannot contain its own hash, so the table is filled in by a later commit.

---

## 1. 2026-10-31 17:13 UTC - docs: start the changelog and the area log

- Files: `docs/CHANGELOG_silicluster_v3.md` (new), `docs/silicluster_area.md` (new)
- What: this file, and the append-only area log required by the project rules, section 7,
  seeded with a measured baseline of `main` at 50 MHz.
- Why: the user asked for a changelog that makes every change undoable; the area
  log is part of the Silicluster deliverable.
- Finding recorded: the baseline mapped area (32,369 um^2 cell area, 2,281
  combinational cells) is materially lower than the reference in the project rules
  (~43,000 um^2, 3,039 cells). The reference appears to have used the generic
  gate count. Flop count (730) agrees exactly.
- Undo: `git revert <hash>` (documentation only, no functional effect).

## 2. 2026-10-31 17:14 UTC - sim: synthesis targets write their statistics with `tee -o`

- Files: `sim/Makefile`, `sim/scripts/area_counts.py` (new)
- What: `syn` and `syn_area` now have yosys write the statistics table to
  `stat_summary.txt` / `area_summary.txt` itself instead of scraping it from the
  redirected log. `syn_area` ends with one summary line (flops, comb cells, cell
  area, die @57%, slot ratio) from the new script. `syn_clean` removes the two
  new files. The old "divide by 0.55" hint is replaced by the script's 57%
  figure, which is the assumption the area log uses.
- Why: the YoWASP (WebAssembly) yosys build truncates redirected stdout, so the
  old grep found nothing and `syn_area` failed even though synthesis succeeded.
  `tee -o` is exact with every yosys build, native included. No change to the
  synthesis script itself, so numbers are unaffected.
- Undo: `git revert <hash>`.

## 3. 2026-10-31 17:17 UTC - pkg: CLK_HZ 50 MHz -> 10 MHz (project rules 3.1)

- Files: `rtl/pkg/pmic_types_pkg.sv` (CLK_HZ, two comments), `rtl/pmic_top.sv`
  (clk port comment, SPI filter comment), `rtl/telemetry/reg_file.sv`
  (ARM_TIMEOUT_W comment), `Build/pmic_full.v`, `Build/stat.txt`,
  `Build/stat_summary.txt`, `Build/area_summary.txt` (regenerated), `.gitignore`
  (ignore the 200 kB `Build/area.txt` log), `docs/silicluster_area.md`.
- What: one constant, `CLK_HZ = 10_000_000`. Comments that stated a 50 MHz
  number which is now wrong were corrected; no other code changed.
- Why: the call caps the external clock at 10 MHz.
- Re-derived constants (script output, 50 MHz -> 10 MHz):
  - ms-based, exact at both clocks: debounce assert 50,000 -> 10,000 clks
    (1 ms), release 10,000 -> 2,000 (200 us), enable-switch debounce
    1,000,000 -> 200,000 (20 ms), hiccup base default/min/max 250k/50k/1M ->
    50k/10k/200k (5/1/20 ms), SCK idle timeout 100,000 -> 20,000 (2 ms), LED
    half-blink 6.25M -> 1.25M (125 ms), timestamp prescaler 50,000 -> 10,000
    (exact 1 ms tick).
  - switching-cycle based, unchanged: clean run 450,000 cycles, PGOOD qualify
    4,050 cycles, fault windows 16/32 with trips 12/28.
  - degraded, confirmed: CLKS_PER_SW 111 -> 22 (true ratio 22.2), so one clock
    of on-time is 4.5% duty instead of 0.9%; MAX_ON_COUNTS 83 -> 16 (75% of 22,
    floored); the two-flop synchroniser is 200 ns = 9.0% of a 2.22 us period
    (was 40 ns = 1.8%).
  - widths narrowed: PRESCALAR_W 16->14, ON_TIME_W 7->5 (x3 registers),
    HICCUP_BASE_W 20->18, HICCUP_TIMER_W 22->20, CNT_W 8->6 (x3), enable
    debounce 20->18, fault debounce 16->14 (x3), SCK timeout 17->15, blink
    23->21. Sum: -30 flops. Measured: 730 -> 700. Matches exactly.
- New issues found by the rescale (reported, NOT changed - outside the permitted
  list):
  - SPI: SPI_FILTER_CLKS = 8 is now 800 ns, longer than a 1 MHz SCK
    half-period. The host must slow SCK; 250 kHz is the verified rate.
  - fault_arbiter BLANK_CLKS = 5 is clock-denominated: the current sample is now
    taken 500 ns before the PWM rise instead of 100 ns. At the 75% duty ceiling
    low-side conduction lasts ~555 ns, so the sample sits right at the start of
    low-side conduction, close to the falling-edge switch-node ringing.
- Gate: lint clean; sv2v clean (2252 lines). equiv_all: 6/8 pass in each flow;
  `pgood_gen_tb` and `pwm_stats_tb` FAIL on their testbench watchdog
  (`WATCHDOG_NS = 10_000.0` ns, an absolute time sized for a 20 ns clock - at
  100 ns those testbenches run longer than 10 us). Zero assertion failures.
  Re-run from scratch copies with only the watchdog scaled x5: both PASS, all
  covers hit (5/5 and 7/7), SV and converted. The RTL is correct; the fix
  belongs in `tb/` (scale `WATCHDOG_NS` with `CLK_PERIOD_NS`), which this
  branch is not permitted to edit. Awaiting approval.
- Area: flops 730 -> 700, comb cells 2281 -> 2137, cell area 32,369 -> 30,821
  um^2.
- Undo: `git revert <hash>`. Later RTL entries build on this value; revert them
  first.

## 4. 2026-10-31 17:17 UTC - sim: yosys writes its own full log with `-l`

- Files: `sim/Makefile`, `Build/stat.txt` (regenerated, complete again)
- What: `syn` and `syn_area` run yosys with `-q -l <log>` and send stdout to
  /dev/null, instead of redirecting stdout into the log.
- Why: follow-up to entry 2. The YoWASP yosys truncation also cut the full log,
  so the `Build/stat.txt` committed in entry 3 was partial (it ended mid-run).
  The numbers in entry 3 came from the `tee -o` summary files and are correct;
  only the full log was short. With `-l`, yosys writes the file itself.
- Undo: `git revert <hash>` (also restores the partial log from entry 3).
