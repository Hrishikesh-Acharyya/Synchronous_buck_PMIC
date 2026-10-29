/*

# Filename:         bind_sva.sv

# File Description: Bind SVA checkers to RTL modules. This file is compiled into the simulation
#                   but not synthesized into the ASIC. It is not part of the RTL source

# Global variables: None

*/

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




