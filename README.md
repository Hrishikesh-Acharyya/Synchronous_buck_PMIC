# Synchronous Buck PMIC — 5 V / 5 A

**A complete discrete-component buck converter design with integrated analog control and protection — no single-chip PWM controller.**

This project demonstrates the full power electronics design chain: from power-stage topology, through analog compensator design and LTspice verification, to automated component selection and PCB layout. Every subsystem (oscillator, PWM generator, gate driver, protection logic) was designed from first principles.

---

## Quick Specs

| Specification | Value |
|---|---|
| **Output** | 5 V @ 5 A (25 W max) |
| **Input range** | 10.8 V – 22 V |
| **Switching frequency** | 450 kHz |
| **Efficiency** | ~92% at 5 A (22 V input) |
| **Gate driver** | LM5106 (discrete control logic) |
| **Control topology** | Voltage-mode, analog Type III compensator |
| **Protection tiers** | 4 (soft-start, cycle-by-cycle current limiting, hiccup mode, UVLO/OVP/OTP) |

---

## Why Build This Discretely?

Integrated PMIC controllers hide everything—oscillators, compensators, current sensing, and fault logic are opaque black boxes. This project reverses that:

✓ **Understand every block** — oscillator, PWM comparator, error amplifier, gate drive, and protection circuitry  
✓ **Design for your specs** — Type III compensator tuned across three load extremes (µA, 100 mA, 5 A)  
✓ **Verify in simulation** — full LTspice behavioral model from oscillator through gate drive  
✓ **Component selection pipeline** — automated MOSFET ranking against actual drive conditions (V_IN, V_OUT, I_out, switching frequency)  
✓ **Production-ready** — all protection blocks (SCP/OCP, OVP, UVLO, over-temp) implemented  

---

## System Architecture

The complete control loop is split into functional blocks:

```
INPUT → [Reverse Polarity] → [Power Stage: LS/HS MOSFETs + Inductor + Caps]
                                    ↓ (V_out, I_sense)
         [UVLO/OVP] ←– [Feedback Network] ←– [Soft Start]
              ↓
    [Oscillator] (450 kHz)
         ↓
    [PWM Generator] → [Gate Driver (LM5106)] → [Dead-time Logic]
         ↑
  [Type III Compensator] ← [Feedback path]
         ↑
  [Protection: Max on-time, Valley current limit, Hiccup, Thermal]
```

### Functional Blocks

- **Oscillator** — 450 kHz timing reference (sawtooth/ramp generator)
- **PWM Generator** — produces masked PWM signal for gate driver
- **Type III Compensator** — analog feedback controller (3-pole/2-zero topology)
- **Gate Driver Stage** — LM5106 high/low-side driver with dead-time insertion and FCCM mode
- **Soft Start** — controlled ramp-up of V_ref to limit inrush current
- **SCP/OCP** — valley current limiting via INA181 current-sense amplifier + low-side sense resistor
- **Hiccup Mode** — RC-accumulator-based shutdown/retry under sustained overcurrent
- **OVP** — output overvoltage latch with PMOS series disconnect
- **UVLO** — input undervoltage lockout with hysteresis
- **Over-Temperature Protection** — NTC-based thermal cutoff

Additional schematics break out the reverse-polarity protection front end and debug GPIO/LED indicators.

---

## Control Loop Design & Verification

### Type III Compensator Bode Analysis

The compensator was tuned in MATLAB (`simulations/MATLAB_code/Compensator_tuner_results_and_interpretations.m`) by extracting the power-stage plant transfer function and designing a Type III compensator optimized for three load extremes:

**Very Light Load (µA)** | **Light Load (100 mA)** | **Heavy Load (5 A)**
---|---|---
![Power Stage Plant - µA](simulations/pictures/Very_light_load_uA/Figure1_Power_Stage_Plant_uA_very_Light_Load.png) | ![Power Stage Plant - 100mA](simulations/pictures/Light_loads_100mA/Figure1_Power_Stage_Plant_100mA_Light_Load.png) | ![Power Stage Plant - 5A](simulations/pictures/Heavy_loads_5A/Figure1_Power_Stage_Plant_5A_Heavy_Load.png)

#### Compensator Response Across Load Range

**Very Light Load (µA)** | **Light Load (100 mA)** | **Heavy Load (5 A)**
---|---|---
![Compensator - µA](simulations/pictures/Very_light_load_uA/Figure2_Type_III_Compensator_uA_very_Light_Load.png) | ![Compensator - 100mA](simulations/pictures/Light_loads_100mA/Figure2_Type_III_Compensator_100mA_Light_Load.png) | ![Compensator - 5A](simulations/pictures/Heavy_loads_5A/Figure2_Type_III_Compensator_5A_Heavy_Load.png)

#### Loop Gain & Stability Margins

