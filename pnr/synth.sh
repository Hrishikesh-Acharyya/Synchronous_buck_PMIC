#!/usr/bin/env bash
#
# Filename:         synth.sh
#
# File Description: Gate-level netlists for place and route, both TELEMETRY_EN
#                   builds, from the converted Verilog (Build/pmic_full.v). The
#                   same yosys mapping as sim/Makefile's syn_area, plus what a
#                   physical netlist needs: tie cells for constants, split
#                   buses, a buffer on every port-to-port assign, and none of
#                   the cells OpenROAD-flow-scripts marks don't-use for sky130hd
#                   (probe and lpflow cells).
#
#                   Usage: synth.sh        writes work/netlist_tel0.v, work/netlist_tel1.v
#
# Global variables: YOSYS - yosys binary (default: yosys).

set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
YOSYS=${YOSYS:-yosys}
cd "$HERE"
mkdir -p work
cp ../Build/pmic_full.v work/pmic_full.v
LIB=platform/sky130_fd_sc_hd__tt_025C_1v80.lib
test -f "$LIB" || { echo "run fetch_platform.sh first"; exit 1; }
DONT_USE="sky130_fd_sc_hd__probe_p_8 sky130_fd_sc_hd__probec_p_8 sky130_fd_sc_hd__lpflow_bleeder_1
 sky130_fd_sc_hd__lpflow_clkbufkapwr_1 sky130_fd_sc_hd__lpflow_clkbufkapwr_16 sky130_fd_sc_hd__lpflow_clkbufkapwr_2
 sky130_fd_sc_hd__lpflow_clkbufkapwr_4 sky130_fd_sc_hd__lpflow_clkbufkapwr_8 sky130_fd_sc_hd__lpflow_clkinvkapwr_1
 sky130_fd_sc_hd__lpflow_clkinvkapwr_16 sky130_fd_sc_hd__lpflow_clkinvkapwr_2 sky130_fd_sc_hd__lpflow_clkinvkapwr_4
 sky130_fd_sc_hd__lpflow_clkinvkapwr_8 sky130_fd_sc_hd__lpflow_decapkapwr_12 sky130_fd_sc_hd__lpflow_decapkapwr_3
 sky130_fd_sc_hd__lpflow_decapkapwr_4 sky130_fd_sc_hd__lpflow_decapkapwr_6 sky130_fd_sc_hd__lpflow_decapkapwr_8
 sky130_fd_sc_hd__lpflow_inputiso0n_1 sky130_fd_sc_hd__lpflow_inputiso0p_1 sky130_fd_sc_hd__lpflow_inputiso1n_1
 sky130_fd_sc_hd__lpflow_inputiso1p_1 sky130_fd_sc_hd__lpflow_inputisolatch_1 sky130_fd_sc_hd__lpflow_isobufsrc_1
 sky130_fd_sc_hd__lpflow_isobufsrc_16 sky130_fd_sc_hd__lpflow_isobufsrc_2 sky130_fd_sc_hd__lpflow_isobufsrc_4
 sky130_fd_sc_hd__lpflow_isobufsrc_8 sky130_fd_sc_hd__lpflow_isobufsrckapwr_16
 sky130_fd_sc_hd__lpflow_lsbuf_lh_hl_isowell_tap_1 sky130_fd_sc_hd__lpflow_lsbuf_lh_hl_isowell_tap_2
 sky130_fd_sc_hd__lpflow_lsbuf_lh_hl_isowell_tap_4 sky130_fd_sc_hd__lpflow_lsbuf_lh_isowell_4
 sky130_fd_sc_hd__lpflow_lsbuf_lh_isowell_tap_1 sky130_fd_sc_hd__lpflow_lsbuf_lh_isowell_tap_2
 sky130_fd_sc_hd__lpflow_lsbuf_lh_isowell_tap_4"
DU=""
for c in $DONT_USE; do DU="$DU -dont_use $c"; done
for T in 0 1; do
    cat > work/syn_tel$T.ys <<YS
read_verilog work/pmic_full.v
chparam -set TELEMETRY_EN $T pmic_top
hierarchy -top pmic_top
synth -top pmic_top -flatten
dfflibmap -liberty $LIB $DU
abc -liberty $LIB $DU
opt_clean
hilomap -singleton -hicell sky130_fd_sc_hd__conb_1 HI -locell sky130_fd_sc_hd__conb_1 LO
setundef -zero
splitnets
opt_clean -purge
insbuf -buf sky130_fd_sc_hd__buf_4 A X
delete t:\$scopeinfo
opt_clean -purge
check
tee -o work/syn_tel${T}_stat.txt stat -liberty $LIB
write_verilog -noattr -noexpr -nohex -nodec work/netlist_tel$T.v
YS
    "$YOSYS" -q -l work/syn_tel$T.log work/syn_tel$T.ys > /dev/null 2>&1
    echo "TELEMETRY_EN=$T: $(grep -E 'Chip area' work/syn_tel${T}_stat.txt)"
done
