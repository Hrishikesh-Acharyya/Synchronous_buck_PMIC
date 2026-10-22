/*

# Filename:         bind_sva.sv

# File Description: Bind SVA checkers to RTL modules. This file is compiled into the simulation
#                   but not synthesized into the ASIC. It is not part of the RTL source

# Global variables: None

*/

bind input_sync input_sync_sva #(.RESET_VALUE(RESET_VALUE)) u_sva (.*);

