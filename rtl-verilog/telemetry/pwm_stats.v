/*

# Filename:         pwm_stats.v

# File Description: Telemetry for the incoming PWM from the analog
#                   modulator. Measures the length of each switching period
#                   in clk counts and the length of the high phase within
#                   it, and exports both for the previous complete period.
#
#                   The period is measured rather than assumed because the
#                   analog oscillator drifts from its nominal 111.1 clk
#                   ticks with temperature and component tolerance. Duty
#                   referenced to the nominal period would carry that drift
#                   straight into the error, and since duty times a known
#                   Vin infers Vout, the drift would appear as an output
#                   voltage error with no ADC in the loop to catch it.
#
#                   Exports raw clock counts rather than a computed duty
#                   cycle. A variable-denominator divide costs a few
#                   hundred LEs and will not close timing at 50 MHz in one
#                   cycle, and the reading MCU divides for free. The raw
#                   period also doubles as switching-frequency telemetry,
#                   which a quotient would discard.
#
#                   Both outputs describe the previous complete period and
#                   are captured from the same counter run, so they are
#                   always consistent with each other. Data is therefore one
#                   switching cycle old: the period is only known once it
#                   has ended.
#
#                   The period counter saturates at all-ones rather than
#                   wrapping. A stalled pwm_sync would otherwise roll it over
#                   and the next captured period would read short, which the
#                   host would take as a higher switching frequency. All-ones
#                   is a value a correct period can never produce, so it reads
#                   as out-of-range instead.
#
#                   Telemetry only. Drives no control path and takes no part
#                   in any protection timing.

#                   Verilog-2005, converted from rtl-systemverilog/telemetry/pwm_stats.sv by sv2v,
#                   with the comments restored by hand from the source.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module pwm_stats (
	clk,
	rst_n,
	pwm_sync,
	duty_count,
	prev_period
);
	// _sv2v_0: added by the conversion. An always_comb block runs once at
	// time zero; always @(*) does not, so each converted block reads this
	// constant-zero register to be evaluated at start-up in simulation.
	// Never assigned after time zero; synthesis removes it.
	reg _sv2v_0;
	// Package constants used here, inlined by the conversion from
	// pmic_types_pkg.sv. Each is evaluated at elaboration; none is hardware.
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
	parameter signed [31:0] CNT_W = pmic_types_pkg_CNT_W;
	input wire clk;
	input wire rst_n;
	//synchronised raw PWM
	input wire pwm_sync;
	//duty_count: keeps track of number of clock ticks the PWM was high for
	output reg [CNT_W - 1:0] duty_count;
	//prev_period: Stores the previous period length for calculations
	output reg [CNT_W - 1:0] prev_period;
	//pwm_fall: Gives idea of when the PWM has fallen for duty cycle measurement
	reg pwm_fall;
	//pwm_rise: Marks the start of the next switching cycle.
	reg pwm_rise;
	//pwm_sync_d: Delayed copy of pwm_sync, used to generate pwm_fall and pwm_rise
	reg pwm_sync_d;
	//period_counter: keeps track of how many clock ticks one switching cycle took
	reg [CNT_W - 1:0] period_counter;
	/*
	Purpose:
	---
	Create a one-clock delayed copy of the synchronised PWM so that the
	start of a switching cycle and the end of HS conduction can be detected combinationally below.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			pwm_sync_d <= 0;
		else
			pwm_sync_d <= pwm_sync;
	/*
	Purpose:
	---
	The blocks assign values to pwm_fall and pwm_rise. Check variable declaration comment
	for more information on the variables.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		pwm_fall = pwm_sync_d & ~pwm_sync;
	end
	/*
	Purpose:
	---
	Rising-edge pulse: the start of the next switching cycle, as described
	with pwm_fall above.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		pwm_rise = ~pwm_sync_d & pwm_sync;
	end
	/*
	Purpose:
	---
	Runs the period_counter.
	Clears and starts the counter on PWM rise, and before clearing the counter
	the old value is read into prev_counter so the data is not lost.
	On pwm_fall, it reads the current period count into duty counts to keep track
	of the HS conduction time, which is exported for the consumer to divide
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			period_counter <= 0;
			duty_count <= 0;
			prev_period <= 0;
		end
		else if (pwm_rise) begin
			prev_period <= period_counter;
			period_counter <= 0;
		end
		else if (period_counter == {CNT_W {1'sb1}}) begin
			if (pwm_fall)
				duty_count <= period_counter;
		end
		else if (pwm_fall) begin
			duty_count <= period_counter;
			period_counter <= period_counter + 1;
		end
		else
			period_counter <= period_counter + 1;
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
