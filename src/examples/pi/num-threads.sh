# shellcheck shell=bash
# Source this in a job, to tell every threaded library how many threads to use:
#
#     source num-threads.sh 4    # 4 threads
#     source num-threads.sh      # as many as --cpus-per-task, or 1
NUM_THREADS="${1:-${SLURM_CPUS_PER_TASK:-1}}"

# Intel MKL, the BLAS of NumPy from Anaconda's defaults channel on x86, and of many
# compiled programs. MKL_DYNAMIC=FALSE stops it from using fewer threads than this.
export MKL_NUM_THREADS="${NUM_THREADS}"
export MKL_DOMAIN_NUM_THREADS="MKL_BLAS=${NUM_THREADS}"
export MKL_DYNAMIC=FALSE

# OpenMP, in compiled code and in the libraries built with it. Each thread is
# pinned to a CPU of its own, spread over those the process may use, and the
# runtime may not change the number of threads by itself.
export OMP_NUM_THREADS="${NUM_THREADS}"
export OMP_PLACES=threads
export OMP_PROC_BIND=spread
export OMP_DYNAMIC=FALSE

# numexpr, which pandas uses to evaluate expressions.
export NUMEXPR_NUM_THREADS="${NUM_THREADS}"

# OpenBLAS, the BLAS of NumPy and SciPy from conda-forge and from PyPI.
export OPENBLAS_NUM_THREADS="${NUM_THREADS}"

# Numba, for functions compiled with parallel=True.
export NUMBA_NUM_THREADS="${NUM_THREADS}"

# Machine learning: JAX and TensorFlow, and NPROC, which some scripts read.
export NPROC="${NUM_THREADS}"
export JAX_NUM_CPU_DEVICES=1
export TF_NUM_INTEROP_THREADS=1
export TF_NUM_INTRAOP_THREADS="${NUM_THREADS}"

# Julia.
export JULIA_NUM_THREADS="${NUM_THREADS}"
