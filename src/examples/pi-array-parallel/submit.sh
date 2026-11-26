#!/bin/bash
# Run this on the login node: the array, then the same reduce job as for the plain array.
set -eo pipefail

array="$(sbatch --parsable job.sh)"
array="${array%%;*}"
sbatch --dependency=afterok:"$array" ../pi-array/reduce.sh
