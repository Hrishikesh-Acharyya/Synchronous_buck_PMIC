#!/usr/bin/env bash
#
# Filename:         report.sh
#
# File Description: Prints one table of testbench results for a flow and
#                   decides the suite's exit status. Reads the result.tsv
#                   each run_tb.sh invocation leaves in its build directory.
#                   A testbench in the expected list with no result is shown
#                   as NOT RUN and counts as a failure - a silently skipped
#                   testbench must never read as a pass.
#
#                   Usage: report.sh <build_root> <flow> <top...>
#
# Global variables: STRICT - 1: INCONCLUSIVE fails the suite as well (CI)

set -uo pipefail

ROOT=$1
FLOW=$2
shift 2
STRICT=${STRICT:-0}

if [[ -t 1 ]]; then
    C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YEL=$'\e[33m'; C_OFF=$'\e[0m'
else
    C_RED=''; C_GRN=''; C_YEL=''; C_OFF=''
fi

n_pass=0; n_inc=0; n_fail=0

echo
echo "==================== $FLOW results ===================="
printf '%-22s %-13s %10s %9s %6s\n' "testbench" "verdict" "covers" "sva_fail" "time"
echo "--------------------------------------------------------------"
for top in "$@"; do
    rec="$ROOT/$FLOW/$top/result.tsv"
    if [[ ! -f $rec ]]; then
        printf '%-22s %s%-13s%s\n' "$top" "$C_RED" "NOT RUN" "$C_OFF"
        n_fail=$((n_fail + 1))
        continue
    fi
    IFS=$'\t' read -r _ _ verdict sva hit total secs <"$rec"
    case $verdict in
        PASS)         c=$C_GRN; n_pass=$((n_pass + 1)) ;;
        INCONCLUSIVE) c=$C_YEL; n_inc=$((n_inc + 1)) ;;
        *)            c=$C_RED; n_fail=$((n_fail + 1)) ;;
    esac
    printf '%-22s %s%-13s%s %10s %9d %5ds\n' "$top" "$c" "$verdict" "$C_OFF" \
        "$hit/$total" "$sva" "$secs"
done
echo "--------------------------------------------------------------"
echo "$n_pass pass, $n_inc inconclusive, $n_fail fail"
echo

[[ $n_fail -gt 0 ]] && exit 1
[[ $STRICT == 1 && $n_inc -gt 0 ]] && exit 2
exit 0