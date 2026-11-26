#!/bin/bash
#SBATCH --job-name=mpi-hello
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=1
#SBATCH --time=00:05:00
set -eo pipefail

# Set up the environment the same way as your real MPI job does.
# Here, that is a conda environment with mpi4py in it.
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-mpi4py-plain}"

srun python mpi_hello.py
