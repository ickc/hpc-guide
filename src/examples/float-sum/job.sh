#!/bin/bash
#SBATCH --job-name=float-sum
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:05:00
set -eo pipefail

# The same list, in 1, 8 and 64 pieces, twice over.
python3 float_sum.py 1 8 64
python3 float_sum.py 1 8 64
