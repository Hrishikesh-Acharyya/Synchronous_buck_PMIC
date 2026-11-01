/*

# Filename:         pwm_mask.v

# File Description:  Per-cycle on-time limiter. Counts clk ticks for the
#                    duration of each incoming PWM pulse and truncates that
#                    pulse once the count reaches max_on_counts, re-arming on
#                    the low phase of the next switching cycle. The block can
#                    only shorten a pulse, never extend one, so the analog
#                    modulator keeps control whenever it commands less than
#                    the ceiling.
#                    Enforced on-time is max_on_counts + 1 clk. pulse_allowed
#                    is decided from the pre-edge run_counter, so it clears
#                    one clock after the ceiling is reached. Fixed offset,
#                    measured, not an error — account for it when setting
#                    MIN_ON_COUNTS / MAX_ON_COUNTS in soft_start.

#                   Verilog-2005, converted from rtl/protect/pwm_mask.sv by sv2v,
#                   with the comments restored by hand from the source.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module pwm_mask (
	clk,
	rst_n,
	pwm_sync,
	max_on_counts,
	pwm_out
);
	// Package constants used here, inlined by the conversion from
	// pmic_types_pkg.sv. Each is evaluated at elaboration; none is hardware.
	// DIGITAL_DUTY_PCT: digital ceiling, deliberately above the 70% analog
	//                   duty clamp so the mask is a secondary backstop and
	//                   never the primary limiter in normal operation.
	localparam signed [31:0] pmic_types_pkg_DIGITAL_DUTY_PCT = 75;
	// CLK_HZ: supervisor clock, from the external oscillator
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
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
	// ON_TIME_W: width of the on-time ceiling bus, must match soft_start
	parameter signed [31:0] ON_TIME_W = pmic_types_pkg_ON_TIME_W;
	input wire clk;
	input wire rst_n;
	input wire pwm_sync;  // synchronised raw PWM from the analog modulator
	input wire [ON_TIME_W - 1:0] max_on_counts;  // on-time ceiling count from soft_start
	output reg pwm_out;  // truncated PWM to the gate driver
	// run_counter: clk ticks elapsed within the present pulse
	reg [ON_TIME_W - 1:0] run_counter;
	// pulse_allowed: envelope gate, low once the present pulse has hit the ceiling
	reg pulse_allowed;
	/*
	Purpose:
	---
	Measure the on-time of each PWM pulse and close the envelope once it
	reaches the ceiling. run_counter is held at zero for the whole low phase
	and counts up through the high phase, so no edge detector is needed.

	pulse_allowed is armed on the low phase rather than on the rising edge:
	pwm_sync lags the raw PWM by two clocks through the input synchroniser,
	so arming on the edge would leave the gate still closed for the first
	clocks of every pulse and chop the front off each one.

	Once cleared, pulse_allowed stays cleared for the rest of the pulse even
	though pwm_sync is still high - only the low phase re-arms it. Without
	that hold the pulse could restart mid-cycle and hand the gate driver a
	double pulse.

	run_counter saturates at max_on_counts rather than wrapping, so a PWM
	input stuck high cannot roll the counter past its range and re-open the
	envelope.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			run_counter <= 0;
			pulse_allowed <= 1;
		end
		else if (pwm_sync) begin
			if (run_counter < max_on_counts) begin
				run_counter <= run_counter + 1;
				pulse_allowed <= 1;
			end
			else begin
				run_counter <= run_counter;
				pulse_allowed <= 0;
			end
		end
		else begin
			run_counter <= 0;
			pulse_allowed <= 1;
		end
	/*
	Purpose:
	---
	Register the masked PWM out to the gate driver. Flopping the output
	rather than driving it combinationally guarantees the driver never sees
	a glitch from unequal routing delays on pwm_sync and pulse_allowed - a
	glitch on the LM5106 IN pin is a shoot-through hazard. The register
	delays both edges equally, so pulse width is unaffected.

	Gate-drive enable is not gated here: supervisor.en drives the LM5106 EN
	pin, which holds both HO and LO low regardless of IN.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			pwm_out <= 0;
		else
			pwm_out <= pwm_sync & pulse_allowed;
endmodule
`default_nettype wire
