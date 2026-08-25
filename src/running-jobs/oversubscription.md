On an HPC, it is quite often you'd run into a situation
that you need to think about restricting the number of threads
in multithreading scenario where if treated not carefully would
leads to oversubscription problems.
For example, you might be using hybrid MPI (so called MPI+X) where X
has access to number of threads smaller than that available
in a node (say 2 MPI processes per node),
or when you're sharing a node with other users if you didn't
set `--exclusive` in your Slurm batch job
(or you're using a QoS allowing non-exclusive nodes).
TODO: see intro to Slurm.

In this case, you'd often want to set some env var to match
the no. of threads available in such situation.
Here's a list of env var I collected over the years to control this
from different kinds of multithreading paradigm:

```bash
# set this once
NUM_THREADS=...

# TODO: add comments to eplain each group of these
export MKL_NUM_THREADS=${NUM_THREADS}
export MKL_DOMAIN_NUM_THREADS="MKL_BLAS=${NUM_THREADS}"
export MKL_DYNAMIC=FALSE

export OMP_NUM_THREADS=${NUM_THREADS}
export OMP_PLACES=threads
export OMP_PROC_BIND=spread
export OMP_DYNAMIC=FALSE

export NUMEXPR_NUM_THREADS=${NUM_THREADS}

export OPENBLAS_NUM_THREADS=${NUM_THREADS}

export NUMBA_NUM_THREADS=${NUM_THREADS}

export NPROC=${NUM_THREADS}
export JAX_NUM_CPU_DEVICES=1
export TF_NUM_INTEROP_THREADS=1
export TF_NUM_INTRAOP_THREADS=${NUM_THREADS}

export JULIA_NUM_THREADS=${NUM_THREADS}
```

[TIPS]
Set that to the number of physical core avaible to the process,
i.e. disregard the no. of logical core unless you know what you're doing.

[TIPS]
As setting these env. var. when they aren't needed does no harm,
and often time, espcially in Python applications, you unknowingly
was using some parallelization backends behind the scene,
I recommend setting all of them in all jobs,
unless of course when you know what you are doing and require
something more advanced than that (e.g. nesting!)
