# shellcheck shell=bash
# Sourced by each example's test.sh, which runs on a login node.
#
# A test exits 0 when the example works, 1 when it does not, and 77 when it
# cannot run here (a missing prerequisite rather than a failure).
#
# Slurm options (account, partition, ...) are taken from the usual SBATCH_*
# and SLURM_* environment variables, so nothing site specific lives in here.

set -euo pipefail

SKIP=77
EXAMPLE_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
# How long a job may wait in the queue before the test gives up.
QUEUE_TIMEOUT="${QUEUE_TIMEOUT:-900}"
export SBATCH_TIMELIMIT="${SBATCH_TIMELIMIT:-00:10:00}"

log() { echo ">> $*" >&2; }
fail() {
    echo "FAIL: $*" >&2
    exit 1
}
skip() {
    echo "SKIP: $*" >&2
    exit "$SKIP"
}

command -v sbatch >/dev/null || skip "no Slurm here: run this on a login node"

# Job output goes to a directory under the (shared) home rather than the example
# directory or /tmp, since a compute node writes it and may not see either.
mkdir -p "$HOME/.cache/hpc-guide-examples"
WORK="$(mktemp -d "$HOME/.cache/hpc-guide-examples/test.XXXXXX")"

JOBS=()
PIDS=()
AT_EXIT=()
# at_exit COMMAND: run it when the test ends, before the jobs are cancelled.
at_exit() { AT_EXIT+=("$1"); }
cleanup() {
    local rc=$?
    local cmd pid jid
    for cmd in ${AT_EXIT[@]+"${AT_EXIT[@]}"}; do eval "$cmd" || true; done
    for pid in ${PIDS[@]+"${PIDS[@]}"}; do kill "$pid" 2>/dev/null || true; done
    for jid in ${JOBS[@]+"${JOBS[@]}"}; do scancel "$jid" 2>/dev/null || true; done
    if [[ $rc -eq 0 || $rc -eq $SKIP ]]; then rm -rf "$WORK"; else echo "logs kept in $WORK" >&2; fi
}
trap cleanup EXIT

# submit [sbatch options] script [args]: submit from the example directory and
# set JID without waiting. Not meant for $(...), which would lose JOBS to a subshell.
submit() {
    JID="$(cd "$EXAMPLE_DIR" && sbatch --parsable --output="$WORK/%j.out" "$@")"
    JID="${JID%%;*}"
    JOBS+=("$JID")
    OUT="$WORK/$JID.out"
    log "submitted job $JID"
}

# batch [sbatch options] script [args]: submit, wait for the job to finish, and
# fail unless it exited 0. Sets JID and OUT, the file holding the job's output.
batch() {
    local pending
    pending="$WORK/sbatch.log"
    JID=""
    (cd "$EXAMPLE_DIR" && timeout "$((QUEUE_TIMEOUT + 600))" sbatch --wait --parsable --output="$WORK/%j.out" "$@") >"$pending" || {
        JID="$(head -n1 "$pending")"
        JID="${JID%%;*}"
        fail "the job failed or timed out; see $WORK/${JID}.out"
    }
    JID="$(head -n1 "$pending")"
    JID="${JID%%;*}"
    OUT="$WORK/$JID.out"
    log "job $JID finished"
}

# expect_output REGEX: the job's output has a line matching the extended regex.
expect_output() {
    grep -Eq "$1" "$OUT" || fail "no line matching '$1' in the output of job $JID ($OUT)"
}

# retry SECONDS command...: rerun the command every 2 seconds until it succeeds.
retry() {
    local deadline=$((SECONDS + $1))
    shift
    until "$@"; do
        ((SECONDS < deadline)) || return 1
        sleep 2
    done
}

job_running() {
    local state
    state="$(squeue -h -j "$1" -o %T 2>/dev/null || true)"
    [[ -n $state ]] || fail "job $1 left the queue; see $WORK/$1.out"
    [[ $state == RUNNING ]]
}

# wait_running JOBID: wait until the job is running.
wait_running() {
    retry "$QUEUE_TIMEOUT" job_running "$1" || fail "job $1 did not start within ${QUEUE_TIMEOUT}s"
    log "job $1 is running"
}

# background command...: run it for the rest of the test.
background() {
    "$@" >"$WORK/background.${#PIDS[@]}.log" 2>&1 &
    PIDS+=($!)
}

# conda_env FILE: create the environment in FILE (relative to the example
# directory) under $WORK, and export CONDA_ENV, which the jobs activate.
conda_env() {
    command -v conda >/dev/null || skip "no conda here: install miniforge first"
    log "creating the environment"
    CONDA_ALWAYS_YES=true conda env create -q -p "$WORK/env" -f "$EXAMPLE_DIR/$1" >"$WORK/create.log" 2>&1 ||
        fail "could not create the environment; see $WORK/create.log"
    export CONDA_ENV="$WORK/env"
}
