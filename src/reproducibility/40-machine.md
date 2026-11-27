---
title: "Recording the machine"
output-file: machine
description: "The part of the environment that belongs to the centre, its modules, MPI, GPU driver, kernel and CPU, which no lockfile pins: a script that records them at the top of every job; why one lockfile still runs different code on different CPUs, and which equivalence to claim on one kind of node and across them; Intel MKL's conditional numerical reproducibility; and choosing variants in the recipe rather than by what was detected."
---

[The previous page](30-environment.md) froze the software you install, down to a lockfile of hashes. The rest of the environment comes with the cluster: the modules, the vendor's MPI, the GPU driver, the kernel and the CPU. They belong to the centre, which upgrades them on its own schedule, so you cannot lock them. What you can do is record them, in every job, so that when a number changes, you can tell whether the machine changed with it.

## The recipe

The batch script you probably have loads the modules it needs, by version, as [the page on modules](../software/package-managers/20-modules.md#modules-in-a-job) recommends, activates the environment, and runs the analysis. Its output holds the results, and nothing about what produced them.

Say a rerun, a year later, differs from the paper in its last digits, and you want to know why. A module named by its version can still be rebuilt, or removed, when the centre upgrades its software. The GPU driver and the kernel are upgraded with the operating system, or on their own. On some clusters, one partition has more than one kind of node, so two runs of the same job can land on different CPUs. And `sacct` keeps each job's ID, nodes and times, for as long as the centre keeps its records, but nothing about the modules, the driver or the kernel.

## Record it in every job

So write down what each job ran on, at the top of its output. This script does that:

``` {.bash include="../examples/provenance/provenance.sh"}
```

Here it is in a job that runs the π of [the page on pixi](../software/package-managers/40-pixi.md#using-it-in-a-batch-job), in its environment:

``` {.bash include="../examples/provenance/job.sh"}
```

Its output starts with[^1]

``` text
== provenance, 2026-11-27T06:27:51+00:00
commit    3e688156cdd44e8728cc0287c8e215ef24d7f555
lockfile  ef3010f706e9dcf1aad8e7a6efa0bb5dde22738d5f8141c20e17739bc6020124  pixi.lock
modules   No modules loaded
os        Red Hat Enterprise Linux 10.3 (Coughlan)
kernel    Linux 6.12.0-264.16.1.el10_3.x86_64 x86_64
cpu       AMD Ryzen 9 9950X 16-Core Processor
gpu       NVIDIA GeForce RTX 5070 Ti, 620.70.06
threads   JULIA_NUM_THREADS=1
threads   MKL_DOMAIN_NUM_THREADS=MKL_BLAS=1
threads   MKL_DYNAMIC=FALSE
threads   MKL_NUM_THREADS=1
threads   NUMBA_NUM_THREADS=1
threads   NUMEXPR_NUM_THREADS=1
threads   OMP_DYNAMIC=FALSE
threads   OMP_NUM_THREADS=1
threads   OPENBLAS_NUM_THREADS=1
```

The commit is the code that ran. If a file that git tracks was changed since, the line ends `with uncommitted changes`, and the commit no longer says what ran, so commit before you submit a job whose result you will keep. The lockfile line is the SHA-256 of each lockfile named after `source provenance.sh`, the one the environment was installed from. When the lockfile is committed, the commit already implies it, but an environment is often installed elsewhere, e.g. in `$PROJECTDIR`,[^2] and the hash is what ties the job to the file it came from.

The modules are listed with `module -t list`, one per line, joined into one line. The script is sourced rather than run, because `module` is a shell function of the job's own shell. Then come the operating system, the kernel, the CPU model and, on a node with NVIDIA GPUs, each kind of GPU and its driver. In a job, a line with the job's ID and its nodes follows, which `sacct` can look up for as long as the centre keeps the record.[^3] The last lines are the number of threads every library was told to use, set by [`num-threads.sh`](../parallel/20-threads.md#the-environment-variables), and `MKL_CBWR`, below, when it is set.

Every line starts with its name, so a year later, `grep -h '^cpu' slurm-*.out | sort | uniq -c` counts your jobs by the CPU they ran on.

## One lockfile, many machines

[The previous page](30-environment.md#limitations) ended with one recipe solved for two platforms giving two environments. One lockfile on one platform does not run one program either. OpenBLAS, the BLAS NumPy gets from conda-forge, comes with its routines written for many kinds of CPU, and when it starts, picks the set for the CPU it finds. `OPENBLAS_CORETYPE` makes it pick another set, so you can see the difference on one machine. Here is a dot product of 10 million floats, on one thread, in the environment of the job above, on the same workstation:

``` bash
export OPENBLAS_NUM_THREADS=1
dot='import numpy as np; x = np.random.default_rng(2026).standard_normal(10**7); print(x @ x)'
python -c "$dot"
OPENBLAS_CORETYPE=Sandybridge python -c "$dot"
OPENBLAS_CORETYPE=Prescott python -c "$dot"
```

prints

``` text
10006567.101962904
10006567.10196307
10006567.101962721
```

The first is with the routines OpenBLAS picked for this CPU, and the other two with those it picks on older Intel CPUs. Intel MKL, too, chooses its code by the CPU it runs on. So the CPU model is an input: with the same lockfile, threads and seeds, a job that lands on another kind of node can change the last digits of anything that goes through these libraries.

Claim two equivalences, then, and say which is which. For a program that follows the strong principle of [the page on determinism](20-determinism.md), a rerun on the same kind of node, with the same lockfile and the same number of threads, is bit-identical. Across kinds of node, or platforms, the code that runs is different, and the equivalence is a tolerance, as in [the introduction](10-intro.md#what-a-claim-of-reproducible-says), checked against one reference result. The record is what tells you which of the two a rerun has to meet.

### Intel MKL's conditional numerical reproducibility

Intel MKL, the BLAS of NumPy from Anaconda's channels on `x86_64`, and of many compiled programs, has a mode that fixes the order of its operations, and can also give the same results across CPUs: [conditional numerical reproducibility](https://www.intel.com/content/www/us/en/docs/onemkl/developer-guide-linux/2025-2/obtaining-numerically-reproducible-results.html), set with `MKL_CBWR` in the job. `MKL_CBWR=AUTO` keeps the code for the CPU it finds, but splits the work between threads, and combines their results, the same way every time, so that a program gives bit-identical results from run to run. That holds as long as the number of threads stays the same, which `MKL_DYNAMIC=FALSE` in `num-threads.sh` makes sure of.[^4] Naming an instruction set makes the results the same across CPUs: `MKL_CBWR=AVX2` on every Intel CPU with AVX2, and `MKL_CBWR=COMPATIBLE` on every Intel or compatible CPU with SSE2. On CPUs not made by Intel, only `AUTO` and `COMPATIBLE` are supported. The cost is speed: Intel puts it at 10 to 20% for the fixed order alone, and in some cases more than half when the code path is fixed too.

## Choose variants in the recipe

Some of what differs from one machine to the next is chosen for you, by detection. Conda picks builds for the CPU and GPU it finds, through its [virtual packages](../software/package-managers/30-conda.md#resolve-on-the-hardware-you-will-run-on), and Spack [builds for the CPU of the node it runs on](../software/package-managers/60-spack.md#build-where-you-run). The lockfile records what was picked, but the next solve, on another node or for another platform, picks again. So where a choice matters to the result, make it in the recipe: the BLAS, with a build string such as `libblas=*=*_mkl`, as in [conda's variants](../software/package-managers/30-conda.md#variants); the MPI, e.g. conda-forge's external MPICH for the vendor's, as in [the section on MPI](../software/mpi/30-conda.md#mpich-from-the-vendor-the-rest-from-conda); and in Spack, the BLAS and the target in the spec itself, with `^openblas` and `target=`.

## Limitations

The record tells you what changed, but once the centre has upgraded the driver or the kernel, nothing brings the old one back, and a rerun can only be checked against the tolerance you declared. A container does not help with this part, since it runs on the host's kernel and driver, as [the page on containers](../software/package-managers/50-containers.md#limitations) says. What does help is that Linux [keeps the interface programs use to talk to it stable](https://docs.kernel.org/process/stable-api-nonsense.html), so an environment or a container made under an older kernel still runs under a newer one.

If your code depends on something else about the node, such as a variable that another library reads, add a line for it to the script.

The next section is about workflows: pipelines of many steps, each with its inputs and an environment of its own.

[^1]: Run on an x86 workstation after `module purge`, outside Slurm, which is why there is no line for the job.

[^2]: `$PROJECTDIR` is what some clusters call the space shared by a project, with its own quota. Not every cluster sets it, and some use another name, so look for that kind of storage in your centre's documentation; [the part on storage](../storage/10-where.md) is about the kinds there are.

[^3]: The batch script runs on one node of the job, usually the first, so on a job of many nodes, the CPU and GPU lines are that node's.

[^4]: For the matrix products and triangular solves of BLAS (`?gemm`, `?symm`, `?hemm` and `?trsm`), on Intel CPUs with AVX2 or AVX-512, `MKL_CBWR=AUTO,STRICT` gives the same results even when the number of threads changes.
