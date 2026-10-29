`default_nettype none
`default_nettype wire
`default_nettype none
module reset_sync (
	clk,
	rst_n_enter,
	rst_n_exit
);
	input wire clk;
	input wire rst_n_enter;
	output reg rst_n_exit;
	reg meta_ff;
	always @(posedge clk or negedge rst_n_enter)
		if (!rst_n_enter)
			meta_ff <= 1'b0;
		else
			meta_ff <= 1'b1;
	always @(posedge clk or negedge rst_n_enter)
		if (!rst_n_enter)
			rst_n_exit <= 1'b0;
		else
			rst_n_exit <= meta_ff;
endmodule
`default_nettype wire
`default_nettype none
module input_sync (
	clk,
	rst_n,
	async_in,
	sync_out
);
	parameter [0:0] RESET_VALUE = 1'b0;
	input wire clk;
	input wire rst_n;
	input wire async_in;
	output reg sync_out;
	reg meta_ff;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			meta_ff <= RESET_VALUE;
			sync_out <= RESET_VALUE;
		end
		else begin
			meta_ff <= async_in;
			sync_out <= meta_ff;
		end
endmodule
`default_nettype wire
`default_nettype none
module input_debounce (
	clk,
	rst_n,
	flag_in,
	flag_out
);
	reg _sv2v_0;
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
	function automatic signed [31:0] pmic_types_pkg_ms_to_clks;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_clks = 50000 * ms;
	endfunction
	localparam signed [31:0] pmic_types_pkg_DEBOUNCE_ASSERT_CLKS = pmic_types_pkg_ms_to_clks(1);
	parameter signed [31:0] ASSERT_CLKS = pmic_types_pkg_DEBOUNCE_ASSERT_CLKS;
	localparam signed [31:0] pmic_types_pkg_DEBOUNCE_RELEASE_CLKS = pmic_types_pkg_ms_to_clks(1) / 5;
	parameter signed [31:0] RELEASE_CLKS = pmic_types_pkg_DEBOUNCE_RELEASE_CLKS;
	parameter [0:0] RESET_VALUE = 1'b1;
	input wire clk;
	input wire rst_n;
	input wire flag_in;
	output reg flag_out;
	generate
		if (ASSERT_CLKS < 1) begin : gen_assert_clks_legal
			initial $display("Error [elaboration] ../rtl/inputs/input_debounce.sv:65:9 - input_debounce.gen_assert_clks_legal\n msg: ", "input_debounce: ASSERT_CLKS must be >= 1, got %0d", ASSERT_CLKS);
		end
		if (RELEASE_CLKS < 1) begin : gen_release_clks_legal
			initial $display("Error [elaboration] ../rtl/inputs/input_debounce.sv:69:9 - input_debounce.gen_release_clks_legal\n msg: ", "input_debounce: RELEASE_CLKS must be >= 1, got %0d", RELEASE_CLKS);
		end
	endgenerate
	localparam signed [31:0] CNT_MAX = (ASSERT_CLKS > RELEASE_CLKS ? ASSERT_CLKS : RELEASE_CLKS);
	localparam signed [31:0] CNT_W = $clog2(CNT_MAX + 1);
	reg [CNT_W - 1:0] disagree_counter;
	reg [CNT_W - 1:0] target_clks;
	function automatic signed [CNT_W - 1:0] sv2v_cast_7B3D1_signed;
		input reg signed [CNT_W - 1:0] inp;
		sv2v_cast_7B3D1_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		target_clks = (flag_in ? sv2v_cast_7B3D1_signed(ASSERT_CLKS) : sv2v_cast_7B3D1_signed(RELEASE_CLKS));
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			disagree_counter <= 0;
		else if (flag_in != flag_out) begin
			if (disagree_counter < (target_clks - 1'b1))
				disagree_counter <= disagree_counter + 1;
		end
		else
			disagree_counter <= 0;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			flag_out <= RESET_VALUE;
		else if ((flag_in != flag_out) && (disagree_counter >= (target_clks - 1'b1)))
			flag_out <= flag_in;
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
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
	reg _sv2v_0;
	localparam signed [31:0] pmic_types_pkg_LM5106_SHRINK_NS = 128;
	localparam signed [31:0] pmic_types_pkg_MIN_GATE_ON_NS = 112;
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
	function automatic signed [31:0] pmic_types_pkg_ns_to_clks;
		input reg signed [31:0] ns;
		pmic_types_pkg_ns_to_clks = (50 * ns) / 1000;
	endfunction
	localparam signed [31:0] pmic_types_pkg_MIN_ON_COUNTS = pmic_types_pkg_ns_to_clks(pmic_types_pkg_LM5106_SHRINK_NS + pmic_types_pkg_MIN_GATE_ON_NS);
	parameter signed [31:0] MIN_ON_COUNTS = pmic_types_pkg_MIN_ON_COUNTS;
	localparam signed [31:0] pmic_types_pkg_DIGITAL_DUTY_PCT = 75;
	localparam signed [31:0] pmic_types_pkg_CONVERTOR_HZ = 450000;
	localparam signed [31:0] pmic_types_pkg_CLKS_PER_SW = pmic_types_pkg_CLK_HZ / pmic_types_pkg_CONVERTOR_HZ;
	function automatic signed [31:0] pmic_types_pkg_duty_to_counts;
		input reg signed [31:0] duty_pct;
		pmic_types_pkg_duty_to_counts = (pmic_types_pkg_CLKS_PER_SW * duty_pct) / 100;
	endfunction
	localparam signed [31:0] pmic_types_pkg_MAX_ON_COUNTS_DEFAULT = pmic_types_pkg_duty_to_counts(pmic_types_pkg_DIGITAL_DUTY_PCT);
	localparam signed [31:0] pmic_types_pkg_ON_TIME_W = $clog2(pmic_types_pkg_MAX_ON_COUNTS_DEFAULT + 1);
	parameter signed [31:0] ON_TIME_W = pmic_types_pkg_ON_TIME_W;
	input wire clk;
	input wire rst_n;
	input wire pwm_sync;
	input wire ss_active;
	input wire run_active;
	localparam signed [31:0] pmic_types_pkg_CYCLES_PER_STEP_MAX = 64;
	localparam signed [31:0] pmic_types_pkg_CYC_STEP_W = 7;
	input wire [6:0] cycles_per_step;
	input wire [ON_TIME_W - 1:0] max_on_limit;
	output reg [ON_TIME_W - 1:0] max_on_counts;
	output reg SS_done;
	localparam [ON_TIME_W - 1:0] MIN_ON_CNT = MIN_ON_COUNTS[ON_TIME_W - 1:0];
	reg pwm_sync_d;
	reg pwm_fall;
	reg [6:0] cycle_counter;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			pwm_sync_d <= 1'b0;
		else
			pwm_sync_d <= pwm_sync;
	always @(*) begin
		if (_sv2v_0)
			;
		pwm_fall = pwm_sync_d & ~pwm_sync;
	end
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
`default_nettype none
module pwm_mask (
	clk,
	rst_n,
	pwm_sync,
	max_on_counts,
	pwm_out
);
	localparam signed [31:0] pmic_types_pkg_DIGITAL_DUTY_PCT = 75;
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
	localparam signed [31:0] pmic_types_pkg_CONVERTOR_HZ = 450000;
	localparam signed [31:0] pmic_types_pkg_CLKS_PER_SW = pmic_types_pkg_CLK_HZ / pmic_types_pkg_CONVERTOR_HZ;
	function automatic signed [31:0] pmic_types_pkg_duty_to_counts;
		input reg signed [31:0] duty_pct;
		pmic_types_pkg_duty_to_counts = (pmic_types_pkg_CLKS_PER_SW * duty_pct) / 100;
	endfunction
	localparam signed [31:0] pmic_types_pkg_MAX_ON_COUNTS_DEFAULT = pmic_types_pkg_duty_to_counts(pmic_types_pkg_DIGITAL_DUTY_PCT);
	localparam signed [31:0] pmic_types_pkg_ON_TIME_W = $clog2(pmic_types_pkg_MAX_ON_COUNTS_DEFAULT + 1);
	parameter signed [31:0] ON_TIME_W = pmic_types_pkg_ON_TIME_W;
	input wire clk;
	input wire rst_n;
	input wire pwm_sync;
	input wire [ON_TIME_W - 1:0] max_on_counts;
	output reg pwm_out;
	reg [ON_TIME_W - 1:0] run_counter;
	reg pulse_allowed;
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
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			pwm_out <= 0;
		else
			pwm_out <= pwm_sync & pulse_allowed;
