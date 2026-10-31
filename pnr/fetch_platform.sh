#!/usr/bin/env bash
#
# Filename:         fetch_platform.sh
#
# File Description: Fills pnr/platform/ with the sky130_fd_sc_hd files the flow
#                   needs. The technology and cell LEFs, track, power-grid,
#                   global-routing and RC set-up scripts and the OpenRCX rules
#                   come from OpenROAD-flow-scripts (platforms/sky130hd, the
#                   rules from sky130hs, which sky130hd links to). The liberty is
#                   the volare sky130A copy that sim/Makefile's syn_area uses,
#                   so the netlists here match the area log. platform/ is not
#                   committed.
#
#                   Usage: fetch_platform.sh
#
# Global variables: LIBERTY - path of sky130_fd_sc_hd__tt_025C_1v80.lib
#                   (default: the volare path in sim/Makefile).

set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
LIBERTY=${LIBERTY:-$HOME/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib}
BASE=https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/master/flow/platforms
mkdir -p "$HERE/platform"
cd "$HERE/platform"
for f in sky130hd/lef/sky130_fd_sc_hd.tlef sky130hd/lef/sky130_fd_sc_hd_merged.lef \
         sky130hd/make_tracks.tcl sky130hd/pdn.tcl sky130hd/setRC.tcl \
         sky130hd/fastroute.tcl sky130hs/rcx_patterns.rules; do
    curl -fsSL -o "$(basename "$f")" "$BASE/$f"
done
test -f "$LIBERTY" || { echo "no liberty at $LIBERTY - set LIBERTY=<path>"; exit 1; }
cp "$LIBERTY" .
sha256sum ./*
