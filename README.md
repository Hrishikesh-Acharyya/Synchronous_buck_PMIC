# Synchronous Buck PMIC — 5 V / 5 A

**A complete discrete-component buck converter design with integrated analog control and protection — no single‑chip PWM controller.**

This project demonstrates the full power-electronics design chain: from power-stage topology, through analog compensator design and LTspice verification, to automated component selection and PCB layout. The repository contains simulation models, compensator tuning scripts, and a MOSFET selection pipeline.

---

## Quick Specs

| Specification | Value |
|---|---|
| **Output** | 5 V @ 5 A (25 W max) |
| **Input range** | 10.8 V – 22 V |
| **Switching frequency** | 450 kHz |
| **Efficiency** | ~92% at 5 A (22 V input) |
| **Gate driver** | LM5106 (discrete control logic) |
| **Control topology** | Voltage-mode, analog Type‑III compensator |
| **Protection tiers** | 4 (soft‑start, cycle‑by‑cycle current limiting, hiccup mode, UVLO/OVP/OTP) |

---

## Note on current development status

PCB layout and CPLD/FPGA digital logic design are next and not yet implemented. The behavioural LTspice model is used for analog verification; higher‑level sequencing (hiccup/state machines, forced‑LS cycles, PGOOD validation) will be migrated to the digital brain (CPLD/FPGA) for deterministic timing and robust sequencing.

> Simulation note: the LTspice runs used for the README are configured on a faster setting to complete a 7 ms simulation in reasonable time; this can smooth very short-lived ringing transients and make traces appear cleaner. The V(out) soft‑start traces shown are representative and stable in the behavioural model — Vout plots appear very clean in these runs, which is explicitly noted below.

---

## Why Build This Discretely?

Integrated PMIC controllers hide everything—oscillators, compensators, current sensing, and fault logic are opaque black boxes. This project reverses that:

✓ **Understand every block** — oscillator, PWM comparator, error amplifier, gate drive, and protection circuitry  
✓ **Design for your specs** — Type‑III compensator tuned across three load extremes (µA, 100 mA, 5 A)  
✓ **Verify in simulation** — full LTspice behavioural model from oscillator through gate drive  
✓ **Component selection pipeline** — automated MOSFET ranking against actual drive conditions (V_IN, V_OUT, I_out, switching frequency)  
✓ **Production-ready protection plan** — all protection blocks (SCP/OCP, OVP, UVLO, over‑temp) implemented or planned with a safe digital fallback

---

## System Architecture (revised)

The complete control loop is split into functional blocks. Key flow notes are called out below the diagram:

INPUT → [Reverse Polarity] → [Power Stage: LS/HS MOSFETs + Inductor + Caps]
                                   ↓ (V_out, I_sense)
        [UVLO/OVP] ←– [Feedback Network] ←– [Soft Start (RC → reference)]
             ↓
   [Oscillator] (450 kHz)
        ↓
   [PWM Generator] (pristine PWM)
        ↓
   [CPLD/FPGA digital brain] — performs protection/state-machine actions (SCP/OCP sequencing, hiccup sequencing, forced LS cycles, etc.)
        ↓
   [Gate Driver (LM5106)] → [Dead‑time Logic] → power stage
        ↑
   [Type‑III Compensator / Reference Comparator] ← [Feedback path]
        ↑
   [Valley Current Detector] ──┐
                              └─ directly modifies PWM (cycle‑by‑cycle valley limit)

Notes:
- The valley current detector influences the PWM directly (cycle‑by‑cycle valley limiting), while the pristine PWM is first provided to the digital brain so the CPLD/FPGA can inject higher‑level protection actions (for example: forcing the low‑side MOSFET on for 3–4 cycles on SCP).  
- The soft‑start RC ramps the comparator/reference (attacks the 2/5 V threshold in the Type‑III reference comparator) to limit inrush during startup.  
- Hiccup behavior and other higher‑level sequencing are handled exclusively in the digital brain to avoid race conditions in analog behavioural logic.

### Functional Blocks

