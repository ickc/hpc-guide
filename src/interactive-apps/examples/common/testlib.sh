# Sourced by each example's test.sh. Runs on a login node.
#
# A test exits 0 when the method works, 1 when it does not, and 77 when it
# cannot run here (a missing prerequisite rather than a failure).
#
# Slurm options (account, partition, ...) are taken from the usual SBATCH_*
# and SLURM_* environment variables, so nothing site specific lives in here.

set -euo pipefail

SKIP=77
EXAMPLE_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
SESSIONS="$HOME/.interactive-apps"
# How long a job may wait in the queue before the test gives up.
QUEUE_TIMEOUT="${QUEUE_TIMEOUT:-900}"
export SBATCH_TIMELIMIT="${SBATCH_TIMELIMIT:-00:10:00}"

mkdir -p "$SESSIONS"
chmod 700 "$SESSIONS"
# Job logs go to the shared home rather than the example directory, since the
# compute node writes them.
WORK="$(mktemp -d "$SESSIONS/test.XXXXXX")"

JOBS=()
PIDS=()
cleanup() {
    local rc=$?
    local pid jid
    for pid in ${PIDS[@]+"${PIDS[@]}"}; do kill "$pid" 2>/dev/null || true; done
    for jid in ${JOBS[@]+"${JOBS[@]}"}; do
        scancel "$jid" 2>/dev/null || true
        rm -rf "${SESSIONS:?}/$jid"
    done
    if [[ $rc -eq 0 || $rc -eq $SKIP ]]; then rm -rf "$WORK"; else echo "logs kept in $WORK" >&2; fi
}
trap cleanup EXIT

log() { echo ">> $*" >&2; }
fail() {
    echo "FAIL: $*" >&2
    exit 1
}
skip() {
    echo "SKIP: $*" >&2
    exit "$SKIP"
}

# submit [sbatch options] script [args]: submit from the example directory and
# set JID. Not meant for $(...), which would lose JOBS to a subshell.
submit() {
    JID="$(cd "$EXAMPLE_DIR" && sbatch --parsable --output="$WORK/%j.out" "$@")"
    JID="${JID%%;*}"
    JOBS+=("$JID")
    log "submitted job $JID"
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

wait_running() {
    retry "$QUEUE_TIMEOUT" job_running "$1" || fail "job $1 did not start within ${QUEUE_TIMEOUT}s"
    log "job $1 is running"
}

# wait_ready JOBID: wait until the job has published its session info, and
# load it into this shell.
wait_ready() {
    wait_running "$1"
    retry 120 test -f "$SESSIONS/$1/info.env" || fail "job $1 published no session info; see $WORK/$1.out"
    # shellcheck disable=SC1090
    source "$SESSIONS/$1/info.env"
}

# background command...: run it for the rest of the test.
background() {
    "$@" >"$WORK/background.${#PIDS[@]}.log" 2>&1 &
    PIDS+=($!)
}

# expect_page URL [curl options]: the demo app answered with its success page.
expect_page() {
    local url="$1"
    shift
    curl -fsS --max-time 10 "$@" "$url" 2>/dev/null | grep -q 'It works'
}
