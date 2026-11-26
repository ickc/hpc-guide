#!/bin/bash
#SBATCH --job-name=hello
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:02:00
echo "Hello from $(hostname), job $SLURM_JOB_ID"
