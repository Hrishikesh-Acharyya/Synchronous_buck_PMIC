/*
# Filename:         input_debounce.v

# File Description:  Disagreement-counter debouncer for a single synchronised
#                    fault flag. Requires the input to hold a new level for
#                    a parameterised number of clocks before the output
#                    follows it, and clears the counter on any disagreement,
#                    so only a continuously stable input qualifies.
#
#                    Asymmetric by default: assert qualification is the
#                    longer of the two, because the flags this conditions
#                    are slow by nature. A thermal event develops over tens
#                    of milliseconds and an input-rail sag over the mains or
#                    load timescale, so a few milliseconds of assert delay
#                    loses nothing real while rejecting switching-node
#                    pickup, ground bounce during load steps, and rail
#                    changeover transients. The failure this guards against
#                    is a false shutdown of a healthy board, not a missed
#                    fault.
#
#                    One instance per flag, parameters overridden at the
#                    call site. Not used on CP_trig: that flag is sampled
#                    once per switching cycle and fault_arbiter's rolling
#                    window already provides the duration filter, so a
#                    second layer would only slow the fastest protection.

#                    Instanced on OTP, UVLO and latch_stat in pmic_top, and
#                    on en_from_switch, where the parameters are overridden
#                    symmetric and long: mechanical contacts bounce equally
#                    on make and break, and a false assert or a false
#                    release are the same nuisance - a soft-start ramp
#                    started and abandoned. That instance also overrides
#                    RESET_VALUE low, since fail-safe for an enable is off,
#                    not on.

#                   Verilog-2005, converted from rtl-systemverilog/inputs/input_debounce.sv by sv2v,
#                   with the comments restored by hand from the source.

# Global variables: None

*/
`timescale 1ns/1ps
`default_nettype none
module input_debounce (
	clk,
	rst_n,
	flag_in,
	flag_out
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
	// ms_to_clks: milliseconds -> clk counts
	function automatic signed [31:0] pmic_types_pkg_ms_to_clks;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_clks = 50000 * ms;
	endfunction
	// DEBOUNCE_ASSERT_CLKS: clocks a flag must hold high continuously
	//                       before the debounced output asserts
	localparam signed [31:0] pmic_types_pkg_DEBOUNCE_ASSERT_CLKS = pmic_types_pkg_ms_to_clks(1);
	// ASSERT_CLKS: clocks flag_in must hold high before flag_out asserts
	parameter signed [31:0] ASSERT_CLKS = pmic_types_pkg_DEBOUNCE_ASSERT_CLKS;
	// DEBOUNCE_RELEASE_CLKS: clocks a flag must hold low continuously
	//                        before the debounced output releases
	localparam signed [31:0] pmic_types_pkg_DEBOUNCE_RELEASE_CLKS = pmic_types_pkg_ms_to_clks(1) / 5;  // 200 us
	// RELEASE_CLKS: clocks flag_in must hold low before flag_out releases
	parameter signed [31:0] RELEASE_CLKS = pmic_types_pkg_DEBOUNCE_RELEASE_CLKS;
	// RESET_VALUE: value flag_out takes out of reset; 1 is fail-safe for faults;
	//              for enable 0 is fail safe. It
	//              should match the RESET_VALUE of the feeding input_sync
	parameter [0:0] RESET_VALUE = 1'b1;
	input wire clk;
	input wire rst_n;
	input wire flag_in;  // synchronised comparator flag
	output reg flag_out;  // debounced flag to the supervisor
	// The source's elaboration-time $error checks, as the conversion renders
	// them: a generate branch that exists only for an illegal parameter value
	// and reports it at time zero. With legal parameters no branch is built.
	generate
		if (ASSERT_CLKS < 1) begin : gen_assert_clks_legal
			initial $display("Error [elaboration] rtl-systemverilog/inputs/input_debounce.sv:66:5 - input_debounce.gen_assert_clks_legal\n msg: ", "input_debounce: ASSERT_CLKS must be >= 1, got %0d", ASSERT_CLKS);
		end
		if (RELEASE_CLKS < 1) begin : gen_release_clks_legal
			initial $display("Error [elaboration] rtl-systemverilog/inputs/input_debounce.sv:72:5 - input_debounce.gen_release_clks_legal\n msg: ", "input_debounce: RELEASE_CLKS must be >= 1, got %0d", RELEASE_CLKS);
		end
	endgenerate
	// CNT_MAX: the longer of the two qualification times, which sizes the
	//          counter. ASSERT_CLKS is expected to be the larger, but the
	//          counter is sized for either so a call-site override cannot
	//          silently truncate.
	localparam signed [31:0] CNT_MAX = (ASSERT_CLKS > RELEASE_CLKS ? ASSERT_CLKS : RELEASE_CLKS);
	// CNT_W: width of the counter and the target compare
	localparam signed [31:0] CNT_W = $clog2(CNT_MAX + 1);
	// disagree_counter: clocks for which flag_in has disagreed with flag_out
	reg [CNT_W - 1:0] disagree_counter;
	// target_clks: qualification time for the pending transition, chosen by
	//              the direction flag_in is trying to move flag_out
	reg [CNT_W - 1:0] target_clks;
	// sv2v_cast_*: generated by the conversion. Each implements one
	// SystemVerilog width cast, N'(x), of the source: it returns its
	// argument resized to the declared width - a pure width conversion that adds no logic.
	function automatic signed [CNT_W - 1:0] sv2v_cast_7B3D1_signed;
		input reg signed [CNT_W - 1:0] inp;
		sv2v_cast_7B3D1_signed = inp;
	endfunction
	/*
	Purpose:
	---
	Select the qualification time for whichever transition is pending. The
	direction is implied by flag_in differing from flag_out: if flag_in is
	high while flag_out is low, an assert is pending and ASSERT_CLKS
	applies. Picking the target combinationally keeps a single counter and
	a single compare rather than duplicating the counter per direction.
	*/
	always @(*) begin
		if (_sv2v_0)
			;
		target_clks = (flag_in ? sv2v_cast_7B3D1_signed(ASSERT_CLKS) : sv2v_cast_7B3D1_signed(RELEASE_CLKS));
	end
	/*
	Purpose:
	---
	Count the clocks for which flag_in has disagreed with the believed
	state, and clear the count the moment they agree again. Only a
	continuously stable input therefore qualifies: a glitch part-way
	through an attempted transition restarts the count from zero.

	The count clears on the edge it reaches its target, which is the edge
	flag_out flips on. The next window therefore starts from zero even when
	it begins on the very next clock - flag_in reversing straight after the
	flip - and has to earn its full qualification time.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			disagree_counter <= 0;
		else if (flag_in != flag_out) begin
			if (disagree_counter < (target_clks - 1'b1))
				disagree_counter <= disagree_counter + 1;
			else
				disagree_counter <= 0;
		end
		else
			disagree_counter <= 0;
	/*
	Purpose:
	---
	Flip the believed state once the disagreement has persisted for the
	selected qualification time. flag_out is registered rather than driven
	combinationally from the compare so that the supervisor sees a clean
	single-clock transition with no decode glitch.

	RESET_VALUE is fail-safe high for the protection flags, matching the
	input_sync instances feeding them, so the supervisor sees a fault
	asserted until the real comparator level has qualified rather than
	treating an unknown rail as healthy.
	*/
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			flag_out <= RESET_VALUE;
		else if ((flag_in != flag_out) && (disagree_counter >= (target_clks - 1'b1)))
			flag_out <= flag_in;
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
