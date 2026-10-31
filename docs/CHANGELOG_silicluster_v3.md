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

## 5. 2026-10-31 17:19 UTC - pkg: ns_to_clks rounds up (project rules 3.2)

- Files: `rtl/pkg/pmic_types_pkg.sv` (ns_to_clks body and comment,
  MIN_ON_COUNTS comment), `Build/*` (regenerated), `docs/silicluster_area.md`.
- What: `ns_to_clks` returns `((CLK_HZ/1e6)*ns + 999) / 1000`, a ceiling,
  instead of a floor.
- Why: its only caller is MIN_ON_COUNTS = ns_to_clks(LM5106_SHRINK_NS +
  MIN_GATE_ON_NS) = ns_to_clks(128 + 112 = 240 ns). Both figures are the
  package's own (LM5106 at RDT = 10k: max t_HPLH 160 ns - typ t_HPHL 32 ns =
  128 ns shrinkage; 112 ns wanted at the gate). At 10 MHz 240 ns is 2.4 clocks.
  Floor gave 2 clocks = 200 ns commanded, 72 ns at the gate - below the 112 ns
  needed to enhance past the Miller plateau. Ceiling gives 3 clocks = 300 ns
  commanded, 172 ns at the gate.
- No-op at 50 MHz, checked: the package elaborated with CLK_HZ = 50 MHz gives
  MIN_ON_COUNTS = 12 before and after (12000 / 1000 is exact); at 10 MHz 2 -> 3.
  ON_TIME_W is 5 either way.
- Observation (not changed): pwm_mask enforces max_on_counts + 1 clocks
  (documented in pwm_mask.sv), so the realised minimum pulse at PWM_out is
  4 clocks = 400 ns. The package's MIN_ON comment treats the count itself as
  the commanded time, so that extra clock is margin, not part of the floor.
  The integration testbench measures 400 ns.
- Side effect: the soft-start ramp is 16 - 3 = 13 steps (was 14 with the
  floor, 71 at 50 MHz).
- Gate: lint clean; sv2v clean; equiv_all same as entry 3 (6/8 per flow, the
  two watchdog-limited testbenches pass with the scaled scratch watchdog, all
  covers, 0 assertion failures).
- Area: flops 700 -> 700, comb cells 2137 -> 2132, cell area 30,821 -> 30,845
  um^2.
- Undo: `git revert <hash>`.

## 6. 2026-10-31 17:20 UTC - pkg: CYCLES_PER_STEP_DEFAULT 16 -> 64 (project rules 3.3)

- Files: `rtl/pkg/pmic_types_pkg.sv`, `Build/*` (regenerated),
  `docs/silicluster_area.md`.
- What: the reset value of the writable cycles-per-step register is 64.
- Why: at 10 MHz the ramp has 13 steps (3 -> 16) against 71 at 50 MHz. With 16
  cycles per step it would last 208 cycles (0.46 ms) instead of 1136 cycles
  (2.52 ms). Matching 1136 needs 87 per step, above CYCLES_PER_STEP_MAX = 64,
  which stays untouched as instructed. 64 is the largest legal value: 13 x 64 =
  832 cycles = 1.85 ms, 73% of the original. No dithering or fractional scheme.
  CYC_STEP_W stays 7 bits (sized from the max, not the default).
- Verified in the integration testbench (entry 9 onwards): the measured ramp
  from En rising to the ceiling is 13 steps of 64 cycles.
- Gate: as entry 5.
- Area: unchanged (700 flops, 2,132 comb cells, 30,845 um^2).
- Depends on entries 3 and 5 for the 13-step arithmetic; on its own it is safe.
- Undo: `git revert <hash>`.

## 7. 2026-10-31 17:23 UTC - top: TELEMETRY_EN parameter (project rules 3.4)

- Files: `rtl/pmic_top.sv`, `sim/Makefile` (`lint_notel`, `syn_notel`,
  `syn_area_notel`, `syn_both`), `Build/*` (regenerated, enabled build plus
  `stat_notel*.txt`, `area_notel_summary.txt`), `docs/silicluster_area.md`.
