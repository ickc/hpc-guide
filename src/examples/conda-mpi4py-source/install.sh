#!/bin/bash
# Build mpi4py from source against the vendor's MPI, into the environment.
set -eo pipefail

# The same modules as the job will load.
module reset
module load PrgEnv-gnu

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-mpi4py-source}"

# cc is the Cray compiler wrapper, which links Cray MPICH by itself.
MPICC="cc -shared" python -m pip install \
    --force-reinstall --no-cache-dir --no-binary mpi4py mpi4py
