---
title: "Threads and oversubscription"
description: "One process using many cores through threads, from OpenMP, BLAS, NumPy or Numba; asking Slurm for the cores with --cpus-per-task; and oversubscription, more threads than cores, with the environment variables that prevent it and how to see it."
output-file: threads
aliases: [../running-jobs/oversubscription.html]
---

[The introduction](10-intro.md) sorted computations by what their pieces need from each other. The simplest way to use more than one core needs nothing from you but the right request to the scheduler: a program that already runs as one process with many threads.

## Threads, and where they come from

A *thread* is a stream of work inside a process. All the threads of a process share its memory, so they can work on the same data without sending it to each other, and the operating system runs each thread on whichever core is free. A process with 8 threads can keep 8 cores busy, but only on one node, since that is where its memory is.

You often get threads without asking for them:

- **BLAS**, the library that does linear algebra, e.g. matrix products, for NumPy, SciPy, R, and most compiled programs. Its common implementations, OpenBLAS and Intel MKL, use threads by default, so `a @ b` in NumPy may use every core it can see.
- **OpenMP**, in compiled code (C, C++, Fortran), where a loop marked with `#pragma omp parallel for` is split between threads, and in many libraries built with it.
- **Numba**, in Python, where a function compiled with `@njit(parallel=True)` runs its `prange` loops on threads.
- **JAX**, on the CPU, which is the odd one out: it [doesn't parallelize operations across CPU cores](https://github.com/jax-ml/jax/issues/5022#issuecomment-1222336766) unless you use explicit parallelism constructs, but some of its operations, such as BLAS or LAPACK, have their own internal parallelism.
- **Python's own threads**, with `threading` or `concurrent.futures.ThreadPoolExecutor`. With the usual build of Python, only one thread runs Python code at a time, because of its global interpreter lock (the GIL), but NumPy, like many libraries written in C, releases the GIL while it computes, so threads that spend their time in NumPy do run at once.[^1]

Here is Monte Carlo π that way: one process, a pool of threads, each running tasks of `pi.py` until all 64 are done.

``` {.python include="../examples/pi-threads/pi_threads.py"}
```

It also reports how many CPUs the process may run on, and its *CPU use*: the CPU time of all its threads, divided by the time that passed. A process that keeps 8 cores busy has a CPU use of 800%.

## Asking for the cores

On your own computer, a program can use every core. On a cluster, it can use the cores the scheduler gave the job, and for threads, you ask for those with `--cpus-per-task`:

``` {.bash include="../examples/pi-threads/job.sh"}
```

`--ntasks=1 --cpus-per-task=8` is one task, i.e. one process, with 8 CPUs for its threads. Slurm puts them all on one node, since a task cannot be split between nodes, and sets `SLURM_CPUS_PER_TASK` to 8 in the job (only when you give `--cpus-per-task`), so the script never has to repeat the number. On most clusters, Slurm also confines the job to its CPUs, so that the process cannot run on any other core of the node. Then `num-threads.sh`, below, tells every threaded library to use 8 threads, and `pi_threads.py` starts 8 of its own.

The output is

``` text
8 threads, on 8 CPUs: 7.4 s, CPU use 794%
pi = 3.141543 from 4294967296 samples
```

which is the same estimate as the baseline on one core, about 8 times faster, with the 8 cores all busy.[^2]

::: callout-tip
Set the number of threads to the number of *physical* cores available to the process, i.e. disregard the number of logical cores unless you know what you're doing.
:::

Some CPUs present each physical core as two *logical* cores, which is called simultaneous multithreading, or hyperthreading on Intel's. The two share the one core, so a second thread on it runs only in the gaps the first leaves. `lscpu` shows whether a node does this, as `Thread(s) per core: 2`, and some clusters count logical cores as CPUs in Slurm. On those, 8 CPUs may be 4 physical cores, and 4 threads is the place to start.

## Oversubscription

On an HPC, you quite often need to think about restricting the number of threads, because when it isn't done carefully, it leads to *oversubscription*: more threads than cores. The threads then take turns on the cores, and every switch from one to another costs time.

It happens when something uses fewer cores than the node has, and a library doesn't know. For example, with hybrid MPI (so-called MPI+X), where each rank's threads, the X, should only use the rank's share of the node, say half of it with 2 MPI ranks per node. Or when you share a node with other users' jobs, which happens whenever you don't ask for the whole node, with `--exclusive`, on a cluster that allows sharing. Or when you run many processes at once, as in the next section: 8 tasks at a time on 8 CPUs, each of which, through NumPy, starts 8 threads, makes 64 threads on 8 cores.

It also happens when `srun` starts tasks without `--cpus-per-task`, e.g. `srun --ntasks=N` in a job that asked for a whole node, with `OMP_NUM_THREADS` set so that ranks times threads is the number of cores. Each task then gets 1 CPU, and with `--cpu-bind=cores` it is pinned to that one core, so all of its threads share it, and the more threads per rank, the slower the job gets. The fix is to tell `srun` how many CPUs each task needs, `srun --ntasks=N --cpus-per-task=M`.

This example does exactly that, the same matrix products in 8 copies at once, first with 1 thread each, then with 8 threads each, what a threaded library would use on 8 CPUs if nothing told it otherwise:

``` {.python include="../examples/oversubscription/matmul.py"}
```

``` {.bash include="../examples/oversubscription/job.sh"}
```

The output is

``` text
== 8 copies at once, NUM_THREADS=1
0.91 s, CPU use 100%
0.92 s, CPU use 100%
0.92 s, CPU use 100%
0.92 s, CPU use 100%
0.92 s, CPU use 100%
0.91 s, CPU use 100%
0.91 s, CPU use 100%
0.92 s, CPU use 100%
all copies: 0.977 s elapsed, 7.645 s CPU time
== 8 copies at once, NUM_THREADS=8
4.49 s, CPU use 101%
4.57 s, CPU use 100%
4.64 s, CPU use 101%
4.68 s, CPU use 101%
4.68 s, CPU use 102%
4.70 s, CPU use 100%
4.70 s, CPU use 100%
4.70 s, CPU use 100%
all copies: 4.846 s elapsed, 38.633 s CPU time
```

The same work took 5 times as long, and 5 times the CPU time. The threads of a matrix product wait for each other, and with 64 threads on 8 cores, the thread being waited for is often not running. Threads that never wait for each other, as those of `pi_threads.py`, lose little to oversubscription, while those of BLAS and OpenMP lose a lot. Oversubscription never gains anything, so it is worth preventing every time.

## The environment variables

So you'd often want to set some environment variables, to match the number of threads to the cores available. Each threaded library reads its own, so here is a list of the ones I have collected over the years, for different kinds of multithreading, as the file every job in this part sources:

``` {.bash include="../examples/pi/num-threads.sh"}
```

`source num-threads.sh 4` sets them all to 4, and `source num-threads.sh` alone to `--cpus-per-task`, or 1 without it. Group by group:

- **MKL**: `MKL_NUM_THREADS` is the number of threads for all of Intel MKL, `MKL_DOMAIN_NUM_THREADS` the number for its BLAS in particular, and `MKL_DYNAMIC=FALSE` stops MKL from deciding to use fewer threads than that by itself.
- **OpenMP**: `OMP_NUM_THREADS` is the number of threads. The other three are about where they run: `OMP_PLACES=threads` makes each logical CPU a place a thread can be pinned to, `OMP_PROC_BIND=spread` pins the threads to places spread evenly over the CPUs the process may use, so that the operating system doesn't move them around, and `OMP_DYNAMIC=FALSE` stops the runtime from changing the number of threads.[^3]
- **numexpr**, which pandas uses to evaluate expressions, has `NUMEXPR_NUM_THREADS`.
- **OpenBLAS**, the BLAS that NumPy and SciPy come with from conda-forge and from PyPI, has `OPENBLAS_NUM_THREADS`.
- **Numba** has `NUMBA_NUM_THREADS`, for functions compiled with `parallel=True`.
- **JAX** has no `JAX_NUM_THREADS`, and how to limit its threads on the CPU is very obscure. `XLA_FLAGS='--xla_cpu_multi_thread_eigen=false intra_op_parallelism_threads=1'` [was the recommendation](https://github.com/jax-ml/jax/issues/743#issuecomment-511684879), and [it is now recommended to use `NPROC=1`](https://github.com/jax-ml/jax/issues/743#issuecomment-2405731890) instead, to disable the multithreading used in Eigen, the library XLA uses for some operations. `NPROC` is a generic name, which other programs may read too, so it might have side effects, and setting it to the same number as everything else keeps those harmless. `JAX_NUM_CPU_DEVICES=1` keeps JAX to one CPU device.
- **TensorFlow** runs independent operations one at a time (`TF_NUM_INTEROP_THREADS=1`), each on the given number of threads (`TF_NUM_INTRAOP_THREADS`).
- **Julia** has `JULIA_NUM_THREADS`.

::: callout-tip
As setting these environment variables when they aren't needed does no harm, and oftentimes, especially in Python applications, you are unknowingly using some parallel backend behind the scenes, I recommend setting all of them in all jobs, unless of course you know what you are doing and need something more advanced than that (e.g. nesting!).
:::

That is why every job in this part sources `num-threads.sh`, even those whose tasks have no threads at all: with 1 thread per task, the 8 copies above take 0.98 s.

## Seeing it

Oversubscription doesn't make a job fail. It runs to the end, with the right result, only slower, so what you see is a time that doesn't add up. To check a job while it runs, look at its CPU use. `pi_threads.py` and `matmul.py` print theirs, which you can do in your own program with `time.process_time()`; for any program, `sacct` shows the CPU time of a job, `TotalCPU`, next to its `Elapsed` time, and while it runs, you can watch it with `top` on its node:

``` bash
srun --jobid=<job ID> --overlap --pty top
```

`--overlap` lets this run alongside the job, on the same CPUs, rather than waiting for them to be free. In `top`, 100% in the `%CPU` column is one core, so a process with 8 threads on its own 8 cores shows about 800%. A process with many threads at about 100%, as the copies above were, is sharing its cores, and so, on a node your job has to itself, is a *load average*, at the top of `top`, well above the number of CPUs.

Threads cannot go beyond the process they belong to, and so beyond its node. The [next section](tasks/10-intro.md) is about many processes instead, many independent tasks at once.

[^1]: On a *free-threaded* build of Python, which has no GIL, threads run Python code at once too: see [Python's HOWTO on free threading](https://docs.python.org/3/howto/free-threading-python.html).

[^2]: The timings on this page were measured on 8 cores of an x86 workstation. On the nodes of your cluster the times will be different, but not the ratios between them.

[^3]: Pinning matters most when one node runs several multithreaded processes, as with MPI+X, which is the subject of the [page on hybrid MPI](30-hybrid-mpi.md), later in this part.