- What: `parameter bit TELEMETRY_EN = 1'b1` on `pmic_top`. Five generate blocks,
  each wrapped IN PLACE so the file keeps its section layout:
  `g_spi_sync` (SCK/CS_n/SDIO synchronisers), `g_spi_filt` (their filters),
  `g_en_switch_edge` (the enable-switch edge detector, consumed only by
  reg_file), `g_telemetry` (SDIO tri-state, spi_slave, reg_file, pwm_stats,
  fault_cause) with its `else` branch `g_no_telemetry`, and `g_timestamp`.
  `git diff -w` shows +47/-1: wrappers, tie-offs and comments only; the
  existing lines are re-indented, not edited.
- Disabled build: SDIO released (`1'bz`), spi_enable tied 1, and trip_run,
  trip_ss, max_strikes, max_on_limit, hiccup_base, cycles_per_step,
  clean_run_target tied to the same package constants reg_file resets to. So it
  behaves like an enabled build the host never writes.
- Ports unchanged, no second top, no duplicated tree. The submission is the
  default, enabled build.
- Correction to the project rules: sv2v does NOT flatten the generate away. It keeps
  TELEMETRY_EN as a Verilog parameter and the blocks as Verilog generates, so
  `Build/pmic_full.v` carries both configurations, defaulting to 1. The
  disabled numbers come from `chparam -set TELEMETRY_EN 0` in yosys.
- Gate: `make lint` clean; `make lint_notel` clean apart from UNUSEDSIGNAL
  (waived for that build only - the compiled-out nets and the SCK/CS_n pins);
  sv2v clean (2313 lines); equiv_all as entry 3 (6/8 per flow, the two
  watchdog-limited testbenches pass with the scaled scratch watchdog).
- Area: enabled 700 flops / 2,127 comb / 30,808 um^2 (comb -5 is ABC noise from
  the restructure); disabled 252 / 705 / 10,523 um^2. Telemetry costs 448
  flops, 1,422 cells, 20,285 um^2 cell area. Disabled fits the slot (0.89x);
  enabled is 2.61x.
- Undo: `git revert <hash>`. Entry 8's testbench needs the enabled build only,
  so it survives this revert.

## 8. 2026-10-31 18:17 UTC - fix(spi_slave): SDIO is never driven during a read

- File and lines: `rtl/telemetry/spi_slave.sv`, BLOCK 7 (transmit shift),
  lines 487-506 after the change (`sdio_oe <= (spi_state == S_READ);` at
  line 492, the S_TURN load at lines 501-504). Also `Build/*` regenerated,
  `docs/silicluster_area.md`.
- Symptom: every SPI read returns 0x00 - PMIC_ID reads 0x00 instead of 0xB5 -
  at 10 MHz and at 50 MHz, in Verilator and Icarus. This is not related to the
  clock change; `spi_slave` has no unit testbench, so it was never exercised.
- Root cause: `sdio_oe` was set at the last falling SCK edge of the
  turnaround byte, cleared again one clock later by the "release outside
  S_READ" rule because the state is still S_TURN until the eighth rising edge,
  and never set again in S_READ.
- Fix (as specified by the reviewer): `sdio_oe <= (spi_state == S_READ);`
  every clock, and the `sdio_oe <= 1'b1` removed from the S_TURN load. The
  S_TURN load of `tx_shift` and `sdio_out` is kept, so the first data bit is
  already on `sdio_out` when the line is taken. The master owns SDIO for the
  whole turnaround byte, as the module contract states.
