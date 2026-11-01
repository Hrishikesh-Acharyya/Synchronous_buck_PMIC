/*

# Filename:         pmic_top.v

# File Description: Top level of the CPLD supervisor. Instantiates the reset
#                    synchroniser and one input synchroniser per asynchronous
#                    pin, then wires the supervisor FSM to the soft-start
#                    ramp, per-cycle PWM mask, rolling fault window, hiccup
#                    cool-down, strike counter and power-good generator.
#
#                    All clock domain crossing lives here: every signal from
#                    the analog side is comparator output with no relation to
#                    clk, and no submodule sees a raw pin. Each asynchronous
#                    input is synchronised once and the result distributed.
#
#                    OTP, UVLO, latch_stat and the enable switch pass
#                    through input_debounce between the synchroniser and
#                    the supervisor. CP_trig does not: fault_arbiter's
#                    rolling window already provides the duration filter.
#                    PGOOD_comp does not either: pgood_gen's deassert is
#                    immediate by design so the rail hands back before the
#                    output collapses.
#
#                    TELEMETRY_EN selects the host-facing blocks in or out:
#                    SPI slave, register file, fault log, timestamp and PWM
#                    statistics, with the SPI line synchronisers and filters
#                    that exist only for them. With it 0 the control path runs
#                    on the package defaults - the same values reg_file resets
#                    to - so a disabled build behaves exactly as an enabled one
#                    the host never writes. The Silicluster submission is the
#                    enabled build; the disabled build only costs the telemetry.

#                   Verilog-2005, converted from rtl-systemverilog/pmic_top.sv by sv2v,
#                   with the comments restored by hand from the source.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module pmic_top (
	clk,
	rst_n_pin,
	SCK,
	CS_n,
	MOSI,
	MISO,
	Osc_in,
	CP_trig,
	OTP_trig,
	UVLO_trig,
	latch_stat,
	PGOOD_comp,
	en_from_switch,
	PWM_out,
	En,
	PGOOD,
	latch_out,
	switch_supply,
	Green_LED,
	pgood_LED,
	Red_LED1,
	Red_LED2,
	Red_LED3
);
	// _sv2v_0: added by the conversion. An always_comb block runs once at
	// time zero; always @(*) does not, so each converted block reads this
	// constant-zero register to be evaluated at start-up in simulation.
	// Never assigned after time zero; synthesis removes it.
	reg _sv2v_0;
	// TELEMETRY_EN: 1 builds the SPI host interface, register file, fault log,
	//               timestamp and PWM statistics; 0 leaves them out and ties the
	//               control values to their package defaults. A generate
	//               condition: synthesis elaborates only the selected branch.
	parameter [0:0] TELEMETRY_EN = 1'b1;
	// ---- clock and reset ----
	input wire clk;  // Clk_Ext, 10 MHz external clock (Silicluster v3 maximum)
	input wire rst_n_pin;  // asynchronous external reset, active low
	//---SPI pins: 4-wire, a separate data line each way
	input wire SCK;
	input wire CS_n;
	input wire MOSI;  // SPI data in, master to supervisor
	output wire MISO;  // SPI data out, supervisor to master
	// ---- asynchronous inputs from the analog side ----
	input wire Osc_in;  // Master_PWM from the analog modulator
	input wire CP_trig;  // valley-current comparator
	input wire OTP_trig;  // over-temperature comparator
	input wire UVLO_trig;  // input undervoltage lockout comparator
	input wire latch_stat;  // SCR protection latch, read back
	input wire PGOOD_comp;  // output rail comparator
	input wire en_from_switch;  // Hardware switch input, driven by user physically
	// ---- outputs ----
	output wire PWM_out;  // masked PWM to the LM5106 IN pin
	output wire En;  // LM5106 enable driven by the supervisor FSM
	output wire PGOOD;  // supply changeover and telemetry
	output wire latch_out;  // CPLD-driven trip into the shared latch
	output wire switch_supply;  // NPN drive for the housekeeping rail changeover
	// ---- indicators ----
	output wire Green_LED;  // running, no fault present
	output wire pgood_LED;  // output rail in regulation
	output wire Red_LED1;  // latched trip (solid) or strikes outstanding (blink)
	output wire Red_LED2;  // over-temperature
	output wire Red_LED3;  // input undervoltage
	// ---- reset synchronization----
	wire rst_n;
	reset_sync rst_sync(
		.clk(clk),
		.rst_n_enter(rst_n_pin),
		.rst_n_exit(rst_n)
	);
	// ---- synchronised copies of the asynchronous inputs ----
	wire en_from_switch_sync;
	wire Osc_sync;
	wire CP_sync;
	wire OTP_sync;
	wire UVLO_sync;
	wire latch_stat_sync;
	wire PGOOD_comp_sync;
	//SPI SIGNALS
	wire sck_sync;
	wire cs_n_sync;
	wire mosi_sync;
	// ---- input synchronisers ----
	// Every asynchronous pin is synchronised once, here, and the result
	// distributed: no submodule sees a raw pin. Fault inputs reset to their
	// FAULT level (RESET_VALUE 1), so the supervisor assumes the worst until a
	// real reading arrives.
	input_sync u_osc_sync(
		.clk(clk),
		.rst_n(rst_n),
		.async_in(Osc_in),
		.sync_out(Osc_sync)
	);
	input_sync #(.RESET_VALUE(1'b1)) u_cp_sync(
		.clk(clk),
		.rst_n(rst_n),
		.async_in(CP_trig),
		.sync_out(CP_sync)
	);
	input_sync #(.RESET_VALUE(1'b1)) u_otp_sync(
		.clk(clk),
		.rst_n(rst_n),
		.async_in(OTP_trig),
		.sync_out(OTP_sync)
	);
	input_sync #(.RESET_VALUE(1'b1)) u_uvlo_sync(
		.clk(clk),
		.rst_n(rst_n),
		.async_in(UVLO_trig),
		.sync_out(UVLO_sync)
	);
	input_sync #(.RESET_VALUE(1'b1)) u_latch_stat_sync(
		.clk(clk),
		.rst_n(rst_n),
		.async_in(latch_stat),
		.sync_out(latch_stat_sync)
	);
	input_sync u_pgood_comp_sync(
		.clk(clk),
		.rst_n(rst_n),
		.async_in(PGOOD_comp),
		.sync_out(PGOOD_comp_sync)
	);
	input_sync u_en_from_switch_sync(
		.clk(clk),
		.rst_n(rst_n),
		.async_in(en_from_switch),
		.sync_out(en_from_switch_sync)
	);
	// SPI bus conditioning, built only with TELEMETRY_EN. Reset values are each
	// line's IDLE level: CS idles high, Mode 0 SCK idles low, MOSI idles low.
	// Resetting to the wrong level manufactures an edge on the first clock after
	// reset.
	generate
		if (TELEMETRY_EN) begin : g_spi_sync
			input_sync u_sck_sync(
				.clk(clk),
				.rst_n(rst_n),
				.async_in(SCK),
				.sync_out(sck_sync)
			);
			input_sync #(.RESET_VALUE(1'b1)) u_cs_sync(
				.clk(clk),
				.rst_n(rst_n),
				.async_in(CS_n),
				.sync_out(cs_n_sync)
			);
			input_sync u_mosi_sync(
				.clk(clk),
				.rst_n(rst_n),
				.async_in(MOSI),
				.sync_out(mosi_sync)
			);
		end
	endgenerate
	//-- debounced and filtered inputs--//
	wire en_from_switch_sync_db;
	wire OTP_sync_db;
	wire UVLO_sync_db;
	wire latch_stat_sync_db;
	//spi signals
	wire sck_filt;
	wire cs_n_filt;
	wire mosi_filt;
	// Package constants used here, inlined by the conversion from
	// pmic_types_pkg.sv. Each is evaluated at elaboration; none is hardware.
	// CLK_HZ: supervisor clock, from the external oscillator
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
	// ms_to_clks: milliseconds -> clk counts
	function automatic signed [31:0] pmic_types_pkg_ms_to_clks;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_clks = 50000 * ms;
	endfunction
	// ---- input debouncers ----
	// The enable switch is debounced symmetric and long, 20 ms each way:
	// mechanical contacts bounce on make and break alike. It resets low, since
	// fail-safe for an enable is off. OTP, UVLO and latch_stat take the module's
	// asymmetric defaults, 1 ms to assert and 200 us to release, and reset to
	// FAULT.
	input_debounce #(
		.ASSERT_CLKS(pmic_types_pkg_ms_to_clks(20)),
		.RELEASE_CLKS(pmic_types_pkg_ms_to_clks(20)),
		.RESET_VALUE(1'b0)
	) u_en_from_switch_db(
		.clk(clk),
		.rst_n(rst_n),
		.flag_in(en_from_switch_sync),
		.flag_out(en_from_switch_sync_db)
	);
	input_debounce u_OTP_sync_db(
		.clk(clk),
		.rst_n(rst_n),
		.flag_in(OTP_sync),
		.flag_out(OTP_sync_db)
	);
	input_debounce u_UVLO_sync_db(
		.clk(clk),
		.rst_n(rst_n),
		.flag_in(UVLO_sync),
		.flag_out(UVLO_sync_db)
	);
	input_debounce u_latch_stat_sync_db(
		.clk(clk),
		.rst_n(rst_n),
		.flag_in(latch_stat_sync),
		.flag_out(latch_stat_sync_db)
	);
	// SPI_FILTER_CLKS: identical on all three lines. Unequal delay between SCK and
	//                  MOSI shifts the data relative to the clock it is sampled
	//                  against, which is worse than no filtering at all.
	localparam signed [31:0] pmic_types_pkg_SPI_FILTER_CLKS = 8;  // 800 ns at 10 MHz (160 ns at 50 MHz)
	// SPI filters, built only with TELEMETRY_EN: input_debounce instanced
	// SYMMETRIC and SHORT, a different regime from the fault flags it was written
	// for. The symmetry is the critical part: spi_slave samples MOSI on an edge
	// derived from SCK, so unequal delay between the two shifts the data relative
	// to the clock it is sampled against. All three instances must therefore
	// carry IDENTICAL parameters - a retune of the fault-flag instances must not
	// be copied here.
	//
	// 8 clocks is 800 ns at 10 MHz: far longer than the tens of ns a switch-node
	// edge couples in, and longer than a 1 MHz SCK half-period. A read bit leaves
	// the slave about 12 clocks (1.2 us) after the master's falling edge, so the
	// host must hold each SCK phase well above that: 250 kHz SCK, a 2 us
	// half-period, is the verified rate. Noise lasting longer than the window is
	// not a glitch and is not this layer's job - CRC-8 in spi_slave catches it
	// and the transaction is discarded.
	generate
		if (TELEMETRY_EN) begin : g_spi_filt
			input_debounce #(
				.ASSERT_CLKS(pmic_types_pkg_SPI_FILTER_CLKS),
				.RELEASE_CLKS(pmic_types_pkg_SPI_FILTER_CLKS),
				.RESET_VALUE(1'b0)
			) u_sck_filt(
				.clk(clk),
				.rst_n(rst_n),
				.flag_in(sck_sync),
				.flag_out(sck_filt)
			);
			input_debounce #(
				.ASSERT_CLKS(pmic_types_pkg_SPI_FILTER_CLKS),
				.RELEASE_CLKS(pmic_types_pkg_SPI_FILTER_CLKS),
				.RESET_VALUE(1'b1)
			) u_cs_filt(
				.clk(clk),
				.rst_n(rst_n),
				.flag_in(cs_n_sync),
				.flag_out(cs_n_filt)
			);
			input_debounce #(
				.ASSERT_CLKS(pmic_types_pkg_SPI_FILTER_CLKS),
				.RELEASE_CLKS(pmic_types_pkg_SPI_FILTER_CLKS),
				.RESET_VALUE(1'b0)
			) u_mosi_filt(
				.clk(clk),
				.rst_n(rst_n),
				.flag_in(mosi_sync),
				.flag_out(mosi_filt)
			);
		end
	endgenerate
	wire ss_active;
	wire run_active;
	wire hiccup_active;
	wire hiccup_done;
	wire SS_done;
	wire window_trip;
	wire window_trip_SS;
	// MAX_STRIKES_DEFAULT: hiccup retries permitted before latch_assert, and
	//                      the reset value of the writable max_strikes
	//                      register. Writable DOWNWARD ONLY: raising it would
	//                      allow more retries into a persistent fault, and
	//                      would also widen STRIKE_W and HICCUP_TIMER_W, so
	//                      reg_file saturates upward writes at this value.
	localparam signed [31:0] pmic_types_pkg_MAX_STRIKES_DEFAULT = 3;
	// STRIKE_W: width of the strike level bus, shared by strike_counter and
	//           hiccup_timer
	localparam signed [31:0] pmic_types_pkg_STRIKE_W = 2;
	wire [1:0] strike_level;
	// DIGITAL_DUTY_PCT: digital ceiling, deliberately above the 70% analog
	//                   duty clamp so the mask is a secondary backstop and
	//                   never the primary limiter in normal operation.
	localparam signed [31:0] pmic_types_pkg_DIGITAL_DUTY_PCT = 75;
	// CONVERTOR_HZ: switching frequency of the analog modulator
	localparam signed [31:0] pmic_types_pkg_CONVERTOR_HZ = 450000;
	// CLKS_PER_SW: clk ticks in one switching period. The true ratio is
	//              22.2 at 10 MHz, a non-integer: every counter in the
	//              design re-references to pwm_fall each cycle, so the
	//              fractional part never accumulates.
	localparam signed [31:0] pmic_types_pkg_CLKS_PER_SW = pmic_types_pkg_CLK_HZ / pmic_types_pkg_CONVERTOR_HZ;
	// duty_to_counts: duty cycle in percent -> on-time in clk counts
	function automatic signed [31:0] pmic_types_pkg_duty_to_counts;
		input reg signed [31:0] duty_pct;
		pmic_types_pkg_duty_to_counts = (pmic_types_pkg_CLKS_PER_SW * duty_pct) / 100;
	endfunction
	// MAX_ON_COUNTS: on-time ceiling handed to pwm_mask
	localparam signed [31:0] pmic_types_pkg_MAX_ON_COUNTS_DEFAULT = pmic_types_pkg_duty_to_counts(pmic_types_pkg_DIGITAL_DUTY_PCT);
	// ON_TIME_W: width of the on-time ceiling bus, shared by soft_start and
	//            pwm_mask. Sized to hold MAX_ON_COUNTS, hence the +1.
	localparam signed [31:0] pmic_types_pkg_ON_TIME_W = $clog2(pmic_types_pkg_MAX_ON_COUNTS_DEFAULT + 1);
	wire [pmic_types_pkg_ON_TIME_W - 1:0] max_on_counts;
	// CNT_W: width of a counter that must hold one full switching period in clk counts
	localparam signed [31:0] pmic_types_pkg_CNT_W = $clog2(pmic_types_pkg_CLKS_PER_SW + 1) + 1;
	wire [pmic_types_pkg_CNT_W - 1:0] duty_count;
	wire [pmic_types_pkg_CNT_W - 1:0] prev_period;
	//TIMESTAMP_W: Width of timestamp generstor register. Arbitrary. Gives ~4.6 hours of timestamping
	//              before resetting.
	localparam signed [31:0] pmic_types_pkg_TIMESTAMP_W = 24;
	//timestamp_ms: The current time to ms precision since start of convertor
	wire [23:0] timestamp_ms;
	//fault_time: The timestamp from the start of an episode's fault,episodes is one mcu host read long
	wire [23:0] fault_time;
	// Driven here, consumed by reg_file.
	// sup_state: supervisor state, state_t in the source. Encoding: 2'b00 S_OFF,
	//            2'b01 S_SS, 2'b10 S_RUN, 2'b11 S_HICCUP.
	wire [1:0] sup_state;
	// Thresholds differ by state because elevated current during soft start
	// is expected as the output capacitor charges from zero in FCCM, whereas
	// sustained overcurrent in S_RUN is a genuine load fault.
	//
	// WINDOW_RUN / TRIP_RUN: trailing switching cycles examined in S_RUN,
	//                        and the faulted count that trips window_trip
	localparam signed [31:0] pmic_types_pkg_WINDOW_RUN = 16;
	wire [4:0] fault_count_run;
	// WINDOW_SS / TRIP_SS: the same for S_SS, more tolerant
	localparam signed [31:0] pmic_types_pkg_WINDOW_SS = 32;
	wire [5:0] fault_count_ss;
	reg en_switch_rise;  // en_from_switch_sync_db edge detction pulse
	//FAULT_CAUSE_W: Width of the fault_cause reg in fault_cause.sv
	//                Also the number of faults
	localparam signed [31:0] pmic_types_pkg_FAULT_CAUSE_W = 5;
	// fault_reg: one-hot accumulated fault causes, consumed by reg_file
	wire [4:0] fault_reg;
	// fault_reg_read_done: one-clk pulse from reg_file when the host reads 0x20
	wire fault_reg_read_done;
	// ---- host access port between spi_slave and reg_file ----
	wire [6:0] spi_addr;
	wire spi_wr_en;
	wire [7:0] spi_wdata;
	wire [7:0] spi_rdata;
	wire spi_rd_first;
	wire spi_rd_byte_done;  // a read data byte has been clocked out
	wire spi_integrity_ok;
	wire spi_abort;
	wire sdio_out;  // MISO data, from spi_slave
	wire sdio_oe;  // high only while sdio_out is read data (S_READ)
	// ---- reg_file control outputs ----
	wire spi_enable;
	// TRIP_W: width of the fault-window trip thresholds, now that both are
	//         host-writable registers rather than parameters. Sized from
	//         WINDOW_SS, the deeper of the two windows, so one width serves
	//         both and neither can be truncated by a call-site override.
	localparam signed [31:0] pmic_types_pkg_TRIP_W = 6;
	wire [5:0] trip_run;
	wire [5:0] trip_ss;
	wire [1:0] max_strikes;
	wire [pmic_types_pkg_ON_TIME_W - 1:0] max_on_limit;
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_MAX_CLKS = pmic_types_pkg_ms_to_clks(20);
	// HICCUP_BASE_W: width of the writable base register. Sized for the
	//                largest LEGAL base, not the default.
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_W = $clog2(pmic_types_pkg_HICCUP_BASE_MAX_CLKS + 1);
	wire [pmic_types_pkg_HICCUP_BASE_W - 1:0] hiccup_base;
	// CYCLES_PER_STEP_MAX: ceiling for host writes. cycle_counter in soft_start
	//                      must be sized for the largest legal value, not the
	//                      default, or a legal write would truncate it.
	localparam signed [31:0] pmic_types_pkg_CYCLES_PER_STEP_MAX = 64;
	// CYC_STEP_W: width of the writable register and of soft_start's counter
	localparam signed [31:0] pmic_types_pkg_CYC_STEP_W = 7;
	wire [6:0] cycles_per_step;
	// CLEAN_RUN_MS: fault-free time in S_RUN that clears the strike count,
	//               so unrelated transients separated in time cannot
	//               accumulate into a permanent shutdown
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_MS = 1000;
	// ms_to_sw_cycles: milliseconds -> switching cycles.
	function automatic signed [31:0] pmic_types_pkg_ms_to_sw_cycles;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_sw_cycles = 450 * ms;
	endfunction
	// CLEAN_RUN_CYCLES: the same interval in switching cycles, and the reset
	//                   default of the writable clean_run_target register
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_CYCLES = pmic_types_pkg_ms_to_sw_cycles(pmic_types_pkg_CLEAN_RUN_MS);
	// CLEAN_RUN_W: width of the clean-run counter and of the writable target.
	//              strike_counter now compares against clean_run_target rather
	//              than saturating at all-ones, so the realised interval is
	//              the value written, not 2**CLEAN_RUN_W. At the default this
	//              is 1.000 s, where the saturating version gave 1.165 s.
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_W = $clog2(pmic_types_pkg_CLEAN_RUN_CYCLES + 1);
	wire [pmic_types_pkg_CLEAN_RUN_W - 1:0] clean_run_target;
	reg en_from_switch_sync_db_d;  // delayed en_from_switch_sync_db
	// Edge detect on the debounced switch. Its only consumer is reg_file, which
	// re-asserts spi_enable on a fresh switch press, so it goes with telemetry.
	generate
		if (TELEMETRY_EN) begin : g_en_switch_edge
			/*
			Purpose: Stores delayed copy of en_from_switch_sync_db for edge detection
			*/
			always @(posedge clk or negedge rst_n)
				if (!rst_n)
					en_from_switch_sync_db_d <= 0;
				else
					en_from_switch_sync_db_d <= en_from_switch_sync_db;
			/*
			Purpose: Edge detection on the physical enable switch signal synced and debounced
			*/
			always @(*) begin
				if (_sv2v_0)
					;
				en_switch_rise = ~en_from_switch_sync_db_d & en_from_switch_sync_db;
			end
		end
	endgenerate
	// ---- supervisor FSM ----
	supervisor u_supervisor(
		.clk(clk),
		.SS_done(SS_done),
		.rst_n(rst_n),
		.en_SW(en_from_switch_sync_db),
		.spi_enable(spi_enable),
		.latch_state(latch_stat_sync_db),
		.OTP(OTP_sync_db),
		.window_trip_SS(window_trip_SS),
		.window_trip(window_trip),
		.latch_assert(latch_out),
		.UVLO(UVLO_sync_db),
		.hiccup_done(hiccup_done),
		.en(En),
		.ss_active(ss_active),
		.run_active(run_active),
		.hiccup_active(hiccup_active),
		.state_out(sup_state)
	);
	// ---- protection ----
	// Rolling overcurrent window, hiccup cool-down, strike counter, soft-start
	// ramp and the per-cycle PWM mask.
	fault_arbiter u_fault_arbiter(
		.clk(clk),
		.rst_n(rst_n),
		.trip_run(trip_run),
		.trip_ss(trip_ss),
		.fault_count_run_out(fault_count_run),
		.fault_count_ss_out(fault_count_ss),
		.pwm_sync(Osc_sync),
		.cp_sync(CP_sync),
		.ss_active(ss_active),
		.run_active(run_active),
		.window_trip(window_trip),
		.window_trip_SS(window_trip_SS)
	);
	hiccup_timer u_hiccup_timer(
		.clk(clk),
		.rst_n(rst_n),
		.base_clks(hiccup_base),
		.hiccup_active(hiccup_active),
		.strike_level(strike_level),
		.hiccup_done(hiccup_done)
	);
	strike_counter u_strike_counter(
		.clk(clk),
		.rst_n(rst_n),
		.max_strikes(max_strikes),
		.clean_run_target(clean_run_target),
		.pwm_sync(Osc_sync),
		.hiccup_active(hiccup_active),
		.run_active(run_active),
		.window_trip(window_trip),
		.strike_level(strike_level),
		.latch_assert(latch_out)
	);
	soft_start u_soft_start(
		.clk(clk),
		.rst_n(rst_n),
		.pwm_sync(Osc_sync),
		.ss_active(ss_active),
		.run_active(run_active),
		.max_on_counts(max_on_counts),
		.max_on_limit(max_on_limit),
		.cycles_per_step(cycles_per_step),
		.SS_done(SS_done)
	);
	pwm_mask u_pwm_mask(
		.clk(clk),
		.rst_n(rst_n),
		.pwm_sync(Osc_sync),
		.max_on_counts(max_on_counts),
		.pwm_out(PWM_out)
	);
	// CYCLES_PER_STEP_DEFAULT: switching cycles per soft-start ramp step, and
	//                          the reset value of the writable register.
	//                          At 10 MHz the ramp has only 13 steps (MIN_ON 3 to
	//                          MAX_ON 16, against 71 at 50 MHz), so the old 16
	//                          would finish in 208 cycles, 0.46 ms, five times
	//                          sooner. Restoring the 50 MHz ramp of 71 x 16 =
	//                          1136 cycles needs 87 per step, above the
	//                          CYCLES_PER_STEP_MAX ceiling below, so the default
	//                          sits AT the ceiling: 13 x 64 = 832 cycles, 1.85 ms,
	//                          73% of the original ramp. The host can still
	//                          shorten it, never lengthen it.
	localparam signed [31:0] pmic_types_pkg_CYCLES_PER_STEP_DEFAULT = 16;
	// HICCUP_BASE_MS: cool-down for strike level 0, the RESET DEFAULT of the
	//                 host-writable hiccup_base register. Each strike doubles
	//                 it, so the default sequence is 10 / 20 ms. Only 2 retries
	//                 and latching on 3rd entry
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_MS = 5;
	// HICCUP_BASE_DEFAULT_CLKS: the same interval in clk counts. Clocks, not
	//                   switching cycles: the power stage is off throughout
	//                   S_HICCUP, so there is no PWM to count.
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_DEFAULT_CLKS = pmic_types_pkg_ms_to_clks(pmic_types_pkg_HICCUP_BASE_MS);
	localparam signed [31:0] pmic_types_pkg_TRIP_RUN_DEFAULT = 12;
	localparam signed [31:0] pmic_types_pkg_TRIP_SS_DEFAULT = 28;
	// sv2v_cast_*: generated by the conversion. Each implements one
	// SystemVerilog width cast, N'(x), of the source: it returns its
	// argument resized to the declared width - a pure width conversion that adds no logic.
	function automatic signed [5:0] sv2v_cast_67DF8_signed;
		input reg signed [5:0] inp;
		sv2v_cast_67DF8_signed = inp;
	endfunction
	function automatic signed [1:0] sv2v_cast_6B4D7_signed;
		input reg signed [1:0] inp;
		sv2v_cast_6B4D7_signed = inp;
	endfunction
	function automatic signed [pmic_types_pkg_ON_TIME_W - 1:0] sv2v_cast_D6A01_signed;
		input reg signed [pmic_types_pkg_ON_TIME_W - 1:0] inp;
		sv2v_cast_D6A01_signed = inp;
	endfunction
	function automatic signed [pmic_types_pkg_HICCUP_BASE_W - 1:0] sv2v_cast_B4DD0_signed;
		input reg signed [pmic_types_pkg_HICCUP_BASE_W - 1:0] inp;
		sv2v_cast_B4DD0_signed = inp;
	endfunction
	function automatic signed [6:0] sv2v_cast_A371F_signed;
		input reg signed [6:0] inp;
		sv2v_cast_A371F_signed = inp;
	endfunction
	function automatic signed [pmic_types_pkg_CLEAN_RUN_W - 1:0] sv2v_cast_DC11B_signed;
		input reg signed [pmic_types_pkg_CLEAN_RUN_W - 1:0] inp;
		sv2v_cast_DC11B_signed = inp;
	endfunction
	// ---- host interface, built only with TELEMETRY_EN ----
	// MISO is driven here and nowhere else. spi_slave's sdio_out carries the read
	// data and sdio_oe is high exactly while spi_slave is in S_READ, so MISO shows
	// read data during the read data phase and is held low at every other time -
	// a plain output, with no tri-state anywhere in the design. Both terms are
	// flops that change on different SCK edges, so MISO does not glitch. The
	// spi_slave port names keep the sdio_ prefix of the original 3-wire bus.
	generate
		if (TELEMETRY_EN) begin : g_telemetry
			assign MISO = sdio_oe & sdio_out;
			spi_slave u_spi_slave(
				.clk(clk),
				.rst_n(rst_n),
				.sck(sck_filt),
				.cs_n(cs_n_filt),
				.sdio_in(mosi_filt),
				.sdio_out(sdio_out),
				.sdio_oe(sdio_oe),
				.addr(spi_addr),
				.wr_en(spi_wr_en),
				.wdata(spi_wdata),
				.rdata(spi_rdata),
				.rd_first(spi_rd_first),
				.rd_byte_done(spi_rd_byte_done),
				.integrity_ok(spi_integrity_ok),
				.abort(spi_abort)
			);
			reg_file u_reg_file(
				.clk(clk),
				.rst_n(rst_n),
				.addr(spi_addr),
				.wr_en(spi_wr_en),
				.wdata(spi_wdata),
				.rdata(spi_rdata),
				.rd_first(spi_rd_first),
				.rd_byte_done(spi_rd_byte_done),
				.integrity_OK(spi_integrity_ok),
				.abort(spi_abort),
				.sup_state(sup_state),
				.pgood(PGOOD),
				.latch_state(latch_stat_sync_db),
				.en_switch(en_from_switch_sync_db),
				.en_switch_rise(en_switch_rise),
				.cp_state(CP_sync),
				.otp_state(OTP_sync_db),
				.uvlo_state(UVLO_sync_db),
				.strike_level(strike_level),
				.duty_count(duty_count),
				.prev_period(prev_period),
				.fault_count_run(fault_count_run),
				.fault_count_ss(fault_count_ss),
				.fault_reg(fault_reg),
				.timestamp_ms(timestamp_ms),
				.fault_time(fault_time),
				.fault_reg_read_done(fault_reg_read_done),
				.spi_enable(spi_enable),
				.trip_run(trip_run),
				.trip_ss(trip_ss),
				.max_strikes(max_strikes),
				.max_on_limit(max_on_limit),
				.hiccup_base(hiccup_base),
				.cycles_per_step(cycles_per_step),
				.clean_run_target(clean_run_target)
			);
			// Telemetry only. pwm_stats drives no control path and takes no part in
			// any protection timing, so it runs unconditionally from the synchronised
			// PWM rather than being gated on a supervisor state - duty and period are
			// as interesting during a fault as during normal running.
			pwm_stats u_pwm_stats(
				.clk(clk),
				.rst_n(rst_n),
				.pwm_sync(Osc_sync),
				.duty_count(duty_count),
				.prev_period(prev_period)
			);
			fault_cause u_fault_cause(
				.clk(clk),
				.rst_n(rst_n),
				.otp_state(OTP_sync_db),
				.uvlo_state(UVLO_sync_db),
				.latch_state(latch_stat_sync_db),
				.latch_assert(latch_out),
				.window_trip(window_trip),
				.window_trip_SS(window_trip_SS),
				.ss_active(ss_active),
				.run_active(run_active),
				.fault_reg_read_done(fault_reg_read_done),
				.timestamp_ms(timestamp_ms),
				.fault_time(fault_time),
				.fault_reg(fault_reg)
			);
		end
		else begin : g_no_telemetry
			// No host interface. MISO is held low and MOSI is unused, and every value
			// reg_file would have held is tied to the package constant reg_file resets
			// to. spi_enable is tied high
			// so the enable switch alone gates the converter - the same as an enabled
			// build whose host has never written CONTROL.
			assign MISO = 1'b0;
			assign spi_enable = 1'b1;
			assign trip_run = sv2v_cast_67DF8_signed(pmic_types_pkg_TRIP_RUN_DEFAULT);
			assign trip_ss = sv2v_cast_67DF8_signed(pmic_types_pkg_TRIP_SS_DEFAULT);
			assign max_strikes = sv2v_cast_6B4D7_signed(pmic_types_pkg_MAX_STRIKES_DEFAULT);
			assign max_on_limit = sv2v_cast_D6A01_signed(pmic_types_pkg_MAX_ON_COUNTS_DEFAULT);
			assign hiccup_base = sv2v_cast_B4DD0_signed(pmic_types_pkg_HICCUP_BASE_DEFAULT_CLKS);
			assign cycles_per_step = sv2v_cast_A371F_signed(pmic_types_pkg_CYCLES_PER_STEP_DEFAULT);
			assign clean_run_target = sv2v_cast_DC11B_signed(pmic_types_pkg_CLEAN_RUN_CYCLES);
		end
	endgenerate
	// ---- status ----
	pgood_gen u_pgood_gen(
		.clk(clk),
		.rst_n(rst_n),
		.pwm_sync(Osc_sync),
		.pgood_comp(PGOOD_comp_sync),
		.run_active(run_active),
		.PGOOD(PGOOD)
	);
	// Time base for the fault log only, so it goes with telemetry.
	generate
		if (TELEMETRY_EN) begin : g_timestamp
			timestamp u_timestamp(
				.clk(clk),
				.rst_n(rst_n),
				.timestamp_ms(timestamp_ms)
			);
		end
	endgenerate
	fault_LED u_fault_LED(
		.clk(clk),
		.rst_n(rst_n),
		.otp_state(OTP_sync_db),
		.uvlo_state(UVLO_sync_db),
		.latch_state(latch_stat_sync_db),
		.latch_assert(latch_out),
		.strike_level(strike_level),
		.ss_active(ss_active),
		.run_active(run_active),
		.pgood(PGOOD),
		.Green_LED(Green_LED),
		.pgood_LED(pgood_LED),
		.Red_LED1(Red_LED1),
		.Red_LED2(Red_LED2),
		.Red_LED3(Red_LED3)
	);
	/*
	switch_supply carries the same value as PGOOD but is a separate pin because
	the two have different electrical jobs. PGOOD is telemetry, driven into a
	high-impedance input. switch_supply sources base current into the NPN that
	pulls the P-FET gate down, so it carries real current and is the pin whose
	drive strength and series resistor matter. Keeping them separate also keeps
	the changeover's switching noise off the telemetry net.

	The deassert is immediate, inherited from pgood_gen. PGOOD_comp is a window
	comparator and reports only in or out, so a droop and a collapse are
	indistinguishable; handing back at the first sign is the only assumption
	safe in both cases.

	PWM_out is not gated by En here. En drives the LM5106 enable pin, which holds
	both gate outputs low regardless of the PWM input, so a second gate would be a
	second shutdown path to keep consistent. latch_out is driven straight from
	strike_counter's latch_assert and is also read back by the supervisor.
	*/
	assign switch_supply = PGOOD;
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
