#!/bin/bash
#SBATCH --job-name=stage-local
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:05:00
#SBATCH --signal=B:USR1@60
set -euo pipefail

# On the shared filesystem: the inputs, packed into one file, and where the results go.
INPUT="${INPUT:-$SLURM_SUBMIT_DIR/inputs.tar}"
RESULTS="${RESULTS:-$SLURM_SUBMIT_DIR/results}"
# Node-local storage: $LOCALDIR if the centre sets it, else $TMPDIR, else /tmp.
LOCAL="${LOCALDIR:-${TMPDIR:-/tmp}}/stage-local.$SLURM_JOB_ID"

stage_out() {
    mkdir -p "$RESULTS"
    tar -cf "$RESULTS/$SLURM_JOB_ID.tar" -C "$LOCAL" out
    echo "staged out $(find "$LOCAL/out" -type f | wc -l) files to $RESULTS/$SLURM_JOB_ID.tar"
    rm -rf "$LOCAL"
}
trap stage_out EXIT
trap 'echo "stopping early, on a signal"; kill "${pid:-}" 2>/dev/null || true; exit 1' USR1 TERM

# Stage in: one file read from the shared filesystem, unpacked on the node.
mkdir -p "$LOCAL/out"
tar -xf "$INPUT" -C "$LOCAL"
echo "staged in $(find "$LOCAL/in" -type f | wc -l) files on $(hostname) in $LOCAL"

# The work, reading and writing only node-local files.
python3 "$SLURM_SUBMIT_DIR/work.py" "$LOCAL/in" "$LOCAL/out" &
pid=$!
wait "$pid"
