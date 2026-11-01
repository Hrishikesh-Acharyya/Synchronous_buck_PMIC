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
#                   On an interactive run the build output is kept in
#                   build.log and shown only if the build fails, the
#                   simulation output is coloured as it streams, and the run
#                   ends with the cover table and a summary card (ui.sh,
#                   covers.sh). The verdict is still taken from the raw logs.
#
# Global variables: Read from the environment, set per recipe by the Makefile:
#                   VERILATOR, VERILATOR_COVERAGE - tool paths
#                   VFLAGS  - full Verilator flag string (word-split on purpose)
#                   QUIET   - 1: logs to file only, one status line printed
#                   WAVES   - 1: pass +WAVES to the model so it dumps a VCD
#                   COLOR   - 1 colour, 0 plain; unset: colour on a terminal
#                   NOFAIL  - 1: always exit 0 so a suite run continues and
#                                the report owns the exit status
#                   STRICT  - 1: INCONCLUSIVE exits non-zero as well
#                   RAW     - 1: stream the simulation output unfiltered

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

# Colours, badges and the output filter. COLOR comes from the Makefile
# (mk/config.mk): under --output-sync stdout is never a terminal, so the
# script cannot decide for itself; run by hand with COLOR unset, ui.sh tests
# its own stdout.
SCRIPTS_DIR=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=ui.sh
source "$SCRIPTS_DIR/ui.sh"

# run_logged: runs a command with its output in a log file, and on the
#             terminal too unless QUIET - through ui_paint, so the log keeps
#             the raw text the verdict greps read. Returns the command's own
#             exit code, not tee's - that is what PIPESTATUS is for.
run_logged() {
    local log=$1; shift
    if [[ $QUIET == 1 ]]; then
        "$@" >"$log" 2>&1
    else
        "$@" 2>&1 | tee "$log" | ui_paint
        return "${PIPESTATUS[0]}"
    fi
}

# step: the "  > build" line an interactive run prints before each stage
step() {
    [[ $QUIET == 1 ]] || printf '  %s>%s %-9s' "$UI_BLD$UI_BLU" "$UI_OFF" "$1"
}

# Wiped every time: Verilator's timestamp-based incremental build is
# unreliable across the 9p mount and has handed back stale binaries.
rm -rf "$DIR"
mkdir -p "$DIR"
start=$(date +%s)

verdict=""
fail_why=""
sva_fails=0
covers_total=0
covers_zero=0
build_secs=0

[[ $QUIET == 1 ]] || ui_header "$TOP" "$FLOW flow"

# Build output goes to build.log only: with -Wall every diagnostic is fatal,
# so a build that succeeds has nothing to say. On failure the log is shown.
step build
# shellcheck disable=SC2086  # VFLAGS is a flag list and must word-split
if ! env -u MAKEFLAGS -u MFLAGS -u MAKELEVEL \
        "$VERILATOR" $VFLAGS --Mdir "$DIR" --top-module "$TOP" "${SRCS[@]}" \
        >"$DIR/build.log" 2>&1; then
    verdict="FAIL"
    fail_why="build failed - see the diagnostics above"
    fail_log="$DIR/build.log"
    build_secs=$(( $(date +%s) - start ))
    if [[ $QUIET != 1 ]]; then
        printf '%s%s failed%s  %ds\n\n' "$UI_BLD$UI_RED" "$UI_CROSS" "$UI_OFF" "$build_secs"
        grep -vE '^(make|g\+\+|ccache|echo|rm |ar |- V e r i l a t i o n)' "$DIR/build.log" \
            | ui_paint | sed 's/^/    /'
    fi
else
    build_secs=$(( $(date +%s) - start ))
    [[ $QUIET == 1 ]] || printf '%s%s%s  %s%ds%s\n' "$UI_GRN" "$UI_TICK" "$UI_OFF" "$UI_DIM" "$build_secs" "$UI_OFF"
    step simulate
    [[ $QUIET == 1 ]] || echo
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
        # covers.tsv / covers.txt: one record per cover, multi-line
        # properties joined (covers.sh)
        bash "$SCRIPTS_DIR/covers.sh" parse "$DIR"
        covers_total=$(wc -l <"$DIR/covers.tsv")
        covers_zero=$(awk -F'\t' '$2 == 0' "$DIR/covers.tsv" | wc -l)
    fi

    checks_failed=$(ui_logval "checks failed" "$DIR/run.log")
    if [[ $sim_rc -ne 0 || $sva_fails -ne 0 ]]; then
        verdict="FAIL"
        if   [[ $sva_fails -ne 0 ]];          then fail_why="$sva_fails assertion failure(s) - the SVA FAIL lines above"
        elif [[ ${checks_failed:-0} != 0 ]];  then fail_why="$checks_failed procedural check(s) failed"
        else fail_why="the simulation exited with status $sim_rc"
        fi
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

