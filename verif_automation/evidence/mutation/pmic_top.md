# Mutation record: pmic_top

`rtl-systemverilog/pmic_top.sv`. Written by `tools/mutation/record.py` from `pmic_top.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | - |
| AI-written | 236 | 0 | 0 | 0 | 0 | 0 | 0 | 236 | - |
| all | 236 | 0 | 0 | 0 | 0 | 0 | 0 | 236 | - |

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
| 6 | 2026-11-28 05:06 | 5948cd0 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 14, accepted 14, rejected 0; `ai_runs/2026-11-28_write_mutants_3` |
| 7 | 2026-11-28 05:15 | 5948cd0 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 11, accepted 11, rejected 0; `ai_runs/2026-11-28_write_mutants_4` |
| 8 | 2026-11-28 05:24 | 5948cd0 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 12, accepted 12, rejected 0; `ai_runs/2026-11-28_write_mutants_5` |
| 9 | 2026-11-28 05:34 | 5948cd0 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 10, accepted 10, rejected 0; `ai_runs/2026-11-28_write_mutants_6` |
| 10 | 2026-11-28 05:42 | 5948cd0 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 8, accepted 8, rejected 0; `ai_runs/2026-11-28_write_mutants_7` |
| 11 | 2026-11-28 05:50 | 5948cd0 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 14, accepted 14, rejected 0; `ai_runs/2026-11-28_write_mutants_8` |
| 12 | 2026-11-28 06:00 | 5948cd0 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 11, accepted 11, rejected 0; `ai_runs/2026-11-28_write_mutants_9` |
| 13 | 2026-11-28 06:08 | 5948cd0 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 4, accepted 3, rejected 1; `ai_runs/2026-11-28_write_mutants_10` |
| 14 | 2026-11-28 06:18 | 5948cd0 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 11, accepted 11, rejected 0; `ai_runs/2026-11-28_write_mutants_11` |
| 15 | 2026-11-28 10:20 | 5948cd0 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 11, accepted 11, rejected 0; `ai_runs/2026-11-28_write_mutants_12` |
| 16 | 2026-11-28 10:31 | 5948cd0 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 11, accepted 11, rejected 0; `ai_runs/2026-11-28_write_mutants_13` |
| 17 | 2026-11-28 10:44 | 5948cd0 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 16, accepted 15, rejected 1; `ai_runs/2026-11-28_write_mutants_14` |
| 18 | 2026-11-28 10:56 | 5948cd0 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 18, accepted 17, rejected 1; `ai_runs/2026-11-28_write_mutants_15` |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (236)

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
| 89 | 6 | sequencing | fault_arbiter's valley-sample cycle boundary is taken from the masked, registered gate PWM_out instead of the synchronised modulator PWM, so each per-cycle CP sample lands one clock after the modulator's turn-on edge | not run |  |
| 90 | 6 | sequencing | pgood_gen counts its qualifying switching cycles on falling edges of the masked gate PWM_out instead of the synchronised modulator PWM | not run |  |
| 91 | 6 | missing_case | fault_cause's 'converter running' scope takes soft_start's SS_done ('ramp finished') instead of the supervisor's ss_active ('in S_SS'), so faults during the ramp are outside the episode | not run |  |
| 92 | 6 | protocol | spi_slave is handed the inverted filtered SCK, as if the bus were CPOL=1 (Mode 3) instead of Mode 0, so it samples MOSI on the master's falling SCK edge and shifts MISO on the rising edge | not run |  |
| 93 | 6 | field | pwm_stats measures the inverted modulator PWM, so DUTY_COUNT reports the low-side (off) time of each cycle instead of the high-side on-time | not run |  |
| 94 | 6 | wrong_event | fault_arbiter's per-cycle CP sample is taken at high-side turn-off (the falling PWM edge, near peak current) instead of at turn-on (the valley), mixing up which edge ends low-side conduction | not run |  |
| 95 | 6 | wrong_event | soft_start counts ramp cycles and widens the ceiling at the PWM turn-on edge instead of after each pulse has ended, so each step lands as a pulse starts | not run |  |
| 96 | 6 | wrong_event | strike_counter takes its clean-run cycle boundary from the masked, registered gate PWM_out instead of the synchronised modulator PWM | not run |  |
| 97 | 6 | reset_init | soft_start's hold branch covers S_HICCUP as well as S_RUN, so a hiccup does not reset the ramped ceiling and SS_done to the floor; only S_OFF does | not run |  |
| 98 | 6 | other | spi_enable, the host's CONTROL run-enable for the converter, is mistaken for an SPI-interface enable and gates the slave's chip select, so a host that disables the converter is locked off the bus | not run |  |
| 99 | 6 | protocol | spi_slave is handed the inverted filtered chip select, as if CS were active high, so the idle bus looks selected and a real transaction looks deselected | not run |  |
| 100 | 6 | other | pwm_mask's PWM input is gated by the gate-driver enable En, adding the second logic shutdown path that the header explicitly rules out | not run |  |
| 101 | 6 | boundary | hiccup_timer is given strike_level minus one, as if the strike count had not already been incremented on entry to S_HICCUP, so each cool-down is half its intended length | not run |  |
| 102 | 6 | boundary | pgood_gen's qualifying delay is converted with ms_to_clks, as for the debouncers, although pgood_gen counts switching cycles, so the 9 ms qualification becomes 450000 PWM cycles (about 1 s) | not run |  |
| 103 | 7 | field | In S_RUN, pwm_mask takes its on-time ceiling straight from the host's max_on_limit register instead of the ceiling soft_start ramped to and now holds | not run |  |
| 104 | 7 | missing_case | The FAULT_FLAGS current-protection status bit is masked by the gate-driver enable, on the idea that the valley comparator only means something while the stage is switching | not run |  |
| 105 | 7 | other | The CPLD's own strike trip latch_out is ORed into the SCR read-back before debouncing, as if the read-back had to follow the CPLD's drive, so the latch read-back no longer reports only the physical SCR | not run |  |
| 106 | 7 | boundary | hiccup_timer is handed strike_level plus one, as if it had to anticipate strike_counter's increment on entry to S_HICCUP, so every cool-down is one doubling longer than the strike count calls for | not run |  |
| 107 | 7 | protocol | MISO is tri-stated outside the read-data phase, following the usual shared-bus SPI slave habit, instead of being driven low as a plain output | not run |  |
| 108 | 7 | missing_case | pwm_stats measures the synchronised modulator PWM only while the gate driver is enabled, though its block comment says it runs unconditionally because duty and period matter as much during a fault | not run |  |
| 109 | 7 | sequencing | The housekeeping changeover drive is held on for one extra clock after PGOOD drops, ORed with the registered pgood_LED copy as a glitch hold-off, so the hand-back is no longer immediate | not run |  |
| 110 | 7 | other | fault_arbiter's current flag is qualified by the modulator PWM, as if the current comparator were only valid during high-side on-time, though it is a valley comparator sampled in low-side conduction | not run |  |
| 111 | 7 | missing_case | fault_cause's 'converter running' capture scope also covers S_HICCUP, as if the hiccup cool-down were part of the operating episode | not run |  |
| 112 | 7 | field | reg_file's enable-switch status bit reports the combined enable (switch AND host CONTROL enable) instead of the physical switch alone | not run |  |
| 113 | 7 | field | reg_file's SCR latch status bit shows only externally-originated latch trips, masking the read-back whenever the CPLD's own latch_out is driving, as if it were fault_cause's OVP inference | not run |  |
| 114 | 8 | other | The CPLD's trip drive latch_out is released once the debounced SCR read-back shows the latch set, as if the self-holding SCR needed the drive only until it fired, instead of following strike_counter's set-only latch_assert | not run |  |
| 115 | 8 | protocol | fault_cause's clear-on-read also fires on spi_abort, as if any transaction that ended unvalidated also closed the fault-log read window, so a failed write wipes the fault record and its start time | not run |  |
| 116 | 8 | protocol | reg_file's read snapshot of the timestamp is retaken after every read data byte clocked out instead of only on the first data byte of the read | not run |  |
| 117 | 8 | protocol | Chip-select deassert is taken straight from the unfiltered synchronised CS_n, so only selection goes through the glitch filter, as if 'deselect must be immediate' | not run |  |
| 118 | 8 | boundary | strike_counter is handed the strike limit minus one, a second off-by-one fix on top of the one strike_counter already makes by comparing with max_strikes-1 | not run |  |
| 119 | 8 | other | The UVLO debouncer is copied from the SPI glitch filters, so input undervoltage qualifies in 8 clocks (160 ns) both ways instead of the fault-flag 1 ms assert and 200 us release | not run |  |
| 120 | 8 | protocol | reg_file's write strobe is qualified by spi_integrity_ok, as if only validated bytes should reach the register file, though reg_file stages every data byte and validates later at commit | not run |  |
| 121 | 8 | protocol | reg_file commits staged writes at the end of any write transaction (integrity_ok or txn_abort), mixing up 'transaction ended' with 'transaction validated' | not run |  |
| 122 | 8 | other | reg_file's txn_abort is driven on every write-transaction end, valid or not, as if it only meant 'discard the temporaries now', so the bus-error tally also counts good transactions | not run |  |
| 123 | 8 | reset_init | fault_cause's clear-on-read is also required to come from a CRC-validated transaction, as if the destructive clear needed write-style validation, though reads never produce integrity_ok | not run |  |
| 124 | 8 | wrong_event | fault_cause's record is cleared when any read transaction starts (rd_first) as well as after 0x20 is read, taking 'clear on read' to mean 'clear when a read begins' | not run |  |
| 125 | 8 | protocol | reg_file's 'data byte transferred' strobe also counts write data bytes, so a write that releases a byte at 0x20 counts as the host having read the fault record | not run |  |
| 126 | 9 | boundary | soft_start's ramp floor is set from the wanted gate on-time MIN_GATE_ON_NS alone, without the LM5106 turn-on shrinkage, so the floor is 6 clocks instead of 12 | not run |  |
| 127 | 9 | boundary | soft_start is handed cycles_per_step minus one, an off-by-one fix applied a second time on top of soft_start's own compare against cycles_per_step-1 | not run |  |
| 128 | 9 | protocol | spi_slave's SCK rising edge is taken straight from the unfiltered synchronised SCK, so only the falling edge goes through the glitch filter, as if the filter were needed only on release | not run |  |
| 129 | 9 | sequencing | spi_slave's 2 ms dead-master SCK idle timeout is converted with ms_to_sw_cycles instead of ms_to_clks, so the slave, which counts clk ticks, times out after 900 clocks (18 us) | not run |  |
| 130 | 9 | boundary | pgood_gen's qualifying count is set to 2**PGOOD_DELAY_W, following the package's out-of-date note that the counter saturates at all-ones, instead of PGOOD_DELAY_CYCLES | not run |  |
| 131 | 9 | other | The 20 ms enable debouncer is fed the combined enable (switch AND host CONTROL enable) instead of the physical switch alone, as if 'the enable' to be debounced were the supervisor's g_en | not run |  |
| 132 | 9 | reset_init | hiccup_timer is kept armed through the soft-start retry as well as S_HICCUP, as if cool-down plus re-ramp were one episode, so hiccup_done is not cleared on leaving S_HICCUP for S_SS | not run |  |
| 133 | 9 | missing_case | fault_cause's over-temperature input is qualified by the gate-driver enable, meant as 'only faults that interrupted switching', but the supervisor drops En combinationally on OTP itself | not run |  |
| 134 | 9 | boundary | The fault-log timebase prescaler is set with ms_to_sw_cycles(1) instead of the clk-based package value. The timestamp counts clk ticks, so a 'millisecond' tick comes every 450 clocks (9 us) instead of every 50000. | not run |  |
| 135 | 9 | boundary | The Red_LED1 strike blink half-period is sized in switching cycles (ms_to_sw_cycles(125)), to match the clean-run window it was chosen against. But fault_LED's blink counter counts clk ticks, so it gets 56250 clocks (about 1.1 ms) instead of 125 ms. | not run |  |
| 136 | 10 | boundary | The per-strike doubling of the hiccup cool-down is also applied at the call site, so hiccup_timer gets a base already shifted by strike_level and shifts it again: each strike quadruples the interval instead of doubling it. | not run |  |
| 137 | 10 | protocol | The slave is selected straight from the unfiltered synchronised CS_n and only the deselect goes through the glitch filter, as if 'selection must be immediate'. | not run |  |
| 138 | 10 | protocol | MISO is also cut by the unfiltered synchronised CS_n, so read data drops at once on a deselect (or a CS glitch) instead of following spi_slave's S_READ phase on the filtered chip select | not run |  |
| 139 | 10 | sequencing | reg_file's STATUS power-good bit is fed fault_LED's registered pgood_LED copy instead of PGOOD itself, so telemetry lags the changeover by a clock | not run |  |
| 140 | 10 | field | reg_file's SCR latch status bit ORs in the CPLD's own trip drive latch_out, as if 'latch set' meant 'either source driving it', instead of reporting the debounced physical read-back alone | not run |  |
| 141 | 10 | sequencing | pgood_gen's 'regulating' qualifier is also ANDed with the gate-driver enable, as if PGOOD had to drop with the combinational fault gating of En rather than when the supervisor leaves S_RUN | not run |  |
| 142 | 10 | boundary | strike_counter is handed the clean-run target minus one, taking the counter to count from zero to target-1, although it clears strikes when clean_counter equals the target itself | not run |  |
| 143 | 10 | field | fault_cause's episode-start snapshot is wired to its own fault_time output instead of the free-running timestamp_ms, a slip between the two adjacent TIMESTAMP_W ports, so the snapshot just reloads the cleared value | not run |  |
| 144 | 11 | missing_case | Supervisor's S_RUN overcurrent exit takes the live synchronised CP comparator instead of fault_arbiter's RUN window trip, so the rolling-window duration filter is bypassed for the FSM | not run |  |
| 145 | 11 | missing_case | Supervisor's soft-start overcurrent exit takes the live synchronised CP comparator instead of fault_arbiter's soft-start window trip, so the higher soft-start tolerance trip_ss is never applied | not run |  |
| 146 | 11 | other | The valley-current comparator is taken as active low (open-drain fault convention) at fault_arbiter, so a low CP_trig counts as an overcurrent cycle | not run |  |
| 147 | 11 | other | The UVLO comparator is read as an 'input good' signal (high when the input rail is above threshold), so its synchronised level is inverted before debouncing | not run |  |
| 148 | 11 | other | The SCR latch read-back is taken as active low (the anode node pulled down when the SCR fires), so the synchronised read-back is inverted before debouncing | not run |  |
| 149 | 11 | other | The over-temperature comparator is read as active low (the open-drain thermal-warning convention), so its synchronised level is inverted before debouncing | not run |  |
| 150 | 11 | other | The output-rail window comparator is taken as an active-low power-fail output, so pgood_gen is handed its inverted synchronised level | not run |  |
| 151 | 11 | other | The physical enable switch is treated as active low (a switch to ground with a pull-up), so its synchronised level is inverted before the 20 ms debouncer | not run |  |
| 152 | 11 | boundary | fault_arbiter is handed the RUN trip threshold minus one, as if it tripped on count > trip_run, though it already compares with >= | not run |  |
| 153 | 11 | reset_init | The fault-log timestamp is held in reset whenever the gate driver is disabled, reading 'time since start of convertor' as time since the converter was enabled, though the timestamp must free-run in every state and be cleared only by rst_n | not run |  |
| 154 | 11 | other | Master_PWM from the modulator is taken as active low (as if it were the low-side drive command), so it is inverted before its synchroniser | not run |  |
| 155 | 11 | boundary | hiccup_timer is handed hiccup_base minus one, an off-by-one 'fix' for its counter matching at the target, which shortens every cool-down by 2**strike_level clocks | not run |  |
| 156 | 11 | reset_init | fault_arbiter's soft-start scope also covers S_HICCUP, as if the cool-down and its soft-start retry were one episode, so the overcurrent windows and the CP history are not cleared during the hiccup | not run |  |
| 157 | 11 | sequencing | The supervisor's switch enable is ANDed with the raw synchronised switch, following a 'switch-off must act at once' idea, so only the press is debounced and a release or bounce takes effect immediately | not run |  |
| 158 | 12 | protocol | spi_slave is held in reset whenever the filtered chip select is high, meant to stop noise on a deselected bus from disturbing it, so a transaction's end at CS rise is erased before the slave can judge it | not run |  |
| 159 | 12 | reset_init | strike_counter is reset whenever the debounced enable switch is off, as if cycling the switch earned a fresh set of strikes, though latch_assert must be cleared only by rst_n together with the physical SCR | not run |  |
| 160 | 12 | wrong_event | fault_cause's record is also cleared by a fresh press of the enable switch, taking an 'episode' to mean one power-on run instead of one host read window | not run |  |
| 161 | 12 | sequencing | The switch-press pulse en_switch_rise is registered, so it reaches reg_file one clock after the debounced switch rises instead of on the same clock | not run |  |
| 162 | 12 | other | The valley-current comparator is mistaken for a peak current limit, so pwm_mask's PWM is cut on any clock where CP_trig is high, a cycle-by-cycle limit the design does not have | not run |  |
| 163 | 12 | sequencing | The supervisor's hiccup exit also waits for the synchronised valley-current comparator to clear, 'do not retry into a live overcurrent', although the header says a retry always follows hiccup_done | not run |  |
| 164 | 12 | missing_case | fault_LED shows outstanding strikes only while the supervisor is in S_RUN, taking 'blink through the clean-run window' to mean only that, so Red_LED1 does not blink during the hiccup cool-down or the soft-start retry | not run |  |
| 165 | 12 | reset_init | The fault-log timestamp is restarted each time the host finishes reading the fault record (fault_reg_read_done), taking the timestamp to be time since the last episode, though it must free-run from rst_n | not run |  |
| 166 | 12 | reset_init | reg_file is held in reset while the debounced enable switch is off, as if switching off were a full reset of the host configuration | not run |  |
| 167 | 12 | other | The supervisor's over-temperature input ORs the undebounced synchronised OTP flag with the debounced one ('trip at once, debounce only the release'), so the 1 ms assert qualification no longer applies to the FSM | not run |  |
| 168 | 12 | wrong_event | soft_start's ramp runs through the hiccup cool-down as well as S_SS, as if cool-down plus retry were one ramp period, so the ceiling keeps widening while the gate driver is off | not run |  |
| 169 | 13 | other | Master_PWM goes through the short symmetric SPI glitch filter after its synchroniser, as if switch-node pickup on the modulator line needed the same 160 ns filter as SCK, so every block's cycle reference is delayed and short pulses are swallowed | not run |  |
| 170 | 13 | boundary | fault_arbiter's valley-sample lookback BLANK_CLKS is sized from the LM5106 turn-on shrinkage (7 clocks, 140 ns), as if the blanking had to cover the gate driver's delay, instead of the module's 5-clock (100 ns) default | not run |  |
| 171 | 13 | other | pwm_mask's on-time ceiling has the LM5106 turn-on shrinkage added at the call site, so the gate on-time is meant to equal the ceiling, but the shrinkage is then counted twice because MIN_ON_COUNTS already includes it | not run |  |
| 172 | 14 | sequencing | soft_start's ramp branch is enabled only while the ramp is unfinished (ss_active and not SS_done), as if a finished ramp no longer needed the S_SS branch, so on the last S_SS clock it falls into the reset-to-floor branch | not run |  |
| 173 | 14 | boundary | fault_arbiter is handed the soft-start trip threshold minus one, as if it tripped on count > trip_ss, though it already compares with >= | not run |  |
| 174 | 14 | reset_init | fault_cause is held in reset while the gate driver is disabled, so routine power-downs do not log a fault. This wipes the record on every fault shutdown, which is exactly when it must survive. | not run |  |
| 175 | 14 | missing_case | fault_LED's over-temperature input is gated by 'converter running' like fault_cause's capture gate, though the LEDs show what is wrong now and must light in any state | not run |  |
| 176 | 14 | missing_case | The switch-press pulse is taken as a rise of the combined enable (switch AND host CONTROL enable), so it is masked exactly when the host has disabled the converter, which is the one case the press is there to override | not run |  |
| 177 | 14 | sequencing | fault_arbiter's soft-start scope is limited to the unfinished ramp (S_SS and not SS_done), so on the last S_SS clock it sees neither state active and clears both windows and the CP history | not run |  |
| 178 | 14 | other | The supervisor holds in S_SS after the ramp is done until the live valley-current comparator is clear, treating 'do not hand over to RUN in overcurrent' as a condition of the ramp handshake | not run |  |
| 179 | 14 | protocol | reg_file's commit and discard strobes are qualified by chip select still asserted, though spi_slave raises both only after CS has risen at the end of the transaction | not run |  |
| 180 | 14 | boundary | soft_start's ramp target is floored at the 75% default ceiling, from the package rule that the digital mask must stay above the analog clamp and never be the primary limiter, so a host-lowered MAX_ON limit is overridden | not run |  |
| 181 | 14 | boundary | fault_arbiter's soft-start trip threshold is floored at the RUN threshold, enforcing the package note that S_SS is 'more tolerant', so a legal host write of trip_ss below trip_run is overridden | not run |  |
| 182 | 14 | sequencing | The supervisor's host enable is ORed with the switch-press pulse at the top level, so a fresh press overrides a host disable on the press clock itself. reg_file already restores spi_enable on the next clock, so the override lands a clock early. | not run |  |
| 186 | 15 | missing_case | fault_LED's UVLO indication is masked unless the converter is in S_SS or S_RUN. This borrows fault_cause's 'a routine power-down asserts UVLO' capture rule, but the LEDs must show what is wrong now, in every state. | not run |  |
| 187 | 15 | priority | The switch-press pulse is suppressed while the host enable is still set, as if it were only needed to lift a veto already in place. reg_file's rule that the physical switch wins a same-clock collision with a host disable is lost. | not run |  |
| 188 | 15 | sequencing | pgood_gen's 'regulating' qualifier also drops on the RUN window trip. The aim is to hand the rail back the moment an overcurrent is detected, but PGOOD should follow the supervisor's exit from S_RUN. | not run |  |
| 189 | 15 | other | The overcurrent window trips are folded into fault_LED's running indication, a second path that fault_LED's header deliberately leaves out because the supervisor's state change already turns off the green LED. | not run |  |
| 190 | 15 | boundary | hiccup_timer's cool-down counter is sized from the default 5 ms base instead of the largest legal host-written base (HICCUP_BASE_MAX_CLKS), which is the sizing mistake the package warns against | not run |  |
| 191 | 15 | missing_case | fault_cause's RUN overcurrent input is wired to the soft-start window trip, so both of its overcurrent inputs carry window_trip_SS and a RUN window trip is never logged | not run |  |
| 192 | 15 | field | reg_file's STRIKE_LEVEL telemetry is zeroed once the CPLD's strike latch has tripped, copying fault_LED's 'latch outranks strikes' priority into the register map. strike_counter deliberately keeps the count readable after latching. | not run |  |
| 193 | 15 | field | reg_file's FCOUNT_SS telemetry is gated by S_SS, mirroring the way fault_arbiter gates window_trip_SS by its own state. But the soft-start count is meant to stay frozen, and readable, through S_RUN. | not run |  |
| 194 | 15 | missing_case | The switch-press pulse that restores the host enable is ignored while a debounced OTP or UVLO is live, as if a press should only re-enable a board that is able to start. | not run |  |
| 195 | 15 | wrong_event | UVLO is only qualified while the gate driver is enabled. This borrows the 'a routine power-down asserts UVLO' rule to ignore UVLO when not switching, so the debounced UVLO the FSM sees drops in S_OFF. | not run |  |
| 196 | 15 | reset_init | fault_cause's clear-on-read is suppressed while the converter is in S_SS or S_RUN, meant to avoid wiping an episode still in progress. The record and its fault_time then survive a host read that should close the read window. | not run |  |
| 197 | 16 | boundary | fault_LED's blink half-period is overridden with the full 250 ms period of the intended 4 Hz blink, so the period is mistaken for the half-period. | not run |  |
| 198 | 16 | field | The FAULT_FLAGS current-protection status bit is masked while the modulator PWM is high, on the idea that the valley comparator only means something during low-side conduction. | not run |  |
| 199 | 16 | missing_case | reg_file's UVLO status bit is masked outside S_SS and S_RUN, copying fault_cause's 'a routine power-down asserts UVLO' capture rule into the live status register. | not run |  |
| 200 | 16 | missing_case | strike_counter's clean-run streak is also broken whenever the output comparator reports the rail out of window, so 'fault-free running' is taken to need the rail in regulation as well as no overcurrent window trip. | not run |  |
| 201 | 16 | other | pgood_gen treats a live valley-current comparator as 'rail not good', so any CP_trig assertion in S_RUN clears the power-good qualification | not run |  |
| 202 | 16 | missing_case | pgood_gen is qualified on S_RUN with no strikes outstanding, as if the housekeeping rail must not be handed to a converter still proving itself after a hiccup | not run |  |
| 203 | 16 | other | The debounced over-temperature flag is added as a second CPLD trip source into the shared SCR latch, as if OTP were a hard fault to latch, instead of latch_out following strike_counter's latch_assert alone | not run |  |
| 204 | 16 | missing_case | fault_LED's running indication is suppressed while strikes are outstanding, so Green_LED is not lit together with the blinking Red_LED1 during the clean-run window | not run |  |
| 205 | 16 | wrong_event | pgood_gen gets the inverted modulator PWM, so it counts its qualifying cycles at high-side turn-on (the cycle boundary fault_arbiter uses) instead of at the end of each pulse | not run |  |
| 206 | 16 | wrong_event | strike_counter counts a strike on the overcurrent window trip itself instead of on entry into S_HICCUP, as if 'a strike' were the trip rather than the hiccup it causes | not run |  |
| 207 | 16 | sequencing | MISO is retimed through an extra clk flop 'to deglitch it', though the header says both terms are already flops and MISO is driven straight from them | not run |  |
| 208 | 17 | reset_init | fault_LED is held in reset while the debounced enable switch is off, as if a switched-off board should show a dark front panel. The LEDs must show what is wrong now, in every state. | not run |  |
| 209 | 17 | field | reg_file is instanced with its two magic key bytes swapped: DISABLE_KEY is set to the write-access value 0xA7 and WRITE_ACCESS_KEY to the disable value 0xD1 | not run |  |
| 210 | 17 | boundary | The timestamp prescaler is handed PRESCALE_VAL minus one, an off-by-one 'fix' made at the call site although timestamp already compares its prescaler with PRESCALE_VAL-1 | not run |  |
| 211 | 17 | sequencing | latch_out is retimed through an extra output flop 'because it drives the SCR gate', though the header says it is driven straight from strike_counter's latch_assert | not run |  |
| 212 | 17 | sequencing | The gate PWM gets a second pin register at the top level for glitch-free output, although pwm_mask's output is already a flop | not run |  |
| 213 | 17 | protocol | spi_slave's SCK falling edge is taken straight from the unfiltered synchronised SCK, so only the rising (sampling) edge goes through the glitch filter, as if only the sample edge needed filtering | not run |  |
| 214 | 17 | missing_case | reg_file's timestamp snapshot is only taken for reads that begin inside the TIME bank (0x18-0x1A), though rd_first must freeze it at the start of any read | not run |  |
| 215 | 17 | boundary | The dead-master SCK idle timeout is given the 5 s host-silence watchdog interval (WD_TIMEOUT_MS) instead of its own 2 ms | not run |  |
| 216 | 17 | field | reg_file's FAULT_TIME registers are given the age of the episode (timestamp_ms minus the episode-start snapshot) instead of the episode-start time itself, reading 'timestamp of the fault' as 'time since the fault' | not run |  |
| 217 | 17 | field | fault_LED's 'strikes outstanding' is taken to mean strikes remaining before the latch (max_strikes - strike_level) instead of strikes accumulated | not run |  |
| 218 | 17 | other | The CPLD's trip drive latch_out is held on while the debounced SCR read-back is set, as if the gate drive had to sustain the SCR, instead of following strike_counter's latch_assert alone | not run |  |
| 219 | 17 | missing_case | The supervisor ignores input undervoltage during soft start, as if input-rail sag from the start-up inrush were expected and had to be blanked | not run |  |
| 220 | 17 | protocol | Host write data is bit-reversed before reg_file, as if spi_slave assembled bytes LSB-first, though the bus is MSB-first | not run |  |
| 221 | 17 | sequencing | The hiccup_done handshake from hiccup_timer is registered once more at the top level before the supervisor, so the cool-down end is acted on one clock late | not run |  |
| 222 | 17 | priority | A completed ramp outranks a soft-start overcurrent trip: window_trip_SS is masked by SS_done at the supervisor, so a same-clock trip hands over to S_RUN instead of hiccuping | not run |  |
| 223 | 18 | sequencing | soft_start's SS_done handshake is registered once more at the top level before the supervisor, so the end of the ramp is acted on one clock late | not run |  |
| 224 | 18 | sequencing | fault_arbiter's RUN window trip is retimed through a flop before the supervisor to break the counter-compare path, so the S_RUN to S_HICCUP exit lands one clock after the trip | not run |  |
| 225 | 18 | sequencing | spi_slave's combinational rd_first is registered before reg_file as an ordinary strobe, so the read snapshot is taken one clock after the first read byte has already been loaded | not run |  |
| 226 | 18 | field | FAULT_CAUSE is read through a priority encoder that keeps only the highest set cause bit, from reading 'priority is encoded in bit position' as 'report the top cause only', though the record is a one-hot OR accumulation | not run |  |
| 227 | 18 | field | The FAULT_FLAGS over-temperature bit ORs in fault_cause's recorded OTP cause, making the live status flag sticky like the fault record | not run |  |
| 228 | 18 | field | The fault record is also cleared by a write to FAULT_CAUSE (0x1D), applying the write-1-to-clear convention to a register that is read-only and clears on read | not run |  |
| 229 | 18 | missing_case | The supervisor ignores over-temperature during S_HICCUP, on the idea that the cool-down already holds the gate off and the retry will catch it | not run |  |
| 230 | 18 | boundary | pgood_gen's qualifying count is given the delay in milliseconds (PGOOD_DELAY_MS = 9) where it expects switching cycles, so a unit conversion is left out | not run |  |
| 231 | 18 | boundary | soft_start's ramp floor is given the summed floor in nanoseconds (240) without ns_to_clks, so a value in ns is used as a clk count | not run |  |
| 232 | 18 | protocol | Register read data is bit-reversed before spi_slave, as if the slave shifted MISO out LSB-first, though the bus is MSB-first | not run |  |
| 233 | 18 | field | The free-running timestamp reaches reg_file with its three bytes in reverse order, so TIME_0 at 0x18 holds the most significant byte instead of the least | not run |  |
| 234 | 18 | field | fault_cause's episode-start time reaches reg_file byte-reversed, so FTIME_0 at 0x1E reports the most significant byte | not run |  |
| 235 | 18 | field | The one-hot fault-cause record is wired to reg_file bit-reversed, as if bit 0 were the highest-priority cause, so OC appears in the OVP position and OVP in the OC position | not run |  |
| 236 | 18 | boundary | strike_counter is given the strike limit plus one, as if MAX_STRIKES counted the hiccups allowed before the latching strike rather than the latching strike itself | not run |  |
| 237 | 18 | sequencing | run_active is retimed through a flop before pgood_gen to break the supervisor-to-PGOOD path, so the power-good qualifier lags the FSM by a clock | not run |  |
| 238 | 18 | protocol | The CS_n glitch filter is given half the SPI filter length, as if chip select only had to beat the first SCK edge, against the header's rule that all three SPI filters carry identical parameters | not run |  |
| 239 | 18 | other | The per-strike doubling meant for the hiccup cool-down is also applied to soft_start's ramp rate, so each strike doubles the switching cycles held at every ceiling step of the retry ramp | not run |  |

Rejected by the gate in step 5 (1):

- pgood_gen takes the raw asynchronous PGOOD_comp pin instead of its synchronised copy, breaking the rule that no submodule sees a raw pin - **make lint already catches it: make lint: UNUSEDSIGNAL**

Rejected by the gate in step 13 (1):

- spi_slave takes MOSI straight from its synchroniser, bypassing the MOSI glitch filter, as if only the clock and select lines needed filtering, so data no longer has the same 8-clock delay as the filtered SCK it is sampled against - **make lint already catches it: make lint: UNUSEDSIGNAL**

Rejected by the gate in step 17 (1):

- The switch-press pulse is qualified by the host enable, as if a host veto had to outrank the physical switch, so a press is ignored exactly when the host has disabled the converter - **the same edit as pmic_top.254.AIM.176**

Rejected by the gate in step 18 (1):

- The rolling-window counts are cross-wired: FCOUNT_RUN (0x15) reports the soft-start window and FCOUNT_SS (0x16) the RUN window - **not legal code: %Error: pmic_top.sv:396:63: syntax error, unexpected '.', expecting ')'**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `pmic_top.96.AIM.11` | The PWM synchroniser gets the fault inputs' fail-safe-high reset value, as if the PWM were a fault flag | not run |  |
| `pmic_top.96.AIM.154` | Master_PWM from the modulator is taken as active low (as if it were the low-side drive command), so it is inverted before its synchroniser | not run |  |
| `pmic_top.96.AIM.169` | Master_PWM goes through the short symmetric SPI glitch filter after its synchroniser, as if switch-node pickup on the modulator line needed the same 160 ns filter as SCK, so every block's cycle reference is delayed and short pulses are swallowed | not run |  |
| `pmic_top.132.AIM.76` | The enable-switch debounce time is converted with ms_to_sw_cycles instead of ms_to_clks, so the debouncer, which counts clk ticks, gets 9000 clocks (180 us) instead of 20 ms | not run |  |
| `pmic_top.133.AIM.9` | The enable switch debouncer gets the fault-flag asymmetric release time (assert/5, 4 ms) instead of the symmetric 20 ms | not run |  |
| `pmic_top.136.AIM.131` | The 20 ms enable debouncer is fed the combined enable (switch AND host CONTROL enable) instead of the physical switch alone, as if 'the enable' to be debounced were the supervisor's g_en | not run |  |
| `pmic_top.136.AIM.151` | The physical enable switch is treated as active low (a switch to ground with a pull-up), so its synchronised level is inverted before the 20 ms debouncer | not run |  |
| `pmic_top.138.AIM.149` | The over-temperature comparator is read as active low (the open-drain thermal-warning convention), so its synchronised level is inverted before debouncing | not run |  |
| `pmic_top.138.AIM.26` | OTP debouncer copied from the enable-switch instance above it: symmetric 20 ms qualification instead of the fault-flag default of 1 ms assert and 200 us release | not run |  |
| `pmic_top.138.AIM.75` | OTP debouncer is given the enable's fail-safe-low reset value, so over-temperature reads clear out of reset while its synchroniser resets high | not run |  |
| `pmic_top.138.AIM.81` | The OTP debouncer's asymmetry is reversed: 200 us to assert and 1 ms to release, the 'trip fast, clear slow' habit applied where the design wants assert to be the longer qualification | not run |  |
| `pmic_top.138.AIM.88` | The OTP debouncer is copied from the SPI glitch filters, so over-temperature is qualified in 8 clocks (160 ns) both ways instead of the fault-flag 1 ms assert and 200 us release | not run |  |
| `pmic_top.139.AIM.10` | The UVLO debouncer is given the enable's fail-safe-low reset value instead of fault-asserted high, so it disagrees with its high-resetting synchroniser | not run |  |
| `pmic_top.139.AIM.119` | The UVLO debouncer is copied from the SPI glitch filters, so input undervoltage qualifies in 8 clocks (160 ns) both ways instead of the fault-flag 1 ms assert and 200 us release | not run |  |
| `pmic_top.139.AIM.147` | The UVLO comparator is read as an 'input good' signal (high when the input rail is above threshold), so its synchronised level is inverted before debouncing | not run |  |
| `pmic_top.139.AIM.195` | UVLO is only qualified while the gate driver is enabled. This borrows the 'a routine power-down asserts UVLO' rule to ignore UVLO when not switching, so the debounced UVLO the FSM sees drops in S_OFF. | not run |  |
| `pmic_top.139.AIM.33` | UVLO debouncer's asymmetry is reversed (fast 200 us assert, slow 1 ms release), the usual 'trip fast, clear slow' rule misapplied where the header wants assert to be the longer qualification | not run |  |
| `pmic_top.139.AIM.83` | The UVLO debouncer is copied from the enable-switch instance above it, so it gets the symmetric 20 ms switch qualification instead of the fault-flag default of 1 ms assert and 200 us release | not run |  |
| `pmic_top.140.AIM.105` | The CPLD's own strike trip latch_out is ORed into the SCR read-back before debouncing, as if the read-back had to follow the CPLD's drive, so the latch read-back no longer reports only the physical SCR | not run |  |
| `pmic_top.140.AIM.148` | The SCR latch read-back is taken as active low (the anode node pulled down when the SCR fires), so the synchronised read-back is inverted before debouncing | not run |  |
| `pmic_top.140.AIM.34` | The latch read-back debouncer is given the short symmetric SPI glitch-filter length (8 clocks) instead of the fault-flag 1 ms / 200 us qualification | not run |  |
| `pmic_top.140.AIM.80` | The latch read-back debouncer is given the enable's fail-safe-low reset value, so the SCR latch reads clear out of reset although its synchroniser resets high | not run |  |
| `pmic_top.140.AIM.84` | The SCR latch read-back debouncer has its asymmetry reversed: it asserts after 200 us and releases after 1 ms, the 'trip fast, clear slow' habit applied where the fault flags want assert to be the longer qualification | not run |  |
| `pmic_top.140.AIM.87` | The SCR latch read-back debouncer is copied from the enable-switch instance, so it gets the symmetric 20 ms switch qualification instead of the fault-flag default of 1 ms assert and 200 us release | not run |  |
| `pmic_top.159.AIM.12` | The SCK filter is instanced with the fault-flag debounce defaults instead of the short symmetric SPI_FILTER_CLKS | not run |  |
| `pmic_top.162.AIM.238` | The CS_n glitch filter is given half the SPI filter length, as if chip select only had to beat the first SCK edge, against the header's rule that all three SPI filters carry identical parameters | not run |  |
| `pmic_top.162.AIM.69` | The CS_n glitch filter is instanced with the fault-flag debounce defaults (1 ms high, 200 us low) instead of the short symmetric SPI_FILTER_CLKS | not run |  |
| `pmic_top.165.AIM.82` | The MOSI glitch filter is instanced with the fault-flag debounce times (1 ms high, 200 us low) instead of the short symmetric SPI_FILTER_CLKS, so it no longer matches the SCK filter | not run |  |
| `pmic_top.242.AIM.28` | The switch-press edge detector's delayed copy is taken from the undebounced synchronised switch instead of the debounced one it is compared with | not run |  |
| `pmic_top.248.AIM.161` | The switch-press pulse en_switch_rise is registered, so it reaches reg_file one clock after the debounced switch rises instead of on the same clock | not run |  |
| `pmic_top.254.AIM.15` | Switch-press edge detector compares the delayed debounced copy with the synchronised but undebounced switch | not run |  |
| `pmic_top.254.AIM.176` | The switch-press pulse is taken as a rise of the combined enable (switch AND host CONTROL enable), so it is masked exactly when the host has disabled the converter, which is the one case the press is there to override | not run |  |
| `pmic_top.254.AIM.187` | The switch-press pulse is suppressed while the host enable is still set, as if it were only needed to lift a veto already in place. reg_file's rule that the physical switch wins a same-clock collision with a host disable is lost. | not run |  |
| `pmic_top.254.AIM.4` | The switch edge detector fires on the falling edge of the debounced switch (release) instead of the rising edge (press) | not run |  |
| `pmic_top.254.AIM.42` | The switch-press detector fires on any change of the debounced switch (press and release) instead of on the press only | not run |  |
| `pmic_top.263.AIM.223` | soft_start's SS_done handshake is registered once more at the top level before the supervisor, so the end of the ramp is acted on one clock late | not run |  |
| `pmic_top.263.AIM.224` | fault_arbiter's RUN window trip is retimed through a flop before the supervisor to break the counter-compare path, so the S_RUN to S_HICCUP exit lands one clock after the trip | not run |  |
| `pmic_top.264.AIM.178` | The supervisor holds in S_SS after the ramp is done until the live valley-current comparator is clear, treating 'do not hand over to RUN in overcurrent' as a condition of the ramp handshake | not run |  |
| `pmic_top.264.AIM.71` | Supervisor leaves soft start only when the ramp is done and the output comparator also reports the rail in window, as if 'soft start finished' meant 'output is up' | not run |  |
| `pmic_top.266.AIM.14` | Supervisor's enable input takes the switch-press edge pulse en_switch_rise instead of the debounced switch level | not run |  |
| `pmic_top.266.AIM.157` | The supervisor's switch enable is ANDed with the raw synchronised switch, following a 'switch-off must act at once' idea, so only the press is debounced and a release or bounce takes effect immediately | not run |  |
| `pmic_top.266.AIM.57` | Supervisor's enable input takes the synchronised but undebounced switch, bypassing the 20 ms symmetric switch debouncer | not run |  |
| `pmic_top.267.AIM.182` | The supervisor's host enable is ORed with the switch-press pulse at the top level, so a fresh press overrides a host disable on the press clock itself. reg_file already restores spi_enable on the next clock, so the override lands a clock early. | not run |  |
| `pmic_top.268.AIM.1` | Supervisor's latch read-back is wired to the CPLD's own trip drive latch_out instead of the debounced SCR read-back latch_stat_sync_db | not run |  |
| `pmic_top.268.AIM.59` | Supervisor's SCR latch read-back takes the synchronised but undebounced latch_stat, unlike the debounced copy the header routes to it | not run |  |
| `pmic_top.269.AIM.167` | The supervisor's over-temperature input ORs the undebounced synchronised OTP flag with the debounced one ('trip at once, debounce only the release'), so the 1 ms assert qualification no longer applies to the FSM | not run |  |
| `pmic_top.269.AIM.2` | Supervisor's OTP input takes the synchronised but undebounced OTP flag, bypassing input_debounce | not run |  |
| `pmic_top.269.AIM.229` | The supervisor ignores over-temperature during S_HICCUP, on the idea that the cool-down already holds the gate off and the retry will catch it | not run |  |
| `pmic_top.270.AIM.145` | Supervisor's soft-start overcurrent exit takes the live synchronised CP comparator instead of fault_arbiter's soft-start window trip, so the higher soft-start tolerance trip_ss is never applied | not run |  |
| `pmic_top.270.AIM.222` | A completed ramp outranks a soft-start overcurrent trip: window_trip_SS is masked by SS_done at the supervisor, so a same-clock trip hands over to S_RUN instead of hiccuping | not run |  |
| `pmic_top.270.AIM.46` | Supervisor's soft-start overcurrent input is wired to the RUN window trip, so the S_SS -> S_HICCUP exit is driven by a trip that fault_arbiter only raises in S_RUN | not run |  |
| `pmic_top.271.AIM.144` | Supervisor's S_RUN overcurrent exit takes the live synchronised CP comparator instead of fault_arbiter's RUN window trip, so the rolling-window duration filter is bypassed for the FSM | not run |  |
| `pmic_top.271.AIM.70` | Supervisor's S_RUN overcurrent exit is wired to the soft-start window trip window_trip_SS, so a RUN window trip never sends the FSM from S_RUN to S_HICCUP | not run |  |
| `pmic_top.272.AIM.30` | Supervisor's latch_assert input is wired to the debounced SCR read-back instead of strike_counter's own trip latch_out, so the CPLD's strike latch is no longer a hard fault to the FSM | not run |  |
| `pmic_top.273.AIM.219` | The supervisor ignores input undervoltage during soft start, as if input-rail sag from the start-up inrush were expected and had to be blanked | not run |  |
| `pmic_top.273.AIM.58` | Supervisor's UVLO input takes the synchronised but undebounced UVLO flag, so input-rail sags shorter than the 1 ms assert qualification shut the converter down | not run |  |
| `pmic_top.274.AIM.163` | The supervisor's hiccup exit also waits for the synchronised valley-current comparator to clear, 'do not retry into a live overcurrent', although the header says a retry always follows hiccup_done | not run |  |
| `pmic_top.287.AIM.16` | CP_trig goes through the fault-flag input_debounce like OTP and UVLO, though the header says fault_arbiter's rolling window is its only filter | not run |  |
| `pmic_top.287.AIM.170` | fault_arbiter's valley-sample lookback BLANK_CLKS is sized from the LM5106 turn-on shrinkage (7 clocks, 140 ns), as if the blanking had to cover the gate driver's delay, instead of the module's 5-clock (100 ns) default | not run |  |
| `pmic_top.289.AIM.152` | fault_arbiter is handed the RUN trip threshold minus one, as if it tripped on count > trip_run, though it already compares with >= | not run |  |
| `pmic_top.290.AIM.173` | fault_arbiter is handed the soft-start trip threshold minus one, as if it tripped on count > trip_ss, though it already compares with >= | not run |  |
| `pmic_top.290.AIM.181` | fault_arbiter's soft-start trip threshold is floored at the RUN threshold, enforcing the package note that S_SS is 'more tolerant', so a legal host write of trip_ss below trip_run is overridden | not run |  |
| `pmic_top.293.AIM.89` | fault_arbiter's valley-sample cycle boundary is taken from the masked, registered gate PWM_out instead of the synchronised modulator PWM, so each per-cycle CP sample lands one clock after the modulator's turn-on edge | not run |  |
| `pmic_top.293.AIM.94` | fault_arbiter's per-cycle CP sample is taken at high-side turn-off (the falling PWM edge, near peak current) instead of at turn-on (the valley), mixing up which edge ends low-side conduction | not run |  |
| `pmic_top.294.AIM.110` | fault_arbiter's current flag is qualified by the modulator PWM, as if the current comparator were only valid during high-side on-time, though it is a valley comparator sampled in low-side conduction | not run |  |
| `pmic_top.294.AIM.146` | The valley-current comparator is taken as active low (open-drain fault convention) at fault_arbiter, so a low CP_trig counts as an overcurrent cycle | not run |  |
| `pmic_top.294.AIM.60` | fault_arbiter's current flag is wired to the raw CP_trig pin instead of its synchronised copy, while its cycle boundary still comes from the synchronised PWM | not run |  |
| `pmic_top.295.AIM.156` | fault_arbiter's soft-start scope also covers S_HICCUP, as if the cool-down and its soft-start retry were one episode, so the overcurrent windows and the CP history are not cleared during the hiccup | not run |  |
| `pmic_top.295.AIM.177` | fault_arbiter's soft-start scope is limited to the unfinished ramp (S_SS and not SS_done), so on the last S_SS clock it sees neither state active and clears both windows and the CP history | not run |  |
| `pmic_top.295.AIM.45` | fault_arbiter's soft-start gate is wired to the gate-driver enable En, so window_trip_SS is not limited to S_SS and can assert in S_RUN from the frozen soft-start count | not run |  |
| `pmic_top.296.AIM.25` | fault_arbiter's run window is qualified on the gate-driver enable En instead of run_active, so soft-start samples go into the RUN window | not run |  |
| `pmic_top.296.AIM.35` | fault_arbiter's RUN window is enabled by the qualified PGOOD instead of run_active, so overcurrent in S_RUN is only counted while the rail is in regulation | not run |  |
| `pmic_top.300.AIM.190` | hiccup_timer's cool-down counter is sized from the default 5 ms base instead of the largest legal host-written base (HICCUP_BASE_MAX_CLKS), which is the sizing mistake the package warns against | not run |  |
| `pmic_top.300.AIM.221` | The hiccup_done handshake from hiccup_timer is registered once more at the top level before the supervisor, so the cool-down end is acted on one clock late | not run |  |
| `pmic_top.302.AIM.136` | The per-strike doubling of the hiccup cool-down is also applied at the call site, so hiccup_timer gets a base already shifted by strike_level and shifts it again: each strike quadruples the interval instead of doubling it. | not run |  |
| `pmic_top.302.AIM.155` | hiccup_timer is handed hiccup_base minus one, an off-by-one 'fix' for its counter matching at the target, which shortens every cool-down by 2**strike_level clocks | not run |  |
| `pmic_top.303.AIM.132` | hiccup_timer is kept armed through the soft-start retry as well as S_HICCUP, as if cool-down plus re-ramp were one episode, so hiccup_done is not cleared on leaving S_HICCUP for S_SS | not run |  |
| `pmic_top.304.AIM.101` | hiccup_timer is given strike_level minus one, as if the strike count had not already been incremented on entry to S_HICCUP, so each cool-down is half its intended length | not run |  |
| `pmic_top.304.AIM.106` | hiccup_timer is handed strike_level plus one, as if it had to anticipate strike_counter's increment on entry to S_HICCUP, so every cool-down is one doubling longer than the strike count calls for | not run |  |
| `pmic_top.304.AIM.20` | Hiccup back-off is scaled by the configured strike limit max_strikes instead of the current strike_level | not run |  |
| `pmic_top.307.AIM.211` | latch_out is retimed through an extra output flop 'because it drives the SCR gate', though the header says it is driven straight from strike_counter's latch_assert | not run |  |
| `pmic_top.308.AIM.114` | The CPLD's trip drive latch_out is released once the debounced SCR read-back shows the latch set, as if the self-holding SCR needed the drive only until it fired, instead of following strike_counter's set-only latch_assert | not run |  |
| `pmic_top.308.AIM.203` | The debounced over-temperature flag is added as a second CPLD trip source into the shared SCR latch, as if OTP were a hard fault to latch, instead of latch_out following strike_counter's latch_assert alone | not run |  |
| `pmic_top.308.AIM.218` | The CPLD's trip drive latch_out is held on while the debounced SCR read-back is set, as if the gate drive had to sustain the SCR, instead of following strike_counter's latch_assert alone | not run |  |
| `pmic_top.309.AIM.159` | strike_counter is reset whenever the debounced enable switch is off, as if cycling the switch earned a fresh set of strikes, though latch_assert must be cleared only by rst_n together with the physical SCR | not run |  |
| `pmic_top.310.AIM.118` | strike_counter is handed the strike limit minus one, a second off-by-one fix on top of the one strike_counter already makes by comparing with max_strikes-1 | not run |  |
| `pmic_top.310.AIM.236` | strike_counter is given the strike limit plus one, as if MAX_STRIKES counted the hiccups allowed before the latching strike rather than the latching strike itself | not run |  |
| `pmic_top.311.AIM.142` | strike_counter is handed the clean-run target minus one, taking the counter to count from zero to target-1, although it clears strikes when clean_counter equals the target itself | not run |  |
| `pmic_top.312.AIM.96` | strike_counter takes its clean-run cycle boundary from the masked, registered gate PWM_out instead of the synchronised modulator PWM | not run |  |
| `pmic_top.313.AIM.206` | strike_counter counts a strike on the overcurrent window trip itself instead of on entry into S_HICCUP, as if 'a strike' were the trip rather than the hiccup it causes | not run |  |
| `pmic_top.313.AIM.39` | strike_counter counts a strike on every entry into soft start (each retry, and the first power-up) instead of on each entry into S_HICCUP | not run |  |
| `pmic_top.313.AIM.50` | strike_counter counts a strike on every gate-driver shutdown (En falling, or low at reset) instead of on each entry into S_HICCUP | not run |  |
| `pmic_top.313.AIM.86` | strike_counter counts a strike when the hiccup cool-down finishes (hiccup_done) instead of when S_HICCUP is entered | not run |  |
| `pmic_top.314.AIM.19` | strike_counter's clean-run streak is gated on En instead of run_active, so it is not broken by soft-start time | not run |  |
| `pmic_top.314.AIM.29` | strike_counter's clean-run streak is gated on the qualified PGOOD instead of run_active, so 'clean running' is taken to mean 'rail in regulation' | not run |  |
| `pmic_top.315.AIM.200` | strike_counter's clean-run streak is also broken whenever the output comparator reports the rail out of window, so 'fault-free running' is taken to need the rail in regulation as well as no overcurrent window trip. | not run |  |
| `pmic_top.315.AIM.52` | strike_counter breaks its clean-run streak on any CP comparator assertion instead of on the window trip, so 'fault-free' is taken to mean no overcurrent cycle at all | not run |  |
| `pmic_top.319.AIM.126` | soft_start's ramp floor is set from the wanted gate on-time MIN_GATE_ON_NS alone, without the LM5106 turn-on shrinkage, so the floor is 6 clocks instead of 12 | not run |  |
| `pmic_top.319.AIM.231` | soft_start's ramp floor is given the summed floor in nanoseconds (240) without ns_to_clks, so a value in ns is used as a clk count | not run |  |
| `pmic_top.321.AIM.37` | soft_start counts its ramp steps on falling edges of the masked PWM_out instead of the synchronised modulator PWM, so each step lands when pwm_mask truncates the pulse rather than after the pulse ends | not run |  |
| `pmic_top.321.AIM.95` | soft_start counts ramp cycles and widens the ceiling at the PWM turn-on edge instead of after each pulse has ended, so each step lands as a pulse starts | not run |  |
| `pmic_top.322.AIM.168` | soft_start's ramp runs through the hiccup cool-down as well as S_SS, as if cool-down plus retry were one ramp period, so the ceiling keeps widening while the gate driver is off | not run |  |
| `pmic_top.322.AIM.172` | soft_start's ramp branch is enabled only while the ramp is unfinished (ss_active and not SS_done), as if a finished ramp no longer needed the S_SS branch, so on the last S_SS clock it falls into the reset-to-floor branch | not run |  |
| `pmic_top.322.AIM.44` | soft_start's ramp branch is enabled by the gate-driver enable En instead of ss_active, so the ramp and clamp logic also runs through S_RUN | not run |  |
| `pmic_top.323.AIM.48` | soft_start holds its ramped ceiling while PGOOD is asserted instead of while the supervisor is in S_RUN, so 'running' is taken to mean 'rail qualified good' | not run |  |
| `pmic_top.323.AIM.56` | soft_start's hold branch is keyed on its own SS_done ('ramp finished') instead of S_RUN, so once a ramp completes it is never reset to the floor | not run |  |
| `pmic_top.323.AIM.97` | soft_start's hold branch covers S_HICCUP as well as S_RUN, so a hiccup does not reset the ramped ceiling and SS_done to the floor; only S_OFF does | not run |  |
| `pmic_top.325.AIM.180` | soft_start's ramp target is floored at the 75% default ceiling, from the package rule that the digital mask must stay above the analog clamp and never be the primary limiter, so a host-lowered MAX_ON limit is overridden | not run |  |
| `pmic_top.326.AIM.127` | soft_start is handed cycles_per_step minus one, an off-by-one fix applied a second time on top of soft_start's own compare against cycles_per_step-1 | not run |  |
| `pmic_top.326.AIM.239` | The per-strike doubling meant for the hiccup cool-down is also applied to soft_start's ramp rate, so each strike doubles the switching cycles held at every ceiling step of the retry ramp | not run |  |
| `pmic_top.329.AIM.212` | The gate PWM gets a second pin register at the top level for glitch-free output, although pwm_mask's output is already a flop | not run |  |
| `pmic_top.332.AIM.100` | pwm_mask's PWM input is gated by the gate-driver enable En, adding the second logic shutdown path that the header explicitly rules out | not run |  |
| `pmic_top.332.AIM.162` | The valley-current comparator is mistaken for a peak current limit, so pwm_mask's PWM is cut on any clock where CP_trig is high, a cycle-by-cycle limit the design does not have | not run |  |
| `pmic_top.332.AIM.61` | pwm_mask is fed the raw Osc_in pin instead of the synchronised PWM that every other block uses for the cycle | not run |  |
| `pmic_top.333.AIM.103` | In S_RUN, pwm_mask takes its on-time ceiling straight from the host's max_on_limit register instead of the ceiling soft_start ramped to and now holds | not run |  |
| `pmic_top.333.AIM.171` | pwm_mask's on-time ceiling has the LM5106 turn-on shrinkage added at the call site, so the gate on-time is meant to equal the ceiling, but the shrinkage is then counted twice because MIN_ON_COUNTS already includes it | not run |  |
| `pmic_top.350.AIM.107` | MISO is tri-stated outside the read-data phase, following the usual shared-bus SPI slave habit, instead of being driven low as a plain output | not run |  |
| `pmic_top.350.AIM.13` | MISO idles high outside the read-data phase (open-drain pull-up convention) instead of held low | not run |  |
| `pmic_top.350.AIM.138` | MISO is also cut by the unfiltered synchronised CS_n, so read data drops at once on a deselect (or a CS glitch) instead of following spi_slave's S_READ phase on the filtered chip select | not run |  |
| `pmic_top.350.AIM.207` | MISO is retimed through an extra clk flop 'to deglitch it', though the header says both terms are already flops and MISO is driven straight from them | not run |  |
| `pmic_top.350.AIM.85` | MISO is enabled whenever the slave is selected (CS_n low), the usual 4-wire convention, instead of only during the read-data phase (S_READ) | not run |  |
| `pmic_top.352.AIM.129` | spi_slave's 2 ms dead-master SCK idle timeout is converted with ms_to_sw_cycles instead of ms_to_clks, so the slave, which counts clk ticks, times out after 900 clocks (18 us) | not run |  |
| `pmic_top.352.AIM.215` | The dead-master SCK idle timeout is given the 5 s host-silence watchdog interval (WD_TIMEOUT_MS) instead of its own 2 ms | not run |  |
| `pmic_top.353.AIM.158` | spi_slave is held in reset whenever the filtered chip select is high, meant to stop noise on a deselected bus from disturbing it, so a transaction's end at CS rise is erased before the slave can judge it | not run |  |
| `pmic_top.354.AIM.128` | spi_slave's SCK rising edge is taken straight from the unfiltered synchronised SCK, so only the falling edge goes through the glitch filter, as if the filter were needed only on release | not run |  |
| `pmic_top.354.AIM.213` | spi_slave's SCK falling edge is taken straight from the unfiltered synchronised SCK, so only the rising (sampling) edge goes through the glitch filter, as if only the sample edge needed filtering | not run |  |
| `pmic_top.354.AIM.92` | spi_slave is handed the inverted filtered SCK, as if the bus were CPOL=1 (Mode 3) instead of Mode 0, so it samples MOSI on the master's falling SCK edge and shifts MISO on the rising edge | not run |  |
| `pmic_top.355.AIM.117` | Chip-select deassert is taken straight from the unfiltered synchronised CS_n, so only selection goes through the glitch filter, as if 'deselect must be immediate' | not run |  |
| `pmic_top.355.AIM.137` | The slave is selected straight from the unfiltered synchronised CS_n and only the deselect goes through the glitch filter, as if 'selection must be immediate'. | not run |  |
| `pmic_top.355.AIM.98` | spi_enable, the host's CONTROL run-enable for the converter, is mistaken for an SPI-interface enable and gates the slave's chip select, so a host that disables the converter is locked off the bus | not run |  |
| `pmic_top.355.AIM.99` | spi_slave is handed the inverted filtered chip select, as if CS were active high, so the idle bus looks selected and a real transaction looks deselected | not run |  |
| `pmic_top.362.AIM.232` | Register read data is bit-reversed before spi_slave, as if the slave shifted MISO out LSB-first, though the bus is MSB-first | not run |  |
| `pmic_top.369.AIM.225` | spi_slave's combinational rd_first is registered before reg_file as an ordinary strobe, so the read snapshot is taken one clock after the first read byte has already been loaded | not run |  |
| `pmic_top.369.AIM.209` | reg_file is instanced with its two magic key bytes swapped: DISABLE_KEY is set to the write-access value 0xA7 and WRITE_ACCESS_KEY to the disable value 0xD1 | not run |  |
| `pmic_top.370.AIM.166` | reg_file is held in reset while the debounced enable switch is off, as if switching off were a full reset of the host configuration | not run |  |
| `pmic_top.374.AIM.120` | reg_file's write strobe is qualified by spi_integrity_ok, as if only validated bytes should reach the register file, though reg_file stages every data byte and validates later at commit | not run |  |
| `pmic_top.375.AIM.220` | Host write data is bit-reversed before reg_file, as if spi_slave assembled bytes LSB-first, though the bus is MSB-first | not run |  |
| `pmic_top.377.AIM.116` | reg_file's read snapshot of the timestamp is retaken after every read data byte clocked out instead of only on the first data byte of the read | not run |  |
| `pmic_top.377.AIM.214` | reg_file's timestamp snapshot is only taken for reads that begin inside the TIME bank (0x18-0x1A), though rd_first must freeze it at the start of any read | not run |  |
| `pmic_top.378.AIM.125` | reg_file's 'data byte transferred' strobe also counts write data bytes, so a write that releases a byte at 0x20 counts as the host having read the fault record | not run |  |
| `pmic_top.379.AIM.121` | reg_file commits staged writes at the end of any write transaction (integrity_ok or txn_abort), mixing up 'transaction ended' with 'transaction validated' | not run |  |
| `pmic_top.379.AIM.179` | reg_file's commit and discard strobes are qualified by chip select still asserted, though spi_slave raises both only after CS has risen at the end of the transaction | not run |  |
| `pmic_top.380.AIM.122` | reg_file's txn_abort is driven on every write-transaction end, valid or not, as if it only meant 'discard the temporaries now', so the bus-error tally also counts good transactions | not run |  |
| `pmic_top.385.AIM.139` | reg_file's STATUS power-good bit is fed fault_LED's registered pgood_LED copy instead of PGOOD itself, so telemetry lags the changeover by a clock | not run |  |
| `pmic_top.385.AIM.21` | reg_file's status PGOOD bit reports the synchronised output comparator instead of the qualified PGOOD | not run |  |
| `pmic_top.386.AIM.113` | reg_file's SCR latch status bit shows only externally-originated latch trips, masking the read-back whenever the CPLD's own latch_out is driving, as if it were fault_cause's OVP inference | not run |  |
| `pmic_top.386.AIM.140` | reg_file's SCR latch status bit ORs in the CPLD's own trip drive latch_out, as if 'latch set' meant 'either source driving it', instead of reporting the debounced physical read-back alone | not run |  |
| `pmic_top.386.AIM.23` | reg_file's latch status bit reports the CPLD's own trip drive latch_out instead of the SCR latch read-back | not run |  |
| `pmic_top.386.AIM.77` | reg_file's SCR latch status bit takes the synchronised but undebounced latch_stat instead of the debounced copy the supervisor acts on | not run |  |
| `pmic_top.387.AIM.112` | reg_file's enable-switch status bit reports the combined enable (switch AND host CONTROL enable) instead of the physical switch alone | not run |  |
| `pmic_top.387.AIM.36` | reg_file's enable-switch status bit is fed from the gate-driver enable En instead of the debounced switch level | not run |  |
| `pmic_top.387.AIM.64` | reg_file's enable-switch status bit is fed the undebounced synchronised switch instead of the debounced level that gates the supervisor | not run |  |
| `pmic_top.387.AIM.78` | reg_file's enable-switch status bit is fed the switch-press edge pulse en_switch_rise instead of the debounced switch level | not run |  |
| `pmic_top.388.AIM.194` | The switch-press pulse that restores the host enable is ignored while a debounced OTP or UVLO is live, as if a press should only re-enable a board that is able to start. | not run |  |
| `pmic_top.389.AIM.104` | The FAULT_FLAGS current-protection status bit is masked by the gate-driver enable, on the idea that the valley comparator only means something while the stage is switching | not run |  |
| `pmic_top.389.AIM.198` | The FAULT_FLAGS current-protection status bit is masked while the modulator PWM is high, on the idea that the valley comparator only means something during low-side conduction. | not run |  |
| `pmic_top.389.AIM.27` | The FAULT_FLAGS register's current-protection bit reports the RUN overcurrent window trip instead of the live synchronised CP comparator | not run |  |
| `pmic_top.390.AIM.22` | reg_file's over-temperature status bit takes the undebounced OTP flag, unlike the debounced one the supervisor acts on | not run |  |
| `pmic_top.390.AIM.227` | The FAULT_FLAGS over-temperature bit ORs in fault_cause's recorded OTP cause, making the live status flag sticky like the fault record | not run |  |
| `pmic_top.391.AIM.199` | reg_file's UVLO status bit is masked outside S_SS and S_RUN, copying fault_cause's 'a routine power-down asserts UVLO' capture rule into the live status register. | not run |  |
| `pmic_top.391.AIM.63` | reg_file's UVLO status bit reports the undebounced synchronised UVLO flag instead of the debounced copy the supervisor acts on | not run |  |
| `pmic_top.392.AIM.192` | reg_file's STRIKE_LEVEL telemetry is zeroed once the CPLD's strike latch has tripped, copying fault_LED's 'latch outranks strikes' priority into the register map. strike_counter deliberately keeps the count readable after latching. | not run |  |
| `pmic_top.392.AIM.62` | reg_file's strike-level status is fed the configured strike limit max_strikes instead of the accumulated strike_level | not run |  |
| `pmic_top.396.AIM.193` | reg_file's FCOUNT_SS telemetry is gated by S_SS, mirroring the way fault_arbiter gates window_trip_SS by its own state. But the soft-start count is meant to stay frozen, and readable, through S_RUN. | not run |  |
| `pmic_top.397.AIM.226` | FAULT_CAUSE is read through a priority encoder that keeps only the highest set cause bit, from reading 'priority is encoded in bit position' as 'report the top cause only', though the record is a one-hot OR accumulation | not run |  |
| `pmic_top.397.AIM.235` | The one-hot fault-cause record is wired to reg_file bit-reversed, as if bit 0 were the highest-priority cause, so OC appears in the OVP position and OVP in the OC position | not run |  |
| `pmic_top.398.AIM.233` | The free-running timestamp reaches reg_file with its three bytes in reverse order, so TIME_0 at 0x18 holds the most significant byte instead of the least | not run |  |
| `pmic_top.398.AIM.73` | reg_file's live TIME registers are fed fault_cause's episode-start snapshot fault_time instead of the free-running timestamp_ms | not run |  |
| `pmic_top.399.AIM.216` | reg_file's FAULT_TIME registers are given the age of the episode (timestamp_ms minus the episode-start snapshot) instead of the episode-start time itself, reading 'timestamp of the fault' as 'time since the fault' | not run |  |
| `pmic_top.399.AIM.234` | fault_cause's episode-start time reaches reg_file byte-reversed, so FTIME_0 at 0x1E reports the most significant byte | not run |  |
| `pmic_top.421.AIM.108` | pwm_stats measures the synchronised modulator PWM only while the gate driver is enabled, though its block comment says it runs unconditionally because duty and period matter as much during a fault | not run |  |
| `pmic_top.421.AIM.8` | pwm_stats measures the masked PWM_out instead of the synchronised modulator PWM | not run |  |
| `pmic_top.421.AIM.93` | pwm_stats measures the inverted modulator PWM, so DUTY_COUNT reports the low-side (off) time of each cycle instead of the high-side on-time | not run |  |
| `pmic_top.428.AIM.174` | fault_cause is held in reset while the gate driver is disabled, so routine power-downs do not log a fault. This wipes the record on every fault shutdown, which is exactly when it must survive. | not run |  |
| `pmic_top.429.AIM.133` | fault_cause's over-temperature input is qualified by the gate-driver enable, meant as 'only faults that interrupted switching', but the supervisor drops En combinationally on OTP itself | not run |  |
| `pmic_top.429.AIM.65` | fault_cause logs over-temperature from the undebounced synchronised OTP flag instead of the debounced copy the supervisor acts on | not run |  |
| `pmic_top.430.AIM.49` | fault_cause logs the undebounced synchronised UVLO flag instead of the debounced copy the supervisor acts on | not run |  |
| `pmic_top.431.AIM.7` | fault_cause's SCR read-back input is wired to the CPLD's own trip latch_out, so it can no longer tell an external latch from a strike latch | not run |  |
| `pmic_top.431.AIM.74` | fault_cause infers OVP from the synchronised but undebounced SCR read-back instead of the debounced copy the supervisor and LEDs act on | not run |  |
| `pmic_top.432.AIM.38` | fault_cause's latch_assert input is fed from the debounced SCR read-back instead of the CPLD's own trip latch_out, so the OVP inference (latch set with latch_assert clear) can never be true | not run |  |
| `pmic_top.433.AIM.191` | fault_cause's RUN overcurrent input is wired to the soft-start window trip, so both of its overcurrent inputs carry window_trip_SS and a RUN window trip is never logged | not run |  |
| `pmic_top.433.AIM.51` | fault_cause logs the overcurrent cause from the live synchronised CP comparator instead of fault_arbiter's RUN window trip, so a single valley-current excursion counts as an overcurrent fault | not run |  |
| `pmic_top.434.AIM.47` | fault_cause's soft-start overcurrent cause is fed from the RUN window trip, so an overcurrent hiccup out of S_SS is not logged | not run |  |
| `pmic_top.435.AIM.111` | fault_cause's 'converter running' capture scope also covers S_HICCUP, as if the hiccup cool-down were part of the operating episode | not run |  |
| `pmic_top.435.AIM.41` | fault_cause's episode scope is wired to hiccup_active instead of ss_active, so it counts S_HICCUP as running and leaves S_SS out | not run |  |
| `pmic_top.435.AIM.91` | fault_cause's 'converter running' scope takes soft_start's SS_done ('ramp finished') instead of the supervisor's ss_active ('in S_SS'), so faults during the ramp are outside the episode | not run |  |
| `pmic_top.436.AIM.24` | fault_cause's capture gate takes the gate-driver enable En as 'running' instead of the supervisor's run_active, so a hard fault in S_RUN is never logged | not run |  |
| `pmic_top.436.AIM.72` | fault_cause's capture gate takes the qualified PGOOD as 'running' instead of run_active, so a fault in S_RUN before PGOOD has qualified, or during a rail dip, is not logged | not run |  |
| `pmic_top.437.AIM.115` | fault_cause's clear-on-read also fires on spi_abort, as if any transaction that ended unvalidated also closed the fault-log read window, so a failed write wipes the fault record and its start time | not run |  |
| `pmic_top.437.AIM.123` | fault_cause's clear-on-read is also required to come from a CRC-validated transaction, as if the destructive clear needed write-style validation, though reads never produce integrity_ok | not run |  |
| `pmic_top.437.AIM.124` | fault_cause's record is cleared when any read transaction starts (rd_first) as well as after 0x20 is read, taking 'clear on read' to mean 'clear when a read begins' | not run |  |
| `pmic_top.437.AIM.160` | fault_cause's record is also cleared by a fresh press of the enable switch, taking an 'episode' to mean one power-on run instead of one host read window | not run |  |
| `pmic_top.437.AIM.196` | fault_cause's clear-on-read is suppressed while the converter is in S_SS or S_RUN, meant to avoid wiping an episode still in progress. The record and its fault_time then survive a host read that should close the read window. | not run |  |
| `pmic_top.437.AIM.228` | The fault record is also cleared by a write to FAULT_CAUSE (0x1D), applying the write-1-to-clear convention to a register that is read-only and clears on read | not run |  |
| `pmic_top.438.AIM.143` | fault_cause's episode-start snapshot is wired to its own fault_time output instead of the free-running timestamp_ms, a slip between the two adjacent TIMESTAMP_W ports, so the snapshot just reloads the cleared value | not run |  |
| `pmic_top.469.AIM.102` | pgood_gen's qualifying delay is converted with ms_to_clks, as for the debouncers, although pgood_gen counts switching cycles, so the 9 ms qualification becomes 450000 PWM cycles (about 1 s) | not run |  |
| `pmic_top.469.AIM.130` | pgood_gen's qualifying count is set to 2**PGOOD_DELAY_W, following the package's out-of-date note that the counter saturates at all-ones, instead of PGOOD_DELAY_CYCLES | not run |  |
| `pmic_top.469.AIM.17` | PGOOD_comp is debounced before pgood_gen, so the deassert the header requires to be immediate is delayed by the debounce release time | not run |  |
| `pmic_top.469.AIM.230` | pgood_gen's qualifying count is given the delay in milliseconds (PGOOD_DELAY_MS = 9) where it expects switching cycles, so a unit conversion is left out | not run |  |
| `pmic_top.469.AIM.237` | run_active is retimed through a flop before pgood_gen to break the supervisor-to-PGOOD path, so the power-good qualifier lags the FSM by a clock | not run |  |
| `pmic_top.471.AIM.205` | pgood_gen gets the inverted modulator PWM, so it counts its qualifying cycles at high-side turn-on (the cycle boundary fault_arbiter uses) instead of at the end of each pulse | not run |  |
| `pmic_top.471.AIM.90` | pgood_gen counts its qualifying switching cycles on falling edges of the masked gate PWM_out instead of the synchronised modulator PWM | not run |  |
| `pmic_top.472.AIM.150` | The output-rail window comparator is taken as an active-low power-fail output, so pgood_gen is handed its inverted synchronised level | not run |  |
| `pmic_top.472.AIM.201` | pgood_gen treats a live valley-current comparator as 'rail not good', so any CP_trig assertion in S_RUN clears the power-good qualification | not run |  |
| `pmic_top.473.AIM.141` | pgood_gen's 'regulating' qualifier is also ANDed with the gate-driver enable, as if PGOOD had to drop with the combinational fault gating of En rather than when the supervisor leaves S_RUN | not run |  |
| `pmic_top.473.AIM.18` | pgood_gen is qualified on the gate-driver enable En instead of run_active, so soft-start counts as running | not run |  |
| `pmic_top.473.AIM.202` | pgood_gen is qualified on S_RUN with no strikes outstanding, as if the housekeeping rail must not be handed to a converter still proving itself after a hiccup | not run |  |
| `pmic_top.473.AIM.32` | pgood_gen is qualified on soft_start's SS_done ('ramp finished') instead of the supervisor's run_active | not run |  |
| `pmic_top.473.AIM.188` | pgood_gen's 'regulating' qualifier also drops on the RUN window trip. The aim is to hand the rail back the moment an overcurrent is detected, but PGOOD should follow the supervisor's exit from S_RUN. | not run |  |
| `pmic_top.483.AIM.134` | The fault-log timebase prescaler is set with ms_to_sw_cycles(1) instead of the clk-based package value. The timestamp counts clk ticks, so a 'millisecond' tick comes every 450 clocks (9 us) instead of every 50000. | not run |  |
| `pmic_top.483.AIM.210` | The timestamp prescaler is handed PRESCALE_VAL minus one, an off-by-one 'fix' made at the call site although timestamp already compares its prescaler with PRESCALE_VAL-1 | not run |  |
| `pmic_top.485.AIM.153` | The fault-log timestamp is held in reset whenever the gate driver is disabled, reading 'time since start of convertor' as time since the converter was enabled, though the timestamp must free-run in every state and be cleared only by rst_n | not run |  |
| `pmic_top.485.AIM.165` | The fault-log timestamp is restarted each time the host finishes reading the fault record (fault_reg_read_done), taking the timestamp to be time since the last episode, though it must free-run from rst_n | not run |  |
| `pmic_top.491.AIM.135` | The Red_LED1 strike blink half-period is sized in switching cycles (ms_to_sw_cycles(125)), to match the clean-run window it was chosen against. But fault_LED's blink counter counts clk ticks, so it gets 56250 clocks (about 1.1 ms) instead of 125 ms. | not run |  |
| `pmic_top.491.AIM.197` | fault_LED's blink half-period is overridden with the full 250 ms period of the intended 4 Hz blink, so the period is mistaken for the half-period. | not run |  |
| `pmic_top.492.AIM.208` | fault_LED is held in reset while the debounced enable switch is off, as if a switched-off board should show a dark front panel. The LEDs must show what is wrong now, in every state. | not run |  |
| `pmic_top.493.AIM.175` | fault_LED's over-temperature input is gated by 'converter running' like fault_cause's capture gate, though the LEDs show what is wrong now and must light in any state | not run |  |
| `pmic_top.493.AIM.66` | fault_LED's over-temperature indication is fed the undebounced synchronised OTP flag instead of the debounced one | not run |  |
| `pmic_top.494.AIM.186` | fault_LED's UVLO indication is masked unless the converter is in S_SS or S_RUN. This borrows fault_cause's 'a routine power-down asserts UVLO' capture rule, but the LEDs must show what is wrong now, in every state. | not run |  |
| `pmic_top.494.AIM.3` | fault_LED's UVLO indication is fed from the undebounced synchronised UVLO flag instead of the debounced copy the supervisor acts on | not run |  |
| `pmic_top.495.AIM.67` | fault_LED's latch indication takes the CPLD's own trip latch_out instead of the SCR read-back, so an external (OVP) latch trip is not shown | not run |  |
| `pmic_top.495.AIM.79` | fault_LED's latch indication is fed the synchronised but undebounced SCR read-back instead of the debounced copy | not run |  |
| `pmic_top.496.AIM.68` | fault_LED's latch_assert input is fed the debounced SCR read-back instead of strike_counter's latch_out, so the CPLD's own strike latch is not shown until the SCR read-back follows | not run |  |
| `pmic_top.497.AIM.164` | fault_LED shows outstanding strikes only while the supervisor is in S_RUN, taking 'blink through the clean-run window' to mean only that, so Red_LED1 does not blink during the hiccup cool-down or the soft-start retry | not run |  |
| `pmic_top.497.AIM.217` | fault_LED's 'strikes outstanding' is taken to mean strikes remaining before the latch (max_strikes - strike_level) instead of strikes accumulated | not run |  |
| `pmic_top.497.AIM.53` | fault_LED's strikes-outstanding input is wired to the configured strike limit max_strikes instead of the accumulated strike_level | not run |  |
| `pmic_top.498.AIM.189` | The overcurrent window trips are folded into fault_LED's running indication, a second path that fault_LED's header deliberately leaves out because the supervisor's state change already turns off the green LED. | not run |  |
| `pmic_top.498.AIM.204` | fault_LED's running indication is suppressed while strikes are outstanding, so Green_LED is not lit together with the blinking Red_LED1 during the clean-run window | not run |  |
| `pmic_top.498.AIM.40` | fault_LED's soft-start input is wired to soft_start's SS_done ('ramp finished') instead of the supervisor's ss_active ('in S_SS') | not run |  |
| `pmic_top.498.AIM.55` | fault_LED's soft-start input is wired to hiccup_active, so the green 'running' LED covers the hiccup cool-down instead of soft start | not run |  |
| `pmic_top.499.AIM.54` | fault_LED's running input takes the qualified PGOOD instead of run_active, so the green LED treats 'rail in regulation' as 'running' | not run |  |
| `pmic_top.500.AIM.6` | fault_LED's power-good input is wired to the synchronised comparator instead of the qualified PGOOD | not run |  |
| `pmic_top.526.AIM.109` | The housekeeping changeover drive is held on for one extra clock after PGOOD drops, ORed with the registered pgood_LED copy as a glitch hold-off, so the hand-back is no longer immediate | not run |  |
| `pmic_top.526.AIM.31` | switch_supply is driven from the registered pgood_LED indicator copy instead of PGOOD itself, adding a clock to the changeover hand-back | not run |  |
| `pmic_top.526.AIM.43` | The housekeeping changeover drive is gated by the gate-driver enable as well as PGOOD, so it no longer carries the same value as PGOOD | not run |  |
| `pmic_top.526.AIM.5` | switch_supply follows the raw synchronised output comparator instead of the qualified PGOOD from pgood_gen | not run |  |
