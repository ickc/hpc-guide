#!/bin/bash
# Run this on the login node: it activates the environment here, once,
# and the job inherits it. Extra arguments are passed on to sbatch.
set -eo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV:-numpy-demo}"

sbatch --export=ALL "$@" <<'EOF_JOB'
#!/bin/bash
#SBATCH --job-name=conda-heredoc
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:05:00

python -c 'import numpy, sys; print(f"numpy {numpy.__version__} from {sys.prefix}")'
EOF_JOB