- Evidence (`tb/pmic_top_tb.v`, Verilator on the SV source):
  - before: PMIC_ID 0x00; `sdio_oe` high in S_TURN on 471 clocks (10 MHz) /
    524 (50 MHz); the first data bit not driven at the master's first sampling
    edge in 469 / 522 reads; 74 FAIL lines.
  - after: PMIC_ID 0xB5, VERSION 0x01, CAPABILITY 0x3D and every register
    default read back correctly; `sdio_oe` never high while the master owns
    SDIO (S_CMD, S_TURN, S_WRITE); released within one clock of leaving S_READ
    on every read; overhang clocks = S_READ exits = reads issued (118 at
    10 MHz, 330 at 50 MHz); first data bit driven 2.8 us (10 MHz) / 3.8 us
    (50 MHz) before the master samples it at 250 kHz SCK. CS dropped mid-byte:
    `sdio_oe` low exactly 2 clocks after the filtered CS rises. Abandoned read:
    S_DEAD with `sdio_oe` low after the 2 ms SCK timeout, then recovery. The 26
    FAIL lines left are all the write path (entry 9).
  - Monitor wording: a registered `sdio_oe` trails `spi_state` by one clock,
    so SDIO stays driven for exactly one clock after S_READ is left. Per the
    reviewer, the monitor asserts the invariant that matters - low throughout
    the master-owned phases, falling within ONE clock of leaving S_READ (bound
    kept at one so a longer overhang trips it) - and checks that the overhang
    count equals the read count.
  - S_READ exits, enumerated: CS deasserted -> S_IDLE (117 at 10 MHz), SCK
    idle timeout -> S_DEAD (1), CS re-asserted -> S_CMD (0: through the 8-clock
    CS filter a fall can only follow a rise that already left S_READ). The CS
    exit means the slave drives SDIO for one clock after its own filtered view
    of CS has deasserted - reported separately, pending a decision.
- Regression: `make lint` clean; `make -B convert` clean (2311 lines);
  `make equiv_all` 6/8 per table, the two failures being the known
  nanosecond-watchdog limit of `pgood_gen_tb` / `pwm_stats_tb` from entry 3
  (both PASS with the scaled scratch watchdog, all covers, 0 assertion
  failures); `spi_slave` has no unit testbench of its own in `tb/`.
- Cells: `spi_slave` 312 -> 328 sky130 cells (80 flops, unchanged), area
  3,363.2 -> 3,325.7 um^2; `reg_file` unchanged (1,093 cells). Flattened:
  flops 700 -> 700, comb cells 2,127 -> 2,116, cell area 30,808 -> 30,837 um^2.
- Undo: `git revert <hash>` (reads stop working again).

## 9. 2026-10-31 18:19 UTC - fix(spi_slave): writes land at the addressed register

- File and lines: `rtl/telemetry/spi_slave.sv`, BLOCK 4 (receive shift and
  write delay line): the increment at line 384 (`if (wr_en) addr <= addr +
  7'd1;`) and the release branch at lines 403-406. Also `Build/*`
  regenerated, `docs/silicluster_area.md`.
- Symptom: every SPI write lands one address high - a write to SCRATCH 0x03
  reads back 0x00; a keyed write to TRIP_RUN 0x50 is taken as a write of the key
  value into TRIP_RUN and leaves the bank locked; a burst to HICCUP_BASE
  0x54-0x56 does not commit. At 10 MHz and at 50 MHz.
- Root cause: the delay line raised `wr_en` and incremented `addr` on the same
  edge, so reg_file sampled each write strobe together with the NEXT address.
- Fix (option A, as specified by the reviewer): the increment is removed from
  the release branch and applied on the clock after the strobe, `if (wr_en)
  addr <= addr + 7'd1;`, so reg_file sees `wr_en` with the address the byte
  belongs to.
- Why not the alternative that was offered (load `addr` with cmd - 1 for
  writes, keep the release-edge increment) - the reviewer's rationale, recorded
  as given: option A is correct at the spi_slave level. The minus-one variant
  stores a wrong value in `addr` for the whole write data phase and relies on
  the release-edge increment to cancel it; two offsets cancelling is a second
  bug positioned to hide the first. Anything that reads `addr` during a write
  (write decode, addr_d, bus-error attribution, readback) would see a bogus
  address. "Stays inside spi_slave.sv" is not a reason to prefer it; file
  boundaries are not correctness boundaries.
