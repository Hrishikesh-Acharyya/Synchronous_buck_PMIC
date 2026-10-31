# Synchronous Buck PMIC — 5 V / 5 A converter with a digital supervisor chip

A 25 W synchronous buck converter (10.8–22 V in, 5 V / 5 A out, 450 kHz),
designed end to end: power stage, analog control loop, component selection,
and a **digital supervisor ASIC** that owns sequencing, protection and
telemetry. The supervisor is verified, synthesised, and placed and routed in
**SkyWater SKY130**, and is prepared for fabrication on the
**Silicluster v3** multi-project chip.

> **This branch, `silicluster-v3`, is the tapeout candidate.** Two Verilog
> packages are submitted: the full chip, [`submissions_full/`](submissions_full/)
> ([README](submissions_full/SILICLUSTER_README.md)), and the protection-only
> chip that fits a single slot, [`submissions_trimmed/`](submissions_trimmed/)
> ([README](submissions_trimmed/SILICLUSTER_README.md)).

## At a glance

| | |
|---|---|
| **Power stage** | 10.8–22 V → 5 V / 5 A, 450 kHz, synchronous rectification, LM5106 gate driver |
| **Analog loop** | Type III voltage mode: 19.2–19.3 dB gain margin and 61.9–63.9° phase margin at every load from µA to 5 A, crossover ~56 kHz |
| **Supervisor chip** | 17 RTL modules: 4-state supervisor, soft start, PWM backstop, overcurrent windows, escalating hiccup, SCR-latch control, OTP/UVLO, power-good, status LEDs, SPI telemetry with CRC-8 |
| **Chip interface** | 10 inputs, 11 outputs, `clk` and `rst` (of 14 / 14 available), 10 MHz, 1.8 V |
| **Verification** | Plain Verilog-2005 integration testbench: 277 checks, 86 coverage bins including every fault crossed with every state, two scoreboards checked every clock; 8 module testbenches with 52 SVA assertions; identical results on Icarus and Verilator, on the SystemVerilog source and the submitted Verilog |
| **Physical design** | Yosys + OpenROAD on `sky130_fd_sc_hd`: routed with 0 router DRC violations; 10 MHz timing met with ~95 ns of slack |
| **Scalable area** | One parameter, `TELEMETRY_EN`: the full chip routes in 2.5–3× the standard slot; the protection-only chip routes in a single 180 × 115 µm slot |

## System architecture

```mermaid
flowchart LR
    subgraph PWR["Power stage (discrete)"]
        VIN["10.8–22 V"] --> SW["HS / LS MOSFETs<br/>LM5106 driver"] --> LC["L + C<br/>5 V / 5 A"]
    end
    subgraph ANA["Analog control and fast sensing"]
        T3["Type III<br/>compensator"] --> PWM["450 kHz ramp +<br/>PWM comparator"]
        CMP["Comparators: valley current,<br/>OTP, UVLO, output window"]
        SCR["SCR protection latch<br/>(analog OVP trips it)"]
    end
    subgraph DIG["Supervisor ASIC (SKY130)"]
        SUP["pmic_top<br/>sequencing · protection · telemetry"]
    end
    LC -- "V_out" --> T3
    PWM -- "Osc_in" --> SUP
    CMP -- "fault flags" --> SUP
    SCR -- "latch_stat" --> SUP
    SUP -- "PWM_out, En" --> SW
    SUP -- "latch_out" --> SCR
    SUP <-->|"SPI"| HOST["Host"]
```

The inner voltage loop stays analog: it is fast and fully characterised. Every
*decision* — when to switch, when to stop, when to retry, when to give up —
moves into the chip, which takes the analog comparators' outputs as
asynchronous flags. The SCR latch is shared: the analog OVP comparator trips
it at analog speed, the chip trips it after repeated overcurrent, and the chip
reads it back to sequence the restart.

## Analog design

| Load | Gain margin | Phase margin | Crossover |
|---|---|---|---|
| µA | 19.2 dB | 61.9° | 56.21 kHz |
| 100 mA | 19.2 dB | 61.9° | 56.21 kHz |
| 5 A | 19.3 dB | 63.9° | 56.18 kHz |

