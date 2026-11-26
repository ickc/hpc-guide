#!/usr/bin/env bash
# The array of 64 tasks, and the reduce job that waits for all of them.
source "$(dirname "$0")/../common/testlib.sh"

conda_env ../pi/environment.yml
submit job.sh
ARRAY="$JID"
at_exit "rm -rf '$EXAMPLE_DIR/results'"
batch --dependency=afterok:"$ARRAY" reduce.sh
expect_output '^pi = 3\.141[0-9]+ from 4294967296 samples$'
