#!/bin/bash
#SBATCH --job-name=pixi-job
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:05:00
set -eo pipefail

# The project directory, with pixi.toml and pixi.lock: where you ran sbatch.
cd "$SLURM_SUBMIT_DIR"

# One command at a time: pixi checks the environment against the lockfile,
# activates it, and runs the task.
pixi run --frozen pi

# Or activate once, and run as many commands as you like in it.
eval "$(pixi shell-hook --frozen -s bash)"
python pi.py
