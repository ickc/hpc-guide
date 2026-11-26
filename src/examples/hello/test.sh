#!/usr/bin/env bash
# Run the script as a batch job and check that it reports a host and its own job ID.
source "$(dirname "$0")/../common/testlib.sh"

batch job.sh
expect_output "^Hello from [^ ,]+, job $JID\$"
