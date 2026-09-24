#!/usr/bin/env bash
# Launch the demo app behind a dev tunnel and fetch it through Microsoft's
# relay, authenticating the way a browser would after signing in.
source "$(dirname "$0")/../common/testlib.sh"
DEVTUNNEL="${DEVTUNNEL:-$(command -v devtunnel || echo "$HOME/.local/bin/devtunnel")}"
export DEVTUNNEL
[[ -x $DEVTUNNEL ]] || skip "devtunnel is not installed; run setup.sh"
"$DEVTUNNEL" user show >/dev/null 2>&1 || skip "devtunnel is not signed in; run setup.sh"

submit launch.sh
wait_ready "$JID"
# The job deletes its tunnel only if it ends by itself, which a test's does not.
# shellcheck disable=SC2016 # expanded when it runs
at_exit '"$DEVTUNNEL" delete "$TUNNEL_ID" -f >/dev/null 2>&1'

TOKEN="$("$DEVTUNNEL" token "$TUNNEL_ID" --scopes connect | sed -n 's/^Token: //p')"
retry 60 expect_page "$URL/" -H "X-Tunnel-Authorization: tunnel $TOKEN" || fail "no page through $URL"
log "page served through $URL"
