#!/bin/bash
#SBATCH --job-name=hold
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=01:00:00
# Holds an allocation and does nothing else, so you can attach shells to it:
#     sbatch hold.sh
#     srun --jobid=<JOBID> --overlap --pty bash -i
# In practice this is your real job script, and you attach to watch it work.
sleep infinity
