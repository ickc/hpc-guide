#!/bin/bash
# Laptop side. After `sbatch launch.sh` on the cluster:
#     LOGIN_HOST=<your login node> ./connect.sh <JOBID>
# Ctrl-C to disconnect.
#
# This is the usual `ssh -L` tunnel. The only additions are fetching the
# certificate, so you can check it, and printing the URL with the token.
set -euo pipefail
JOBID="${1:?usage: connect.sh JOBID}"
LOGIN_HOST="${LOGIN_HOST:?set LOGIN_HOST to the login node, as you would name it after ssh}"
LOCAL_PORT="${LOCAL_PORT:-8443}"

INFO="$(ssh -o BatchMode=yes "$LOGIN_HOST" "cat ~/.interactive-apps/$JOBID/info.env")"
eval "$INFO"
CERT="cert-$JOBID.pem"
ssh -o BatchMode=yes "$LOGIN_HOST" "cat $SESSION/cert.pem" >"$CERT"

cat <<MSG
Open   https://localhost:$LOCAL_PORT/?token=$APP_TOKEN
Your browser will warn that the certificate is self-signed. Accept it only if
its SHA-256 fingerprint is
       $FINGERPRINT
(the certificate is also saved as $CERT). Ctrl-C to disconnect.
MSG
exec ssh -N -o ExitOnForwardFailure=yes -L "$LOCAL_PORT:$LISTEN_IP:$TLS_PORT" "$LOGIN_HOST"
