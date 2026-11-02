#!/bin/bash
#SBATCH --job-name=dev-tunnel
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=01:00:00
# Cluster side, after setup.sh. Submit from this directory:
#     sbatch launch.sh
# then run connect.sh on your laptop, or read the URL from the job's output.
#
# The app listens on loopback. devtunnel connects out to Microsoft's relay and
# serves it at an https://....devtunnels.ms URL that only your account can open.
set -euo pipefail
DEVTUNNEL="${DEVTUNNEL:-$(command -v devtunnel || echo "$HOME/.local/bin/devtunnel")}"

SESSION="$HOME/.interactive-apps/$SLURM_JOB_ID"
mkdir -p "$SESSION"
chmod 700 "$HOME/.interactive-apps" "$SESSION"
APP_PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"

# --- your app, bound to 127.0.0.1:$APP_PORT --------------------------------
python3 "${DEMO_APP:-$SLURM_SUBMIT_DIR/../common/demo_app.py}" --host 127.0.0.1 --port "$APP_PORT" &
# ----------------------------------------------------------------------------

# Without --allow-anonymous, the tunnel only lets in the account that made it.
# It is registered with the relay until it expires, so keep that short, and
# delete it when the job ends normally.
"$DEVTUNNEL" host -p "$APP_PORT" --protocol http --expiration 1d >"$SESSION/devtunnel.log" 2>&1 &
trap '"$DEVTUNNEL" delete "${TUNNEL_ID:-}" -f >/dev/null 2>&1; rm -rf "$SESSION"' EXIT
until grep -q '^Ready to accept connections' "$SESSION/devtunnel.log"; do sleep 1; done
TUNNEL_ID="$(sed -n 's/^Ready to accept connections for tunnel: //p' "$SESSION/devtunnel.log")"
URL="$(sed -n 's/^Connect via browser: //p' "$SESSION/devtunnel.log")"

# Written aside and moved into place, so connect.sh never reads half of it.
cat >"$SESSION/info.env.tmp" <<INFO
JOBID=$SLURM_JOB_ID
TUNNEL_ID=$TUNNEL_ID
URL=$URL
INFO
mv "$SESSION/info.env.tmp" "$SESSION/info.env"
echo "open $URL"
wait
