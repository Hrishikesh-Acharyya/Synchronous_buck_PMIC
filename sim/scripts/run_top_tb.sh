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
#                   COLOR  - 1 colour, 0 plain; unset: colour on a terminal
#                   RAW    - 1: stream the simulation output unfiltered
#
#                   Presentation is shared with run_tb.sh (ui.sh): build output
#                   only on failure, coloured simulation output, a summary
#                   card. The verdict still comes from the raw run.log.

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

# Colours, badges and the output filter (ui.sh). COLOR comes from the
# Makefile: under --output-sync stdout is never a terminal.
SCRIPTS_DIR=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=ui.sh
source "$SCRIPTS_DIR/ui.sh"

# run_logged: as in run_tb.sh - log file always, terminal (through
#             ui_paint) unless QUIET, and the command's own exit code
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

# build_quiet: the build, logged only; shown if it fails
build_quiet() {
    "$@" >"$DIR/build.log" 2>&1
}

rm -rf "$DIR"
mkdir -p "$DIR"
start=$(date +%s)

# This testbench takes minutes, and under `make -j` its output is held until
# it ends, so a silent terminal looks like a hang. In QUIET mode, announce
# the start straight to the terminal, bypassing make's buffering. Skipped
# when there is no terminal (CI, redirected runs).
if [[ $QUIET == 1 ]] && { : >/dev/tty; } 2>/dev/null; then
    case $SIM in
        verilator) eta="about 1 min to build, 1-2 min to run" ;;
        *)         eta="Icarus at 50 MHz: allow 10-25 min" ;;
    esac
    printf '%s %-6s %-22s %s%s%s\n' "$(ui_badge RUNNING)" "$FLOW" "$TOP" "$UI_DIM" "$eta" "$UI_OFF" >/dev/tty
fi
plusargs=()
[[ $WAVES == 1 ]] && plusargs+=("+WAVES")

[[ $QUIET == 1 ]] || ui_header "$TOP" "$FLOW flow $UI_DOT $SIM"
step build
build_ok=1
case $SIM in
    verilator)
        # shellcheck disable=SC2086  # TOP_VFLAGS is a flag list
        # env -u: Verilator's own make must not see the parent's jobserver -
        # it cannot use it from here and falls back to one job; --build-jobs
        # in TOP_VFLAGS sets its parallelism instead.
        build_quiet env -u MAKEFLAGS -u MFLAGS -u MAKELEVEL \
            "$VERILATOR" $TOP_VFLAGS --Mdir "$DIR" \
            --top-module "$TOP" "${SRCS[@]}" || build_ok=0
        RUN=("./V$TOP")
        ;;
    iverilog)
        # shellcheck disable=SC2086  # TOP_IVFLAGS is a flag list
        build_quiet "$IVERILOG" $TOP_IVFLAGS -s "$TOP" \
            -o "$DIR/$TOP.vvp" "${SRCS[@]}" || build_ok=0
        # -n: $stop ends the run instead of opening the interactive prompt
        RUN=("$VVP" -n "./$TOP.vvp")
        ;;
    *)
        echo "run_top_tb.sh: unknown simulator '$SIM'"; exit 2 ;;
esac

build_secs=$(( $(date +%s) - start ))
if [[ $QUIET != 1 ]]; then
    if [[ $build_ok == 1 ]]; then
        printf '%s%s%s  %s%ds%s\n' "$UI_GRN" "$UI_TICK" "$UI_OFF" "$UI_DIM" "$build_secs" "$UI_OFF"
        step simulate; echo
    else
        printf '%s%s failed%s  %ds\n\n' "$UI_BLD$UI_RED" "$UI_CROSS" "$UI_OFF" "$build_secs"
        grep -vE '^(make|g\+\+|ccache|echo|rm |ar |- V e r i l a t i o n)' "$DIR/build.log" \
            | ui_paint | sed 's/^/    /'
    fi
fi

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

# Interactive runs: the summary card.
if [[ $QUIET != 1 ]]; then
    log=$DIR/run.log
    checks_run=$(ui_logval "checks run" "$log")
    checks_failed=$(ui_logval "checks failed" "$log")
    exit_why=$(ui_logval "exit" "$log")
    simtime=$(sed -nE 's/.*\$finish at ([^;]+);.*/\1/p' "$log" 2>/dev/null | tail -1)
    if   [[ $verdict == PASS ]]; then why="every check passed and every coverage bin was hit"
    elif [[ $build_ok != 1 ]];   then why="build failed - see the diagnostics above"
    elif [[ ! -s $log ]];        then why="no simulation output"
    else why="${checks_failed:-?} check(s) failed, or the run ended without a verdict - see the red lines above"
    fi
    echo
    ui_card_row verdict "$(ui_badge "$verdict")  $why"
    if [[ -s $log ]]; then
        ui_card_row checks "$(ui_num "${checks_run:-0}") run $UI_DOT $(ui_good_zero "${checks_failed:-0}") failed"
        ui_card_row coverage "$(ui_bar "$bins_hit" "$bins_total" 20) $bins_hit/$bins_total bins hit"
        for k in clock TELEMETRY_EN "random seed"; do
            v=$(ui_logval "$k" "$log")
            [[ -n $v ]] && ui_card_row "$k" "$v"
        done
        [[ -n $exit_why ]] && ui_card_row exit "$exit_why${simtime:+ $UI_DOT $simtime simulated}"
    fi
    ui_card_row time "build ${build_secs}s $UI_DOT total ${secs}s"
    ui_card_row logs "$UI_DIM$DIR/{build,run}.log$UI_OFF"
    echo
fi

# The one-line status - the only output of a QUIET (suite) run.
printf '%s %-6s %-22s bins   %s %3d/%-3d  %-9s  %ds\n' "$(ui_badge "$verdict")" \
    "$FLOW" "$TOP" "$(ui_bar "$bins_hit" "$bins_total" 10)" "$bins_hit" "$bins_total" "$SIM" "$secs"
if [[ $QUIET == 1 && $verdict == FAIL ]]; then
    log=$DIR/run.log; [[ -f $log ]] || log=$DIR/build.log
    echo "  --- FAIL lines / last lines of $log ---"
    { grep -E " FAIL |MISS|SCOREBOARD|MONITOR" "$log" || tail -n 25 "$log"; } | head -n 25 | sed 's/^/  /'
fi

[[ $NOFAIL == 1 ]] && exit 0
[[ $verdict == PASS ]] && exit 0
exit 1