**Very Light Load (µA)** | **Light Load (100 mA)** | **Heavy Load (5 A)**
---|---|---
![Loop Gain - µA](simulations/pictures/Very_light_load_uA/Figure3_Loop_Gain_Margins_uA_very_Light_Load.png) | ![Loop Gain - 100mA](simulations/pictures/Light_loads_100mA/Figure3_Loop_Gain_Margins_100mA_Light_Load.png) | ![Loop Gain - 5A](simulations/pictures/Heavy_loads_5A/Figure3_Loop_Gain_Margins_5A_Heavy_Load.png)

The compensator was verified to maintain adequate gain margin (>6 dB) and phase margin (>50°) across all three load extremes—critical since a Type III tuned for only one load point can lose stability badly at others.

#### System Transient Response

**Very Light Load (µA)** | **Light Load (100 mA)** | **Heavy Load (5 A)**
---|---|---
![Transients - µA](simulations/pictures/Very_light_load_uA/Figure5_System_Transients_uA_very_Light_Load.png) | ![Transients - 100mA](simulations/pictures/Light_loads_100mA/Figure5_System_Transients_100mA_Light_Load.png) | ![Transients - 5A](simulations/pictures/Heavy_loads_5A/Figure5_System_Transients_5A_Heavy_Load.png)

Each plot shows: reference step, control effort, line transient (V_in step), load transient (I_out step), and noise susceptibility across all three load extremes.

---

## Protection Architecture (Tiered)

A multi-level fault response strategy ensures robustness across short-circuit, overcurrent, and thermal events:

| Tier | Mechanism | Response |
|---|---|---|
| **Tier 1** | Max on-time clamp | Hard upper bound on high-side conduction time (~2 µs) |
| **Tier 2** | Valley current limiting | Cycle-by-cycle current limit via low-side sense resistor + D flip-flop |
| **Tier 3** | Hiccup mode | RC-accumulator trips full shutdown/retry cycle under sustained overcurrent |
| **Tier 4** | Static protection | Input UVLO/OVP, latching output OVP, NTC over-temperature cutoff, reverse-polarity protection |

**Key design note:** Valley current sensing uses an INA181 current-sense amplifier and low-side sense resistor. The zero-current detection comparator (TLV3501) required hysteresis feedback to prevent retriggering/chatter around the zero crossing—a significant debugging effort resolved via simulation.

---

## LTspice Behavioral Model

The full system is simulated in LTspice (`simulations/behavioural_model_complete.asc`) using switch-based MOSFET models. Individual subsystems are also isolated for targeted verification:

- **`behavioural_model_complete.asc`** — oscillator + PWM + compensator + gate drive + protection logic (integrated)
- **`behavioural_model_bare.asc`** — minimal control loop for fast simulation
- **`compensator_and_plant.asc`** — open-loop plant + compensator (tuning reference)
- **`oscillator.asc`** — standalone 450 kHz timing reference
- **`OVP_test.asc`** — output voltage protection latch + PMOS disconnect
- **`UVLO_protection.asc`** — undervoltage lockout hysteresis behavior
- **`digital_architecture.asc`** — expanded schematic with reverse-polarity front end and GPIO debug signals

---

## Automated MOSFET Selection Pipeline

Rather than hand-picking MOSFETs from datasheets, a small Python pipeline narrows a large parts catalog to candidates fitting the LM5106 drive envelope:

### Pipeline Stages

1. **`digikey_mosScraper.py` / `mouser_mosScrapper.py`**  
   Pull candidate MOSFET part numbers and datasheet links from Digi-Key and Mouser APIs → `excel_sheets/mosfet_urls.xlsx`

2. **`gemini_mosfet_data_extractor.py`**  
   Uses Gemini API (with Pydantic-validated structured output + API-key rotation) to extract:
   - R_ds(on) @ V_GS, I_D conditions
   - Gate charge (Qg, Qsw)
   - Switching losses
   - Package info

3. **`excel_cleanup.py`**  
   Normalizes and validates extracted numeric fields

4. **`JK_optimiser_HS.py` / `JK_optimiser_LS.py`**  
   Scores and ranks candidates for high-side and low-side positions against actual drive conditions:
   - V_IN = 22 V, V_OUT = 5 V, I_out = 5 A @ 450 kHz
   - Metrics: switching losses, conduction losses, thermal, gate drive margin

5. **`check_models.py`**  
   Utility to verify which Gemini models are available/callable

### Output

- **`mosfet_urls.xlsx`** — raw scraped part numbers and datasheet links
- **`cleaned_mosfets.xlsx`** — extracted and validated parameters
- **`High_side_frequency_optimization_matrix_*.xlsx`** — ranked HS candidates
- **`low_side_frequency_matrix_*.xlsx`** — ranked LS candidates

### Component Selection

Passive components (output capacitors) were similarly datasheet-driven:

![MLCC Capacitor Selection](simulations/pictures/MLCC_cap_selection.png)