# Interactive runs: the cover table, then the summary card.
if [[ $QUIET != 1 && -s $DIR/covers.tsv ]]; then
    bash "$SCRIPTS_DIR/covers.sh" table "$DIR"
fi
if [[ $QUIET != 1 ]]; then
    asserts=0
    [[ -s $DIR/asserts.tsv ]] && asserts=$(awk -F'\t' '{ s += $2 } END { print s + 0 }' "$DIR/asserts.tsv")
    checkers=$( [[ -s $DIR/asserts.tsv ]] && wc -l <"$DIR/asserts.tsv" || echo 0)
    checks_run=$(ui_logval "checks run" "$DIR/run.log" 2>/dev/null)
    checks_failed=$(ui_logval "checks failed" "$DIR/run.log" 2>/dev/null)
    exit_why=$(ui_logval "exit" "$DIR/run.log" 2>/dev/null)
    simtime=$(sed -nE 's/.*\$finish at ([^;]+);.*/\1/p' "$DIR/run.log" 2>/dev/null | tail -1)
    thin=$( [[ -s $DIR/covers.tsv ]] && awk -F'\t' -v t="${THIN:-10}" '$2 > 0 && $2 < t' "$DIR/covers.tsv" | wc -l || echo 0)

    case $verdict in
        PASS)         why="no assertion or check failed, and every cover was hit" ;;
        INCONCLUSIVE) if [[ $covers_total -eq 0 ]]; then why="clean, but there are no covers - nothing shows the assertions ran"
                      else why="clean, but $covers_zero cover(s) never hit - the assertions behind them proved nothing"; fi ;;
        *)            why=$fail_why ;;
    esac

    echo
    ui_card_row verdict "$(ui_badge "$verdict")  $why"
    if [[ $verdict != FAIL || -f $DIR/run.log ]]; then
        if [[ -s $DIR/asserts.tsv ]]; then
            ui_card_row assertions "$(ui_num "$asserts") armed in $checkers checker(s) $UI_DOT $(ui_good_zero "$sva_fails") failed"
        else
            ui_card_row assertions "$(ui_good_zero "$sva_fails") failed"
        fi
        if [[ ${checks_run:-0} == 0 ]]; then
            ui_card_row checks "${UI_DIM}none - every claim is in the bound checker$UI_OFF"
        else
            ui_card_row checks "$(ui_num "$checks_run") run $UI_DOT $(ui_good_zero "${checks_failed:-0}") failed"
        fi
        cov_note=""
        (( thin > 0 )) && cov_note=" $UI_DOT $UI_YEL$thin thin (<${THIN:-10} hits)$UI_OFF"
        (( covers_zero > 0 )) && cov_note+=" $UI_DOT $UI_BLD$UI_RED$covers_zero never hit$UI_OFF"
        if [[ -f $DIR/coverage.dat ]]; then
            ui_card_row covers "$(ui_bar "$covers_hit" "$covers_total" 20) $covers_hit/$covers_total hit$cov_note"
        else
            ui_card_row covers "${UI_DIM}not recorded - coverage is written only when the run reaches \$finish$UI_OFF"
        fi
        [[ -n $exit_why ]] && ui_card_row exit "$exit_why${simtime:+ $UI_DOT $simtime simulated}"
    fi
    ui_card_row time "build ${build_secs}s $UI_DOT total ${secs}s"
    ui_card_row logs "$UI_DIM$DIR/{build,run}.log$UI_OFF"
    echo
fi

# The one-line status - the only output of a QUIET (suite) run.
printf '%s %-6s %-22s covers %s %3d/%-3d  sva_fail %s  %ds\n' \
    "$(ui_badge "$verdict")" "$FLOW" "$TOP" "$(ui_bar "$covers_hit" "$covers_total" 10)" \
    "$covers_hit" "$covers_total" "$(ui_good_zero "$sva_fails")" "$secs"

# In quiet mode nothing else was printed, so show where it went wrong.
if [[ $QUIET == 1 && $verdict == FAIL ]]; then
    echo "  --- last 25 lines of $fail_log ---"
    tail -n 25 "$fail_log" | sed 's/^/  /'
fi
if [[ $verdict == INCONCLUSIVE ]]; then
    if [[ $covers_total -eq 0 ]]; then
        echo "  no cover directives - nothing proves the assertions ran"
    else
        awk -F'\t' '$2 == 0 { print "  zero-hit: " $3 ": " $4 }' "$DIR/covers.tsv"
    fi
fi

[[ $NOFAIL == 1 ]] && exit 0
case $verdict in
    PASS)         exit 0 ;;
    INCONCLUSIVE) [[ $STRICT == 1 ]] && exit 2 || exit 0 ;;
    *)            exit 1 ;;
esac