| Loop gain, µA load | Loop gain, 5 A load | Output voltage, 5 A |
|---|---|---|
| <img src="simulations/pictures/Very_light_load_uA/Figure3_Loop_Gain_Margins_uA_very_Light_Load.png" width="280"> | <img src="simulations/pictures/Heavy_loads_5A/Figure3_Loop_Gain_Margins_5A_Heavy_Load.png" width="280"> | <img src="simulations/graphs_or_pdfs/vout_heavy_load.png" width="280"> |

- **Stable across five decades of load.** A first compensator, tuned at a
  single operating point, showed healthy margins (21.8 dB, 60.2°) yet rang to
  ±15 A at light load: the LC double pole sharpens as the load falls. The
  retuned design is verified at µA, 100 mA and 5 A, and the old design is kept
  in the repository as the record of why one operating point is not enough.
- **Designed against derated parts.** The 47 µF output MLCC is ≈35 µF at 5 V
  bias (−25.6 %); the plant model uses the derated value, which keeps the LC
  pole where the compensator expects it.
- **MOSFETs chosen by an automated pipeline**: DigiKey and Mouser APIs →
  datasheet extraction with Gemini → loss-based ranking at 29 switching
  frequencies from 100 to 800 kHz, for two candidate gate drivers
  ([`Mosfet_extraction_pipeline/`](Mosfet_extraction_pipeline/)).
- **Four protection tiers**: soft start, cycle-by-cycle valley current limit,
  hiccup retry, and static UVLO / OVP / OTP / reverse-polarity protection.

<details>
<summary><b>More analog results: plant, compensator, overlays and transients at each load, circuit schematics</b></summary>

| | µA | 100 mA | 5 A |
|---|---|---|---|
| Plant | <img src="simulations/pictures/Very_light_load_uA/Figure1_Power_Stage_Plant_uA_very_Light_Load.png" width="230"> | <img src="simulations/pictures/Light_loads_100mA/Figure1_Power_Stage_Plant_100mA_Light_Load.png" width="230"> | <img src="simulations/pictures/Heavy_loads_5A/Figure1_Power_Stage_Plant_5A_Heavy_Load.png" width="230"> |
| Compensator | <img src="simulations/pictures/Very_light_load_uA/Figure2_Type_III_Compensator_uA_very_Light_Load.png" width="230"> | <img src="simulations/pictures/Light_loads_100mA/Figure2_Type_III_Compensator_100mA_Light_Load.png" width="230"> | <img src="simulations/pictures/Heavy_loads_5A/Figure2_Type_III_Compensator_5A_Heavy_Load.png" width="230"> |
| Overlay G, C, T | <img src="simulations/pictures/Very_light_load_uA/Figure4_System_Overlay_uA_very_Light_Load.png" width="230"> | <img src="simulations/pictures/Light_loads_100mA/Figure4_System_Overlay_100mA_Light_Load.png" width="230"> | <img src="simulations/pictures/Heavy_loads_5A/Figure4_System_Overlay_5A_Heavy_Load.png" width="230"> |
| Transients | <img src="simulations/pictures/Very_light_load_uA/Figure5_System_Transients_uA_very_Light_Load.png" width="230"> | <img src="simulations/pictures/Light_loads_100mA/Figure5_System_Transients_100mA_Light_Load.png" width="230"> | <img src="simulations/pictures/Heavy_loads_5A/Figure5_System_Transients_5A_Heavy_Load.png" width="230"> |

| Power stage | Oscillator | Type III compensator | Soft start |
|---|---|---|---|
| <img src="simulations/pictures/Plant.png" width="200"> | <img src="simulations/pictures/Oscillator.png" width="200"> | <img src="simulations/pictures/compensator.png" width="200"> | <img src="simulations/pictures/Soft_start.png" width="200"> |
| **Valley current limit** | **Over-temperature** | **Overvoltage latch** | **Switch node** |
| <img src="simulations/pictures/SCP_OCP.png" width="200"> | <img src="simulations/pictures/OTP.png" width="200"> | <img src="simulations/pictures/OVP.png" width="200"> | <img src="simulations/graphs_or_pdfs/switch_node.png" width="200"> |

