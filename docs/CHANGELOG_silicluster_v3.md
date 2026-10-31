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

## 11. 2026-10-31 18:38 UTC - fix(reg_file): clear the fault log only on a completed read of 0x20

- Files and lines: `rtl/telemetry/reg_file.sv` (input `rd_byte_done` at line
  56; `fault_reg_read_done` at line 245; `addr_d` and its always_ff removed),
  `rtl/telemetry/spi_slave.sv` (output `rd_byte_done` at line 65, its own
  always_comb with a Purpose block, line 568), `rtl/pmic_top.sv` (one internal
  wire `spi_rd_byte_done`, connected to both instances inside `g_telemetry`; no
  port change). `Build/*` regenerated, `docs/silicluster_area.md`.
- Symptom: a host WRITE that touches read-only 0x20 clears the fault log
  (0x1D-0x20), and so does a command byte that loads 0x21 while the pointer was
  left at 0x20 by the previous transaction. The testbench check "write to
  read-only 0x20 leaves the fault record" failed after entry 9.
- Root cause: reg_file inferred "the record has been read" from the address
  moving 0x20 -> 0x21 between two clocks with `wr_en` low, but the address also
  moves on command loads and write releases, and the `!wr_en` mask only lined up
  with writes while spi_slave stepped `addr` on the same clock as `wr_en` - the
  alignment that put every write one address high (entry 9).
- Fix, approved by the reviewer: define the clear by what happened rather than by
  address timing. spi_slave exports `rd_byte_done = byte_done && (spi_state ==
  S_READ)`, the eighth rising SCK edge of a READ data byte, while `addr` still
  names that byte. reg_file clears on `rd_byte_done && (addr == 0x20)`. The
  address-history register `addr_d` is no longer needed and is removed.
- Behaviour kept, recorded as asked: reading 0x20 ALONE still clears the log. A
  one-byte read of 0x20 is a completed read of the record's top byte, which is
  what triggers the clear; a host that wants the whole record must read
  0x1D-0x20 as one burst. Stopping before 0x20 loses nothing.
- Every other use of `addr` and `wr_en` in reg_file was checked: the read mux,
  the threshold temp-register writes, the scratch/key/CONTROL writes and the key
  arming. None depended on when `addr` increments; they were simply wrong before
  entry 9 and correct after. Only this guard had been timed against the bug.
- Evidence:
  - Isolated trace of `fault_reg_read_done` on five paths (Icarus, converted
    Verilog). Before (entry 9 state): clears on A (4-byte read sweep), B (1-byte
    write to 0x20), C (read of 0x1F then a command to 0x21), D (1-byte read of
    0x20), E (2-byte write 0x1F..0x20). After: clears on A and D only.
  - Integration testbench: "write to read-only 0x20 leaves the fault record" FAIL
    -> PASS, and with it the following "fault log: OTP" read. Full run PASS, 0
    FAIL lines, at 10 MHz (Verilator on the SV source, Icarus on the converted
    Verilog) and at 50 MHz (Verilator).
- Regression: `make lint` clean; `make lint_notel` clean; `make -B convert`
  clean (2318 lines); `make equiv_all` 8/8 in both tables, every cover hit, 0
  assertion failures.
- Cells: flops 700 -> 693 (`addr_d`), comb cells 2,130 -> 2,086, cell area
  30,827 -> 30,522 um^2. Per module: reg_file 1,093 -> 1,071 cells (264 -> 257
  flops), 12,085 -> 11,825 um^2; spi_slave 308 -> 306 cells, 3,323 -> 3,360
  um^2 (the strobe decode).
- Undo: `git revert <hash>` (writes to 0x20 and the stray command load clear
  the log again).

## 12. 2026-10-31 18:42 UTC - fix(spi_slave): sdio_oe exactly aligned with S_READ

- File and line: `rtl/telemetry/spi_slave.sv`, BLOCK 7, line 505
  (`sdio_oe <= (spi_state_next == S_READ);`) and its comment. `Build/*`
  regenerated, `docs/silicluster_area.md`, and the SDIO monitor in
  `tb/pmic_top_tb.v`.
- Symptom: after entry 8, `sdio_oe` trailed `spi_state` by one clock on both
  edges. On every exit from S_READ the slave kept driving SDIO for one clock -
  and the exits are CS deasserted -> S_IDLE (110 of 111 reads at 10 MHz) and SCK
  timeout -> S_DEAD (1); CS re-asserted -> S_CMD cannot occur through the CS
  filter. The CS exit meant one clock of drive onto a bus the slave itself
  already saw as deselected.