- **Oscillator** — 450 kHz timing reference (sawtooth/ramp generator)
- **PWM Generator** — produces the pristine PWM reference; the valley detector and the digital brain both may modify it (valley detector = direct cycle‑by‑cycle action; digital brain = sequenced/state changes)
- **Type‑III Compensator** — analog feedback controller (3‑pole/2‑zero topology)
- **Gate Driver Stage** — LM5106 high/low‑side driver with dead‑time insertion and FCCM mode
- **Soft Start** — controlled ramp of reference to limit inrush; implemented as an RC that modulates the comparator reference (2/5 V node)
- **SCP/OCP** — valley current limiting via INA181 + low‑side sense resistor; high‑level SCP handling performed by CPLD/FPGA
- **Hiccup Mode** — implemented and sequenced in the digital brain only (behavioural file's transient hiccup logic will be migrated to digital)
- **OVP** — output overvoltage latch with PMOS series disconnect
- **UVLO** — input undervoltage lockout with hysteresis
- **Over‑Temperature Protection** — NTC‑based thermal cutoff

Additional schematics break out the reverse‑polarity protection front end and debug GPIO/LED indicators.

---

## Control Loop Design & Verification

### Type‑III Compensator Bode Analysis

The compensator was tuned in MATLAB (`simulations/MATLAB_code/Compensator_tuner_results_and_interpretations.m`) by extracting the power‑stage plant transfer function and designing a Type‑III compensator across three load extremes (µA, 100 mA, 5 A). The simulations verify gain and phase margins for all operating points. Bode overlays and loop gain/phase plots are included in `simulations/pictures/`.

---

## Protection Architecture (tiered, updated)

A multi‑level fault response strategy ensures robustness across short‑circuit, overcurrent, and thermal events:

| Tier | Mechanism | Response |
|---|---|---|
| **Tier 1** | Max on‑time clamp | Hard upper bound on high‑side conduction time (~2 µs) |
| **Tier 2** | Valley current limiting | Cycle‑by‑cycle current limit via low‑side sense + INA181; valley detector directly modulates PWM |
| **Tier 3** | Hiccup mode (digital) | CPLD/FPGA sequences full shutdown and timed retry under sustained overcurrent |
| **Tier 4** | Static protection | Input UVLO/OVP, latching output OVP, NTC over‑temperature cutoff, reverse‑polarity protection |

Design note: All higher‑level digital logic used in the behavioural model (D‑FFs, AND/OR gates implementing SCP/OCP sequencing) will be migrated into the CPLD/FPGA. Moving timing/state machines into the digital domain prevents analog race‑throughs, contention and the risk of thermal drift changing tuned analog gate timings.

---

## LTspice Behavioral Model

The full system is simulated in LTspice (`simulations/behavioural_model_complete.asc`) using switch‑based MOSFET models. Individual subsystems are also isolated for targeted verification:

- **`behavioural_model_complete.asc`** — oscillator + PWM + compensator + gate drive + protection logic (integrated behavioural model)
- **`behavioural_model_bare.asc`** — minimal control loop for fast simulation
- **`compensator_and_plant.asc`** — open‑loop plant + compensator (tuning reference)
- **`oscillator.asc`** — standalone 450 kHz timing reference
- **`OVP_test.asc`** — output voltage protection latch + PMOS disconnect
- **`UVLO_protection.asc`** — undervoltage lockout hysteresis behavior
- **`digital_architecture.asc`** — expanded schematic with reverse‑polarity front end and GPIO debug signals (transitional — most digital sequencing will be replaced by CPLD/FPGA RTL)

---

## Automated MOSFET Selection Pipeline

Rather than hand‑picking MOSFETs from datasheets, a small Python pipeline narrows a large parts catalog to candidates fitting the LM5106 drive envelope:

### Pipeline Stages

1. **`digikey_mosScraper.py` / `mouser_mosScrapper.py`**  
   Pull candidate MOSFET part numbers and datasheet links from Digi‑Key and Mouser APIs → `excel_sheets/mosfet_urls.xlsx`

2. **`gemini_mosfet_data_extractor.py`**  
   Uses Gemini API (with Pydantic‑validated structured output + API‑key rotation) to extract:
   - R_ds(on) @ V_GS, I_D conditions
   - Gate charge (Qg, Qsw)
   - Switching losses
   - Package info

3. **`excel_cleanup.py`** — normalizes and validates extracted numeric fields

4. **`JK_optimiser_HS.py` / `JK_optimiser_LS.py`** — scores and ranks candidates for high‑side and low‑side positions against actual drive conditions:
   - V_IN = 22 V, V_OUT = 5 V, I_out = 5 A @ 450 kHz
   - Metrics: switching losses, conduction losses, thermal, gate drive margin

5. **`check_models.py`** — verifies which Gemini models are available/callable

### Output

- **`mosfet_urls.xlsx`** — raw scraped part numbers and datasheet links  
- **`cleaned_mosfets.xlsx`** — extracted and validated parameters  
- **`High_side_frequency_optimization_matrix_*.xlsx`** — ranked HS candidates  
- **`low_side_frequency_matrix_*.xlsx`** — ranked LS candidates

Emphasis: MOSFET selection is guaranteed by the JK optimisation pipeline which ranks candidates against realistic drive conditions and datasheet‑extracted parameters — therefore individual MOSFET loss breakdown plots are not included in the README; the optimiser and its ranking matrices provide the selection assurances.

---

## Component selection — capacitors (updated)

MLCCs were considered and accurately modelled in the plant using the manufacturer's DC‑bias and temperature derating graphs rather than a single nominal value or a generic photo. The plant model incorporates the measured/declared capacitance vs. DC bias and temperature so the compensator tuning and transient simulation reflect realistic effective capacitance and ESR.

Representative manufacturer graphs used in modelling (in repo):
- MLCC DC‑bias / capacitance vs Vdc: simulations/pictures/KGM32LR51E476MU_47uf_output_cap_47uf_ESR.png  
- MLCC temperature / derating curve: simulations/pictures/KGM32LR51E476MU_47uf_output_cap_DCDerating.png

Kyocera's capacitor DC‑bias / derating tool and manufacturer datasheets were used as sources for some MLCC models.

---

## Selected simulations & signals

PCB design and digital logic design are next (not yet implemented). The behavioural LTspice model is used for analog verification; higher‑level sequencing (hiccup/state machines, forced‑LS cycles, PGOOD validation) will be implemented in the CPLD/FPGA and replaced in behavioural files once RTL is available.

Figure numbering corresponds to images in `simulations/pictures/` that are included in this repository.

Figure 1 — Heavy‑load soft‑start / Vout
- File: simulations/pictures/figure1_heavy_load_vout.png
- Caption: V(out) during soft‑start into heavy load. Shows controlled RC soft‑start ramp to 5 V (rise ≈ 2 ms in this simulation), limiting inrush while digital validation/PGOOD logic readies. The Vout trace in this run is very clean (see simulation note above).

Figure 2 — Switch‑node waveform
- File: simulations/pictures/figure2_switch_node.png
- Caption: Switch node (HS/LS switching) at 450 kHz. Shows HS plateau near VIN, LS interval near 0 V, and negative undershoot during LS turn‑on; used to tune dead‑time, snubbers and PCB power‑loop layout.

Figure 3 — PGOOD (Vout vs PGOOD)
- File: simulations/pictures/figure3_pgood_vs_vout.png
- Caption: V(out) (blue) and PGOOD (red). PGOOD asserts after the output crosses the PGOOD threshold and a validation window; PGOOD will be implemented and debounced in CPLD/FPGA logic.

Figure 4 — SCP/OCP behavioural trigger (schematic)
- File: simulations/pictures/figure4_scp_ocp_trigger.png
- Caption: INA181 → TLV3501 comparator → D‑FF + gating logic from the behavioural model. Planned change: keep comparator for cycle‑by‑cycle sensing and migrate D‑FFs, counters and sequencing into CPLD/FPGA RTL to avoid analog race conditions and thermal timing drift.

Figure 6 — Soft‑start circuit (schematic)
- File: simulations/pictures/figure6_soft_start.png
- Caption: Soft‑start RC/diode + fault NMOS arrangement used in the behavioural model; soft‑start ramps the Type‑III reference (2/5 V node). In the final design the soft‑start reference will be controllable by the digital brain for programmable ramps.

Figure 7 — Type‑III compensator (schematic)
- File: simulations/pictures/figure7_compensator.png
- Caption: Type‑III compensator topology used for loop shaping (Cf, Rc, Cc network shown). Bode overlays (all three load cases) are available in simulations/pictures to show gain & phase margins.

Figure 8 — Oscillator (schematic)
- File: simulations/pictures/figure8_oscillator.png
- Caption: 450 kHz sawtooth/ramp generator used as the timing reference for PWM. The oscillator output (V_trig) is the timing input to the PWM generator in the behavioural model.

Figure 9 — Plant (schematic)
- File: simulations/pictures/figure9_plant.png
- Caption: Power stage and output filter (MOSFETs, L, C) used for plant extraction and compensator tuning.

Figure 10 — OVP circuit (schematic)
- File: simulations/pictures/figure10_ovp.png
- Caption: Output overvoltage protection and latching PMOS disconnect. The current schematic includes a manual reset path consideration; latch/reset behaviour will be validated in hardware.

(Per project direction, the RC‑based hiccup behavioural schematic is excluded from README figures because hiccuping will be migrated to the digital brain.)

---

## PCB Design

`Sync_buck_convertor/Sync_buck_convertor.PrjPcb` is the Altium Designer project file for the physical board.

**Note:** Schematic and PCB layout files are excluded from version control (see `.gitignore`) to preserve competitive details. Layout is in progress and will be documented separately.

---

## Repository Structure

```
Synchronous_buck_PMIC/
├── Mosfet_extraction_pipeline/
│   └── ...
├── Sync_buck_convertor/
│   └── Sync_buck_convertor.PrjPcb
├── simulations/
│   ├── behavioural_model_complete.asc
│   ├── ...
│   └── pictures/
│       ├── Heavy_loads_5A/
│       ├── Light_loads_100mA/
│       ├── Very_light_load_uA/
│       ├── MLCC_cap_selection.png
│       ├── MLCC_temp_derating_curve.png
│       └── [component datasheets & derating curves]
├── LICENSE
├── LICENSE-CERN-OHL-P-2.0.txt
└── CONTRIBUTING.md
```

---

## Design Tools & Methodology

- **LTspice** — behavioral simulation, compensator tuning verification, protection circuit validation  
- **MATLAB** — plant transfer function extraction, Type‑III compensator design, Bode/transient analysis  
- **Altium Designer** — schematic capture, PCB layout, design rule checking  
- **Python** — MOSFET data extraction pipeline, Excel automation, component optimization scripts

---

## Key Design Insights (condensed)

- Compensator tuning uses three load cases (µA, 100 mA, 5 A) and ensures adequate gain/phase margins across the range.  
- Valley current sensing is used for cycle‑by‑cycle current limiting and directly modifies PWM to clamp current.  
- Digital sequencing (CPLD/FPGA) is used for higher‑level protection (SCP/OCP sequencing, hiccuping) to avoid race conditions and analog timing drift.  
- MOSFETs were selected using the JK optimisation pipeline which ranks candidates using datasheet parameters and drive‑condition scoring; this provides the selection guarantees for HS/LS devices.  
- LM5106 was selected for robust gate drive, programmable dead‑time, and compatibility with the input range.

---

## Contribution Policy

This repository is a **static portfolio archive**. Issues reporting critical errors are welcome; pull requests are **not being accepted**. See `CONTRIBUTING.md` for details.

---

## License

- **Code** (Python, MATLAB, test scripts): **MIT License** — see `LICENSE`  
- **Hardware** (schematics, PCB layout): **CERN‑OHL‑P v2** — see `LICENSE-CERN-OHL-P-2.0.txt`

---

## Future Work / Open Questions (explicit)

- Provide ZCD (zero‑current detection) and FCCM/DEM switching functionality (mode switching between forced continuous/conduction mode and discontinuous/edge mode). This is planned as a next milestone and will be implemented in the digital domain (CPLD/FPGA) so the switching logic can be deterministic across temperature and process variation.  
- Move all timing/state protection logic from the analog behavioural model into CPLD/FPGA RTL (D‑FFs, AND/OR gates, counters) to prevent race‑through, contention, and thermal drift affecting tuned timings.  
- PCB layout parasitic optimization (gate drive loop inductance, power plane integrity).  
- Thermal modeling and experimental validation (MOSFET junction temperature prediction under various load profiles) — not yet available and planned as the next step after preliminary PCB layout is matured.  
- Experimental validation — hardware bring‑up and measured efficiency curves.

For questions or to discuss the design, feel free to open an issue. Enjoy the project!
