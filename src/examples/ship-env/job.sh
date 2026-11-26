#!/bin/bash
#SBATCH --job-name=ship-env
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:10:00
set -eo pipefail

# The packed environment, made once by conda-pack, on the shared filesystem.
TARBALL="${TARBALL:-$HOME/envs/shipped.tar.gz}"
# Node-local storage: the job's own temporary directory, if the cluster sets one.
LOCAL="${TMPDIR:-/tmp}/$SLURM_JOB_ID"
trap 'rm -rf "$LOCAL"' EXIT

mkdir -p "$LOCAL/env"
tar -xzf "$TARBALL" -C "$LOCAL/env"
source "$LOCAL/env/bin/activate"
conda-unpack

python -c 'import numpy, sys; print(f"numpy {numpy.__version__} from {sys.prefix}")'
