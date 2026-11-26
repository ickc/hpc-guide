#!/usr/bin/env bash
# Create the environment with conda-forge's Open MPI, and check that its mpirun forms one world over 2 nodes.
source "$(dirname "$0")/../common/testlib.sh"

command -v conda >/dev/null || skip "no conda here: install miniforge first"

log "creating the environment"
CONDA_ALWAYS_YES=true conda env create -q -p "$WORK/env" -f "$EXAMPLE_DIR/environment.yml" >"$WORK/create.log" 2>&1 ||
    fail "could not create the environment; see $WORK/create.log"
export CONDA_ENV="$WORK/env"

batch job.sh
expect_output '^MPI library: Open MPI'
expect_output '^nodes in world: 2$'
expect_output '^RESULT: PASS'