Models: LTspice behavioural models in [`simulations/`](simulations/) run from a
clean clone (vendor device models are not redistributed). Compensator: MATLAB
Control System Designer sessions and the plotting script in
`simulations/MATLAB_code/`.

</details>

## The supervisor chip

SystemVerilog source in [`rtl/`](rtl/), converted to Verilog-2005 for the
Silicluster flow: one file per module, comments restored by hand and proved
code-identical to the converter's output (`make package_check`).

| Block | Behaviour |
|---|---|
| **Supervisor** | Off → soft start → run, hiccup on overcurrent. Any fault forces off in the same clock — the gate-driver enable is gated combinationally — and every retry re-ramps from the minimum pulse. |
| **Soft start and PWM backstop** | The on-time ceiling ramps from the minimum gate pulse to a 75 % duty backstop, 64 switching cycles a step; every pulse is truncated at the ceiling, and a stuck-high modulator yields one capped pulse. |
| **Overcurrent** | One valley-current sample per switching cycle in rolling windows: trip at 12 faulted cycles in 16 while running, 28 in 32 during soft start. |
| **Hiccup and strikes** | Cool-down from a 5 ms base, doubling with each strike; the third strike trips the SCR latch; 1 s of clean running clears the strikes. |
| **OTP, UVLO, latch readback** | Synchronised and debounced (1 ms to assert, 200 µs to release), fail-safe out of reset. |
| **Power good** | Qualified for 9 ms in run, dropped immediately; drives a supply-changeover output. |
| **Status LEDs** | Running, power good, strikes outstanding (blink) or latched (solid), over-temperature, undervoltage. |
| **Telemetry** (optional) | 4-wire SPI, CRC-8 on every write: identity, live status, PWM duty and period, millisecond timestamp, timestamped fault log, bus-error counter, keyed writable thresholds, keyed host disable with a 5 s silence watchdog. |

**One parameter, two chips.** `TELEMETRY_EN` builds the design with or
without the host interface. The protection logic is identical in both, and
the same testbench verifies both.

| | `TELEMETRY_EN = 1` (default) | `TELEMETRY_EN = 0` |
|---|---|---|
| Flops / cells / cell area | 694 / 2,119 / 30,737 µm² | 252 / 705 / 10,523 µm² |
| Routes in | 2.5–3× the standard slot | one 180 × 115 µm slot |
| Thresholds | defaults, writable over SPI | fixed at the defaults |
| Observability | full register map over SPI | pins and LEDs |

## Verification

The submission testbench, [`pmic_top_tb.v`](submissions_full/tb/pmic_top_tb.v), is a single
plain Verilog-2005 module. It drives only the chip's pins, with behavioural
models of the modulator, the comparators, the SCR latch and an SPI host, and
checks in four layers: directed checks; per-clock monitors; two scoreboards —
an independent reference model of the supervisor FSM and a shadow of the
register map, both compared every clock; and coverage bins that fail the run
if any is missed.

| Build | Checks | Coverage | Simulated | Scoreboard comparisons |
|---|---|---|---|---|
| `TELEMETRY_EN = 1` | 277, 0 failed | 86 / 86 | 0.79 s | 7.9 M clocks |
| `TELEMETRY_EN = 0` | 173, 0 failed | 54 / 54 | 1.43 s, default timers | 14.3 M clocks |

- Both builds pass on **Icarus Verilog and Verilator**, against the
  **SystemVerilog source and the submitted Verilog**, at 10 and 50 MHz, with
  identical check lines.
- Beyond the directed phases: every fault cause crossed with every state it
  can arrive in, the overcurrent window's exact threshold, strike escalation
  and the clean-run window restarting, glitch and chatter rejection,
  overlapping faults, reset while running, programmed thresholds reaching the
  protection, and SPI corner cases.
- Module level: **8 testbenches with 52 bound SVA assertions and 53 cover
  properties**, run against both the source and the converted Verilog.
- CI (GitHub Actions) lints the RTL and runs the full regression in both
  flows, and tracks synthesis cell counts on pull requests.
