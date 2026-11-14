#!/usr/bin/env bash
#
# Filename:         run_cocotb.sh
#
# File Description: Runs a cocotb suite - the host-interface suite
#                   (tb/telemetry/host_if) or the whole-supervisor suite
#                   (tb/top/pmic_top) - for sim/Makefile, and writes the same
#                   one-line result record run_tb.sh writes, so report.sh
#                   lists it beside the module testbenches. The suite's own
#                   Makefile is invoked with -f from a per-flow build
#                   directory, so each flow's sim_build, results.xml and
#                   coverage.dat are kept apart and parallel flows never
#                   collide.
#
#                   Usage: run_cocotb.sh <build_dir> <flow> <top> <tb_dir> <extra_args> <sources...>
#                     top         the name the result tables list
#                     tb_dir      the suite's folder (holds its Makefile)
#                     extra_args  the Verilator flags, as one word-split string
#                     sources     the RTL to verify: the SystemVerilog list, or
#                                 the package plus the converted Verilog
#
#                   Verdict, as for the module testbenches:
#                     FAIL          the run failed, a test failed, or an SVA
#                                   FAIL line was printed
#                     INCONCLUSIVE  clean, but an SVA cover never fired
#                     PASS          clean, and every cover fired
#                   The covers column counts the bound checkers' covers. The
#                   cocotb-coverage covergroups are reported separately in
#                   fcov.tsv (bins hit, bins total) and shown by report.sh.
#
# Global variables: Read from the environment, set by sim/mk/cocotb.mk:
#                   SUITE_VARS - extra make variables for the suite, e.g.
#                                RANDOM_EVENTS=400 for host_if
#                   COVER_FILTER - regex on the checker file name: only those
#                                checkers' covers count toward the verdict.
#                                Empty = every bound checker's covers.
#                   FCOV_REPORT - the covergroup report script; default the
#                                suite's own fcov_report.py
#                   QUIET, NOFAIL, STRICT, COLOR, RAW - as for run_tb.sh

set -uo pipefail

DIR=$1
FLOW=$2
TOP=$3
SUITE_DIR=$4
EXTRA_ARGS=$5
shift 5
SRCS=("$@")
# shellcheck disable=SC2206  # SUITE_VARS is a list of VAR=value words
SUITE_VARS=(${SUITE_VARS:-})
QUIET=${QUIET:-0}
NOFAIL=${NOFAIL:-0}
STRICT=${STRICT:-0}

SCRIPTS_DIR=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=ui.sh
source "$SCRIPTS_DIR/ui.sh"

mkdir -p "$DIR"
# remove only what a previous run of this flow left behind
rm -rf "$DIR/sim_build" "$DIR/annotated"
rm -f "$DIR"/{run.log,results.xml,coverage.dat,fcov.xml,fcov.tsv,covers.tsv,covers.txt,asserts.tsv,result.tsv}
start=$(date +%s)

[[ $QUIET == 1 ]] || ui_header "$TOP" "$FLOW flow $UI_DOT cocotb"

# The suite: every test. The parent's jobserver is hidden from the inner make,
# which runs its own Verilator build. FCOV_XML is passed to every suite; one
# that samples no covergroups simply never writes it.
suite() {
    ( cd "$DIR" && env -u MAKEFLAGS -u MFLAGS -u MAKELEVEL \
        make -f "$SUITE_DIR/Makefile" SIM_BUILD="$DIR/sim_build" \
             RTL_SRCS="${SRCS[*]}" EXTRA_ARGS="$EXTRA_ARGS" \
             FCOV_XML="$DIR/fcov.xml" "${SUITE_VARS[@]}" )
}
if [[ $QUIET == 1 ]]; then
    suite > "$DIR/run.log" 2>&1
    run_rc=$?
else
    suite 2>&1 | tee "$DIR/run.log" | grep -E "\*\* test_|SVA FAIL|Error|FAIL" | ui_paint
    run_rc=${PIPESTATUS[0]}
fi

# tests: from cocotb's JUnit results
tests=0; failed=0
if [[ -f $DIR/results.xml ]]; then
    tests=$(grep -c "<testcase" "$DIR/results.xml")
    failed=$(grep -c "<failure" "$DIR/results.xml")
fi
sva_fails=$(grep -c "SVA FAIL:" "$DIR/run.log")

