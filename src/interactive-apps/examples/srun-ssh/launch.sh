#!/bin/bash
#SBATCH --job-name=srun-ssh
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=01:00:00
# Cluster side. Submit from this directory:
#     sbatch launch.sh
# then run connect.sh on your laptop.
#
# Starts the app on the compute node's loopback, where nothing else can reach
# it, and prepares a throwaway sshd for connect.sh to run over the srun pipe.
set -euo pipefail

SESSION="$HOME/.interactive-apps/$SLURM_JOB_ID"
mkdir -p "$SESSION"
chmod 700 "$HOME/.interactive-apps" "$SESSION"
# The keys only open this job, so they are useless once it ends. Tidy them up
# when the app exits; after an scancel the directory may be left behind, and
# can simply be deleted.
trap 'rm -rf "$SESSION"' EXIT
# sshd refuses to run -i unless started by absolute path.
SSHD="${SSHD:-$(command -v sshd || echo /usr/sbin/sshd)}"

# A host key and a client key made for this job alone, so nothing here touches
# your own ~/.ssh.
ssh-keygen -q -t ed25519 -N '' -f "$SESSION/host_key"
ssh-keygen -q -t ed25519 -N '' -f "$SESSION/client_key"
cp "$SESSION/client_key.pub" "$SESSION/authorized_keys"
cat >"$SESSION/sshd_config" <<CONF
HostKey $SESSION/host_key
AuthorizedKeysFile $SESSION/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowTcpForwarding yes
X11Forwarding no
StrictModes no
CONF
"$SSHD" -t -f "$SESSION/sshd_config"

# Any free port will do, since only this node's loopback can see it.
APP_PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"

# Written aside and moved into place, so connect.sh never reads half of it.
cat >"$SESSION/info.env.tmp" <<INFO
JOBID=$SLURM_JOB_ID
NODE=$(hostname)
APP_PORT=$APP_PORT
SSHD=$SSHD
SESSION=$SESSION
INFO
mv "$SESSION/info.env.tmp" "$SESSION/info.env"

echo "app on $(hostname) 127.0.0.1:$APP_PORT; now run on your laptop: ./connect.sh $SLURM_JOB_ID"

# --- your app, bound to 127.0.0.1:$APP_PORT --------------------------------
# e.g. jupyter lab --no-browser --ip=127.0.0.1 --port="$APP_PORT"
python3 "${DEMO_APP:-$SLURM_SUBMIT_DIR/../common/demo_app.py}" --host 127.0.0.1 --port "$APP_PORT"
