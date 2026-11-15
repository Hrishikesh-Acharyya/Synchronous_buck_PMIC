# Place and route of pmic_top - does it fit the Silicluster slot?

The Silicluster v3 call gives the digital slot as 180 um x 115 um and leaves
the fit check to the designer. Synthesis gives only cell area; whether a block
fits is decided by placing and routing it into the box. This directory does
that with OpenROAD and the SkyWater sky130_fd_sc_hd library, for both
`TELEMETRY_EN` builds, and keeps the results.

## Results (2026-11-15, the resubmission netlists)

The design changed between the first submission and this one (see the package
READMEs), so every run was made again on the new netlists: the reduced build
is the same size as before (10,453 um^2 of cells), the full build 3.5% larger
(31,811 um^2).

OpenROAD 2.0-12381-g01bba3695 (litex-hub conda build), sky130_fd_sc_hd typical
corner. Every run: core inset from the die by the margin given, pins on the die
edge (met2/met3), tap cells every 14 um, power grid met1 rails + met4 vertical +
met5 horizontal straps, placement, resizing and buffering, clock tree, setup
and hold repair, global routing, TritonRoute detailed routing, fillers; then
parasitics extracted from the routed wires (OpenRCX) for timing at 10 MHz.
Utilisation is cell area (taps, buffers and clock tree included, fillers not)
over core area.

### Reduced build, `TELEMETRY_EN = 0`

| Die (um) | vs slot | Margin | Utilisation | Result | Setup / hold slack |
|---|---|---|---|---|---|
| 180 x 115 | 1.00x | 2 um | 66% | routed, 0 DRC violations | +97.3 / +0.30 ns |
| 180 x 115 | 1.00x | 5 um | 72% | routed, 0 DRC violations | +97.3 / +0.34 ns |
| 180 x 115 | 1.00x | 10 um | 84% | routed, 0 DRC violations | +96.1 / +0.32 ns |
| 180 x 100 | 0.87x | 2 um | 75% | routed, 0 DRC violations | +97.3 / +0.34 ns |
| 180 x 90 | 0.78x | 2 um | 84% | routed, 0 DRC violations | +97.0 / +0.35 ns |
| 180 x 80 | 0.70x | 2 um | 96% | routed, 0 DRC violations, after 21 router passes | +95.1 / +0.28 ns |

It fits the standard slot with margin to spare: with 10 um reserved all round,
or in 70% of the slot (only just, at that size). About 20 mm of wire and 7,500
vias in the standard slot, almost all on met1 and met2. Power about 225 uW
(default switching activity, not a simulation).

### Full build, `TELEMETRY_EN = 1`

| Die (um) | vs slot | Margin | Utilisation | Result | Setup / hold slack |
|---|---|---|---|---|---|
| 180 x 115 | 1.0x | 2 um | 168% | cells do not fit | - |
| 180 x 230 | 2.0x | 2 um | 94% | global routing fails (congestion) | - |
| 180 x 288 | 2.5x | 2 um | 75% | detailed routing still running when this was committed - see the next commit | - |
| 180 x 345 | 3.0x | 2 um | 63% | routed, 0 DRC violations, 14 router passes | +94.3 / +0.34 ns |

3x the slot routes comfortably. About 94 mm of wire and 25,000 vias; power
about 600 uW (default activity).

Timing is no constraint at 10 MHz (100 ns): the longest register-to-register
path is about 3 ns in the reduced build and 6 ns in the full build.

Caveat: Silicluster integrates with its own flow - pin positions, power grid,
margins and settings may differ from these. The reduced build passes at every
margin tried, which is the reason to trust it.

`results/` holds, per run, `metrics.txt` (every number), the timing, power,
skew and DRC reports, the gzipped flow log, routed DEF and post-route netlist,
and `results/summary.tsv`, one row per run. Pictures of five routed runs are
in `results/images/`.

### Against the first submission (2026-10-31)

| | First submission | This one |
|---|---|---|
| Reduced build in the slot, 2 um margin | 66%, routed | 66%, routed |
| Reduced build, smallest die routed | 180 x 90 um (180 x 80 failed in global routing) | 180 x 80 um |
| Full build at 3x | 61%, routed, 14 router passes | 63%, routed, 14 router passes |
| Full build at 2.5x | 72%, routed, 41 router passes | 75%, result in the next commit |

## Reproducing

1. OpenROAD: `micromamba create -p <prefix> -c litex-hub -c https://repo.anaconda.com/pkgs/main openroad python=3.8`
   (or any OpenROAD build of early 2024 or later).
2. `./fetch_platform.sh` - LEFs and set-up scripts from OpenROAD-flow-scripts,
   the liberty from volare (`LIBERTY=<path>` to override).
3. `YOSYS=<yosys> ./synth.sh` - netlists for both builds from
   `Build/pmic_full.v` (run `make convert` in `sim/` first if the RTL changed).
4. `OPENROAD=<openroad> ./run_pnr.sh <TELEMETRY_EN> <die_w> <die_h> [margin]`,
   e.g. `./run_pnr.sh 0 180 115`. A reduced-build run takes about 2 minutes;
   a full-build run 10-40 minutes, nearly all of it detailed routing.
5. `./summarize.py` - one line per run, and `work/summary.tsv`.
6. `./collect.py` - rebuild `results/` from `work/` (reports, gzipped logs and
   layouts, the summary and the pictures).

`platform/` and `work/` are generated and not committed.
