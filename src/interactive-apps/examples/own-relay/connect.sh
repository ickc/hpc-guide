#!/bin/bash
# Laptop side. Once the job is running:
#     RELAY_HOST=me@my-server ./connect.sh
# then open http://localhost:8888 (or LOCAL_PORT). Ctrl-C to disconnect.
# Uses the same RELAY_PORT as the job (default 8888).
set -euo pipefail
RELAY_HOST="${RELAY_HOST:?set RELAY_HOST=user@host of your relay}"
RELAY_PORT="${RELAY_PORT:-8888}"
LOCAL_PORT="${LOCAL_PORT:-8888}"

echo "Open http://localhost:$LOCAL_PORT  (Ctrl-C to disconnect)"
exec ssh -N -o ExitOnForwardFailure=yes -L "$LOCAL_PORT:127.0.0.1:$RELAY_PORT" "$RELAY_HOST"
