# Synchronous buck PMIC supervisor - Silicluster v3 digital project

Project type: **digital**. Top-level module: **`pmic_top`** (`rtl/pmic_top.v`).
Testbench top: **`pmic_top_tb`** (`tb/pmic_top_tb.v`).

## What the design is

The digital supervisor of a 450 kHz synchronous buck converter (10.8-22 V in).
The analog side - modulator, comparators, LM5106 gate driver, an SCR protection
latch - sits off chip. This logic sits between them and decides when the power
stage may switch:

- a four-state supervisor (off, soft start, run, hiccup) that drives the gate
  driver enable and stops on any fault in the same clock it is seen;
- a soft-start ramp that widens a per-cycle on-time ceiling from a minimum
  gate pulse to a 75% duty backstop, and a mask that truncates every PWM pulse
  at that ceiling;
- overcurrent protection: a rolling window of valley-current samples, one per
  switching cycle, with separate thresholds for soft start and run; a hiccup
  cool-down that doubles with each strike; a strike counter that trips the SCR
  latch after three consecutive retries and is cleared by a fault-free run;
- over-temperature, input undervoltage and latch readback, each synchronised
  and debounced; power-good qualification with immediate deassert; status
  LEDs;
- telemetry and control over a 4-wire SPI slave with CRC-8: identity, live
  status, PWM duty and period, fault counters, a timestamped fault log, and
  writable protection thresholds behind a key. This host interface is
  optional: the parameter `TELEMETRY_EN` builds the design with it (the
  default) or without it, and the testbench verifies both (see
  "Configuration" below).

The source is SystemVerilog. These files are its Verilog-2005 conversion
(sv2v), one `.v` per source file with the source folder layout, and with the
comments sv2v discards restored by hand. The package `pmic_types_pkg` is
inlined into every module that uses it, so it has no file of its own; its
constants appear as `pmic_types_pkg_*` localparams.

## Files

```
rtl/pmic_top.v                 top level: synchronisers, debouncers, wiring
rtl/supervisor.v               supervisor FSM and gate-driver enable
rtl/clk_rst/reset_sync.v       reset synchroniser
rtl/inputs/input_sync.v        two-flop synchroniser
rtl/inputs/input_debounce.v    debouncer
rtl/protect/soft_start.v       soft-start ramp
rtl/protect/pwm_mask.v         per-cycle on-time limiter
rtl/protect/fault_arbiter.v    rolling overcurrent windows
rtl/protect/hiccup_timer.v     hiccup cool-down
rtl/protect/strike_counter.v   strike counter and latch trip
rtl/status/pgood_gen.v         power-good qualification
rtl/status/fault_LED.v         status LEDs
rtl/status/timestamp.v         millisecond counter
rtl/telemetry/spi_slave.v      4-wire SPI slave, CRC-8
rtl/telemetry/reg_file.v       register map
rtl/telemetry/fault_cause.v    fault log
rtl/telemetry/pwm_stats.v      PWM duty and period measurement
tb/pmic_top_tb.v               the testbench
```

## Pins

The call provides `clk` and `rst` separately from the 14 inputs and 14 outputs.
This design uses 10 inputs and 11 outputs besides them, and no bidirectional
pins.

| Pin | Dir | Function |
|-----|-----|----------|
| `clk` | in | Supervisor clock, **10 MHz** |
| `rst_n_pin` | in | Reset, **active low**, asynchronous assert, released synchronously inside |
| `SCK` | in | SPI clock (mode 0) |
| `CS_n` | in | SPI chip select, active low |
| `MOSI` | in | SPI data in (master out, slave in) |
| `MISO` | out | SPI data out (master in, slave out): read data during a read, low otherwise |
| `Osc_in` | in | PWM from the analog modulator |
| `CP_trig` | in | Valley-current comparator (overcurrent), high = fault |
| `OTP_trig` | in | Over-temperature comparator, high = fault |
| `UVLO_trig` | in | Input undervoltage comparator, high = fault |
| `latch_stat` | in | SCR protection latch readback, high = latched |
| `PGOOD_comp` | in | Output rail in-window comparator, high = good |
| `en_from_switch` | in | Physical enable switch, high = on |
| `PWM_out` | out | Masked PWM to the LM5106 IN pin |
| `En` | out | LM5106 enable |
| `PGOOD` | out | Power good |
| `latch_out` | out | Trip into the SCR latch after repeated overcurrent |
| `switch_supply` | out | Housekeeping supply changeover drive (same value as PGOOD) |
| `Green_LED` | out | Running, no fault |
| `pgood_LED` | out | Power good |
| `Red_LED1` | out | Solid: latched; blinking: strikes outstanding |
| `Red_LED2` | out | Over-temperature |
| `Red_LED3` | out | Input undervoltage |

