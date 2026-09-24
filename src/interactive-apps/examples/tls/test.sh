#!/usr/bin/env bash
# Launch the demo app behind the TLS proxy and fetch it from the login node,
# trusting only the job's own certificate. That is the hop the laptop's
# `ssh -L` hands over to; the laptop-to-login part is plain SSH.
source "$(dirname "$0")/../common/testlib.sh"
command -v openssl >/dev/null || skip "openssl is needed to make the certificate"

submit launch.sh
wait_ready "$JID"

URL="https://$LISTEN_IP:$TLS_PORT/?token=$APP_TOKEN"
retry 60 expect_page "$URL" --cacert "$SESSION/cert.pem" || fail "no page over TLS from $LISTEN_IP:$TLS_PORT"
log "page served over TLS from $LISTEN_IP:$TLS_PORT"
