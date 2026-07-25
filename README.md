# Synchronous Buck PMIC — 5 V / 5 A

Designed a synchronous buck PMIC from scratch including a gate driver module, a Type‑III compensator and a PWM generator circuit.

A discrete synchronous buck converter with analog control and tiered protection. The repository includes power‑stage topology, compensator design, LTspice behavioral verification, and an automated component selection pipeline.

---

## Quick Specifications

| Specification | Value |
|---|---|
| Output | 5 V @ 5 A (25 W max) |
| Input range | 10.8 V – 22 V |
| Switching frequency | 450 kHz |
| Efficiency | ~92% at 5 A (22 V input, simulated) |
| Gate driver | LM5106 (gate driver IC) |
| Control topology | Voltage‑mode, analog Type‑III compensator |
| Protection tiers | Soft‑start, cycle‑by‑cycle current limiting, hiccup (digital), UVLO/OVP/OTP |

---

## Current development status

PCB layout and digital control (CPLD/FPGA) are planned and not yet implemented. The LTspice behavioral model is used for analog verification; higher‑level sequencing (hiccup/state machines, forced low‑side cycles, PGOOD validation) will be implemented in the digital domain for deterministic timing and robust sequencing.

Valley current detection, hiccup sequencing and soft‑start control are currently implemented in the analog behavioral LTspice model for verification; these functions will be migrated to the CPLD/FPGA digital controller in a future revision.

Note: the LTspice simulations used to generate the repository plots trade simulation runtime for time resolution. Very short‑duration switching ringing can be reduced by the chosen time‑step settings; steady‑state and soft‑start behaviour remain representative for design decisions.

---

## Design rationale

Discrete control provides visibility and tuning of each control block (oscillator, comparator, compensator, gate drive and protection), enabling design trade‑offs not exposed by integrated PMICs. The analog control loop is verified in simulation and protection sequencing is architected for eventual digital implementation.

---

## System architecture

Functional blocks:

- Reverse‑polarity and input front‑end
- Power stage: high‑side and low‑side MOSFETs, inductor and output capacitors
- Oscillator (450 kHz nominal)
- PWM generator (pristine PWM reference)
- CPLD/FPGA digital controller (sequenced protection and state machines)
- Gate driver (LM5106) with dead‑time logic
- Analog Type‑III compensator and reference comparator
- Valley current detector (cycle‑by‑cycle current limiting; currently behavioral)
- Static protections: UVLO, OVP, thermal cutoff

Notes:
- The pristine PWM is presented to the digital controller for high‑level sequencing (for example: forced low‑side cycles during severe faults). The valley detector is implemented in the analog behavioral model as a fast, cycle‑by‑cycle clamp; sequencing and stateful behaviour will be migrated to the digital controller.
- Soft‑start is implemented in the behavioral simulations as an analog ramp affecting the comparator reference; this will be controllable by the digital controller in later revisions.
- Hiccup and other sequencing functions are intended to run in the digital controller to avoid timing race conditions and thermal drift in analog logic.

---

## Control loop design and verification

The Type‑III compensator was designed in MATLAB by extracting the power‑stage plant transfer function and tuning across three operating points: µA (very light load), 100 mA (light load) and 5 A (heavy load). Bode plots and loop gain/phase results demonstrating gain and phase margins are provided in the `simulations/pictures/` directory.

---

## Protection strategy

A multi‑tier protection strategy is employed:

| Tier | Mechanism | Function |
|---|---|---|
| Tier 1 | Max on‑time clamp | Prevent excessive high‑side conduction time |
| Tier 2 | Valley current limiting (analog) | Immediate cycle‑by‑cycle current limiting via low‑side sensing and comparator |
| Tier 3 | Hiccup (digital, planned) | Sequenced shutdown and retry under sustained overcurrent (CPLD/FPGA) |
| Tier 4 | Static protections | UVLO, OVP with latching PMOS disconnect, thermal cutoff |

