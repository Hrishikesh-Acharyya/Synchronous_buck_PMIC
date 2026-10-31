/*

# Filename:         soft_start.v

# File Description: Generates the ramping on-time count ceiling used during
#                    soft start. Counts switching cycles of the incoming PWM
#                    and widens max_on_counts by one clk count every
#                    cycles_per_step cycles, from MIN_ON_COUNTS up to
#                    max_on_limit, then asserts SS_done. The ceiling is held
#                    through S_RUN as a digital backstop sitting above the
#                    70% analog duty clamp, and resets to the floor in any
#                    other state so that a hiccup retry always re-ramps.

#                   Verilog-2005, converted from rtl/protect/soft_start.sv by sv2v,
#                   with the comments restored by hand from the source.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module soft_start (
	clk,
	rst_n,
	pwm_sync,
	ss_active,
	run_active,
	cycles_per_step,
	max_on_limit,
	max_on_counts,
	SS_done
);
	// _sv2v_0: added by the conversion. An always_comb block runs once at
	// time zero; always @(*) does not, so each converted block reads this
	// constant-zero register to be evaluated at start-up in simulation.
	// Never assigned after time zero; synthesis removes it.
	reg _sv2v_0;
	// Package constants used here, inlined by the conversion from
	// pmic_types_pkg.sv. Each is evaluated at elaboration; none is hardware.
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
	// CLK_HZ: supervisor clock, from the external oscillator
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 10000000;
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
		pmic_types_pkg_ns_to_clks = ((10 * ns) + 999) / 1000;
	endfunction
	// MIN_ON_COUNTS: soft-start on-time floor. Commanded on-time must cover
	//                the driver shrinkage before any of it reaches the gate,
	//                so the floor is the sum of the two figures above, rounded
	//                up to whole clocks: 3 clocks (300 ns) at 10 MHz, about
	//                13.5% commanded duty.
	localparam signed [31:0] pmic_types_pkg_MIN_ON_COUNTS = pmic_types_pkg_ns_to_clks(pmic_types_pkg_LM5106_SHRINK_NS + pmic_types_pkg_MIN_GATE_ON_NS);
	// MIN_ON_COUNTS: starting on-time ceiling in clk counts
	parameter signed [31:0] MIN_ON_COUNTS = pmic_types_pkg_MIN_ON_COUNTS;
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
	// ON_TIME_W: width of the on-time ceiling bus
	parameter signed [31:0] ON_TIME_W = pmic_types_pkg_ON_TIME_W;
	input wire clk;
	input wire rst_n;
	input wire pwm_sync;  // synchronised raw PWM from the analog modulator
	input wire ss_active;  // high only while the supervisor is in S_SS
	input wire run_active;  // high only while the supervisor is in S_RUN
	// CYCLES_PER_STEP_MAX: ceiling for host writes. cycle_counter in soft_start
	//                      must be sized for the largest legal value, not the
	//                      default, or a legal write would truncate it.
	localparam signed [31:0] pmic_types_pkg_CYCLES_PER_STEP_MAX = 64;
	// CYC_STEP_W: width of the writable register and of soft_start's counter
	localparam signed [31:0] pmic_types_pkg_CYC_STEP_W = 7;
	input wire [6:0] cycles_per_step;  // switching cycles held at each ceiling before widening
	input wire [ON_TIME_W - 1:0] max_on_limit;  // final target, from reg_file
	output reg [ON_TIME_W - 1:0] max_on_counts;  // on-time ceiling count handed to pwm_mask
	output reg SS_done;  // ramp has reached MAX_ON_COUNTS
	// MIN_ON_CNT: MIN_ON_COUNTS sized to the ceiling bus
	localparam [ON_TIME_W - 1:0] MIN_ON_CNT = MIN_ON_COUNTS[ON_TIME_W - 1:0];
	// pwm_sync_d: pwm_sync delayed one clk, used to detect the cycle boundary
	reg pwm_sync_d;
	// pwm_fall: one-clk pulse marking the end of a switching cycle
	reg pwm_fall;
	// cycle_counter: switching cycles elapsed at the present ceiling
	reg [6:0] cycle_counter;
	/*
	Purpose:
	---
	Create a one-clock delayed copy of the incoming PWM so that the falling
	edge of a switching cycle can be detected combinationally below.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			pwm_sync_d <= 1'b0;
		else
			pwm_sync_d <= pwm_sync;
	/*
	Purpose:
	---
	Detect the falling edge of the incoming PWM and produce a one-clk pulse
	for the cycle counter. The falling edge is used rather than the rising
	edge so that max_on_counts is updated while the pulse is over and
	pwm_mask's run_counter is parked, never mid-pulse.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		pwm_fall = pwm_sync_d & ~pwm_sync;
	end
	/*
	Purpose:
	---
	Run the soft-start ramp. In S_SS, count switching cycles and widen
	max_on_counts by one count every CYCLES_PER_STEP cycles until it reaches
	max_on_limit, then assert SS_done. In S_RUN, hold everything so the ceiling
	persists as the running duty backstop. In any other state, reset to the
	floor so that a hiccup retry re-ramps from the bottom rather than
	re-enabling at full duty into an unresolved fault.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			cycle_counter <= 1'sb0;
			max_on_counts <= MIN_ON_CNT;
			SS_done <= 1'b0;
		end
		else if (ss_active) begin
			if (pwm_fall) begin
				if (cycle_counter == (cycles_per_step - 1'b1)) begin
					cycle_counter <= 1'sb0;
					if (max_on_counts == max_on_limit)
						SS_done <= 1'b1;
					else begin
						max_on_counts <= max_on_counts + 1;
						if ((max_on_counts + 1) == max_on_limit)
							SS_done <= 1'b1;
					end
				end
				else
					cycle_counter <= cycle_counter + 1;
			end
		end
		else if (run_active)
			;
		else begin
			cycle_counter <= 1'sb0;
			max_on_counts <= MIN_ON_CNT;
			SS_done <= 1'b0;
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
