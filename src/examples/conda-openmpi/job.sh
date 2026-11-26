#!/bin/bash
#SBATCH --job-name=mpi4py-openmpi
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=1
#SBATCH --time=00:05:00
set -eo pipefail

# This Open MPI brings its own runtime, so leave the vendor's MPI unloaded.
module reset

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-mpi4py-openmpi}"

# Open MPI's own mpirun, told to get the nodes from Slurm and start through it.
mpirun --prtemca ras slurm --prtemca plm slurm \
    --np 8 --map-by ppr:4:node:PE=1 --bind-to core \
    python ../mpi-hello/mpi_hello.py
