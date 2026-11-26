#!/usr/bin/env bash
# Both rounds run to the end; how much slower the second is depends on the machine.
source "$(dirname "$0")/../common/testlib.sh"

conda_env ../pi/environment.yml
batch job.sh
expect_output '^== 8 copies at once, NUM_THREADS=1$'
expect_output '^== 8 copies at once, NUM_THREADS=8$'
[[ $(grep -c '^all copies: ' "$OUT") -eq 2 ]] || fail "expected two timings in $OUT"
