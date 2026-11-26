#!/usr/bin/env bash
# A Dragon pool over 2 whole nodes runs the 64 tasks.
source "$(dirname "$0")/../common/testlib.sh"

conda_env environment.yml
batch job.sh
[[ $(grep -Ec ': [0-9]+ tasks$' "$OUT") -eq 2 ]] || fail "expected the tasks to run on 2 nodes; see $OUT"
expect_output '^pi = 3\.141[0-9]+ from 4294967296 samples$'
