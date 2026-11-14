#!/usr/bin/env bash
#
# Filename:         soak_verdict.sh
#
# File Description: The verdict on a finished soak, for sim/Makefile's soak
#                   targets: counts the PASS and FAIL lines of the suite's
#                   soak/results.txt, prints one line, lists every failing run
#                   with its seed, and exits 1 if any run failed or none
#                   passed. A suite's soak never stops on a failure, so this
#                   is where a failing seed turns the target red.
#
#                   Usage: soak_verdict.sh <results.txt>
#
# Global variables: None

results=$1
SCRIPTS_DIR=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=ui.sh
source "$SCRIPTS_DIR/ui.sh"

if [[ ! -f $results ]]; then
    echo "soak verdict: no $results - the soak did not finish"
    exit 1
fi

passed=$(grep -c ': PASS' "$results")
failed=$(grep -c ': FAIL' "$results")

if [[ $failed -eq 0 && $passed -gt 0 ]]; then
    echo "$(ui_badge PASS) soak: $passed of $passed runs passed - $results"
    exit 0
fi

echo "$(ui_badge FAIL) soak: $failed of $((passed + failed)) runs failed - $results"
grep ': FAIL' "$results" | sed 's/^/  /'
echo "  replay one in the suite's folder: make replay SEED=<seed> EVENTS=<events>"
exit 1
