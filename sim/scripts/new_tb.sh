#!/usr/bin/env bash
#
# Filename:         new_tb.sh
#
# File Description: `make new_tb M=<group>/<module>`: copies tb/template_tb.sv
#                   to tb/<group>/<module>_tb.sv with every <MODULE> marker
#                   replaced by the module name, then prints the line that
#                   registers it in the Makefile's TESTBENCHES list. Refuses to
#                   overwrite an existing testbench, and warns if no RTL file
#                   of that name exists yet.
#
#                   Usage: new_tb.sh <group>/<module>   (run from sim/)
#
# Global variables: COLOR - 1 for ANSI colour

set -euo pipefail

if [[ ${COLOR:-0} == 1 ]]; then
    C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YEL=$'\e[33m'; C_OFF=$'\e[0m'
else
    C_RED=''; C_GRN=''; C_YEL=''; C_OFF=''
fi

entry=${1%/}
if [[ ! $entry =~ ^[A-Za-z0-9_]+/[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "${C_RED}xx expected <group>/<module>, e.g. status/pgood_gen - got '$entry'${C_OFF}" >&2
    exit 1
fi
module=${entry#*/}
template=../tb/template_tb.sv
dest=../tb/${entry}_tb.sv

[[ -f $template ]] || { echo "${C_RED}xx no template at $template${C_OFF}" >&2; exit 1; }
[[ -e $dest ]] && { echo "${C_RED}xx $dest already exists - not overwritten${C_OFF}" >&2; exit 1; }

mkdir -p "$(dirname "$dest")"
sed -e "s/<MODULE>/$module/g" -e "s/tb_template\.sv/${module}_tb.sv/" "$template" >"$dest"
echo "${C_GRN}-- created $dest${C_OFF}"

[[ -f ../rtl-systemverilog/${entry}.sv ]] \
    || echo "${C_YEL}!! no ../rtl-systemverilog/${entry}.sv yet - the testbench will not build until it exists${C_OFF}"

echo "   next: fill in the <ANGLE_BRACKET> markers, then add this line to TESTBENCHES in sim/Makefile:"
echo "           $entry"
echo "   and run:  make tb_$module"
