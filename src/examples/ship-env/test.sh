#!/usr/bin/env bash
# Create the environment, pack it with conda-pack, and run it unpacked on node-local storage.
source "$(dirname "$0")/../common/testlib.sh"

command -v conda >/dev/null || skip "no conda here: install miniforge first"

log "creating and packing the environment"
CONDA_ALWAYS_YES=true conda env create -q -p "$WORK/env" -f "$EXAMPLE_DIR/environment.yml" >"$WORK/create.log" 2>&1 ||
    fail "could not create the environment; see $WORK/create.log"
"$WORK/env/bin/conda-pack" -p "$WORK/env" -o "$WORK/shipped.tar.gz" >"$WORK/pack.log" 2>&1 ||
    fail "could not pack the environment; see $WORK/pack.log"
export TARBALL="$WORK/shipped.tar.gz"

batch job.sh
# The Python that ran is the unpacked copy, not the environment on the shared filesystem.
expect_output "^numpy [0-9.]+ from /.+/$JID/env\$"
