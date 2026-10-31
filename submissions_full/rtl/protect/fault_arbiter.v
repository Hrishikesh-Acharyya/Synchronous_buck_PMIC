/*

# Filename:         fault_arbiter.v

# File Description: Rolling-window overcurrent detector. Samples the
#                    current-protection flag at the valley, one sample per
#                    switching cycle taken at the rising edge of pwm_sync,
#                    and asserts window_trip / window_trip_SS when the
#                    number of faulted cycles within the trailing window
#                    exceeds the threshold for the present state. Two
#                    thresholds are used because elevated current during
#                    soft start is expected as the output capacitor charges,
#                    whereas sustained overcurrent in S_RUN is a real load
#                    fault.

#                   Verilog-2005, converted from rtl/protect/fault_arbiter.sv by sv2v,
#                   with the comments restored by hand from the source.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module fault_arbiter (
	clk,
	rst_n,
	pwm_sync,
	cp_sync,
	ss_active,
	run_active,
	trip_run,
	trip_ss,
	window_trip,
	window_trip_SS,
	fault_count_run_out,
	fault_count_ss_out
);
	// _sv2v_0: added by the conversion. An always_comb block runs once at
	// time zero; always @(*) does not, so each converted block reads this
	// constant-zero register to be evaluated at start-up in simulation.
	// Never assigned after time zero; synthesis removes it.
	reg _sv2v_0;
	// Package constants used here, inlined by the conversion from
	// pmic_types_pkg.sv. Each is evaluated at elaboration; none is hardware.
	// Thresholds differ by state because elevated current during soft start
	// is expected as the output capacitor charges from zero in FCCM, whereas
	// sustained overcurrent in S_RUN is a genuine load fault.
	//
	// WINDOW_RUN / TRIP_RUN: trailing switching cycles examined in S_RUN,
	//                        and the faulted count that trips window_trip
	localparam signed [31:0] pmic_types_pkg_WINDOW_RUN = 16;
	// WINDOW_RUN: trailing switching cycles examined while in S_RUN
	parameter signed [31:0] WINDOW_RUN = pmic_types_pkg_WINDOW_RUN;
	// WINDOW_SS / TRIP_SS: the same for S_SS, more tolerant
	localparam signed [31:0] pmic_types_pkg_WINDOW_SS = 32;
	// WINDOW_SS: trailing switching cycles examined while in S_SS
	parameter signed [31:0] WINDOW_SS = pmic_types_pkg_WINDOW_SS;
	// BLANK_CLKS: clocks of lookback applied to cp_sync, so the sample
	//             taken at pwm_rise reads the comparator as it was before
	//             high-side turn-on rather than during the switch-node slew.
	//             Must be >= 2; the shift concatenation below is malformed
	//             at 1.
	parameter signed [31:0] BLANK_CLKS = 5;
	input wire clk;
	input wire rst_n;
	input wire pwm_sync;  // synchronised raw PWM, for the cycle boundary
	input wire cp_sync;  // synchronised current-protection flag (CP_trig)
	input wire ss_active;  // high only while the supervisor is in S_SS
	input wire run_active;  // high only while the supervisor is in S_RUN
	// TRIP_W: width of the fault-window trip thresholds, now that both are
	//         host-writable registers rather than parameters. Sized from
	//         WINDOW_SS, the deeper of the two windows, so one width serves
	//         both and neither can be truncated by a call-site override.
	localparam signed [31:0] pmic_types_pkg_TRIP_W = 6;
	input wire [5:0] trip_run;  // TRIP_RUN: faulted cycles within WINDOW_RUN that assert window_trip
	input wire [5:0] trip_ss;  // TRIP_SS: faulted cycles within WINDOW_SS that assert window_trip_SS
	output reg window_trip;  // fault window exceeded while running
	output reg window_trip_SS;  // fault window exceeded during soft start
	output reg [$clog2(WINDOW_RUN + 1) - 1:0] fault_count_run_out;  // telemetry output
	output reg [$clog2(WINDOW_SS + 1) - 1:0] fault_count_ss_out;  // telemetry output
	localparam signed [31:0] FCNT_RUN_W = $clog2(WINDOW_RUN + 1);
	localparam signed [31:0] FCNT_SS_W = $clog2(WINDOW_SS + 1);
	// pwm_sync_d: pwm_sync delayed one clk, used to detect the cycle start
	reg pwm_sync_d;
	// pwm_rise: one-clk pulse marking high-side turn-on, i.e. the end of
	//           the low-side conduction period
	reg pwm_rise;
	// fault_shifter_SS: 32 bit register, each bit is the CP_trig value for one switching cycle,
	// sampled at the valley, with the most recent cycle in bit 0. Shifted
	// left each cycle to make room for the new sample
	reg [WINDOW_SS - 1:0] fault_shifter_SS;
	//fault_shifter_RUN: 16 bit register for RUN state fault handling
	reg [WINDOW_RUN - 1:0] fault_shifter_RUN;
	// fault_count_run: faulted cycles within the trailing WINDOW_RUN bits
	reg [FCNT_RUN_W - 1:0] fault_count_run;
	// fault_count_ss: faulted cycles within the trailing WINDOW_SS bits
	reg [FCNT_SS_W - 1:0] fault_count_ss;
	// cp_delay: shift register of cp_sync; bit [BLANK_CLKS-1] holds the
	//           comparator state from BLANK_CLKS clocks ago
	reg [BLANK_CLKS - 1:0] cp_delay;
	/*
	Purpose:
	---
	Create a one-clock delayed copy of the synchronised PWM so that the
	start of a switching cycle can be detected combinationally below.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			pwm_sync_d <= 0;
		else
			pwm_sync_d <= pwm_sync;
	/*
	Purpose:
	---
	Detect the rising edge of the switching cycle and produce a one-clk
	enable pulse. The sample is taken here
	because the end of low-side conduction is where inductor current is at
	its valley: valley sits one half-ripple below the average load current,
	and ripple amplitude varies strongly across the 10.8-22 V input range,
	so a fixed threshold on the valley tracks load current far more closely
	than one on the peak would. Peak sampling would make the effective trip
	current fall as Vin rises.

	The peak itself is not measurable here. It occurs at commutation, and
	the low-side FET only carries it during the reverse-recovery and
	ringing that follows its turn-on - the current has already fallen
	appreciably by the time the switch node settles enough to measure.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		pwm_rise = ~pwm_sync_d & pwm_sync;
	end
	// sv2v_cast_*: generated by the conversion. Each implements one
	// SystemVerilog width cast, N'(x), of the source: it returns its
	// argument resized to the declared width - a pure width conversion that adds no logic.
	function automatic [BLANK_CLKS - 1:0] sv2v_cast_A4FBD;
		input reg [BLANK_CLKS - 1:0] inp;
		sv2v_cast_A4FBD = inp;
	endfunction
	/*
	Purpose:
	---
	Hold a short history of cp_sync so that the sample latched at pwm_rise
	is the comparator state from BLANK_CLKS clocks earlier. Sampling at the
	edge itself would read the comparator during high-side turn-on, where
	the switch node slews tens of volts in nanoseconds and the sense signal
	is unusable. Looking backward rather than delaying the enable keeps the
	sample inside the low-side conduction period at every duty cycle.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			cp_delay <= 1'sb0;
		else if (!run_active && !ss_active)
			cp_delay <= 1'sb0;
		else
			cp_delay <= (cp_delay << 1) | sv2v_cast_A4FBD(cp_sync);
	function automatic [FCNT_RUN_W - 1:0] sv2v_cast_7CA3E;
		input reg [FCNT_RUN_W - 1:0] inp;
		sv2v_cast_7CA3E = inp;
	endfunction
	function automatic [WINDOW_RUN - 1:0] sv2v_cast_CCA05;
		input reg [WINDOW_RUN - 1:0] inp;
		sv2v_cast_CCA05 = inp;
	endfunction
	function automatic [FCNT_SS_W - 1:0] sv2v_cast_40C54;
		input reg [FCNT_SS_W - 1:0] inp;
		sv2v_cast_40C54 = inp;
	endfunction
	function automatic [WINDOW_SS - 1:0] sv2v_cast_5BB5F;
		input reg [WINDOW_SS - 1:0] inp;
		sv2v_cast_5BB5F = inp;
	endfunction
	/*
	Purpose:
	---
	Maintain a rolling window of the current-protection flag, one bit per
	switching cycle, and a running count of the faulted cycles within it.

	The flag is sampled as a level rather than as an edge: the comparator has
	hysteresis and holds high for as long as the overcurrent persists, and
	what matters thermally is the fraction of recent cycles spent in
	overcurrent, not how many separate excursions occurred. A single
	sustained fault must trip the window, and edge counting would never see
	it.

	The counts are maintained incrementally - plus the bit entering, minus
	the bit leaving the window - rather than by summing the register every
	clock, which would synthesise to a wide adder tree. Both reads use the
	pre-edge register value, so the indexed bit is the one about to be
	displaced.

	Both windows are cleared whenever neither state is active, so a hiccup
	retry starts on a clean window rather than re-tripping immediately on
	the history that caused the trip. cp_delay is cleared on the same
	condition, so the retry also starts without the
	comparator history from before the converter was switching - the CP
	synchroniser resets high, so that history would otherwise enter the
	fresh window as spurious faulted cycles.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			fault_shifter_RUN <= 0;
			fault_shifter_SS <= 0;
			fault_count_run <= 0;
			fault_count_ss <= 0;
		end
		else if (pwm_rise && run_active) begin
			fault_count_run <= (fault_count_run + sv2v_cast_7CA3E(cp_delay[BLANK_CLKS - 1])) - sv2v_cast_7CA3E(fault_shifter_RUN[WINDOW_RUN - 1]);
			fault_shifter_RUN <= (fault_shifter_RUN << 1) | sv2v_cast_CCA05(cp_delay[BLANK_CLKS - 1]);
		end
		else if (pwm_rise && ss_active) begin
			fault_count_ss <= (fault_count_ss + sv2v_cast_40C54(cp_delay[BLANK_CLKS - 1])) - sv2v_cast_40C54(fault_shifter_SS[WINDOW_SS - 1]);
			fault_shifter_SS <= (fault_shifter_SS << 1) | sv2v_cast_5BB5F(cp_delay[BLANK_CLKS - 1]);
		end
		else if (!run_active && !ss_active) begin
			fault_shifter_RUN <= 0;
			fault_shifter_SS <= 0;
			fault_count_run <= 0;
			fault_count_ss <= 0;
		end
	function automatic [5:0] sv2v_cast_67DF8;
		input reg [5:0] inp;
		sv2v_cast_67DF8 = inp;
	endfunction
	/*
	Purpose:
	---
	Run-window trip: the faulted-cycle count against its threshold. The
	thresholds differ because elevated current during soft start is expected
	as the output capacitor charges from zero in FCCM, whereas sustained
	overcurrent in S_RUN is a genuine load fault.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		window_trip = sv2v_cast_67DF8(fault_count_run) >= trip_run;
	end
	/*
	Purpose:
	---
	Soft-start-window trip: the same comparison against the more tolerant
	soft-start threshold.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		window_trip_SS = fault_count_ss >= trip_ss;
	end
	/*
	Purpose:
	---
	Telemetry copy of the run-window count, for the register file.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		fault_count_run_out = fault_count_run;
	end
	/*
	Purpose:
	---
	Telemetry copy of the soft-start-window count, for the register file.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		fault_count_ss_out = fault_count_ss;
	end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
