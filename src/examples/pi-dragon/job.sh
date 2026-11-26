#!/bin/bash
#SBATCH --job-name=pi-dragon
#SBATCH --nodes=2
#SBATCH --exclusive
#SBATCH --time=00:05:00
set -eo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-pi-dragon}"
# Where pi.py is, for `import pi`, on every node.
export PYTHONPATH="$PWD/../pi"
# Every worker is a process with one thread, and there is one worker per CPU.
source ../pi/num-threads.sh 1

# No srun: the dragon launcher starts its runtime on every node of the job by itself.
dragon pi_dragon.py
