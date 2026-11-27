# Mutation record: pmic_top

`rtl-systemverilog/pmic_top.sv`. Written by `tools/mutation/record.py` from `pmic_top.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | - |
| AI-written | 88 | 0 | 0 | 0 | 0 | 0 | 0 | 88 | - |
| all | 88 | 0 | 0 | 0 | 0 | 0 | 0 | 88 | - |

Survivors: 0 - 0 decided equivalent, 0 accepted, 0 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: -.

## Survivors (0)

None.

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-27 22:54 | 3b029b7 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 29, accepted 29, rejected 0; `ai_runs/2026-11-27_write_mutants_36` |
| 2 | 2026-11-27 23:08 | 3b029b7 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 21, accepted 21, rejected 0; `ai_runs/2026-11-27_write_mutants_37` |
| 3 | 2026-11-27 23:36 | 3b029b7 | AI wrote mutants (claude-opus-5-5) | asked 20, proposed 6, accepted 6, rejected 0; `ai_runs/2026-11-27_write_mutants_38` |
| 4 | 2026-11-28 00:06 | 3b029b7 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 20, accepted 20, rejected 0; `ai_runs/2026-11-27_write_mutants_39` |
| 5 | 2026-11-28 00:21 | 3b029b7 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 13, accepted 12, rejected 1; `ai_runs/2026-11-28_write_mutants` |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (88)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | other | Supervisor's latch read-back is wired to the CPLD's own trip drive latch_out instead of the debounced SCR read-back latch_stat_sync_db | not run |  |
| 2 | 1 | other | Supervisor's OTP input takes the synchronised but undebounced OTP flag, bypassing input_debounce | not run |  |
| 3 | 1 | other | fault_LED's UVLO indication is fed from the undebounced synchronised UVLO flag instead of the debounced copy the supervisor acts on | not run |  |
| 4 | 1 | wrong_event | The switch edge detector fires on the falling edge of the debounced switch (release) instead of the rising edge (press) | not run |  |
| 5 | 1 | other | switch_supply follows the raw synchronised output comparator instead of the qualified PGOOD from pgood_gen | not run |  |
| 6 | 1 | other | fault_LED's power-good input is wired to the synchronised comparator instead of the qualified PGOOD | not run |  |
| 7 | 1 | field | fault_cause's SCR read-back input is wired to the CPLD's own trip latch_out, so it can no longer tell an external latch from a strike latch | not run |  |
| 8 | 1 | other | pwm_stats measures the masked PWM_out instead of the synchronised modulator PWM | not run |  |
| 9 | 1 | boundary | The enable switch debouncer gets the fault-flag asymmetric release time (assert/5, 4 ms) instead of the symmetric 20 ms | not run |  |
| 10 | 1 | reset_init | The UVLO debouncer is given the enable's fail-safe-low reset value instead of fault-asserted high, so it disagrees with its high-resetting synchroniser | not run |  |
| 11 | 1 | reset_init | The PWM synchroniser gets the fault inputs' fail-safe-high reset value, as if the PWM were a fault flag | not run |  |
| 12 | 1 | protocol | The SCK filter is instanced with the fault-flag debounce defaults instead of the short symmetric SPI_FILTER_CLKS | not run |  |
| 13 | 1 | protocol | MISO idles high outside the read-data phase (open-drain pull-up convention) instead of held low | not run |  |
| 14 | 1 | wrong_event | Supervisor's enable input takes the switch-press edge pulse en_switch_rise instead of the debounced switch level | not run |  |
| 15 | 1 | sequencing | Switch-press edge detector compares the delayed debounced copy with the synchronised but undebounced switch | not run |  |
| 16 | 1 | missing_case | CP_trig goes through the fault-flag input_debounce like OTP and UVLO, though the header says fault_arbiter's rolling window is its only filter | not run |  |
| 17 | 1 | sequencing | PGOOD_comp is debounced before pgood_gen, so the deassert the header requires to be immediate is delayed by the debounce release time | not run |  |
| 18 | 1 | missing_case | pgood_gen is qualified on the gate-driver enable En instead of run_active, so soft-start counts as running | not run |  |
| 19 | 1 | reset_init | strike_counter's clean-run streak is gated on En instead of run_active, so it is not broken by soft-start time | not run |  |
| 20 | 1 | field | Hiccup back-off is scaled by the configured strike limit max_strikes instead of the current strike_level | not run |  |
| 21 | 1 | field | reg_file's status PGOOD bit reports the synchronised output comparator instead of the qualified PGOOD | not run |  |
| 22 | 1 | sequencing | reg_file's over-temperature status bit takes the undebounced OTP flag, unlike the debounced one the supervisor acts on | not run |  |
| 23 | 1 | wrong_event | reg_file's latch status bit reports the CPLD's own trip drive latch_out instead of the SCR latch read-back | not run |  |
| 24 | 1 | wrong_event | fault_cause's capture gate takes the gate-driver enable En as 'running' instead of the supervisor's run_active, so a hard fault in S_RUN is never logged | not run |  |
| 25 | 1 | wrong_event | fault_arbiter's run window is qualified on the gate-driver enable En instead of run_active, so soft-start samples go into the RUN window | not run |  |
| 26 | 1 | other | OTP debouncer copied from the enable-switch instance above it: symmetric 20 ms qualification instead of the fault-flag default of 1 ms assert and 200 us release | not run |  |
| 27 | 1 | field | The FAULT_FLAGS register's current-protection bit reports the RUN overcurrent window trip instead of the live synchronised CP comparator | not run |  |
| 28 | 1 | wrong_event | The switch-press edge detector's delayed copy is taken from the undebounced synchronised switch instead of the debounced one it is compared with | not run |  |
| 29 | 1 | wrong_event | strike_counter's clean-run streak is gated on the qualified PGOOD instead of run_active, so 'clean running' is taken to mean 'rail in regulation' | not run |  |
| 30 | 2 | missing_case | Supervisor's latch_assert input is wired to the debounced SCR read-back instead of strike_counter's own trip latch_out, so the CPLD's strike latch is no longer a hard fault to the FSM | not run |  |
| 31 | 2 | sequencing | switch_supply is driven from the registered pgood_LED indicator copy instead of PGOOD itself, adding a clock to the changeover hand-back | not run |  |
| 32 | 2 | sequencing | pgood_gen is qualified on soft_start's SS_done ('ramp finished') instead of the supervisor's run_active | not run |  |
| 33 | 2 | boundary | UVLO debouncer's asymmetry is reversed (fast 200 us assert, slow 1 ms release), the usual 'trip fast, clear slow' rule misapplied where the header wants assert to be the longer qualification | not run |  |
| 34 | 2 | boundary | The latch read-back debouncer is given the short symmetric SPI glitch-filter length (8 clocks) instead of the fault-flag 1 ms / 200 us qualification | not run |  |
| 35 | 2 | missing_case | fault_arbiter's RUN window is enabled by the qualified PGOOD instead of run_active, so overcurrent in S_RUN is only counted while the rail is in regulation | not run |  |
| 36 | 2 | field | reg_file's enable-switch status bit is fed from the gate-driver enable En instead of the debounced switch level | not run |  |
| 37 | 2 | sequencing | soft_start counts its ramp steps on falling edges of the masked PWM_out instead of the synchronised modulator PWM, so each step lands when pwm_mask truncates the pulse rather than after the pulse ends | not run |  |
| 38 | 2 | other | fault_cause's latch_assert input is fed from the debounced SCR read-back instead of the CPLD's own trip latch_out, so the OVP inference (latch set with latch_assert clear) can never be true | not run |  |
| 39 | 2 | wrong_event | strike_counter counts a strike on every entry into soft start (each retry, and the first power-up) instead of on each entry into S_HICCUP | not run |  |
| 40 | 2 | wrong_event | fault_LED's soft-start input is wired to soft_start's SS_done ('ramp finished') instead of the supervisor's ss_active ('in S_SS') | not run |  |
| 41 | 2 | missing_case | fault_cause's episode scope is wired to hiccup_active instead of ss_active, so it counts S_HICCUP as running and leaves S_SS out | not run |  |
| 42 | 2 | wrong_event | The switch-press detector fires on any change of the debounced switch (press and release) instead of on the press only | not run |  |
| 43 | 2 | sequencing | The housekeeping changeover drive is gated by the gate-driver enable as well as PGOOD, so it no longer carries the same value as PGOOD | not run |  |
| 44 | 2 | missing_case | soft_start's ramp branch is enabled by the gate-driver enable En instead of ss_active, so the ramp and clamp logic also runs through S_RUN | not run |  |
| 45 | 2 | missing_case | fault_arbiter's soft-start gate is wired to the gate-driver enable En, so window_trip_SS is not limited to S_SS and can assert in S_RUN from the frozen soft-start count | not run |  |
| 46 | 2 | missing_case | Supervisor's soft-start overcurrent input is wired to the RUN window trip, so the S_SS -> S_HICCUP exit is driven by a trip that fault_arbiter only raises in S_RUN | not run |  |
| 47 | 2 | missing_case | fault_cause's soft-start overcurrent cause is fed from the RUN window trip, so an overcurrent hiccup out of S_SS is not logged | not run |  |
| 48 | 2 | wrong_event | soft_start holds its ramped ceiling while PGOOD is asserted instead of while the supervisor is in S_RUN, so 'running' is taken to mean 'rail qualified good' | not run |  |
| 49 | 2 | field | fault_cause logs the undebounced synchronised UVLO flag instead of the debounced copy the supervisor acts on | not run |  |
| 50 | 2 | wrong_event | strike_counter counts a strike on every gate-driver shutdown (En falling, or low at reset) instead of on each entry into S_HICCUP | not run |  |
| 51 | 3 | wrong_event | fault_cause logs the overcurrent cause from the live synchronised CP comparator instead of fault_arbiter's RUN window trip, so a single valley-current excursion counts as an overcurrent fault | not run |  |
| 52 | 3 | wrong_event | strike_counter breaks its clean-run streak on any CP comparator assertion instead of on the window trip, so 'fault-free' is taken to mean no overcurrent cycle at all | not run |  |
| 53 | 3 | field | fault_LED's strikes-outstanding input is wired to the configured strike limit max_strikes instead of the accumulated strike_level | not run |  |
| 54 | 3 | wrong_event | fault_LED's running input takes the qualified PGOOD instead of run_active, so the green LED treats 'rail in regulation' as 'running' | not run |  |
| 55 | 3 | wrong_event | fault_LED's soft-start input is wired to hiccup_active, so the green 'running' LED covers the hiccup cool-down instead of soft start | not run |  |
| 56 | 3 | reset_init | soft_start's hold branch is keyed on its own SS_done ('ramp finished') instead of S_RUN, so once a ramp completes it is never reset to the floor | not run |  |
| 57 | 4 | other | Supervisor's enable input takes the synchronised but undebounced switch, bypassing the 20 ms symmetric switch debouncer | not run |  |
| 58 | 4 | other | Supervisor's UVLO input takes the synchronised but undebounced UVLO flag, so input-rail sags shorter than the 1 ms assert qualification shut the converter down | not run |  |
| 59 | 4 | other | Supervisor's SCR latch read-back takes the synchronised but undebounced latch_stat, unlike the debounced copy the header routes to it | not run |  |
| 60 | 4 | sequencing | fault_arbiter's current flag is wired to the raw CP_trig pin instead of its synchronised copy, while its cycle boundary still comes from the synchronised PWM | not run |  |
| 61 | 4 | sequencing | pwm_mask is fed the raw Osc_in pin instead of the synchronised PWM that every other block uses for the cycle | not run |  |
| 62 | 4 | field | reg_file's strike-level status is fed the configured strike limit max_strikes instead of the accumulated strike_level | not run |  |
| 63 | 4 | other | reg_file's UVLO status bit reports the undebounced synchronised UVLO flag instead of the debounced copy the supervisor acts on | not run |  |
| 64 | 4 | other | reg_file's enable-switch status bit is fed the undebounced synchronised switch instead of the debounced level that gates the supervisor | not run |  |
| 65 | 4 | other | fault_cause logs over-temperature from the undebounced synchronised OTP flag instead of the debounced copy the supervisor acts on | not run |  |
| 66 | 4 | other | fault_LED's over-temperature indication is fed the undebounced synchronised OTP flag instead of the debounced one | not run |  |
| 67 | 4 | missing_case | fault_LED's latch indication takes the CPLD's own trip latch_out instead of the SCR read-back, so an external (OVP) latch trip is not shown | not run |  |
| 68 | 4 | missing_case | fault_LED's latch_assert input is fed the debounced SCR read-back instead of strike_counter's latch_out, so the CPLD's own strike latch is not shown until the SCR read-back follows | not run |  |
| 69 | 4 | protocol | The CS_n glitch filter is instanced with the fault-flag debounce defaults (1 ms high, 200 us low) instead of the short symmetric SPI_FILTER_CLKS | not run |  |
| 70 | 4 | missing_case | Supervisor's S_RUN overcurrent exit is wired to the soft-start window trip window_trip_SS, so a RUN window trip never sends the FSM from S_RUN to S_HICCUP | not run |  |
| 71 | 4 | other | Supervisor leaves soft start only when the ramp is done and the output comparator also reports the rail in window, as if 'soft start finished' meant 'output is up' | not run |  |
| 72 | 4 | wrong_event | fault_cause's capture gate takes the qualified PGOOD as 'running' instead of run_active, so a fault in S_RUN before PGOOD has qualified, or during a rail dip, is not logged | not run |  |
| 73 | 4 | field | reg_file's live TIME registers are fed fault_cause's episode-start snapshot fault_time instead of the free-running timestamp_ms | not run |  |
| 74 | 4 | missing_case | fault_cause infers OVP from the synchronised but undebounced SCR read-back instead of the debounced copy the supervisor and LEDs act on | not run |  |
| 75 | 4 | reset_init | OTP debouncer is given the enable's fail-safe-low reset value, so over-temperature reads clear out of reset while its synchroniser resets high | not run |  |
| 76 | 4 | boundary | The enable-switch debounce time is converted with ms_to_sw_cycles instead of ms_to_clks, so the debouncer, which counts clk ticks, gets 9000 clocks (180 us) instead of 20 ms | not run |  |
| 77 | 5 | missing_case | reg_file's SCR latch status bit takes the synchronised but undebounced latch_stat instead of the debounced copy the supervisor acts on | not run |  |
| 78 | 5 | wrong_event | reg_file's enable-switch status bit is fed the switch-press edge pulse en_switch_rise instead of the debounced switch level | not run |  |
| 79 | 5 | missing_case | fault_LED's latch indication is fed the synchronised but undebounced SCR read-back instead of the debounced copy | not run |  |
| 80 | 5 | reset_init | The latch read-back debouncer is given the enable's fail-safe-low reset value, so the SCR latch reads clear out of reset although its synchroniser resets high | not run |  |
| 81 | 5 | boundary | The OTP debouncer's asymmetry is reversed: 200 us to assert and 1 ms to release, the 'trip fast, clear slow' habit applied where the design wants assert to be the longer qualification | not run |  |
| 82 | 5 | protocol | The MOSI glitch filter is instanced with the fault-flag debounce times (1 ms high, 200 us low) instead of the short symmetric SPI_FILTER_CLKS, so it no longer matches the SCK filter | not run |  |
| 83 | 5 | other | The UVLO debouncer is copied from the enable-switch instance above it, so it gets the symmetric 20 ms switch qualification instead of the fault-flag default of 1 ms assert and 200 us release | not run |  |
| 84 | 5 | other | The SCR latch read-back debouncer has its asymmetry reversed: it asserts after 200 us and releases after 1 ms, the 'trip fast, clear slow' habit applied where the fault flags want assert to be the longer qualification | not run |  |
| 85 | 5 | protocol | MISO is enabled whenever the slave is selected (CS_n low), the usual 4-wire convention, instead of only during the read-data phase (S_READ) | not run |  |
| 86 | 5 | wrong_event | strike_counter counts a strike when the hiccup cool-down finishes (hiccup_done) instead of when S_HICCUP is entered | not run |  |
| 87 | 5 | other | The SCR latch read-back debouncer is copied from the enable-switch instance, so it gets the symmetric 20 ms switch qualification instead of the fault-flag default of 1 ms assert and 200 us release | not run |  |
| 88 | 5 | other | The OTP debouncer is copied from the SPI glitch filters, so over-temperature is qualified in 8 clocks (160 ns) both ways instead of the fault-flag 1 ms assert and 200 us release | not run |  |

Rejected by the gate in step 5 (1):

- pgood_gen takes the raw asynchronous PGOOD_comp pin instead of its synchronised copy, breaking the rule that no submodule sees a raw pin - **make lint already catches it: make lint: UNUSEDSIGNAL**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `pmic_top.96.AIM.11` | The PWM synchroniser gets the fault inputs' fail-safe-high reset value, as if the PWM were a fault flag | not run |  |
| `pmic_top.132.AIM.76` | The enable-switch debounce time is converted with ms_to_sw_cycles instead of ms_to_clks, so the debouncer, which counts clk ticks, gets 9000 clocks (180 us) instead of 20 ms | not run |  |
| `pmic_top.133.AIM.9` | The enable switch debouncer gets the fault-flag asymmetric release time (assert/5, 4 ms) instead of the symmetric 20 ms | not run |  |
| `pmic_top.138.AIM.26` | OTP debouncer copied from the enable-switch instance above it: symmetric 20 ms qualification instead of the fault-flag default of 1 ms assert and 200 us release | not run |  |
| `pmic_top.138.AIM.75` | OTP debouncer is given the enable's fail-safe-low reset value, so over-temperature reads clear out of reset while its synchroniser resets high | not run |  |
| `pmic_top.138.AIM.81` | The OTP debouncer's asymmetry is reversed: 200 us to assert and 1 ms to release, the 'trip fast, clear slow' habit applied where the design wants assert to be the longer qualification | not run |  |
| `pmic_top.138.AIM.88` | The OTP debouncer is copied from the SPI glitch filters, so over-temperature is qualified in 8 clocks (160 ns) both ways instead of the fault-flag 1 ms assert and 200 us release | not run |  |
| `pmic_top.139.AIM.10` | The UVLO debouncer is given the enable's fail-safe-low reset value instead of fault-asserted high, so it disagrees with its high-resetting synchroniser | not run |  |
| `pmic_top.139.AIM.33` | UVLO debouncer's asymmetry is reversed (fast 200 us assert, slow 1 ms release), the usual 'trip fast, clear slow' rule misapplied where the header wants assert to be the longer qualification | not run |  |
| `pmic_top.139.AIM.83` | The UVLO debouncer is copied from the enable-switch instance above it, so it gets the symmetric 20 ms switch qualification instead of the fault-flag default of 1 ms assert and 200 us release | not run |  |
| `pmic_top.140.AIM.34` | The latch read-back debouncer is given the short symmetric SPI glitch-filter length (8 clocks) instead of the fault-flag 1 ms / 200 us qualification | not run |  |
| `pmic_top.140.AIM.80` | The latch read-back debouncer is given the enable's fail-safe-low reset value, so the SCR latch reads clear out of reset although its synchroniser resets high | not run |  |
| `pmic_top.140.AIM.84` | The SCR latch read-back debouncer has its asymmetry reversed: it asserts after 200 us and releases after 1 ms, the 'trip fast, clear slow' habit applied where the fault flags want assert to be the longer qualification | not run |  |
| `pmic_top.140.AIM.87` | The SCR latch read-back debouncer is copied from the enable-switch instance, so it gets the symmetric 20 ms switch qualification instead of the fault-flag default of 1 ms assert and 200 us release | not run |  |
| `pmic_top.159.AIM.12` | The SCK filter is instanced with the fault-flag debounce defaults instead of the short symmetric SPI_FILTER_CLKS | not run |  |
| `pmic_top.162.AIM.69` | The CS_n glitch filter is instanced with the fault-flag debounce defaults (1 ms high, 200 us low) instead of the short symmetric SPI_FILTER_CLKS | not run |  |
| `pmic_top.165.AIM.82` | The MOSI glitch filter is instanced with the fault-flag debounce times (1 ms high, 200 us low) instead of the short symmetric SPI_FILTER_CLKS, so it no longer matches the SCK filter | not run |  |
| `pmic_top.242.AIM.28` | The switch-press edge detector's delayed copy is taken from the undebounced synchronised switch instead of the debounced one it is compared with | not run |  |
| `pmic_top.254.AIM.15` | Switch-press edge detector compares the delayed debounced copy with the synchronised but undebounced switch | not run |  |
| `pmic_top.254.AIM.4` | The switch edge detector fires on the falling edge of the debounced switch (release) instead of the rising edge (press) | not run |  |
| `pmic_top.254.AIM.42` | The switch-press detector fires on any change of the debounced switch (press and release) instead of on the press only | not run |  |
| `pmic_top.264.AIM.71` | Supervisor leaves soft start only when the ramp is done and the output comparator also reports the rail in window, as if 'soft start finished' meant 'output is up' | not run |  |
| `pmic_top.266.AIM.14` | Supervisor's enable input takes the switch-press edge pulse en_switch_rise instead of the debounced switch level | not run |  |
| `pmic_top.266.AIM.57` | Supervisor's enable input takes the synchronised but undebounced switch, bypassing the 20 ms symmetric switch debouncer | not run |  |
| `pmic_top.268.AIM.1` | Supervisor's latch read-back is wired to the CPLD's own trip drive latch_out instead of the debounced SCR read-back latch_stat_sync_db | not run |  |
| `pmic_top.268.AIM.59` | Supervisor's SCR latch read-back takes the synchronised but undebounced latch_stat, unlike the debounced copy the header routes to it | not run |  |
| `pmic_top.269.AIM.2` | Supervisor's OTP input takes the synchronised but undebounced OTP flag, bypassing input_debounce | not run |  |
| `pmic_top.270.AIM.46` | Supervisor's soft-start overcurrent input is wired to the RUN window trip, so the S_SS -> S_HICCUP exit is driven by a trip that fault_arbiter only raises in S_RUN | not run |  |
| `pmic_top.271.AIM.70` | Supervisor's S_RUN overcurrent exit is wired to the soft-start window trip window_trip_SS, so a RUN window trip never sends the FSM from S_RUN to S_HICCUP | not run |  |
| `pmic_top.272.AIM.30` | Supervisor's latch_assert input is wired to the debounced SCR read-back instead of strike_counter's own trip latch_out, so the CPLD's strike latch is no longer a hard fault to the FSM | not run |  |
| `pmic_top.273.AIM.58` | Supervisor's UVLO input takes the synchronised but undebounced UVLO flag, so input-rail sags shorter than the 1 ms assert qualification shut the converter down | not run |  |
| `pmic_top.287.AIM.16` | CP_trig goes through the fault-flag input_debounce like OTP and UVLO, though the header says fault_arbiter's rolling window is its only filter | not run |  |
| `pmic_top.294.AIM.60` | fault_arbiter's current flag is wired to the raw CP_trig pin instead of its synchronised copy, while its cycle boundary still comes from the synchronised PWM | not run |  |
| `pmic_top.295.AIM.45` | fault_arbiter's soft-start gate is wired to the gate-driver enable En, so window_trip_SS is not limited to S_SS and can assert in S_RUN from the frozen soft-start count | not run |  |
| `pmic_top.296.AIM.25` | fault_arbiter's run window is qualified on the gate-driver enable En instead of run_active, so soft-start samples go into the RUN window | not run |  |
| `pmic_top.296.AIM.35` | fault_arbiter's RUN window is enabled by the qualified PGOOD instead of run_active, so overcurrent in S_RUN is only counted while the rail is in regulation | not run |  |
| `pmic_top.304.AIM.20` | Hiccup back-off is scaled by the configured strike limit max_strikes instead of the current strike_level | not run |  |
| `pmic_top.313.AIM.39` | strike_counter counts a strike on every entry into soft start (each retry, and the first power-up) instead of on each entry into S_HICCUP | not run |  |
| `pmic_top.313.AIM.50` | strike_counter counts a strike on every gate-driver shutdown (En falling, or low at reset) instead of on each entry into S_HICCUP | not run |  |
| `pmic_top.313.AIM.86` | strike_counter counts a strike when the hiccup cool-down finishes (hiccup_done) instead of when S_HICCUP is entered | not run |  |
| `pmic_top.314.AIM.19` | strike_counter's clean-run streak is gated on En instead of run_active, so it is not broken by soft-start time | not run |  |
| `pmic_top.314.AIM.29` | strike_counter's clean-run streak is gated on the qualified PGOOD instead of run_active, so 'clean running' is taken to mean 'rail in regulation' | not run |  |
| `pmic_top.315.AIM.52` | strike_counter breaks its clean-run streak on any CP comparator assertion instead of on the window trip, so 'fault-free' is taken to mean no overcurrent cycle at all | not run |  |
| `pmic_top.321.AIM.37` | soft_start counts its ramp steps on falling edges of the masked PWM_out instead of the synchronised modulator PWM, so each step lands when pwm_mask truncates the pulse rather than after the pulse ends | not run |  |
| `pmic_top.322.AIM.44` | soft_start's ramp branch is enabled by the gate-driver enable En instead of ss_active, so the ramp and clamp logic also runs through S_RUN | not run |  |
| `pmic_top.323.AIM.48` | soft_start holds its ramped ceiling while PGOOD is asserted instead of while the supervisor is in S_RUN, so 'running' is taken to mean 'rail qualified good' | not run |  |
| `pmic_top.323.AIM.56` | soft_start's hold branch is keyed on its own SS_done ('ramp finished') instead of S_RUN, so once a ramp completes it is never reset to the floor | not run |  |
| `pmic_top.332.AIM.61` | pwm_mask is fed the raw Osc_in pin instead of the synchronised PWM that every other block uses for the cycle | not run |  |
| `pmic_top.350.AIM.13` | MISO idles high outside the read-data phase (open-drain pull-up convention) instead of held low | not run |  |
| `pmic_top.350.AIM.85` | MISO is enabled whenever the slave is selected (CS_n low), the usual 4-wire convention, instead of only during the read-data phase (S_READ) | not run |  |
| `pmic_top.385.AIM.21` | reg_file's status PGOOD bit reports the synchronised output comparator instead of the qualified PGOOD | not run |  |
| `pmic_top.386.AIM.23` | reg_file's latch status bit reports the CPLD's own trip drive latch_out instead of the SCR latch read-back | not run |  |
| `pmic_top.386.AIM.77` | reg_file's SCR latch status bit takes the synchronised but undebounced latch_stat instead of the debounced copy the supervisor acts on | not run |  |
| `pmic_top.387.AIM.36` | reg_file's enable-switch status bit is fed from the gate-driver enable En instead of the debounced switch level | not run |  |
| `pmic_top.387.AIM.64` | reg_file's enable-switch status bit is fed the undebounced synchronised switch instead of the debounced level that gates the supervisor | not run |  |
| `pmic_top.387.AIM.78` | reg_file's enable-switch status bit is fed the switch-press edge pulse en_switch_rise instead of the debounced switch level | not run |  |
| `pmic_top.389.AIM.27` | The FAULT_FLAGS register's current-protection bit reports the RUN overcurrent window trip instead of the live synchronised CP comparator | not run |  |
| `pmic_top.390.AIM.22` | reg_file's over-temperature status bit takes the undebounced OTP flag, unlike the debounced one the supervisor acts on | not run |  |
| `pmic_top.391.AIM.63` | reg_file's UVLO status bit reports the undebounced synchronised UVLO flag instead of the debounced copy the supervisor acts on | not run |  |
| `pmic_top.392.AIM.62` | reg_file's strike-level status is fed the configured strike limit max_strikes instead of the accumulated strike_level | not run |  |
| `pmic_top.398.AIM.73` | reg_file's live TIME registers are fed fault_cause's episode-start snapshot fault_time instead of the free-running timestamp_ms | not run |  |
| `pmic_top.421.AIM.8` | pwm_stats measures the masked PWM_out instead of the synchronised modulator PWM | not run |  |
| `pmic_top.429.AIM.65` | fault_cause logs over-temperature from the undebounced synchronised OTP flag instead of the debounced copy the supervisor acts on | not run |  |
| `pmic_top.430.AIM.49` | fault_cause logs the undebounced synchronised UVLO flag instead of the debounced copy the supervisor acts on | not run |  |
| `pmic_top.431.AIM.7` | fault_cause's SCR read-back input is wired to the CPLD's own trip latch_out, so it can no longer tell an external latch from a strike latch | not run |  |
| `pmic_top.431.AIM.74` | fault_cause infers OVP from the synchronised but undebounced SCR read-back instead of the debounced copy the supervisor and LEDs act on | not run |  |
| `pmic_top.432.AIM.38` | fault_cause's latch_assert input is fed from the debounced SCR read-back instead of the CPLD's own trip latch_out, so the OVP inference (latch set with latch_assert clear) can never be true | not run |  |
| `pmic_top.433.AIM.51` | fault_cause logs the overcurrent cause from the live synchronised CP comparator instead of fault_arbiter's RUN window trip, so a single valley-current excursion counts as an overcurrent fault | not run |  |
| `pmic_top.434.AIM.47` | fault_cause's soft-start overcurrent cause is fed from the RUN window trip, so an overcurrent hiccup out of S_SS is not logged | not run |  |
| `pmic_top.435.AIM.41` | fault_cause's episode scope is wired to hiccup_active instead of ss_active, so it counts S_HICCUP as running and leaves S_SS out | not run |  |
| `pmic_top.436.AIM.24` | fault_cause's capture gate takes the gate-driver enable En as 'running' instead of the supervisor's run_active, so a hard fault in S_RUN is never logged | not run |  |
| `pmic_top.436.AIM.72` | fault_cause's capture gate takes the qualified PGOOD as 'running' instead of run_active, so a fault in S_RUN before PGOOD has qualified, or during a rail dip, is not logged | not run |  |
| `pmic_top.469.AIM.17` | PGOOD_comp is debounced before pgood_gen, so the deassert the header requires to be immediate is delayed by the debounce release time | not run |  |
| `pmic_top.473.AIM.18` | pgood_gen is qualified on the gate-driver enable En instead of run_active, so soft-start counts as running | not run |  |
| `pmic_top.473.AIM.32` | pgood_gen is qualified on soft_start's SS_done ('ramp finished') instead of the supervisor's run_active | not run |  |
| `pmic_top.493.AIM.66` | fault_LED's over-temperature indication is fed the undebounced synchronised OTP flag instead of the debounced one | not run |  |
| `pmic_top.494.AIM.3` | fault_LED's UVLO indication is fed from the undebounced synchronised UVLO flag instead of the debounced copy the supervisor acts on | not run |  |
| `pmic_top.495.AIM.67` | fault_LED's latch indication takes the CPLD's own trip latch_out instead of the SCR read-back, so an external (OVP) latch trip is not shown | not run |  |
| `pmic_top.495.AIM.79` | fault_LED's latch indication is fed the synchronised but undebounced SCR read-back instead of the debounced copy | not run |  |
| `pmic_top.496.AIM.68` | fault_LED's latch_assert input is fed the debounced SCR read-back instead of strike_counter's latch_out, so the CPLD's own strike latch is not shown until the SCR read-back follows | not run |  |
| `pmic_top.497.AIM.53` | fault_LED's strikes-outstanding input is wired to the configured strike limit max_strikes instead of the accumulated strike_level | not run |  |
| `pmic_top.498.AIM.40` | fault_LED's soft-start input is wired to soft_start's SS_done ('ramp finished') instead of the supervisor's ss_active ('in S_SS') | not run |  |
| `pmic_top.498.AIM.55` | fault_LED's soft-start input is wired to hiccup_active, so the green 'running' LED covers the hiccup cool-down instead of soft start | not run |  |
| `pmic_top.499.AIM.54` | fault_LED's running input takes the qualified PGOOD instead of run_active, so the green LED treats 'rail in regulation' as 'running' | not run |  |
| `pmic_top.500.AIM.6` | fault_LED's power-good input is wired to the synchronised comparator instead of the qualified PGOOD | not run |  |
| `pmic_top.526.AIM.31` | switch_supply is driven from the registered pgood_LED indicator copy instead of PGOOD itself, adding a clock to the changeover hand-back | not run |  |
| `pmic_top.526.AIM.43` | The housekeeping changeover drive is gated by the gate-driver enable as well as PGOOD, so it no longer carries the same value as PGOOD | not run |  |
| `pmic_top.526.AIM.5` | switch_supply follows the raw synchronised output comparator instead of the qualified PGOOD from pgood_gen | not run |  |
