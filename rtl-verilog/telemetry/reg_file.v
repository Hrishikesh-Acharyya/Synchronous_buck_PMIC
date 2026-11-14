/*

# Filename:         reg_file.v

# File Description: Register map for the PMIC supervisor. Presents a
#                   byte-addressable view of supervisor status to a host, and holds the
#                   writable control bits and protection thresholds..

#                   Verilog-2005, converted from rtl-systemverilog/telemetry/reg_file.sv by sv2v,
#                   with the comments restored by hand from the source.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module reg_file (
	clk,
	rst_n,
	addr,
	wr_en,
	wdata,
	rdata,
	rd_first,
	rd_byte_done,
	integrity_OK,
	txn_abort,
	sup_state,
	pgood,
	latch_state,
	en_switch,
	en_switch_rise,
	cp_state,
	otp_state,
	uvlo_state,
	strike_level,
	duty_count,
	prev_period,
	fault_count_run,
	fault_count_ss,
	fault_reg,
	fault_time,
	timestamp_ms,
	spi_enable,
	trip_run,
	trip_ss,
	max_strikes,
	max_on_limit,
	hiccup_base,
	cycles_per_step,
	clean_run_target,
	fault_reg_read_done
);
	// _sv2v_0: added by the conversion. An always_comb block runs once at
	// time zero; always @(*) does not, so each converted block reads this
	// constant-zero register to be evaluated at start-up in simulation.
	// Never assigned after time zero; synthesis removes it.
	reg _sv2v_0;
	// PMIC_ID: fixed identifier byte; lets the host confirm it is talking to this
	//              device rather than another slave answering on the same select
	parameter [7:0] PMIC_ID = 8'hb5;
	// VERSION_ID: {major[3:0], minor[3:0]} revision of the REGISTER MAP, not the RTL.
	//              Bump it when an address changes meaning, so firmware can refuse a
	//              map it does not understand
	parameter [7:0] VERSION_ID = 8'h01;
	// DISABLE_KEY_ID: magic byte arming a host-commanded disable
	parameter [7:0] DISABLE_KEY_ID = 8'hd1;
	// WRITE_ACCESS_KEY_ID: magic byte unlocking the threshold bank
	parameter [7:0] WRITE_ACCESS_KEY_ID = 8'ha7;
	// ARM_TIMEOUT_W: width of the arm expiry counter. At 50 MHz, 16 bits is about
	//                1.3 ms - far longer than any legal transaction, far shorter
	//                than a human notices.
	parameter signed [31:0] ARM_TIMEOUT_W = 16;
	input wire clk;
	input wire rst_n;
	//addr: 7 bit address
	input wire [6:0] addr;
	// wr_en: Indicates write command
	input wire wr_en;
	// wdata: host -> supervisor. Data that is to be written into supervisor by MCU
	input wire [7:0] wdata;
	// rdata: supervisor -> host. Data that supervisor gives
	output reg [7:0] rdata;
	// rd_first : first data byte of a read  -> triggers snapshot
	input wire rd_first;
	// rd_byte_done : the read data byte at addr has just been clocked out to the host
	input wire rd_byte_done;
	// integrity_OK   : write transaction passed length check and CRC
	input wire integrity_OK;
	// txn_abort    : transaction ended unvalidated -> discard temporary flop data.
	input wire txn_abort;
	// sup_state: supervisor FSM state. Telemetry, and ALSO the gate on hiccup_base,
	//            cycles_per_step and clean_run_target - those never change
	//            outside S_OFF (writing back their present value is allowed
	//            in any state)
	// encoding (state_t in the source): 2'b00 S_OFF, 2'b01 S_SS, 2'b10 S_RUN,
	// 2'b11 S_HICCUP
	input wire [1:0] sup_state;
	input wire pgood;
	input wire latch_state;
	input wire en_switch;
	input wire en_switch_rise;
	input wire cp_state;
	input wire otp_state;
	input wire uvlo_state;
	// Package constants used here, inlined by the conversion from
	// pmic_types_pkg.sv. Each is evaluated at elaboration; none is hardware.
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
	input wire [1:0] strike_level;
	// CLK_HZ: supervisor clock, from the external oscillator
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
	// CONVERTOR_HZ: switching frequency of the analog modulator
	localparam signed [31:0] pmic_types_pkg_CONVERTOR_HZ = 450000;
	// CLKS_PER_SW: clk ticks in one switching period. The true ratio is
	//              111.1, a non-integer: every counter in the
	//              design re-references to pwm_fall each cycle, so the
	//              fractional part never accumulates.
	localparam signed [31:0] pmic_types_pkg_CLKS_PER_SW = pmic_types_pkg_CLK_HZ / pmic_types_pkg_CONVERTOR_HZ;
	// CNT_W: width of a counter that must hold one full switching period in clk counts
	localparam signed [31:0] pmic_types_pkg_CNT_W = $clog2(pmic_types_pkg_CLKS_PER_SW + 1) + 1;
	input wire [pmic_types_pkg_CNT_W - 1:0] duty_count;
	input wire [pmic_types_pkg_CNT_W - 1:0] prev_period;
	input wire [4:0] fault_count_run;
	input wire [5:0] fault_count_ss;
	//FAULT_CAUSE_W: Width of the fault_cause reg in fault_cause.sv
	//                Also the number of faults
	localparam signed [31:0] pmic_types_pkg_FAULT_CAUSE_W = 5;
	input wire [4:0] fault_reg;
	//TIMESTAMP_W: Width of timestamp generstor register. Arbitrary. Gives ~4.6 hours of timestamping
	//              before resetting.
	localparam signed [31:0] pmic_types_pkg_TIMESTAMP_W = 24;
	input wire [23:0] fault_time;
	// timestamp_ms: free-running millisecond counter; timestamp source for the fault log
	input wire [23:0] timestamp_ms;
	// ---------------- control out ----------------
	// What registers the MCU can write
	output reg spi_enable;
	// WINDOW_SS / TRIP_SS: the same for S_SS, more tolerant
	localparam signed [31:0] pmic_types_pkg_WINDOW_SS = 32;
	// TRIP_W: width of the fault-window trip thresholds, now that both are
	//         host-writable registers rather than parameters. Sized from
	//         WINDOW_SS, the deeper of the two windows, so one width serves
	//         both and neither can be truncated by a call-site override.
	localparam signed [31:0] pmic_types_pkg_TRIP_W = 6;
	output reg [5:0] trip_run;
	output reg [5:0] trip_ss;
	output reg [1:0] max_strikes;
	// DIGITAL_DUTY_PCT: digital ceiling, deliberately above the 70% analog
	//                   duty clamp so the mask is a secondary backstop and
	//                   never the primary limiter in normal operation.
	localparam signed [31:0] pmic_types_pkg_DIGITAL_DUTY_PCT = 75;
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
	output reg [pmic_types_pkg_ON_TIME_W - 1:0] max_on_limit;
	// ms_to_clks: milliseconds -> clk counts
	function automatic signed [31:0] pmic_types_pkg_ms_to_clks;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_clks = 50000 * ms;
	endfunction
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_MAX_CLKS = pmic_types_pkg_ms_to_clks(20);
	// HICCUP_BASE_W: width of the writable base register. Sized for the
	//                largest LEGAL base, not the default.
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_W = $clog2(pmic_types_pkg_HICCUP_BASE_MAX_CLKS + 1);
	// hiccup_base: strike-level-0 cool-down in clk counts, not milliseconds
	output reg [pmic_types_pkg_HICCUP_BASE_W - 1:0] hiccup_base;
	// CYCLES_PER_STEP_MAX: ceiling for host writes. cycle_counter in soft_start
	//                      must be sized for the largest legal value, not the
	//                      default, or a legal write would truncate it.
	localparam signed [31:0] pmic_types_pkg_CYCLES_PER_STEP_MAX = 64;
	// CYC_STEP_W: width of the writable register and of soft_start's counter
	localparam signed [31:0] pmic_types_pkg_CYC_STEP_W = 7;
	// cycles_per_step: switching cycles per soft-start ramp step
	output reg [6:0] cycles_per_step;
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
	// clean_run_target: fault-free switching cycles in S_RUN that clear the
	//                   strike count
	output reg [pmic_types_pkg_CLEAN_RUN_W - 1:0] clean_run_target;
	//fault_reg_read_done: Indicated that the fault_register was read
	output reg fault_reg_read_done;
	reg write_rejected;  // set when a transaction's threshold writes are refused - all or nothing
	// ---- 0x00-0x0F : identity ----
	localparam [6:0] ADDR_PMIC_ID = 7'h00;
	localparam [6:0] ADDR_VERSION = 7'h01;
	localparam [6:0] ADDR_CAPABILITY = 7'h02;
	localparam [6:0] ADDR_SCRATCH = 7'h03;
	// ---- 0x10-0x3F : telemetry, read only ----
	localparam [6:0] ADDR_STATUS = 7'h10;
	localparam [6:0] ADDR_FAULT_FLAGS = 7'h11;
	localparam [6:0] ADDR_STRIKE_LEVEL = 7'h12;
	localparam [6:0] ADDR_DUTY_COUNT = 7'h13;
	localparam [6:0] ADDR_PREV_PERIOD = 7'h14;
	localparam [6:0] ADDR_FCOUNT_RUN = 7'h15;
	localparam [6:0] ADDR_FCOUNT_SS = 7'h16;
	localparam [6:0] ADDR_TIME_0 = 7'h18;
	localparam [6:0] ADDR_TIME_1 = 7'h19;
	localparam [6:0] ADDR_TIME_2 = 7'h1a;
	localparam [6:0] ADDR_BUS_ERR_L = 7'h1b;
	localparam [6:0] ADDR_BUS_ERR_H = 7'h1c;
	// Fault record: cause byte then the episode-start timestamp. Read as one
	// four-byte sweep; the clear fires only on leaving the TOP address, so a
	// partial read cannot destroy a record the host has not fully received.
	localparam [6:0] ADDR_FAULT_CAUSE = 7'h1d;
	localparam [6:0] ADDR_FTIME_0 = 7'h1e;
	localparam [6:0] ADDR_FTIME_1 = 7'h1f;
	localparam [6:0] ADDR_FTIME_2 = 7'h20;
	// ---- 0x40-0x4F : control ----
	// DISABLE_KEY sits directly below CONTROL so auto-increment carries the arm
	// and the command inside one transaction, under one CRC.
	localparam [6:0] ADDR_DISABLE_KEY = 7'h40;
	localparam [6:0] ADDR_CONTROL = 7'h41;
	// WRITE_ACCESS_KEY sits at the TOP of the bank for the same reason: the next
	// address after it is the first threshold.
	localparam [6:0] ADDR_WRITE_KEY = 7'h4f;
	// ---- 0x50-0x6F : thresholds, locked ----
	localparam [6:0] ADDR_TRIP_RUN = 7'h50;
	localparam [6:0] ADDR_TRIP_SS = 7'h51;
	localparam [6:0] ADDR_MAX_STRIKES = 7'h52;
	localparam [6:0] ADDR_MAX_ON = 7'h53;
	localparam [6:0] ADDR_HICCUP_0 = 7'h54;
	localparam [6:0] ADDR_HICCUP_1 = 7'h55;
	localparam [6:0] ADDR_HICCUP_2 = 7'h56;
	localparam [6:0] ADDR_CYC_PER_STEP = 7'h57;
	localparam [6:0] ADDR_CLEAN_RUN_0 = 7'h58;
	localparam [6:0] ADDR_CLEAN_RUN_1 = 7'h59;
	localparam [6:0] ADDR_CLEAN_RUN_2 = 7'h5a;
	// CAPABILITY_VAL: which optional blocks were compiled in. Lets one firmware
	// image serve several build configurations - the host reads this and knows
	// not to bother with addresses whose source does not exist yet.
	//   [0] pwm_stats present     [1] RESERVED
	//   [2] thresholds writable   [3] Fault Record exists
	//   [4] timestamp counter     [5] bus error counter
	localparam [7:0] CAPABILITY_VAL = 8'b00111101;
	//WD_TIMEOUT_MS: host silence tolerated before the SPI enable veto is released.
	//               Long enough that any sane polling rate never trips it, short
	//               enough that an unattended board recovers in a useful time.
	//               Firmware requirement: while holding the veto (spi_enable = 0)
	//               the host must complete a valid WRITE at least this often -
	//               e.g. to SCRATCH. Reads do not count as proof of life. Since
	//               SCRATCH commits only on integrity_OK, such a heartbeat proves
	//               the whole write path, CRC included, not just that SCK runs.
	localparam signed [31:0] WD_TIMEOUT_MS = 5000;
	// scratch_r: read-write byte with no effect on anything. The host writes a
	//            pattern and reads it back to prove both bus directions work
	//            before trusting any real register. Commits on integrity_OK like
	//            every other writable register, so the check exercises the same
	//            CRC gate a real write must pass.
	reg [7:0] scratch_r;
	// scratch_temp: a SCRATCH write lands here first; copied to scratch_r only
	//               on integrity_OK
	reg [7:0] scratch_temp;
	// scratch_pending: scratch_temp holds a write from the current transaction,
	//                  cleared at its end whether committed or aborted
	reg scratch_pending;
	// disable_armed: a valid DISABLE_KEY has been written; the next CONTROL write
	//                clearing bit 0 will be honoured
	reg disable_armed;
	// unlock_armed: a valid WRITE_ACCESS_KEY has been written; the threshold bank
	//               will accept a commit
	reg unlock_armed;
	// arm_timer: counts while either key is armed. An armed operation the host
	//            never follows through must lapse rather than sit armed forever -
	//            the MCU can be unplugged mid-sequence.
	reg [ARM_TIMEOUT_W - 1:0] arm_timer;
	reg [7:0] temp_trip_run;
	reg [7:0] temp_trip_ss;
	reg [7:0] temp_max_strk;
	reg [7:0] temp_max_on;
	reg [7:0] temp_hiccup_0;
	reg [7:0] temp_hiccup_1;
	reg [7:0] temp_hiccup_2;
	reg [7:0] temp_cyc_step;
	reg [7:0] temp_clean_0;
	reg [7:0] temp_clean_1;
	reg [7:0] temp_clean_2;
	// temp_dirty: one bit per temp register. Commit disturbs only what the
	//               host actually wrote in this transaction - a write touching
	//               TRIP_RUN must not also rewrite MAX_STRIKES from a stale temp.
	reg [10:0] temp_dirty;
	// en_pending / en_pending_val: a CONTROL write records its intent here rather
	// than changing spi_enable directly. The change applies only on integrity_OK,
	// so a transaction whose CRC fails cannot stop a running converter. The
	// thresholds already work this way; spi_enable is the one bit where getting it
	// wrong costs the load its power.
	reg en_pending;
	reg en_pending_val;
	// bus_err_count: failed transactions seen on the host bus - CRC mismatch, CS
	//                rising off a byte boundary, illegal length, or an SCK timeout
	//                poisoning the frame to S_DEAD. A healthy link leaves this at
	//                zero; a nonzero value that keeps climbing points at wiring,
	//                grounding or an MCU driving the bus wrongly.
	reg [15:0] bus_err_count;
	/*
	Purpose:
	         The output signal is used by fault_cause module to clear
	         the fault cause register and start logging a new episode.
	         It fires on what happened, not on how the address moved: a
	         READ data byte has just been clocked out (rd_byte_done) and
	         that byte was 0x20, the top of the four-byte record. The whole
	         record is therefore delivered before anything is destroyed,
	         and a host that stops before 0x20 gets a partial view but
	         loses nothing. A read that covers 0x20 clears the record,
	         including a one-byte read of 0x20 alone.

	         A command byte loading the address, or a write releasing a
	         byte, moves addr but is not a read, and cannot clear it. The
	         earlier form compared the address one clock apart and masked
	         writes with !wr_en; that only held while spi_slave stepped
	         addr on the same clock as wr_en, which was also what put
	         every write one address high.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		fault_reg_read_done = rd_byte_done && (addr == ADDR_FTIME_2);
	end
	//timestamp_snap: timestamp_ms frozen at the start of a read transaction
	reg [23:0] timestamp_snap;
	/*
	Purpose:
	---
	Freeze the free-running millisecond counter for the duration of a read, so the
	three bytes at 0x18-0x1A come from one coherent value.

	Without this the read mux samples the live counter as the pointer reaches each
	byte, and a tick landing mid-transaction stitches old and new bytes together.
	At a carry boundary that is not a small error: a counter at 0x00FFFF ticking to
	0x010000 between byte 0 and byte 1 reconstructs as 0x01FFFF, which is 65
	seconds adrift from a 1 ms timebase. A log of mostly-sane timestamps with
	occasional impossible ones is worse than one that is uniformly coarse.

	rd_first pulses at the start of ANY read transaction, so the freeze happens
	before the first byte is loaded regardless of which address the sweep begins
	at. The snapshot is therefore as old as the transaction start - tens of
	microseconds - which is invisible against a 1 ms tick. Consistency matters here
	and freshness does not.

	fault_time needs no snapshot: it is already frozen by construction, held until
	the host read that destroys it.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			timestamp_snap <= 1'sb0;
		else if (rd_first)
			timestamp_snap <= timestamp_ms;
	//wd_mark: timestamp_ms at the last proof the host was alive
	reg [23:0] wd_mark;
	//wd_expired: host has been silent past the timeout while holding the veto
	reg wd_expired;
	//wd_restored: the watchdog, not the host, re-enabled the converter
	reg wd_restored;
	/*
	Purpose:
	---
	Hold the reference time the bus-silence watchdog measures against.

	Re-marked continuously while spi_enable is high, so the timeout always starts
	from the instant the veto is applied rather than from some earlier transaction.
	While the veto is held it is re-marked only on integrity_OK: a write with a
	valid CRC, whatever it wrote (a rejected threshold write still counts, since
	the host proved it is alive). Reads produce no integrity_OK and so never feed
	the watchdog - holding the veto requires writing.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			wd_mark <= 1'sb0;
		else if (spi_enable)
			wd_mark <= timestamp_ms;
		else if (integrity_OK)
			wd_mark <= timestamp_ms;
	// sv2v_cast_*: generated by the conversion. Each implements one
	// SystemVerilog width cast, N'(x), of the source: it returns its
	// argument resized to the declared width - a pure width conversion that adds no logic.
	function automatic signed [23:0] sv2v_cast_24_signed;
		input reg signed [23:0] inp;
		sv2v_cast_24_signed = inp;
	endfunction
	/*
	Purpose:
	---
	Flag an expired watchdog. Gated on the veto actually being held, so the counter
	is meaningless - and the status bit never set - during normal operation when
	spi_enable is already high.

	Unsigned subtraction, so a timestamp_ms wrap between the mark and the present
	still yields the correct elapsed interval.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		wd_expired = !spi_enable && ((timestamp_ms - wd_mark) >= sv2v_cast_24_signed(WD_TIMEOUT_MS));
	end
	/*
	Purpose:
	---
	Count failed host transactions. spi_slave already distinguishes a good write
	from a bad one and reduces every failure mode to txn_abort, so nothing new has to
	be detected here - this block only keeps the tally.

	Saturating, not wrapping. A wrapped counter reading 3 could mean three errors
	or sixty-five thousand.

	Cleared only by rst_n. The host reads it periodically and takes differences; a
	clear-on-read would need its own address edge-detect and buys nothing a
	subtraction does not already give.

	LIMITATION: txn_abort is raised only for WRITE transactions - spi_slave gates it on
	cs_rise && !rw, because a read carries no CRC and has nothing to validate. A
	read that times out or ends misaligned is therefore not counted.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			bus_err_count <= 1'sb0;
		else if (txn_abort && !(&bus_err_count))
			bus_err_count <= bus_err_count + 1'b1;
	// Thresholds differ by state because elevated current during soft start
	// is expected as the output capacitor charges from zero in FCCM, whereas
	// sustained overcurrent in S_RUN is a genuine load fault.
	//
	// WINDOW_RUN / TRIP_RUN: trailing switching cycles examined in S_RUN,
	//                        and the faulted count that trips window_trip
	localparam signed [31:0] pmic_types_pkg_WINDOW_RUN = 16;
	function automatic signed [5:0] sv2v_cast_67DF8_signed;
		input reg signed [5:0] inp;
		sv2v_cast_67DF8_signed = inp;
	endfunction
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	/*
	clamp_trip_run: saturate a run-window threshold. The window is WINDOW_RUN
	cycles deep, so a threshold above it could never be reached - that would
	silently disable overcurrent protection in S_RUN.
	*/
	function automatic [5:0] clamp_trip_run;
		input reg [7:0] input_trip_run;
		if (input_trip_run < 8'd1)
			clamp_trip_run = sv2v_cast_67DF8_signed(1);
		else if (input_trip_run > sv2v_cast_8_signed(pmic_types_pkg_WINDOW_RUN))
			clamp_trip_run = sv2v_cast_67DF8_signed(pmic_types_pkg_WINDOW_RUN);
		else
			clamp_trip_run = input_trip_run[5:0];
	endfunction
	/*
	clamp_trip_ss: the same for the deeper soft-start window
	*/
	function automatic [5:0] clamp_trip_ss;
		input reg [7:0] input_trip_ss;
		if (input_trip_ss < 8'd1)
			clamp_trip_ss = sv2v_cast_67DF8_signed(1);
		else if (input_trip_ss > sv2v_cast_8_signed(pmic_types_pkg_WINDOW_SS))
			clamp_trip_ss = sv2v_cast_67DF8_signed(pmic_types_pkg_WINDOW_SS);
		else
			clamp_trip_ss = input_trip_ss[5:0];
	endfunction
	function automatic signed [1:0] sv2v_cast_6B4D7_signed;
		input reg signed [1:0] inp;
		sv2v_cast_6B4D7_signed = inp;
	endfunction
	/*
	clamp_max_strikes: DOWNWARD ONLY. STRIKE_W and HICCUP_TIMER_W are both sized
	from MAX_STRIKES_DEFAULT, so raising it past the default would overflow
	strike_level and under-size the cool-down counter.
	*/
	function automatic [1:0] clamp_max_strikes;
		input reg [7:0] input_max_strikes;
		if (input_max_strikes < 8'd1)
			clamp_max_strikes = sv2v_cast_6B4D7_signed(1);
		else if (input_max_strikes > sv2v_cast_8_signed(pmic_types_pkg_MAX_STRIKES_DEFAULT))
			clamp_max_strikes = sv2v_cast_6B4D7_signed(pmic_types_pkg_MAX_STRIKES_DEFAULT);
		else
			clamp_max_strikes = input_max_strikes[1:0];
	endfunction
	// Turn-on is delayed by the dead-time generator, turn-off is not, so
	// every gate pulse comes out shorter than commanded:
	//     HO on-time = commanded - (t_HPLH - t_HPHL)
	//
	// LM5106_SHRINK_NS: worst-case shrinkage, from the Switching
	//                   Characteristics table at RDT = 10k. Maximum upper
	//                   turn-on delay 160 ns against typical upper turn-off
	//                   delay 32 ns. t_HPHL has no minimum specified, so 32
	//                   is the best available figure and real shrinkage
	//                   could be worse. Revisit if RDT changes - at
	//                   RDT = 100k this becomes ~658 ns.
	localparam signed [31:0] pmic_types_pkg_LM5106_SHRINK_NS = 128;
	// MIN_GATE_ON_NS: minimum on-time wanted at the gate. A design choice,
	//                 not a datasheet value: long enough for the FET to
	//                 enhance past the Miller plateau rather than dissipate
	//                 in the linear region.
	localparam signed [31:0] pmic_types_pkg_MIN_GATE_ON_NS = 112;
	// ns_to_clks: nanoseconds -> clk counts. Split into two steps because
	//             clocks-per-nanosecond is less than one and would truncate
	//             to zero in integer arithmetic.
	//             Rounds UP. Every caller asks for a MINIMUM time, and a
	//             floored count delivers less than was asked for: at 10 MHz
	//             240 ns is 2.4 clocks, and the floor of 2 commands 200 ns,
	//             leaving 72 ns at the gate after the LM5106 shrinkage
	//             instead of the 112 ns MIN_GATE_ON_NS requires. The +999
	//             is a ceiling for the /1000 and changes nothing when the
	//             division is exact, as it is at 50 MHz (12000 / 1000).
	function automatic signed [31:0] pmic_types_pkg_ns_to_clks;
		input reg signed [31:0] ns;
		pmic_types_pkg_ns_to_clks = ((50 * ns) + 999) / 1000;
	endfunction
	// MIN_ON_COUNTS: soft-start on-time floor. Commanded on-time must cover
	//                the driver shrinkage before any of it reaches the gate,
	//                so the floor is the sum of the two figures above, rounded
	//                up to whole clocks: 12 clocks (240 ns) at 50 MHz, about
	//                10.8% commanded duty.
	localparam signed [31:0] pmic_types_pkg_MIN_ON_COUNTS = pmic_types_pkg_ns_to_clks(pmic_types_pkg_LM5106_SHRINK_NS + pmic_types_pkg_MIN_GATE_ON_NS);
	function automatic signed [pmic_types_pkg_ON_TIME_W - 1:0] sv2v_cast_D6A01_signed;
		input reg signed [pmic_types_pkg_ON_TIME_W - 1:0] inp;
		sv2v_cast_D6A01_signed = inp;
	endfunction
	/*
	clamp_max_on: DOWNWARD ONLY. Writing a duty ceiling above the compile-time
	default would stop the LM5106 bootstrap capacitor recharging during low-side
	conduction, collapsing high-side gate drive and destroying the FET. A single
	register write must never be able to do that.

	WHEN IT TAKES EFFECT. max_on_limit changes on the commit, but soft_start
	copies it into the gate ceiling only while ramping. Written in S_OFF or
	S_SS it governs the present ramp; written in S_RUN it reaches the gate at
	the next soft start (a hiccup retry or any restart), and until then the
	gate keeps the ceiling the last ramp reached - which passed this same
	clamp, so it is never above the safe maximum. The deferral is deliberate:
	the duty ceiling only ever moves through a ramp, never under a loop that
	is regulating. The MAX_ON readback is therefore the limit the next ramp
	will use; in S_RUN it can differ from the ceiling on the gate.
	*/
	function automatic [pmic_types_pkg_ON_TIME_W - 1:0] clamp_max_on;
		input reg [7:0] input_max_on;
		if (input_max_on > sv2v_cast_8_signed(pmic_types_pkg_MAX_ON_COUNTS_DEFAULT))
			clamp_max_on = sv2v_cast_D6A01_signed(pmic_types_pkg_MAX_ON_COUNTS_DEFAULT);
		else if (input_max_on < sv2v_cast_8_signed(pmic_types_pkg_MIN_ON_COUNTS))
			clamp_max_on = sv2v_cast_D6A01_signed(pmic_types_pkg_MIN_ON_COUNTS);
		else
			clamp_max_on = input_max_on[pmic_types_pkg_ON_TIME_W - 1:0];
	endfunction
	function automatic signed [6:0] sv2v_cast_A371F_signed;
		input reg signed [6:0] inp;
		sv2v_cast_A371F_signed = inp;
	endfunction
	/*
	clamp_cyc_step: ramp rate. Zero would make the step condition never match.
	*/
	function automatic [6:0] clamp_cyc_step;
		input reg [7:0] input_cyc_step;
		if (input_cyc_step < 8'd1)
			clamp_cyc_step = sv2v_cast_A371F_signed(1);
		else if (input_cyc_step > sv2v_cast_8_signed(pmic_types_pkg_CYCLES_PER_STEP_MAX))
			clamp_cyc_step = sv2v_cast_A371F_signed(pmic_types_pkg_CYCLES_PER_STEP_MAX);
		else
			clamp_cyc_step = input_cyc_step[6:0];
	endfunction
	// HICCUP_BASE_MIN_CLKS / HICCUP_BASE_MAX_CLKS: the range proved safe at
	//                   design time. reg_file saturates host writes into this
	//                   range rather than rejecting them, so no firmware bug
	//                   can place the cool-down outside it.
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_MIN_CLKS = pmic_types_pkg_ms_to_clks(1);
	function automatic signed [pmic_types_pkg_HICCUP_BASE_W - 1:0] sv2v_cast_B4DD0_signed;
		input reg signed [pmic_types_pkg_HICCUP_BASE_W - 1:0] inp;
		sv2v_cast_B4DD0_signed = inp;
	endfunction
	/*
	clamp_hiccup: cool-down base in clk counts. The upper bound is what
	HICCUP_TIMER_W was sized for; exceeding it would overflow the cool-down
	counter and end the interval early.
	*/
	function automatic [pmic_types_pkg_HICCUP_BASE_W - 1:0] clamp_hiccup;
		input [23:0] input_hiccup;
		if (input_hiccup < sv2v_cast_24_signed(pmic_types_pkg_HICCUP_BASE_MIN_CLKS))
			clamp_hiccup = sv2v_cast_B4DD0_signed(pmic_types_pkg_HICCUP_BASE_MIN_CLKS);
		else if (input_hiccup > sv2v_cast_24_signed(pmic_types_pkg_HICCUP_BASE_MAX_CLKS))
			clamp_hiccup = sv2v_cast_B4DD0_signed(pmic_types_pkg_HICCUP_BASE_MAX_CLKS);
		else
			clamp_hiccup = input_hiccup[pmic_types_pkg_HICCUP_BASE_W - 1:0];
	endfunction
	// CLEAN_RUN_MIN_CYCLES: floor for host writes
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_MIN_CYCLES = pmic_types_pkg_ms_to_sw_cycles(100);
	function automatic signed [pmic_types_pkg_CLEAN_RUN_W - 1:0] sv2v_cast_DC11B_signed;
		input reg signed [pmic_types_pkg_CLEAN_RUN_W - 1:0] inp;
		sv2v_cast_DC11B_signed = inp;
	endfunction
	/*
	clamp_clean_run: fault-free cycles that clear the strike count. Bounded above
	by the counter width in strike_counter.
	*/
	function automatic [pmic_types_pkg_CLEAN_RUN_W - 1:0] clamp_clean_run;
		input reg [23:0] raw;
		if (raw < sv2v_cast_24_signed(pmic_types_pkg_CLEAN_RUN_MIN_CYCLES))
			clamp_clean_run = sv2v_cast_DC11B_signed(pmic_types_pkg_CLEAN_RUN_MIN_CYCLES);
		else if (raw > sv2v_cast_24_signed((2 ** pmic_types_pkg_CLEAN_RUN_W) - 1))
			clamp_clean_run = sv2v_cast_DC11B_signed((2 ** pmic_types_pkg_CLEAN_RUN_W) - 1);
		else
			clamp_clean_run = raw[pmic_types_pkg_CLEAN_RUN_W - 1:0];
	endfunction
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	/*
	Purpose:
	---
	Present the addressed byte combinationally. Holds no state: a wide mux routing
	existing signals. Default assignment before the case prevents latches on
	unimplemented addresses, which return 0x00 by contract.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		rdata = 8'h00;
		case (addr)
			ADDR_PMIC_ID: rdata = PMIC_ID;
			ADDR_VERSION: rdata = VERSION_ID;
			ADDR_CAPABILITY: rdata = CAPABILITY_VAL;
			ADDR_SCRATCH: rdata = scratch_r;
			ADDR_STATUS: rdata = {write_rejected, disable_armed, spi_enable, en_switch, latch_state, pgood, sup_state};
			ADDR_FAULT_FLAGS: rdata = {5'b00000, cp_state, otp_state, uvlo_state};
			ADDR_STRIKE_LEVEL: rdata = sv2v_cast_8(strike_level);
			ADDR_DUTY_COUNT: rdata = duty_count;
			ADDR_PREV_PERIOD: rdata = prev_period;
			ADDR_FCOUNT_RUN: rdata = sv2v_cast_8(fault_count_run);
			ADDR_FCOUNT_SS: rdata = sv2v_cast_8(fault_count_ss);
			ADDR_TIME_0: rdata = (rd_first ? timestamp_ms[7:0] : timestamp_snap[7:0]);
			ADDR_TIME_1: rdata = (rd_first ? timestamp_ms[15:8] : timestamp_snap[15:8]);
			ADDR_TIME_2: rdata = (rd_first ? sv2v_cast_8(timestamp_ms[23:16]) : sv2v_cast_8(timestamp_snap[23:16]));
			ADDR_BUS_ERR_L: rdata = bus_err_count[7:0];
			ADDR_BUS_ERR_H: rdata = bus_err_count[15:8];
			ADDR_FAULT_CAUSE: rdata = sv2v_cast_8(fault_reg);
			ADDR_FTIME_0: rdata = fault_time[7:0];
			ADDR_FTIME_1: rdata = fault_time[15:8];
			ADDR_FTIME_2: rdata = sv2v_cast_8(fault_time[23:16]);
			ADDR_CONTROL: rdata = {4'b0000, wd_restored, en_pending, disable_armed, spi_enable};
			ADDR_WRITE_KEY: rdata = {7'b0000000, unlock_armed};
			ADDR_DISABLE_KEY: rdata = {7'b0000000, disable_armed};
			ADDR_TRIP_RUN: rdata = sv2v_cast_8(trip_run);
			ADDR_TRIP_SS: rdata = sv2v_cast_8(trip_ss);
			ADDR_MAX_STRIKES: rdata = sv2v_cast_8(max_strikes);
			ADDR_MAX_ON: rdata = sv2v_cast_8(max_on_limit);
			ADDR_HICCUP_0: rdata = hiccup_base[7:0];
			ADDR_HICCUP_1: rdata = hiccup_base[15:8];
			ADDR_HICCUP_2: rdata = sv2v_cast_8(hiccup_base[pmic_types_pkg_HICCUP_BASE_W - 1:16]);
			ADDR_CYC_PER_STEP: rdata = sv2v_cast_8(cycles_per_step);
			ADDR_CLEAN_RUN_0: rdata = clean_run_target[7:0];
			ADDR_CLEAN_RUN_1: rdata = clean_run_target[15:8];
			ADDR_CLEAN_RUN_2: rdata = sv2v_cast_8(clean_run_target[pmic_types_pkg_CLEAN_RUN_W - 1:16]);
			default: rdata = 8'h00;
		endcase
	end
	/*
	Purpose:
	---
	Accept threshold writes into temp storage only. NOTHING here reaches a live
	register; BLOCK 4 does that on integrity_OK.

	Writes are accepted regardless of unlock state. The unlock is checked at commit,
	not here, so the gating lives in exactly one place - and so a host that writes
	the threshold before the key still fails cleanly rather than half-succeeding.

	The dirty bits are cleared on BOTH transaction boundaries: discarded on txn_abort,
	consumed on integrity_OK. Either way no temp survives into the next
	transaction, so a value written in one transaction cannot be committed by a
	later unrelated one.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			temp_dirty <= 1'sb0;
			temp_trip_run <= 1'sb0;
			temp_trip_ss <= 1'sb0;
			temp_max_strk <= 1'sb0;
			temp_max_on <= 1'sb0;
			temp_hiccup_0 <= 1'sb0;
			temp_hiccup_1 <= 1'sb0;
			temp_hiccup_2 <= 1'sb0;
			temp_cyc_step <= 1'sb0;
			temp_clean_0 <= 1'sb0;
			temp_clean_1 <= 1'sb0;
			temp_clean_2 <= 1'sb0;
		end
		else if (txn_abort || integrity_OK)
			temp_dirty <= 0;
		else if (wr_en)
			case (addr)
				ADDR_TRIP_RUN: begin
					temp_trip_run <= wdata;
					temp_dirty[0] <= 1'b1;
				end
				ADDR_TRIP_SS: begin
					temp_trip_ss <= wdata;
					temp_dirty[1] <= 1'b1;
				end
				ADDR_MAX_STRIKES: begin
					temp_max_strk <= wdata;
					temp_dirty[2] <= 1'b1;
				end
				ADDR_MAX_ON: begin
					temp_max_on <= wdata;
					temp_dirty[3] <= 1'b1;
				end
				ADDR_HICCUP_0: begin
					temp_hiccup_0 <= wdata;
					temp_dirty[4] <= 1'b1;
				end
				ADDR_HICCUP_1: begin
					temp_hiccup_1 <= wdata;
					temp_dirty[5] <= 1'b1;
				end
				ADDR_HICCUP_2: begin
					temp_hiccup_2 <= wdata;
					temp_dirty[6] <= 1'b1;
				end
				ADDR_CYC_PER_STEP: begin
					temp_cyc_step <= wdata;
					temp_dirty[7] <= 1'b1;
				end
				ADDR_CLEAN_RUN_0: begin
					temp_clean_0 <= wdata;
					temp_dirty[8] <= 1'b1;
				end
				ADDR_CLEAN_RUN_1: begin
					temp_clean_1 <= wdata;
					temp_dirty[9] <= 1'b1;
				end
				ADDR_CLEAN_RUN_2: begin
					temp_clean_2 <= wdata;
					temp_dirty[10] <= 1'b1;
				end
				default:
					;
			endcase
	// Multi-byte temps reassembled. Little endian: byte 0 is the low byte.
	reg [23:0] temp_hiccup_full;
	reg [23:0] temp_clean_full;
	/*
	Purpose:
	---
	Reassemble the three HICCUP_BASE temp bytes. Little endian: byte 0 is the
	low byte.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		temp_hiccup_full = {temp_hiccup_2, temp_hiccup_1, temp_hiccup_0};
	end
	/*
	Purpose:
	---
	Reassemble the three CLEAN_RUN temp bytes, little endian.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		temp_clean_full = {temp_clean_2, temp_clean_1, temp_clean_0};
	end
	// Strict multi-byte rule: all three bytes must have been written in this
	// transaction, or none of them commits. A partial write is a firmware bug, and
	// mixing a new low byte with an old high byte is exactly the nonsense value
	// temp flop use exists to prevent.
	reg hiccup_all;
	reg hiccup_any;
	reg clean_all;
	reg clean_any;
	/*
	Purpose:
	---
	Strict multi-byte rule: all three HICCUP_BASE bytes written in this
	transaction, or none of them commits. Mixing a new low byte with an old
	high byte is exactly the nonsense value the temp registers exist to stop.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		hiccup_all = &temp_dirty[6:4];
	end
	/*
	Purpose:
	---
	Any HICCUP_BASE byte written in this transaction. With hiccup_all it
	decides between commit and rejection.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		hiccup_any = |temp_dirty[6:4];
	end
	/*
	Purpose:
	---
	The strict multi-byte rule for CLEAN_RUN.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		clean_all = &temp_dirty[10:8];
	end
	/*
	Purpose:
	---
	Any CLEAN_RUN byte written in this transaction.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		clean_any = |temp_dirty[10:8];
	end
	// off_ok: the three registers compared against FREE-RUNNING counters change
	//         only in S_OFF, when neither counter is live. A live change
	//         landing below the current count would expire that counter instantly.
	reg off_ok;
	/*
	Purpose:
	---
	S_OFF-only gate. hiccup_base, cycles_per_step and clean_run_target are
	compared against free-running counters, so they change only in S_OFF, when
	neither counter is live.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		off_ok = sup_state == 2'b00;  // S_OFF
	end
	// off_change: this transaction would CHANGE an S_OFF-only register - its
	//             staged raw value differs from the live one. Writing back the
	//             present value is not a change, so firmware can rewrite the
	//             whole bank in any state.
	reg off_change;
	function automatic [23:0] sv2v_cast_24;
		input reg [23:0] inp;
		sv2v_cast_24 = inp;
	endfunction
	/*
	Purpose:
	---
	Tell a change to an S_OFF-only register from a write-back of its present
	value. The key lives for one transaction and addresses only increment, so
	reaching any threshold means writing every register below it; firmware does
	that as a read-modify-write of the bank. Without this test a running
	converter would refuse the whole frame for passing through hiccup_base,
	cycles_per_step and clean_run_target with their own values, leaving only the
	four live thresholds below 0x54 writable.

	The comparison is RAW (pre-clamp) staged value against the live register.
	Readback is post-clamp, so a value read back equals the live one exactly and
	a read-modify-write passes. A raw value that would only clamp TO the live
	value is still a change and is refused outside S_OFF: the rule stays "write
	back exactly what you read", with no clamp arithmetic in the decision.
	For a partly written multi-byte register the comparison reads stale temp
	bytes, but the partial rule below rejects that transaction regardless.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		off_change = ((temp_dirty[7] && (temp_cyc_step != sv2v_cast_8(cycles_per_step))) || (hiccup_any && (temp_hiccup_full != sv2v_cast_24(hiccup_base)))) || (clean_any && (temp_clean_full != sv2v_cast_24(clean_run_target)));
	end
	// threshold_reject: some threshold write in this transaction cannot be
	//                   honoured - no key, a change to an S_OFF-only register
	//                   outside S_OFF, or a partial multi-byte write. Any one
	//                   of them rejects every threshold write in the transaction.
	reg threshold_reject;
	/*
	Purpose:
	---
	Decide, before anything commits, whether the transaction's threshold writes
	can be honoured as a whole. Evaluated only where temp_dirty is non-zero; a
	transaction that wrote no threshold is never a rejection. The partial
	multi-byte rule holds in every state, whatever the value.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		threshold_reject = ((!unlock_armed || (off_change && !off_ok)) || (hiccup_any && !hiccup_all)) || (clean_any && !clean_all);
	end
	// CYCLES_PER_STEP_DEFAULT: switching cycles per soft-start ramp step, and
	//                          the reset value of the writable register
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
	/*
	Purpose:
	---
	Move validated temp values into the live threshold registers, clamping on the
	way IN rather than on the way out. Clamping on write means the register always
	holds a legal value, so a host readback shows what is actually in effect.

	Gating is decided once, in threshold_reject: no key, a change to an
	S_OFF-only register outside S_OFF, or a partial multi-byte write rejects every
	threshold write in the transaction. An accepted write-back of an S_OFF-only
	register commits its clamped value, which is the value it already holds. All or nothing, the strict multi-byte rule extended to the
	whole transaction, so the converter never runs a half-applied configuration.
	(hiccup_base, cycles_per_step and clean_run_target are S_OFF-only because they
	are compared against free-running counters; trip_run, trip_ss, max_strikes and
	max_on_limit are compared against bounded accumulators that re-reference every
	switching cycle, so a mid-run change to them is safe.)

	write_rejected is set by a rejected commit and cleared by an accepted one; a
	transaction that wrote no threshold leaves it alone, so a control-only write
	cannot clear a rejection the host has not read yet. It is reported in STATUS
	bit 7; the host reads sup_state in the same byte to tell a locked bank from a
	running converter.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			trip_run <= sv2v_cast_67DF8_signed(pmic_types_pkg_TRIP_RUN_DEFAULT);
			trip_ss <= sv2v_cast_67DF8_signed(pmic_types_pkg_TRIP_SS_DEFAULT);
			max_strikes <= sv2v_cast_6B4D7_signed(pmic_types_pkg_MAX_STRIKES_DEFAULT);
			max_on_limit <= sv2v_cast_D6A01_signed(pmic_types_pkg_MAX_ON_COUNTS_DEFAULT);
			hiccup_base <= sv2v_cast_B4DD0_signed(pmic_types_pkg_HICCUP_BASE_DEFAULT_CLKS);
			cycles_per_step <= sv2v_cast_A371F_signed(pmic_types_pkg_CYCLES_PER_STEP_DEFAULT);
			clean_run_target <= sv2v_cast_DC11B_signed(pmic_types_pkg_CLEAN_RUN_CYCLES);
			write_rejected <= 1'b0;
		end
		else if (integrity_OK && |temp_dirty) begin
			// All or nothing: one refused write rejects the whole set, so the
			// converter never runs a half-applied configuration. A transaction
			// that wrote no threshold leaves write_rejected alone.
			if (threshold_reject)
				write_rejected <= 1'b1;
			else begin
				write_rejected <= 1'b0;
				if (temp_dirty[0])
					trip_run <= clamp_trip_run(temp_trip_run);
				if (temp_dirty[1])
					trip_ss <= clamp_trip_ss(temp_trip_ss);
				if (temp_dirty[2])
					max_strikes <= clamp_max_strikes(temp_max_strk);
				if (temp_dirty[3])
					max_on_limit <= clamp_max_on(temp_max_on);
				if (temp_dirty[7])
					cycles_per_step <= clamp_cyc_step(temp_cyc_step);
				if (hiccup_any)
					hiccup_base <= clamp_hiccup(temp_hiccup_full);
				if (clean_any)
					clean_run_target <= clamp_clean_run(temp_clean_full);
			end
		end
	/*
	Purpose:
	---
	Hold the control bits and manage the two key-protected operations. The enable path
	is asymmetric: enabling takes one write, disabling needs a key first, because a
	spurious enable only removes a veto while a spurious disable stops a working
	supply. en_switch_rise is applied last so the physical switch wins any
	same-cycle collision.
	SCRATCH is staged like CONTROL: held in scratch_temp and committed only
	on integrity_OK, so a bad-CRC write leaves it unchanged.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			arm_timer <= 1'sb0;
			spi_enable <= 1'b1;
			scratch_r <= 8'h00;
			scratch_temp <= 8'h00;
			scratch_pending <= 1'b0;
			disable_armed <= 1'b0;
			unlock_armed <= 1'b0;
			en_pending <= 1'b0;
			en_pending_val <= 1'b0;
			wd_restored <= 1'b0;
		end
		else begin
			if (disable_armed || unlock_armed) begin
				arm_timer <= arm_timer + 1;
				if (&arm_timer) begin
					disable_armed <= 0;
					unlock_armed <= 0;
				end
			end
			else
				arm_timer <= 1'sb0;
			if (wr_en)
				case (addr)
					ADDR_SCRATCH: begin
						scratch_temp <= wdata;
						scratch_pending <= 1'b1;  // committed on integrity_OK, dropped on txn_abort
					end
					ADDR_DISABLE_KEY: disable_armed <= wdata == DISABLE_KEY_ID;
					ADDR_WRITE_KEY: unlock_armed <= wdata == WRITE_ACCESS_KEY_ID;
					ADDR_CONTROL:
						if (wdata[0]) begin
							en_pending <= 1'b1;
							en_pending_val <= 1'b1;
							disable_armed <= 0;
						end
						else if (disable_armed) begin
							en_pending <= 1'b1;
							en_pending_val <= 1'b0;
							disable_armed <= 1'b0;
						end
					default:
						;
				endcase
			if (integrity_OK) begin
				if (en_pending)
					spi_enable <= en_pending_val;
				if (scratch_pending)
					scratch_r <= scratch_temp;
			end
			if (txn_abort || integrity_OK) begin
				disable_armed <= 1'b0;
				unlock_armed <= 1'b0;
				en_pending <= 1'b0;
				en_pending_val <= 1'b0;
				scratch_pending <= 1'b0;
			end
			if (wd_expired) begin
				spi_enable <= 1'b1;
				wd_restored <= 1'b1;
			end
			if ((integrity_OK && en_pending) && !en_pending_val)
				wd_restored <= 1'b0;
			if (en_switch_rise)
				spi_enable <= 1'b1;
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
