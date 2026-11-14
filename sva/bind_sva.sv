/*

# Filename:         bind_sva.sv

# File Description: Bind SVA checkers to RTL modules. This file is compiled into the simulation
#                   but not synthesized into the ASIC. It is not part of the RTL source

# Global variables: None

*/

bind reset_sync reset_sync_sva u_sva (.*);

bind input_sync input_sync_sva #(
  .RESET_VALUE(RESET_VALUE)
  ) u_sva (.*);

bind input_debounce input_debounce_sva #(
    .ASSERT_CLKS (ASSERT_CLKS),
    .RELEASE_CLKS(RELEASE_CLKS),
    .RESET_VALUE (RESET_VALUE)
) u_sva (.dut_disagree_counter(disagree_counter),.*);


bind pwm_mask pwm_mask_sva #(
    .ON_TIME_W(ON_TIME_W)
) u_sva (
    .dut_run_counter(run_counter),
    .*
);

bind pgood_gen pgood_gen_sva #(
    .QUAL_CYCLES  (PGOOD_DELAY_CYCLES),
    .PGOOD_DELAY_W(PGOOD_DELAY_W)
) u_sva (
    .dut_qualify_counter(qualify_counter),
    .dut_pwm_fall       (pwm_fall),
    .*
);

bind timestamp timestamp_sva #(
    .PRESCALE_VAL(PRESCALE_VAL),
    .TIMESTAMP_W (TIMESTAMP_W),
    .PRESCALAR_W (PRESCALAR_W)
) u_sva (
    .dut_prescalar(prescalar),
    .*
);

bind fault_LED fault_LED_sva #(
    .LED_BLINK_HALF_CLKS(LED_BLINK_HALF_CLKS),
    .BLINK_W            (BLINK_W)
) u_sva (
    .dut_blink_counter(blink_counter),
    .dut_blink        (blink),
    .*
);

bind pwm_stats pwm_stats_sva #(
    .CNT_W(CNT_W)
) u_sva (
    .dut_period_counter(period_counter),
    .*
);

bind soft_start soft_start_sva #(
    .MIN_ON_COUNTS(MIN_ON_COUNTS),
    .ON_TIME_W(ON_TIME_W)
) u_sva (.*);

bind hiccup_timer hiccup_timer_sva #(
    .STRIKE_W(STRIKE_W),
    .TIMER_W(TIMER_W)
) u_sva (.*);

bind strike_counter strike_counter_sva #(
    .CLEAN_RUN_W(CLEAN_RUN_W),
    .STRIKE_W(STRIKE_W)
) u_sva (.*);

bind fault_cause fault_cause_sva u_sva (.*);

bind supervisor supervisor_sva u_sva (.*);

bind pmic_top pmic_top_sva #(
    .TELEMETRY_EN(TELEMETRY_EN)
) u_sva (.*);

bind fault_arbiter fault_arbiter_sva #(
    .WINDOW_RUN (WINDOW_RUN),
    .WINDOW_SS  (WINDOW_SS)
) u_sva (
    .*
);

bind spi_slave spi_slave_sva #(
    .SCK_IDLE_TIMEOUT_CLKS(SCK_IDLE_TIMEOUT_CLKS)
) u_sva (
    .dut_spi_state(spi_state),
    .*
);

// reg_file: commit discipline, threshold gates and safe ranges, keys, enable
// path, watchdog, read port, bus-error counter. Internals are the ones named in
// reg_file's "Internal state" section.
bind reg_file reg_file_sva #(
    .PMIC_ID            (PMIC_ID),
    .VERSION_ID         (VERSION_ID),
    .DISABLE_KEY_ID     (DISABLE_KEY_ID),
    .WRITE_ACCESS_KEY_ID(WRITE_ACCESS_KEY_ID),
    .ARM_TIMEOUT_W      (ARM_TIMEOUT_W)
) u_sva (
    .dut_scratch_r      (scratch_r),
    .dut_temp_dirty     (temp_dirty),
    .dut_temp_cyc_step  (temp_cyc_step),
    .dut_temp_hiccup_full(temp_hiccup_full),
    .dut_temp_clean_full(temp_clean_full),
    .dut_en_pending     (en_pending),
    .dut_en_pending_val (en_pending_val),
    .dut_scratch_pending(scratch_pending),
    .dut_disable_armed  (disable_armed),
    .dut_unlock_armed   (unlock_armed),
    .dut_arm_timer      (arm_timer),
    .dut_wd_mark        (wd_mark),
    .dut_wd_restored    (wd_restored),
    .dut_write_rejected (write_rejected),
    .dut_bus_err_count  (bus_err_count),
    .dut_timestamp_snap (timestamp_snap),
    .*
);










