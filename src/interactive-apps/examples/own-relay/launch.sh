#!/bin/bash
#SBATCH --job-name=own-relay
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=01:00:00
# Cluster side. Submit from this directory, naming your relay:
#     RELAY_HOST=me@my-server sbatch launch.sh
# then run connect.sh on your laptop.
#
# The app listens on loopback. The job connects out to your relay with ssh -R,
# which makes the app appear on the relay's own loopback at RELAY_PORT.
#
# RELAY_HOST  user@host of your relay (required)
# RELAY_SSH   extra ssh options, e.g. "-p 443 -i ~/.ssh/id_relay"
# RELAY_PORT  port the app appears on, on the relay's loopback (default 8888)
set -euo pipefail
RELAY_HOST="${RELAY_HOST:?set RELAY_HOST=user@host of your relay}"
RELAY_PORT="${RELAY_PORT:-8888}"

SESSION="$HOME/.interactive-apps/$SLURM_JOB_ID"
mkdir -p "$SESSION"
chmod 700 "$HOME/.interactive-apps" "$SESSION"
trap 'rm -rf "$SESSION"' EXIT
APP_PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"

# Written aside and moved into place, so connect.sh never reads half of it.
cat >"$SESSION/info.env.tmp" <<INFO
JOBID=$SLURM_JOB_ID
RELAY_HOST=$RELAY_HOST
RELAY_PORT=$RELAY_PORT
INFO
mv "$SESSION/info.env.tmp" "$SESSION/info.env"

# --- your app, bound to 127.0.0.1:$APP_PORT --------------------------------
python3 "${DEMO_APP:-$SLURM_SUBMIT_DIR/../common/demo_app.py}" --host 127.0.0.1 --port "$APP_PORT" &
# ----------------------------------------------------------------------------

# BatchMode: a job cannot answer a password or passphrase prompt, so the key
# must work unattended. accept-new: trust the relay's host key the first time.
# shellcheck disable=SC2086
ssh -N ${RELAY_SSH:-} \
    -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
    -R "127.0.0.1:$RELAY_PORT:127.0.0.1:$APP_PORT" \
    "$RELAY_HOST"
