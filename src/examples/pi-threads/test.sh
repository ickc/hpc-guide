#!/usr/bin/env bash
# One process with 8 threads, on the 8 CPUs it asked for, kept busy.
source "$(dirname "$0")/../common/testlib.sh"

conda_env ../pi/environment.yml
batch job.sh
expect_output '^8 threads, on 8 CPUs: '
expect_output '^pi = 3\.141[0-9]+ from 4294967296 samples$'