- Verification earned its keep before silicon: it caught wrong data on SPI
  reads, an off-by-one in write addressing, a fault-log clear that could fire
  on the wrong byte, and a tri-state that synthesis silently removed — the
  reason the SPI uses separate MOSI and MISO pins.

## Physical design

Synthesised with Yosys and placed and routed with OpenROAD on
`sky130_fd_sc_hd`: tap cells, a met1/met4/met5 power grid, clock tree, setup
and hold repair, detailed routing, and parasitics extracted from the routed
wires for timing.

| Build | Die | vs slot | Utilisation | Result |
|---|---|---|---|---|
| `TELEMETRY_EN = 0` | 180 × 115 µm | 1.0× | 66 % | routed, 0 DRC violations |
| `TELEMETRY_EN = 0` | 180 × 115 µm, 10 µm reserved all round | 1.0× | 84 % | routed, 0 DRC violations |
| `TELEMETRY_EN = 0` | 180 × 90 µm | 0.78× | 84 % | routed, 0 DRC violations |
| `TELEMETRY_EN = 1` | 180 × 230 µm | 2.0× | 90 % | does not route |
| `TELEMETRY_EN = 1` | 180 × 288 µm | 2.5× | 72 % | routed, 0 DRC violations |
| `TELEMETRY_EN = 1` | 180 × 345 µm | 3.0× | 61 % | routed, 0 DRC violations |

| Protection-only chip in the standard slot (180 × 115 µm) | Full chip at 3× the slot (180 × 345 µm) |
|---|---|
| <img src="pnr/results/images/reduced_180x115_border2um.png" width="430"> | <img src="pnr/results/images/full_180x345_border2um.png" width="190"> |

Timing is met at 10 MHz with 94–97 ns of setup slack (typical corner); the
longest register-to-register path is 2.8 ns (reduced) and 5.6 ns (full). DRC
figures are the detailed router's; sign-off DRC and LVS belong to the
integration flow. Flow, scripts and every run's reports:
[`pnr/`](pnr/README.md).

## Repository map

```
rtl/            supervisor chip, SystemVerilog (17 modules + package)
tb/, sva/       module testbenches (SystemVerilog) + bound SVA
sim/            Makefile: lint, convert, equiv_all, top_both, syn_both, package
submissions_full/     Silicluster v3 package, full chip: Verilog-2005 rtl/, tb/, README
submissions_trimmed/  the same, TELEMETRY_EN = 0: protection only, one slot
Build/          converted single-file Verilog, synthesis summaries
pnr/            OpenROAD place-and-route flow and results
docs/           changelog of this branch, area log
simulations/    LTspice models, MATLAB compensator sessions, figures
Mosfet_extraction_pipeline/   automated MOSFET sourcing and ranking
fpga/, quartus/ PYNQ-Z2 bring-up harness, Intel MAX 10 project
Sync_buck_convertor/          Altium project (layout not started)
```

## Run it

```bash
cd sim
make lint                # strict Verilator lint of the RTL
make -j4 equiv_all       # every testbench, SystemVerilog and converted Verilog, both builds
make top_both            # integration testbench, both builds, Verilator and Icarus
make syn_both            # sky130 area of both builds
make signoff             # ship check of both packages, ends in SIGNOFF OK
make zip                 # one zip per package
```

The integration testbench also runs straight from each package's own files —
see [`submissions_full/SILICLUSTER_README.md`](submissions_full/SILICLUSTER_README.md).

## Status

- **Done:** analog loop design and simulation, component selection,
  supervisor RTL, verification, synthesis, place and route, Silicluster v3
  package.
- **Next:** PCB schematic and layout, hardware bring-up with measured
  efficiency and transients, a light-load (DCM) mode.

## License and contributions

- **Code** (Python, MATLAB, scripts): MIT License — see `LICENSE`.
- **Hardware design** (schematics, PCB layout): CERN Open Hardware License v2 —
  see `LICENSE-CERN-OHL-P-2.0.txt`.

This repository is maintained as a technical portfolio. Issues documenting
errors or technical corrections are welcome; pull requests are not being
accepted at this time (see `CONTRIBUTING.md`).
