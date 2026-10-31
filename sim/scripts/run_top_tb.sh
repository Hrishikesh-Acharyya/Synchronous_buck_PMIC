#!/usr/bin/env bash
#
# Filename:         run_top_tb.sh
#
# File Description: Builds and runs the integration testbench tb/pmic_top_tb.v
#                   with Verilator or Icarus Verilog, and writes the same
#                   one-line result record run_tb.sh writes, so report.sh can
#                   list it beside the module testbenches.
#
#                   Usage: run_top_tb.sh <sim> <build_dir> <flow> <sources...>
#                     sim   verilator | iverilog
#                     flow  a label only (sv, equiv, iv) for the result record
#
#                   The verdict comes from the testbench's own last line,
#                   "pmic_top_tb: PASS" or "pmic_top_tb: FAIL". That matters for
#                   Icarus: vvp exits 0 from $stop, and Verilog-2005 has no way
#                   to set an exit code, so this script is what makes a failing
#                   run exit non-zero there. A run with no verdict line - a
#                   build error, a crash - is a FAIL.
#
#                   The covers column of the record carries the testbench's
#                   coverage bins (hit/total). The testbench already fails on
#                   any unhit bin, so INCONCLUSIVE never applies to it.
#
# Global variables: Read from the environment, set per recipe by the Makefile:
#                   VERILATOR, IVERILOG, VVP - tool paths
#                   TOP_VFLAGS  - Verilator flags (word-split on purpose)
#                   TOP_IVFLAGS - Icarus flags (word-split on purpose)
#                   QUIET  - 1: logs to file only, one status line printed
#                   NOFAIL - 1: always exit 0; the suite report decides
#                   WAVES  - 1: pass +WAVES so the testbench dumps a VCD

set -uo pipefail

SIM=$1
DIR=$2
FLOW=$3
shift 3
SRCS=("$@")

VERILATOR=${VERILATOR:-verilator}
IVERILOG=${IVERILOG:-iverilog}
VVP=${VVP:-vvp}
TOP_VFLAGS=${TOP_VFLAGS:-}
TOP_IVFLAGS=${TOP_IVFLAGS:-}
QUIET=${QUIET:-0}
NOFAIL=${NOFAIL:-0}
WAVES=${WAVES:-0}
TOP=pmic_top_tb

if [[ -t 1 ]]; then
    C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_OFF=$'\e[0m'
else
    C_RED=''; C_GRN=''; C_OFF=''
fi

# run_logged: as in run_tb.sh - log file always, terminal unless QUIET, and
#             the command's own exit code rather than tee's
run_logged() {
    local log=$1; shift
    if [[ $QUIET == 1 ]]; then
        "$@" >"$log" 2>&1
    else
        "$@" 2>&1 | tee "$log"
        return "${PIPESTATUS[0]}"
    fi
}

rm -rf "$DIR"
mkdir -p "$DIR"
start=$(date +%s)
plusargs=()
[[ $WAVES == 1 ]] && plusargs+=("+WAVES")

build_ok=1
case $SIM in
    verilator)
        # shellcheck disable=SC2086  # TOP_VFLAGS is a flag list
        run_logged "$DIR/build.log" "$VERILATOR" $TOP_VFLAGS --Mdir "$DIR" \
            --top-module "$TOP" "${SRCS[@]}" || build_ok=0
        RUN=("./V$TOP")
        ;;
    iverilog)
        # shellcheck disable=SC2086  # TOP_IVFLAGS is a flag list
        run_logged "$DIR/build.log" "$IVERILOG" $TOP_IVFLAGS -s "$TOP" \
            -o "$DIR/$TOP.vvp" "${SRCS[@]}" || build_ok=0
        # -n: $stop ends the run instead of opening the interactive prompt
        RUN=("$VVP" -n "./$TOP.vvp")
        ;;
    *)
        echo "run_top_tb.sh: unknown simulator '$SIM'"; exit 2 ;;
esac

# cd so pmic_top_tb.log and the VCD land in the build directory, not in sim/
if [[ $build_ok == 1 ]]; then
    run_logged "$DIR/run.log" bash -c 'cd "$1" && shift && "$@"' _ \
        "$DIR" "${RUN[@]}" "${plusargs[@]}"
fi

verdict=FAIL
bins_hit=0
bins_total=0
if [[ -f $DIR/run.log ]] && grep -q "^pmic_top_tb: PASS" "$DIR/run.log"; then
    verdict=PASS
fi
if [[ -f $DIR/run.log ]]; then
    read -r bins_hit bins_total < <(sed -nE 's/^ +([0-9]+) of ([0-9]+) bins hit.*/\1 \2/p' \
                                    "$DIR/run.log" | tail -1) || true
    bins_hit=${bins_hit:-0}; bins_total=${bins_total:-0}
fi
secs=$(( $(date +%s) - start ))

# Same record layout as run_tb.sh: flow, top, verdict, assertion failures (the
# integration testbench binds no SVA), covers hit, covers total, seconds.
printf '%s\t%s\t%s\t%d\t%d\t%d\t%d\n' "$FLOW" "$TOP" "$verdict" 0 \
    "$bins_hit" "$bins_total" "$secs" >"$DIR/result.tsv"

if [[ $verdict == PASS ]]; then colour=$C_GRN; else colour=$C_RED; fi
printf '%s[%-12s]%s %-6s %-22s bins %d/%d  %s  %ds\n' "$colour" "$verdict" "$C_OFF" \
    "$FLOW" "$TOP" "$bins_hit" "$bins_total" "$SIM" "$secs"
if [[ $QUIET == 1 && $verdict == FAIL ]]; then
    log=$DIR/run.log; [[ -f $log ]] || log=$DIR/build.log
    echo "  --- FAIL lines / last lines of $log ---"
    { grep -E " FAIL |MISS|SCOREBOARD|MONITOR" "$log" || tail -n 25 "$log"; } | head -n 25 | sed 's/^/  /'
fi

[[ $NOFAIL == 1 ]] && exit 0
[[ $verdict == PASS ]] && exit 0
exit 1
