#!/usr/bin/env bash
# Build mpi4py against the vendor's MPI, and check that it forms one world over 2 nodes.
source "$(dirname "$0")/../common/testlib.sh"

command -v conda >/dev/null || skip "no conda here: install miniforge first"
bash -lc 'module is-avail PrgEnv-gnu' >/dev/null 2>&1 || skip "no PrgEnv-gnu module: this example is for a Cray system"

log "creating the environment"
CONDA_ALWAYS_YES=true conda env create -q -p "$WORK/env" -f "$EXAMPLE_DIR/environment.yml" >"$WORK/create.log" 2>&1 ||
    fail "could not create the environment; see $WORK/create.log"
export CONDA_ENV="$WORK/env"

log "building mpi4py"
bash -l "$EXAMPLE_DIR/install.sh" >"$WORK/install.log" 2>&1 ||
    fail "could not build mpi4py; see $WORK/install.log"

batch job.sh
expect_output '^MPI library: .*CRAY MPICH'
expect_output '^nodes in world: 2$'
expect_output '^RESULT: PASS'
