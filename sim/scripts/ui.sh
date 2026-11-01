#!/usr/bin/env bash
#
# Filename:         ui.sh
#
# File Description: Terminal presentation shared by run_tb.sh, run_top_tb.sh,
#                   report.sh and covers.sh - colours, verdict badges, bars,
#                   the live colouring of simulation output and the summary
#                   card. Sourced, never run. Nothing here decides a verdict:
#                   the scripts that source it still grep the raw logs, so
#                   changing how a run looks can never change whether it
#                   passes.
#
#                   Colour follows COLOR exactly as before (1 on, 0 off,
#                   unset: on if stdout is a terminal). With colour off every
#                   glyph falls back to plain ASCII and the escapes the
#                   testbenches print themselves are stripped, so CI logs
#                   stay readable.
#
# Global variables: COLOR  - 1 colour, 0 plain; unset: colour on a terminal
#                   RAW    - 1: stream simulation output untouched, no filter
#                   UI_*   - colour escapes and glyphs, set below
#                   UI_COLS - terminal width used to fit the cover table

# SC2034: the UI_* variables are set here for the scripts that source this
#         file, so shellcheck, reading it alone, sees them as unused.
# shellcheck disable=SC2034
if [[ ${COLOR:-} == 1 || ( -z ${COLOR:-} && -t 1 ) ]]; then
    UI_ON=1
    UI_RED=$'\e[31m';  UI_GRN=$'\e[32m';  UI_YEL=$'\e[33m'
    UI_BLU=$'\e[34m';  UI_CYN=$'\e[36m'
    UI_BLD=$'\e[1m';   UI_DIM=$'\e[2m';   UI_OFF=$'\e[0m'
    # badges: black text on a coloured block, readable on light and dark themes
    UI_B_PASS=$'\e[1;30;42m'; UI_B_INC=$'\e[1;30;43m'; UI_B_FAIL=$'\e[1;97;41m'
    UI_B_RUN=$'\e[1;30;46m'
    UI_FULL='█'; UI_EMPTY='░'; UI_RULE='─'; UI_BAR='│'; UI_DOT='·'
    UI_TICK='✔'; UI_CROSS='✘'
else
    UI_ON=0
    UI_RED=''; UI_GRN=''; UI_YEL=''; UI_BLU=''; UI_CYN=''
    UI_BLD=''; UI_DIM=''; UI_OFF=''
    UI_B_PASS=''; UI_B_INC=''; UI_B_FAIL=''; UI_B_RUN=''
    UI_FULL='#'; UI_EMPTY='.'; UI_RULE='-'; UI_BAR='|'; UI_DOT='-'
    UI_TICK='ok'; UI_CROSS='xx'
fi

# UI_COLS: the terminal's width. Under make --output-sync stdout is a pipe,
#          so ask the controlling terminal; CI has none and gets 110.
UI_COLS=${COLUMNS:-}
if [[ -z $UI_COLS ]]; then
    UI_COLS=$( { stty size </dev/tty | cut -d' ' -f2; } 2>/dev/null )
fi
[[ $UI_COLS =~ ^[0-9]+$ ]] || UI_COLS=110
(( UI_COLS > 160 )) && UI_COLS=160
(( UI_COLS < 70 ))  && UI_COLS=70

# ui_repeat: $1 copies of the string $2
ui_repeat() {
    local out='' i
    for (( i = 0; i < $1; i++ )); do out+=$2; done
    printf '%s' "$out"
}

# ui_header: a full-width title rule - "── title ── subtitle ────"
ui_header() {
    local title=$1 sub=${2:-} fill
    # 8 = the two 2-glyph rules and the four spaces around title and subtitle
    fill=$(( UI_COLS - ${#title} - ${#sub} - 8 ))
    (( fill < 2 )) && fill=2
    printf '\n%s%s%s %s%s%s %s%s%s %s %s%s%s\n' \
        "$UI_DIM" "$UI_RULE$UI_RULE" "$UI_OFF" "$UI_BLD$UI_CYN" "$title" "$UI_OFF" \
        "$UI_DIM" "$UI_RULE$UI_RULE" "$UI_OFF" "$sub" \
        "$UI_DIM" "$(ui_repeat "$fill" "$UI_RULE")" "$UI_OFF"
}

# ui_rule: a dim full-width line
ui_rule() {
    printf '%s%s%s\n' "$UI_DIM" "$(ui_repeat "$UI_COLS" "$UI_RULE")" "$UI_OFF"
}

# ui_badge: the verdict as a fixed-width block, so columns line up
#           PASS / INCONCLUSIVE / FAIL / NOT RUN / RUNNING
ui_badge() {
    local v=$1 c
    case $v in
        PASS)         c=$UI_B_PASS ;;
        INCONCLUSIVE) c=$UI_B_INC; v=INCONCL ;;
        RUNNING)      c=$UI_B_RUN ;;
        *)            c=$UI_B_FAIL ;;
    esac
    if [[ $UI_ON == 1 ]]; then
        printf '%s %-7s %s' "$c" "$v" "$UI_OFF"
    else
        printf '[%-7s]' "$v"
    fi
}

