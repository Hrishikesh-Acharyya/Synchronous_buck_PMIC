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
#                   COLOR  - 1 colour, 0 plain; unset: colour on a terminal

set -uo pipefail

ROOT=$1
FLOW=$2
shift 2
STRICT=${STRICT:-0}

# Colours, badges and bars (ui.sh). COLOR comes from the Makefile (mk/config.mk):
# under --output-sync stdout is never a terminal, so the script cannot decide
# for itself; run by hand with COLOR unset, ui.sh tests its own stdout.
# shellcheck source=ui.sh
source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"

n_pass=0; n_inc=0; n_fail=0
sum_hit=0; sum_total=0; sum_secs=0; sum_sva=0
problems=()

case $FLOW in
    sv)          flow_name="SystemVerilog source" ;;
    equiv)       flow_name="sv2v output (Build/pmic_full.v)" ;;
    split)       flow_name="split Verilog (rtl-verilog/)" ;;
    iv)          flow_name="Icarus Verilog" ;;
    *_notel)     flow_name="TELEMETRY_EN=0 build" ;;
    *)           flow_name="" ;;
esac
ui_header "$FLOW results" "$flow_name"
printf '  %s%-9s  %-22s  %-18s  %8s  %6s%s\n' "$UI_DIM" "verdict" "testbench" "covers" "sva_fail" "time" "$UI_OFF"
for top in "$@"; do
    rec="$ROOT/$FLOW/$top/result.tsv"
    if [[ ! -f $rec ]]; then
        printf '  %s  %-22s  %s%s%s\n' "$(ui_badge "NOT RUN")" "$top" "$UI_RED" "no result - the testbench did not run" "$UI_OFF"
        n_fail=$((n_fail + 1))
        problems+=("$top: not run")
        continue
    fi
    IFS=$'\t' read -r _ _ verdict sva hit total secs <"$rec"
    case $verdict in
        PASS)         n_pass=$((n_pass + 1)) ;;
        INCONCLUSIVE) n_inc=$((n_inc + 1));   problems+=("$top: $((total - hit)) cover(s) never hit") ;;
        *)            n_fail=$((n_fail + 1))
                      if (( sva > 0 )); then problems+=("$top: $sva assertion failure(s)")
                      else problems+=("$top: failed - build, check or exit status; see its run.log"); fi ;;
    esac
    sum_hit=$((sum_hit + hit)); sum_total=$((sum_total + total))
    sum_secs=$((sum_secs + secs)); sum_sva=$((sum_sva + sva))
    # widths applied to the plain text first: escapes would count toward them
    if (( sva == 0 )); then sva_c=$UI_GRN; else sva_c=$UI_BLD$UI_RED; fi
    printf '  %s  %-22s  %s %-7s  %s%8d%s  %5ds\n' "$(ui_badge "$verdict")" "$top" \
        "$(ui_bar "$hit" "$total" 10)" "$hit/$total" "$sva_c" "$sva" "$UI_OFF" "$secs"
done
ui_rule

n_all=$((n_pass + n_inc + n_fail))
if (( n_fail == 0 && n_inc == 0 )); then
    banner="$(ui_badge PASS)  ${UI_BLD}${UI_GRN}all $n_all testbench$( ((n_all == 1)) || echo es) pass${UI_OFF}"
elif (( n_fail == 0 )); then
    banner="$(ui_badge INCONCLUSIVE)  ${UI_BLD}${UI_YEL}$n_inc of $n_all inconclusive${UI_OFF}"
else
    banner="$(ui_badge FAIL)  ${UI_BLD}${UI_RED}$n_fail of $n_all failed${UI_OFF}"
fi
printf '  %s   %s%d pass %s %d inconclusive %s %d fail%s\n' "$banner" "$UI_DIM" \
    "$n_pass" "$UI_DOT" "$n_inc" "$UI_DOT" "$n_fail" "$UI_OFF"
printf '  %scovers %s/%s hit %s assertion failures %s %s %ss of simulation, summed%s\n' \
    "$UI_DIM" "$(ui_num "$sum_hit")" "$(ui_num "$sum_total")" "$UI_DOT" "$sum_sva" "$UI_DOT" "$sum_secs" "$UI_OFF"
# functional coverage: a covergroup line for each testbench that records it
# (fcov.tsv: bins hit, bins total) - the cocotb host-interface suite
for top in "$@"; do
    fcov="$ROOT/$FLOW/$top/fcov.tsv"
    [[ -s $fcov ]] || continue
    IFS=$'\t' read -r fhit ftotal <"$fcov"
    printf '  %scovergroups%s %-14s %s%s%s %s/%s bins hit\n' "$UI_BLD$UI_MAG" "$UI_OFF" "$top" \
        "$UI_MAG" "$(ui_bar "$fhit" "$ftotal" 10)" "$UI_OFF" "$fhit" "$ftotal"
done
for p in "${problems[@]}"; do
    printf '  %s%s%s %s\n' "$UI_RED" "$UI_CROSS" "$UI_OFF" "$p"
done
echo

[[ $n_fail -gt 0 ]] && exit 1
[[ $STRICT == 1 && $n_inc -gt 0 ]] && exit 2
exit 0
