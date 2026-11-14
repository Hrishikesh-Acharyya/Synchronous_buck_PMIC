#!/usr/bin/env bash
#
# Filename:         doctor.sh
#
# File Description: `make doctor`: reports every tool the sim/ flow can use -
#                   found or missing, and its version - plus the liberty file
#                   and the output paths in use, and which make targets each
#                   missing tool disables. Nothing is installed or changed.
#
#                   Exit status is 0 when everything the core flow needs
#                   (Verilator, sv2v, yosys, Python) is present, 1 otherwise.
#
# Global variables: Read from the environment, set by the Makefile:
#                   VERILATOR, VERILATOR_COVERAGE, SV2V, YOSYS, IVERILOG, VVP,
#                   VIEWER, PYTHON, SHELLCHECK - tool paths
#                   LIBERTY, TBBUILD, SYNDIR, WAVEDIR - paths
#                   COLOR - 1 for ANSI colour

set -uo pipefail

if [[ ${COLOR:-0} == 1 ]]; then
    C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YEL=$'\e[33m'; C_BLD=$'\e[1m'; C_OFF=$'\e[0m'
else
    C_RED=''; C_GRN=''; C_YEL=''; C_BLD=''; C_OFF=''
fi

missing_core=0

# tool: $1 label, $2 command, $3 version flag, $4 core (1) or optional (0),
#       $5 what it is needed for
tool() {
    local label=$1 cmd=$2 flag=$3 core=$4 needed=$5 ver
    if command -v "$cmd" >/dev/null 2>&1; then
        ver=$("$cmd" "$flag" 2>&1 | head -n 1)
        printf '  %s%-9s%s %-18s %s\n' "$C_GRN" "found" "$C_OFF" "$label" "$ver"
    elif [[ $core == 1 ]]; then
        printf '  %s%-9s%s %-18s needed for: %s\n' "$C_RED" "MISSING" "$C_OFF" "$label" "$needed"
        missing_core=1
    else
        printf '  %s%-9s%s %-18s optional, used by: %s\n' "$C_YEL" "missing" "$C_OFF" "$label" "$needed"
    fi
}

echo "${C_BLD}Tools${C_OFF}"
tool verilator          "${VERILATOR:-verilator}"                   --version 1 "lint, every tb_/equiv_ target"
tool verilator_coverage "${VERILATOR_COVERAGE:-verilator_coverage}" --version 0 "cover listings of the module testbenches"
tool sv2v               "${SV2V:-sv2v}"                             --version 1 "convert, split, verilog, verilog_check"
tool yosys              "${YOSYS:-yosys}"                           -V        1 "syn, syn_notel, syn_area, syn_compare"
tool python3            "${PYTHON:-python3}"                        --version 1 "verilog, verilog_check, syn_area, bundle"
tool iverilog           "${IVERILOG:-iverilog}"                     -V        0 "iv_top, iv_top_notel, top_all"
tool vvp                "${VVP:-vvp}"                               -V        0 "iv_top, iv_top_notel, top_all"
tool gtkwave            "${VIEWER:-gtkwave}"                        --version 0 "wave_ and view_ targets"
tool shellcheck         "${SHELLCHECK:-shellcheck}"                 --version 0 "check_scripts (bash -n runs without it)"
tool git                git                                         --version 0 "syn_compare"

echo
echo "${C_BLD}Files and paths${C_OFF}"
if [[ -f ${LIBERTY:-} ]]; then
    printf '  %s%-9s%s %-18s %s\n' "$C_GRN" "found" "$C_OFF" "liberty" "$LIBERTY"
else
    printf '  %s%-9s%s %-18s %s\n' "$C_YEL" "missing" "$C_OFF" "liberty" \
        "syn_area / syn_area_notel / syn_both need it: set LIBERTY=path"
fi
printf '  %-9s %-18s %s\n' "" "testbench builds" "${TBBUILD:-?}"
printf '  %-9s %-18s %s\n' "" "synthesis output" "${SYNDIR:-?}"
printf '  %-9s %-18s %s\n' "" "GTKWave layouts"  "${WAVEDIR:-?}"
printf '  %-9s %-18s %s\n' "" "colour"           "COLOR=${COLOR:-0} (COLOR=0 or NO_COLOR=1 turns it off)"

echo
if [[ $missing_core == 0 ]]; then
    echo "${C_GRN}-- core flow ready${C_OFF}"
else
    echo "${C_RED}xx a core tool is missing - see above${C_OFF}"
fi
exit "$missing_core"