There is no bidirectional pin and no tri-state anywhere in the design: `MISO`
is a plain output (`assign MISO = sdio_oe & sdio_out` in `pmic_top.v`), driven
low whenever the chip is not sending read data. Every input is asynchronous to
`clk` and is synchronised on chip.

## Clock and reset

- `clk` must be **10 MHz**, the maximum the call allows. Every time constant
  is derived from it at elaboration (1 ms debounce, 200 us release, 20 ms
  enable-switch debounce, 1 ms timestamp tick, 125 ms LED blink, 1-20 ms hiccup
  base, 2 ms SPI idle timeout); a slower clock stretches all of them in
  proportion.
- `rst_n_pin` is active low. Assertion clears the design immediately;
  release is synchronised to `clk` (two flops). Out of reset the fault inputs
  are treated as faulted until they have been seen healthy for 200 us, and
  every register-map value is at its default.

## Configuration

`TELEMETRY_EN` is a parameter of `pmic_top` (`rtl/pmic_top.v`). One source,
two builds, both verified by the same testbench:

| | `TELEMETRY_EN = 1` (default in these files) | `TELEMETRY_EN = 0` |
|---|---|---|
| Host interface | SPI slave, register map, fault log, timestamp, PWM statistics | none |
| Protection thresholds | defaults, writable over SPI | fixed at the defaults |
| `SCK`, `CS_n`, `MOSI` | used | unused inputs |
| `MISO` | read data during a read, low otherwise | always low |
| Area (below) | about 2.6x the standard slot | about 0.9x the standard slot |

The protection itself - supervisor, soft start, overcurrent windows, hiccup,
strikes and latch, OTP, UVLO, PGOOD, LEDs - is the same logic in both. The
defaults: overcurrent trip after 12 faulted cycles in 16 (28 in 32 during soft
start), 5 ms hiccup base doubling per strike, latch after 3 strikes, strikes
cleared by 1 s of fault-free running, 64 switching cycles per soft-start step.

**If the additional area cannot be granted**, the reduced build can be used
instead: change the default on line 75 of `rtl/pmic_top.v` from
`parameter [0:0] TELEMETRY_EN = 1'b1;` to `1'b0`, or set the parameter to 0 at
synthesis. The testbench takes the same parameter and passes it to `pmic_top`,
so `-P pmic_top_tb.TELEMETRY_EN=0` (Icarus) or `-GTELEMETRY_EN=0` (Verilator)
runs the reduced build with its own test sequence. A self-contained package
of the reduced build sets both defaults to 0: line 75 of `rtl/pmic_top.v` and
the `TELEMETRY_EN` parameter near the top of `tb/pmic_top_tb.v`.

With `TELEMETRY_EN = 1`:

- SPI: mode 0, MSB first, 4-wire (`MOSI` in, `MISO` out). **SCK at most about 250 kHz**
  at a 10 MHz clock (verified rate): the three SPI lines pass through an
  800 ns digital filter, and a read bit leaves the chip about 1.2 us after the
  master's falling edge. Write frame: command byte (bit 7 = 0, address in
  bits 6:0), data bytes, then CRC-8 (polynomial 0x07, initial value 0x00, over
  the command and data bytes). Read frame: command byte (bit 7 = 1), one
  dummy (turnaround) byte, then data bytes on `MISO`; after the command byte
  `MOSI` is ignored.
  The address auto-increments. A write commits only if CS rises on a byte
  boundary after at least three bytes with a good CRC.
- Register map highlights: 0x00 ID (0xB5), 0x01 version, 0x03 scratch, 0x10
  status, 0x11 fault flags, 0x12 strike level, 0x13/0x14 PWM duty/period,
  0x18-0x1A millisecond timestamp, 0x1B/0x1C bus error count, 0x1D-0x20 fault
  log (cleared by reading 0x20), 0x40/0x41 disable key and control, 0x4F write
  key, 0x50-0x5A thresholds (writable after the key 0xA7 at 0x4F in the same
  transaction; out-of-range values are clamped; hiccup base, ramp rate and
  clean-run window only while off).

## Running the testbench

