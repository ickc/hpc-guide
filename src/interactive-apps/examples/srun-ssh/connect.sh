#!/bin/bash
# Laptop side. After `sbatch launch.sh` on the cluster:
#     LOGIN_HOST=<your login node> ./connect.sh <JOBID>
# then open http://localhost:8888 (or LOCAL_PORT). Ctrl-C to disconnect.
#
# LOGIN_HOST is whatever you type after `ssh` to reach the login node, e.g. an
# alias from ~/.ssh/config. Leave it empty to run this on the login node itself.
set -euo pipefail
JOBID="${1:?usage: connect.sh JOBID}"
LOGIN_HOST="${LOGIN_HOST-}"
LOCAL_PORT="${LOCAL_PORT:-8888}"

# on_login COMMAND: run a command on the login node.
on_login() {
    if [[ -n $LOGIN_HOST ]]; then ssh -o BatchMode=yes "$LOGIN_HOST" "$1"; else bash -c "$1"; fi
}

# Copy the session's details and keys here; they are deleted on exit.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
on_login "cat ~/.interactive-apps/$JOBID/info.env" >"$TMP/info.env"
# shellcheck disable=SC1091
source "$TMP/info.env"
on_login "cat $SESSION/client_key" >"$TMP/client_key"
chmod 600 "$TMP/client_key"
# Trust exactly the host key the job generated, and nothing else.
echo "$NODE $(on_login "cat $SESSION/host_key.pub")" >"$TMP/known_hosts"

# The transport to the node: srun starts sshd there, in inetd mode (-i), which
# speaks SSH on stdin/stdout. --unbuffered is required, or the handshake stalls.
PROXY="srun --jobid=$JOBID --overlap --unbuffered --ntasks=1 $SSHD -i -f $SESSION/sshd_config"
if [[ -n $LOGIN_HOST ]]; then PROXY="ssh -o BatchMode=yes $LOGIN_HOST '$PROXY'"; fi

echo "Open http://localhost:$LOCAL_PORT  (Ctrl-C to disconnect)"
exec ssh -N \
    -o ProxyCommand="$PROXY" \
    -o UserKnownHostsFile="$TMP/known_hosts" -o StrictHostKeyChecking=yes \
    -o IdentitiesOnly=yes -i "$TMP/client_key" \
    -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
    -L "$LOCAL_PORT:127.0.0.1:$APP_PORT" \
    "$USER@$NODE"
