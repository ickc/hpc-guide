#!/bin/bash
#SBATCH --job-name=cloudflare-tunnel
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=01:00:00
# Cluster side. Submit from this directory:
#     sbatch launch.sh
# then run connect.sh on your laptop, or read the URL from the job's output.
#
# The app listens on loopback. cloudflared connects out to Cloudflare and serves
# it at a random https://....trycloudflare.com URL, which is PUBLIC: anyone who
# has the URL can reach the app, so the app's own token is all that keeps them out.
set -euo pipefail
CLOUDFLARED="${CLOUDFLARED:-$(command -v cloudflared || echo "$HOME/.local/bin/cloudflared")}"

SESSION="$HOME/.interactive-apps/$SLURM_JOB_ID"
mkdir -p "$SESSION"
chmod 700 "$HOME/.interactive-apps" "$SESSION"
trap 'rm -rf "$SESSION"' EXIT

if [[ ! -x $CLOUDFLARED ]]; then
    case "$(uname -m)" in
        x86_64) arch=amd64 ;;
        aarch64) arch=arm64 ;;
        *) echo "no cloudflared build for $(uname -m)" >&2 && exit 1 ;;
    esac
    mkdir -p "$(dirname "$CLOUDFLARED")"
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$arch" -o "$CLOUDFLARED"
    chmod +x "$CLOUDFLARED"
fi

APP_PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
# A strong token. The demo app reads APP_TOKEN; Jupyter makes its own.
APP_TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(24))')"
export APP_TOKEN

# --- your app, bound to 127.0.0.1:$APP_PORT --------------------------------
python3 "${DEMO_APP:-$SLURM_SUBMIT_DIR/../common/demo_app.py}" --host 127.0.0.1 --port "$APP_PORT" &
# ----------------------------------------------------------------------------

"$CLOUDFLARED" tunnel --no-autoupdate --url "http://127.0.0.1:$APP_PORT" >"$SESSION/cloudflared.log" 2>&1 &
until URL="$(grep -o 'https://[-a-z0-9]*\.trycloudflare\.com' "$SESSION/cloudflared.log")"; do sleep 1; done

cat >"$SESSION/info.env" <<INFO
JOBID=$SLURM_JOB_ID
URL=$URL
APP_TOKEN=$APP_TOKEN
INFO
echo "the URL is in $SESSION/info.env; connect.sh prints it with the token"
wait
