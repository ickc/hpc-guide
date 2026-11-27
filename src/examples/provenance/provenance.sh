# shellcheck shell=bash
# Source this at the top of a job, from inside the git repository of the code it
# runs, to record in the job's output what the job ran on:
#
#     source provenance.sh pixi.lock    # and the SHA-256 of each lockfile named
#
# Each line starts with its name, so that `grep '^cpu' slurm-*.out` finds it later.
# Nothing here stops the job, whatever is missing on the node.

echo "== provenance, $(date --iso-8601=seconds)"

# The code: the commit checked out, and whether a file git tracks differs from it.
if commit="$(git rev-parse HEAD 2>/dev/null)"; then
    git diff --quiet HEAD -- || commit="$commit, with uncommitted changes"
    echo "commit    $commit"
fi

# The environment: each lockfile it was made from, by its hash.
for lockfile in "$@"; do
    echo "lockfile  $(sha256sum "$lockfile")"
done

# What the centre provides: the modules loaded, the OS, the kernel, the CPU, and
# the GPUs with their driver, where there are any. Lmod writes the list to stderr.
if type module >/dev/null 2>&1; then
    echo "modules   $(module -t list 2>&1 | paste -sd ' ')"
fi
echo "os        $(. /etc/os-release && echo "$PRETTY_NAME")"
echo "kernel    $(uname -srm)"
echo "cpu       $(lscpu | sed -n 's/^ *Model name: *//p' | sort -u | paste -sd ',')"
if gpus="$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null)"; then
    sort -u <<<"$gpus" | sed 's/^/gpu       /'
fi

# The job, which sacct can look up later, and the threads every library was told
# to use, from num-threads.sh, with MKL_CBWR if it is set.
if [[ -n ${SLURM_JOB_ID:-} ]]; then
    echo "job       $SLURM_JOB_ID, on $SLURM_JOB_NODELIST"
fi
if threads="$(env | grep -E '_NUM_THREADS=|_DYNAMIC=|^MKL_CBWR=' | sort)"; then
    sed 's/^/threads   /' <<<"$threads"
fi
unset commit lockfile gpus threads