Icarus Verilog, `TELEMETRY_EN = 1` (about two minutes):

```
iverilog -g2005 -o pmic_top_tb.vvp rtl/*.v rtl/*/*.v tb/pmic_top_tb.v
vvp -n pmic_top_tb.vvp
```

Verilator 5, `TELEMETRY_EN = 1` (about 45 seconds):

```
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-ZERODLY \
    --top-module pmic_top_tb rtl/*.v rtl/*/*.v tb/pmic_top_tb.v
./obj_dir/Vpmic_top_tb
```

For the reduced build, `TELEMETRY_EN = 0`, add the parameter at compile time:
`iverilog -g2005 -P pmic_top_tb.TELEMETRY_EN=0 ...` (about four minutes), or
`verilator ... -GTELEMETRY_EN=0 ...` (about 35 seconds). The testbench
passes it to `pmic_top`, so the one setting selects both the design and the
test sequence that fits it.

The `-Wno-*` flags silence width warnings that come from the conversion's
width-cast helper functions, and the testbench's run-time delays; with them the
build is warning-free.

The run prints one line per check, a coverage table, and ends with
`pmic_top_tb: PASS` or `pmic_top_tb: FAIL`; everything is also written to
`pmic_top_tb.log`. Add `+WAVES` to the run command for a VCD. The testbench
finishes with `$finish` on PASS and `$stop` on FAIL; Verilator then exits
non-zero, but Icarus `vvp` exits 0 either way (Verilog-2005 cannot set an exit
code), so a script should test the last line.

## What the testbench does

One Verilog-2005 module. It drives `pmic_top` only through its pins, with
behavioural models around it: an asynchronous 450 kHz modulator, the SCR latch,
comparator levels, the enable switch, and an SPI master with CRC-8. With
`TELEMETRY_EN = 1` every configuration is written over SPI into the register
map, as a host would; no timer in the design was shortened for simulation. The
run covers about 360 ms of simulated time in 13 phases: reset and defaults; the
SPI protocol and register map (single and burst reads and writes, CRC, length
and alignment aborts, the locked bank, clamping, CS dropped mid-read, the SCK
timeout); start-up through the 20 ms switch debounce and the soft-start ramp;
the duty backstop; PGOOD; overcurrent, hiccup and retry; the 100 ms clean-run
window; OTP, UVLO and SCR-latch shutdown and recovery; host disable and enable;
the timestamp snapshot across a carry; strike accumulation to the latch; the
enable switch; a stuck-high modulator.

It checks in four layers:

- **directed checks** - 198, each printing PASS or FAIL;
- **monitors** sampled every clock - `MISO` carrying read data exactly while
  the SPI slave is in its read state and low at every other time, the first read
  bit valid on `MISO` at the start of read data, `switch_supply` equal to
  `PGOOD`, no
  `PGOOD` without `En`, no `PWM_out` pulse above the 75% ceiling, `latch_out`
  never falling without a reset;
- **two scoreboards** compared with the design every clock - a reference model
  of the supervisor FSM (state and `En`), and a shadow of the register map
  built from the bytes sent and the documented rules (keys, deferred enable,
  off-only registers, multi-byte rule, clamps), also checked against every byte
  read back;
- **a coverage table** of 51 bins: every supervisor transition, every fault
  entry and exit path, hiccup retry, strike levels and latch, the strike clear,
  soft-start completion, PGOOD qualification and both ways it drops, and every
  SPI read, write, abort and rejection path. A bin is set only when a monitor
  sees the design reach the condition; any bin left unhit fails the run.

The unavoidable 100 ms clean-run window runs concurrently with 32 seeded
directed-random register transactions, 16 random duty settings and 6 random
sub-debounce glitches. `force` is used twice, only for states no stimulus can
reach: an illegal SPI state encoding, and the 5 s host-silence watchdog.

**What the coverage table means, and what it does not.** It proves the stimulus
arrived: every listed state, transition and path was actually exercised in the
design. It does not prove the design correct the way an assertion or formal
suite does - the directed checks and the scoreboards carry that, and only for
what they compare. The source repository also has module-level SystemVerilog
testbenches with bound SVA assertions, which pass against these same Verilog
files; they are SystemVerilog, so they are not part of this submission.

Results: PASS, 216 checks with 0 failures (the 198 directed checks and 18
end-of-run monitor and scoreboard verdicts) and all 51 bins, on Icarus Verilog
12 and on Verilator 5.052, against these files and against the SystemVerilog
source, with identical check lines between them.

