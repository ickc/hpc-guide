#!/bin/bash
#SBATCH --job-name=pi-mpi4py-futures
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=1
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
# Every worker is a rank with one thread, on a core of its own.
source ../pi/num-threads.sh 1

# 8 ranks: rank 0 runs the script, and the other 7 are its workers.
srun --cpu-bind=cores python -m mpi4py.futures "${1:-pi_mpi4py_futures.py}"