endmodule
`default_nettype wire
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
	reg _sv2v_0;
	localparam signed [31:0] pmic_types_pkg_WINDOW_RUN = 16;
	parameter signed [31:0] WINDOW_RUN = pmic_types_pkg_WINDOW_RUN;
	localparam signed [31:0] pmic_types_pkg_WINDOW_SS = 32;
	parameter signed [31:0] WINDOW_SS = pmic_types_pkg_WINDOW_SS;
	parameter signed [31:0] BLANK_CLKS = 5;
	input wire clk;
	input wire rst_n;
	input wire pwm_sync;
	input wire cp_sync;
	input wire ss_active;
	input wire run_active;
	localparam signed [31:0] pmic_types_pkg_TRIP_W = 6;
	input wire [5:0] trip_run;
	input wire [5:0] trip_ss;
	output reg window_trip;
	output reg window_trip_SS;
	output reg [$clog2(WINDOW_RUN + 1) - 1:0] fault_count_run_out;
	output reg [$clog2(WINDOW_SS + 1) - 1:0] fault_count_ss_out;
	localparam signed [31:0] FCNT_RUN_W = $clog2(WINDOW_RUN + 1);
	localparam signed [31:0] FCNT_SS_W = $clog2(WINDOW_SS + 1);
	reg pwm_sync_d;
	reg pwm_rise;
	reg [WINDOW_SS - 1:0] fault_shifter_SS;
	reg [WINDOW_RUN - 1:0] fault_shifter_RUN;
	reg [FCNT_RUN_W - 1:0] fault_count_run;
	reg [FCNT_SS_W - 1:0] fault_count_ss;
	reg [BLANK_CLKS - 1:0] cp_delay;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			pwm_sync_d <= 0;
		else
			pwm_sync_d <= pwm_sync;
	always @(*) begin
		if (_sv2v_0)
			;
		pwm_rise = ~pwm_sync_d & pwm_sync;
	end
	function automatic [BLANK_CLKS - 1:0] sv2v_cast_A4FBD;
		input reg [BLANK_CLKS - 1:0] inp;
		sv2v_cast_A4FBD = inp;
	endfunction
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
	always @(*) begin
		if (_sv2v_0)
			;
		window_trip = sv2v_cast_67DF8(fault_count_run) >= trip_run;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		window_trip_SS = fault_count_ss >= trip_ss;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		fault_count_run_out = fault_count_run;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		fault_count_ss_out = fault_count_ss;
	end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
`default_nettype none
module hiccup_timer (
	clk,
	rst_n,
	hiccup_active,
	strike_level,
	base_clks,
	hiccup_done
);
	reg _sv2v_0;
	localparam signed [31:0] pmic_types_pkg_MAX_STRIKES_DEFAULT = 3;
	localparam signed [31:0] pmic_types_pkg_STRIKE_W = 2;
	parameter signed [31:0] STRIKE_W = pmic_types_pkg_STRIKE_W;
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
	function automatic signed [31:0] pmic_types_pkg_ms_to_clks;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_clks = 50000 * ms;
	endfunction
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_MAX_CLKS = pmic_types_pkg_ms_to_clks(20);
	localparam signed [31:0] pmic_types_pkg_HICCUP_TIMER_W = $clog2((pmic_types_pkg_HICCUP_BASE_MAX_CLKS << 2) + 1);
	parameter signed [31:0] TIMER_W = pmic_types_pkg_HICCUP_TIMER_W;
	input wire clk;
	input wire rst_n;
	input wire hiccup_active;
	input wire [STRIKE_W - 1:0] strike_level;
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_W = $clog2(pmic_types_pkg_HICCUP_BASE_MAX_CLKS + 1);
	input wire [pmic_types_pkg_HICCUP_BASE_W - 1:0] base_clks;
	output reg hiccup_done;
	reg [TIMER_W - 1:0] cool_down_target;
	reg [TIMER_W - 1:0] cool_counter;
	function automatic [TIMER_W - 1:0] sv2v_cast_5FB0D;
		input reg [TIMER_W - 1:0] inp;
		sv2v_cast_5FB0D = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		cool_down_target = sv2v_cast_5FB0D(base_clks) << strike_level;
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			cool_counter <= 0;
			hiccup_done <= 0;
		end
		else if (!hiccup_active) begin
			hiccup_done <= 1'b0;
			cool_counter <= 0;
		end
		else if (cool_counter == cool_down_target) begin
			hiccup_done <= 1'b1;
			cool_counter <= cool_counter;
		end
		else
			cool_counter <= cool_counter + 1;
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
`default_nettype none
module strike_counter (
	clk,
	rst_n,
	pwm_sync,
	hiccup_active,
	run_active,
	window_trip,
	max_strikes,
	clean_run_target,
	strike_level,
	latch_assert
);
	reg _sv2v_0;
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_MS = 1000;
	localparam signed [31:0] pmic_types_pkg_CONVERTOR_HZ = 450000;
	function automatic signed [31:0] pmic_types_pkg_ms_to_sw_cycles;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_sw_cycles = 450 * ms;
	endfunction
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_CYCLES = pmic_types_pkg_ms_to_sw_cycles(pmic_types_pkg_CLEAN_RUN_MS);
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_W = $clog2(pmic_types_pkg_CLEAN_RUN_CYCLES + 1);
	parameter signed [31:0] CLEAN_RUN_W = pmic_types_pkg_CLEAN_RUN_W;
	localparam signed [31:0] pmic_types_pkg_MAX_STRIKES_DEFAULT = 3;
	localparam signed [31:0] pmic_types_pkg_STRIKE_W = 2;
	parameter signed [31:0] STRIKE_W = pmic_types_pkg_STRIKE_W;
	input wire clk;
	input wire rst_n;
	input wire pwm_sync;
	input wire hiccup_active;
	input wire run_active;
	input wire window_trip;
	input wire [STRIKE_W - 1:0] max_strikes;
	input wire [CLEAN_RUN_W - 1:0] clean_run_target;
	output reg [STRIKE_W - 1:0] strike_level;
	output reg latch_assert;
	reg hiccup_active_d;
	reg hiccup_entry;
	reg pwm_sync_d;
	reg pwm_fall;
	reg [CLEAN_RUN_W - 1:0] clean_counter;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			hiccup_active_d <= 0;
			pwm_sync_d <= 0;
		end
		else begin
			hiccup_active_d <= hiccup_active;
			pwm_sync_d <= pwm_sync;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		hiccup_entry = hiccup_active & ~hiccup_active_d;
		pwm_fall = pwm_sync_d & ~pwm_sync;
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			latch_assert <= 1'b0;
			strike_level <= 1'sb0;
		end
		else if (hiccup_entry) begin
			strike_level <= strike_level + 1;
			if (strike_level == (max_strikes - 1'b1))
				latch_assert <= 1'b1;
		end
		else if (clean_counter == clean_run_target)
			strike_level <= 1'sb0;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			clean_counter <= 0;
		else if (!run_active || window_trip)
			clean_counter <= 0;
		else if (pwm_fall) begin
			if (clean_counter == clean_run_target)
				clean_counter <= clean_counter;
			else
				clean_counter <= clean_counter + 1;
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
`default_nettype none
module pgood_gen (
	clk,
	rst_n,
	pwm_sync,
	pgood_comp,
	run_active,
	PGOOD
);
	reg _sv2v_0;
	localparam signed [31:0] pmic_types_pkg_PGOOD_DELAY_MS = 9;
	localparam signed [31:0] pmic_types_pkg_CONVERTOR_HZ = 450000;
	function automatic signed [31:0] pmic_types_pkg_ms_to_sw_cycles;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_sw_cycles = 450 * ms;
	endfunction
	localparam signed [31:0] pmic_types_pkg_PGOOD_DELAY_CYCLES = pmic_types_pkg_ms_to_sw_cycles(pmic_types_pkg_PGOOD_DELAY_MS);
	parameter signed [31:0] PGOOD_DELAY_CYCLES = pmic_types_pkg_PGOOD_DELAY_CYCLES;
	parameter signed [31:0] PGOOD_DELAY_W = $clog2(PGOOD_DELAY_CYCLES + 1);
	input wire clk;
	input wire rst_n;
	input wire pwm_sync;
	input wire pgood_comp;
	input wire run_active;
	output reg PGOOD;
	reg pwm_sync_d;
	reg pwm_fall;
	reg [PGOOD_DELAY_W - 1:0] qualify_counter;
	function automatic signed [PGOOD_DELAY_W - 1:0] sv2v_cast_C6A89_signed;
		input reg signed [PGOOD_DELAY_W - 1:0] inp;
		sv2v_cast_C6A89_signed = inp;
	endfunction
	localparam [PGOOD_DELAY_W - 1:0] TARGET = sv2v_cast_C6A89_signed(PGOOD_DELAY_CYCLES);
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			pwm_sync_d <= 0;
		else
			pwm_sync_d <= pwm_sync;
	always @(*) begin
		if (_sv2v_0)
			;
		pwm_fall = pwm_sync_d & ~pwm_sync;
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			qualify_counter <= 0;
		else if (!run_active || !pgood_comp)
			qualify_counter <= 0;
		else if (pwm_fall) begin
			if (qualify_counter == TARGET)
				qualify_counter <= TARGET;
			else
				qualify_counter <= qualify_counter + 1;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		PGOOD = ((qualify_counter == TARGET) & pgood_comp) & run_active;
	end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
