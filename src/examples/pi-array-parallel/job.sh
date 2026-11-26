#!/bin/bash
#SBATCH --job-name=pi-array-parallel
#SBATCH --array=1-2
#SBATCH --output=pi-array-parallel-%A_%a.out
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --time=00:05:00
set -eo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-pi}"
source ../pi/num-threads.sh 1

# This array task's share of the 64 seeds: 1 to 32 for the first, 33 to 64 for the second.
share=$((64 / SLURM_ARRAY_TASK_COUNT))
first=$(((SLURM_ARRAY_TASK_ID - 1) * share + 1))
last=$((first + share - 1))

# Run them on the whole node, one per CPU.
mkdir -p results
seq "$first" "$last" | parallel --jobs "$SLURM_CPUS_ON_NODE" \
    'python ../pi/pi.py count {} > results/{}.txt'
