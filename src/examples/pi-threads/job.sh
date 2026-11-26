#!/bin/bash
#SBATCH --job-name=pi-threads
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:05:00
set -eo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-pi}"
# Where pi.py is, for `import pi`.
export PYTHONPATH="$PWD/../pi"

# One thread for each CPU the job asked for.
source ../pi/num-threads.sh "$SLURM_CPUS_PER_TASK"
python pi_threads.py "$SLURM_CPUS_PER_TASK"
