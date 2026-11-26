#!/usr/bin/env bash
# One Python process hands the 64 tasks to a pool of 8 worker processes.
source "$(dirname "$0")/../common/testlib.sh"

conda_env ../pi/environment.yml
batch job.sh
expect_output '^pi = 3\.141[0-9]+ from 4294967296 samples$'
