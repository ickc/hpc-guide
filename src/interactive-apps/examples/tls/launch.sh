#!/bin/bash
#SBATCH --job-name=tls
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=01:00:00
# Cluster side. Submit from this directory:
#     sbatch launch.sh
# then run connect.sh on your laptop.
#
# The app listens on loopback; tls_proxy.py serves it over HTTPS on an address
# the login node can reach. Anyone on the cluster can connect to that port, so
# the app's own token is what keeps them out, and TLS keeps the token secret.
set -euo pipefail

SESSION="$HOME/.interactive-apps/$SLURM_JOB_ID"
mkdir -p "$SESSION"
chmod 700 "$HOME/.interactive-apps" "$SESSION"
trap 'rm -rf "$SESSION"' EXIT

# The address other nodes know this one by. Set LISTEN_IP if your cluster wants
# a different network (e.g. the high-speed one) for traffic from the login node.
LISTEN_IP="${LISTEN_IP:-$(getent hosts "$(hostname)" | awk '{print $1; exit}')}"
free_port() { python3 -c 'import socket; s = socket.socket(); s.bind(("", 0)); print(s.getsockname()[1])'; }
APP_PORT="$(free_port)"
TLS_PORT="$(free_port)"

# A self-signed certificate for this job only. You check its fingerprint once
# instead of trusting a certificate authority.
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 2 \
    -keyout "$SESSION/key.pem" -out "$SESSION/cert.pem" -subj "/CN=$(hostname)" \
    -addext "subjectAltName=DNS:$(hostname),DNS:localhost,IP:127.0.0.1,IP:$LISTEN_IP" 2>/dev/null
FINGERPRINT="$(openssl x509 -in "$SESSION/cert.pem" -noout -fingerprint -sha256 | cut -d= -f2)"

# A strong token. The demo app reads APP_TOKEN; Jupyter makes its own.
export APP_TOKEN="$(openssl rand -hex 24)"

cat >"$SESSION/info.env" <<INFO
JOBID=$SLURM_JOB_ID
LISTEN_IP=$LISTEN_IP
TLS_PORT=$TLS_PORT
APP_TOKEN=$APP_TOKEN
FINGERPRINT=$FINGERPRINT
SESSION=$SESSION
INFO

echo "https://$LISTEN_IP:$TLS_PORT, certificate SHA-256 $FINGERPRINT"
echo "now run on your laptop: ./connect.sh $SLURM_JOB_ID"

# --- your app, bound to 127.0.0.1:$APP_PORT --------------------------------
python3 "${DEMO_APP:-$SLURM_SUBMIT_DIR/../common/demo_app.py}" --host 127.0.0.1 --port "$APP_PORT" &
# ----------------------------------------------------------------------------
python3 "$SLURM_SUBMIT_DIR/tls_proxy.py" --listen "$LISTEN_IP:$TLS_PORT" --backend "127.0.0.1:$APP_PORT" \
    --cert "$SESSION/cert.pem" --key "$SESSION/key.pem"
