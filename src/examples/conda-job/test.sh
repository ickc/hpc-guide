#!/usr/bin/env bash
# Create the environment, then run it both ways: activated in the job, and
# activated on the login node and inherited through the heredoc.
source "$(dirname "$0")/../common/testlib.sh"

command -v conda >/dev/null || skip "no conda here: install miniforge first"

log "creating the environment"
CONDA_ALWAYS_YES=true conda env create -q -p "$WORK/env" -f "$EXAMPLE_DIR/environment.yml" >"$WORK/create.log" 2>&1 ||
    fail "could not create the environment; see $WORK/create.log"
export CONDA_ENV="$WORK/env"

batch job.sh
expect_output "^numpy [0-9.]+ from $CONDA_ENV\$"

JID="$(cd "$EXAMPLE_DIR" && timeout "$((QUEUE_TIMEOUT + 600))" ./submit.sh --wait --parsable --output="$WORK/%j.out")" ||
    fail "the heredoc job failed or timed out"
JID="${JID%%;*}"
OUT="$WORK/$JID.out"
log "job $JID finished"
expect_output "^numpy [0-9.]+ from $CONDA_ENV\$"
