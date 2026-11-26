#!/usr/bin/env bash
# 4 ranks over 2 nodes, each with 4 threads, and where each of them ran.
source "$(dirname "$0")/../common/testlib.sh"

command -v mamba >/dev/null || skip "no mamba here: install miniforge first"
bash -lc 'module is-avail PrgEnv-gnu' >/dev/null 2>&1 || skip "no PrgEnv-gnu module: this example is for a Cray system"

log "creating the environment"
mamba env create -y --channel-priority flexible -p "$WORK/env" -f "$EXAMPLE_DIR/../pi/environment-mpi.yml" >"$WORK/create.log" 2>&1 ||
    fail "could not create the environment; see $WORK/create.log"
export CONDA_ENV="$WORK/env"

batch job.sh
[[ $(grep -Ec '^rank [0-9]+ on .*: 4 threads on CPUs ' "$OUT") -eq 4 ]] || fail "expected 4 ranks of 4 threads; see $OUT"
expect_output '^pi = 3\.141[0-9]+ from 4294967296 samples$'
