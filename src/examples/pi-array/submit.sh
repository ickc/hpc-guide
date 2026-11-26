#!/bin/bash
# Run this on the login node: it submits the array, and the job that adds up
# its results, which starts only once every task of the array has succeeded.
set -eo pipefail

array="$(sbatch --parsable job.sh)"
array="${array%%;*}"
sbatch --dependency=afterok:"$array" reduce.sh
