#!/usr/bin/env bash
#
# Filename:         run_tb.sh
#
# File Description: Builds and runs one Verilator testbench, applies the cover
#                   gate, and writes a one-line result record. Called by the
#                   generated tb_<module> and equiv_<module> targets in
#                   sim/Makefile - one invocation per testbench, so parallel
#                   make never shares a build directory or a log.
#
#                   Usage: run_tb.sh <top> <build_dir> <flow> <sources...>
#                     flow is a label only ("sv" or "equiv") and ends up in
#                     the result record so the report can tell them apart.
#
#                   Three verdicts, per the logbook:
#                     FAIL          build failed, the simulation exited
#                                   non-zero, or any SVA FAIL line printed
#                     INCONCLUSIVE  everything clean, but a cover read zero or
#                                   there were no covers at all - the
#                                   assertions behind them proved nothing
#                     PASS          clean, and every cover hit
#
# Global variables: Read from the environment, set per recipe by the Makefile:
#                   VERILATOR, VERILATOR_COVERAGE - tool paths
#                   VFLAGS  - full Verilator flag string (word-split on purpose)
#                   QUIET   - 1: logs to file only, one status line printed
#                   WAVES   - 1: pass +WAVES to the model so it dumps a VCD
#                   NOFAIL  - 1: always exit 0 so a suite run continues and
#                                the report owns the exit status
#                   STRICT  - 1: INCONCLUSIVE exits non-zero as well

set -uo pipefail

TOP=$1
DIR=$2
FLOW=$3
shift 3
SRCS=("$@")

VERILATOR=${VERILATOR:-verilator}
VERILATOR_COVERAGE=${VERILATOR_COVERAGE:-verilator_coverage}
VFLAGS=${VFLAGS:-}
QUIET=${QUIET:-0}
WAVES=${WAVES:-0}
NOFAIL=${NOFAIL:-0}
STRICT=${STRICT:-0}

# Colour only when talking to a terminal, so CI logs stay clean.
if [[ -t 1 ]]; then
    C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YEL=$'\e[33m'; C_OFF=$'\e[0m'
else
    C_RED=''; C_GRN=''; C_YEL=''; C_OFF=''
fi

# run_logged: runs a command with its output in a log file, and on the
#             terminal too unless QUIET. Returns the command's own exit code,
#             not tee's - that is what pipefail and PIPESTATUS are for.
run_logged() {
    local log=$1; shift
    if [[ $QUIET == 1 ]]; then
        "$@" >"$log" 2>&1
    else
        "$@" 2>&1 | tee "$log"
        return "${PIPESTATUS[0]}"
    fi
}

# Wiped every time: Verilator's timestamp-based incremental build is
# unreliable across the 9p mount and has handed back stale binaries.
rm -rf "$DIR"
mkdir -p "$DIR"
start=$(date +%s)

verdict=""
sva_fails=0
covers_total=0
covers_zero=0

# shellcheck disable=SC2086  # VFLAGS is a flag list and must word-split
if ! run_logged "$DIR/build.log" \
        "$VERILATOR" $VFLAGS --Mdir "$DIR" --top-module "$TOP" "${SRCS[@]}"; then
    verdict="FAIL"
    fail_log="$DIR/build.log"
else
    plusargs=()
    [[ $WAVES == 1 ]] && plusargs+=("+WAVES")

    # cd so coverage.dat and the VCD land beside the model, not in sim/.
    run_logged "$DIR/run.log" bash -c 'cd "$1" && shift && "$@"' _ \
        "$DIR" "./V$TOP" "${plusargs[@]}"
    sim_rc=$?
    fail_log="$DIR/run.log"

    sva_fails=$(grep -c "SVA FAIL:" "$DIR/run.log")

    # Cover gate. --annotate-all because by default only files with MISSING
    # coverage are written, so a fully covered run produces an empty
    # directory; --annotate-min 1 so only genuine zeros are marked, rather
    # than the default 10 that flags a cover with three hits as dead.
    if [[ -f $DIR/coverage.dat ]]; then
        "$VERILATOR_COVERAGE" --annotate "$DIR/annotated" --annotate-all \
            --annotate-min 1 "$DIR/coverage.dat" >/dev/null 2>&1
        grep -rh "cover property" "$DIR/annotated/" 2>/dev/null \
            | sed 's/^[[:space:]]*//' >"$DIR/covers.txt"
        covers_total=$(wc -l <"$DIR/covers.txt")
        covers_zero=$(grep -c "%000000" "$DIR/covers.txt")
    fi

    if [[ $sim_rc -ne 0 || $sva_fails -ne 0 ]]; then
        verdict="FAIL"
    elif [[ $covers_total -eq 0 || $covers_zero -ne 0 ]]; then
        verdict="INCONCLUSIVE"
    else
        verdict="PASS"
    fi
fi

secs=$(( $(date +%s) - start ))
covers_hit=$(( covers_total - covers_zero ))

# Result record: flow, top, verdict, SVA failures, covers hit, covers total,
# seconds. Tab separated so report.sh can read it with one `read`.
printf '%s\t%s\t%s\t%d\t%d\t%d\t%d\n' "$FLOW" "$TOP" "$verdict" \
    "$sva_fails" "$covers_hit" "$covers_total" "$secs" >"$DIR/result.tsv"

# Full cover listing on interactive runs, as the old run_tb printed.
if [[ $QUIET != 1 && -s $DIR/covers.txt ]]; then
    echo "--------------------------------------------------"
    echo "cover directives - $TOP"
    echo "--------------------------------------------------"
    cat "$DIR/covers.txt"
    echo "--------------------------------------------------"
fi

case $verdict in
    PASS)         colour=$C_GRN ;;
    INCONCLUSIVE) colour=$C_YEL ;;
    *)            colour=$C_RED ;;
esac
printf '%s[%-12s]%s %-6s %-22s covers %d/%d  sva_fail %d  %ds\n' \
    "$colour" "$verdict" "$C_OFF" "$FLOW" "$TOP" \
    "$covers_hit" "$covers_total" "$sva_fails" "$secs"

# In quiet mode nothing else was printed, so show where it went wrong.
if [[ $QUIET == 1 && $verdict == FAIL ]]; then
    echo "  --- last 25 lines of $fail_log ---"
    tail -n 25 "$fail_log" | sed 's/^/  /'
fi
if [[ $verdict == INCONCLUSIVE ]]; then
    if [[ $covers_total -eq 0 ]]; then
        echo "  no cover directives - nothing proves the assertions ran"
    else
        grep "%000000" "$DIR/covers.txt" | sed 's/^/  zero-hit: /'
    fi
fi

[[ $NOFAIL == 1 ]] && exit 0
case $verdict in
    PASS)         exit 0 ;;
    INCONCLUSIVE) [[ $STRICT == 1 ]] && exit 2 || exit 0 ;;
    *)            exit 1 ;;
esac