### With `TELEMETRY_EN = 0`

The reduced build has no register map, so the testbench runs a separate
pins-only sequence on the design's default timers, with nothing configured -
about 1.2 s of simulated time, most of it the default 1 s clean-run window.
The phases keep the numbers of the full sequence: reset and fail-safe
outputs; SPI frames with no effect; start-up and the soft-start ramp (64
cycles a step); the duty backstop; PGOOD; overcurrent, a 10 ms first hiccup
(the 5 ms base doubled) and retry; the 1 s clean-run window, concurrent with
the same duty and glitch corners and 48 random SPI frames; OTP, UVLO and
SCR-latch shutdown and recovery; a keyed SPI disable that must change nothing;
OTP during a hiccup; strikes to the latch on the default 10 and 20 ms hiccups;
restart, the enable switch and a stuck-high modulator.

It proves the host interface is truly absent, not just idle: the configuration
the full sequence writes (a 1 ms hiccup base, a 100 ms clean-run window) is
sent as a valid keyed SPI frame, and the hiccup and the window are then timed
at their defaults; keyed disables are sent while running and `En` must never
fall; every bit read back on `MISO` must be 0. The FSM scoreboard and the
monitors run underneath as before. Of the 51 coverage bins, 20 name hardware
this build does not have (host disable, SPI protocol, timestamp, fault log,
bus-error counter, watchdog, PWM statistics) and are reported "n/a"; the other
31 must all be hit.

Results: PASS, 134 checks with 0 failures and all 31 applicable bins, on
Icarus Verilog 12 and on Verilator 5.052, against these files and against the
SystemVerilog source, with identical check lines between them; also at 50 MHz
(Verilator, package clock rebuilt).

## Area

Synthesised with Yosys 0.70 and the sky130_fd_sc_hd typical library
(`synth -flatten`, `dfflibmap`, `abc`), cell area only:

| Build | Flops | Comb cells | Cell area | Die at 57% utilisation | vs 180 x 115 um slot |
|-------|-------|------------|-----------|------------------------|----------------------|
| `TELEMETRY_EN = 1` (default) | 694 | 2,119 | 30,737 um^2 | ~53,900 um^2 | 2.6x |
| `TELEMETRY_EN = 0` (reduced) | 252 | 705 | 10,523 um^2 | ~18,500 um^2 | 0.9x |

These are synthesis estimates, not a layout. Cell area is the sum of the
standard cells' own areas; a placed and routed block also needs room for
wiring, power straps and tap cells, so the die figure assumes the cells fill
57% of it. That 57% is an assumption carried over from an earlier estimate -
it is not a figure from the call or from a place-and-route run - and place and
route sets the real number. For scale: the reduced build fits the standard
slot if the layout reaches at least 51% utilisation; the full build needs about
2.6x the slot at 57% and 3x at 50%.

The full build needs more than the standard slot; additional area is
requested. Almost all of the difference is the host interface - SPI, register
map, fault log, timestamp, PWM statistics - which is what lets the design be
configured and observed remotely, including on the virtual testing platform.
If that area is not available, the reduced build is estimated to fit the
standard slot (see "Configuration").

## Known limitations

- At 10 MHz one clock of on-time is 4.5% duty, so the soft-start ramp has 13
  steps (it would have 71 at 50 MHz) and the minimum gate pulse is 400 ns.
- The overcurrent sample is taken 5 clocks (500 ns) before each PWM rise; at
  the 75% duty ceiling that is close to the start of low-side conduction.
- The fault log's latch bit cannot be set: the strike latch trips in the hiccup
  state, where the fault log does not record. The latch itself, the status bit
  and the LED work.
- Reading 0x20 clears the fault log even in a one-byte read; read 0x1D-0x20 as
  one burst to get the whole record first.
- `MISO` is always driven, low when idle, so sharing the MISO line with other
  SPI devices needs an external buffer. With one device on the bus it does not
  matter.
- With `TELEMETRY_EN = 0` nothing can be configured or read back: the
  thresholds are fixed at their defaults, `SCK`, `CS_n` and `MOSI` are unused
  inputs, `MISO` is constant 0, and the chip is observable only through
  `PWM_out`, `En`, `PGOOD`, `latch_out`, `switch_supply` and the LEDs.

## Participant

Hrishikesh Acharyya. Project: synchronous buck PMIC supervisor (digital).
