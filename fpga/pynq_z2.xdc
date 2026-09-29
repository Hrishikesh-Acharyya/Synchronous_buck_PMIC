## PYNQ-Z2 constraints for pynq_test_top.
## Pin locations taken from the TUL master file pynq-z2_v1.0.xdc.

## ---- Clock: 125 MHz from the Ethernet PHY ----
set_property -dict { PACKAGE_PIN H16  IOSTANDARD LVCMOS33 } [get_ports { sysclk }]
create_clock -name sys_clk_pin -period 8.000 -waveform {0 4} [get_ports { sysclk }]
## The 50 MHz MMCM output is derived automatically from sys_clk_pin.

## ---- Switches ----
set_property -dict { PACKAGE_PIN M20  IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]
set_property -dict { PACKAGE_PIN M19  IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]

## ---- Buttons ----
set_property -dict { PACKAGE_PIN D19  IOSTANDARD LVCMOS33 } [get_ports { btns[0] }]
set_property -dict { PACKAGE_PIN D20  IOSTANDARD LVCMOS33 } [get_ports { btns[1] }]
set_property -dict { PACKAGE_PIN L20  IOSTANDARD LVCMOS33 } [get_ports { btns[2] }]
set_property -dict { PACKAGE_PIN L19  IOSTANDARD LVCMOS33 } [get_ports { btns[3] }]

## ---- LEDs ----
set_property -dict { PACKAGE_PIN R14  IOSTANDARD LVCMOS33 } [get_ports { leds[0] }]
set_property -dict { PACKAGE_PIN P14  IOSTANDARD LVCMOS33 } [get_ports { leds[1] }]
set_property -dict { PACKAGE_PIN N16  IOSTANDARD LVCMOS33 } [get_ports { leds[2] }]
set_property -dict { PACKAGE_PIN M14  IOSTANDARD LVCMOS33 } [get_ports { leds[3] }]
set_property -dict { PACKAGE_PIN L15  IOSTANDARD LVCMOS33 } [get_ports { led4_b }]
set_property -dict { PACKAGE_PIN L14  IOSTANDARD LVCMOS33 } [get_ports { led5_g }]

## ---- PMOD JA: scope / logic analyser probe points ----
set_property -dict { PACKAGE_PIN Y18  IOSTANDARD LVCMOS33 } [get_ports { ja[0] }]
set_property -dict { PACKAGE_PIN Y19  IOSTANDARD LVCMOS33 } [get_ports { ja[1] }]
set_property -dict { PACKAGE_PIN Y16  IOSTANDARD LVCMOS33 } [get_ports { ja[2] }]
set_property -dict { PACKAGE_PIN Y17  IOSTANDARD LVCMOS33 } [get_ports { ja[3] }]
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports { ja[4] }]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports { ja[5] }]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports { ja[6] }]
set_property -dict { PACKAGE_PIN W19  IOSTANDARD LVCMOS33 } [get_ports { ja[7] }]

## ---- Asynchronous I/O ----
## Switches and buttons have no relation to any clock; they are synchronised
## in RTL (input_sync / reset_sync). LEDs and PMOD outputs are watched by eyes
## and scopes, not by a clocked receiver. Neither side has a timing
## requirement, so exclude them rather than report meaningless violations.
set_false_path -from [get_ports { sw[*] btns[*] }]
set_false_path -to   [get_ports { leds[*] led4_b led5_g ja[*] }]

## ---- Synchroniser flops ----
## Keeps each two-flop chain placed together and tells the tools these are
## metastability-absorbing stages, without an attribute in the shared RTL.
set_property ASYNC_REG TRUE [get_cells -hier -filter { NAME =~ *meta_ff_reg || NAME =~ *sync_out_reg || NAME =~ *rst_n_exit_reg }]
