#!/usr/bin/env bash
# Create the environment with the external MPICH, and check that it forms one world over 2 nodes.
source "$(dirname "$0")/../common/testlib.sh"

command -v mamba >/dev/null || skip "no mamba here: install miniforge first"
bash -lc 'module is-avail PrgEnv-gnu' >/dev/null 2>&1 || skip "no PrgEnv-gnu module: this example is for a Cray system"

log "creating the environment"
mamba env create -y --channel-priority flexible -p "$WORK/env" -f "$EXAMPLE_DIR/environment.yml" >"$WORK/create.log" 2>&1 ||
    fail "could not create the environment; see $WORK/create.log"
export CONDA_ENV="$WORK/env"

batch job.sh
expect_output '^world size: 8$'
expect_output '^nodes in world: 2$'
expect_output '^RESULT: PASS'
