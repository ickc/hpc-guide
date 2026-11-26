#!/usr/bin/env bash
# Build the OSU benchmarks against the vendor's MPI with Spack, and measure the latency between 2 nodes.
source "$(dirname "$0")/../common/testlib.sh"

[[ -n ${SPACK_ROOT:-} ]] || skip "no Spack here: source its setup-env.sh first"
# The prefixes of this system's Cray MPICH, PMI and libfabric, from the programming environment.
read -r MPICH PMI FABRIC < <(bash -lc 'module reset >/dev/null 2>&1; module load PrgEnv-gnu >/dev/null 2>&1
    echo "${MPICH_DIR:--} $(pkg-config --variable=prefix cray-pmi 2>/dev/null || echo -) $(pkg-config --variable=prefix libfabric 2>/dev/null || echo -)"')
[[ $MPICH != - && $PMI != - && $FABRIC != - ]] || skip "no Cray programming environment: this example is for a Cray EX system"
source "$SPACK_ROOT/share/spack/setup-env.sh"

mkdir -p "$WORK/env"
sed -e "s|/path/to/cray-mpich|$MPICH|" -e "s|/path/to/cray-pmi|$PMI|" -e "s|/path/to/libfabric|$FABRIC|" \
    "$EXAMPLE_DIR/spack.yaml" >"$WORK/env/spack.yaml"
log "building the environment"
spack -e "$WORK/env" install -j 8 >"$WORK/install.log" 2>&1 ||
    fail "could not build the environment; see $WORK/install.log"
export SPACK_ENV_DIR="$WORK/env"

batch job.sh
# osu_latency refuses to run unless it is in a world of exactly 2 ranks.
expect_output '^# OSU MPI Latency Test'
expect_output '^1 +[0-9.]+$'