**DC-Bias Derating** | **Temperature Derating**
---|---
![DC Bias Derating](simulations/pictures/KGM32LR51E476MU_output_cap_47uf_ESR.png) | ![Temp Derating](simulations/pictures/KGM32LR51E476MU_47uf_output_cap_DCDerating.png)

---

## PCB Design

`Sync_buck_convertor/Sync_buck_convertor.PrjPcb` is the Altium Designer project file for the physical board.

**Note:** Schematic and PCB layout files are excluded from version control (see `.gitignore`) to preserve competitive details. Layout is in progress and will be documented separately.

---

## Repository Structure

```
Synchronous_buck_PMIC/
├── Mosfet_extraction_pipeline/          # Automated component sourcing & ranking
│   ├── digikey_mosScraper.py
│   ├── mouser_mosScrapper.py
│   ├── gemini_mosfet_data_extractor.py
│   ├── excel_cleanup.py
│   ├── JK_optimiser_HS.py
│   ├── JK_optimiser_LS.py
│   ├── check_models.py
│   └── excel_sheets/
│       ├── mosfet_urls.xlsx
│       ├── cleaned_mosfets.xlsx
│       ├── High_side_frequency_optimization_matrix_LM5106.xlsx
│       └── low_side_frequency_matrix_LM5106.xlsx
│
├── Sync_buck_convertor/                 # Altium project (layout in progress)
│   └── Sync_buck_convertor.PrjPcb
│
├── simulations/
│   ├── behavioural_model_complete.asc
│   ├── behavioural_model_bare.asc
│   ├── digital_architecture.asc
│   ├── compensator_and_plant.asc
│   ├── oscillator.asc
│   ├── OVP_test.asc
│   ├── UVLO_protection.asc
│   │
│   ├── MATLAB_code/
│   │   └── Compensator_tuner_results_and_interpretations.m
│   │
│   └── pictures/
│       ├── Heavy_loads_5A/              # 5 plots each (plant, comp, loop gain, overlay, transients)
│       ├── Light_loads_100mA/
│       ├── Very_light_load_uA/
│       ├── MLCC_cap_selection.png
│       ├── MLCC_temp_derating_curve.png
│       └── [component datasheets & derating curves]
│
├── LICENSE                              # MIT (code / scripts)
├── LICENSE-CERN-OHL-P-2.0.txt           # CERN-OHL-P (hardware design)
└── CONTRIBUTING.md
```

---

## Design Tools & Methodology

- **LTspice** — behavioral simulation, compensator tuning verification, protection circuit validation
- **MATLAB** — plant transfer function extraction, Type III compensator design, Bode/transient analysis
- **Altium Designer** — schematic capture, PCB layout, design rule checking
- **Python** — MOSFET data extraction pipeline, Excel automation, component optimization scripts

---

## Key Design Insights

### Compensator Tuning Across Load Extremes

A Type III compensator must be optimized not just at nominal load but across the entire operating range. This design includes:

- **µA loading** — very light load; tests regulator quiescent losses and loop stability at high loop gain
- **100 mA loading** — intermediate; tests compromises between light and heavy load response
- **5 A loading** — full rated load; tests phase margin and transient recovery

Each load case is independently tuned to maintain >6 dB gain margin and >50° phase margin. The system overlay plots show all three responses together for visual margin verification.

### Valley Current Sensing

Rather than peak inductor current sensing, valley current sensing (measuring the minimum inductor current each cycle) enables:

- Accurate cycle-by-cycle current limiting even with inductor DCR variation
- Natural integration of overcurrent detection into the PWM feedback path
- Reduced component count vs. separate peak-current comparators

The zero-current detection comparator (TLV3501) required significant hysteresis tuning in simulation to prevent oscillation near the zero-current transition.

### Gate Driver Considerations

The LM5106 was selected for:

- Robust high/low-side bootstrapping
- Programmable dead-time
- Wide V_IN range tolerance (10.8–22 V maps cleanly to LM5106 specs)
- Discrete control flexibility around the driver without additional level shifters

---

## Contribution Policy

This repository is a **static portfolio archive**. Issues reporting critical errors are welcome; pull requests are **not being accepted**. See `CONTRIBUTING.md` for details.

---

## License

- **Code** (Python, MATLAB, test scripts): **MIT License** — see `LICENSE`
- **Hardware** (schematics, PCB layout): **CERN-OHL-P v2** — see `LICENSE-CERN-OHL-P-2.0.txt`

Both are in the repository root.

---

## Next Steps / Open Questions

Design notes and open questions are tracked as annotations directly in the LTspice schematics. Key areas for future work:

- **DEM/ZCD-based mode switching** — planned but not yet active; would enable discontinuous/boundary-conduction mode for light-load efficiency
- **PCB layout parasitic optimization** — gate drive loop inductance, power plane integrity
- **Thermal modeling** — MOSFET junction temperature prediction under various load profiles
- **Experimental validation** — hardware bring-up and measured efficiency curves

---

**For questions or to discuss the design, feel free to open an issue. Enjoy the project!**