`default_nettype none
module timestamp (
	clk,
	rst_n,
	timestamp_ms
);
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
	localparam signed [31:0] pmic_types_pkg_PRESCALAR_HZ = 1000;
	localparam signed [31:0] pmic_types_pkg_PRESCALE_VAL = pmic_types_pkg_CLK_HZ / pmic_types_pkg_PRESCALAR_HZ;
	parameter signed [31:0] PRESCALE_VAL = pmic_types_pkg_PRESCALE_VAL;
	localparam signed [31:0] pmic_types_pkg_TIMESTAMP_W = 24;
	parameter signed [31:0] TIMESTAMP_W = pmic_types_pkg_TIMESTAMP_W;
	parameter signed [31:0] PRESCALAR_W = $clog2(PRESCALE_VAL + 1);
	input wire clk;
	input wire rst_n;
	output reg [TIMESTAMP_W - 1:0] timestamp_ms;
	reg [PRESCALAR_W - 1:0] prescalar;
	function automatic signed [PRESCALAR_W - 1:0] sv2v_cast_725DF_signed;
		input reg signed [PRESCALAR_W - 1:0] inp;
		sv2v_cast_725DF_signed = inp;
	endfunction
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			prescalar <= 1'sb0;
		else if (prescalar == sv2v_cast_725DF_signed(PRESCALE_VAL - 1))
			prescalar <= 1'sb0;
		else
			prescalar <= prescalar + 1'b1;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			timestamp_ms <= 1'sb0;
		else if (prescalar == sv2v_cast_725DF_signed(PRESCALE_VAL - 1))
			timestamp_ms <= timestamp_ms + 1'b1;
endmodule
`default_nettype wire
`default_nettype none
module fault_LED (
	clk,
	rst_n,
	otp_state,
	uvlo_state,
	latch_state,
	latch_assert,
	strike_level,
	ss_active,
	run_active,
	pgood,
	Green_LED,
	pgood_LED,
	Red_LED1,
	Red_LED2,
	Red_LED3
);
	reg _sv2v_0;
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
	function automatic signed [31:0] pmic_types_pkg_ms_to_clks;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_clks = 50000 * ms;
	endfunction
	parameter signed [31:0] LED_BLINK_HALF_CLKS = pmic_types_pkg_ms_to_clks(125);
	parameter signed [31:0] BLINK_W = $clog2(LED_BLINK_HALF_CLKS + 1);
	input wire clk;
	input wire rst_n;
	input wire otp_state;
	input wire uvlo_state;
	input wire latch_state;
	input wire latch_assert;
	localparam signed [31:0] pmic_types_pkg_MAX_STRIKES_DEFAULT = 3;
	localparam signed [31:0] pmic_types_pkg_STRIKE_W = 2;
	input wire [1:0] strike_level;
	input wire ss_active;
	input wire run_active;
	input wire pgood;
	output reg Green_LED;
	output reg pgood_LED;
	output reg Red_LED1;
	output reg Red_LED2;
	output reg Red_LED3;
	reg [BLINK_W - 1:0] blink_counter;
	reg blink;
	reg currently_faulted;
	function automatic signed [BLINK_W - 1:0] sv2v_cast_83398_signed;
		input reg signed [BLINK_W - 1:0] inp;
		sv2v_cast_83398_signed = inp;
	endfunction
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			blink_counter <= 1'sb0;
			blink <= 1'b0;
		end
		else if (blink_counter == sv2v_cast_83398_signed(LED_BLINK_HALF_CLKS - 1)) begin
			blink_counter <= 1'sb0;
			blink <= ~blink;
		end
		else
			blink_counter <= blink_counter + 1'b1;
	always @(*) begin
		if (_sv2v_0)
			;
		currently_faulted = ((otp_state || uvlo_state) || latch_state) || latch_assert;
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			Green_LED <= 1'b0;
		else
			Green_LED <= (ss_active || run_active) && !currently_faulted;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			pgood_LED <= 1'b0;
		else
			pgood_LED <= pgood;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			Red_LED1 <= 1'b0;
		else if (latch_state || latch_assert)
			Red_LED1 <= 1'b1;
		else if (strike_level != {2 {1'sb0}})
			Red_LED1 <= blink;
		else
			Red_LED1 <= 1'b0;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			Red_LED2 <= 1'b0;
		else
			Red_LED2 <= otp_state;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			Red_LED3 <= 1'b0;
		else
			Red_LED3 <= uvlo_state;
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
`default_nettype none
module pwm_stats (
	clk,
	rst_n,
	pwm_sync,
	duty_count,
	prev_period
);
	reg _sv2v_0;
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
	localparam signed [31:0] pmic_types_pkg_CONVERTOR_HZ = 450000;
	localparam signed [31:0] pmic_types_pkg_CLKS_PER_SW = pmic_types_pkg_CLK_HZ / pmic_types_pkg_CONVERTOR_HZ;
	localparam signed [31:0] pmic_types_pkg_CNT_W = $clog2(pmic_types_pkg_CLKS_PER_SW + 1) + 1;
	parameter signed [31:0] CNT_W = pmic_types_pkg_CNT_W;
	input wire clk;
	input wire rst_n;
	input wire pwm_sync;
	output reg [CNT_W - 1:0] duty_count;
	output reg [CNT_W - 1:0] prev_period;
	reg pwm_fall;
	reg pwm_rise;
	reg pwm_sync_d;
	reg [CNT_W - 1:0] period_counter;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			pwm_sync_d <= 0;
		else
			pwm_sync_d <= pwm_sync;
	always @(*) begin
		if (_sv2v_0)
			;
		pwm_fall = pwm_sync_d & ~pwm_sync;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		pwm_rise = ~pwm_sync_d & pwm_sync;
	end
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
`default_nettype none
module reg_file (
	clk,
	rst_n,
	addr,
	wr_en,
	wdata,
	rdata,
	rd_first,
	integrity_OK,
	abort,
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
	reg _sv2v_0;
	parameter [7:0] PMIC_ID = 8'hb5;
	parameter [7:0] VERSION_ID = 8'h01;
	parameter [7:0] DISABLE_KEY_ID = 8'hd1;
	parameter [7:0] WRITE_ACCESS_KEY_ID = 8'ha7;
	parameter signed [31:0] ARM_TIMEOUT_W = 16;
	input wire clk;
	input wire rst_n;
	input wire [6:0] addr;
	input wire wr_en;
	input wire [7:0] wdata;
	output reg [7:0] rdata;
	input wire rd_first;
	input wire integrity_OK;
	input wire abort;
	input wire [1:0] sup_state;
	input wire pgood;
	input wire latch_state;
	input wire en_switch;
	input wire en_switch_rise;
	input wire cp_state;
	input wire otp_state;
	input wire uvlo_state;
	localparam signed [31:0] pmic_types_pkg_MAX_STRIKES_DEFAULT = 3;
	localparam signed [31:0] pmic_types_pkg_STRIKE_W = 2;
	input wire [1:0] strike_level;
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
	localparam signed [31:0] pmic_types_pkg_CONVERTOR_HZ = 450000;
	localparam signed [31:0] pmic_types_pkg_CLKS_PER_SW = pmic_types_pkg_CLK_HZ / pmic_types_pkg_CONVERTOR_HZ;
	localparam signed [31:0] pmic_types_pkg_CNT_W = $clog2(pmic_types_pkg_CLKS_PER_SW + 1) + 1;
	input wire [pmic_types_pkg_CNT_W - 1:0] duty_count;
	input wire [pmic_types_pkg_CNT_W - 1:0] prev_period;
	input wire [4:0] fault_count_run;
	input wire [5:0] fault_count_ss;
	localparam signed [31:0] pmic_types_pkg_FAULT_CAUSE_W = 5;
	input wire [4:0] fault_reg;
	localparam signed [31:0] pmic_types_pkg_TIMESTAMP_W = 24;
	input wire [23:0] fault_time;
	input wire [23:0] timestamp_ms;
	output reg spi_enable;
	localparam signed [31:0] pmic_types_pkg_WINDOW_SS = 32;
	localparam signed [31:0] pmic_types_pkg_TRIP_W = 6;
	output reg [5:0] trip_run;
	output reg [5:0] trip_ss;
	output reg [1:0] max_strikes;
	localparam signed [31:0] pmic_types_pkg_DIGITAL_DUTY_PCT = 75;
	function automatic signed [31:0] pmic_types_pkg_duty_to_counts;
		input reg signed [31:0] duty_pct;
		pmic_types_pkg_duty_to_counts = (pmic_types_pkg_CLKS_PER_SW * duty_pct) / 100;
	endfunction
	localparam signed [31:0] pmic_types_pkg_MAX_ON_COUNTS_DEFAULT = pmic_types_pkg_duty_to_counts(pmic_types_pkg_DIGITAL_DUTY_PCT);
	localparam signed [31:0] pmic_types_pkg_ON_TIME_W = $clog2(pmic_types_pkg_MAX_ON_COUNTS_DEFAULT + 1);
	output reg [pmic_types_pkg_ON_TIME_W - 1:0] max_on_limit;
	function automatic signed [31:0] pmic_types_pkg_ms_to_clks;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_clks = 50000 * ms;
	endfunction
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_MAX_CLKS = pmic_types_pkg_ms_to_clks(20);
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_W = $clog2(pmic_types_pkg_HICCUP_BASE_MAX_CLKS + 1);
	output reg [pmic_types_pkg_HICCUP_BASE_W - 1:0] hiccup_base;
	localparam signed [31:0] pmic_types_pkg_CYCLES_PER_STEP_MAX = 64;
	localparam signed [31:0] pmic_types_pkg_CYC_STEP_W = 7;
	output reg [6:0] cycles_per_step;
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_MS = 1000;
	function automatic signed [31:0] pmic_types_pkg_ms_to_sw_cycles;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_sw_cycles = 450 * ms;
	endfunction
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_CYCLES = pmic_types_pkg_ms_to_sw_cycles(pmic_types_pkg_CLEAN_RUN_MS);
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_W = $clog2(pmic_types_pkg_CLEAN_RUN_CYCLES + 1);
	output reg [pmic_types_pkg_CLEAN_RUN_W - 1:0] clean_run_target;
	output reg fault_reg_read_done;
	reg write_rejected;
	localparam [6:0] ADDR_PMIC_ID = 7'h00;
	localparam [6:0] ADDR_VERSION = 7'h01;
	localparam [6:0] ADDR_CAPABILITY = 7'h02;
	localparam [6:0] ADDR_SCRATCH = 7'h03;
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
	localparam [6:0] ADDR_FAULT_CAUSE = 7'h1d;
	localparam [6:0] ADDR_FTIME_0 = 7'h1e;
	localparam [6:0] ADDR_FTIME_1 = 7'h1f;
	localparam [6:0] ADDR_FTIME_2 = 7'h20;
	localparam [6:0] ADDR_DISABLE_KEY = 7'h40;
	localparam [6:0] ADDR_CONTROL = 7'h41;
	localparam [6:0] ADDR_WRITE_KEY = 7'h4f;
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
	localparam [7:0] CAPABILITY_VAL = 8'b00111101;
	localparam signed [31:0] WD_TIMEOUT_MS = 5000;
	reg [7:0] scratch_r;
	reg disable_armed;
	reg unlock_armed;
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
	reg [10:0] temp_dirty;
	reg en_pending;
	reg en_pending_val;
	reg [6:0] addr_d;
	reg [15:0] bus_err_count;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			addr_d <= 1'sb0;
		else
			addr_d <= addr;
	always @(*) begin
		if (_sv2v_0)
			;
		fault_reg_read_done = ((addr_d == ADDR_FTIME_2) && (addr == (ADDR_FTIME_2 + 7'd1))) && !wr_en;
	end
	reg [23:0] timestamp_snap;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			timestamp_snap <= 1'sb0;
		else if (rd_first)
			timestamp_snap <= timestamp_ms;
	reg [23:0] wd_mark;
	reg wd_expired;
	reg wd_restored;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			wd_mark <= 1'sb0;
		else if (spi_enable)
			wd_mark <= timestamp_ms;
		else if (integrity_OK)
			wd_mark <= timestamp_ms;
	function automatic signed [23:0] sv2v_cast_24_signed;
		input reg signed [23:0] inp;
		sv2v_cast_24_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		wd_expired = !spi_enable && ((timestamp_ms - wd_mark) >= sv2v_cast_24_signed(WD_TIMEOUT_MS));
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			bus_err_count <= 1'sb0;
		else if (abort && !(&bus_err_count))
			bus_err_count <= bus_err_count + 1'b1;
	localparam signed [31:0] pmic_types_pkg_WINDOW_RUN = 16;
	function automatic signed [5:0] sv2v_cast_67DF8_signed;
		input reg signed [5:0] inp;
		sv2v_cast_67DF8_signed = inp;
	endfunction
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	function automatic [5:0] clamp_trip_run;
		input reg [7:0] input_trip_run;
		if (input_trip_run < 8'd1)
			clamp_trip_run = sv2v_cast_67DF8_signed(1);
		else if (input_trip_run > sv2v_cast_8_signed(pmic_types_pkg_WINDOW_RUN))
			clamp_trip_run = sv2v_cast_67DF8_signed(pmic_types_pkg_WINDOW_RUN);
		else
			clamp_trip_run = input_trip_run[5:0];
	endfunction
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
	function automatic [1:0] clamp_max_strikes;
		input reg [7:0] input_max_strikes;
		if (input_max_strikes < 8'd1)
			clamp_max_strikes = sv2v_cast_6B4D7_signed(1);
		else if (input_max_strikes > sv2v_cast_8_signed(pmic_types_pkg_MAX_STRIKES_DEFAULT))
			clamp_max_strikes = sv2v_cast_6B4D7_signed(pmic_types_pkg_MAX_STRIKES_DEFAULT);
		else
			clamp_max_strikes = input_max_strikes[1:0];
	endfunction
	localparam signed [31:0] pmic_types_pkg_LM5106_SHRINK_NS = 128;
	localparam signed [31:0] pmic_types_pkg_MIN_GATE_ON_NS = 112;
	function automatic signed [31:0] pmic_types_pkg_ns_to_clks;
		input reg signed [31:0] ns;
		pmic_types_pkg_ns_to_clks = (50 * ns) / 1000;
	endfunction
	localparam signed [31:0] pmic_types_pkg_MIN_ON_COUNTS = pmic_types_pkg_ns_to_clks(pmic_types_pkg_LM5106_SHRINK_NS + pmic_types_pkg_MIN_GATE_ON_NS);
	function automatic signed [pmic_types_pkg_ON_TIME_W - 1:0] sv2v_cast_D6A01_signed;
		input reg signed [pmic_types_pkg_ON_TIME_W - 1:0] inp;
		sv2v_cast_D6A01_signed = inp;
	endfunction
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
	function automatic [6:0] clamp_cyc_step;
		input reg [7:0] input_cyc_step;
		if (input_cyc_step < 8'd1)
			clamp_cyc_step = sv2v_cast_A371F_signed(1);
		else if (input_cyc_step > sv2v_cast_8_signed(pmic_types_pkg_CYCLES_PER_STEP_MAX))
			clamp_cyc_step = sv2v_cast_A371F_signed(pmic_types_pkg_CYCLES_PER_STEP_MAX);
		else
			clamp_cyc_step = input_cyc_step[6:0];
	endfunction
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_MIN_CLKS = pmic_types_pkg_ms_to_clks(1);
	function automatic signed [pmic_types_pkg_HICCUP_BASE_W - 1:0] sv2v_cast_B4DD0_signed;
		input reg signed [pmic_types_pkg_HICCUP_BASE_W - 1:0] inp;
		sv2v_cast_B4DD0_signed = inp;
	endfunction
	function automatic [pmic_types_pkg_HICCUP_BASE_W - 1:0] clamp_hiccup;
		input [23:0] input_hiccup;
		if (input_hiccup < sv2v_cast_24_signed(pmic_types_pkg_HICCUP_BASE_MIN_CLKS))
			clamp_hiccup = sv2v_cast_B4DD0_signed(pmic_types_pkg_HICCUP_BASE_MIN_CLKS);
		else if (input_hiccup > sv2v_cast_24_signed(pmic_types_pkg_HICCUP_BASE_MAX_CLKS))
			clamp_hiccup = sv2v_cast_B4DD0_signed(pmic_types_pkg_HICCUP_BASE_MAX_CLKS);
		else
			clamp_hiccup = input_hiccup[pmic_types_pkg_HICCUP_BASE_W - 1:0];
	endfunction
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_MIN_CYCLES = pmic_types_pkg_ms_to_sw_cycles(100);
	function automatic signed [pmic_types_pkg_CLEAN_RUN_W - 1:0] sv2v_cast_DC11B_signed;
		input reg signed [pmic_types_pkg_CLEAN_RUN_W - 1:0] inp;
		sv2v_cast_DC11B_signed = inp;
	endfunction
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
		else if (abort || integrity_OK)
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
	reg [23:0] temp_hiccup_full;
	reg [23:0] temp_clean_full;
	always @(*) begin
		if (_sv2v_0)
			;
		temp_hiccup_full = {temp_hiccup_2, temp_hiccup_1, temp_hiccup_0};
	end
	always @(*) begin
		if (_sv2v_0)
			;
		temp_clean_full = {temp_clean_2, temp_clean_1, temp_clean_0};
	end
	reg hiccup_all;
	reg hiccup_any;
	reg clean_all;
	reg clean_any;
	always @(*) begin
		if (_sv2v_0)
			;
		hiccup_all = &temp_dirty[6:4];
	end
	always @(*) begin
		if (_sv2v_0)
			;
		hiccup_any = |temp_dirty[6:4];
	end
	always @(*) begin
		if (_sv2v_0)
			;
		clean_all = &temp_dirty[10:8];
	end
	always @(*) begin
		if (_sv2v_0)
			;
		clean_any = |temp_dirty[10:8];
	end
	reg off_ok;
	always @(*) begin
		if (_sv2v_0)
			;
		off_ok = sup_state == 2'b00;
	end
	localparam signed [31:0] pmic_types_pkg_CYCLES_PER_STEP_DEFAULT = 16;
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_MS = 5;
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_DEFAULT_CLKS = pmic_types_pkg_ms_to_clks(pmic_types_pkg_HICCUP_BASE_MS);
	localparam signed [31:0] pmic_types_pkg_TRIP_RUN_DEFAULT = 12;
	localparam signed [31:0] pmic_types_pkg_TRIP_SS_DEFAULT = 28;
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
		else if (integrity_OK) begin
			if (|temp_dirty) begin
				write_rejected <= 1'b0;
				if (!unlock_armed)
					write_rejected <= 1'b1;
				else begin
					if (temp_dirty[0])
						trip_run <= clamp_trip_run(temp_trip_run);
					if (temp_dirty[1])
						trip_ss <= clamp_trip_ss(temp_trip_ss);
					if (temp_dirty[2])
						max_strikes <= clamp_max_strikes(temp_max_strk);
					if (temp_dirty[3])
						max_on_limit <= clamp_max_on(temp_max_on);
					if (temp_dirty[7]) begin
						if (off_ok)
							cycles_per_step <= clamp_cyc_step(temp_cyc_step);
						else
							write_rejected <= 1'b1;
					end
					if (hiccup_any) begin
						if (hiccup_all && off_ok)
							hiccup_base <= clamp_hiccup(temp_hiccup_full);
						else
							write_rejected <= 1'b1;
					end
					if (clean_any) begin
						if (clean_all && off_ok)
							clean_run_target <= clamp_clean_run(temp_clean_full);
						else
							write_rejected <= 1'b1;
					end
				end
			end
		end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			arm_timer <= 1'sb0;
			spi_enable <= 1'b1;
			scratch_r <= 8'h00;
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
					ADDR_SCRATCH: scratch_r <= wdata;
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
			end
			if (abort || integrity_OK) begin
				disable_armed <= 1'b0;
				unlock_armed <= 1'b0;
				en_pending <= 1'b0;
				en_pending_val <= 1'b0;
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
`default_nettype none
module spi_slave (
	clk,
	rst_n,
	sck,
	cs_n,
	sdio_in,
	sdio_out,
	sdio_oe,
	addr,
	wr_en,
	wdata,
	rdata,
	rd_first,
	integrity_ok,
	abort
);
	reg _sv2v_0;
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
	function automatic signed [31:0] pmic_types_pkg_ms_to_clks;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_clks = 50000 * ms;
	endfunction
	parameter signed [31:0] SCK_IDLE_TIMEOUT_CLKS = pmic_types_pkg_ms_to_clks(2);
	input wire clk;
	input wire rst_n;
	input wire sck;
	input wire cs_n;
	input wire sdio_in;
	output reg sdio_out;
	output reg sdio_oe;
	output reg [6:0] addr;
	output reg wr_en;
	output reg [7:0] wdata;
	input wire [7:0] rdata;
	output reg rd_first;
	output reg integrity_ok;
	output reg abort;
	reg sck_d;
	reg cs_n_d;
	reg sck_rise;
	reg sck_fall;
	reg cs_fall;
	reg cs_rise;
	reg [2:0] bit_count;
	reg [3:0] byte_count;
	reg byte_done;
	reg [7:0] rx_byte;
	reg [2:0] spi_state;
	reg [2:0] spi_state_next;
	reg rw;
	reg sck_timeout;
	reg [6:0] rx_shift;
	reg [7:0] crc;
	reg [7:0] held_data;
	reg held_valid;
	reg [7:0] tx_shift;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			sck_d <= 0;
			cs_n_d <= 1;
		end
		else begin
			sck_d <= sck;
			cs_n_d <= cs_n;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		sck_fall = sck_d & ~sck;
		sck_rise = ~sck_d & sck;
		cs_fall = cs_n_d & ~cs_n;
		cs_rise = ~cs_n_d & cs_n;
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			spi_state <= 3'b000;
		else
			spi_state <= spi_state_next;
	always @(*) begin
		if (_sv2v_0)
			;
		spi_state_next = spi_state;
		if (cs_fall)
			spi_state_next = 3'b001;
		else if (cs_rise)
			spi_state_next = 3'b000;
		else if (sck_timeout && (spi_state != 3'b000))
			spi_state_next = 3'b101;
		else
			(* full_case, parallel_case *)
			case (spi_state)
				3'b000: spi_state_next = 3'b000;
				3'b001:
					if (byte_done)
						spi_state_next = (rx_byte[7] ? 3'b011 : 3'b010);
				3'b010: spi_state_next = 3'b010;
				3'b011:
					if (byte_done)
						spi_state_next = 3'b100;
				3'b100: spi_state_next = 3'b100;
				3'b101: spi_state_next = 3'b101;
				default: spi_state_next = 3'b101;
			endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		byte_done = sck_rise & (bit_count == 3'd7);
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			bit_count <= 0;
			byte_count <= 0;
		end
		else if (cs_fall) begin
			bit_count <= 0;
			byte_count <= 0;
		end
		else if (sck_rise) begin
			bit_count <= bit_count + 1;
			if (byte_done && !(&byte_count))
				byte_count <= byte_count + 1;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		rx_byte = {rx_shift, sdio_in};
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			rx_shift <= 7'h00;
			rw <= 1'b0;
			addr <= 7'h00;
			held_data <= 8'h00;
			held_valid <= 1'b0;
			wr_en <= 1'b0;
			wdata <= 8'h00;
		end
		else begin
			wr_en <= 1'b0;
			if (sck_rise)
				rx_shift <= {rx_shift[5:0], sdio_in};
			if (cs_fall)
				held_valid <= 1'b0;
			else if (byte_done) begin
				if (spi_state == 3'b001) begin
					rw <= rx_byte[7];
					addr <= rx_byte[6:0];
				end
				else if (spi_state == 3'b010) begin
					if (held_valid) begin
						wdata <= held_data;
						wr_en <= 1'b1;
						addr <= addr + 7'd1;
					end
					held_data <= rx_byte;
					held_valid <= 1'b1;
				end
				else if (spi_state == 3'b100)
					addr <= addr + 7'd1;
			end
		end
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			crc <= 8'h00;
		else if (cs_fall)
			crc <= 8'h00;
		else if (sck_rise) begin
			if (crc[7] ^ sdio_in)
				crc <= (crc << 1) ^ 8'h07;
			else
				crc <= crc << 1;
		end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			tx_shift <= 8'h00;
			sdio_out <= 1'b0;
			sdio_oe <= 1'b0;
		end
		else begin
			if (spi_state != 3'b100)
				sdio_oe <= 1'b0;
			if (sck_fall) begin
				if ((spi_state == 3'b011) && (bit_count == 3'd7)) begin
					tx_shift <= rdata;
					sdio_out <= rdata[7];
					sdio_oe <= 1'b1;
				end
				else if (spi_state == 3'b100) begin
					if (bit_count == 3'd0) begin
						tx_shift <= rdata;
						sdio_out <= rdata[7];
					end
					else begin
						tx_shift <= {tx_shift[6:0], 1'b0};
						sdio_out <= tx_shift[6];
					end
				end
			end
		end
	always @(*) begin
		if (_sv2v_0)
			;
		rd_first = (sck_fall && (spi_state == 3'b011)) && (bit_count == 3'd7);
	end
	reg [$clog2(SCK_IDLE_TIMEOUT_CLKS + 1) - 1:0] idle_counter;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			idle_counter <= 0;
			sck_timeout <= 0;
		end
		else begin
			sck_timeout <= 0;
			if (cs_n)
				idle_counter <= 0;
			else if (sck_rise || sck_fall)
				idle_counter <= 0;
			else if (idle_counter == SCK_IDLE_TIMEOUT_CLKS[$clog2(SCK_IDLE_TIMEOUT_CLKS + 1) - 1:0]) begin
				sck_timeout <= 1'b1;
				idle_counter <= 1'sb0;
			end
			else
				idle_counter <= idle_counter + 1;
		end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			integrity_ok <= 0;
			abort <= 0;
		end
		else begin
			integrity_ok <= 1'b0;
			abort <= 1'b0;
			if (cs_rise && !rw) begin
				if ((((spi_state != 3'b101) && (bit_count == 3'd0)) && (byte_count >= 4'd3)) && (crc == 8'h00))
					integrity_ok <= 1'b1;
				else
					abort <= 1'b1;
			end
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
`default_nettype none
module fault_cause (
	clk,
	rst_n,
	otp_state,
	uvlo_state,
	latch_state,
	latch_assert,
	window_trip,
	window_trip_SS,
	ss_active,
	run_active,
	fault_reg_read_done,
	timestamp_ms,
	fault_time,
	fault_reg
);
	reg _sv2v_0;
	input wire clk;
	input wire rst_n;
	input wire otp_state;
	input wire uvlo_state;
	input wire latch_state;
	input wire latch_assert;
	input wire window_trip;
	input wire window_trip_SS;
	input wire ss_active;
	input wire run_active;
	input wire fault_reg_read_done;
	localparam signed [31:0] pmic_types_pkg_TIMESTAMP_W = 24;
	input wire [23:0] timestamp_ms;
	output reg [23:0] fault_time;
	localparam signed [31:0] pmic_types_pkg_FAULT_CAUSE_W = 5;
	output reg [4:0] fault_reg;
	localparam signed [31:0] BIT_OVP = 4;
	localparam signed [31:0] BIT_LATCH = 3;
	localparam signed [31:0] BIT_OTP = 2;
	localparam signed [31:0] BIT_UVLO = 1;
	localparam signed [31:0] BIT_OC = 0;
	reg convertor_running;
	reg ovp;
	reg episode_start;
	always @(*) begin
		if (_sv2v_0)
			;
		convertor_running = ss_active || run_active;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (latch_state & ~latch_assert)
			ovp = 1'b1;
		else
			ovp = 1'b0;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		episode_start = (convertor_running && (fault_reg == {5 {1'sb0}})) && (((((otp_state || uvlo_state) || ovp) || latch_assert) || window_trip) || window_trip_SS);
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			fault_time <= 1'sb0;
		else if (fault_reg_read_done)
			fault_time <= 1'sb0;
		else if (episode_start)
			fault_time <= timestamp_ms;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			fault_reg <= 1'sb0;
		else if (fault_reg_read_done)
			fault_reg <= 1'sb0;
		else if (convertor_running) begin
			if (otp_state)
				fault_reg[BIT_OTP] <= 1'b1;
			if (uvlo_state)
				fault_reg[BIT_UVLO] <= 1'b1;
			if (window_trip || window_trip_SS)
				fault_reg[BIT_OC] <= 1'b1;
			if (ovp)
				fault_reg[BIT_OVP] <= 1'b1;
			if (latch_assert)
				fault_reg[BIT_LATCH] <= 1'b1;
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
`default_nettype none
module supervisor (
	clk,
	SS_done,
	rst_n,
	latch_state,
	OTP,
	window_trip_SS,
	window_trip,
	latch_assert,
	UVLO,
	hiccup_done,
	en_SW,
	spi_enable,
	en,
	ss_active,
	run_active,
	hiccup_active,
	state_out
);
	reg _sv2v_0;
	input wire clk;
	input wire SS_done;
	input wire rst_n;
	input wire latch_state;
	input wire OTP;
	input wire window_trip_SS;
	input wire window_trip;
	input wire latch_assert;
	input wire UVLO;
	input wire hiccup_done;
	input wire en_SW;
	input wire spi_enable;
	output reg en;
	output reg ss_active;
	output reg run_active;
	output reg hiccup_active;
	output reg [1:0] state_out;
	reg en_from_state;
	reg [1:0] state;
	reg [1:0] next_state;
	wire g_en;
	assign g_en = spi_enable & en_SW;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			state <= 2'b00;
		else
			state <= next_state;
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		(* full_case, parallel_case *)
		case (state)
			2'b00:
				if ((((g_en & ~latch_state) & ~OTP) & ~UVLO) & ~latch_assert)
					next_state = 2'b01;
				else
					next_state = 2'b00;
			2'b01:
				if ((((~g_en | OTP) | latch_state) | UVLO) | latch_assert)
					next_state = 2'b00;
				else if (window_trip_SS)
					next_state = 2'b11;
				else if (SS_done)
					next_state = 2'b10;
				else
					next_state = 2'b01;
			2'b10:
				if ((((~g_en | latch_state) | OTP) | UVLO) | latch_assert)
					next_state = 2'b00;
				else if (window_trip)
					next_state = 2'b11;
				else
					next_state = 2'b10;
			2'b11:
				if ((((~g_en | latch_state) | OTP) | latch_assert) | UVLO)
					next_state = 2'b00;
				else if (hiccup_done)
					next_state = 2'b01;
				else
					next_state = 2'b11;
			default: next_state = 2'b00;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (state)
			2'b00: en_from_state = 1'b0;
			2'b01: en_from_state = 1'b1;
			2'b10: en_from_state = 1'b1;
			2'b11: en_from_state = 1'b0;
			default: en_from_state = 1'b0;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		ss_active = state == 2'b01;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		run_active = state == 2'b10;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		hiccup_active = state == 2'b11;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		en = ((((g_en & en_from_state) & ~OTP) & ~latch_state) & ~UVLO) & ~latch_assert;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		state_out = state;
	end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
`default_nettype none
module pmic_top (
	clk,
	rst_n_pin,
	SCK,
	CS_n,
	SDIO,
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
	reg _sv2v_0;
	input wire clk;
	input wire rst_n_pin;
	input wire SCK;
	input wire CS_n;
	inout wire SDIO;
	input wire Osc_in;
	input wire CP_trig;
	input wire OTP_trig;
	input wire UVLO_trig;
	input wire latch_stat;
	input wire PGOOD_comp;
	input wire en_from_switch;
	output wire PWM_out;
	output wire En;
	output wire PGOOD;
	output wire latch_out;
	output wire switch_supply;
	output wire Green_LED;
	output wire pgood_LED;
	output wire Red_LED1;
	output wire Red_LED2;
	output wire Red_LED3;
	wire rst_n;
	reset_sync rst_sync(
		.clk(clk),
		.rst_n_enter(rst_n_pin),
		.rst_n_exit(rst_n)
	);
	wire en_from_switch_sync;
	wire Osc_sync;
	wire CP_sync;
	wire OTP_sync;
	wire UVLO_sync;
	wire latch_stat_sync;
	wire PGOOD_comp_sync;
	wire sck_sync;
	wire cs_n_sync;
	wire sdio_sync;
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
	input_sync u_sdio_sync(
		.clk(clk),
		.rst_n(rst_n),
		.async_in(SDIO),
		.sync_out(sdio_sync)
	);
	wire en_from_switch_sync_db;
	wire OTP_sync_db;
	wire UVLO_sync_db;
	wire latch_stat_sync_db;
	wire sck_filt;
	wire cs_n_filt;
	wire sdio_filt;
	localparam signed [31:0] pmic_types_pkg_CLK_HZ = 50000000;
	function automatic signed [31:0] pmic_types_pkg_ms_to_clks;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_clks = 50000 * ms;
	endfunction
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
	localparam signed [31:0] pmic_types_pkg_SPI_FILTER_CLKS = 8;
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
	) u_sdio_filt(
		.clk(clk),
		.rst_n(rst_n),
		.flag_in(sdio_sync),
		.flag_out(sdio_filt)
	);
	wire ss_active;
	wire run_active;
	wire hiccup_active;
	wire hiccup_done;
	wire SS_done;
	wire window_trip;
	wire window_trip_SS;
	localparam signed [31:0] pmic_types_pkg_MAX_STRIKES_DEFAULT = 3;
	localparam signed [31:0] pmic_types_pkg_STRIKE_W = 2;
	wire [1:0] strike_level;
	localparam signed [31:0] pmic_types_pkg_DIGITAL_DUTY_PCT = 75;
	localparam signed [31:0] pmic_types_pkg_CONVERTOR_HZ = 450000;
	localparam signed [31:0] pmic_types_pkg_CLKS_PER_SW = pmic_types_pkg_CLK_HZ / pmic_types_pkg_CONVERTOR_HZ;
	function automatic signed [31:0] pmic_types_pkg_duty_to_counts;
		input reg signed [31:0] duty_pct;
		pmic_types_pkg_duty_to_counts = (pmic_types_pkg_CLKS_PER_SW * duty_pct) / 100;
	endfunction
	localparam signed [31:0] pmic_types_pkg_MAX_ON_COUNTS_DEFAULT = pmic_types_pkg_duty_to_counts(pmic_types_pkg_DIGITAL_DUTY_PCT);
	localparam signed [31:0] pmic_types_pkg_ON_TIME_W = $clog2(pmic_types_pkg_MAX_ON_COUNTS_DEFAULT + 1);
	wire [pmic_types_pkg_ON_TIME_W - 1:0] max_on_counts;
	localparam signed [31:0] pmic_types_pkg_CNT_W = $clog2(pmic_types_pkg_CLKS_PER_SW + 1) + 1;
	wire [pmic_types_pkg_CNT_W - 1:0] duty_count;
	wire [pmic_types_pkg_CNT_W - 1:0] prev_period;
	localparam signed [31:0] pmic_types_pkg_TIMESTAMP_W = 24;
	wire [23:0] timestamp_ms;
	wire [23:0] fault_time;
	wire [1:0] sup_state;
	localparam signed [31:0] pmic_types_pkg_WINDOW_RUN = 16;
	wire [4:0] fault_count_run;
	localparam signed [31:0] pmic_types_pkg_WINDOW_SS = 32;
	wire [5:0] fault_count_ss;
	reg en_switch_rise;
	localparam signed [31:0] pmic_types_pkg_FAULT_CAUSE_W = 5;
	wire [4:0] fault_reg;
	wire fault_reg_read_done;
	wire [6:0] spi_addr;
	wire spi_wr_en;
	wire [7:0] spi_wdata;
	wire [7:0] spi_rdata;
	wire spi_rd_first;
	wire spi_integrity_ok;
	wire spi_abort;
	wire sdio_out;
	wire sdio_oe;
	wire spi_enable;
	localparam signed [31:0] pmic_types_pkg_TRIP_W = 6;
	wire [5:0] trip_run;
	wire [5:0] trip_ss;
	wire [1:0] max_strikes;
	wire [pmic_types_pkg_ON_TIME_W - 1:0] max_on_limit;
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_MAX_CLKS = pmic_types_pkg_ms_to_clks(20);
	localparam signed [31:0] pmic_types_pkg_HICCUP_BASE_W = $clog2(pmic_types_pkg_HICCUP_BASE_MAX_CLKS + 1);
	wire [pmic_types_pkg_HICCUP_BASE_W - 1:0] hiccup_base;
	localparam signed [31:0] pmic_types_pkg_CYCLES_PER_STEP_MAX = 64;
	localparam signed [31:0] pmic_types_pkg_CYC_STEP_W = 7;
	wire [6:0] cycles_per_step;
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_MS = 1000;
	function automatic signed [31:0] pmic_types_pkg_ms_to_sw_cycles;
		input reg signed [31:0] ms;
		pmic_types_pkg_ms_to_sw_cycles = 450 * ms;
	endfunction
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_CYCLES = pmic_types_pkg_ms_to_sw_cycles(pmic_types_pkg_CLEAN_RUN_MS);
	localparam signed [31:0] pmic_types_pkg_CLEAN_RUN_W = $clog2(pmic_types_pkg_CLEAN_RUN_CYCLES + 1);
	wire [pmic_types_pkg_CLEAN_RUN_W - 1:0] clean_run_target;
	reg en_from_switch_sync_db_d;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			en_from_switch_sync_db_d <= 0;
		else
			en_from_switch_sync_db_d <= en_from_switch_sync_db;
	always @(*) begin
		if (_sv2v_0)
			;
		en_switch_rise = ~en_from_switch_sync_db_d & en_from_switch_sync_db;
	end
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
	assign SDIO = (sdio_oe ? sdio_out : 1'bz);
	spi_slave u_spi_slave(
		.clk(clk),
		.rst_n(rst_n),
		.sck(sck_filt),
		.cs_n(cs_n_filt),
		.sdio_in(sdio_filt),
		.sdio_out(sdio_out),
		.sdio_oe(sdio_oe),
		.addr(spi_addr),
		.wr_en(spi_wr_en),
		.wdata(spi_wdata),
		.rdata(spi_rdata),
		.rd_first(spi_rd_first),
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
	pgood_gen u_pgood_gen(
		.clk(clk),
		.rst_n(rst_n),
		.pwm_sync(Osc_sync),
		.pgood_comp(PGOOD_comp_sync),
		.run_active(run_active),
		.PGOOD(PGOOD)
	);
	timestamp u_timestamp(
		.clk(clk),
		.rst_n(rst_n),
		.timestamp_ms(timestamp_ms)
	);
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
	assign switch_supply = PGOOD;
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
