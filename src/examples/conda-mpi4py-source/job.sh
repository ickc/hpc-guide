#!/bin/bash
#SBATCH --job-name=mpi4py-source
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=1
#SBATCH --time=00:05:00
set -eo pipefail

# The same modules mpi4py was built with.
module reset
module load PrgEnv-gnu

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-mpi4py-source}"

srun python ../mpi-hello/mpi_hello.py
