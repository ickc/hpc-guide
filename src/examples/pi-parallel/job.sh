#!/bin/bash
#SBATCH --job-name=pi-parallel
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:05:00
set -eo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-pi}"
# Every task is a process with one thread, so as many tasks as CPUs at a time.
source ../pi/num-threads.sh 1

mkdir -p results
parallel --jobs "$SLURM_CPUS_PER_TASK" --joblog joblog.tsv \
    'python ../pi/pi.py count {} > results/{}.txt' :::: tasks.txt
python ../pi/pi.py reduce results/*.txt
