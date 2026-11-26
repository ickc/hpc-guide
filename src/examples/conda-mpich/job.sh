#!/bin/bash
#SBATCH --job-name=mpi4py-mpich
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=1
#SBATCH --time=00:05:00
set -eo pipefail

# The vendor's MPI. On a Cray system, it comes with the programming environment.
module reset
module load PrgEnv-gnu

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-mpi4py-mpich}"

# The vendor's libmpi.so.12, for mpi4py to find, since the environment has none.
export LD_LIBRARY_PATH="${MPICH_DIR}/lib-abi-mpich:${LD_LIBRARY_PATH:-}"

srun python ../mpi-hello/mpi_hello.py
