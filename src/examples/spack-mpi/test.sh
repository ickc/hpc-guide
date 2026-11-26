#!/usr/bin/env bash
# Build the OSU benchmarks against the vendor's MPI with Spack, and measure the latency between 2 nodes.
source "$(dirname "$0")/../common/testlib.sh"

[[ -n ${SPACK_ROOT:-} ]] || skip "no Spack here: source its setup-env.sh first"
[[ -d /opt/cray/pe/mpich/8.1.30 ]] || skip "no Cray MPICH 8.1.30: this example is for a Cray EX system"
source "$SPACK_ROOT/share/spack/setup-env.sh"

mkdir -p "$WORK/env"
cp "$EXAMPLE_DIR/spack.yaml" "$WORK/env/"
log "building the environment"
spack -e "$WORK/env" install -j 8 >"$WORK/install.log" 2>&1 ||
    fail "could not build the environment; see $WORK/install.log"
export SPACK_ENV_DIR="$WORK/env"

batch job.sh
# osu_latency refuses to run unless it is in a world of exactly 2 ranks.
expect_output '^# OSU MPI Latency Test'
expect_output '^1 +[0-9.]+$'
