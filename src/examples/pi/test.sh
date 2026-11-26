#!/usr/bin/env bash
# The serial baseline: every task on one core, and the estimate of π they add up to.
source "$(dirname "$0")/../common/testlib.sh"

conda_env environment.yml
batch job.sh
expect_output '^pi = 3\.141[0-9]+ from 4294967296 samples$'
