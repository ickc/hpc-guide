#!/bin/bash
#SBATCH --job-name=pi-futures
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:05:00
set -eo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-pi}"
# Where pi.py is, for `import pi`.
export PYTHONPATH="$PWD/../pi"
# Every worker is a process with one thread, and there is one worker per CPU.
source ../pi/num-threads.sh 1

python pi_futures.py
