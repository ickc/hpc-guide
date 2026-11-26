#!/bin/bash
#SBATCH --job-name=oversubscription
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:05:00
set -eo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-pi}"

# As many copies as CPUs, at the same time, doing the same work twice:
# first with 1 thread each, then with as many threads as CPUs each.
TIMEFORMAT="all copies: %R s elapsed, %U s CPU time"
for threads in 1 "$SLURM_CPUS_PER_TASK"; do
    echo "== $SLURM_CPUS_PER_TASK copies at once, NUM_THREADS=$threads"
    source ../pi/num-threads.sh "$threads"
    time {
        for _ in $(seq "$SLURM_CPUS_PER_TASK"); do python matmul.py & done
        wait
    }
done
