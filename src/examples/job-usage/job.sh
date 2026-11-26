#!/bin/bash
#SBATCH --job-name=job-usage
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:05:00
/usr/bin/time -v python3 use_memory.py 1024 60
