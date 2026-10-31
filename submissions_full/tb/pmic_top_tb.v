/*

# Filename:         pmic_top_tb.v

# File Description: Self-checking integration testbench for pmic_top - the
#                   Silicluster v3 submission testbench. Plain Verilog-2005 in
#                   one module, so it runs unchanged against the SystemVerilog
#                   source (Verilator) and against the converted Verilog
#                   (Verilator or Icarus Verilog).
#
#                   Board models sit around the DUT: a free-running 450 kHz
#                   modulator on Osc_in, the SCR protection latch read back on
#                   latch_stat, comparator levels on CP_trig / OTP_trig /
#                   UVLO_trig / PGOOD_comp, the enable switch, and an SPI master
#                   with CRC-8 on SCK / CS_n / MOSI / MISO. Every configuration the run
#                   needs is written over SPI into the register map, as a host
#                   would; no timer in the RTL is shortened.
#
#                   TELEMETRY_EN: the same parameter as pmic_top's, passed down to
#                   the DUT, so one setting selects both the build and the test
#                   sequence that fits it:
#                     1 (default) the full build. The sequence below configures
#                       short timers over SPI and checks the host interface too.
#                     0 the reduced build: no SPI slave, register file, fault
#                       log, timestamp or PWM statistics; MISO tied low. A
#                       pins-only sequence runs instead, on the package default
#                       timers (5 ms hiccup base, 1 s clean-run window), and
#                       proves SPI frames have no effect. Phases 2, 3 and 10
#                       have no counterpart there; the others keep their numbers.
#                   Set it with  iverilog -P pmic_top_tb.TELEMETRY_EN=0  or
#                   verilator -GTELEMETRY_EN=0, or by editing the default below.
#                   The synthesised configuration is pmic_top's own default, so
#                   a submission must set both to the same value.
#
#                   Checking happens in four layers:
#                     check tasks   every directed claim prints PASS or FAIL
#                     monitors      run-long invariants, sampled every clock
#                     scoreboards   a reference model of the supervisor FSM and a
#                                   shadow of the register map, each compared
#                                   with the DUT every clock
#                     coverage      one flag per bin, set only when a monitor sees
#                                   the DUT reach the condition; any unhit bin
#                                   fails the run
#
#                   What the coverage table is and is not: it proves the stimulus
#                   ARRIVED - every listed transition, fault path and SPI path
#                   was actually exercised in the DUT. It does not prove the
#                   design correct the way an assertion or formal suite does. The
#                   checks and the scoreboards carry that weight, and only for
#                   what they compare.
#
#                   Phases, in order:
#                     1  reset, fail-safe outputs, identity, register defaults
#                     2  SPI protocol and register map: single and burst writes
#                        and reads, CRC, length and alignment aborts, locked
#                        bank, clamping, CS dropped mid-read, SCK timeout, an
#                        illegal SPI state forced and recovered
#                     3  host configures a short hiccup base and clean window
#                     4  enable switch, soft-start ramp, duty backstop, PWM
#                        pass-through, PWM statistics
#                     5  PGOOD qualification, immediate drop, re-qualification
#                     6  overcurrent in S_RUN, hiccup, retry, fault log
#                     7  clean-run window, run CONCURRENTLY with directed-random
#                        register traffic, duty corners and glitch corners
#                     8  OTP and UVLO shutdown and recovery, UVLO in soft start
#                     9  host disable and enable, host-silence watchdog (forced
#                        time), OTP during a hiccup cool-down
#                     10 timestamp burst across the 255 -> 256 ms carry
#                     11 analog OVP trip of the SCR, reset-button recovery
#                     12 strike accumulation to latch, no restart, recovery
#                     13 restart after a latch, enable switch off and on, a
#                        modulator stuck high
#                     14 reset while running (with telemetry, mid-transaction)
#                     15 every fault from every state it can arrive in
#                     16 the overcurrent window's exact threshold
#                     17 a second strike inside the clean-run window (the
#                        pins-only sequence does this in its phase 7)
#                     18 UVLO and latch glitches, switch chatter, overlapping
#                        faults, strikes kept across a fault
#                     19 programmed thresholds reach the protection (telemetry)
#                     20 SPI corners: read-only, unmapped, wrap, glitches
#
#                   Internal probes. Stimulus enters through pins only. The
#                   checks read some DUT internals hierarchically where the
#                   claim is about internal timing no pin shows: the SPI slave's
#                   sdio_oe and state, the filtered CS, the millisecond counter,
#                   the supervisor's state and inputs (for the FSM scoreboard)
#                   and the register-file contents (for the register-map
#                   scoreboard). All names exist in both the SystemVerilog source
#                   and the sv2v output, which keeps generate-block names. The
#                   probes into the SPI slave and register file exist only when
#                   TELEMETRY_EN = 1, so they sit in a generate block; with
#                   TELEMETRY_EN = 0 they are tied to the values those blocks
#                   would hold at rest, and the monitors that read them become
#                   checks that MISO never leaves 0.
#
#                   force/release is used twice, only where a state is otherwise
#                   unreachable: an illegal spi_slave state encoding, and the
#                   5 s host-silence watchdog, which would need 50 million clocks.
#
#                   Directed-random corners use a seeded xorshift32 generator in
#                   this file rather than $random. Verilator's $random does not
#                   reproduce the IEEE 1364 sequence, so a local generator gives
#                   Verilator and Icarus identical stimulus and the SV and
#                   converted runs stay comparable transaction for transaction.
#
#                   CLK_HZ is a parameter so the same file runs at 10 MHz (the
#                   submission) and at 50 MHz (with the package rebuilt at
#                   50 MHz); every expectation derives from it.
#
#                   Exit status: $finish on PASS, $stop on FAIL. Verilator exits
#                   non-zero on $stop. Icarus vvp does not, so the Makefile turns
#                   the verdict line into the exit status for that simulator.
#                   Everything printed also goes to pmic_top_tb.log.

# Global variables: checks_run, checks_failed, cov, cov_hits, the scoreboard
#                   counters and rng - written from tasks and monitors across
#                   the file, shared state within this module.

*/
`timescale 1ns/1ps
`default_nettype none

module pmic_top_tb;

// ============================================================
// Timing - mirrors pmic_types_pkg, since Verilog-2005 cannot import a package
// ============================================================
// CLK_HZ: supervisor clock. Must equal pmic_types_pkg::CLK_HZ of the build
//         under test; override for a 50 MHz build.
parameter integer CLK_HZ = 10_000_000;
// TELEMETRY_EN: configuration under test, passed to pmic_top (see the header).
//               1 = full build and the SPI sequence, 0 = reduced build and the
//               pins-only sequence.
parameter [0:0] TELEMETRY_EN = 1'b1;
// CLK_PERIOD_NS: real division, so a clock that does not divide 1e9 exactly
//                is still generated at the right rate
localparam real    CLK_PERIOD_NS   = 1.0e9 / CLK_HZ;
// SW_PERIOD_NS: 450 kHz modulator period, 2222.2 ns. Not a multiple of the
//               clock, so Osc_in is genuinely asynchronous to clk.
localparam real    SW_PERIOD_NS    = 1.0e9 / 450_000.0;
localparam integer CLKS_PER_SW     = CLK_HZ / 450_000;
// MAX_ON_COUNTS / MIN_ON_COUNTS: duty_to_counts(75) and the rounded-up
//                                ns_to_clks(128 + 112 ns) of the package
localparam integer MAX_ON_COUNTS   = (CLKS_PER_SW * 75) / 100;
localparam integer MIN_ON_COUNTS   = (((CLK_HZ / 1_000_000) * 240) + 999) / 1000;
// Register-map reset values and clamp ranges, package and reg_file constants
localparam integer TRIP_RUN_DEF    = 12;
localparam integer TRIP_SS_DEF     = 28;
localparam integer WINDOW_RUN      = 16;
localparam integer WINDOW_SS       = 32;
localparam integer MAX_STRIKES_DEF = 3;
localparam integer CYC_STEP_DEF    = 64;
localparam integer CYC_STEP_MAX    = 64;
localparam integer HICCUP_DEF      = (CLK_HZ / 1000) * 5;
localparam integer HICCUP_MIN      = (CLK_HZ / 1000) * 1;
localparam integer HICCUP_MAX      = (CLK_HZ / 1000) * 20;
localparam integer CLEAN_DEF       = 450_000;
// CLEAN_SHORT: CLEAN_RUN_MIN_CYCLES, 100 ms of switching cycles - the shortest
//              clean-run window the register map accepts. Phase 7 overlaps it
//              with other work rather than waiting it out.
localparam integer CLEAN_SHORT     = 45_000;
// CLEAN_MAX: top of the 19-bit clean-run register
localparam integer CLEAN_MAX       = 524_287;
localparam integer PGOOD_CYCLES    = 4050;
localparam real    MS              = 1.0e6;
localparam real    US              = 1.0e3;
// SPI_HALF_NS: SCK half-period, 250 kHz. At 10 MHz the slave sees SCK through
//              2 synchroniser and 8 filter clocks, about 1.2 us, so a read bit
//              leaves the slave that long after the master's falling edge; 2 us
//              leaves 0.8 us of setup at the master's sampling edge.
localparam real    SPI_HALF_NS     = 2000.0;
localparam real    SPI_GAP_NS      = 6000.0;
// WATCHDOG_NS: the full run is about 0.9 s of simulated time; the pins-only
//              run about 1.6 s, most of it the default 1 s clean-run window
localparam real    WATCHDOG_NS     = (TELEMETRY_EN ? 1500.0 : 2600.0) * MS;
// SCR_DELAY_NS: SCR latch and readback path
localparam real    SCR_DELAY_NS    = 500.0;
// OSC_PHASE_NS: start offset of the modulator. Half its period is 1111.111 ns,
//               and nine half-periods round to exactly 10 us at 1 ps
//               precision - a clock edge. An Osc_in edge at the same instant as
//               a clock edge is sampled in an order the language leaves to the
//               simulator, so Verilator and Icarus would disagree by a clock.
//               The offset keeps every modulator edge at least ~0.5 ns from a
//               clock edge at 10 and 50 MHz.
localparam real    OSC_PHASE_NS    = 37.3;
// LFSR_SEED: fixed, so every run sees the same directed-random corners
localparam [31:0]  LFSR_SEED       = 32'h1D5E_A5E1;

// Register addresses (reg_file.sv)
localparam [6:0] A_ID = 7'h00, A_VERSION = 7'h01, A_CAPABILITY = 7'h02, A_SCRATCH = 7'h03;
localparam [6:0] A_STATUS = 7'h10, A_FLAGS = 7'h11, A_STRIKE = 7'h12, A_DUTY = 7'h13;
localparam [6:0] A_TIME0 = 7'h18, A_BUSERR_L = 7'h1B, A_FCAUSE = 7'h1D, A_FTIME2 = 7'h20;
localparam [6:0] A_DISKEY = 7'h40, A_CONTROL = 7'h41, A_WRKEY = 7'h4F;
localparam [6:0] A_TRIP_RUN = 7'h50, A_TRIP_SS = 7'h51, A_MAX_STRIKES = 7'h52, A_MAX_ON = 7'h53;
localparam [6:0] A_HICCUP0 = 7'h54, A_CYC_STEP = 7'h57, A_CLEAN0 = 7'h58, A_CLEAN2 = 7'h5A;
localparam [7:0] WRITE_KEY = 8'hA7, DISABLE_KEY = 8'hD1;
// Supervisor states (STATUS[1:0] and the FSM register)
localparam [1:0] ST_OFF = 2'd0, ST_SS = 2'd1, ST_RUN = 2'd2, ST_HICCUP = 2'd3;
// spi_slave states
localparam [2:0] SPI_IDLE = 3'd0, SPI_CMD = 3'd1, SPI_WRITE = 3'd2, SPI_TURN = 3'd3;
localparam [2:0] SPI_READ = 3'd4, SPI_DEAD = 3'd5;
// Why the supervisor last went to S_OFF, as seen by the FSM scoreboard
localparam [2:0] CAUSE_NONE = 3'd0, CAUSE_OTP = 3'd1, CAUSE_UVLO = 3'd2, CAUSE_OVP = 3'd3;
localparam [2:0] CAUSE_STRIKE = 3'd4, CAUSE_HOST = 3'd5, CAUSE_SWITCH = 3'd6, CAUSE_RESET = 3'd7;


// ============================================================
// Board signals
// ============================================================
// Inputs start at their inactive level and are driven active later, so an
// async clear in the DUT sees a real edge rather than x -> 0.
reg  clk            = 1'b0;
reg  rst_n_pin      = 1'b1;
reg  SCK            = 1'b0;
reg  CS_n           = 1'b1;
reg  CP_trig        = 1'b0;
reg  OTP_trig       = 1'b0;
reg  UVLO_trig      = 1'b0;
reg  PGOOD_comp     = 1'b0;
reg  en_from_switch = 1'b0;
reg  Osc_in         = 1'b0;
// MOSI: driven by the SPI master. MISO: driven by the DUT.
reg  MOSI           = 1'b0;
wire MISO;
wire latch_stat;
wire PWM_out, En, PGOOD, latch_out, switch_supply;
wire Green_LED, pgood_LED, Red_LED1, Red_LED2, Red_LED3;

integer checks_run    = 0;
integer checks_failed = 0;


// ============================================================
// DUT
// ============================================================
pmic_top #(.TELEMETRY_EN(TELEMETRY_EN)) u_dut (
    .clk(clk), .rst_n_pin(rst_n_pin),
    .SCK(SCK), .CS_n(CS_n), .MOSI(MOSI), .MISO(MISO),
    .Osc_in(Osc_in), .CP_trig(CP_trig), .OTP_trig(OTP_trig), .UVLO_trig(UVLO_trig),
    .latch_stat(latch_stat), .PGOOD_comp(PGOOD_comp), .en_from_switch(en_from_switch),
    .PWM_out(PWM_out), .En(En), .PGOOD(PGOOD), .latch_out(latch_out),
    .switch_supply(switch_supply),
    .Green_LED(Green_LED), .pgood_LED(pgood_LED),
    .Red_LED1(Red_LED1), .Red_LED2(Red_LED2), .Red_LED3(Red_LED3));

// ---- internal probes (see the file header for why each exists) ----
// SPI slave and its filtered CS and strobes (all assigned in g_tel_probes below)
wire [2:0]  spi_state_int;
wire        sdio_oe_int;
wire        sdio_out_int;
wire        tx_shift7_int;
wire        cs_filt_int;
wire        integrity_int;
wire        abort_int;
wire        rd_first_int;
// millisecond counter and its read snapshot (g_tel_probes)
wire [23:0] ts_live_int;
wire [23:0] ts_snap_int;
// supervisor state and every input it decides on
wire        dut_rst_n      = u_dut.rst_n;
wire [1:0]  sup_state      = u_dut.u_supervisor.state;
wire        sup_en_sw      = u_dut.u_supervisor.en_SW;
wire        sup_spi_en     = u_dut.u_supervisor.spi_enable;
wire        sup_otp        = u_dut.u_supervisor.OTP;
wire        sup_uvlo       = u_dut.u_supervisor.UVLO;
wire        sup_latch_st   = u_dut.u_supervisor.latch_state;
wire        sup_latch_as   = u_dut.u_supervisor.latch_assert;
wire        sup_trip       = u_dut.u_supervisor.window_trip;
wire        sup_trip_ss    = u_dut.u_supervisor.window_trip_SS;
wire        sup_ss_done    = u_dut.u_supervisor.SS_done;
wire        sup_hic_done   = u_dut.u_supervisor.hiccup_done;
// status nets in pmic_top
wire [1:0]  strike_int     = u_dut.strike_level;
wire        run_active_int = u_dut.run_active;
wire        ss_active_int  = u_dut.ss_active;
wire [7:0]  max_on_cnt_int = u_dut.max_on_counts;
wire        osc_sync_int   = u_dut.Osc_sync;
wire        otp_sync_int   = u_dut.OTP_sync;
wire        otp_db_int     = u_dut.OTP_sync_db;
wire        latch_db_int   = u_dut.latch_stat_sync_db;
wire        uvlo_sync_int  = u_dut.UVLO_sync;
wire        uvlo_db_int    = u_dut.UVLO_sync_db;
wire        latch_sync_int = u_dut.latch_stat_sync;
wire [4:0]  fcount_run_int = u_dut.fault_count_run;
wire        sw_rise_int;      // this and the next: g_tel_probes
wire        flog_clear_int;
// register file contents, for the register-map scoreboard (g_tel_probes)
wire [7:0]  rf_scratch, rf_trip_run, rf_trip_ss, rf_max_strikes, rf_max_on, rf_cyc_step;
wire [23:0] rf_hiccup, rf_clean;
wire        rf_spi_enable, rf_write_rej, rf_wd_restored;
wire [15:0] rf_bus_err;

// The SPI slave, the register file and their conditioning exist only with
// TELEMETRY_EN = 1, so the probes into them are built only then - including
// the top-level nets those blocks drive, which the reduced build declares but
// leaves undriven. Without them each probe holds the value its block would
// hold at rest: CS high, slave idle and not driving, no strobes, registers at
// their package defaults.
generate
    if (TELEMETRY_EN) begin : g_tel_probes
        assign cs_filt_int    = u_dut.cs_n_filt;
        assign integrity_int  = u_dut.spi_integrity_ok;
        assign abort_int      = u_dut.spi_abort;
        assign rd_first_int   = u_dut.spi_rd_first;
        assign ts_live_int    = u_dut.timestamp_ms;
        assign sw_rise_int    = u_dut.en_switch_rise;
        assign flog_clear_int = u_dut.fault_reg_read_done;
        assign spi_state_int  = u_dut.g_telemetry.u_spi_slave.spi_state;
        assign sdio_oe_int    = u_dut.g_telemetry.u_spi_slave.sdio_oe;
        assign sdio_out_int   = u_dut.g_telemetry.u_spi_slave.sdio_out;
        assign tx_shift7_int  = u_dut.g_telemetry.u_spi_slave.tx_shift[7];
        assign ts_snap_int    = u_dut.g_telemetry.u_reg_file.timestamp_snap;
        assign rf_scratch     = u_dut.g_telemetry.u_reg_file.scratch_r;
        assign rf_trip_run    = u_dut.g_telemetry.u_reg_file.trip_run;
        assign rf_trip_ss     = u_dut.g_telemetry.u_reg_file.trip_ss;
        assign rf_max_strikes = u_dut.g_telemetry.u_reg_file.max_strikes;
        assign rf_max_on      = u_dut.g_telemetry.u_reg_file.max_on_limit;
        assign rf_hiccup      = u_dut.g_telemetry.u_reg_file.hiccup_base;
        assign rf_cyc_step    = u_dut.g_telemetry.u_reg_file.cycles_per_step;
        assign rf_clean       = u_dut.g_telemetry.u_reg_file.clean_run_target;
        assign rf_spi_enable  = u_dut.g_telemetry.u_reg_file.spi_enable;
        assign rf_write_rej   = u_dut.g_telemetry.u_reg_file.write_rejected;
        assign rf_bus_err     = u_dut.g_telemetry.u_reg_file.bus_err_count;
        assign rf_wd_restored = u_dut.g_telemetry.u_reg_file.wd_restored;
    end
    else begin : g_notel_probes
        assign cs_filt_int    = 1'b1;
        assign integrity_int  = 1'b0;
        assign abort_int      = 1'b0;
        assign rd_first_int   = 1'b0;
        assign ts_live_int    = 24'd0;
        assign sw_rise_int    = 1'b0;
        assign flog_clear_int = 1'b0;
        assign spi_state_int  = SPI_IDLE;
        assign sdio_oe_int    = 1'b0;
        assign sdio_out_int   = 1'b0;
        assign tx_shift7_int  = 1'b0;
        assign ts_snap_int    = 24'd0;
        assign rf_scratch     = 8'h00;
        assign rf_trip_run    = TRIP_RUN_DEF[7:0];
        assign rf_trip_ss     = TRIP_SS_DEF[7:0];
        assign rf_max_strikes = MAX_STRIKES_DEF[7:0];
        assign rf_max_on      = MAX_ON_COUNTS[7:0];
        assign rf_hiccup      = HICCUP_DEF[23:0];
        assign rf_cyc_step    = CYC_STEP_DEF[7:0];
        assign rf_clean       = CLEAN_DEF[23:0];
        assign rf_spi_enable  = 1'b1;
        assign rf_write_rej   = 1'b0;
        assign rf_bus_err     = 16'd0;
        assign rf_wd_restored = 1'b0;
    end
endgenerate


/*
Purpose:
---
Free-running supervisor clock. Generates the clock and nothing else.
*/
always #(CLK_PERIOD_NS / 2.0) clk = ~clk;


// ============================================================
// Logging - every line goes to the terminal and to pmic_top_tb.log
// ============================================================
// log_fd: no declaration initialiser. The sequence opens the log at time 0, and
//         Verilog-2005 leaves the order of a declaration initialiser and an
//         initial block at time 0 to the simulator - Icarus runs a generate
//         block's initial first - so an "= 0" here could close the log again.
//         Until the open, an x (Icarus) or 0 (Verilator) both skip the writes.
integer       log_fd;
reg [8*240:1] msg;       // message buffer of the stimulus thread and its tasks; monitors
                         // print directly, so no two processes share it

task emit(input [8*240:1] text);
    begin
        $display("%0s", text);
        if (log_fd != 0) $fdisplay(log_fd, "%0s", text);
    end
endtask

task note(input [8*120:1] text);
    begin
        $sformat(msg, "[%12.3f us] ----  %0s", $realtime / US, text);
        emit(msg);
    end
endtask


