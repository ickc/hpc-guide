#!/usr/bin/env bash
# Make the certificate and the token as the page does, run JupyterLab with them
# in a job, and fetch its status from the login node over HTTPS, trusting only
# that certificate. The certificate is for localhost, as the browser sees it
# through the laptop's tunnel, so curl is told that localhost:28417 is the
# node's port 28417, which is where the tunnel goes.
#
# It uses a home directory of its own, so your own ~/.jupyter-tls is left alone.
# The port is the page's fixed one, so the job fails if another job on the
# same node has it.
source "$(dirname "$0")/../common/testlib.sh"
command -v openssl >/dev/null || skip "openssl is needed to make the certificate"
conda_env environment.yml

export HOME="$WORK/home"
mkdir -p "$HOME"
bash "$EXAMPLE_DIR/setup.sh" >"$WORK/setup.log" 2>&1 || fail "setup.sh failed; see $WORK/setup.log"
TOKEN="$(cat "$HOME/.jupyter-tls/token")"

PATH="$CONDA_ENV/bin:$PATH" submit job.sh
wait_running "$JID"
NODE="$(squeue -h -j "$JID" -o %N)"

status() {
    curl -fsS --max-time 10 --cacert "$HOME/.jupyter-tls/cert.pem" \
        --connect-to "localhost:28417:$NODE:28417" \
        "https://localhost:28417/api/status?token=$TOKEN" | grep -q '"started"'
}
retry 120 status || fail "no answer over HTTPS from $NODE:28417; see $OUT"
log "JupyterLab answered over HTTPS from $NODE:28417"
