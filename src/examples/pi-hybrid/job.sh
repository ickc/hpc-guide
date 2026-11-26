#!/bin/bash
#SBATCH --job-name=pi-hybrid
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=2
#SBATCH --cpus-per-task=4
#SBATCH --time=00:05:00
set -eo pipefail

# The vendor's MPI. On a Cray system, it comes with the programming environment.
module reset
module load PrgEnv-gnu

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-pi-mpi}"
# The vendor's libmpi.so.12, for mpi4py to find, since the environment has none.
export LD_LIBRARY_PATH="${MPICH_DIR}/lib-abi-mpich:${LD_LIBRARY_PATH:-}"
# Where pi.py is, for `import pi`.
export PYTHONPATH="$PWD/../pi"
# Every rank has --cpus-per-task CPUs, for as many threads.
source ../pi/num-threads.sh

# 4 ranks, 2 per node, each pinned to 4 cores of its own, with 4 threads.
srun --cpus-per-task="$SLURM_CPUS_PER_TASK" --cpu-bind=verbose,cores \
    python -m mpi4py pi_hybrid.py "$NUM_THREADS"
