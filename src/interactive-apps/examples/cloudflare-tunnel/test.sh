#!/usr/bin/env bash
# Launch the demo app behind a Cloudflare quick tunnel and fetch it through
# Cloudflare, as a browser anywhere on the internet would.
source "$(dirname "$0")/../common/testlib.sh"

submit launch.sh
wait_ready "$JID"
# A new trycloudflare.com name can take a little while to resolve.
retry 120 expect_page "$URL/?token=$APP_TOKEN" || fail "no page through $URL"
log "page served through $URL"
