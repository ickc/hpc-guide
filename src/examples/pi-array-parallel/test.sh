#!/usr/bin/env bash
# An array of 2 tasks, each a whole node running its 32 tasks with GNU parallel,
# and the reduce job that waits for both.
source "$(dirname "$0")/../common/testlib.sh"

conda_env ../pi/environment.yml
submit job.sh
ARRAY="$JID"
at_exit "rm -rf '$EXAMPLE_DIR/results'"
batch --dependency=afterok:"$ARRAY" ../pi-array/reduce.sh
expect_output '^pi = 3\.141[0-9]+ from 4294967296 samples$'
