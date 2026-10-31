#!/usr/bin/env bash
#
# Filename:         run_pnr.sh
#
# File Description: One place-and-route run of pmic_top: flow.tcl, then the
#                   post-route reports (report.tcl) and a layout picture
#                   (image.tcl) if the routing succeeded. Results go to
#                   work/runs/tel<T>_<W>x<H>_m<M>/; metrics.txt there holds every
#                   number. summarize.py tabulates all runs.
#
#                   Usage: run_pnr.sh <TELEMETRY_EN 0|1> <die_w_um> <die_h_um> [margin_um] [density_add]
#                   e.g.   run_pnr.sh 0 180 115        reduced build, standard slot
#
# Global variables: OPENROAD - openroad binary (default: openroad).

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
OPENROAD=${OPENROAD:-openroad}
T=$1; W=$2; H=$3; M=${4:-2.0}; D=${5:-0.10}
NETLIST=$HERE/work/netlist_tel$T.v
test -f "$NETLIST" || { echo "no $NETLIST - run synth.sh first"; exit 2; }
OUT=$HERE/work/runs/tel${T}_${W}x${H}_m${M}
rm -rf "$OUT"; mkdir -p "$OUT"
cd "$HERE"
s=$(date +%s)
NETLIST=$NETLIST DIE_W=$W DIE_H=$H MARGIN=$M OUT=$OUT DENSITY_ADD=$D \
    "$OPENROAD" -no_init -exit -threads 4 -log "$OUT/flow.log" flow.tcl > "$OUT/stdout.log" 2>&1
rc=$?
echo "elapsed_s = $(( $(date +%s) - s ))" >> "$OUT/metrics.txt"
if [ $rc -eq 0 ]; then
    RUN=$OUT "$OPENROAD" -no_init -exit report.tcl > "$OUT/report.log" 2>&1
    RUN=$OUT QT_QPA_PLATFORM=offscreen timeout 300 "$OPENROAD" -no_init -gui image.tcl \
        > "$OUT/image.log" 2>&1 || true
fi
echo "[tel$T ${W}x${H} m$M] rc=$rc $(grep -E '^(result|drc_violations|util_final|worst_setup_slack_ns|worst_hold_slack_ns) =' "$OUT/metrics.txt" | tr '\n' ' ')"
exit $rc
