#!/usr/bin/env bash
# The 64 tasks on 7 worker ranks over 2 nodes, with mpi4py.futures and with map_parallel.
source "$(dirname "$0")/../common/testlib.sh"

command -v mamba >/dev/null || skip "no mamba here: install miniforge first"
bash -lc 'module is-avail PrgEnv-gnu' >/dev/null 2>&1 || skip "no PrgEnv-gnu module: this example is for a Cray system"

log "creating the environment"
mamba env create -y --channel-priority flexible -p "$WORK/env" -f "$EXAMPLE_DIR/../pi/environment-mpi.yml" >"$WORK/create.log" 2>&1 ||
    fail "could not create the environment; see $WORK/create.log"
export CONDA_ENV="$WORK/env"

batch job.sh
expect_output '^7 workers$'
[[ $(grep -Ec ': [0-9]+ tasks$' "$OUT") -eq 2 ]] || fail "expected the tasks to run on 2 nodes; see $OUT"
expect_output '^pi = 3\.141[0-9]+ from 4294967296 samples$'

batch job.sh pi_map_parallel_mpi.py
expect_output '^pi = 3\.141[0-9]+ from 4294967296 samples$'
