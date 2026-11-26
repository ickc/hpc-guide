#!/bin/bash
# Laptop side. Once the job is running:
#     LOGIN_HOST=<your login node> ./connect.sh <JOBID>
# then open the URL it prints. Ctrl-C to disconnect.
#
# It reads the relay, its port and the app's token from the login node, and
# tunnels to the relay. Set RELAY_HOST if your laptop knows the relay by
# another name than the job does.
set -euo pipefail
JOBID="${1:?usage: connect.sh JOBID}"
LOGIN_HOST="${LOGIN_HOST:?set LOGIN_HOST to the login node, as you would name it after ssh}"
LOCAL_PORT="${LOCAL_PORT:-8888}"
relay="${RELAY_HOST-}"

eval "$(ssh -o BatchMode=yes "$LOGIN_HOST" "cat ~/.interactive-apps/$JOBID/info.env")"
RELAY_HOST="${relay:-$RELAY_HOST}"

echo "Open http://localhost:$LOCAL_PORT/?token=$APP_TOKEN  (Ctrl-C to disconnect)"
exec ssh -N -o ExitOnForwardFailure=yes -L "$LOCAL_PORT:127.0.0.1:$RELAY_PORT" "$RELAY_HOST"
