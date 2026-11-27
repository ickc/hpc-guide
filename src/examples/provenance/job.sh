#!/bin/bash
#SBATCH --job-name=provenance
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:05:00
set -eo pipefail

source ../pi/num-threads.sh

# The project of the pixi example, with its environment installed from pixi.lock.
cd ../pixi-job
eval "$(pixi shell-hook --frozen -s bash)"

# What the job runs on, at the top of its output, before the work.
source ../provenance/provenance.sh pixi.lock

python pi.py
