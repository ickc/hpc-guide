#!/bin/bash
# Laptop side. After `sbatch launch.sh` on the cluster:
#     LOGIN_HOST=<your login node> ./connect.sh <JOBID>
# There is no tunnel to hold open from here; this only looks up the URL and
# opens it. Sign in with the same account you used in setup.sh.
set -euo pipefail
JOBID="${1:?usage: connect.sh JOBID}"
LOGIN_HOST="${LOGIN_HOST:?set LOGIN_HOST to the login node, as you would name it after ssh}"

eval "$(ssh -o BatchMode=yes "$LOGIN_HOST" "cat ~/.interactive-apps/$JOBID/info.env")"
echo "$URL"
if command -v open >/dev/null; then open "$URL"; elif command -v xdg-open >/dev/null; then xdg-open "$URL"; fi
