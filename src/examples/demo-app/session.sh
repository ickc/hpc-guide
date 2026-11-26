# shellcheck shell=bash
# Sourced after ../common/testlib.sh by the tests of the examples in the part
# "Working interactively", whose jobs serve demo_app.py (here) as a stand-in for
# JupyterLab or RStudio.

# Their jobs write what the laptop side needs (ports, tokens, keys) to a
# directory of their own under here.
SESSIONS="$HOME/.interactive-apps"

# wait_ready JOBID: wait until the job is running and has written its session
# details, load them into this shell, and remove them when the test ends.
wait_ready() {
    wait_running "$1"
    at_exit "rm -rf '$SESSIONS/$1'"
    retry 120 test -f "$SESSIONS/$1/info.env" || fail "job $1 wrote no session details; see $WORK/$1.out"
    # shellcheck disable=SC1090
    source "$SESSIONS/$1/info.env"
}

# expect_page URL [curl options]: the demo app answered with its page, which it
# does only when given the right token.
expect_page() {
    local url="$1"
    shift
    curl -fsS --max-time 10 "$@" "$url" 2>/dev/null | grep -q 'It works'
}
