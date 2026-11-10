#!/usr/bin/env bash
#
# Filename:         soak_run.sh
#
# File Description: One run of the pmic_top soak, called by the Makefile's
#                   soak target - several at once, so each run works in its
#                   own folder (SOAK_RAW/runN.d) on the soak's shared build.
#                   Prints one line, "run N: PASS|FAIL SEED=<seed>", where the
#                   seed is base + N so runs started together never share one.
#                   A run passes only if make succeeded and its results.xml
#                   holds a test and no failure.
#
#                   Usage: soak_run.sh <run> <base_seed>
#
# Global variables: From the environment, set by the soak target:
#                   TB_DIR, SOAK_RAW, EVENTS, CHECKERS, SIM_BUILD

run=$1
seed=$(( $2 + run ))
dir=$SOAK_RAW/run$run.d

# a run is its own make: not part of the soak's jobserver
unset MAKEFLAGS MFLAGS MAKELEVEL

mkdir -p "$dir" && cd "$dir" || { echo "run $run: FAIL SEED=$seed (no run folder)"; exit 0; }
rm -f results.xml coverage.dat

if make --no-print-directory -f "$TB_DIR/Makefile" \
        TESTCASE=random_walk RANDOM_EVENTS="$EVENTS" RANDOM_SEED="$seed" \
        CHECKERS="$CHECKERS" SIM_BUILD="$SIM_BUILD" \
        RANDOM_CSV="$SOAK_RAW/events_run$run.csv" FCOV_XML="$SOAK_RAW/fcov_run$run.xml" \
        > "$SOAK_RAW/run$run.log" 2>&1 \
   && test -f results.xml && grep -q '<testcase' results.xml \
   && ! grep -q -E '<failure|<error' results.xml; then
    status=PASS
else
    status=FAIL
fi
if [ -f coverage.dat ]; then cp coverage.dat "$SOAK_RAW/cov_run$run.dat"; fi
echo "run $run: $status SEED=$seed"
