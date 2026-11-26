#!/usr/bin/env bash
# The check against the obvious recipe, mpi4py and MPICH from conda-forge:
# the job must fail, with each of the 8 processes in a world of its own.
# The routes that pass are tested in conda-mpich, conda-mpi4py-source and conda-openmpi.
source "$(dirname "$0")/../common/testlib.sh"

command -v conda >/dev/null || skip "no conda here: install miniforge first"

log "creating the environment"
CONDA_ALWAYS_YES=true conda env create -q -p "$WORK/env" -f "$EXAMPLE_DIR/environment.yml" >"$WORK/create.log" 2>&1 ||
    fail "could not create the environment; see $WORK/create.log"
export CONDA_ENV="$WORK/env"

(cd "$EXAMPLE_DIR" && timeout "$((QUEUE_TIMEOUT + 600))" sbatch --wait --parsable --output="$WORK/%j.out" job.sh) >"$WORK/sbatch.log" &&
    fail "the job passed, but a bundled conda MPI should not form one world under srun"
JID="$(head -n1 "$WORK/sbatch.log")"
JID="${JID%%;*}"
OUT="$WORK/$JID.out"
log "job $JID finished"
[[ $(grep -c '^world size: 1$' "$OUT") -eq 8 ]] || fail "expected 8 single-rank worlds in $OUT"
expect_output '^RESULT: FAIL'