- Root cause: `sdio_oe` was registered from the current state, so it could only
  follow a state change one clock after it.
- Fix, approved by the reviewer: register it from the next state. `sdio_oe` and
  `spi_state` now change on the same edge - the slave takes SDIO on the edge it
  enters S_READ and lets go on the edge it leaves. Still a flop, so the
  tri-state enable stays glitch-free.
- Reviewer's condition, checked: the drive now starts one clock earlier, on the
  edge `spi_state` enters S_READ. The first data bit is on SDIO at that edge -
  `sdio_out` is loaded on the last falling SCK edge of the turnaround byte and
  only changes on falling edges. The testbench checks, 1 ns after every drive
  start, that the net carries `sdio_out`, that `sdio_out` is the MSB of the
  loaded byte, and that the master has already released the line: 0 failures in
  111 drive starts at 10 MHz and 376 at 50 MHz.
- Monitor tightened, as asked, from "falls within one clock" to exact alignment:
  any clock with `sdio_oe != (spi_state == S_READ)` fails, with no tolerance.
- Evidence, before -> after: misaligned clocks 222 -> 0 at 10 MHz and 752 -> 0
  at 50 MHz (two per read before: one late take-over, one late release); every
  read test passes at both clocks; release after the filtered CS rises 2 -> 1
  clock; setup margin of the first data bit at the master's sampling edge 2.8 ->
  2.9 us (10 MHz) and 3.76 -> 3.78 us (50 MHz) at 250 kHz SCK. Full integration
  testbench PASS, 0 FAIL lines, at 10 MHz (Verilator SV, Icarus converted) and
  50 MHz (Verilator SV).
- Regression: `make lint` and `make lint_notel` clean; `make -B convert` clean
  (2318 lines); `make equiv_all` 8/8 in both tables, every cover, 0 assertion
  failures.
- Cells: spi_slave 306 -> 307 cells (80 flops), 3,359.5 -> 3,353.2 um^2;
  reg_file unchanged. Flattened: flops 693 -> 693, comb cells 2,086 -> 2,113,
  cell area 30,522 -> 30,644 um^2 - ABC result variation across module
  boundaries, since the module itself shrank.
- Undo: `git revert <hash>` (back to one clock of trailing drive).

## 13. 2026-10-31 19:14 UTC - tb: Silicluster integration testbench `tb/pmic_top_tb.v`

- Files: `tb/pmic_top_tb.v` (new, one module, plain Verilog-2005). Nothing else
  in `tb/` touched.
