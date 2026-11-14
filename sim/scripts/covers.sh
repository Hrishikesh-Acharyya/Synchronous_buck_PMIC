#!/usr/bin/env bash
#
# Filename:         covers.sh
#
# File Description: Reads the coverage annotation Verilator writes for one
#                   testbench run and turns it into
#                     covers.tsv  one row per cover: checker file, hits, name,
#                                 condition - the machine-readable record
#                     covers.txt  one line per cover, the whole property on
#                                 one line, zero hits marked %000000 as
#                                 verilator_coverage marks them
#                     asserts.tsv one row per checker: file, assertions armed
#                   and prints the cover table. A property written over several
#                   source lines is joined, so no condition is cut off.
#
#                   Usage: covers.sh parse <build_dir>
#                          covers.sh table <build_dir> [full]
#                     parse  writes the three files from <build_dir>/annotated
#                     table  prints them; "full" wraps long conditions instead
#                            of cutting them at the terminal edge
#
#                   Hit counts are the annotation's, which is the largest
#                   count over all instances of a checker.
#
# Global variables: COLOR - via ui.sh; THIN - hits below this are flagged as
#                   thinly exercised (default 10)

set -uo pipefail

MODE=$1
DIR=$2
FULL=${3:-}
THIN=${THIN:-10}
# shellcheck source=ui.sh
source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"

parse() {
    : >"$DIR/covers.tsv"
    : >"$DIR/asserts.tsv"
    local f
    for f in "$DIR"/annotated/*; do
        [[ -f $f ]] || continue
        awk -v file="$(basename "$f")" -v tsv="$DIR/covers.tsv" -v asr="$DIR/asserts.tsv" '
        # annotated line: optional "%" (below --annotate-min) or "~" (a
        # line holding points with different counts), a six-digit
        # count, then the source text; lines with no coverage point carry
        # no count
        function text_of(s) {
            sub(/^[ \t]*[%~]?[0-9][0-9][0-9][0-9][0-9][0-9] /, "", s)
            sub(/^[ \t]+/, "", s)
            return s
        }
        function flush(   cond) {
            cond = body
            sub(/^\(@\([^)]*\)[ ]*/, "", cond)                    # (@(posedge clk)
            sub(/^disable iff \([^()]*(\([^()]*\))?[^()]*\)[ ]*/, "", cond)
            sub(/\);[ \t]*(\/\/.*)?$/, "", cond)                  # closing );
            gsub(/[ \t]+/, " ", cond)
            printf "%s\t%d\t%s\t%s\n", file, count, name, cond >> tsv
            open = 0
        }
        {
            raw = $0
            sub(/\r$/, "", raw)            # CRLF checkers
            t = text_of(raw)
            if (open) {
                body = body " " t
                if (t ~ /;[ \t]*(\/\/.*)?$/) flush()
                next
            }
            if (t ~ /^\/\// ) next
            if (t ~ /assert property/ && t !~ /^\/\//) asserts++
            if (t ~ /cover property/ && match(raw, /[%~]?[0-9][0-9][0-9][0-9][0-9][0-9] /)) {
                c = substr(raw, RSTART, RLENGTH - 1)
                sub(/[%~]/, "", c)
                count = c + 0
                name = t; sub(/:.*/, "", name); gsub(/[ \t]/, "", name)
                body = t; sub(/^.*cover property[ \t]*/, "", body)
                open = 1
                if (t ~ /;[ \t]*(\/\/.*)?$/) flush()
            }
        }
        END { printf "%s\t%d\n", file, asserts >> asr }' "$f"
    done
    awk -F'\t' '{ printf "%s%06d %s: cover property %s\n", ($2 == 0 ? "%" : ""), $2, $3, $4 }' \
        "$DIR/covers.tsv" >"$DIR/covers.txt"
}

table() {
    [[ -s $DIR/covers.tsv ]] || { echo "  no covers recorded in $DIR"; return; }
    awk -F'\t' -v cols="$UI_COLS" -v full="$FULL" -v thin="$THIN" -v on="$UI_ON" \
        -v red="$UI_BLD$UI_RED" -v grn="$UI_GRN" -v yel="$UI_YEL" -v cyn="$UI_BLD$UI_CYN" \
        -v dim="$UI_DIM" -v bld="$UI_BLD" -v off="$UI_OFF" \
        -v fullc="$UI_FULL" -v emptyc="$UI_EMPTY" -v dot="$UI_DOT" '
    function rep(s, n,   o) { o = ""; while (n-- > 0) o = o s; return o }
    function commas(n,   s, o) {
        s = n ""; o = ""
        while (length(s) > 3) { o = "," substr(s, length(s) - 2) o; s = substr(s, 1, length(s) - 3) }
        return s o
    }
    # activity: log10 scale over five cells - 1, 10, 100, 1k, 10k+ hits
    function activity(n,   k) {
        k = (n <= 0) ? 0 : int(log(n) / log(10)) + 1
        if (k > 5) k = 5
        return rep(fullc, k) dim rep(emptyc, 5 - k) off
    }
    { f[NR] = $1; h[NR] = $2; nm[NR] = $3; cd[NR] = $4
      if (length($3) > w) w = length($3)
      tot[$1]++; if ($2 > 0) hit[$1]++; if ($2 > 0 && $2 < thin) th[$1]++ }
    END {
        if (w > 34) w = 34
        if (w < 10) w = 10
        cw = cols - w - 22; if (cw < 20) cw = 20
        for (i = 1; i <= NR; i++) {
            if (f[i] != last) {
                last = f[i]
                summary = (hit[f[i]] + 0) " of " tot[f[i]] " hit"
                if (th[f[i]]) summary = summary ", " th[f[i]] " thin"
                printf "\n  %scovers %s %s%s  %s%s%s\n", cyn, dot, f[i], off, \
                    (hit[f[i]] == tot[f[i]] ? grn : red), summary, off
                printf "  %s%8s  %-5s  %-*s  %s%s\n", dim, "hits", "", w, "cover", "condition", off
            }
            n = h[i]
            if (n == 0)         c = red
            else if (n < thin)  c = yel
            else                c = grn
            num = (n == 0) ? "never" : commas(n)
            cond = cd[i]
            name = nm[i]
            if (length(name) > w) name = substr(name, 1, w - 1) "~"
            if (!full && length(cond) > cw) cond = substr(cond, 1, cw - 3) "..."
            printf "  %s%8s%s  %s%s%s  %s%-*s%s  %s", c, num, off, c, activity(n), off, \
                (n == 0 ? red : bld), w, name, off, (n == 0 ? red : dim)
            if (full) {
                first = 1
                while (length(cond) > 0) {
                    if (!first) printf "\n  %*s", w + 19, ""
                    printf "%s", substr(cond, 1, cw); cond = substr(cond, cw + 1); first = 0
                }
            } else printf "%s", cond
            printf "%s\n", off
        }
        printf "\n  %s%s>= %d hits   %s%s1-%d thinly exercised   %s%snever hit%s\n", \
            grn, fullc, thin, yel, fullc, thin - 1, red, emptyc, off
    }' "$DIR/covers.tsv"
}

case $MODE in
    parse) parse ;;
    table) table ;;
    *)     echo "usage: covers.sh parse|table <build_dir> [full]" >&2; exit 2 ;;
esac