- Evidence (`tb/pmic_top_tb.v`), before (entry 8 state) -> after:
  - 10 MHz: SCRATCH 0x00 -> 0x5A; TRIP_RUN keyed write 12 -> 9 (neighbour
    TRIP_SS untouched); 3-byte HICCUP_BASE burst 50000 -> 84565 (read back as a
    3-byte burst); configuration for the protection phases 50000 -> 10000.
    Bad-CRC write: nothing commits, BUS_ERR counts it, the next good write
    commits. Clamped writes read back clamped (TRIP_RUN 200 -> 16, TRIP_SS 0 ->
    1, MAX_STRIKES 9 -> 3, MAX_ON 250 -> 16, HICCUP_BASE 1 -> 10000,
    CYCLES_PER_STEP 0 -> 1, CLEAN_RUN 5 -> 45000).
  - 50 MHz: the same set passes (MAX_ON clamps to 83, HICCUP_BASE to 50000).
  - Icarus on the converted Verilog at 10 MHz: identical results.
  - Timestamp burst from 0x18 started so the 255 -> 256 ms tick lands between
    byte 0 and byte 1: reads 0x0000FF (one snapshot); an unsnapshotted read
    would give 0x0001FF.
- KNOWN DEFECT EXPOSED, NOT A REGRESSION OF UNKNOWN CAUSE - pending approval:
  the testbench check "write to read-only 0x20 leaves the fault record" PASSES
  before this commit and FAILS after it, by design of the old timing. reg_file
  generates `fault_reg_read_done` from `addr_d == 0x20 && addr == 0x21 &&
  !wr_en`; the `!wr_en` term only masked writes because the old spi_slave
  stepped `addr` on the same clock it raised `wr_en` - the same alignment
  that put every write one address high. With the increment now one clock
  after the strobe, a host WRITE that touches 0x20 clears the fault log.
  Traced in isolation: a 1-byte write to 0x20 and a 2-byte write 0x1F..0x20
  both clear the record after this fix and did not before. The same trace
  shows a pre-existing clear path that does not depend on this fix: a command
  that loads 0x21 while the pointer was left at 0x20 by the previous
  transaction (for example a 1-byte read of 0x1F) clears the record at the
  command byte. Fixing reg_file is outside this change; the analysis and a
  proposed guard are with the reviewer. Until then this check is expected to
  fail, together with the following "fault log: OTP" read, which finds the
  record already cleared.
- Regression: `make lint` clean; `make -B convert` clean (2312 lines);
  `make equiv_all` 6/8 per table (the entry-3 watchdog limit; both PASS
  scaled, all covers, 0 assertion failures). Integration testbench at 10 MHz
  (Verilator SV, Icarus converted) and 50 MHz (Verilator SV): 2 FAIL lines
  each, both the known 0x20 defect above; every other check passes.
- Cells: `spi_slave` 328 -> 308 sky130 cells (80 flops, unchanged), area
  3,325.7 -> 3,323.2 um^2; `reg_file` unchanged (1,093 cells). Flattened:
  flops 700 -> 700, comb cells 2,116 -> 2,130, cell area 30,837 -> 30,827 um^2.
- Undo: `git revert <hash>` (writes land one address high again, and the 0x20
  check passes again for the wrong reason).

## 10. 2026-10-31 18:35 UTC - tb: pgood_gen and pwm_stats watchdogs scale with the clock

- Files and lines: `tb/status/pgood_gen_tb.sv` line 66,
  `tb/telemetry/pwm_stats_tb.sv` line 50. Those two lines only, approved by the
  reviewer; nothing else in `tb/` changed.
- Classification: a TESTBENCH bug exposed by the clock change (entry 3), not an
  RTL issue. Both watchdogs were an absolute `10_000.0` ns, which was 500 clocks
  at 20 ns. At 100 ns the same stimulus needs 5x the time, so both testbenches
  hit the watchdog with zero assertion failures.
- Fix: `WATCHDOG_NS = 500.0 * CLK_PERIOD_NS`, from the testbench's own
  `CLK_PERIOD_NS` rather than a hardcoded multiplier - 10 us at 50 MHz
  (unchanged) and 50 us at 10 MHz.
- Evidence: `make equiv_all` 6/8 -> 8/8 in both tables (SV source and sv2v
  output), every cover hit, 0 assertion failures. Against a scratch copy of the
  RTL with the package at 50 MHz, both testbenches also PASS (5/5, 7/7 covers).
  This closes the "awaiting approval" item recorded in entries 3, 5, 6, 7, 8
  and 9.
- No RTL change, no area change.
- Undo: `git revert <hash>` (equiv_all returns to 6/8 at 10 MHz).
