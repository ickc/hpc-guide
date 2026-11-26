#!/bin/bash
#SBATCH --job-name=pi-reduce
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:02:00
set -eo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-pi}"

python ../pi/pi.py reduce results/*.txt
