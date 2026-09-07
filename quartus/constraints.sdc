# 50 MHz system clock, matching the 20 ns period used in simulation.
create_clock -name clk -period 20.000 [get_ports clk]

# Fault inputs arrive from analog comparators with no relationship to clk.
# Excluded here and handled by synchronisers in RTL; without this the
# analyser reports meaningless setup/hold failures on unclocked paths.
set_false_path -from [get_ports {OTP UVLO latch_state latch_assert g_en}] -to *

derive_clock_uncertainty