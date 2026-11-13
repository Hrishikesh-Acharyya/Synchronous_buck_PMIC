/*

# Filename:         bind_top_only.sv

# File Description: The lean checker set for the pmic_top soak: pmic_top_sva
#                   alone, bound as sva/bind_sva.sv binds it. Every block's
#                   own checker is left out - each block was closed by its
#                   own testbench, and the full set still runs in every
#                   directed and outer-flow build - so a soak simulates about
#                   ten times as many board events per hour. Selected with
#                   CHECKERS=top (the soak's default); see the Makefile.
#
#                   Testbench only; never synthesised.

# Global variables: None

*/

bind pmic_top pmic_top_sva #(
    .TELEMETRY_EN(TELEMETRY_EN)
) u_sva (.*);

`default_nettype wire