# SVA covers: annotate, then the same parser as the module testbenches
covers_total=0; covers_zero=0
if [[ -f $DIR/coverage.dat ]]; then
    "${VERILATOR_COVERAGE:-verilator_coverage}" --annotate "$DIR/annotated" --annotate-all \
        --annotate-min 1 "$DIR/coverage.dat" >/dev/null 2>&1
    bash "$SCRIPTS_DIR/covers.sh" parse "$DIR"
    # COVER_FILTER: keep only the suite's own checkers. The whole-supervisor
    # suite binds every block's checker, but the blocks' corner covers are
    # their own testbenches' job; it is judged by pmic_top_sva, as a module
    # testbench is judged by its checker.
    if [[ -n ${COVER_FILTER:-} ]]; then
        awk -F'\t' -v re="$COVER_FILTER" '$1 ~ re' "$DIR/covers.tsv" > "$DIR/covers.tsv.f" \
            && mv "$DIR/covers.tsv.f" "$DIR/covers.tsv"
    fi
    covers_total=$(wc -l <"$DIR/covers.tsv")
    covers_zero=$(awk -F'\t' '$2 == 0' "$DIR/covers.tsv" | wc -l)
fi
covers_hit=$(( covers_total - covers_zero ))

# functional coverage: bins hit / total, for report.sh - suites with covergroups
FCOV_REPORT=${FCOV_REPORT:-$SUITE_DIR/fcov_report.py}
if [[ -f $DIR/fcov.xml && -f $FCOV_REPORT ]]; then
    python3 "$FCOV_REPORT" summary "$DIR/fcov.xml" | tr ' ' '\t' > "$DIR/fcov.tsv"
fi

if [[ $run_rc -ne 0 || $failed -ne 0 || $tests -eq 0 || $sva_fails -ne 0 ]]; then
    verdict=FAIL
elif [[ $covers_total -eq 0 || $covers_zero -ne 0 ]]; then
    verdict=INCONCLUSIVE
else
    verdict=PASS
fi
secs=$(( $(date +%s) - start ))

printf '%s\t%s\t%s\t%d\t%d\t%d\t%d\n' "$FLOW" "$TOP" "$verdict" \
    "$sva_fails" "$covers_hit" "$covers_total" "$secs" >"$DIR/result.tsv"

if [[ $QUIET != 1 ]]; then
    [[ -s $DIR/covers.tsv ]] && bash "$SCRIPTS_DIR/covers.sh" table "$DIR"
    echo
    ui_card_row verdict "$(ui_badge "$verdict")  $((tests - failed)) of $tests cocotb tests passed"
    ui_card_row assertions "$(ui_good_zero "$sva_fails") failed"
    ui_card_row covers "$(ui_bar "$covers_hit" "$covers_total" 20) $covers_hit/$covers_total SVA covers hit"
    if [[ -s $DIR/fcov.tsv ]]; then
        read -r fhit ftotal < <(tr '\t' ' ' < "$DIR/fcov.tsv")
        ui_card_row covergroups "$UI_MAG$(ui_bar "$fhit" "$ftotal" 20)$UI_OFF $fhit/$ftotal bins"
        python3 "$FCOV_REPORT" report "$DIR/fcov.xml" | sed 's/^/                 /'
    fi
    ui_card_row time "${secs}s"
    ui_card_row logs "$UI_DIM$DIR/run.log$UI_OFF"
    echo
fi

printf '%s %-6s %-22s covers %s %3d/%-3d  sva_fail %s  %ds\n' \
    "$(ui_badge "$verdict")" "$FLOW" "$TOP" "$(ui_bar "$covers_hit" "$covers_total" 10)" \
    "$covers_hit" "$covers_total" "$(ui_good_zero "$sva_fails")" "$secs"

if [[ $QUIET == 1 && $verdict == FAIL ]]; then
    echo "  --- failing tests / last lines of $DIR/run.log ---"
    { grep -E "FAIL|SVA FAIL|Error" "$DIR/run.log" || tail -n 25 "$DIR/run.log"; } | head -n 25 | sed 's/^/  /'
fi
if [[ $verdict == INCONCLUSIVE ]]; then
    awk -F'\t' '$2 == 0 { print "  zero-hit: " $3 ": " $4 }' "$DIR/covers.tsv"
fi

[[ $NOFAIL == 1 ]] && exit 0
case $verdict in
    PASS)         exit 0 ;;
    INCONCLUSIVE) [[ $STRICT == 1 ]] && exit 2 || exit 0 ;;
    *)            exit 1 ;;
esac
