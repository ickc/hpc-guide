#!/bin/bash
#SBATCH --job-name=pi-array
#SBATCH --array=1-64%16
#SBATCH --output=pi-array-%A_%a.out
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:05:00
set -eo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-pi}"
source ../pi/num-threads.sh 1

# This array task is one task of the problem, with its index as the seed.
mkdir -p results
python ../pi/pi.py count "$SLURM_ARRAY_TASK_ID" >"results/$SLURM_ARRAY_TASK_ID.txt"
