#!/usr/bin/env bash
#
# Filename:         run_package.sh
#
# File Description: Ship check of one Silicluster package folder, run on the
#                   package's own files exactly as its SILICLUSTER_README.md
#                   tells a reviewer to: the integration testbench under Icarus
#                   Verilog and under Verilator (default parameters, so each
#                   package tests the build it describes), the two runs'
#                   check lines compared, and the package's rtl/ synthesised
#                   with yosys and put through `check -assert`. Called twice by
#                   `make signoff`, once per package.
#
#                   Usage: run_package.sh <package_dir> <work_dir>
#
#                   Exit status 0 only if both simulators report
#                   "pmic_top_tb: PASS" with identical check lines, the
#                   Verilator build is warning-free with the README's flags,
#                   and synthesis passes its design check.
#
# Global variables: VERILATOR, IVERILOG, VVP, YOSYS - tool paths (environment).

set -uo pipefail

PKG=$(cd "$1" && pwd)
WORK=$2
VERILATOR=${VERILATOR:-verilator}
IVERILOG=${IVERILOG:-iverilog}
VVP=${VVP:-vvp}
YOSYS=${YOSYS:-yosys}
NAME=$(basename "$PKG")

rm -rf "$WORK"
mkdir -p "$WORK"
cp -r "$PKG/rtl" "$PKG/tb" "$WORK/"
cd "$WORK" || exit 1
fail=0
say() { echo "[$NAME] $*"; }

# ---- Icarus Verilog, the README's commands ----
if "$IVERILOG" -g2005 -o pmic_top_tb.vvp rtl/*.v rtl/*/*.v tb/pmic_top_tb.v > icarus_build.log 2>&1; then
    "$VVP" -n pmic_top_tb.vvp > icarus.log 2>&1
else
    say "Icarus build FAILED"; cat icarus_build.log; fail=1
fi
v_iv=$(grep -E "pmic_top_tb: (PASS|FAIL)" icarus.log 2>/dev/null | tail -1)
say "Icarus:    ${v_iv:-no verdict}  $(grep -E 'checks run|coverage  ' icarus.log 2>/dev/null | tr -s ' ' | tr '\n' ' ')"
[ "$v_iv" = "pmic_top_tb: PASS" ] || fail=1

# ---- Verilator, the README's commands ----
if "$VERILATOR" --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-ZERODLY \
       --top-module pmic_top_tb rtl/*.v rtl/*/*.v tb/pmic_top_tb.v > verilator_build.log 2>&1; then
    ./obj_dir/Vpmic_top_tb > verilator.log 2>&1
else
    say "Verilator build FAILED"; tail -20 verilator_build.log; fail=1
fi
v_vl=$(grep -E "pmic_top_tb: (PASS|FAIL)" verilator.log 2>/dev/null | tail -1)
nwarn=$(grep -c "%Warning" verilator_build.log)
say "Verilator: ${v_vl:-no verdict}  $(grep -E 'checks run|coverage  ' verilator.log 2>/dev/null | tr -s ' ' | tr '\n' ' ')build warnings: $nwarn"
[ "$v_vl" = "pmic_top_tb: PASS" ] || fail=1
[ "$nwarn" = 0 ] || fail=1

# ---- the two simulators agree on every check ----
if diff <(grep -E "\] (PASS|FAIL)  " icarus.log) <(grep -E "\] (PASS|FAIL)  " verilator.log) > /dev/null; then
    say "Icarus and Verilator check lines identical ($(grep -c -E '\] (PASS|FAIL)  ' icarus.log) lines)"
else
    say "Icarus and Verilator check lines DIFFER"; fail=1
fi

# ---- synthesis from the package's own files ----
files=$(ls rtl/*.v rtl/*/*.v | tr '\n' ' ')
if "$YOSYS" -q -l yosys.log -p "read_verilog $files; hierarchy -top pmic_top; \
        synth -top pmic_top -flatten; check -assert; tee -o synth_stat.txt stat" > /dev/null 2>&1; then
    cells=$(grep -E "^ +[0-9]+ +cells$|Number of cells" synth_stat.txt | head -1 | tr -s ' ')
    latches=$(grep -c -i "dlatch" synth_stat.txt)
    say "yosys:     synthesised, design check clean, ${cells# }, latches: $latches"
    [ "$latches" = 0 ] || fail=1
else
    say "yosys synthesis or design check FAILED"; tail -20 yosys.log; fail=1
fi

[ $fail = 0 ] && say "package OK" || say "package NOT OK"
exit $fail
