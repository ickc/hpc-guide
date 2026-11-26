#!/bin/bash
#SBATCH --job-name=pi-workflow
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:10:00
set -eo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-pi-workflow}"
# Every task is a process with one thread, so as many tasks as CPUs at a time.
source ../pi/num-threads.sh 1

# The whole workflow inside this job, on its CPUs.
snakemake --cores "$SLURM_CPUS_PER_TASK"
cat pi.txt