# ui_bar: hit/total as a bar of $3 cells (default 10), coloured green when
#         full, yellow when partial, red at zero
ui_bar() {
    local hit=$1 total=$2 w=${3:-10} n c
    if (( total == 0 )); then
        printf '%s%s%s' "$UI_DIM" "$(ui_repeat "$w" "$UI_EMPTY")" "$UI_OFF"
        return
    fi
    n=$(( hit * w / total ))
    (( hit > 0 && n == 0 )) && n=1
    if   (( hit == total )); then c=$UI_GRN
    elif (( hit == 0 ));     then c=$UI_RED
    else                          c=$UI_YEL
    fi
    printf '%s%s%s%s%s' "$c" "$(ui_repeat "$n" "$UI_FULL")" \
        "$UI_DIM" "$(ui_repeat $(( w - n )) "$UI_EMPTY")" "$UI_OFF"
}

# ui_num: an integer with thousands separators - 8215 -> 8,215
ui_num() {
    local s=$1 out=''
    while (( ${#s} > 3 )); do out=",${s: -3}$out"; s=${s:0:${#s}-3}; done
    printf '%s' "$s$out"
}

# ui_good_zero: "0" in green - zero is the good value for failures - and any
#               other count in bold red
ui_good_zero() {
    if (( $1 == 0 )); then printf '%s0%s' "$UI_GRN" "$UI_OFF"
    else                   printf '%s%s%s' "$UI_BLD$UI_RED" "$1" "$UI_OFF"
    fi
}

# ui_card_row: one line of the summary card - "│ label      value"
ui_card_row() {
    printf '  %s%s%s %s%-12s%s %s\n' "$UI_CYN" "$UI_BAR" "$UI_OFF" \
        "$UI_DIM" "$1" "$UI_OFF" "$2"
}

# ui_paint: filter for live simulation output. Failures in bold red, HIT /
#           MISS bins coloured, section headers bold. The testbench's closing
#           verdict block and Verilator's report footer are dropped from the
#           terminal - the summary card repeats all of it - but stay in
#           run.log untouched. A failing assertion usually fails on every
#           clock after it first goes wrong, so only the first FAIL_SHOW
#           (default 5) lines per assertion or check label are shown, and
#           the rest are counted at the end. RAW=1 turns the filter off.
ui_paint() {
    if [[ ${RAW:-0} == 1 ]]; then cat; return; fi
    awk -v on="$UI_ON" -v red="$UI_BLD$UI_RED" -v grn="$UI_GRN" -v yel="$UI_YEL" \
        -v cyn="$UI_BLD$UI_CYN" -v dim="$UI_DIM" -v off="$UI_OFF" \
        -v show="${FAIL_SHOW:-5}" '
    {
        line = $0
        plain = line
        gsub(/\033\[[0-9;]*m/, "", plain)
        if (!on) line = plain

        # the verdict block and the simulator footer: shown by the card.
        # (Regexes avoid {n,} counts: mawk, the default awk on Ubuntu,
        # does not support them.)
        if (plain ~ /^-------------------+$/)                         next
        if (plain ~ /^(exit|assertion fails|checks run|checks failed|clock|TELEMETRY_EN|random seed|coverage) +: /) next
        if (plain ~ /^[A-Za-z0-9_]+_tb: (PASS|FAIL)/)                  next
        if (plain ~ /^- /)                                            next
        # no more than one blank line in a row
        if (plain ~ /^[ \t]*$/) { if (blank) next; blank = 1 } else blank = 0

        # repeated failures of one label: first few shown, the rest counted
        if (plain ~ /(SVA|CHECK) FAIL: /) {
            lab = plain
            sub(/^.*(SVA|CHECK) FAIL: /, "", lab)
            sub(/[:,(].*$/, "", lab)
            if (++seen[lab] > show) { if (seen[lab] == show + 1) order[++nlab] = lab; next }
        }

        if (!on) { print line; fflush(); next }

        if (plain ~ /(SVA FAIL|CHECK FAIL|FAIL:| FAIL |MISS|SCOREBOARD|MONITOR|%Error|ERROR)/)
            line = red line off
        else if (plain ~ /%Warning|WARNING|INCONCLUSIVE/)
            line = yel line off
        else if (plain ~ /^==+ .* ==+$/ || plain ~ /^##/)
            line = cyn line off
        else if (plain ~ /^ +HIT /)
            sub(/HIT/, grn "HIT" off, line)
        else if (plain ~ /^\[[ 0-9.]+[a-z]*s\] PASS /)            # pmic_top_tb checks
            sub(/\] PASS /, "] " grn "PASS" off " ", line)
        else if (plain ~ /^\[[ 0-9.]+[a-z]*s\] ---- /)            # pmic_top_tb phases
            line = cyn line off
        else if (plain ~ /^---+ .* ---+$/ || plain ~ /^[A-Z][A-Za-z ]+:$/)
            line = cyn line off
        print line
        fflush()
    }
    END {
        for (i = 1; i <= nlab; i++)
            printf "%s... %d more %s failure(s) not shown - all are in run.log%s\n", \
                red, seen[order[i]] - show, order[i], off
    }'
}

# ui_logval: the value of "key : value" from the last verdict block of a log,
#            escapes stripped; empty when the key is missing
ui_logval() {
    sed 's/\x1b\[[0-9;]*m//g' "$2" 2>/dev/null \
        | sed -nE "s/^$1 +: (.*)$/\1/p" | tail -1
}