// ============================================================
// Check tasks - every check prints a verdict and is counted
// ============================================================
task check(input [8*96:1] label, input condition);
    begin
        checks_run = checks_run + 1;
        if (condition === 1'b1)
            $sformat(msg, "[%12.3f us] PASS  %0s", $realtime / US, label);
        else begin
            checks_failed = checks_failed + 1;
            $sformat(msg, "[%12.3f us] FAIL  %0s", $realtime / US, label);
        end
        emit(msg);
    end
endtask

task check_eq(input [8*96:1] label, input integer got, input integer expected);
    begin
        checks_run = checks_run + 1;
        if (got == expected)
            $sformat(msg, "[%12.3f us] PASS  %0s = %0d (0x%0h)", $realtime / US, label, got, got);
        else begin
            checks_failed = checks_failed + 1;
            $sformat(msg, "[%12.3f us] FAIL  %0s = %0d (0x%0h), expected %0d (0x%0h)",
                     $realtime / US, label, got, got, expected, expected);
        end
        emit(msg);
    end
endtask

task check_range(input [8*96:1] label, input real got, input real lo, input real hi);
    begin
        checks_run = checks_run + 1;
        if ((got >= lo) && (got <= hi))
            $sformat(msg, "[%12.3f us] PASS  %0s = %0.1f in [%0.1f, %0.1f]",
                     $realtime / US, label, got, lo, hi);
        else begin
            checks_failed = checks_failed + 1;
            $sformat(msg, "[%12.3f us] FAIL  %0s = %0.1f, expected [%0.1f, %0.1f]",
                     $realtime / US, label, got, lo, hi);
        end
        emit(msg);
    end
endtask


// ============================================================
// Coverage - one flag per bin, set only by a monitor or task that sees the DUT
// reach the condition. Any bin left unhit fails the run.
// ============================================================
localparam integer C_OFF_SS     = 0,  C_SS_RUN     = 1,  C_SS_HIC     = 2,  C_SS_OFF     = 3;
localparam integer C_RUN_HIC    = 4,  C_RUN_OFF    = 5,  C_HIC_SS     = 6,  C_HIC_OFF    = 7;
localparam integer C_OFF_OTP    = 8,  C_OFF_UVLO   = 9,  C_OFF_OVP    = 10, C_OFF_STRIKE = 11;
localparam integer C_OFF_HOST   = 12, C_OFF_SWITCH = 13, C_RE_OTP     = 14, C_RE_UVLO    = 15;
localparam integer C_RE_HOST    = 16, C_RE_SWITCH  = 17, C_RE_RESET   = 18, C_STRIKE1    = 19;
localparam integer C_STRIKE2    = 20, C_STRIKE3    = 21, C_STRIKE_CLR = 22, C_RAMP_TOP   = 23;
localparam integer C_PG_QUAL    = 24, C_PG_COMP    = 25, C_PG_RUN     = 26, C_BACKSTOP   = 27;
localparam integer C_PASS       = 28, C_GLITCH     = 29, C_BLINK      = 30, C_SOLID      = 31;
localparam integer C_RD_SINGLE  = 32, C_RD_BURST   = 33, C_WR_COMMIT  = 34, C_WR_BURST   = 35;
localparam integer C_AB_CRC     = 36, C_AB_ALIGN   = 37, C_AB_SHORT   = 38, C_REJ_LOCK   = 39;
localparam integer C_REJ_OFF    = 40, C_CLAMP      = 41, C_CS_MIDRD   = 42, C_SCK_TMO    = 43;
localparam integer C_SPI_ILLEG  = 44, C_TS_CARRY   = 45, C_FLOG_CLR   = 46, C_BUS_ERR    = 47;
localparam integer C_WATCHDOG   = 48, C_STATS      = 49, C_STUCK      = 50;
// second pass: each fault cause crossed with the state it arrives in (laid
// out S_SS, S_RUN, S_HICCUP per cause), then the new scenarios
localparam integer C_X_OTP_SS   = 51, C_X_OTP_RUN  = 52, C_X_OTP_HIC  = 53;
localparam integer C_X_UVLO_SS  = 54, C_X_UVLO_RUN = 55, C_X_UVLO_HIC = 56;
localparam integer C_X_OVP_SS   = 57, C_X_OVP_RUN  = 58, C_X_OVP_HIC  = 59;
localparam integer C_X_SW_SS    = 60, C_X_SW_RUN   = 61, C_X_SW_HIC   = 62;
localparam integer C_X_HOST_SS  = 63, C_X_HOST_RUN = 64, C_X_HOST_HIC = 65;
localparam integer C_X_STRK_HIC = 66;
localparam integer C_WIN_HOLD   = 67, C_WIN_EXACT  = 68, C_ESC2       = 69, C_CLEAN_RESTART = 70;
localparam integer C_SW_CHATTER = 71, C_UVLO_GLITCH = 72, C_LATCH_GLITCH = 73, C_OVERLAP = 74;
localparam integer C_RST_RUN    = 75, C_STRK_PERSIST = 76;
localparam integer C_REG_TRIP_RUN = 77, C_REG_TRIP_SS = 78, C_REG_STRIKES = 79, C_REG_MAX_ON = 80;
localparam integer C_REG_CYC    = 81, C_SPI_GLITCH = 82, C_SPI_WRAP   = 83, C_SPI_RST    = 84;
localparam integer C_SPI_RO     = 85;
localparam integer NB           = 86;

reg  [NB-1:0] cov = {NB{1'b0}};
integer       cov_hits [0:NB-1];
integer       cov_missed = 0;
integer       cov_applicable = NB;   // bins that exist in the build under test
integer       cov_idx;

// cov_applies: whether a bin exists in the build under test. Without telemetry
//              there is no host disable, SPI protocol, register map,
//              timestamp, fault log, bus-error counter, watchdog or PWM
//              statistics: 32 of the 86 bins name hardware that is not built,
//              and they are reported "n/a".
function cov_applies(input integer bin);
    begin
        if (TELEMETRY_EN) cov_applies = 1'b1;
        else cov_applies = !((bin == C_OFF_HOST) || (bin == C_RE_HOST) ||
                             ((bin >= C_RD_SINGLE) && (bin <= C_STATS)) ||
                             ((bin >= C_X_HOST_SS) && (bin <= C_X_HOST_HIC)) ||
                             (bin >= C_REG_TRIP_RUN));
    end
endfunction

// xbin: the cross bin of a fault cause from a source state
function integer xbin(input integer base, input [1:0] from);
    xbin = base + ((from == ST_SS) ? 0 : ((from == ST_RUN) ? 1 : 2));
endfunction

/*
Purpose:
---
Zero the per-bin hit counters before anything can set a bin.
*/
initial for (cov_idx = 0; cov_idx < NB; cov_idx = cov_idx + 1) cov_hits[cov_idx] = 0;

// cover_bin: automatic, because monitors call it from several processes
task automatic cover_bin(input integer bin);
    begin
        cov[bin]      = 1'b1;
        cov_hits[bin] = cov_hits[bin] + 1;
    end
endtask

function [8*56:1] cov_name(input integer bin);
    begin
        case (bin)
            C_OFF_SS:     cov_name = "FSM   S_OFF -> S_SS";
            C_SS_RUN:     cov_name = "FSM   S_SS -> S_RUN (soft start complete)";
            C_SS_HIC:     cov_name = "FSM   S_SS -> S_HICCUP (overcurrent in ramp)";
            C_SS_OFF:     cov_name = "FSM   S_SS -> S_OFF (fault in ramp)";
            C_RUN_HIC:    cov_name = "FSM   S_RUN -> S_HICCUP (overcurrent)";
            C_RUN_OFF:    cov_name = "FSM   S_RUN -> S_OFF";
            C_HIC_SS:     cov_name = "FSM   S_HICCUP -> S_SS (hiccup retry)";
            C_HIC_OFF:    cov_name = "FSM   S_HICCUP -> S_OFF";
            C_OFF_OTP:    cov_name = "off   by over-temperature";
            C_OFF_UVLO:   cov_name = "off   by input undervoltage";
            C_OFF_OVP:    cov_name = "off   by SCR latched from analog OVP";
            C_OFF_STRIKE: cov_name = "off   by strike latch (latch_assert)";
            C_OFF_HOST:   cov_name = "off   by host disable over SPI";
            C_OFF_SWITCH: cov_name = "off   by enable switch released";
            C_RE_OTP:     cov_name = "on    restart after OTP clears";
            C_RE_UVLO:    cov_name = "on    restart after UVLO clears";
            C_RE_HOST:    cov_name = "on    restart on host enable";
            C_RE_SWITCH:  cov_name = "on    restart on enable switch";
            C_RE_RESET:   cov_name = "on    restart after a latch, by reset only";
            C_STRIKE1:    cov_name = "strk  strike level 1";
            C_STRIKE2:    cov_name = "strk  strike level 2";
            C_STRIKE3:    cov_name = "strk  strike level 3 (latch)";
            C_STRIKE_CLR: cov_name = "strk  strikes cleared by clean-run window";
            C_RAMP_TOP:   cov_name = "ss    ramp reached the MAX_ON ceiling";
            C_PG_QUAL:    cov_name = "pg    PGOOD qualified";
            C_PG_COMP:    cov_name = "pg    PGOOD dropped by the comparator";
            C_PG_RUN:     cov_name = "pg    PGOOD dropped by leaving S_RUN";
            C_BACKSTOP:   cov_name = "pwm   duty backstop truncated a pulse";
            C_PASS:       cov_name = "pwm   pulse passed through unclipped";
            C_GLITCH:     cov_name = "flt   OTP glitch below debounce rejected";
            C_BLINK:      cov_name = "led   Red_LED1 blinking (strike outstanding)";
            C_SOLID:      cov_name = "led   Red_LED1 solid (latched)";
            C_RD_SINGLE:  cov_name = "spi   read, single byte";
            C_RD_BURST:   cov_name = "spi   read, burst";
            C_WR_COMMIT:  cov_name = "spi   write committed";
            C_WR_BURST:   cov_name = "spi   write committed, burst";
            C_AB_CRC:     cov_name = "spi   write aborted: bad CRC";
            C_AB_ALIGN:   cov_name = "spi   write aborted: CS off a byte boundary";
            C_AB_SHORT:   cov_name = "spi   write aborted: too short";
            C_REJ_LOCK:   cov_name = "spi   threshold write rejected: bank locked";
            C_REJ_OFF:    cov_name = "spi   threshold write rejected: not in S_OFF";
            C_CLAMP:      cov_name = "spi   value clamped on commit";
            C_CS_MIDRD:   cov_name = "spi   CS dropped mid-read, line released";
            C_SCK_TMO:    cov_name = "spi   SCK idle timeout -> S_DEAD";
            C_SPI_ILLEG:  cov_name = "spi   illegal state recovered (forced)";
            C_TS_CARRY:   cov_name = "tel   timestamp burst coherent across a carry";
            C_FLOG_CLR:   cov_name = "tel   fault log cleared by a read of 0x20";
            C_BUS_ERR:    cov_name = "tel   bus error counter advanced";
            C_WATCHDOG:   cov_name = "tel   host-silence watchdog restored enable";
            C_STATS:      cov_name = "tel   PWM statistics read back plausibly";
            C_STUCK:      cov_name = "pwm   modulator stuck high: one capped pulse";
            C_X_OTP_SS:   cov_name = "cross OTP while in S_SS";
            C_X_OTP_RUN:  cov_name = "cross OTP while in S_RUN";
            C_X_OTP_HIC:  cov_name = "cross OTP while in S_HICCUP";
            C_X_UVLO_SS:  cov_name = "cross UVLO while in S_SS";
            C_X_UVLO_RUN: cov_name = "cross UVLO while in S_RUN";
            C_X_UVLO_HIC: cov_name = "cross UVLO while in S_HICCUP";
            C_X_OVP_SS:   cov_name = "cross analog OVP while in S_SS";
            C_X_OVP_RUN:  cov_name = "cross analog OVP while in S_RUN";
            C_X_OVP_HIC:  cov_name = "cross analog OVP while in S_HICCUP";
            C_X_SW_SS:    cov_name = "cross switch released while in S_SS";
            C_X_SW_RUN:   cov_name = "cross switch released while in S_RUN";
            C_X_SW_HIC:   cov_name = "cross switch released while in S_HICCUP";
            C_X_HOST_SS:  cov_name = "cross host disable while in S_SS";
            C_X_HOST_RUN: cov_name = "cross host disable while in S_RUN";
            C_X_HOST_HIC: cov_name = "cross host disable while in S_HICCUP";
            C_X_STRK_HIC: cov_name = "cross strike latch while in S_HICCUP";
            C_WIN_HOLD:   cov_name = "flt   11 of 16 faulted cycles held below the trip";
            C_WIN_EXACT:  cov_name = "flt   trip on exactly the 12th faulted cycle";
            C_ESC2:       cov_name = "strk  second hiccup twice the first";
            C_CLEAN_RESTART: cov_name = "strk  clean-run window restarted after a trip";
            C_SW_CHATTER: cov_name = "flt   switch chatter under the debounce ignored";
            C_UVLO_GLITCH: cov_name = "flt   UVLO glitch below debounce rejected";
            C_LATCH_GLITCH: cov_name = "flt   latch readback glitch below debounce rejected";
            C_OVERLAP:    cov_name = "flt   OTP and UVLO overlapping: back after both clear";
            C_RST_RUN:    cov_name = "rst   reset while running: outputs safe at once";
            C_STRK_PERSIST: cov_name = "strk  strikes kept across a fault-off and restart";
            C_REG_TRIP_RUN: cov_name = "reg   TRIP_RUN written: run trips at the new count";
            C_REG_TRIP_SS: cov_name = "reg   TRIP_SS written: ramp trips at the new count";
            C_REG_STRIKES: cov_name = "reg   MAX_STRIKES = 1: latch on the first strike";
            C_REG_MAX_ON: cov_name = "reg   MAX_ON written: ramp and backstop at the new top";
            C_REG_CYC:    cov_name = "reg   CYCLES_PER_STEP written: ramp steps follow it";
            C_SPI_GLITCH: cov_name = "spi   SCK and CS glitches under the filter ignored";
            C_SPI_WRAP:   cov_name = "spi   burst read wraps from 0x7F to 0x00";
            C_SPI_RST:    cov_name = "spi   reset mid-transaction, next one works";
            C_SPI_RO:     cov_name = "spi   write to a read-only register ignored";
            default:      cov_name = "?";
        endcase
    end
endfunction

task print_coverage;
    integer b;
    begin
        cov_missed = 0;
        cov_applicable = 0;
        emit("---------------------------- coverage ----------------------------");
        for (b = 0; b < NB; b = b + 1) begin
            if (cov_applies(b)) begin
                cov_applicable = cov_applicable + 1;
                if (!cov[b]) cov_missed = cov_missed + 1;
                $sformat(msg, "  %0s %7d  %0s", cov[b] ? "HIT " : "MISS", cov_hits[b], cov_name(b));
            end
            else
                $sformat(msg, "  n/a  %7d  %0s", cov_hits[b], cov_name(b));
            emit(msg);
        end
        if (cov_applicable == NB)
            $sformat(msg, "  %0d of %0d bins hit", NB - cov_missed, NB);
        else
            $sformat(msg, "  %0d of %0d bins hit (%0d n/a: not built with TELEMETRY_EN = 0)",
                     cov_applicable - cov_missed, cov_applicable, NB - cov_applicable);
        emit(msg);
        emit("------------------------------------------------------------------");
    end
endtask


// ============================================================
// Board models
// ============================================================
// osc_enable / osc_stuck_high / osc_high_ns: modulator on, modulator output
// stuck high, and the high time it commands
reg  osc_enable     = 1'b1;
reg  osc_stuck_high = 1'b0;
reg  osc_started    = 1'b0;
// osc_high_ns starts at 90% duty, 2000 ns, and keeps it until phase 4 says
// otherwise. Set here and nowhere else at time 0: see log_fd for why.
real osc_high_ns    = 2000.0;

/*
Purpose:
---
Analog modulator. A free-running 450 kHz square wave whose high time the
stimulus sets, standing in for the PWM comparator output. Real-valued delays
keep it asynchronous to clk, which is what the input synchroniser and every
pwm_fall-referenced counter in the DUT exist to cope with. osc_stuck_high holds
it high, as a dead modulator or latched comparator would.
*/
always begin : osc_model
    if (!osc_started) begin
        osc_started = 1'b1;
        #(OSC_PHASE_NS);
    end
    if (osc_stuck_high) begin
        Osc_in = 1'b1;
        #(SW_PERIOD_NS);
    end
    else if (osc_enable) begin
        Osc_in = 1'b1;
        #(osc_high_ns);
        Osc_in = 1'b0;
        #(SW_PERIOD_NS - osc_high_ns);
    end
    else begin
        Osc_in = 1'b0;
        #(SW_PERIOD_NS);
    end
end

// scr_latched: state of the SCR protection latch. ovp_event is the analog OVP
//              comparator, the latch's second trip source.
reg scr_latched = 1'b0;
reg ovp_event   = 1'b0;
// latch_glitch: a readback pulse with the SCR not latched (phase 18)
reg latch_glitch = 1'b0;

/*
Purpose:
---
SCR protection latch. Set by the CPLD's latch_out or by the analog OVP
comparator, and cleared only by the manual drain button, which on the board is
the same button as rst_n_pin - so the SCR and the DUT's latch_assert always
clear together, as fault_cause.sv assumes.
*/
always @(posedge latch_out or posedge ovp_event or negedge rst_n_pin) begin
    if (!rst_n_pin) scr_latched <= 1'b0;
    else            scr_latched <= 1'b1;
end
assign #(SCR_DELAY_NS) latch_stat = scr_latched | latch_glitch;


// ============================================================
// Run-long monitors
// ============================================================
// MISO. The slave's read-data enable must track spi_state == S_READ exactly:
// never on while the master is sending (command byte, turnaround byte, write
// data) and never after the read ends, with no tolerance, so a change that
// delays the take-over or the release by one clock trips it. At the pin, MISO
// must be low whenever the slave is not in S_READ.
integer oe_misaligned      = 0;   // clocks with sdio_oe != (spi_state == S_READ)
integer oe_in_master_phase = 0;   // ... of which sdio_oe high in S_CMD, S_TURN, S_WRITE
integer oe_rises           = 0;   // times the slave took the line
integer oe_rise_bad        = 0;   // ... without the first data bit on MISO
integer read_exits         = 0;   // transitions out of S_READ, by destination:
integer exit_to_idle       = 0;   //   CS deasserted
integer exit_to_dead       = 0;   //   SCK idle timeout
integer exit_to_cmd        = 0;   //   CS re-asserted
integer exit_to_other      = 0;
integer reads_issued       = 0;   // reads issued that reached the data phase
integer mirror_errors      = 0;   // switch_supply != PGOOD
integer pgood_no_en        = 0;   // PGOOD high with En low for 2+ clocks
integer pgood_no_en_run    = 0;
integer backstop_errors    = 0;   // a PWM_out pulse longer than the ceiling
integer latch_drops        = 0;   // latch_out fell without a reset
integer miso_idle          = 0;   // MISO high while the slave is not in S_READ
integer miso_xz            = 0;   // MISO x or z after reset (4-state simulators)
reg [2:0] spi_state_prev   = 3'd0;

/*
Purpose:
---
Protocol and invariant monitor, sampled on every rising clock edge with the
values the DUT registers are about to update from: the MISO enable against the
SPI state, MISO low outside S_READ, the S_READ exit tally, switch_supply
mirroring PGOOD, PGOOD never outliving En, and MISO never x or z.
*/
always @(posedge clk) begin
    if (rst_n_pin) begin
        if (sdio_oe_int !== (spi_state_int == SPI_READ)) begin
            oe_misaligned = oe_misaligned + 1;
            if (sdio_oe_int && ((spi_state_int == SPI_CMD) || (spi_state_int == SPI_TURN) ||
                                (spi_state_int == SPI_WRITE)))
                oe_in_master_phase = oe_in_master_phase + 1;
            if (oe_misaligned <= 5) begin
                $display("[%0t] MONITOR: sdio_oe = %b in spi_state %0d (previous %0d)",
                         $time, sdio_oe_int, spi_state_int, spi_state_prev);
                if (log_fd != 0) $fdisplay(log_fd, "[%0t] MONITOR: sdio_oe = %b in spi_state %0d (previous %0d)",
                         $time, sdio_oe_int, spi_state_int, spi_state_prev);
            end
        end
        if ((spi_state_prev == SPI_READ) && (spi_state_int != SPI_READ)) begin
            read_exits = read_exits + 1;
            if      (spi_state_int == SPI_IDLE) exit_to_idle  = exit_to_idle + 1;
            else if (spi_state_int == SPI_DEAD) exit_to_dead  = exit_to_dead + 1;
            else if (spi_state_int == SPI_CMD)  exit_to_cmd   = exit_to_cmd + 1;
            else                                exit_to_other = exit_to_other + 1;
        end
        if (switch_supply !== PGOOD) mirror_errors = mirror_errors + 1;
        if (PGOOD && !En) pgood_no_en_run = pgood_no_en_run + 1;
        else              pgood_no_en_run = 0;
        if (pgood_no_en_run == 2) pgood_no_en = pgood_no_en + 1;
        if ((spi_state_int != SPI_READ) && (MISO !== 1'b0)) miso_idle = miso_idle + 1;
        if ((MISO !== 1'b0) && (MISO !== 1'b1)) miso_xz = miso_xz + 1;
    end
    spi_state_prev = spi_state_int;
end

real oe_rise_t        = 0.0;
real oe_fall_t        = 0.0;
real first_bit_margin = 1.0e9;   // smallest oe-to-sampling-edge time seen
integer first_bit_errors = 0;    // reads whose first bit was not driven in time

/*
Purpose:
---
Time-stamp the read-data enable rising and falling, for the latency checks.
*/
always @(posedge sdio_oe_int) oe_rise_t = $realtime;
always @(negedge sdio_oe_int) oe_fall_t = $realtime;

/*
Purpose:
---
At the moment MISO starts carrying read data the first data bit must already
be on it. sdio_out and tx_shift are loaded on the last falling SCK edge of the
turnaround byte and change only on falling edges, so 1 ns after sdio_oe rises
the MISO pin must carry sdio_out, and sdio_out must be the MSB of the loaded
byte.
*/
always @(posedge sdio_oe_int) begin
    #(1.0);
    oe_rises = oe_rises + 1;
    if ((MISO !== sdio_out_int) || (sdio_out_int !== tx_shift7_int)) begin
        oe_rise_bad = oe_rise_bad + 1;
        $display("[%0t] MONITOR: MISO enabled without the first data bit (MISO=%b sdio_out=%b tx_shift[7]=%b)",
                 $time, MISO, sdio_out_int, tx_shift7_int);
        if (log_fd != 0) $fdisplay(log_fd, "[%0t] MONITOR: MISO enabled without the first data bit (MISO=%b sdio_out=%b tx_shift[7]=%b)",
                 $time, MISO, sdio_out_int, tx_shift7_int);
    end
end

// pwm_rise_t / pwm_width_ns / pwm_pulses: last PWM_out pulse, for the phases
real    pwm_rise_t   = 0.0;
real    pwm_width_ns = 0.0;
integer pwm_pulses   = 0;

/*
Purpose:
---
Measure every PWM_out pulse. PWM_out is a register output, so widths are whole
clocks. The backstop invariant is that no pulse ever exceeds MAX_ON_COUNTS + 1
clocks, whatever Osc_in does. In S_RUN a pulse that ends while the synchronised
modulator is still high was cut by the backstop; one that ends after it fell
passed through.
*/
always @(posedge PWM_out) pwm_rise_t = $realtime;
always @(negedge PWM_out) begin
    if (pwm_rise_t > 0.0) begin
        pwm_width_ns = $realtime - pwm_rise_t;
        pwm_pulses   = pwm_pulses + 1;
        if (pwm_width_ns > (MAX_ON_COUNTS + 1) * CLK_PERIOD_NS + 1.0)
            backstop_errors = backstop_errors + 1;
        if (run_active_int && osc_sync_int &&
            (pwm_width_ns > (MAX_ON_COUNTS + 1) * CLK_PERIOD_NS - 1.0))
            cover_bin(C_BACKSTOP);
        if (run_active_int && !osc_sync_int &&
            (pwm_width_ns < MAX_ON_COUNTS * CLK_PERIOD_NS - 1.0))
            cover_bin(C_PASS);
    end
end

/*
Purpose:
---
latch_assert is set-only and cleared by rst_n alone, because it trips a
physical SCR. Any fall of latch_out with the reset button released is a bug.
*/
always @(negedge latch_out) if (rst_n_pin === 1'b1) latch_drops = latch_drops + 1;


// ============================================================
// Coverage monitors - bins set from what the DUT actually did
// ============================================================
reg  [1:0] strike_prev   = 2'd0;
reg        ramp_top_prev = 1'b0;
reg [15:0] bus_err_prev  = 16'd0;
real       otp_sync_rise_t = 0.0;
integer    n_integrity   = 0;   // integrity_ok pulses seen
integer    n_abort       = 0;   // abort pulses seen
integer    n_rd_first    = 0;   // read data phases started

/*
Purpose:
---
Per-clock coverage of strike levels, the strike clear, the ramp reaching its
ceiling, the fault-log clear, the bus-error counter, and the SPI transaction
outcomes the SPI tasks compare against.
*/
always @(posedge clk) begin
    if (dut_rst_n === 1'b1) begin
        if (strike_int != strike_prev) begin
            if (strike_int == 2'd1) cover_bin(C_STRIKE1);
            if (strike_int == 2'd2) cover_bin(C_STRIKE2);
            if (strike_int == 2'd3) cover_bin(C_STRIKE3);
            if ((strike_int == 2'd0) && run_active_int) cover_bin(C_STRIKE_CLR);
        end
        if ((ss_active_int && (max_on_cnt_int == MAX_ON_COUNTS)) && !ramp_top_prev) cover_bin(C_RAMP_TOP);
        ramp_top_prev = ss_active_int && (max_on_cnt_int == MAX_ON_COUNTS);
        if (flog_clear_int) cover_bin(C_FLOG_CLR);
        if (rf_bus_err != bus_err_prev) cover_bin(C_BUS_ERR);
        if (integrity_int) n_integrity = n_integrity + 1;
        if (abort_int)     n_abort     = n_abort + 1;
        if (rd_first_int)  n_rd_first  = n_rd_first + 1;
    end
    strike_prev  = strike_int;
    bus_err_prev = rf_bus_err;
end

/*
Purpose:
---
PGOOD coverage. A drop with run_active still high came from the comparator; a
drop together with run_active came from leaving S_RUN. Only a fall from 1 is a
drop: a four-state simulator (Icarus) also sees PGOOD go x -> 0 at power-on
reset, which a plain negedge counts and a two-state one (Verilator) never
sees, so the hit counts would differ between the two.
*/
reg pgood_q = 1'b0;   // PGOOD's previous level
always @(posedge PGOOD) cover_bin(C_PG_QUAL);
always @(PGOOD) begin
    if ((pgood_q === 1'b1) && (PGOOD === 1'b0)) begin
        if (run_active_int) cover_bin(C_PG_COMP);
        else                cover_bin(C_PG_RUN);
    end
    pgood_q = PGOOD;
end

/*
Purpose:
---
A synchronised OTP pulse that came and went without the debounced flag ever
rising is a glitch the debouncer rejected.
*/
always @(posedge otp_sync_int) otp_sync_rise_t = $realtime;
always @(negedge otp_sync_int)
    if ((dut_rst_n === 1'b1) && !otp_db_int && ($realtime - otp_sync_rise_t > 50.0 * US))
        cover_bin(C_GLITCH);

/*
Purpose:
---
Red_LED1: blinking while strikes are outstanding and nothing is latched, solid
once latched.
*/
always @(posedge Red_LED1) begin
    if (latch_out || latch_db_int) cover_bin(C_SOLID);
    else if (strike_int != 2'd0)   cover_bin(C_BLINK);
end

// red1_rises: Red_LED1 rising edges, for the pins-only blink-rate check
integer red1_rises = 0;
always @(posedge Red_LED1) red1_rises = red1_rises + 1;

/*
Purpose:
---
The host-silence watchdog re-enabling the converter.
*/
always @(posedge rf_wd_restored) cover_bin(C_WATCHDOG);


// ============================================================
// Second-pass monitors - more invariants, sampled for the whole run
// ============================================================
real    uvlo_sync_rise_t  = 0.0;
real    latch_sync_rise_t = 0.0;
real    en_fall_t         = 0.0;   // last En fall, for the hiccup durations
integer pgood_not_run     = 0;     // clocks with PGOOD high outside S_RUN
integer green_err         = 0;     // clocks Green_LED disagreed with running-and-no-fault
integer red23_err         = 0;     // clocks Red_LED2 / Red_LED3 disagreed with OTP / UVLO
integer ceiling_err       = 0;     // PWM_out pulses longer than the ceiling in force
integer latch_wrong       = 0;     // latch_out set at a strike level other than MAX_STRIKES
reg     green_exp = 1'b0, red2_exp = 1'b0, red3_exp = 1'b0;
reg [7:0] ceil_at_rise    = 8'd0;

/*
Purpose:
---
UVLO and latch-readback pulses that came and went without the debounced flag
rising are glitches the debouncers rejected - the counterparts of the OTP
glitch bin.
*/
always @(posedge uvlo_sync_int) uvlo_sync_rise_t = $realtime;
always @(negedge uvlo_sync_int)
    if ((dut_rst_n === 1'b1) && !uvlo_db_int && ($realtime - uvlo_sync_rise_t > 50.0 * US))
        cover_bin(C_UVLO_GLITCH);
always @(posedge latch_sync_int) latch_sync_rise_t = $realtime;
always @(negedge latch_sync_int)
    if ((dut_rst_n === 1'b1) && !latch_db_int && ($realtime - latch_sync_rise_t > 50.0 * US))
        cover_bin(C_LATCH_GLITCH);

always @(negedge En) en_fall_t = $realtime;

/*
Purpose:
---
Every clock: PGOOD only in S_RUN; Green_LED equal to running-and-no-fault,
Red_LED2 to the debounced OTP flag and Red_LED3 to the debounced UVLO flag,
each one clock later (the LEDs are registered).
*/
always @(posedge clk) begin : led_pgood_monitor
    if (dut_rst_n === 1'b1) begin
        if ((PGOOD === 1'b1) && (run_active_int !== 1'b1)) pgood_not_run = pgood_not_run + 1;
        if (Green_LED !== green_exp) green_err = green_err + 1;
        if ((Red_LED2 !== red2_exp) || (Red_LED3 !== red3_exp)) red23_err = red23_err + 1;
        green_exp = (ss_active_int || run_active_int) &&
                    !(otp_db_int || uvlo_db_int || latch_db_int || latch_out);
        red2_exp  = otp_db_int;
        red3_exp  = uvlo_db_int;
    end
    else begin
        green_exp = 1'b0;
        red2_exp  = 1'b0;
        red3_exp  = 1'b0;
    end
end

/*
Purpose:
---
No PWM_out pulse may be longer than the ceiling in force when it started plus
the one registered clock - the soft-start level while ramping, the programmed
MAX_ON in S_RUN, the minimum while off. Stronger than the fixed backstop check.
*/
always @(posedge PWM_out) ceil_at_rise = max_on_cnt_int;
always @(negedge PWM_out) begin
    #(0.5);   // after the pulse monitor has recorded the width
    if ((dut_rst_n === 1'b1) && (pwm_width_ns > (ceil_at_rise + 1) * CLK_PERIOD_NS + 1.0))
        ceiling_err = ceiling_err + 1;
end

/*
Purpose:
---
latch_out may only rise on the strike that reaches MAX_STRIKES (the register
value with telemetry, the default without).
*/
always @(posedge latch_out) begin
    #(1.0);
    if (strike_int !== rf_max_strikes[1:0]) latch_wrong = latch_wrong + 1;
end


// ============================================================
// Scoreboard 1 - supervisor FSM reference model
// ============================================================
/*
The model restates the supervisor's specification in a different shape from
the RTL: one fault predicate that forces S_OFF from any state, then a short
per-state advance. Its inputs are the supervisor's own ports, so it checks the
FSM's decisions, its state encoding and the En output across the whole
integrated run - including through sv2v - not the conditioning upstream of
those ports, which the directed checks cover. It is also what attributes each
transition to a cause for the coverage table.
*/
reg [1:0] sm_state       = 2'd0;
reg [1:0] dut_prev       = 2'd0;
reg [2:0] cause_prev     = 3'd0;
reg [2:0] last_off_cause = 3'd7;
reg [1:0] last_off_from  = 2'd0;   // state the supervisor left for the last S_OFF
reg       was_latched    = 1'b0;
real      t_last_run_entry = 0.0;
integer   sm_compares    = 0;
integer   sm_mismatch    = 0;
integer   en_mismatch    = 0;

/*
Purpose:
---
Every clock: compare the DUT's state and En with the model (pre-edge values on
both sides), record any transition the DUT made together with the cause the
model attributes it to, then advance the model on the same inputs the DUT is
deciding on at this edge.
*/
always @(posedge clk) begin : fsm_scoreboard
    reg       fault;
    reg       en_model;
    reg [1:0] sm_next;
    reg [2:0] cause_now;
    if (dut_rst_n !== 1'b1) begin
        if ((last_off_cause == CAUSE_STRIKE) || (last_off_cause == CAUSE_OVP)) was_latched = 1'b1;
        last_off_cause = CAUSE_RESET;
        sm_state   = ST_OFF;
        dut_prev   = ST_OFF;
        cause_prev = CAUSE_NONE;
    end
    else begin
        fault    = !(sup_spi_en && sup_en_sw) || sup_otp || sup_uvlo || sup_latch_st || sup_latch_as;
        en_model = !fault && ((sm_state == ST_SS) || (sm_state == ST_RUN));
        sm_compares = sm_compares + 1;
        if (sup_state !== sm_state) begin
            sm_mismatch = sm_mismatch + 1;
            if (sm_mismatch <= 5) begin
                $display("[%0t] FSM SCOREBOARD: DUT state %0d, model %0d", $time, sup_state, sm_state);
                if (log_fd != 0) $fdisplay(log_fd, "[%0t] FSM SCOREBOARD: DUT state %0d, model %0d", $time, sup_state, sm_state);
            end
        end
        if (En !== en_model) begin
            en_mismatch = en_mismatch + 1;
            if (en_mismatch <= 5) begin
                $display("[%0t] FSM SCOREBOARD: En %b, model %b", $time, En, en_model);
                if (log_fd != 0) $fdisplay(log_fd, "[%0t] FSM SCOREBOARD: En %b, model %b", $time, En, en_model);
            end
        end

        // ---- coverage of the DUT's own transitions ----
        if (sup_state !== dut_prev) begin
            case ({dut_prev, sup_state})
                {ST_OFF, ST_SS}: begin
                    cover_bin(C_OFF_SS);
                    case (last_off_cause)
                        CAUSE_OTP:    cover_bin(C_RE_OTP);
                        CAUSE_UVLO:   cover_bin(C_RE_UVLO);
                        CAUSE_HOST:   cover_bin(C_RE_HOST);
                        CAUSE_SWITCH: cover_bin(C_RE_SWITCH);
                        CAUSE_RESET:  if (was_latched) begin
                                          cover_bin(C_RE_RESET);
                                          was_latched = 1'b0;
                                      end
                        default: ;
                    endcase
                end
                {ST_SS, ST_RUN}: begin
                    cover_bin(C_SS_RUN);
                    t_last_run_entry = $realtime;
                end
                {ST_SS, ST_HICCUP}:  cover_bin(C_SS_HIC);
                {ST_SS, ST_OFF}:     cover_bin(C_SS_OFF);
                {ST_RUN, ST_HICCUP}: cover_bin(C_RUN_HIC);
                {ST_RUN, ST_OFF}:    cover_bin(C_RUN_OFF);
                {ST_HICCUP, ST_SS}:  cover_bin(C_HIC_SS);
                {ST_HICCUP, ST_OFF}: cover_bin(C_HIC_OFF);
                default: ;
            endcase
            if ((sup_state == ST_OFF) && (dut_prev != ST_OFF)) begin
                last_off_cause = cause_prev;
                case (cause_prev)
                    CAUSE_OTP:    cover_bin(C_OFF_OTP);
                    CAUSE_UVLO:   cover_bin(C_OFF_UVLO);
                    CAUSE_OVP:    cover_bin(C_OFF_OVP);
                    CAUSE_STRIKE: cover_bin(C_OFF_STRIKE);
                    CAUSE_HOST:   cover_bin(C_OFF_HOST);
                    CAUSE_SWITCH: cover_bin(C_OFF_SWITCH);
                    default: ;
                endcase
                last_off_from = dut_prev;
                case (cause_prev)
                    CAUSE_OTP:    cover_bin(xbin(C_X_OTP_SS,  dut_prev));
                    CAUSE_UVLO:   cover_bin(xbin(C_X_UVLO_SS, dut_prev));
                    CAUSE_OVP:    cover_bin(xbin(C_X_OVP_SS,  dut_prev));
                    CAUSE_SWITCH: cover_bin(xbin(C_X_SW_SS,   dut_prev));
                    CAUSE_HOST:   cover_bin(xbin(C_X_HOST_SS, dut_prev));
                    CAUSE_STRIKE: if (dut_prev == ST_HICCUP) cover_bin(C_X_STRK_HIC);
                    default: ;
                endcase
            end
        end

        // ---- advance the model ----
        if      (sup_latch_as) cause_now = CAUSE_STRIKE;
        else if (sup_latch_st) cause_now = CAUSE_OVP;
        else if (sup_otp)      cause_now = CAUSE_OTP;
        else if (sup_uvlo)     cause_now = CAUSE_UVLO;
        else if (!sup_spi_en)  cause_now = CAUSE_HOST;
        else if (!sup_en_sw)   cause_now = CAUSE_SWITCH;
        else                   cause_now = CAUSE_NONE;
        case (sm_state)
            ST_OFF:  sm_next = fault ? ST_OFF : ST_SS;
            ST_SS:   sm_next = fault ? ST_OFF : (sup_trip_ss ? ST_HICCUP : (sup_ss_done ? ST_RUN : ST_SS));
            ST_RUN:  sm_next = fault ? ST_OFF : (sup_trip ? ST_HICCUP : ST_RUN);
            default: sm_next = fault ? ST_OFF : (sup_hic_done ? ST_SS : ST_HICCUP);
        endcase
        sm_state   = sm_next;
        dut_prev   = sup_state;
        cause_prev = cause_now;
    end
end


// ============================================================
// Scoreboard 2 - register-map shadow
// ============================================================
/*
A shadow of every writable register, updated from the bytes the testbench
sends using the register map's documented rules - not from the DUT: the
delay line that releases each data byte only when the next completes (so
SCRATCH and the keys act before the CRC is known), keys that must share a
transaction with what they unlock, CONTROL changes deferred to a good CRC, the
S_OFF-only registers, the all-three-bytes rule, and the clamp ranges. The
shadow is compared with the register file every clock between transactions,
and with every byte read back over SPI.
*/
reg [7:0]  sh_scratch, sh_trip_run, sh_trip_ss, sh_max_strikes, sh_max_on, sh_cyc_step;
reg [23:0] sh_hiccup, sh_clean;
reg        sh_spi_enable, sh_write_rej;
reg        spi_busy = 1'b1;      // a transaction or reset in flight: compare paused
reg        sh_last_locked;       // last commit rejected for want of the key
reg        sh_last_offonly;      // last commit rejected an S_OFF-only register
reg        sh_last_clamped;      // last commit clamped a value
reg [7:0]  sh_tmp [0:10];        // threshold temp registers, 0x50..0x5A
integer    rm_compares = 0, rm_mismatch = 0;
integer    rd_compares = 0, rd_mismatch = 0;
integer    outcome_mismatch = 0; // integrity/abort not as the protocol predicts

task shadow_reset;
    begin
        sh_scratch    = 8'h00;
        sh_trip_run   = TRIP_RUN_DEF;
        sh_trip_ss    = TRIP_SS_DEF;
        sh_max_strikes= MAX_STRIKES_DEF;
        sh_max_on     = MAX_ON_COUNTS;
        sh_hiccup     = HICCUP_DEF;
        sh_cyc_step   = CYC_STEP_DEF;
        sh_clean      = CLEAN_DEF;
        sh_spi_enable = 1'b1;
        sh_write_rej  = 1'b0;
    end
endtask

// Clamp functions, from the ranges documented in reg_file.sv
function [7:0] clamp8(input [7:0] value, input integer lo, input integer hi);
    begin
        if      (value < lo) clamp8 = lo;
        else if (value > hi) clamp8 = hi;
        else                 clamp8 = value;
    end
endfunction

function [23:0] clamp24(input [23:0] value, input integer lo, input integer hi);
    begin
        if      (value < lo) clamp24 = lo;
        else if (value > hi) clamp24 = hi;
        else                 clamp24 = value;
    end
endfunction

/*
shadow_write: apply one write transaction. n_rel is the number of data bytes
the slave released (each is released when the following byte completes, so a
frame that ends early releases one fewer). committed is whether the frame
passes the slave's end-of-transaction checks.
*/
task shadow_write(input [6:0] cmd_addr, input integer n_rel, input committed);
    integer    i;
    reg [6:0]  a;
    reg [7:0]  b;
    reg [10:0] dirty;
    reg        unlock, disarm, en_pend, en_val, off_ok;
    reg [7:0]  clamped;
    reg [23:0] clamped24;
    begin
        unlock = 1'b0; disarm = 1'b0; en_pend = 1'b0; en_val = 1'b0; dirty = 11'd0;
        sh_last_locked = 1'b0; sh_last_offonly = 1'b0; sh_last_clamped = 1'b0;
        off_ok = (sm_state == ST_OFF);
        for (i = 0; i < n_rel; i = i + 1) begin
            a = cmd_addr + i;
            b = spi_tx[i];
            if      (a == A_SCRATCH) sh_scratch = b;            // immediate, before the CRC
            else if (a == A_DISKEY)  disarm = (b == DISABLE_KEY);
            else if (a == A_WRKEY)   unlock = (b == WRITE_KEY);
            else if (a == A_CONTROL) begin
                if (b[0]) begin en_pend = 1'b1; en_val = 1'b1; disarm = 1'b0; end
                else if (disarm) begin en_pend = 1'b1; en_val = 1'b0; disarm = 1'b0; end
            end
            else if ((a >= A_TRIP_RUN) && (a <= A_CLEAN2)) begin
                sh_tmp[a - A_TRIP_RUN] = b;
                dirty[a - A_TRIP_RUN]  = 1'b1;
            end
        end
        if (committed) begin
            if (en_pend) sh_spi_enable = en_val;
            if (|dirty) begin
                sh_write_rej = 1'b0;
                if (!unlock) begin
                    sh_write_rej   = 1'b1;
                    sh_last_locked = 1'b1;
                end
                else begin
                    if (dirty[0]) begin
                        clamped = clamp8(sh_tmp[0], 1, WINDOW_RUN);
                        if (clamped != sh_tmp[0]) sh_last_clamped = 1'b1;
                        sh_trip_run = clamped;
                    end
                    if (dirty[1]) begin
                        clamped = clamp8(sh_tmp[1], 1, WINDOW_SS);
                        if (clamped != sh_tmp[1]) sh_last_clamped = 1'b1;
                        sh_trip_ss = clamped;
                    end
                    if (dirty[2]) begin
                        clamped = clamp8(sh_tmp[2], 1, MAX_STRIKES_DEF);
                        if (clamped != sh_tmp[2]) sh_last_clamped = 1'b1;
                        sh_max_strikes = clamped;
                    end
                    if (dirty[3]) begin
                        clamped = clamp8(sh_tmp[3], MIN_ON_COUNTS, MAX_ON_COUNTS);
                        if (clamped != sh_tmp[3]) sh_last_clamped = 1'b1;
                        sh_max_on = clamped;
                    end
                    if (dirty[7]) begin
                        if (off_ok) begin
                            clamped = clamp8(sh_tmp[7], 1, CYC_STEP_MAX);
                            if (clamped != sh_tmp[7]) sh_last_clamped = 1'b1;
                            sh_cyc_step = clamped;
                        end
                        else begin sh_write_rej = 1'b1; sh_last_offonly = 1'b1; end
                    end
                    if (|dirty[6:4]) begin
                        if ((&dirty[6:4]) && off_ok) begin
                            clamped24 = clamp24({sh_tmp[6], sh_tmp[5], sh_tmp[4]}, HICCUP_MIN, HICCUP_MAX);
                            if (clamped24 != {sh_tmp[6], sh_tmp[5], sh_tmp[4]}) sh_last_clamped = 1'b1;
                            sh_hiccup = clamped24;
                        end
                        else begin sh_write_rej = 1'b1; if (!off_ok) sh_last_offonly = 1'b1; end
                    end
                    if (|dirty[10:8]) begin
                        if ((&dirty[10:8]) && off_ok) begin
                            clamped24 = clamp24({sh_tmp[10], sh_tmp[9], sh_tmp[8]}, CLEAN_SHORT, CLEAN_MAX);
                            if (clamped24 != {sh_tmp[10], sh_tmp[9], sh_tmp[8]}) sh_last_clamped = 1'b1;
                            sh_clean = clamped24;
                        end
                        else begin sh_write_rej = 1'b1; if (!off_ok) sh_last_offonly = 1'b1; end
                    end
                end
            end
        end
    end
endtask

// sh_mapped / sh_byte: which read addresses the shadow predicts, and their value
function sh_mapped(input [6:0] a);
    sh_mapped = (a == A_SCRATCH) || ((a >= A_TRIP_RUN) && (a <= A_CLEAN2));
endfunction

function [7:0] sh_byte(input [6:0] a);
    begin
        case (a)
            A_SCRATCH:       sh_byte = sh_scratch;
            A_TRIP_RUN:      sh_byte = sh_trip_run;
            A_TRIP_SS:       sh_byte = sh_trip_ss;
            A_MAX_STRIKES:   sh_byte = sh_max_strikes;
            A_MAX_ON:        sh_byte = sh_max_on;
            A_HICCUP0:       sh_byte = sh_hiccup[7:0];
            A_HICCUP0 + 7'd1: sh_byte = sh_hiccup[15:8];
            A_HICCUP0 + 7'd2: sh_byte = sh_hiccup[23:16];
            A_CYC_STEP:      sh_byte = sh_cyc_step;
            A_CLEAN0:        sh_byte = sh_clean[7:0];
            A_CLEAN0 + 7'd1: sh_byte = sh_clean[15:8];
            A_CLEAN2:        sh_byte = sh_clean[23:16];
            default:         sh_byte = 8'h00;
        endcase
    end
endfunction

/*
Purpose:
---
Every clock with no transaction in flight, the register file must hold exactly
what the shadow predicts. Changes that do not come from the bus are applied to
the shadow here, after the compare: a fresh enable-switch press re-enables
spi_enable on the same edge the DUT does.
*/
always @(posedge clk) begin : regmap_scoreboard
    if (TELEMETRY_EN && !spi_busy && (dut_rst_n === 1'b1)) begin
        rm_compares = rm_compares + 1;
        if ((rf_scratch !== sh_scratch) || (rf_trip_run !== sh_trip_run) ||
            (rf_trip_ss !== sh_trip_ss) || (rf_max_strikes !== sh_max_strikes) ||
            (rf_max_on !== sh_max_on) || (rf_hiccup !== sh_hiccup) ||
            (rf_cyc_step !== sh_cyc_step) || (rf_clean !== sh_clean) ||
            (rf_spi_enable !== sh_spi_enable) || (rf_write_rej !== sh_write_rej)) begin
            rm_mismatch = rm_mismatch + 1;
            if (rm_mismatch <= 5) begin
                $display("[%0t] REGMAP SCOREBOARD: DUT scr %h trun %0d tss %0d strk %0d maxon %0d hic %0d cyc %0d clean %0d en %b rej %b",
                         $time, rf_scratch, rf_trip_run, rf_trip_ss, rf_max_strikes, rf_max_on,
                         rf_hiccup, rf_cyc_step, rf_clean, rf_spi_enable, rf_write_rej);
                if (log_fd != 0) $fdisplay(log_fd, "[%0t] REGMAP SCOREBOARD: DUT scr %h trun %0d tss %0d strk %0d maxon %0d hic %0d cyc %0d clean %0d en %b rej %b",
                         $time, rf_scratch, rf_trip_run, rf_trip_ss, rf_max_strikes, rf_max_on,
                         rf_hiccup, rf_cyc_step, rf_clean, rf_spi_enable, rf_write_rej);
                $display("[%0t] REGMAP SCOREBOARD: model scr %h trun %0d tss %0d strk %0d maxon %0d hic %0d cyc %0d clean %0d en %b rej %b",
                         $time, sh_scratch, sh_trip_run, sh_trip_ss, sh_max_strikes, sh_max_on,
                         sh_hiccup, sh_cyc_step, sh_clean, sh_spi_enable, sh_write_rej);
                if (log_fd != 0) $fdisplay(log_fd, "[%0t] REGMAP SCOREBOARD: model scr %h trun %0d tss %0d strk %0d maxon %0d hic %0d cyc %0d clean %0d en %b rej %b",
                         $time, sh_scratch, sh_trip_run, sh_trip_ss, sh_max_strikes, sh_max_on,
                         sh_hiccup, sh_cyc_step, sh_clean, sh_spi_enable, sh_write_rej);
            end
        end
    end
    if (sw_rise_int) sh_spi_enable = 1'b1;
end


// ============================================================
// SPI master - Mode 0, MSB first, 4-wire (MOSI, MISO), CRC-8 poly 0x07 init 0x00
// ============================================================
reg [7:0] spi_tx [0:15];   // bytes to write, after the command byte
reg [7:0] spi_rx [0:15];   // bytes read back
integer   n_int_before, n_abort_before, n_rdf_before;

// crc8: one byte into the running CRC, MSB first - the bit order spi_slave
//       shifts in, so the slave's register reaches zero after the CRC byte
function [7:0] crc8(input [7:0] crc_in, input [7:0] data);
    integer bit_idx;
    reg [7:0] crc_acc;
    begin
        crc_acc = crc_in;
        for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1)
            crc_acc = (crc_acc[7] ^ data[bit_idx]) ? ((crc_acc << 1) ^ 8'h07) : (crc_acc << 1);
        crc8 = crc_acc;
    end
endfunction

// spi_send_bits: the master puts each bit on MOSI while SCK is low and the
//                slave samples it on the rising edge; nbits from the MSB down
task spi_send_bits(input [7:0] data, input integer nbits);
    integer bit_idx;
    begin
        for (bit_idx = 7; bit_idx > 7 - nbits; bit_idx = bit_idx - 1) begin
            MOSI = data[bit_idx];
            #(SPI_HALF_NS) SCK = 1'b1;
            #(SPI_HALF_NS) SCK = 1'b0;
        end
    end
endtask

task spi_send_byte(input [7:0] data);
    spi_send_bits(data, 8);
endtask

// spi_recv_byte: sample MISO on each rising edge, MOSI held low (a don't-care
//                here). check_first also asserts that MISO is carrying read
//                data at the first data edge.
task spi_recv_byte(output [7:0] data, input check_first);
    integer bit_idx;
    begin
        MOSI = 1'b0;
        for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1) begin
            #(SPI_HALF_NS) SCK = 1'b1;
            data[bit_idx] = MISO;
            if (check_first && (bit_idx == 7)) begin
                if (sdio_oe_int !== 1'b1) first_bit_errors = first_bit_errors + 1;
                else if ($realtime - oe_rise_t < first_bit_margin)
                    first_bit_margin = $realtime - oe_rise_t;
            end
            #(SPI_HALF_NS) SCK = 1'b0;
        end
    end
endtask

task spi_begin;
    begin
        spi_busy       = 1'b1;
        n_int_before   = n_integrity;
        n_abort_before = n_abort;
        CS_n = 1'b0;
        #(SPI_HALF_NS);
    end
endtask

task spi_end;
    begin
        MOSI = 1'b0;
        #(SPI_HALF_NS) CS_n = 1'b1;
    end
endtask

// expect_outcome: the slave's end-of-frame decision must be the one the
//                 protocol predicts; spi_busy clears once the commit has landed
task expect_outcome(input committed, input is_write);
    begin
        #(SPI_GAP_NS);
        if (is_write) begin
            if (committed && (n_integrity != n_int_before + 1)) outcome_mismatch = outcome_mismatch + 1;
            if (!committed && (n_abort != n_abort_before + 1))  outcome_mismatch = outcome_mismatch + 1;
            if (committed && (n_integrity == n_int_before + 1))  cover_bin(C_WR_COMMIT);
        end
        spi_busy = 1'b0;
    end
endtask

// spi_write: [cmd][spi_tx[0..n-1]][CRC]; bad_crc flips the CRC byte
task spi_write(input [6:0] addr, input integer nbytes, input bad_crc);
    integer idx;
    reg [7:0] crc_acc;
    begin
        crc_acc = crc8(8'h00, {1'b0, addr});
        for (idx = 0; idx < nbytes; idx = idx + 1) crc_acc = crc8(crc_acc, spi_tx[idx]);
        spi_begin;
        spi_send_byte({1'b0, addr});
        for (idx = 0; idx < nbytes; idx = idx + 1) spi_send_byte(spi_tx[idx]);
        spi_send_byte(bad_crc ? ~crc_acc : crc_acc);
        spi_end;
        shadow_write(addr, nbytes, !bad_crc);
        expect_outcome(!bad_crc, 1'b1);
        if (bad_crc && (n_abort == n_abort_before + 1)) cover_bin(C_AB_CRC);
        if (!bad_crc && (nbytes > 1) && (n_integrity == n_int_before + 1)) cover_bin(C_WR_BURST);
        if (!bad_crc && (n_integrity == n_int_before + 1) && rf_write_rej) begin
            if (sh_last_locked)  cover_bin(C_REJ_LOCK);
            if (sh_last_offonly) cover_bin(C_REJ_OFF);
        end
        if (!bad_crc && sh_last_clamped && (rf_trip_run === sh_trip_run) &&
            (rf_trip_ss === sh_trip_ss) && (rf_max_on === sh_max_on) &&
            (rf_hiccup === sh_hiccup) && (rf_clean === sh_clean)) cover_bin(C_CLAMP);
    end
endtask

// spi_write_short: command and CRC only, two bytes - below the three-byte
//                  minimum, so the slave must abort and commit nothing
task spi_write_short(input [6:0] addr);
    begin
        spi_begin;
        spi_send_byte({1'b0, addr});
        spi_send_byte(crc8(8'h00, {1'b0, addr}));
        spi_end;
        shadow_write(addr, 0, 1'b0);
        expect_outcome(1'b0, 1'b1);
        if (n_abort == n_abort_before + 1) cover_bin(C_AB_SHORT);
    end
endtask

// spi_write_misaligned: command, one data byte, then CS rises three bits into
//                       the CRC byte. The data byte is never released.
task spi_write_misaligned(input [6:0] addr, input [7:0] data);
    begin
        spi_begin;
        spi_send_byte({1'b0, addr});
        spi_send_byte(data);
        spi_send_bits(crc8(crc8(8'h00, {1'b0, addr}), data), 3);
        spi_end;
        shadow_write(addr, 0, 1'b0);
        expect_outcome(1'b0, 1'b1);
        if (n_abort == n_abort_before + 1) cover_bin(C_AB_ALIGN);
    end
endtask

// spi_read: [cmd][turnaround][n data bytes]. After the command byte MOSI is a
//           don't-care; the master holds it low through the turnaround and
//           data bytes while the slave answers on MISO.
//           Every byte at an address the shadow predicts is compared.
task spi_read(input [6:0] addr, input integer nbytes);
    integer idx;
    reg [7:0] turnaround;
    reg [6:0] a;
    begin
        n_rdf_before = n_rd_first;
        CS_n = 1'b0;
        #(SPI_HALF_NS);
        spi_send_byte({1'b1, addr});
        spi_recv_byte(turnaround, 1'b0);
        reads_issued = reads_issued + 1;
        for (idx = 0; idx < nbytes; idx = idx + 1) spi_recv_byte(spi_rx[idx], idx == 0);
        #(SPI_HALF_NS) CS_n = 1'b1;
        #(SPI_GAP_NS);
        if (n_rd_first == n_rdf_before + 1) cover_bin((nbytes > 1) ? C_RD_BURST : C_RD_SINGLE);
        for (idx = 0; idx < nbytes; idx = idx + 1) begin
            a = addr + idx;
            if (sh_mapped(a) && !spi_busy) begin
                rd_compares = rd_compares + 1;
                if (spi_rx[idx] !== sh_byte(a)) begin
                    rd_mismatch = rd_mismatch + 1;
                    $sformat(msg, "[%0t] REGMAP SCOREBOARD: read 0x%h = 0x%h, shadow 0x%h",
                             $time, a, spi_rx[idx], sh_byte(a));
                    emit(msg);
                end
            end
        end
    end
endtask

// reg_read / reg_write: single-byte conveniences
reg [7:0] rd_val;
task reg_read(input [6:0] addr);
    begin
        spi_read(addr, 1);
        rd_val = spi_rx[0];
    end
endtask

task reg_write(input [6:0] addr, input [7:0] data);
    begin
        spi_tx[0] = data;
        spi_write(addr, 1, 1'b0);
    end
endtask

// write_thresholds: one keyed transaction from WRITE_KEY up through the whole
//                   threshold bank. The key and the values must share one CRC:
//                   reg_file drops the unlock at the end of every transaction.
task write_thresholds(input [7:0] trip_run, input [7:0] trip_ss, input [7:0] max_strikes,
                      input [7:0] max_on, input [23:0] hiccup, input [7:0] cyc_step,
                      input [23:0] clean_run);
    begin
        spi_tx[0]  = WRITE_KEY;
        spi_tx[1]  = trip_run;       spi_tx[2]  = trip_ss;
        spi_tx[3]  = max_strikes;    spi_tx[4]  = max_on;
        spi_tx[5]  = hiccup[7:0];    spi_tx[6]  = hiccup[15:8];    spi_tx[7]  = hiccup[23:16];
        spi_tx[8]  = cyc_step;
        spi_tx[9]  = clean_run[7:0]; spi_tx[10] = clean_run[15:8]; spi_tx[11] = clean_run[23:16];
        spi_write(A_WRKEY, 12, 1'b0);
    end
endtask

// write_run_thresholds: keyed write of the four registers writable at any time
task write_run_thresholds(input [7:0] trip_run, input [7:0] trip_ss,
                          input [7:0] max_strikes, input [7:0] max_on);
    begin
        spi_tx[0] = WRITE_KEY;
        spi_tx[1] = trip_run;    spi_tx[2] = trip_ss;
        spi_tx[3] = max_strikes; spi_tx[4] = max_on;
        spi_write(A_WRKEY, 5, 1'b0);
    end
endtask

task read_thresholds;
    spi_read(A_TRIP_RUN, 11);
endtask


// ============================================================
// Waiting helpers - fork/join with disable, so a missing event fails a check
// after its timeout instead of hanging the run
// ============================================================
reg  timed_out;

task wait_en(input level, input real timeout_ns);
    begin
        timed_out = 1'b0;
        fork : wait_en_blk
            begin wait (En === level); disable wait_en_blk; end
            begin #(timeout_ns); timed_out = 1'b1; disable wait_en_blk; end
        join
    end
endtask

task wait_pgood(input level, input real timeout_ns);
    begin
        timed_out = 1'b0;
        fork : wait_pg_blk
            begin wait (PGOOD === level); disable wait_pg_blk; end
            begin #(timeout_ns); timed_out = 1'b1; disable wait_pg_blk; end
        join
    end
endtask

task wait_strike(input [1:0] level, input real timeout_ns);
    begin
        timed_out = 1'b0;
        fork : wait_strk_blk
            begin wait (strike_int === level); disable wait_strk_blk; end
            begin #(timeout_ns); timed_out = 1'b1; disable wait_strk_blk; end
        join
    end
endtask

// wait_state: poll STATUS over SPI until the supervisor reports a state
reg [1:0] last_state;
task wait_state(input [1:0] state, input real timeout_ns);
    real t_start;
    begin
        t_start = $realtime;
        reg_read(A_STATUS);
        last_state = rd_val[1:0];
        while ((last_state != state) && ($realtime - t_start < timeout_ns)) begin
            #(50.0 * US);
            reg_read(A_STATUS);
            last_state = rd_val[1:0];
        end
    end
endtask

// do_reset: the manual reset / SCR drain button. The register map returns to
//           its reset values, and so does the shadow.
task do_reset;
    begin
        spi_busy  = 1'b1;
        rst_n_pin = 1'b1;
        #1;
        rst_n_pin = 1'b0;
        #(10.0 * CLK_PERIOD_NS);
        shadow_reset;
        rst_n_pin = 1'b1;
        #(10.0 * CLK_PERIOD_NS);
        spi_busy  = 1'b0;
    end
endtask


// ============================================================
// Pins-only helpers - the reduced build (TELEMETRY_EN = 0) has no register map
// to poll and no SPI slave, so its sequence waits on the supervisor through
// the probe and sends SPI frames only to show they change nothing
// ============================================================
// wait_sup_state: wait for the supervisor's state register, read through the
//                 probe, with the same timeout behaviour as the other waits
task wait_sup_state(input [1:0] state, input real timeout_ns);
    begin
        timed_out = 1'b0;
        fork : wait_sup_blk
            begin wait (sup_state === state); disable wait_sup_blk; end
            begin #(timeout_ns); timed_out = 1'b1; disable wait_sup_blk; end
        join
        last_state = sup_state;
    end
endtask

// spi_frames_sent / miso_high_bits: SPI traffic sent to the reduced build, and
//                                   bits sampled high on MISO while reading
integer spi_frames_sent = 0;
integer miso_high_bits  = 0;

// spi_frame_ignored: a well-formed write frame, [cmd][spi_tx[0..n-1]][CRC] -
//                    one a full build would accept. No shadow update and no
//                    outcome check: the reduced build has no slave to decide.
task spi_frame_ignored(input [6:0] addr, input integer nbytes);
    integer   idx;
    reg [7:0] crc_acc;
    begin
        crc_acc = crc8(8'h00, {1'b0, addr});
        for (idx = 0; idx < nbytes; idx = idx + 1) crc_acc = crc8(crc_acc, spi_tx[idx]);
        CS_n = 1'b0;
        #(SPI_HALF_NS);
        spi_send_byte({1'b0, addr});
        for (idx = 0; idx < nbytes; idx = idx + 1) spi_send_byte(spi_tx[idx]);
        spi_send_byte(crc_acc);
        spi_end;
        #(SPI_GAP_NS);
        spi_frames_sent = spi_frames_sent + 1;
    end
endtask

// spi_read_ignored: a read frame, [cmd][turnaround][n data bytes], counting
//                   every bit sampled high on MISO. A full build answers (the
//                   ID register alone is 0xB5); the reduced build must not.
task spi_read_ignored(input [6:0] addr, input integer nbytes);
    integer   idx, b;
    reg [7:0] rx;
    begin
        CS_n = 1'b0;
        #(SPI_HALF_NS);
        spi_send_byte({1'b1, addr});
        for (idx = 0; idx <= nbytes; idx = idx + 1) begin
            spi_recv_byte(rx, 1'b0);
            for (b = 0; b < 8; b = b + 1)
                if (rx[b] !== 1'b0) miso_high_bits = miso_high_bits + 1;
        end
        #(SPI_HALF_NS) CS_n = 1'b1;
        #(SPI_GAP_NS);
        spi_frames_sent = spi_frames_sent + 1;
    end
endtask

// en_falls: falling edges of En, so a window can show the converter never
//           stopped while frames that would disable a full build arrived
integer en_falls = 0;
always @(negedge En) en_falls = en_falls + 1;


// ============================================================
// Soft-start ramp measurement
// ============================================================
integer ramp_levels;       // distinct ceiling levels seen
integer ramp_bad_plateau;  // interior plateaus not CYC_STEP_DEF +- 2 pulses long
integer ramp_backwards;    // a pulse narrower than the one before it
integer ramp_first_level;
real    ramp_t_ceiling;    // time the first full-ceiling pulse ended

/*
measure_ramp: follow PWM_out from En rising until the pulse reaches the
ceiling max_on, with Osc_in commanding more than the ceiling so every pulse
shows the soft-start limit. Each level must last cyc_step switching cycles and
rise by exactly one clock, so a ramp that skipped steps or ran at the wrong rate
fails.
*/
task measure_ramp(input real timeout_ns, input integer cyc_step, input integer max_on);
    integer level, prev_level, plateau;
    real t_start;
    begin
        ramp_levels = 0; ramp_bad_plateau = 0; ramp_backwards = 0;
        ramp_t_ceiling = 0.0; prev_level = -1; plateau = 0; ramp_first_level = -1;
        t_start = $realtime;
        while ((ramp_t_ceiling == 0.0) && ($realtime - t_start < timeout_ns)) begin
            @(negedge PWM_out);
            #(1.0);   // let the pulse monitor, woken by the same edge, record it
            // real -> integer rounds to nearest; widths are whole clocks
            level = pwm_width_ns / CLK_PERIOD_NS;
            if (ramp_first_level < 0) ramp_first_level = level;
            if (level == prev_level) plateau = plateau + 1;
            else begin
                if (level < prev_level) ramp_backwards = ramp_backwards + 1;
                if ((prev_level > ramp_first_level) &&
                    ((plateau < cyc_step - 2) || (plateau > cyc_step + 2)))
                    ramp_bad_plateau = ramp_bad_plateau + 1;
                ramp_levels = ramp_levels + 1;
                prev_level = level;
                plateau = 1;
            end
            if (level >= max_on + 1) ramp_t_ceiling = $realtime;
        end
    end
endtask


// ============================================================
// Directed-random corners - seeded xorshift32, identical in every simulator
// ============================================================
reg [31:0] rng = LFSR_SEED;

function [31:0] xorshift32(input [31:0] x);
    reg [31:0] y;
    begin
        y = x ^ (x << 13);
        y = y ^ (y >> 17);
        y = y ^ (y << 5);
        xorshift32 = y;
    end
endfunction

// rand_below: the next value in [0, n)
task rand_below(input integer n, output integer value);
    begin
        rng   = xorshift32(rng);
        value = rng % n;
    end
endtask

/*
random_register_traffic: n random transactions while the converter runs, each
predicted by the shadow and checked by it every clock and on every read. The
mix covers keyed writes of the run-time thresholds with out-of-range values,
unkeyed writes, keyed writes that reach the S_OFF-only registers (rejected while
running), bad-CRC writes, SCRATCH writes and burst reads. CONTROL is excluded:
a disable would end the clean-run window this traffic runs inside.
*/
task random_register_traffic(input integer n);
    integer t, kind, k, nvals, base, len, value;
    begin
        for (t = 0; t < n; t = t + 1) begin
            rand_below(8, kind);
            case (kind)
                0, 1: begin   // keyed write of 1..4 run-time thresholds
                    rand_below(4, nvals);
                    spi_tx[0] = WRITE_KEY;
                    for (k = 1; k <= nvals + 1; k = k + 1) begin
                        rand_below(64, value);
                        spi_tx[k] = value;
                    end
                    spi_write(A_WRKEY, nvals + 2, 1'b0);
                end
                2: begin      // unkeyed threshold write: locked out
                    rand_below(4, base);
                    rand_below(256, value);
                    spi_tx[0] = value;
                    spi_write(A_TRIP_RUN + base, 1, 1'b0);
                end
                3: begin      // keyed, reaching S_OFF-only registers while running
                    spi_tx[0] = WRITE_KEY;
                    spi_tx[1] = sh_trip_run; spi_tx[2] = sh_trip_ss;
                    spi_tx[3] = sh_max_strikes; spi_tx[4] = sh_max_on;
                    for (k = 5; k <= 8; k = k + 1) begin
                        rand_below(256, value);
                        spi_tx[k] = value;
                    end
                    spi_write(A_WRKEY, 9, 1'b0);
                end
                4: begin      // keyed write with a bad CRC: nothing commits
                    spi_tx[0] = WRITE_KEY;
                    rand_below(256, value);
                    spi_tx[1] = value;
                    spi_write(A_WRKEY, 2, 1'b1);
                end
                5: begin      // SCRATCH, occasionally with a bad CRC
                    rand_below(256, value);
                    spi_tx[0] = value;
                    rand_below(4, k);
                    spi_write(A_SCRATCH, 1, k == 0);
                end
                default: begin // burst read of shadowed addresses
                    rand_below(12, base);
                    rand_below(4, len);
                    if (base == 11) spi_read(A_SCRATCH, 1);
                    else            spi_read(A_TRIP_RUN + base, (base + len + 1 > 11) ? 11 - base : len + 1);
                end
            endcase
        end
    end
endtask

/*
random_duty_corners: n random modulator duties in S_RUN. Below the ceiling the
pulse passes through, quantised to whole clocks; above it the backstop cuts it
to MAX_ON_COUNTS + 1 clocks. Within a clock of the ceiling either is correct.
*/
task random_duty_corners(input integer n);
    integer t, pct, ok;
    real    ceiling_ns;
    begin
        ceiling_ns = (MAX_ON_COUNTS + 1) * CLK_PERIOD_NS;
        for (t = 0; t < n; t = t + 1) begin
            rand_below(91, pct);
            osc_high_ns = SW_PERIOD_NS * (pct + 5) / 100.0;
            #(4.0 * SW_PERIOD_NS);
            @(negedge PWM_out);
            #(1.0);   // let the pulse monitor, woken by the same edge, record it
            if (osc_high_ns < ceiling_ns - CLK_PERIOD_NS)
                ok = (pwm_width_ns >= osc_high_ns - CLK_PERIOD_NS - 1.0) &&
                     (pwm_width_ns <= osc_high_ns + CLK_PERIOD_NS + 1.0);
            else if (osc_high_ns > ceiling_ns + CLK_PERIOD_NS)
                ok = (pwm_width_ns > ceiling_ns - 1.0) && (pwm_width_ns < ceiling_ns + 1.0);
            else
                ok = (pwm_width_ns <= ceiling_ns + 1.0);
            $sformat(msg, "random duty %0d%%: PWM_out pulse vs pass-through / backstop", pct + 5);
            check(msg, ok);
        end
        osc_high_ns = SW_PERIOD_NS / 2.0;
    end
endtask

/*
random_glitch_corners: n OTP pulses of random width between 100 us and 900 us,
all shorter than the 1 ms assert debounce. None may stop the converter, and
none may break the clean-run streak.
*/
task random_glitch_corners(input integer n);
    integer t, width_us;
    begin
        for (t = 0; t < n; t = t + 1) begin
            rand_below(801, width_us);
            OTP_trig = 1'b1;
            #((width_us + 100) * US);
            OTP_trig = 1'b0;
            #(300.0 * US);
            $sformat(msg, "OTP glitch of %0d us rejected: En still high, Red_LED2 dark", width_us + 100);
            check(msg, (En === 1'b1) && (Red_LED2 === 1'b0));
        end
    end
endtask

/*
random_ignored_traffic: n random SPI frames for the reduced build - keyed
disables, keyed threshold writes of random values, SCRATCH writes and reads.
A full build would act on many of them; the reduced build has no slave, so the
window this runs in checks that En never drops, the strike clears on the
default 1 s schedule and every read returns nothing on MISO.
*/
task random_ignored_traffic(input integer n);
    integer t, kind, k, value;
    begin
        for (t = 0; t < n; t = t + 1) begin
            rand_below(4, kind);
            case (kind)
                0: begin       // keyed disable: DISKEY, then CONTROL = 0
                    spi_tx[0] = DISABLE_KEY;
                    spi_tx[1] = 8'h00;
                    spi_frame_ignored(A_DISKEY, 2);
                end
                1: begin       // keyed write of the four run-time thresholds
                    spi_tx[0] = WRITE_KEY;
                    for (k = 1; k <= 4; k = k + 1) begin
                        rand_below(256, value);
                        spi_tx[k] = value;
                    end
                    spi_frame_ignored(A_WRKEY, 5);
                end
                2: begin       // SCRATCH write
                    rand_below(256, value);
                    spi_tx[0] = value;
                    spi_frame_ignored(A_SCRATCH, 1);
                end
                default: begin // two-byte read of ID, STATUS, thresholds or SCRATCH
                    rand_below(4, k);
                    case (k)
                        0:       spi_read_ignored(A_ID, 2);
                        1:       spi_read_ignored(A_STATUS, 2);
                        2:       spi_read_ignored(A_TRIP_RUN, 2);
                        default: spi_read_ignored(A_SCRATCH, 2);
                    endcase
                end
            endcase
        end
    end
endtask


// ============================================================
// Verdict
// ============================================================
task finish_run(input [8*48:1] reason);
    begin
        print_coverage;
        emit("--------------------------------------------------");
        $sformat(msg, "exit            : %0s", reason);       emit(msg);
        $sformat(msg, "clock           : %0d Hz", CLK_HZ);    emit(msg);
        if (TELEMETRY_EN) emit("TELEMETRY_EN    : 1 (full build, SPI sequence)");
        else              emit("TELEMETRY_EN    : 0 (reduced build, pins-only sequence)");
        $sformat(msg, "random seed     : 0x%h", LFSR_SEED);   emit(msg);
        $sformat(msg, "checks run      : %0d", checks_run);   emit(msg);
        $sformat(msg, "checks failed   : %0d", checks_failed); emit(msg);
        if (cov_applicable == NB)
            $sformat(msg, "coverage        : %0d of %0d bins", NB - cov_missed, NB);
        else
            $sformat(msg, "coverage        : %0d of %0d bins (%0d n/a without telemetry)",
                     cov_applicable - cov_missed, cov_applicable, NB - cov_applicable);
        emit(msg);
        if ((checks_failed == 0) && (cov_missed == 0)) emit("pmic_top_tb: PASS");
        else                                           emit("pmic_top_tb: FAIL");
        emit("--------------------------------------------------");
        if (log_fd != 0) $fclose(log_fd);
        if ((checks_failed == 0) && (cov_missed == 0)) $finish;
        else                                           $stop;
    end
endtask

/*
Purpose:
---
Hard stop on absolute time, so a stalled run still reports a verdict.
*/
initial begin
    #(WATCHDOG_NS);
    checks_failed = checks_failed + 1;
    finish_run("WATCHDOG - did not complete");
end

/*
Purpose:
---
VCD only on request (+WAVES); the full run is several hundred ms of simulated
time.
*/
initial begin
    if ($test$plusargs("WAVES")) begin
        $dumpfile("pmic_top_tb.vcd");
        $dumpvars(0, pmic_top_tb);
    end
end


// ============================================================
// Stimulus
// ============================================================
integer idx;
integer bus_err_before;
integer strike_hiccups;
integer value24;
integer pulses_before;
integer red1_before, en_falls_before;
real    t_event, t_en_rise, t_cs_filt, t_strike;
reg [23:0] ts_force;
reg [23:0] carry_at;

// ============================================================
// Phases 14 onward - run by both sequences after phase 13. They close the
// gaps a second review of the stimulus found: every fault from every state
// it can arrive in (the cross bins), the overcurrent window's exact
// threshold, strike escalation and the clean-run window restarting, glitch
// and chatter rejection on the other inputs, overlapping faults, reset while
// running, and - with telemetry - programmed thresholds reaching the
// protection and the SPI corners.
// ============================================================
// hic_base_ns: hiccup base in force from phase 14 on - the 1 ms the SPI
//              sequence configures, or the 5 ms default without telemetry
real    hic_base_ns;
real    t_mark, hic_dur1, hic_dur2, t_run2;
integer en_falls_mark, k_trip, fmax, s_mark;

// oc_trip: hold the overcurrent comparator until the converter stops, then
//          release it
task oc_trip;
    begin
        CP_trig = 1'b1;
        wait_en(1'b0, 200.0 * US);
        CP_trig = 1'b0;
    end
endtask

// reset_and_config: the reset button. The SPI build then sets the short
//                   timers again while the 20 ms switch debounce runs.
//                   Returns when the converter is enabled (in soft start).
task reset_and_config;
    begin
        do_reset;
        if (TELEMETRY_EN) begin
            #(300.0 * US);
            write_thresholds(TRIP_RUN_DEF, TRIP_SS_DEF, MAX_STRIKES_DEF, MAX_ON_COUNTS,
                             HICCUP_MIN, CYC_STEP_DEF, CLEAN_SHORT);
        end
        wait_en(1'b1, 21.0 * MS);
    end
endtask

// count_to_trip: put the comparator in fault from just after one rising edge
//                of the modulator onward - the arbiter samples it about
//                500 ns before each rise, so a level set just after a rise is
//                taken at the next one, at any duty - until En drops; k_trip
//                is the number of faulted samples it took
task count_to_trip(input integer limit);
    begin
        k_trip = 0;
        @(posedge Osc_in);
        #(8.0 * CLK_PERIOD_NS);
        while ((En === 1'b1) && (k_trip < limit)) begin
            CP_trig = 1'b1;
            k_trip = k_trip + 1;
            @(posedge Osc_in);
            #(8.0 * CLK_PERIOD_NS);
        end
        CP_trig = 1'b0;
    end
endtask

/*
Phase 14: reset while running. Every output must go safe in the same instant
the button is pressed (the flops reset asynchronously), and the restart must
wait out the 20 ms switch debounce again. With telemetry the reset also cuts
an SPI write in half; the next transaction must work.
*/
task phase_reset_running;
    begin
        note("Phase 14: reset while running - outputs safe at once, restart only after the switch debounce");
        osc_high_ns = SW_PERIOD_NS / 2.0;
        wait_sup_state(ST_RUN, 15.0 * MS);
        wait_pgood(1'b1, 10.0 * MS);
        check("before the reset: running with PGOOD qualified", (sup_state === ST_RUN) && (PGOOD === 1'b1));
        if (TELEMETRY_EN) begin
            spi_busy = 1'b1;
            CS_n = 1'b0;
            #(SPI_HALF_NS);
            spi_send_byte({1'b0, A_SCRATCH});
            spi_send_bits(8'hA5, 4);
        end
        rst_n_pin = 1'b0;
        #(1.0);
        check("reset while running: En low at once", En === 1'b0);
        check("reset while running: PWM_out low at once", PWM_out === 1'b0);
        check("reset while running: PGOOD and switch_supply low at once", (PGOOD === 1'b0) && (switch_supply === 1'b0));
        check("reset while running: latch_out and MISO low", (latch_out === 1'b0) && (MISO === 1'b0));
        if ((En === 1'b0) && (PWM_out === 1'b0) && (PGOOD === 1'b0)) cover_bin(C_RST_RUN);
        CS_n = 1'b1;
        MOSI = 1'b0;
        #(10.0 * CLK_PERIOD_NS);
        shadow_reset;
        rst_n_pin = 1'b1;
        t_mark = $realtime;
        #(10.0 * CLK_PERIOD_NS);
        spi_busy = 1'b0;
        if (TELEMETRY_EN) begin
            reg_read(A_ID);      check_eq("reset mid-transaction: the next transaction works (PMIC_ID)", rd_val, 8'hB5);
            if (rd_val == 8'hB5) cover_bin(C_SPI_RST);
            reg_read(A_SCRATCH); check_eq("reset mid-transaction: SCRATCH at its reset value", rd_val, 8'h00);
            write_thresholds(TRIP_RUN_DEF, TRIP_SS_DEF, MAX_STRIKES_DEF, MAX_ON_COUNTS,
                             HICCUP_MIN, CYC_STEP_DEF, CLEAN_SHORT);
        end
        if ($realtime < t_mark + 19.8 * MS) #(t_mark + 19.8 * MS - $realtime);
        check("after the reset: still off 19.8 ms after release (switch debounce restarts)", En === 1'b0);
        wait_en(1'b1, 1.0 * MS);
        check_range("after the reset: restart after release (ms)", ($realtime - t_mark) / MS, 19.99, 20.05);
        wait_sup_state(ST_RUN, 15.0 * MS);
        check_eq("after the reset: S_RUN (probe)", last_state, ST_RUN);
    end
endtask

/*
Phase 15: every fault from every state it can arrive in - the cross of cause
and source state that phases 1-13 left open: OTP and OVP in soft start, UVLO
and OVP in a hiccup, the enable switch in soft start and in a hiccup, and with
telemetry the host disable in both. A soft start is reached through the
200 us restart after a UVLO pulse, or - for the 20 ms switch debounce - through
a hiccup retry timed to be ramping when the debounce completes. Each check
reads the state the supervisor left for S_OFF.
*/
task phase_fault_by_state;
    real t0;
    begin
        note("Phase 15: every fault from every state it can arrive in");
        // (a) over-temperature during soft start
        UVLO_trig = 1'b1;
        wait_en(1'b0, 2.0 * MS);
        UVLO_trig = 1'b0;
        wait_sup_state(ST_SS, 1.0 * MS);
        #(100.0 * US);
        OTP_trig = 1'b1;
        wait_en(1'b0, 2.0 * MS);
        #(10.0 * CLK_PERIOD_NS);
        check_eq("OTP in soft start: S_OFF entered from S_SS (probe)", last_off_from, ST_SS);
        OTP_trig = 1'b0;
        wait_en(1'b1, 1.0 * MS);
        wait_sup_state(ST_RUN, 15.0 * MS);
        check_eq("back in S_RUN after OTP in soft start (probe)", last_state, ST_RUN);
        // (b) undervoltage during a hiccup cool-down
        oc_trip;
        UVLO_trig = 1'b1;
        #(1.5 * MS);
        check_eq("UVLO in a hiccup: S_OFF entered from S_HICCUP (probe)", last_off_from, ST_HICCUP);
        check_eq("UVLO in a hiccup: in S_OFF, not retrying (probe)", sup_state, ST_OFF);
        UVLO_trig = 1'b0;
        wait_en(1'b1, 1.0 * MS);
        wait_sup_state(ST_RUN, 15.0 * MS);
        check_eq("back in S_RUN after UVLO in a hiccup (probe)", last_state, ST_RUN);
        // (c) analog OVP during a hiccup cool-down
        oc_trip;
        ovp_event = 1'b1;
        #(1.5 * MS);
        check_eq("OVP in a hiccup: S_OFF entered from S_HICCUP (probe)", last_off_from, ST_HICCUP);
        ovp_event = 1'b0;
        #(1.0 * MS);
        check("OVP in a hiccup: no restart while the SCR is latched", En === 1'b0);
        reset_and_config;
        wait_sup_state(ST_RUN, 15.0 * MS);
        // (d) analog OVP during soft start
        UVLO_trig = 1'b1;
        wait_en(1'b0, 2.0 * MS);
        UVLO_trig = 1'b0;
        wait_sup_state(ST_SS, 1.0 * MS);
        // let En settle first: the state probe can wake this process in the
        // same instant the state changes, before the enable logic follows
        #(100.0 * US);
        ovp_event = 1'b1;
        wait_en(1'b0, 2.0 * MS);
        #(10.0 * CLK_PERIOD_NS);
        check_eq("OVP in soft start: S_OFF entered from S_SS (probe)", last_off_from, ST_SS);
        ovp_event = 1'b0;
        reset_and_config;
        wait_sup_state(ST_RUN, 15.0 * MS);
        // (e) enable switch released during soft start: a hiccup retry
        //     starts the ramp about 1 ms before the 20 ms debounce completes
        t0 = $realtime;
        en_from_switch = 1'b0;
        #(19.0 * MS - 2.0 * hic_base_ns);
        oc_trip;
        wait_en(1'b1, 2.0 * hic_base_ns + 1.0 * MS);
        wait_en(1'b0, 2.0 * MS);
        #(10.0 * CLK_PERIOD_NS);
        check_eq("switch released in soft start: S_OFF entered from S_SS (probe)", last_off_from, ST_SS);
        check_range("switch released in soft start: off after (ms)", ($realtime - t0) / MS, 19.99, 20.06);
        en_from_switch = 1'b1;
        wait_en(1'b1, 21.0 * MS);
        wait_sup_state(ST_RUN, 15.0 * MS);
        // (f) enable switch released during a hiccup cool-down: the second
        //     strike's 4 x base cool-down spans the moment the debounce completes
        t0 = $realtime;
        en_from_switch = 1'b0;
        #(20.0 * MS - 2.0 * hic_base_ns);
        oc_trip;
        if ($realtime < t0 + 20.5 * MS) #(t0 + 20.5 * MS - $realtime);
        check_eq("switch released in a hiccup: S_OFF entered from S_HICCUP (probe)", last_off_from, ST_HICCUP);
        check_eq("switch released in a hiccup: in S_OFF, not retrying (probe)", sup_state, ST_OFF);
        en_from_switch = 1'b1;
        if (TELEMETRY_EN) begin
            // (g) host disable during soft start
            reset_and_config;
            spi_tx[0] = DISABLE_KEY; spi_tx[1] = 8'h00;
            spi_write(A_DISKEY, 2, 1'b0);
            #(10.0 * CLK_PERIOD_NS);
            check_eq("host disable in soft start: S_OFF entered from S_SS (probe)", last_off_from, ST_SS);
            reg_write(A_CONTROL, 8'h01);
            wait_en(1'b1, 100.0 * US);
            wait_sup_state(ST_RUN, 15.0 * MS);
            // (h) host disable during a hiccup cool-down
            oc_trip;
            spi_tx[0] = DISABLE_KEY; spi_tx[1] = 8'h00;
            spi_write(A_DISKEY, 2, 1'b0);
            #(10.0 * CLK_PERIOD_NS);
            check_eq("host disable in a hiccup: S_OFF entered from S_HICCUP (probe)", last_off_from, ST_HICCUP);
            reg_write(A_CONTROL, 8'h01);
            wait_en(1'b1, 100.0 * US);
            wait_sup_state(ST_RUN, 15.0 * MS);
        end
        reset_and_config;
        wait_sup_state(ST_RUN, 15.0 * MS);
    end
endtask

/*
Phase 16: the overcurrent window's threshold, exactly. With 11 faulted cycles
in every 16 the rolling count must peak at 11 and never trip; from a clean
window, consecutive faulted cycles must trip on the 12th and not before.
*/
task phase_window_boundary;
    integer blk, i;
    begin
        note("Phase 16: overcurrent window - 11 of every 16 holds, the 12th consecutive trips");
        en_falls_mark = en_falls;
        CP_trig = 1'b0;
        repeat (16) @(posedge Osc_in);
        #(8.0 * CLK_PERIOD_NS);
        fmax = 0;
        for (blk = 0; blk < 4; blk = blk + 1)
            for (i = 0; i < 16; i = i + 1) begin
                CP_trig = (i < TRIP_RUN_DEF - 1);   // taken at the next rise
                @(posedge Osc_in);
                #(8.0 * CLK_PERIOD_NS);
                if (fcount_run_int > fmax) fmax = fcount_run_int;
            end
        CP_trig = 1'b0;
        check_eq("11 faulted cycles in every 16: the run window peaks at 11", fmax, TRIP_RUN_DEF - 1);
        check("11 faulted cycles in every 16: no trip, still running",
              (en_falls == en_falls_mark) && (sup_state === ST_RUN));
        if ((fmax == TRIP_RUN_DEF - 1) && (en_falls == en_falls_mark)) cover_bin(C_WIN_HOLD);
        repeat (16) @(posedge Osc_in);
        count_to_trip(20);
        check_eq("consecutive faulted cycles from a clean window: trip on exactly the 12th", k_trip, TRIP_RUN_DEF);
        if (k_trip == TRIP_RUN_DEF) cover_bin(C_WIN_EXACT);
        wait_en(1'b1, 2.0 * hic_base_ns + 1.0 * MS);
        hic_dur1 = $realtime - en_fall_t;
        check_range("first hiccup (ms) = 2 x base", hic_dur1 / MS,
                    2.0 * hic_base_ns / MS - 0.01, 2.0 * hic_base_ns / MS + 0.05);
        wait_sup_state(ST_RUN, 15.0 * MS);
    end
endtask

/*
Phase 17 (telemetry build; the pins-only build does this in its phase 7, on
the default timers): a second strike inside the clean-run window. The
cool-down must double, the strike must not clear, and the window must start
again from the latest S_RUN entry - a window that kept counting from the
first entry would clear the strike some 35 ms early.
*/
task phase_escalation;
    begin
        note("Phase 17: second strike inside the clean-run window - escalation, and the window restarts");
        #(30.0 * MS);
        check_eq("strike outstanding before the second trip (probe)", strike_int, 1);
        oc_trip;
        wait_en(1'b1, 4.0 * hic_base_ns + 1.0 * MS);
        hic_dur2 = $realtime - en_fall_t;
        check_range("second hiccup (ms) = 4 x base", hic_dur2 / MS,
                    4.0 * hic_base_ns / MS - 0.01, 4.0 * hic_base_ns / MS + 0.05);
        check_range("second hiccup / first hiccup", hic_dur2 / hic_dur1, 1.98, 2.02);
        check_eq("interrupted window: strike level 2, not cleared (probe)", strike_int, 2);
        if ((hic_dur2 / hic_dur1 > 1.98) && (hic_dur2 / hic_dur1 < 2.02)) cover_bin(C_ESC2);
        wait_sup_state(ST_RUN, 15.0 * MS);
        #(5.0 * CLK_PERIOD_NS);   // the scoreboard stamps the entry a clock later
        t_run2 = t_last_run_entry;
        wait_strike(2'd0, t_run2 + CLEAN_SHORT * SW_PERIOD_NS + 5.0 * MS - $realtime);
        check("strikes cleared after the interrupted window", timed_out === 1'b0);
        check_range("window restarted: cleared one full window after the latest S_RUN entry (ms)",
                    ($realtime - t_run2) / MS,
                    CLEAN_SHORT * SW_PERIOD_NS / MS - 0.5, CLEAN_SHORT * SW_PERIOD_NS / MS + 0.5);
        if ((timed_out === 1'b0) && ($realtime - t_run2 > CLEAN_SHORT * SW_PERIOD_NS - 0.5 * MS))
            cover_bin(C_CLEAN_RESTART);
    end
endtask

/*
Phase 18: the rest of the input conditioning, and fault overlap. A UVLO pulse
and a latch-readback pulse shorter than the 1 ms debounce and an enable
switch open for 10 ms (under its 20 ms debounce) must all leave the converter
running. OTP and UVLO overlapping must hold it off until the second clears.
A strike outstanding before a fault-off must still be there after the
restart: only a clean run or the reset button clears strikes.
*/
task phase_robustness;
    begin
        note("Phase 18: UVLO and latch glitches, switch chatter, overlapping faults, strikes kept across a fault");
        if (strike_int == 2'd0) begin
            oc_trip;
            wait_en(1'b1, 2.0 * hic_base_ns + 1.0 * MS);
            wait_sup_state(ST_RUN, 15.0 * MS);
        end
        s_mark = strike_int;
        en_falls_mark = en_falls;
        UVLO_trig = 1'b1; #(500.0 * US); UVLO_trig = 1'b0; #(300.0 * US);
        check("UVLO glitch of 500 us rejected: En still high, Red_LED3 dark", (En === 1'b1) && (Red_LED3 === 1'b0));
        latch_glitch = 1'b1; #(500.0 * US); latch_glitch = 1'b0; #(300.0 * US);
        check("latch_stat glitch of 500 us rejected: En still high, latch not taken",
              (En === 1'b1) && (latch_db_int === 1'b0));
        en_from_switch = 1'b0; #(10.0 * MS); en_from_switch = 1'b1; #(1.0 * MS);
        check("enable switch open 10 ms (under the 20 ms debounce): still running",
              (En === 1'b1) && (sup_state === ST_RUN));
        check_eq("no En fall through the three glitches", en_falls - en_falls_mark, 0);
        if ((En === 1'b1) && (en_falls == en_falls_mark)) cover_bin(C_SW_CHATTER);
        // overlapping OTP and UVLO: off on the first, back only after the second
        t_mark = $realtime;
        OTP_trig = 1'b1;
        #(0.5 * MS);
        UVLO_trig = 1'b1;
        wait_en(1'b0, 1.0 * MS);
        if ($realtime < t_mark + 2.0 * MS) #(t_mark + 2.0 * MS - $realtime);
        OTP_trig = 1'b0;
        #(0.5 * MS);
        check("OTP cleared, UVLO still present: still off", (En === 1'b0) && (Red_LED3 === 1'b1));
        UVLO_trig = 1'b0;
        t_mark = $realtime;
        wait_en(1'b1, 0.5 * MS);
        check_range("both cleared: restart after the last one clears (us)", ($realtime - t_mark) / US, 199.0, 205.0);
        if (timed_out === 1'b0) cover_bin(C_OVERLAP);
        wait_sup_state(ST_RUN, 15.0 * MS);
        check_eq("strikes kept across a fault-off and restart (probe)", strike_int, s_mark);
        if ((strike_int == s_mark) && (s_mark != 0)) cover_bin(C_STRK_PERSIST);
    end
endtask

/*
Phase 19 (telemetry build): programmed thresholds reach the protection, not
just the register file. Written in S_OFF after a reset: TRIP_SS = 6 must trip
the first ramp on the 6th faulted cycle; the retry's ramp must step every 8
cycles (CYCLES_PER_STEP) and top out at MAX_ON = MIN_ON + 7 (10 counts at
10 MHz), cutting a 90% command at MAX_ON + 1 clocks; TRIP_RUN = 4 must trip
S_RUN on the 4th faulted cycle. Then, from a clean slate, MAX_STRIKES = 1 must
latch on the first strike.
*/
task phase_register_effects;
    integer mo;
    begin
        mo = MIN_ON_COUNTS + 7;
        note("Phase 19: programmed thresholds reach the protection - TRIP_SS, CYCLES_PER_STEP, MAX_ON, TRIP_RUN, MAX_STRIKES");
        do_reset;
        #(300.0 * US);
        write_thresholds(8'd4, 8'd6, MAX_STRIKES_DEF, mo, HICCUP_MIN, 8'd8, CLEAN_SHORT);
        osc_high_ns = 2000.0;
        wait_en(1'b1, 21.0 * MS);
        #(100.0 * US);
        count_to_trip(40);
        check_eq("TRIP_SS = 6: the ramp trips on the 6th faulted cycle", k_trip, 6);
        #(10.0 * CLK_PERIOD_NS);
        check_eq("TRIP_SS = 6: S_HICCUP from soft start (probe)", sup_state, ST_HICCUP);
        if (k_trip == 6) cover_bin(C_REG_TRIP_SS);
        wait_en(1'b1, 3.0 * MS);
        t_en_rise = $realtime;
        measure_ramp(20.0 * MS, 8, mo);
        check_eq("CYCLES_PER_STEP = 8: plateaus of 8 cycles (bad count)", ramp_bad_plateau, 0);
        check_eq("MAX_ON = MIN_ON + 7: ramp levels MIN..MAX_ON", ramp_levels, mo - MIN_ON_COUNTS + 1);
        check_range("CYCLES_PER_STEP = 8: ramp duration En->ceiling (switching cycles)",
                    (ramp_t_ceiling - t_en_rise) / SW_PERIOD_NS,
                    (mo - MIN_ON_COUNTS) * 8 - 2.0, (mo - MIN_ON_COUNTS) * 8 + 2.0);
        if ((ramp_bad_plateau == 0) && (ramp_levels == mo - MIN_ON_COUNTS + 1)) cover_bin(C_REG_CYC);
        wait_sup_state(ST_RUN, 1.0 * MS);
        #(50.0 * US);
        check_range("MAX_ON = MIN_ON + 7: 90% commanded in S_RUN, PWM_out cut at MAX_ON+1 clocks (ns)",
                    pwm_width_ns, (mo + 1) * CLK_PERIOD_NS - 1.0, (mo + 1) * CLK_PERIOD_NS + 1.0);
        if ((pwm_width_ns > (mo + 1) * CLK_PERIOD_NS - 1.0) && (pwm_width_ns < (mo + 1) * CLK_PERIOD_NS + 1.0))
            cover_bin(C_REG_MAX_ON);
        osc_high_ns = SW_PERIOD_NS / 2.0;
        repeat (4) @(posedge Osc_in);
        count_to_trip(20);
        check_eq("TRIP_RUN = 4: S_RUN trips on the 4th faulted cycle", k_trip, 4);
        if (k_trip == 4) cover_bin(C_REG_TRIP_RUN);
        do_reset;
        #(300.0 * US);
        write_thresholds(TRIP_RUN_DEF, TRIP_SS_DEF, 8'd1, MAX_ON_COUNTS, HICCUP_MIN, CYC_STEP_DEF, CLEAN_SHORT);
        wait_en(1'b1, 21.0 * MS);
        wait_sup_state(ST_RUN, 15.0 * MS);
        oc_trip;
        #(10.0 * CLK_PERIOD_NS);
        check("MAX_STRIKES = 1: the first strike sets latch_out", latch_out === 1'b1);
        check_eq("MAX_STRIKES = 1: strike level 1 at the latch (probe)", strike_int, 1);
        if (latch_out === 1'b1) cover_bin(C_REG_STRIKES);
        #(2.0 * MS);
        check("MAX_STRIKES = 1: no retry after the latch", En === 1'b0);
        reset_and_config;
        wait_sup_state(ST_RUN, 15.0 * MS);
    end
endtask

// spi_read_glitched: a one-byte read with an SCK pulse and a CS_n pulse of 3
//                    clocks each between the command and the turnaround byte -
//                    shorter than the 8-clock input filter (800 ns at 10 MHz)
task spi_read_glitched(input [6:0] addr);
    reg [7:0] turnaround;
    begin
        CS_n = 1'b0;
        #(SPI_HALF_NS);
        spi_send_byte({1'b1, addr});
        #(SPI_HALF_NS / 2.0);
        SCK = 1'b1; #(3.0 * CLK_PERIOD_NS); SCK = 1'b0;
        #(SPI_HALF_NS / 2.0);
        CS_n = 1'b1; #(3.0 * CLK_PERIOD_NS); CS_n = 1'b0;
        spi_recv_byte(turnaround, 1'b0);
        reads_issued = reads_issued + 1;
        spi_recv_byte(rd_val, 1'b1);
        #(SPI_HALF_NS) CS_n = 1'b1;
        #(SPI_GAP_NS);
    end
endtask

/*
Phase 20 (telemetry build): SPI corners - a write to a read-only register,
reads of unmapped addresses, a burst read across the top of the 7-bit map,
and SCK and CS_n glitches inside a frame.
*/
task phase_spi_corners;
    begin
        note("Phase 20: SPI corners - read-only and unmapped addresses, address wrap, glitches under the filter");
        reg_write(A_ID, 8'h00);
        reg_read(A_ID);    check_eq("write to the read-only PMIC_ID ignored", rd_val, 8'hB5);
        if (rd_val == 8'hB5) cover_bin(C_SPI_RO);
        reg_read(7'h30);   check_eq("unmapped address 0x30 reads 0", rd_val, 8'h00);
        reg_read(7'h7F);   check_eq("unmapped address 0x7F reads 0", rd_val, 8'h00);
        spi_read(7'h7E, 4);
        check("burst read wraps 0x7F -> 0x00: 0, 0, PMIC_ID, VERSION",
              (spi_rx[0] === 8'h00) && (spi_rx[1] === 8'h00) && (spi_rx[2] === 8'hB5) && (spi_rx[3] === 8'h01));
        if ((spi_rx[2] === 8'hB5) && (spi_rx[3] === 8'h01)) cover_bin(C_SPI_WRAP);
        spi_read_glitched(A_ID);
        check_eq("3-clock SCK and CS_n glitches inside a frame (filter is 8): the read is unaffected", rd_val, 8'hB5);
        if (rd_val == 8'hB5) cover_bin(C_SPI_GLITCH);
    end
endtask

// extra_phases: 14 onward, in order
task extra_phases;
    begin
        hic_base_ns = TELEMETRY_EN ? HICCUP_MIN * CLK_PERIOD_NS : HICCUP_DEF * CLK_PERIOD_NS;
        phase_reset_running;
        phase_fault_by_state;
        phase_window_boundary;
        if (TELEMETRY_EN) phase_escalation;
        phase_robustness;
        if (TELEMETRY_EN) begin
            phase_register_effects;
            phase_spi_corners;
        end
    end
endtask


// The two sequences sit in generate branches: the SPI sequence forces two
// registers inside the SPI slave and the register file, which exist only in
// the full build, so it cannot even be elaborated against the reduced one.
generate
if (TELEMETRY_EN) begin : g_seq_tel

/*
Purpose:
---
The SPI sequence, for the full build (TELEMETRY_EN = 1): the directed phases,
in order. Most checks are inline; the monitors, scoreboards and coverage run
underneath for the whole run.
*/
initial begin
    log_fd = $fopen("pmic_top_tb.log", "w");
    shadow_reset;
    $sformat(msg, "==== pmic_top_tb : CLK_HZ = %0d, MIN_ON = %0d, MAX_ON = %0d clocks, TELEMETRY_EN = 1 ====",
             CLK_HZ, MIN_ON_COUNTS, MAX_ON_COUNTS);
    emit(msg);

    // ---------------------------------------------------------------
    // Phase 1: reset, fail-safe outputs, identity, defaults
    // ---------------------------------------------------------------
    note("Phase 1: power-on reset and defaults");
    #1;
    rst_n_pin = 1'b0;
    #(10.0 * CLK_PERIOD_NS);
    check("in reset: En low",                 En === 1'b0);
    check("in reset: PGOOD low",              PGOOD === 1'b0);
    check("in reset: latch_out low",          latch_out === 1'b0);
    check("in reset: MISO low",               MISO === 1'b0);
    rst_n_pin = 1'b1;
    #(10.0 * CLK_PERIOD_NS);
    spi_busy = 1'b0;
    #(20.0 * US);
    // The fault debouncers reset to FAULT and need the 200 us release time of a
    // healthy comparator before they clear.
    check("after reset: Red_LED2 (OTP) fail-safe lit",  Red_LED2 === 1'b1);
    check("after reset: Red_LED3 (UVLO) fail-safe lit", Red_LED3 === 1'b1);
    #(250.0 * US);
    check("Red_LED2 cleared after 200 us release", Red_LED2 === 1'b0);
    check("Red_LED3 cleared after 200 us release", Red_LED3 === 1'b0);
    check("switch off: En stays low", En === 1'b0);
    // In S_OFF pwm_mask holds the floor, so PWM_out shows the minimum on-time
    // even with the modulator commanding 90%: the MIN_ON_COUNTS rounding fix.
    check_range("PWM_out pulse in S_OFF (ns) = (MIN_ON_COUNTS+1) clocks", pwm_width_ns,
                (MIN_ON_COUNTS + 1) * CLK_PERIOD_NS - 1.0, (MIN_ON_COUNTS + 1) * CLK_PERIOD_NS + 1.0);
    check("minimum gate pulse >= 240 ns commanded (LM5106 128 ns + 112 ns)", pwm_width_ns >= 240.0);
    reg_read(A_ID);         check_eq("PMIC_ID", rd_val, 8'hB5);
    reg_read(A_VERSION);    check_eq("VERSION", rd_val, 8'h01);
    reg_read(A_CAPABILITY); check_eq("CAPABILITY", rd_val, 8'h3D);
    reg_read(A_STATUS);
    check_eq("STATUS state = S_OFF", rd_val[1:0], ST_OFF);
    check("STATUS spi_enable = 1 out of reset", rd_val[5] === 1'b1);
    check("STATUS en_switch = 0", rd_val[4] === 1'b0);
    read_thresholds;
    check_eq("TRIP_RUN default", spi_rx[0], TRIP_RUN_DEF);
    check_eq("TRIP_SS default", spi_rx[1], TRIP_SS_DEF);
    check_eq("MAX_STRIKES default", spi_rx[2], MAX_STRIKES_DEF);
    check_eq("MAX_ON default = duty_to_counts(75)", spi_rx[3], MAX_ON_COUNTS);
    check_eq("HICCUP_BASE default = 5 ms of clocks", {spi_rx[6], spi_rx[5], spi_rx[4]}, HICCUP_DEF);
    check_eq("CYCLES_PER_STEP default", spi_rx[7], CYC_STEP_DEF);
    check_eq("CLEAN_RUN default = 1 s of cycles", {spi_rx[10], spi_rx[9], spi_rx[8]}, CLEAN_DEF);

    // ---------------------------------------------------------------
    // Phase 2: SPI protocol and register map
    // ---------------------------------------------------------------
    note("Phase 2: SPI protocol and register map");
    reg_write(A_SCRATCH, 8'h5A);
    reg_read(A_SCRATCH);        check_eq("single write/read SCRATCH 0x03", rd_val, 8'h5A);
    reg_read(A_SCRATCH + 7'd1); check_eq("neighbour 0x04 untouched (unimplemented, reads 0)", rd_val, 8'h00);
    // a single register at mid-map: the key and one data byte, TRIP_RUN at 0x50
    spi_tx[0] = WRITE_KEY; spi_tx[1] = 8'd9;
    spi_write(A_WRKEY, 2, 1'b0);
    reg_read(A_TRIP_RUN);  check_eq("single keyed write/read TRIP_RUN 0x50", rd_val, 9);
    reg_read(A_TRIP_SS);   check_eq("neighbour TRIP_SS 0x51 untouched", rd_val, TRIP_SS_DEF);
    reg_read(A_STATUS);    check("STATUS write_rejected = 0 after keyed write", rd_val[7] === 1'b0);
    // a 3-byte value in a burst write, read back as a 3-byte burst
    value24 = 24'h012345 + HICCUP_MIN;
    write_thresholds(TRIP_RUN_DEF, TRIP_SS_DEF, MAX_STRIKES_DEF, MAX_ON_COUNTS,
                     value24, CYC_STEP_DEF, CLEAN_DEF);
    spi_read(A_HICCUP0, 3);
    check_eq("3-byte burst write/read HICCUP_BASE 0x54..0x56", {spi_rx[2], spi_rx[1], spi_rx[0]}, value24);
    // a bad CRC: nothing commits, the error counter moves
    reg_read(A_BUSERR_L);  bus_err_before = rd_val;
    spi_tx[0] = WRITE_KEY; spi_tx[1] = 8'd5;
    spi_write(A_WRKEY, 2, 1'b1);
    reg_write(A_SCRATCH, 8'hC3);
    reg_read(A_TRIP_RUN);  check_eq("bad-CRC write did not commit TRIP_RUN", rd_val, TRIP_RUN_DEF);
    reg_read(A_SCRATCH);   check_eq("good write after a bad one commits", rd_val, 8'hC3);
    reg_read(A_BUSERR_L);  check_eq("BUS_ERR counted the bad CRC", rd_val, bus_err_before + 1);
    // length and alignment: a 2-byte frame and a frame cut mid-byte both abort
    spi_write_short(A_SCRATCH);
    spi_write_misaligned(A_SCRATCH, 8'h77);
    reg_read(A_SCRATCH);   check_eq("short and misaligned frames left SCRATCH alone", rd_val, 8'hC3);
    reg_read(A_BUSERR_L);  check_eq("BUS_ERR counted both", rd_val, bus_err_before + 3);
    // the threshold bank without the key: rejected and flagged
    spi_tx[0] = 8'd7;
    spi_write(A_TRIP_RUN, 1, 1'b0);
    reg_read(A_TRIP_RUN);  check_eq("unkeyed threshold write ignored", rd_val, TRIP_RUN_DEF);
    reg_read(A_STATUS);    check("STATUS write_rejected = 1 after unkeyed write", rd_val[7] === 1'b1);
    // out-of-range writes saturate; readback shows the clamp
    write_thresholds(8'd200, 8'd0, 8'd9, 8'd250, 24'd1, 8'd0, 24'd5);
    read_thresholds;
    check_eq("TRIP_RUN 200 clamps to WINDOW_RUN", spi_rx[0], WINDOW_RUN);
    check_eq("TRIP_SS 0 clamps to 1", spi_rx[1], 1);
    check_eq("MAX_STRIKES 9 clamps down to default", spi_rx[2], MAX_STRIKES_DEF);
    check_eq("MAX_ON 250 clamps down to default", spi_rx[3], MAX_ON_COUNTS);
    check_eq("HICCUP_BASE 1 clamps up to 1 ms", {spi_rx[6], spi_rx[5], spi_rx[4]}, HICCUP_MIN);
    check_eq("CYCLES_PER_STEP 0 clamps to 1", spi_rx[7], 1);
    check_eq("CLEAN_RUN 5 clamps up to 100 ms", {spi_rx[10], spi_rx[9], spi_rx[8]}, CLEAN_SHORT);

    // CS deasserted in the middle of a read byte
    CS_n = 1'b0;
    #(SPI_HALF_NS);
    spi_send_byte({1'b1, A_ID});
    spi_recv_byte(rd_val, 1'b0);
    MOSI = 1'b0;
    reads_issued = reads_issued + 1;
    for (idx = 0; idx < 3; idx = idx + 1) begin
        #(SPI_HALF_NS) SCK = 1'b1;
        #(SPI_HALF_NS) SCK = 1'b0;
    end
    check("mid-read: slave sending read data before CS rises", sdio_oe_int === 1'b1);
    CS_n = 1'b1;
    t_event = $realtime;
    // Timed from edge-stamped monitors: polling on the edge where the DUT
    // updates sdio_oe would read the pre-edge value and overstate the latency.
    @(posedge cs_filt_int);
    t_cs_filt = $realtime;
    #(10.0 * CLK_PERIOD_NS);
    check("CS up mid-byte: sdio_oe released", sdio_oe_int === 1'b0);
    check_range("CS up mid-byte: sdio_oe low within 2 clocks of filtered CS (clocks)",
                (oe_fall_t - t_cs_filt) / CLK_PERIOD_NS, 0.0, 2.01);
    check_range("CS up mid-byte: release after the CS pin (clocks, sync + filter + 2)",
                (oe_fall_t - t_event) / CLK_PERIOD_NS, 0.0, 14.0);
    if ((sdio_oe_int === 1'b0) && (oe_fall_t > t_event)) cover_bin(C_CS_MIDRD);
    #(SPI_GAP_NS);

    // a read abandoned without CS rising: the 2 ms SCK idle timeout
    CS_n = 1'b0;
    #(SPI_HALF_NS);
    spi_send_byte({1'b1, A_ID});
    spi_recv_byte(rd_val, 1'b0);
    MOSI = 1'b0;
    reads_issued = reads_issued + 1;
    for (idx = 0; idx < 2; idx = idx + 1) begin
        #(SPI_HALF_NS) SCK = 1'b1;
        #(SPI_HALF_NS) SCK = 1'b0;
    end
    #(2.2 * MS);
    check_eq("abandoned read: spi_state after SCK timeout = S_DEAD", spi_state_int, SPI_DEAD);
    check("abandoned read: sdio_oe low after timeout", sdio_oe_int === 1'b0);
    if ((spi_state_int == SPI_DEAD) && (sdio_oe_int === 1'b0)) cover_bin(C_SCK_TMO);
    CS_n = 1'b1;
    #(SPI_GAP_NS);
    check_eq("abandoned read: CS high returns to S_IDLE", spi_state_int, SPI_IDLE);
    reg_read(A_ID);        check_eq("first read after the timeout recovers", rd_val, 8'hB5);

    // An illegal spi_slave state. The encoding has six states in three bits,
    // so 3'b110 is unreachable by any stimulus; force it for one clock. The
    // FSM's default arm must send it to S_DEAD, with MISO held low, and the
    // next transaction must recover through cs_fall.
    @(posedge clk);
    #(1.0);
    force u_dut.g_telemetry.u_spi_slave.spi_state = 3'b110;
    @(posedge clk);
    #(1.0);
    release u_dut.g_telemetry.u_spi_slave.spi_state;
    @(posedge clk);
    @(posedge clk);
    #(1.0);
    check_eq("illegal spi_state 6 falls to S_DEAD", spi_state_int, SPI_DEAD);
    check("illegal spi_state: MISO stays low", (sdio_oe_int === 1'b0) && (MISO === 1'b0));
    reg_read(A_ID);        check_eq("illegal spi_state: next transaction recovers", rd_val, 8'hB5);
    if (rd_val == 8'hB5) cover_bin(C_SPI_ILLEG);

    // ---------------------------------------------------------------
    // Phase 3: host configuration for the protection phases
    // ---------------------------------------------------------------
    note("Phase 3: configure short timers over SPI (as built, no RTL change)");
    // 1 ms hiccup base and 100 ms clean-run window, both the register map's
    // minimum; default ramp. Accepted only in S_OFF, which is where it is.
    write_thresholds(TRIP_RUN_DEF, TRIP_SS_DEF, MAX_STRIKES_DEF, MAX_ON_COUNTS,
                     HICCUP_MIN, CYC_STEP_DEF, CLEAN_SHORT);
    read_thresholds;
    check_eq("configured HICCUP_BASE = 1 ms", {spi_rx[6], spi_rx[5], spi_rx[4]}, HICCUP_MIN);
    check_eq("configured CLEAN_RUN = 100 ms", {spi_rx[10], spi_rx[9], spi_rx[8]}, CLEAN_SHORT);
    check_eq("configured CYCLES_PER_STEP", spi_rx[7], CYC_STEP_DEF);
    check_eq("configured TRIP_RUN", spi_rx[0], TRIP_RUN_DEF);
    check_eq("configured TRIP_SS", spi_rx[1], TRIP_SS_DEF);

    // ---------------------------------------------------------------
    // Phase 4: start-up
    // ---------------------------------------------------------------
    note("Phase 4: enable switch, soft start, duty backstop, PWM stats");
    // The 20 ms enable debounce is a pmic_top constant, not a register, so it
    // is the one start-up wait that cannot be shortened. Paid here and after
    // each reset.
    en_from_switch = 1'b1;
    t_event = $realtime;
    #(19.8 * MS);
    check("En still low 19.8 ms after the switch (20 ms debounce)", En === 1'b0);
    wait_en(1'b1, 1.0 * MS);
    t_en_rise = $realtime;
    check_range("En rise after switch (ms)", (t_en_rise - t_event) / MS, 19.99, 20.05);
    #(2.0 * CLK_PERIOD_NS);
    check("Green_LED lit in soft start", Green_LED === 1'b1);
    measure_ramp(20.0 * MS, CYC_STEP_DEF, MAX_ON_COUNTS);
    check_eq("ramp starts at MIN_ON_COUNTS+1 clocks", ramp_first_level, MIN_ON_COUNTS + 1);
    check_eq("ramp levels MIN..MAX (one clock per step)", ramp_levels, MAX_ON_COUNTS - MIN_ON_COUNTS + 1);
    check_eq("ramp plateaus of CYCLES_PER_STEP cycles (bad count)", ramp_bad_plateau, 0);
    check_eq("ramp never steps backwards", ramp_backwards, 0);
    check_range("ramp duration En->ceiling (switching cycles)",
                (ramp_t_ceiling - t_en_rise) / SW_PERIOD_NS,
                (MAX_ON_COUNTS - MIN_ON_COUNTS) * CYC_STEP_DEF - 2.0,
                (MAX_ON_COUNTS - MIN_ON_COUNTS) * CYC_STEP_DEF + 2.0);
    check("Green_LED lit while switching", Green_LED === 1'b1);
    wait_state(ST_RUN, 1.0 * MS);
    check_eq("S_RUN reached after the ramp", last_state, ST_RUN);
    // 90% commanded in S_RUN: the backstop truncates every pulse
    #(50.0 * US);
    check_range("90% commanded in S_RUN: PWM_out truncated (ns)", pwm_width_ns,
                (MAX_ON_COUNTS + 1) * CLK_PERIOD_NS - 1.0, (MAX_ON_COUNTS + 1) * CLK_PERIOD_NS + 1.0);
    // 50% commanded: passes through, quantised to whole clocks
    osc_high_ns = SW_PERIOD_NS / 2.0;
    #(50.0 * US);
    check_range("50% commanded: PWM_out passes through (ns)", pwm_width_ns,
                osc_high_ns - CLK_PERIOD_NS - 1.0, osc_high_ns + CLK_PERIOD_NS + 1.0);
    spi_read(A_DUTY, 2);
    check_range("PWM stats: PREV_PERIOD (clocks)", spi_rx[1],
                SW_PERIOD_NS / CLK_PERIOD_NS - 2.0, SW_PERIOD_NS / CLK_PERIOD_NS + 1.0);
    check_range("PWM stats: DUTY_COUNT (clocks)", spi_rx[0],
                osc_high_ns / CLK_PERIOD_NS - 2.0, osc_high_ns / CLK_PERIOD_NS + 1.0);
    if ((spi_rx[1] >= SW_PERIOD_NS / CLK_PERIOD_NS - 2.0) && (spi_rx[0] > 0)) cover_bin(C_STATS);

    // ---------------------------------------------------------------
    // Phase 5: PGOOD
    // ---------------------------------------------------------------
    note("Phase 5: PGOOD qualification");
    PGOOD_comp = 1'b1;
    t_event = $realtime;
    #(8.8 * MS);
    check("PGOOD still low 8.8 ms after the rail is good", PGOOD === 1'b0);
    wait_pgood(1'b1, 1.0 * MS);
    check_range("PGOOD qualify delay (switching cycles)", ($realtime - t_event) / SW_PERIOD_NS,
                PGOOD_CYCLES - 2.0, PGOOD_CYCLES + 2.0);
    #(2.0 * CLK_PERIOD_NS);
    check("pgood_LED follows PGOOD", pgood_LED === 1'b1);
    check("switch_supply follows PGOOD", switch_supply === 1'b1);
    reg_read(A_STATUS);    check("STATUS pgood = 1", rd_val[2] === 1'b1);
    PGOOD_comp = 1'b0;
    t_event = $realtime;
    wait_pgood(1'b0, 1.0 * US);
    check_range("PGOOD deassert after the comparator drops (clocks)",
                ($realtime - t_event) / CLK_PERIOD_NS, 0.0, 3.5);
    #(2.0 * US);
    PGOOD_comp = 1'b1;
    #(5.0 * MS);
    check("PGOOD requalifies from zero, not from where it left off", PGOOD === 1'b0);

    // ---------------------------------------------------------------
    // Phase 6: overcurrent in S_RUN -> hiccup -> retry
    // ---------------------------------------------------------------
    note("Phase 6: overcurrent in S_RUN, hiccup, retry");
    CP_trig = 1'b1;
    t_event = $realtime;
    wait_en(1'b0, 100.0 * US);
    check_range("En drops after TRIP_RUN faulted cycles (switching cycles)",
                ($realtime - t_event) / SW_PERIOD_NS, TRIP_RUN_DEF - 2.0, TRIP_RUN_DEF + 2.0);
    check("PGOOD dropped with S_RUN", PGOOD === 1'b0);
    CP_trig = 1'b0;
    t_event = $realtime;
    // strike 1: the cool-down is the base shifted by the strike level, 2 ms
    #(1.9 * MS);
    check("still cooling down 1.9 ms into the first hiccup", En === 1'b0);
    wait_en(1'b1, 0.5 * MS);
    check_range("first hiccup duration (ms) = 2 x base", ($realtime - t_event) / MS, 1.99, 2.05);
    @(negedge PWM_out);
            #(1.0);   // let the pulse monitor, woken by the same edge, record it
    @(negedge PWM_out);
            #(1.0);   // let the pulse monitor, woken by the same edge, record it
    check_range("retry re-ramps from MIN (ns)", pwm_width_ns,
                (MIN_ON_COUNTS + 1) * CLK_PERIOD_NS - 1.0, (MIN_ON_COUNTS + 1) * CLK_PERIOD_NS + 1.0);
    wait_state(ST_RUN, 3.0 * MS + (MAX_ON_COUNTS - MIN_ON_COUNTS) * CYC_STEP_DEF * SW_PERIOD_NS);
    check_eq("retry reaches S_RUN", last_state, ST_RUN);
    reg_read(A_STRIKE);    check_eq("STRIKE_LEVEL after one hiccup", rd_val, 1);
    reg_read(A_FCAUSE);    check_eq("fault log: partial read shows OC", rd_val, 8'h01);
    spi_read(A_FCAUSE, 4);
    check_eq("fault log: cause after a 4-byte sweep is OC", spi_rx[0], 8'h01);
    check("fault log: episode timestamp is non-zero", {spi_rx[3], spi_rx[2], spi_rx[1]} != 24'd0);
    reg_read(A_FCAUSE);    check_eq("fault log cleared by the full sweep", rd_val, 8'h00);

    // ---------------------------------------------------------------
    // Phase 7: clean-run window, run concurrently with random corners
    // ---------------------------------------------------------------
    note("Phase 7: clean-run window || random register traffic, duty and glitch corners");
    // The clean-run window cannot be shorter than 100 ms (CLEAN_RUN_MIN_CYCLES)
    // and the blink half-period is a 125 ms fault_LED parameter. Neither is
    // waited out: the window thread below only watches, while the corner
    // thread fills the same 100 ms with directed-random work that must not
    // disturb it. The strike is outstanding from the retry in phase 6 until the
    // window closes, which spans the first blink edge at 125 ms after reset.
    fork
        begin : window_thread
            if ($realtime < 130.0 * MS) #(130.0 * MS - $realtime);
            check("Red_LED1 blinking while a strike is outstanding (lit at 130 ms)", Red_LED1 === 1'b1);
            check("Green_LED also lit: running with a strike outstanding", Green_LED === 1'b1);
            wait_strike(2'd0, t_last_run_entry + CLEAN_SHORT * SW_PERIOD_NS + 5.0 * MS - $realtime);
            check("strike cleared by the clean-run window", timed_out === 1'b0);
            check_range("clean-run window from S_RUN entry (ms)", ($realtime - t_last_run_entry) / MS,
                        CLEAN_SHORT * SW_PERIOD_NS / MS - 0.5, CLEAN_SHORT * SW_PERIOD_NS / MS + 0.5);
            #(2.0 * CLK_PERIOD_NS);
            check("Red_LED1 dark once the strike clears (blink phase still high)", Red_LED1 === 1'b0);
        end
        begin : corner_thread
            // directed first: a keyed write that reaches CYCLES_PER_STEP and
            // HICCUP_BASE while running must be refused for those registers
            spi_tx[0] = WRITE_KEY;
            spi_tx[1] = sh_trip_run;      spi_tx[2] = sh_trip_ss;
            spi_tx[3] = sh_max_strikes;   spi_tx[4] = sh_max_on;
            spi_tx[5] = HICCUP_MIN[7:0];  spi_tx[6] = HICCUP_MIN[15:8]; spi_tx[7] = HICCUP_MIN[23:16];
            spi_tx[8] = 8'd32;
            spi_write(A_WRKEY, 9, 1'b0);
            reg_read(A_STATUS);   check("S_OFF-only write while running: STATUS write_rejected", rd_val[7] === 1'b1);
            reg_read(A_CYC_STEP); check_eq("S_OFF-only write while running: CYCLES_PER_STEP unchanged", rd_val, CYC_STEP_DEF);
            random_register_traffic(32);
            write_run_thresholds(TRIP_RUN_DEF, TRIP_SS_DEF, MAX_STRIKES_DEF, MAX_ON_COUNTS);
            random_duty_corners(16);
            random_glitch_corners(6);
        end
    join
    reg_read(A_STRIKE);    check_eq("STRIKE_LEVEL reads 0 after the window", rd_val, 0);
    read_thresholds;
    check_eq("run-time thresholds restored after the traffic", spi_rx[0], TRIP_RUN_DEF);
    check_eq("S_OFF-only CLEAN_RUN untouched by traffic in S_RUN", {spi_rx[10], spi_rx[9], spi_rx[8]}, CLEAN_SHORT);
    check_eq("S_OFF-only HICCUP_BASE untouched by traffic in S_RUN", {spi_rx[6], spi_rx[5], spi_rx[4]}, HICCUP_MIN);

    // ---------------------------------------------------------------
    // Phase 8: OTP and UVLO shutdown and recovery
    // ---------------------------------------------------------------
    note("Phase 8: OTP and UVLO shutdown and recovery, UVLO in soft start");
    OTP_trig = 1'b1;
    t_event = $realtime;
    #(0.9 * MS);
    check("OTP: En still high at 0.9 ms (1 ms debounce)", En === 1'b1);
    wait_en(1'b0, 0.5 * MS);
    check_range("OTP: shutdown after (ms)", ($realtime - t_event) / MS, 0.99, 1.02);
    #(1.0 * US);
    check("OTP: Red_LED2 lit", Red_LED2 === 1'b1);
    check("OTP: Green_LED dark", Green_LED === 1'b0);
    reg_read(A_FLAGS);     check("FAULT_FLAGS otp bit", rd_val[1] === 1'b1);
    // The record clears only when a host READ completes the byte at 0x20. A
    // write to the read-only 0x20 must leave it intact.
    reg_write(A_FTIME2, 8'h00);
    reg_read(A_FCAUSE);    check_eq("write to read-only 0x20 leaves the fault record", rd_val, 8'h04);
    spi_read(A_FCAUSE, 4); check_eq("fault log: OTP", spi_rx[0], 8'h04);
    OTP_trig = 1'b0;
    t_event = $realtime;
    #(150.0 * US);
    check("OTP cleared: still off at 150 us (200 us release)", En === 1'b0);
    wait_en(1'b1, 0.5 * MS);
    check_range("OTP cleared: automatic restart after (us)", ($realtime - t_event) / US, 199.0, 205.0);
    wait_state(ST_RUN, 15.0 * MS);
    check_eq("back in S_RUN after OTP", last_state, ST_RUN);

    UVLO_trig = 1'b1;
    t_event = $realtime;
    wait_en(1'b0, 2.0 * MS);
    check_range("UVLO: shutdown after (ms)", ($realtime - t_event) / MS, 0.99, 1.02);
    #(1.0 * US);
    check("UVLO: Red_LED3 lit", Red_LED3 === 1'b1);
    reg_read(A_FLAGS);     check("FAULT_FLAGS uvlo bit", rd_val[0] === 1'b1);
    spi_read(A_FCAUSE, 4); check_eq("fault log: UVLO", spi_rx[0], 8'h02);
    UVLO_trig = 1'b0;
    wait_en(1'b1, 0.5 * MS);
    check("UVLO cleared: restart", En === 1'b1);
    check("UVLO cleared: Red_LED3 dark", Red_LED3 === 1'b0);
    // Undervoltage again while the ramp is still running: S_SS -> S_OFF.
    #(100.0 * US);
    check("soft start still in progress", ss_active_int === 1'b1);
    UVLO_trig = 1'b1;
    wait_en(1'b0, 2.0 * MS);
    check("UVLO during soft start: off before the ramp completes", run_active_int === 1'b0);
    UVLO_trig = 1'b0;
    wait_en(1'b1, 0.5 * MS);
    wait_state(ST_RUN, 15.0 * MS);
    check_eq("back in S_RUN after UVLO in soft start", last_state, ST_RUN);

    // ---------------------------------------------------------------
    // Phase 9: host disable, enable, watchdog, OTP during a hiccup
    // ---------------------------------------------------------------
    note("Phase 9: host disable and enable, host-silence watchdog, OTP in a hiccup");
    reg_write(A_CONTROL, 8'h00);
    #(10.0 * US);
    check("CONTROL disable without the key is ignored", En === 1'b1);
    spi_tx[0] = DISABLE_KEY; spi_tx[1] = 8'h00;
    spi_write(A_DISKEY, 2, 1'b0);
    #(1.0 * US);
    check("keyed disable: En low", En === 1'b0);
    reg_read(A_STATUS);
    check("keyed disable: STATUS spi_enable = 0", rd_val[5] === 1'b0);
    check_eq("keyed disable: S_OFF", rd_val[1:0], ST_OFF);
    reg_write(A_CONTROL, 8'h01);
    wait_en(1'b1, 10.0 * US);
    check("CONTROL enable: En high again", En === 1'b1);
    wait_state(ST_RUN, 15.0 * MS);
    check_eq("back in S_RUN after host enable", last_state, ST_RUN);

    // The host-silence watchdog releases a host disable after 5 s without a
    // valid transaction - 50 million clocks at 10 MHz, out of reach here. The
    // elapsed time is supplied by forcing the watchdog's reference, wd_mark, to
    // 5000 ms before the present count: exactly what 5 s of silence leaves
    // behind. wd_mark is a register the design re-marks on the next clock once
    // the converter is enabled, so the release is clean in every simulator, and
    // the millisecond counter itself is never touched. Everything else in the
    // path - the elapsed-time compare, the release of the veto, wd_restored -
    // is the design as built.
    spi_tx[0] = DISABLE_KEY; spi_tx[1] = 8'h00;
    spi_write(A_DISKEY, 2, 1'b0);
    #(1.0 * US);
    check("watchdog: host disable in force", En === 1'b0);
    spi_busy = 1'b1;
    ts_force = ts_live_int - 24'd5000;
    force u_dut.g_telemetry.u_reg_file.wd_mark = ts_force;
    wait_en(1'b1, 100.0 * US);
    @(posedge clk);
    #(1.0);
    release u_dut.g_telemetry.u_reg_file.wd_mark;
    check("watchdog: converter re-enabled after 5 s of host silence", timed_out === 1'b0);
    #(1.0 * US);
    sh_spi_enable = 1'b1;
    spi_busy = 1'b0;
    reg_read(A_CONTROL);
    check("watchdog: CONTROL reports wd_restored", rd_val[3] === 1'b1);
    check("watchdog: CONTROL reports enabled", rd_val[0] === 1'b1);
    wait_state(ST_RUN, 15.0 * MS);
    check_eq("back in S_RUN after the watchdog", last_state, ST_RUN);

    // Over-temperature arriving during a hiccup cool-down: S_HICCUP -> S_OFF.
    CP_trig = 1'b1;
    wait_en(1'b0, 100.0 * US);
    CP_trig = 1'b0;
    OTP_trig = 1'b1;
    #(1.5 * MS);
    check("OTP during the cool-down: still off", En === 1'b0);
    reg_read(A_STATUS);    check_eq("OTP during the cool-down: S_OFF, not a retry", rd_val[1:0], ST_OFF);
    OTP_trig = 1'b0;
    wait_en(1'b1, 1.0 * MS);
    check("OTP cleared after the cool-down: restart", En === 1'b1);
    wait_state(ST_RUN, 15.0 * MS);
    check_eq("back in S_RUN", last_state, ST_RUN);
    // Fault log since its last read (phase 8): the undervoltage in soft start
    // and the overcurrent trip. The OTP that arrived during the cool-down is
    // not there - fault_cause records faults that interrupt operation, and the
    // converter was already stopped.
    spi_read(A_FCAUSE, 4);
    check_eq("fault log: UVLO in soft start + overcurrent, not the OTP in the cool-down", spi_rx[0], 8'h03);

    // ---------------------------------------------------------------
    // Phase 10: timestamp burst across the 255 -> 256 ms carry
    // ---------------------------------------------------------------
    note("Phase 10: timestamp burst read across a byte-0 -> byte-1 carry");
    // A burst from 0x18 reads the low byte first. Started so the tick from
    // 0x..FF to the next value lands after byte 0 is loaded and before byte 1
    // is, an unsnapshotted read would stitch the old low byte to the new middle
    // byte (0x0001FF for the 255 -> 256 carry); the snapshot must return the
    // old value whole. The carry used is the next one at least 2 ms ahead.
    carry_at = (((ts_live_int + 24'd2) >> 8) << 8) + 24'd255;
    $sformat(msg, "timestamp carry used: %0d -> %0d ms", carry_at, carry_at + 1);
    note(msg);
    wait (ts_live_int >= carry_at);
    // next tick in 1 ms; rd_first comes ~16 SCK periods after CS falls
    #(1.0 * MS - 16.0 * 2.0 * SPI_HALF_NS - 10.0 * US);
    spi_read(A_TIME0, 3);
    check("the carry tick happened during the burst", ts_live_int >= carry_at + 24'd1);
    check_eq("timestamp burst = one snapshot (the value before the carry)",
             {spi_rx[2], spi_rx[1], spi_rx[0]}, carry_at);
    check_eq("timestamp burst matches reg_file's snapshot", {spi_rx[2], spi_rx[1], spi_rx[0]}, ts_snap_int);
    if ((ts_live_int >= carry_at + 24'd1) && ({spi_rx[2], spi_rx[1], spi_rx[0]} == carry_at)) cover_bin(C_TS_CARRY);

    // ---------------------------------------------------------------
    // Phase 11: analog OVP trips the SCR
    // ---------------------------------------------------------------
    note("Phase 11: analog OVP trip, reset-button recovery");
    ovp_event = 1'b1;
    t_event = $realtime;
    wait_en(1'b0, 2.0 * MS);
    check_range("OVP: off after latch_stat debounce (ms)", ($realtime - t_event) / MS, 0.99, 1.02);
    check("OVP: the CPLD's own latch_out stays low", latch_out === 1'b0);
    #(1.0 * US);
    check("OVP: Red_LED1 solid", Red_LED1 === 1'b1);
    reg_read(A_STATUS);    check("OVP: STATUS latch = 1", rd_val[3] === 1'b1);
    spi_read(A_FCAUSE, 4); check_eq("fault log: OVP inferred", spi_rx[0], 8'h10);
    ovp_event = 1'b0;
    #(2.0 * MS);
    check("OVP: no restart while the SCR is latched", En === 1'b0);
    do_reset;
    #(300.0 * US);
    check("reset button: SCR cleared", latch_stat === 1'b0);
    check("reset button: Red_LED1 dark", Red_LED1 === 1'b0);
    reg_read(A_SCRATCH);   check_eq("reset restored SCRATCH", rd_val, 8'h00);
    write_thresholds(TRIP_RUN_DEF, TRIP_SS_DEF, MAX_STRIKES_DEF, MAX_ON_COUNTS,
                     HICCUP_MIN, CYC_STEP_DEF, CLEAN_SHORT);
    wait_en(1'b1, 21.0 * MS);
    check("restart after reset (20 ms switch debounce again)", En === 1'b1);
    wait_state(ST_RUN, 15.0 * MS);
    check_eq("S_RUN after reset", last_state, ST_RUN);

    // ---------------------------------------------------------------
    // Phase 12: strikes accumulate to latch
    // ---------------------------------------------------------------
    note("Phase 12: persistent overcurrent, strikes to latch");
    CP_trig = 1'b1;
    strike_hiccups = 0;
    t_event = $realtime;
    // RUN trip -> hiccup (2 ms) -> SS trip -> hiccup (4 ms) -> SS trip -> latch
    while ((latch_out !== 1'b1) && ($realtime - t_event < 30.0 * MS)) begin
        wait_en(1'b0, 30.0 * MS - ($realtime - t_event));
        // latch_assert lands one clock after the hiccup entry that earns it,
        // so look a few clocks later before deciding this was a retry
        #(5.0 * CLK_PERIOD_NS);
        if (latch_out !== 1'b1) strike_hiccups = strike_hiccups + 1;
        while ((En !== 1'b1) && (latch_out !== 1'b1) && ($realtime - t_event < 30.0 * MS))
            @(posedge clk);
    end
    check("latch_out asserted by repeated overcurrent", latch_out === 1'b1);
    check_eq("retries before the latch = MAX_STRIKES-1", strike_hiccups, MAX_STRIKES_DEF - 1);
    check("En low once latched", En === 1'b0);
    CP_trig = 1'b0;
    #(10.0 * MS);
    check("no restart 10 ms after the fault clears", En === 1'b0);
    check("latch_out still set", latch_out === 1'b1);
    check("SCR read back latched", latch_stat === 1'b1);
    check("Red_LED1 solid", Red_LED1 === 1'b1);
    reg_read(A_STRIKE);    check_eq("STRIKE_LEVEL at latch", rd_val, MAX_STRIKES_DEF);
    reg_read(A_STATUS);    check("STATUS latch = 1", rd_val[3] === 1'b1);
    spi_read(A_FCAUSE, 4);
    check("fault log: overcurrent recorded", spi_rx[0][0] === 1'b1);
    if (spi_rx[0][3] !== 1'b1)
        note("fault log LATCH bit not set: latch_assert only rises in S_HICCUP, outside the capture gate (reported finding)");
    do_reset;
    #(10.0 * US);
    check("reset clears latch_out", latch_out === 1'b0);
    #(300.0 * US);
    check("reset clears the SCR", latch_stat === 1'b0);
    reg_read(A_STRIKE);    check_eq("reset clears STRIKE_LEVEL", rd_val, 0);
    read_thresholds;
    check_eq("reset restores HICCUP_BASE default", {spi_rx[6], spi_rx[5], spi_rx[4]}, HICCUP_DEF);
    check_eq("reset restores CLEAN_RUN default", {spi_rx[10], spi_rx[9], spi_rx[8]}, CLEAN_DEF);

    // ---------------------------------------------------------------
    // Phase 13: restart after a latch, enable switch, stuck modulator
    // ---------------------------------------------------------------
    note("Phase 13: restart after a latch, enable switch off and on, modulator stuck high");
    wait_en(1'b1, 21.0 * MS);
    check("latched part restarts after the reset button", En === 1'b1);
    wait_state(ST_RUN, 15.0 * MS);
    check_eq("S_RUN after the latch is cleared", last_state, ST_RUN);
    // A modulator stuck high: one pulse cut at the ceiling, then nothing until
    // the modulator falls - pwm_mask holds the envelope closed.
    @(negedge PWM_out);
            #(1.0);   // let the pulse monitor, woken by the same edge, record it
    pulses_before = pwm_pulses;
    osc_stuck_high = 1'b1;
    #(20.0 * SW_PERIOD_NS);
    check("stuck modulator: at most one PWM_out pulse", pwm_pulses - pulses_before <= 1);
    check("stuck modulator: PWM_out held low", PWM_out === 1'b0);
    check_range("stuck modulator: that pulse capped at MAX_ON+1 clocks (ns)", pwm_width_ns,
                0.0, (MAX_ON_COUNTS + 1) * CLK_PERIOD_NS + 1.0);
    if ((pwm_pulses - pulses_before <= 1) && (PWM_out === 1'b0)) cover_bin(C_STUCK);
    osc_stuck_high = 1'b0;
    #(5.0 * SW_PERIOD_NS);
    // enable switch: release and press, 20 ms of debounce each way
    en_from_switch = 1'b0;
    t_event = $realtime;
    #(19.8 * MS);
    check("switch released: En still high at 19.8 ms", En === 1'b1);
    wait_en(1'b0, 1.0 * MS);
    check_range("switch released: off after (ms)", ($realtime - t_event) / MS, 19.99, 20.05);
    en_from_switch = 1'b1;
    t_event = $realtime;
    wait_en(1'b1, 21.0 * MS);
    check_range("switch pressed: restart after (ms)", ($realtime - t_event) / MS, 19.99, 20.05);
    #(10.0 * US);
    check("switch pressed: back in soft start", ss_active_int === 1'b1);

    // ---------------------------------------------------------------
    // Run-long invariants, scoreboards
    // ---------------------------------------------------------------
    extra_phases;

    note("Run-long invariants and scoreboards");
    check_eq("clocks with sdio_oe != (spi_state == S_READ)", oe_misaligned, 0);
    check_eq("... of which sdio_oe high while the master is sending", oe_in_master_phase, 0);
    check_eq("MISO high while the slave is not in S_READ (clocks)", miso_idle, 0);
    check_eq("read data starts without the first bit on MISO", oe_rise_bad, 0);
    check_eq("read data starts = reads that reached the data phase", oe_rises, reads_issued);
    check_eq("exits from S_READ = reads that reached the data phase", read_exits, reads_issued);
    $sformat(msg, "              (S_READ exits: %0d to S_IDLE on CS, %0d to S_DEAD on timeout, %0d to S_CMD, %0d other)",
             exit_to_idle, exit_to_dead, exit_to_cmd, exit_to_other);
    emit(msg);
    check_eq("first read bit not driven at the first data SCK rise", first_bit_errors, 0);
    $sformat(msg, "              (smallest sdio_oe-to-sampling-edge margin: %0.1f ns at SCK %0.0f kHz)",
             first_bit_margin, 1.0e6 / (2.0 * SPI_HALF_NS));
    emit(msg);
    check_eq("switch_supply mirrored PGOOD on every clock (mismatches)", mirror_errors, 0);
    check_eq("PGOOD high with En low for 2+ clocks", pgood_no_en, 0);
    check_eq("PWM_out pulses above the MAX_ON ceiling", backstop_errors, 0);
    check_eq("latch_out falls without a reset", latch_drops, 0);
    check_eq("MISO x or z after reset (clocks)", miso_xz, 0);
    check_eq("FSM scoreboard: state mismatches", sm_mismatch, 0);
    check_eq("FSM scoreboard: En mismatches", en_mismatch, 0);
    $sformat(msg, "              (FSM scoreboard compared %0d clocks)", sm_compares);
    emit(msg);
    check_eq("register-map scoreboard: per-clock mismatches", rm_mismatch, 0);
    check_eq("register-map scoreboard: read-back mismatches", rd_mismatch, 0);
    check_eq("register-map scoreboard: commit/abort not as predicted", outcome_mismatch, 0);
    $sformat(msg, "              (register map compared on %0d clocks and %0d read-back bytes)",
             rm_compares, rd_compares);
    emit(msg);
    $sformat(msg, "register-map scoreboard compared read-backs (%0d bytes, at least 50)", rd_compares);
    check(msg, rd_compares >= 50);
    check_eq("PGOOD high outside S_RUN (clocks)", pgood_not_run, 0);
    check_eq("Green_LED disagreed with running-and-no-fault (clocks)", green_err, 0);
    check_eq("Red_LED2 / Red_LED3 disagreed with OTP / UVLO (clocks)", red23_err, 0);
    check_eq("PWM_out pulses longer than the ceiling in force", ceiling_err, 0);
    check_eq("latch_out set at a strike level other than MAX_STRIKES", latch_wrong, 0);

    finish_run("normal end");
end

end
else begin : g_seq_notel

/*
Purpose:
---
The pins-only sequence, for the reduced build (TELEMETRY_EN = 0). There is no
register map, so nothing is configured: every timer runs at its package
default - the 5 ms hiccup base, the 1 s clean-run window, 64 cycles per ramp
step - and the SPI pins are driven only to show they change nothing. Phases
keep the SPI sequence's numbers; phase 2 becomes the SPI-has-no-effect check,
and 3 (configuration) and 10 (timestamp) have no counterpart. The FSM
scoreboard, the run-long monitors and the coverage bins that exist in this
build run underneath, as in the SPI sequence.
*/
initial begin
    log_fd = $fopen("pmic_top_tb.log", "w");
    shadow_reset;
    $sformat(msg, "==== pmic_top_tb : CLK_HZ = %0d, MIN_ON = %0d, MAX_ON = %0d clocks, TELEMETRY_EN = 0 ====",
             CLK_HZ, MIN_ON_COUNTS, MAX_ON_COUNTS);
    emit(msg);

    // ---------------------------------------------------------------
    // Phase 1: reset, fail-safe outputs, no host interface
    // ---------------------------------------------------------------
    note("Phase 1: power-on reset, fail-safe outputs, no host interface");
    #1;
    rst_n_pin = 1'b0;
    #(10.0 * CLK_PERIOD_NS);
    check("in reset: En low",                 En === 1'b0);
    check("in reset: PGOOD low",              PGOOD === 1'b0);
    check("in reset: latch_out low",          latch_out === 1'b0);
    check("in reset: MISO low",               MISO === 1'b0);
    rst_n_pin = 1'b1;
    #(10.0 * CLK_PERIOD_NS);
    #(20.0 * US);
    check("after reset: Red_LED2 (OTP) fail-safe lit",  Red_LED2 === 1'b1);
    check("after reset: Red_LED3 (UVLO) fail-safe lit", Red_LED3 === 1'b1);
    #(250.0 * US);
    check("Red_LED2 cleared after 200 us release", Red_LED2 === 1'b0);
    check("Red_LED3 cleared after 200 us release", Red_LED3 === 1'b0);
    check("switch off: En stays low", En === 1'b0);
    check_range("PWM_out pulse in S_OFF (ns) = (MIN_ON_COUNTS+1) clocks", pwm_width_ns,
                (MIN_ON_COUNTS + 1) * CLK_PERIOD_NS - 1.0, (MIN_ON_COUNTS + 1) * CLK_PERIOD_NS + 1.0);
    check("minimum gate pulse >= 240 ns commanded (LM5106 128 ns + 112 ns)", pwm_width_ns >= 240.0);
    check_eq("supervisor in S_OFF (probe)", sup_state, ST_OFF);
    check("no host interface: the supervisor's spi_enable is tied high", sup_spi_en === 1'b1);
    spi_read_ignored(A_ID, 1);
    check_eq("no host interface: read of PMIC_ID (0xB5 in a full build), MISO bits high",
             miso_high_bits, 0);

    // ---------------------------------------------------------------
    // Phase 2: SPI frames in S_OFF have no effect
    // ---------------------------------------------------------------
    note("Phase 2: SPI frames have no effect (no slave built)");
    // The configuration the SPI sequence writes in its phase 3 - a 1 ms hiccup
    // base and a 100 ms clean-run window - as the same valid keyed frame. A
    // full build in S_OFF would commit it. Phases 6 and 7 time the default
    // 10 ms first hiccup and 1 s window, which shows it was not.
    spi_tx[0]  = WRITE_KEY;
    spi_tx[1]  = TRIP_RUN_DEF[7:0];      spi_tx[2]  = TRIP_SS_DEF[7:0];
    spi_tx[3]  = MAX_STRIKES_DEF[7:0];   spi_tx[4]  = MAX_ON_COUNTS[7:0];
    spi_tx[5]  = HICCUP_MIN[7:0];        spi_tx[6]  = HICCUP_MIN[15:8];   spi_tx[7]  = HICCUP_MIN[23:16];
    spi_tx[8]  = CYC_STEP_DEF[7:0];
    spi_tx[9]  = CLEAN_SHORT[7:0];       spi_tx[10] = CLEAN_SHORT[15:8];  spi_tx[11] = CLEAN_SHORT[23:16];
    spi_frame_ignored(A_WRKEY, 12);
    spi_read_ignored(A_TRIP_RUN, 11);
    check_eq("threshold read-back after the keyed write: MISO bits high", miso_high_bits, 0);
    check_eq("SPI frames: supervisor still in S_OFF (probe)", sup_state, ST_OFF);
    check("SPI frames: En still low", En === 1'b0);

    // ---------------------------------------------------------------
    // Phase 4: start-up
    // ---------------------------------------------------------------
    note("Phase 4: enable switch, soft start, duty backstop");
    en_from_switch = 1'b1;
    t_event = $realtime;
    #(19.8 * MS);
    check("En still low 19.8 ms after the switch (20 ms debounce)", En === 1'b0);
    wait_en(1'b1, 1.0 * MS);
    t_en_rise = $realtime;
    check_range("En rise after switch (ms)", (t_en_rise - t_event) / MS, 19.99, 20.05);
    #(2.0 * CLK_PERIOD_NS);
    check("Green_LED lit in soft start", Green_LED === 1'b1);
    measure_ramp(20.0 * MS, CYC_STEP_DEF, MAX_ON_COUNTS);
    check_eq("ramp starts at MIN_ON_COUNTS+1 clocks", ramp_first_level, MIN_ON_COUNTS + 1);
    check_eq("ramp levels MIN..MAX (one clock per step)", ramp_levels, MAX_ON_COUNTS - MIN_ON_COUNTS + 1);
    check_eq("ramp plateaus of the default 64 cycles per step (bad count)", ramp_bad_plateau, 0);
    check_eq("ramp never steps backwards", ramp_backwards, 0);
    check_range("ramp duration En->ceiling (switching cycles)",
                (ramp_t_ceiling - t_en_rise) / SW_PERIOD_NS,
                (MAX_ON_COUNTS - MIN_ON_COUNTS) * CYC_STEP_DEF - 2.0,
                (MAX_ON_COUNTS - MIN_ON_COUNTS) * CYC_STEP_DEF + 2.0);
    check("Green_LED lit while switching", Green_LED === 1'b1);
    wait_sup_state(ST_RUN, 1.0 * MS);
    check_eq("S_RUN reached after the ramp (probe)", last_state, ST_RUN);
    // 90% commanded in S_RUN: the backstop truncates every pulse
    #(50.0 * US);
    check_range("90% commanded in S_RUN: PWM_out truncated (ns)", pwm_width_ns,
                (MAX_ON_COUNTS + 1) * CLK_PERIOD_NS - 1.0, (MAX_ON_COUNTS + 1) * CLK_PERIOD_NS + 1.0);
    // 50% commanded: passes through, quantised to whole clocks
    osc_high_ns = SW_PERIOD_NS / 2.0;
    #(50.0 * US);
    check_range("50% commanded: PWM_out passes through (ns)", pwm_width_ns,
                osc_high_ns - CLK_PERIOD_NS - 1.0, osc_high_ns + CLK_PERIOD_NS + 1.0);

    // ---------------------------------------------------------------
    // Phase 5: PGOOD
    // ---------------------------------------------------------------
    note("Phase 5: PGOOD qualification");
    PGOOD_comp = 1'b1;
    t_event = $realtime;
    #(8.8 * MS);
    check("PGOOD still low 8.8 ms after the rail is good", PGOOD === 1'b0);
    wait_pgood(1'b1, 1.0 * MS);
    check_range("PGOOD qualify delay (switching cycles)", ($realtime - t_event) / SW_PERIOD_NS,
                PGOOD_CYCLES - 2.0, PGOOD_CYCLES + 2.0);
    #(2.0 * CLK_PERIOD_NS);
    check("pgood_LED follows PGOOD", pgood_LED === 1'b1);
    check("switch_supply follows PGOOD", switch_supply === 1'b1);
    PGOOD_comp = 1'b0;
    t_event = $realtime;
    wait_pgood(1'b0, 1.0 * US);
    check_range("PGOOD deassert after the comparator drops (clocks)",
                ($realtime - t_event) / CLK_PERIOD_NS, 0.0, 3.5);
    #(2.0 * US);
    PGOOD_comp = 1'b1;
    #(5.0 * MS);
    check("PGOOD requalifies from zero, not from where it left off", PGOOD === 1'b0);

    // ---------------------------------------------------------------
    // Phase 6: overcurrent in S_RUN -> hiccup on the default base -> retry
    // ---------------------------------------------------------------
    note("Phase 6: overcurrent in S_RUN, hiccup on the default 5 ms base, retry");
    red1_before = red1_rises;
    CP_trig = 1'b1;
    t_event = $realtime;
    wait_en(1'b0, 100.0 * US);
    t_strike = $realtime;
    check_range("En drops after TRIP_RUN faulted cycles (switching cycles)",
                ($realtime - t_event) / SW_PERIOD_NS, TRIP_RUN_DEF - 2.0, TRIP_RUN_DEF + 2.0);
    check("PGOOD dropped with S_RUN", PGOOD === 1'b0);
    CP_trig = 1'b0;
    t_event = $realtime;
    // strike 1: the default 5 ms base shifted by the strike level, 10 ms. The
    // 1 ms base sent over SPI in phase 2 would have made it 2 ms.
    #(9.9 * MS);
    check("still cooling down 9.9 ms into the first hiccup", En === 1'b0);
    wait_en(1'b1, 0.5 * MS);
    hic_dur1 = $realtime - t_event;
    check_range("first hiccup duration (ms) = 2 x the default 5 ms base", ($realtime - t_event) / MS,
                9.99, 10.05);
    @(negedge PWM_out);
            #(1.0);   // let the pulse monitor, woken by the same edge, record it
    @(negedge PWM_out);
            #(1.0);   // let the pulse monitor, woken by the same edge, record it
    check_range("retry re-ramps from MIN (ns)", pwm_width_ns,
                (MIN_ON_COUNTS + 1) * CLK_PERIOD_NS - 1.0, (MIN_ON_COUNTS + 1) * CLK_PERIOD_NS + 1.0);
    wait_sup_state(ST_RUN, 3.0 * MS + (MAX_ON_COUNTS - MIN_ON_COUNTS) * CYC_STEP_DEF * SW_PERIOD_NS);
    check_eq("retry reaches S_RUN (probe)", last_state, ST_RUN);
    check_eq("strike level after one hiccup (probe)", strike_int, 1);

    // ---------------------------------------------------------------
    // Phase 7: the default 1 s clean-run window, concurrent with corners
    // ---------------------------------------------------------------
    note("Phase 7: default 1 s clean-run window || duty corners, glitch corners, ignored SPI traffic");
    // The window runs from the retry's S_RUN entry. The strike stays out
    // for all of it, so Red_LED1 blinks at its 125 ms half-period: lit in the
    // second quarter-second after reset, dark in the third. Alongside it, the
    // same duty and glitch corners as the SPI sequence, and random SPI frames
    // - keyed disables among them - that a full build would act on.
    // A second strike 20 ms into the window: the cool-down doubles (4 x the
    // default base), the strike does not clear, and the window must start
    // again from the retry's S_RUN entry - which the window thread below
    // times, so its 1 s clear also proves the restart.
    #(20.0 * MS);
    oc_trip;
    wait_en(1'b1, 4.0 * HICCUP_DEF * CLK_PERIOD_NS + 1.0 * MS);
    hic_dur2 = $realtime - en_fall_t;
    check_range("second hiccup inside the window (ms) = 4 x the default 5 ms base", hic_dur2 / MS,
                4.0 * HICCUP_DEF * CLK_PERIOD_NS / MS - 0.01, 4.0 * HICCUP_DEF * CLK_PERIOD_NS / MS + 0.05);
    check_range("second hiccup / first hiccup", hic_dur2 / hic_dur1, 1.98, 2.02);
    check_eq("interrupted window: strike level 2, not cleared (probe)", strike_int, 2);
    if ((hic_dur2 / hic_dur1 > 1.98) && (hic_dur2 / hic_dur1 < 2.02)) cover_bin(C_ESC2);
    wait_sup_state(ST_RUN, 3.0 * MS + (MAX_ON_COUNTS - MIN_ON_COUNTS) * CYC_STEP_DEF * SW_PERIOD_NS);
    en_falls_before = en_falls;
    fork
        begin : window_notel
            if ($realtime < 130.0 * MS) #(130.0 * MS - $realtime);
            check("Red_LED1 blinking while a strike is outstanding (lit at 130 ms)", Red_LED1 === 1'b1);
            check("Green_LED also lit: running with a strike outstanding", Green_LED === 1'b1);
            if ($realtime < 255.0 * MS) #(255.0 * MS - $realtime);
            check("Red_LED1 blinking: dark at 255 ms, in the off half-period", Red_LED1 === 1'b0);
            wait_strike(2'd0, t_last_run_entry + CLEAN_DEF * SW_PERIOD_NS + 5.0 * MS - $realtime);
            check("strike cleared by the default clean-run window", timed_out === 1'b0);
            check_range("clean-run window from S_RUN entry (ms) = the default 1 s",
                        ($realtime - t_last_run_entry) / MS,
                        CLEAN_DEF * SW_PERIOD_NS / MS - 0.5, CLEAN_DEF * SW_PERIOD_NS / MS + 0.5);
            if (timed_out === 1'b0) cover_bin(C_CLEAN_RESTART);
            #(2.0 * CLK_PERIOD_NS);
            check("Red_LED1 dark once the strike clears", Red_LED1 === 1'b0);
        end
        begin : corner_notel
            random_duty_corners(16);
            random_glitch_corners(6);
            random_ignored_traffic(48);
        end
    join
    $sformat(msg, "Red_LED1 blinked through the outstanding strike (rising edges in %0.1f ms)",
             ($realtime - t_strike) / MS);
    check_range(msg, red1_rises - red1_before,
                ($realtime - t_strike) / (250.0 * MS) - 1.0, ($realtime - t_strike) / (250.0 * MS) + 1.0);
    check_eq("En never fell during the window, keyed SPI disables included", en_falls - en_falls_before, 0);
    check_eq("ignored SPI reads during the window: MISO bits high", miso_high_bits, 0);

    // ---------------------------------------------------------------
    // Phase 8: OTP and UVLO shutdown and recovery
    // ---------------------------------------------------------------
    note("Phase 8: OTP and UVLO shutdown and recovery, UVLO in soft start");
    OTP_trig = 1'b1;
    t_event = $realtime;
    #(0.9 * MS);
    check("OTP: En still high at 0.9 ms (1 ms debounce)", En === 1'b1);
    wait_en(1'b0, 0.5 * MS);
    check_range("OTP: shutdown after (ms)", ($realtime - t_event) / MS, 0.99, 1.02);
    #(1.0 * US);
    check("OTP: Red_LED2 lit", Red_LED2 === 1'b1);
    check("OTP: Green_LED dark", Green_LED === 1'b0);
    check_eq("OTP: supervisor in S_OFF (probe)", sup_state, ST_OFF);
    OTP_trig = 1'b0;
    t_event = $realtime;
    #(150.0 * US);
    check("OTP cleared: still off at 150 us (200 us release)", En === 1'b0);
    wait_en(1'b1, 0.5 * MS);
    check_range("OTP cleared: automatic restart after (us)", ($realtime - t_event) / US, 199.0, 205.0);
    wait_sup_state(ST_RUN, 15.0 * MS);
    check_eq("back in S_RUN after OTP (probe)", last_state, ST_RUN);

    UVLO_trig = 1'b1;
    t_event = $realtime;
    wait_en(1'b0, 2.0 * MS);
    check_range("UVLO: shutdown after (ms)", ($realtime - t_event) / MS, 0.99, 1.02);
    #(1.0 * US);
    check("UVLO: Red_LED3 lit", Red_LED3 === 1'b1);
    UVLO_trig = 1'b0;
    wait_en(1'b1, 0.5 * MS);
    check("UVLO cleared: restart", En === 1'b1);
    check("UVLO cleared: Red_LED3 dark", Red_LED3 === 1'b0);
    // Undervoltage again while the ramp is still running: S_SS -> S_OFF.
    #(100.0 * US);
    check("soft start still in progress", ss_active_int === 1'b1);
    UVLO_trig = 1'b1;
    wait_en(1'b0, 2.0 * MS);
    check("UVLO during soft start: off before the ramp completes", run_active_int === 1'b0);
    UVLO_trig = 1'b0;
    wait_en(1'b1, 0.5 * MS);
    wait_sup_state(ST_RUN, 15.0 * MS);
    check_eq("back in S_RUN after UVLO in soft start (probe)", last_state, ST_RUN);

    // ---------------------------------------------------------------
    // Phase 9: SPI disable ignored, OTP during a hiccup
    // ---------------------------------------------------------------
    note("Phase 9: keyed SPI disable ignored while running, OTP in a hiccup");
    // The frames that stop a full build in its phase 9
    spi_tx[0] = 8'h00;
    spi_frame_ignored(A_CONTROL, 1);
    spi_tx[0] = DISABLE_KEY; spi_tx[1] = 8'h00;
    spi_frame_ignored(A_DISKEY, 2);
    #(1.0 * US);
    check("keyed SPI disable has no effect: En still high", En === 1'b1);
    check_eq("keyed SPI disable has no effect: still S_RUN (probe)", sup_state, ST_RUN);
    check("spi_enable still tied high (probe)", sup_spi_en === 1'b1);

    // Over-temperature arriving during a hiccup cool-down: S_HICCUP -> S_OFF.
    CP_trig = 1'b1;
    wait_en(1'b0, 100.0 * US);
    CP_trig = 1'b0;
    OTP_trig = 1'b1;
    #(1.5 * MS);
    check("OTP during the cool-down: still off", En === 1'b0);
    check_eq("OTP during the cool-down: S_OFF, not a retry (probe)", sup_state, ST_OFF);
    OTP_trig = 1'b0;
    wait_en(1'b1, 1.0 * MS);
    check("OTP cleared after the cool-down: restart", En === 1'b1);
    wait_sup_state(ST_RUN, 15.0 * MS);
    check_eq("back in S_RUN (probe)", last_state, ST_RUN);

    // ---------------------------------------------------------------
    // Phase 11: analog OVP trips the SCR
    // ---------------------------------------------------------------
    note("Phase 11: analog OVP trip, reset-button recovery");
    ovp_event = 1'b1;
    t_event = $realtime;
    wait_en(1'b0, 2.0 * MS);
    check_range("OVP: off after latch_stat debounce (ms)", ($realtime - t_event) / MS, 0.99, 1.02);
    check("OVP: the CPLD's own latch_out stays low", latch_out === 1'b0);
    #(1.0 * US);
    check("OVP: Red_LED1 solid", Red_LED1 === 1'b1);
    ovp_event = 1'b0;
    #(2.0 * MS);
    check("OVP: no restart while the SCR is latched", En === 1'b0);
    do_reset;
    #(300.0 * US);
    check("reset button: SCR cleared", latch_stat === 1'b0);
    check("reset button: Red_LED1 dark", Red_LED1 === 1'b0);
    check_eq("reset button: strike level cleared (probe)", strike_int, 0);
    wait_en(1'b1, 21.0 * MS);
    check("restart after reset (20 ms switch debounce again)", En === 1'b1);
    wait_sup_state(ST_RUN, 15.0 * MS);
    check_eq("S_RUN after reset (probe)", last_state, ST_RUN);

    // ---------------------------------------------------------------
    // Phase 12: strikes accumulate to latch, on the default hiccup times
    // ---------------------------------------------------------------
    note("Phase 12: persistent overcurrent, strikes to latch, default hiccup times");
    CP_trig = 1'b1;
    strike_hiccups = 0;
    t_event = $realtime;
    // RUN trip -> hiccup (10 ms) -> SS trip -> hiccup (20 ms) -> SS trip -> latch
    while ((latch_out !== 1'b1) && ($realtime - t_event < 60.0 * MS)) begin
        wait_en(1'b0, 60.0 * MS - ($realtime - t_event));
        // latch_assert lands one clock after the hiccup entry that earns it,
        // so look a few clocks later before deciding this was a retry
        #(5.0 * CLK_PERIOD_NS);
        if (latch_out !== 1'b1) strike_hiccups = strike_hiccups + 1;
        while ((En !== 1'b1) && (latch_out !== 1'b1) && ($realtime - t_event < 60.0 * MS))
            @(posedge clk);
    end
    check("latch_out asserted by repeated overcurrent", latch_out === 1'b1);
    check_eq("retries before the latch = MAX_STRIKES-1", strike_hiccups, MAX_STRIKES_DEF - 1);
    check_range("first trip to latch (ms): 10 + 20 ms of hiccups and three trips",
                ($realtime - t_event) / MS, 30.0, 30.4);
    check("En low once latched", En === 1'b0);
    CP_trig = 1'b0;
    #(10.0 * MS);
    check("no restart 10 ms after the fault clears", En === 1'b0);
    check("latch_out still set", latch_out === 1'b1);
    check("SCR read back latched", latch_stat === 1'b1);
    check("Red_LED1 solid", Red_LED1 === 1'b1);
    check_eq("strike level at latch (probe)", strike_int, MAX_STRIKES_DEF);
    do_reset;
    #(10.0 * US);
    check("reset clears latch_out", latch_out === 1'b0);
    #(300.0 * US);
    check("reset clears the SCR", latch_stat === 1'b0);
    check_eq("reset clears the strike level (probe)", strike_int, 0);

    // ---------------------------------------------------------------
    // Phase 13: restart after a latch, enable switch, stuck modulator
    // ---------------------------------------------------------------
    note("Phase 13: restart after a latch, enable switch off and on, modulator stuck high");
    wait_en(1'b1, 21.0 * MS);
    check("latched part restarts after the reset button", En === 1'b1);
    wait_sup_state(ST_RUN, 15.0 * MS);
    check_eq("S_RUN after the latch is cleared (probe)", last_state, ST_RUN);
    // A modulator stuck high: one pulse cut at the ceiling, then nothing until
    // the modulator falls - pwm_mask holds the envelope closed.
    @(negedge PWM_out);
            #(1.0);   // let the pulse monitor, woken by the same edge, record it
    pulses_before = pwm_pulses;
    osc_stuck_high = 1'b1;
    #(20.0 * SW_PERIOD_NS);
    check("stuck modulator: at most one PWM_out pulse", pwm_pulses - pulses_before <= 1);
    check("stuck modulator: PWM_out held low", PWM_out === 1'b0);
    check_range("stuck modulator: that pulse capped at MAX_ON+1 clocks (ns)", pwm_width_ns,
                0.0, (MAX_ON_COUNTS + 1) * CLK_PERIOD_NS + 1.0);
    if ((pwm_pulses - pulses_before <= 1) && (PWM_out === 1'b0)) cover_bin(C_STUCK);
    osc_stuck_high = 1'b0;
    #(5.0 * SW_PERIOD_NS);
    // enable switch: release and press, 20 ms of debounce each way
    en_from_switch = 1'b0;
    t_event = $realtime;
    #(19.8 * MS);
    check("switch released: En still high at 19.8 ms", En === 1'b1);
    wait_en(1'b0, 1.0 * MS);
    check_range("switch released: off after (ms)", ($realtime - t_event) / MS, 19.99, 20.05);
    en_from_switch = 1'b1;
    t_event = $realtime;
    wait_en(1'b1, 21.0 * MS);
    check_range("switch pressed: restart after (ms)", ($realtime - t_event) / MS, 19.99, 20.05);
    #(10.0 * US);
    check("switch pressed: back in soft start", ss_active_int === 1'b1);

    // ---------------------------------------------------------------
    // Run-long invariants, scoreboard
    // ---------------------------------------------------------------
    extra_phases;

    note("Run-long invariants and scoreboard");
    check_eq("MISO high at any time after reset (clocks; tied low without telemetry)", miso_idle, 0);
    check_eq("MISO x or z after reset (clocks)", miso_xz, 0);
    check_eq("MISO bits sampled high during every ignored SPI read", miso_high_bits, 0);
    $sformat(msg, "              (%0d SPI frames sent to the reduced build, none with any effect)",
             spi_frames_sent);
    emit(msg);
    check_eq("switch_supply mirrored PGOOD on every clock (mismatches)", mirror_errors, 0);
    check_eq("PGOOD high with En low for 2+ clocks", pgood_no_en, 0);
    check_eq("PWM_out pulses above the MAX_ON ceiling", backstop_errors, 0);
    check_eq("latch_out falls without a reset", latch_drops, 0);
    check_eq("FSM scoreboard: state mismatches", sm_mismatch, 0);
    check_eq("FSM scoreboard: En mismatches", en_mismatch, 0);
    $sformat(msg, "              (FSM scoreboard compared %0d clocks)", sm_compares);
    emit(msg);
    check_eq("PGOOD high outside S_RUN (clocks)", pgood_not_run, 0);
    check_eq("Green_LED disagreed with running-and-no-fault (clocks)", green_err, 0);
    check_eq("Red_LED2 / Red_LED3 disagreed with OTP / UVLO (clocks)", red23_err, 0);
    check_eq("PWM_out pulses longer than the ceiling in force", ceiling_err, 0);
    check_eq("latch_out set at a strike level other than MAX_STRIKES", latch_wrong, 0);

    finish_run("normal end");
end

end
endgenerate

endmodule

`default_nettype wire
