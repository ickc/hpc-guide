#!/usr/bin/env bash
# GNU parallel runs the 64 tasks 8 at a time, one result file each, and logs every one.
source "$(dirname "$0")/../common/testlib.sh"

conda_env ../pi/environment.yml
at_exit "rm -rf '$EXAMPLE_DIR/results' '$EXAMPLE_DIR/joblog.tsv'"
batch job.sh
expect_output '^pi = 3\.141[0-9]+ from 4294967296 samples$'
[[ $(tail -n +2 "$EXAMPLE_DIR/joblog.tsv" | wc -l) -eq 64 ]] || fail "expected 64 tasks in joblog.tsv"
