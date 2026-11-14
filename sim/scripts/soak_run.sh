#!/usr/bin/env bash
#
# Filename:         soak_run.sh
#
# File Description: One run of a cocotb suite's soak (host_if or pmic_top),
#                   called by the suite Makefile's soak target - several at
#                   once, so each run works in its own folder (SOAK_RAW/runN.d)
#                   on the soak's shared build. Prints one line,
#                   "run N: PASS|FAIL SEED=<seed>", where the seed is
#                   base + N so runs started together never share one. A run
#                   passes only if make succeeded and its results.xml holds a
#                   test and no failure: cocotb 1.x exits 0 when a test fails.
#
#                   Usage: soak_run.sh <run> <base_seed>
#
# Global variables: From the environment, set by the soak target:
#                   SUITE_MAKEFILE - the suite's Makefile
#                   SOAK_RAW       - absolute folder for the per-run files
#                   SIM_BUILD      - absolute shared build folder
#                   SOAK_ARGS      - the suite's random-walk make variables,
#                                    space separated (TESTCASE=..., ...)

run=$1
seed=$(( $2 + run ))
dir=$SOAK_RAW/run$run.d
# shellcheck disable=SC2153  # SOAK_ARGS comes from the soak target's environment
read -r -a soak_args <<< "$SOAK_ARGS"

# a run is its own make, not part of the soak's jobserver
unset MAKEFLAGS MFLAGS MAKELEVEL

if ! mkdir -p "$dir" || ! cd "$dir"; then
    echo "run $run: FAIL SEED=$seed (no run folder)"
    exit 0
fi
rm -f results.xml coverage.dat

if make --no-print-directory -f "$SUITE_MAKEFILE" "${soak_args[@]}" \
        RANDOM_SEED="$seed" SIM_BUILD="$SIM_BUILD" \
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