- What: the submission testbench required by the call (section 6, "a Verilog
  testbench to verify the operation of the design"), driving `pmic_top` only
  through its pins with board models around it: a free-running asynchronous
  450 kHz modulator, the SCR latch read back on latch_stat, comparator levels,
  the enable switch, and an SPI master with CRC-8. All configuration goes over
  SPI into the register map; no RTL timer is shortened.
- Structure, following project rules section 4:
  - every check prints PASS/FAIL and is counted; one verdict line; everything
    is also written to `pmic_top_tb.log`;
  - run-long monitors every clock: SDIO driven exactly while the SPI slave is
    in S_READ (no tolerance), first data bit valid at every drive start,
    switch_supply == PGOOD, no PGOOD without En, PWM backstop, latch_out
    set-only, SDIO contention;
  - two scoreboards compared every clock: a reference model of the supervisor
    FSM (state and En, from the supervisor's own inputs) and a shadow of the
    register map built from the bytes sent and the documented rules (delay
    line, keys, deferred CONTROL, S_OFF-only registers, all-three-bytes rule,
    clamps), also checked against every byte read back;
  - 51 coverage bins, each set only when a monitor sees the DUT reach the
    condition (all eight FSM transitions, every fault entry and exit path,
    hiccup retry, strike levels 1-3 and latch, strike clear, ramp ceiling, PGOOD
    qualify and both drops, every SPI read/write/abort/reject path, the
    timestamp snapshot, the fault-log clear, the watchdog, a stuck modulator);
    any unhit bin fails the run;
  - fork/join with disable for every timed wait; the unavoidable 100 ms
    clean-run window runs concurrently with 32 directed-random register
    transactions, 16 random duty corners and 6 random sub-debounce OTP glitches
    (seeded xorshift32 rather than $random, whose sequence Verilator does not
    reproduce, so both simulators get identical stimulus);
  - force/release only where a state is otherwise unreachable: an illegal SPI
    state encoding, and the 5 s host-silence watchdog (via its wd_mark
    reference, so no counter is disturbed);
  - new paths beyond the first version: S_SS -> S_OFF (UVLO in the ramp),
    S_HICCUP -> S_OFF (OTP in the cool-down), enable switch off/on, the length
    and alignment aborts, S_OFF-only rejection while running, a stuck-high
    modulator.
- Honest scope, as the rules ask: the coverage table proves the stimulus
  arrived; it does not prove the design correct the way the SVA suite does.
  The checks and scoreboards carry that weight, for what they compare.
- Testbench bugs found and fixed while building it (none were RTL issues):
  real-to-integer double rounding in the ramp measurement; a same-edge race
  between a waiting task and the pulse monitor (1 ns settle after each PWM_out
  edge wait); a modulator whose edges landed exactly on clock edges every 4.5
  periods, which the two simulators order differently (fixed 37.3 ns start
  offset); and a watchdog force on the millisecond net that Verilator and
  Icarus resolve differently (moved to wd_mark).
- Results at this commit, 0 FAIL lines and 51/51 bins in every run:
  Verilator on the SV source at 10 MHz and 50 MHz, Verilator on the converted
  Verilog at 10 MHz, Icarus on the converted Verilog at 10 MHz. SV source vs
  converted Verilog, and Verilator vs Icarus, produce identical check lines
  including timestamps - no divergence between the SystemVerilog and the
  Verilog. FSM scoreboard ~4.8 M clocks compared, 0 mismatches; register-map
  scoreboard ~4.7 M clocks and 87 read-back bytes, 0 mismatches.
- No RTL or area change.
- Undo: `git revert <hash>` (entry 14 runs it from make; revert that first).

## 14. 2026-10-31 19:14 UTC - sim: run the integration testbench from make

- Files: `sim/Makefile`, `sim/scripts/run_top_tb.sh` (new).
- What: targets `tb_top` (Verilator, SV source), `equiv_top` (Verilator,
  converted Verilog), `iv_top` (Icarus, converted Verilog) and `top_all`.
  `tb_all`, `equiv` and `equiv_all` now include it, listed as `pmic_top_tb`
  with its coverage bins in the covers column; `make list` shows it.
- The runner takes the verdict from the testbench's last line and writes the
  record `report.sh` reads. It is also what gives Icarus a non-zero exit on a
  FAIL: vvp exits 0 from `$stop` and Verilog-2005 cannot set an exit code.
  Checked with stand-in testbenches: FAIL -> exit 1, PASS -> exit 0.
- Lint waivers, testbench code only, each documented in the Makefile: BLKSEQ,
  PROCASSINIT, WIDTHTRUNC, ZERODLY, REALCVT, UNUSEDSIGNAL, MULTIDRIVEN (the
  deliberate force/release); ENUMVALUE for the SV source only (the forced
  illegal state lands in an enum register there); TIMESCALEMOD for the
  converted single file only (sv2v drops `timescale; the RTL has no delays).
- Evidence: `make -j4 equiv_all` 9/9 PASS in both tables (the 8 module
  testbenches plus pmic_top_tb at 51/51 bins); `make iv_top` PASS 51/51.
- No RTL or area change. CI (`rtl.yml`) runs `equiv_all`, so it now runs the
  integration testbench too, with Verilator only.
- Undo: `git revert <hash>`.

## 15. 2026-10-31 19:39 UTC - package: the Silicluster submission tree and zip

- Files: `submission/rtl/**` (17 new `.v` files, the annotated split tree),
  `submission/README.md` (new), `Build/sync_buck_pmic_silicluster_v3.zip`
  (new, the file to email), `sim/Makefile` (`package`, `package_check`, `zip`,
  `SPLIT=1`), `sim/scripts/strip_compare.py` (new), `.gitignore`
  (`Build/package_raw/`, and `Build/area_notel.txt` untracked like `area.txt`).
- What, following project rules section 7:
  - `make package` runs `sv2v -w adjacent` on a copy of `rtl/` in a clean staging
    tree, `Build/package_raw`, and drops `pmic_types_pkg.v` (two pragmas and
    nothing else - the package is inlined into its consumers). 17 files.
  - Comments restored into `submission/rtl/`: every file header, every Purpose
    block on its matching `always`, and the signal and parameter descriptions.
    Method, stated plainly: a first pass placed by a script that matches each
    `always` and each declaration to its SystemVerilog counterpart, then every
    file reviewed and edited by hand. Adapted where the conversion changed the
    code: inlined package constants and functions carry the package's
    descriptions; `_sv2v_0`, the `sv2v_cast_*` helpers, the converted `$error`
    checks and `(* full_case, parallel_case *)` are explained where they occur;
    the enum names the conversion replaced with literals are tabulated at each
    state register and named on every use; `pmic_top`'s section, instance and
    generate comments restored; one stale sentence about package imports
    removed. `supervisor.sv` has no header or Purpose blocks, so `supervisor.v`
    got new ones from its state comments, and the few one-line blocks the source
    leaves without a Purpose got short ones - every `always` in the tree has one.
  - The one non-comment line added is `timescale 1ns/1ps`, which every source
    file carries and sv2v drops; with it neither simulator warns about a missing
    timescale. Two source comments that were already wrong are corrected in the
    submission copy only (the `.sv` keep theirs): fault_cause's window_trip_SS
    port said "in S_RUN" (it is S_SS), and fault_LED named a state S_LATCHED
    that does not exist.
  - `make package_check` strips comments and the timescale line from both trees
    and requires identical token streams: 17 of 17 files code-identical to fresh
    sv2v output. Negative test: a one-token edit is reported.
- Re-verification on the annotated files themselves (project rules 7.3):
  `make equiv SPLIT=1` - all 8 module testbenches with their SVA and
  `pmic_top_tb` (51/51 bins) PASS; `make iv_top SPLIT=1` - PASS 51/51. The
  check lines are identical, timestamps included, to the run on the
  SystemVerilog source.
- The zip: `README.md`, `rtl/` (the annotated files), `tb/pmic_top_tb.v`. Built
  by `make zip`, which runs `package_check` first. Verified by extracting it into
  an empty directory and running exactly the README's commands: Icarus 12 PASS
  51/51; Verilator 5.052 PASS 51/51, warning-free with the README's flags;
  identical check lines between the two.
- README (project rules 7.4): the design, every pin, clock and reset
  expectations, the SPI frame format and host speed limit, how to compile and
  run the testbench in both simulators, what the coverage table does and does
  not mean, `TELEMETRY_EN = 1` as submitted, area with the basis for the
  additional-area request, known limitations.
- No RTL or area change: the netlist is that of entry 12 (693 flops, 30,644
  um^2 cell area, 2.60x the standard slot; 0.89x with TELEMETRY_EN=0).
- Undo: `git revert <hash>`.

## 16. 2026-10-31 19:39 UTC - docs: commit hash of every changelog entry

- Files: `docs/CHANGELOG_silicluster_v3.md` (this table).
- Undo: `git revert <hash>` (documentation only).

## 17. 2026-10-31 20:01 UTC - top: split the bidirectional SDIO pin into MOSI and MISO

- Files: `rtl/pmic_top.sv` (ports and wiring), `rtl/telemetry/spi_slave.sv`
  (comments only), `tb/pmic_top_tb.v`, `Build/*` (regenerated),
  `docs/silicluster_area.md`. Requested by the user.
- Why: the Silicluster call offers 14 digital inputs and 14 digital outputs and
  never mentions bidirectional pins or output enables, and the project's
  `pmic_top` is not the chip top - the integration harness sits between its
  ports and the pads, so the `1'bz` inside it would be an internal tri-state.
  Synthesis already warned "Yosys has only limited support for tri-state
  logic", and the old netlist shows why that matters: yosys kept no tri-state
  buffer and deleted the `sdio_oe` enable flop, so the synthesised chip would
  have driven SDIO permanently and fought the host on every command and write.
- What: `inout SDIO` becomes `input MOSI` and `output MISO`. MOSI feeds the
  same synchroniser and filter SDIO did (instances and nets renamed `mosi_*`).
  `MISO = sdio_oe & sdio_out`: read data while spi_slave is in S_READ, low at
  every other time; tied low when TELEMETRY_EN = 0. No tri-state remains.
  spi_slave keeps its ports (`sdio_in`, `sdio_out`, `sdio_oe`) and every line of
  logic; only its comments were updated from the shared line to MOSI/MISO.
- SPI behaviour unchanged, as the user required: same mode 0 framing, CRC-8,
  dummy turnaround byte and timing. Proof: (1) the converted `spi_slave`,
  `reg_file`, `supervisor`, `fault_arbiter`, `soft_start` and `pwm_mask` modules
  are byte-identical to before; the only converted-code difference is
  `pmic_top`'s ports and wiring. (2) Every check of the integration testbench
  gives the same result at the same timestamp as before the split; the only
  differing lines are renamed labels and one new check.
- Pins: 10 inputs (SCK, CS_n, MOSI, Osc_in, CP_trig, OTP_trig, UVLO_trig,
  latch_stat, PGOOD_comp, en_from_switch) and 11 outputs (MISO plus the
  existing 10), with clk and rst on their own pins: 10/14 and 11/14.
- MISO is always driven, low when idle, so sharing it with other SPI devices
  needs an external buffer; one device on the bus is unaffected.
- Testbench: the master drives MOSI and samples MISO; new pin-level checks that
  MISO is low whenever the slave is not in S_READ and never x or z; the exact
  sdio_oe-to-S_READ alignment check is kept.
- Gate: `make lint` and `make lint_notel` clean; `make -B convert` clean (2320
  lines); `make equiv_all` 9/9 in both tables; integration testbench PASS with
  51/51 bins at 10 MHz (Verilator SV source, Icarus converted) and 50 MHz;
  synthesis log no longer has a tri-state warning.
- Area: flops 693 -> 694 (the sdio_oe flop the old flow deleted), comb cells
  2,113 -> 2,119, cell area 30,644 -> 30,737 um^2 (2.61x the slot). Per module:
  spi_slave unchanged (307 cells, 80 flops); pmic_top +1 cell, the AND gate.
  TELEMETRY_EN = 0 unchanged (252 flops, 10,523 um^2).
- Undo: `git revert <hash>` (entry 18 regenerates the submission from this;
  revert that first).

## 18. 2026-10-31 20:07 UTC - package: regenerate the submission for MOSI/MISO

- Files: `submission/rtl/**` (regenerated and re-annotated), `submission/README.md`,
  `Build/sync_buck_pmic_silicluster_v3.zip`, `rtl/pkg/pmic_types_pkg.sv` (one
  comment: the SPI filter note said "SCK and SDIO", now "SCK and MOSI";
  sv2v drops comments, so the converted file is byte-identical).
- What: `make package` from the entry-17 RTL, the same comment restoration as
  entry 15 with the pmic_top texts updated from the shared SDIO line to MOSI and
  MISO, and the README's pin table (10 inputs, 11 outputs, no bidirectional
  pin), SPI description, monitor description, area figures and a new known
  limitation (MISO is always driven) updated.
- Gate: `make package_check` 17 of 17 files code-identical to fresh sv2v output;
  `make equiv SPLIT=1` 9/9 PASS (pmic_top_tb 51/51 bins); `make iv_top SPLIT=1`
  PASS 51/51. The rebuilt zip, extracted into an empty directory and run with
  the README's commands: Icarus PASS 51/51 and Verilator PASS 51/51, both with
  zero build warnings, identical check lines.
- Undo: `git revert <hash>`.

## 19. 2026-10-31 20:10 UTC - package: rebuild the zip, which entry 18 left stale

- Files: `Build/sync_buck_pmic_silicluster_v3.zip`.
- CORRECTION to entry 18: its zip was NOT rebuilt. In that gate run `make zip`
  executed from the wrong directory and failed silently, so the committed zip
  was still the pre-split (SDIO) one from entry 15, and the "zip test" in entry
  18 extracted and passed that old zip. The annotated files and README in entry
  18 were correct; only the zip was stale. Caught by checking the zip's
  contents after the commit.
- Now: rebuilt by `make zip` (package_check first: 17 of 17 code-identical) and
  checked to contain the MOSI/MISO files (zipped `pmic_top.v` has MOSI and MISO
  and no SDIO; README and testbench likewise). Extracted into an empty directory
  and run with the README's commands: Icarus PASS and Verilator PASS, 216
  checks, 51/51 bins, zero build warnings, identical check lines.
- Undo: `git revert <hash>` (restores the stale zip - do not).

## 20. 2026-10-31 20:11 UTC - docs: commit table updated for entries 17-19

- Files: `docs/CHANGELOG_silicluster_v3.md` (the table below).
- Undo: `git revert <hash>` (documentation only).

## 21. 2026-10-31 20:21 UTC - package: correct the README's check count

- Files: `submission/README.md` (two sentences), `Build/sync_buck_pmic_silicluster_v3.zip`
  (rebuilt so it carries the corrected README).
- CORRECTION to entries 15 and 18: the README said "directed checks - 215".
  That was the total count before the MOSI/MISO change, and entry 18 did not
  update it when that change added one check. A fresh run of the README's own
  commands on `submission/rtl` reports 216 checks: 198 directed checks plus 18
  end-of-run monitor and scoreboard verdicts. The README now gives 198 for the
  directed layer, and its Results line gives 216 checks, 0 failures, 51/51 bins.
- Evidence (2026-10-31, before the edit): Icarus 12 216 checks, 0 failed,
  51/51 (1 min 48 s); Verilator 5.052 the same (8 s); `make tb_top` on the
  SystemVerilog source the same; all three with identical check lines.
- No RTL, testbench or Verilog file changed.
- Undo: `git revert <hash>` (documentation and zip only).

---

## Commit table

Every entry above is exactly one commit on this branch. To undo one, revert its
commit (`git revert <commit>`), newest first where entries depend on each
other, then rerun the gate: `cd sim && make lint && make -B convert && make -j4
equiv_all`, and for the submission `make package_check && make equiv SPLIT=1`.
Commit times are UTC and are the times each entry records.

| Entry | Commit | Time (UTC) | Subject |
|------:|--------|------------|---------|
|  1 | `d4ab8f4` | 2026-10-31 17:13 | docs: start the Silicluster v3 changelog and area log |
|  2 | `77c3e12` | 2026-10-31 17:14 | sim: write synthesis statistics with tee -o, add area summary script |
|  3 | `f76243b` | 2026-10-31 17:17 | pkg: CLK_HZ 50 MHz -> 10 MHz for the Silicluster v3 clock limit |
|  4 | `a9435bd` | 2026-10-31 17:17 | sim: have yosys write its full log with -l instead of a stdout redirect |
|  5 | `38714cc` | 2026-10-31 17:19 | pkg: round minimum-time conversion up so MIN_ON_COUNTS holds at 10 MHz |
|  6 | `3f38794` | 2026-10-31 17:20 | pkg: default soft-start step 16 -> 64 cycles to restore the ramp length |
|  7 | `456761f` | 2026-10-31 17:23 | top: add TELEMETRY_EN to select the host interface in or out |
|  8 | `371f431` | 2026-10-31 18:17 | fix(spi_slave): drive SDIO for the whole read data phase |
|  9 | `0fa1398` | 2026-10-31 18:19 | fix(spi_slave): increment the write address after the strobe, not with it |
| 10 | `ea2b915` | 2026-10-31 18:35 | tb: scale the pgood_gen and pwm_stats watchdogs with the clock period |
| 11 | `2207257` | 2026-10-31 18:38 | fix(reg_file): clear the fault log only on a completed read of 0x20 |
| 12 | `e9bfcdc` | 2026-10-31 18:42 | fix(spi_slave): register sdio_oe from the next state so it tracks S_READ exactly |
| 13 | `3a586ff` | 2026-10-31 19:14 | tb: add the Silicluster integration testbench pmic_top_tb.v |
| 14 | `29684c7` | 2026-10-31 19:14 | sim: run the integration testbench from make, in all three flows |
| 15 | `7a58492` | 2026-10-31 19:39 | package: Silicluster submission tree, README and zip |
| 16 | `a9fa9c8` | 2026-10-31 19:39 | docs: record the commit hash of every changelog entry |
| 17 | `478fd75` | 2026-10-31 20:01 | top: split the bidirectional SDIO pin into MOSI and MISO |
| 18 | `bc7fba0` | 2026-10-31 20:07 | package: regenerate the submission for MOSI/MISO |
| 19 | `c767707` | 2026-10-31 20:10 | package: rebuild the zip, which the previous commit left stale |
| 20 | `5f68f60` | 2026-10-31 20:11 | docs: update the changelog commit table for entries 17-19 |

Entry 21 is the newest commit touching this file, so its own hash is:
`git log -1 --format=%h -- docs/CHANGELOG_silicluster_v3.md`.
