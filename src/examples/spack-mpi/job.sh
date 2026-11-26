#!/bin/bash
#SBATCH --job-name=spack-mpi
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --time=00:05:00
set -eo pipefail

# The Spack environment: this directory, where you ran sbatch.
source "${SPACK_ROOT:?}/share/spack/setup-env.sh"
spack env activate "${SPACK_ENV_DIR:-$SLURM_SUBMIT_DIR}"

# One rank on each node, so the latency measured is between the nodes.
srun osu_latency
