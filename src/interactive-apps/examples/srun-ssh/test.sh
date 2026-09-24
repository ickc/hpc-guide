#!/usr/bin/env bash
# Launch the demo app, connect the way a laptop would (minus the first SSH hop),
# and fetch the page through the tunnel.
source "$(dirname "$0")/../common/testlib.sh"

submit launch.sh
wait_ready "$JID"

LOCAL_PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
background env LOGIN_HOST= LOCAL_PORT="$LOCAL_PORT" "$EXAMPLE_DIR/connect.sh" "$JID"
retry 120 expect_page "http://127.0.0.1:$LOCAL_PORT/" || fail "no page through the tunnel"
log "page served through the tunnel from $NODE"
