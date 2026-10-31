# Silicluster v3 area log

Append-only. One row per synthesis run that follows an RTL change. Never edit
an old row; the trend is the useful part.

## Method

- Input: `Build/pmic_full.v`, the sv2v output of `rtl/`, top `pmic_top`.
- Flops and mapped combinational cells: `make syn_area` (yosys `synth -flatten`,
  `dfflibmap` + `abc` against `sky130_fd_sc_hd__tt_025C_1v80.lib`), counted
  from the mapped `stat -liberty` table. "Comb cells" is every mapped sky130
  cell that is not a flop.
- **Cell area** is the yosys `Chip area` figure: the sum of standard-cell
  footprints. It is NOT die area.
- **Die area** = cell area / 0.57, a utilisation assumption of 57% carried over
  from the earlier estimate on `main`. Real P&R utilisation will differ.
- **Slot ratio** = die area / 20,700 um^2. The standard digital slot is
  180 um x 115 um = 20,700 um^2 (Silicluster v3 call, section 7).
- Tool: Yosys 0.70 (YoWASP build) unless stated. Yosys 0.33 (Ubuntu 24.04
  package, the version CI installs) was cross-checked on the baseline and gives
  the same 730 flops, 2,336 comb cells, 32,492 um^2.

## Runs

| Date (UTC)       | Commit / changelog entry | Clock  | TELEMETRY_EN | Flops | Comb cells | Cell area (um^2) | Die @57% (um^2) | Ratio vs slot | Note |
|------------------|--------------------------|--------|--------------|-------|------------|------------------|-----------------|---------------|------|
| 2026-10-31 17:10 | a70e4a9 (main)           | 50 MHz | (n/a, =1)    | 730   | 2,281      | 32,369           | 56,787          | 2.74x         | baseline, `main` as received |
| 2026-10-31 17:17 | chg 3: CLK_HZ 10 MHz     | 10 MHz | (n/a, =1)    | 700   | 2,137      | 30,821           | 54,072          | 2.61x         | -30 flops from narrowed counters, as derived |
| 2026-10-31 17:19 | chg 5: ns_to_clks ceil   | 10 MHz | (n/a, =1)    | 700   | 2,132      | 30,845           | 54,113          | 2.61x         | MIN_ON_COUNTS 2 -> 3; width unchanged |

Commit hashes for each changelog entry are in the table at the end of
`docs/CHANGELOG_silicluster_v3.md`.

## Findings

- **2026-10-31, baseline differs from the reference in the project rules.** The rules
  quote 730 flops, 3,039 mapped combinational cells, ~43,000 um^2 cell area and
  ~75,500 um^2 die for `main`. Flops agree exactly. The mapped run here gives
  2,281 combinational cells and 32,369 um^2 cell area (Yosys 0.70), and 2,336 /
  32,492 um^2 with Yosys 0.33. 3,039 matches the GENERIC gate count in the
  committed `Build/stat.txt` (3,793 cells - 730 flops - 31 `$scopeinfo` =
  3,032), so the earlier figure most likely came from the unmapped netlist and
  overstates the area by roughly a third. All figures below are measured
  sky130 numbers.
