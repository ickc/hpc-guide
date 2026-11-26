#!/bin/bash
#SBATCH --job-name=conda-job
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:05:00

# Make `conda activate` available in this non-interactive shell.
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-numpy-demo}"

python -c 'import numpy, sys; print(f"numpy {numpy.__version__} from {sys.prefix}")'
