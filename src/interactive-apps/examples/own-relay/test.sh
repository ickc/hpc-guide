#!/usr/bin/env bash
# Launch the demo app, let the job connect out to your relay, and fetch the page
# on the relay itself. Needs RELAY_HOST (and RELAY_SSH if you use it) set, and
# the login node able to ssh to the relay without a prompt.
source "$(dirname "$0")/../common/testlib.sh"
[[ -n ${RELAY_HOST:-} ]] || skip "set RELAY_HOST to a relay you control"
export RELAY_HOST RELAY_PORT="${RELAY_PORT:-$((20000 + RANDOM % 20000))}"

submit launch.sh
wait_ready "$JID"
# shellcheck disable=SC2086
on_relay() { ssh ${RELAY_SSH:-} -o BatchMode=yes "$RELAY_HOST" "$@"; }
retry 60 on_relay "curl -fsS --max-time 10 http://127.0.0.1:$RELAY_PORT/ | grep -q 'It works'" ||
    fail "no page on $RELAY_HOST:$RELAY_PORT"
log "page served on $RELAY_HOST, 127.0.0.1:$RELAY_PORT"