Higher‑level sequencing (D‑flip‑flops, counters and state machines) implemented in behavioral models will be migrated to the digital controller to improve determinism and avoid analog timing contention.

---

## LTspice behavioral model

Simulation files are provided in `simulations/` and demonstrate the integrated system and individual subsystems:

- `behavioural_model_complete.asc` — integrated oscillator, PWM, compensator, gate drive and protection logic
- `behavioural_model_bare.asc` — minimal control loop for rapid simulation
- `compensator_and_plant.asc` — plant extraction and compensator tuning reference
- `oscillator.asc` — standalone oscillator
- `OVP_test.asc`, `UVLO_protection.asc` — protection subcircuits
- `digital_architecture.asc` — transitional behavioral digital logic (to be replaced by CPLD/FPGA RTL)

---

## Component selection and MOSFET pipeline

Automated component selection is performed via a Python pipeline that collects candidate MOSFET data, normalizes parameters and scores candidates.

Key steps:
- Data acquisition from Digi‑Key / Mouser (`digikey_mosScraper.py`, `mouser_mosScrapper.py`)
- Parameter extraction and validation (`gemini_mosfet_data_extractor.py`, `excel_cleanup.py`)
- Candidate scoring and ranking (`JK_optimiser_HS.py`, `JK_optimiser_LS.py`)

The JK optimisers rank MOSFETs against realistic drive conditions (V_IN, V_OUT, I_out, switching frequency) using gate‑charge, conduction characteristics and thermal considerations where available. The optimisation matrices provide the basis for HS/LS device selection; therefore per‑device loss breakdowns are not included in the README.

---

## Capacitor selection and modelling

MLCCs were modelled using manufacturer DC‑bias and temperature derating data to account for effective capacitance and ESR under operating conditions. Representative graphs used for modelling are included in `simulations/pictures/`.

---

## Selected simulation figures

Representative images are available in `simulations/pictures/`:

- Figure 1 — Heavy‑load soft‑start / Vout (simulations/pictures/figure1_heavy_load_vout.png)
- Figure 2 — Switch‑node waveform (simulations/pictures/figure2_switch_node.png)
- Figure 3 — PGOOD vs Vout (simulations/pictures/figure3_pgood_vs_vout.png)
- Figure 4 — SCP/OCP trigger schematic (simulations/pictures/figure4_scp_ocp_trigger.png)
- Figure 6 — Soft‑start schematic (simulations/pictures/figure6_soft_start.png)
- Figure 7 — Type‑III compensator schematic (simulations/pictures/figure7_compensator.png)
- Figure 8 — Oscillator schematic (simulations/pictures/figure8_oscillator.png)
- Figure 9 — Plant schematic (simulations/pictures/figure9_plant.png)
- Figure 10 — OVP circuit schematic (simulations/pictures/figure10_ovp.png)

Note: Figure 5 (RC‑based hiccup schematic) is excluded from README figures because hiccup sequencing will be migrated to the digital controller.

The simulation traces were produced with a timestep setting that balances runtime and resolution; short‑duration switching ringing may be attenuated by this setting, while overall steady‑state and soft‑start behaviour remain representative.

---

## PCB and layout

The Altium project is located at `Sync_buck_convertor/Sync_buck_convertor.PrjPcb`. PCB layout work is in progress; layout files are omitted from version control to protect design details.

---

## Repository structure

```
Synchronous_buck_PMIC/
├── Mosfet_extraction_pipeline/
├── Sync_buck_convertor/
├── simulations/
└── LICENSE, CONTRIBUTING.md
```

---

## Tools and methodology

LTspice, MATLAB, Altium Designer and Python were used for simulation, compensator design, PCB work and data automation respectively.

---

## Future work

- Implement ZCD and FCCM/DEM mode switching in the digital controller
- Migrate protection sequencing and state machines to CPLD/FPGA RTL
- PCB parasitic optimisation (gate‑drive and power loop)
- Thermal modelling and experimental validation following PCB prototyping

---

## Contact

For technical questions or to report issues, please open an issue in this repository.
