#!/usr/bin/env bash
# The workflow inside one job, 64 count tasks on 8 CPUs and then the reduce,
# with Snakemake and with make.
source "$(dirname "$0")/../common/testlib.sh"

conda_env environment.yml
clean() { rm -rf "$EXAMPLE_DIR/results" "$EXAMPLE_DIR/pi.txt" "$EXAMPLE_DIR/.snakemake"; }
at_exit clean

clean
batch job.sh
expect_output '^pi = 3\.141[0-9]+ from 4294967296 samples$'

clean
batch job-make.sh
expect_output '^pi = 3\.141[0-9]+ from 4294967296 samples$'
