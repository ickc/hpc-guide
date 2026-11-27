---
title: "Which way to run many tasks?"
description: "Many independent tasks, each its own process, and the ways to run them side by side: GNU parallel and a pool of processes in Python on one node, a job array, mpi4py.futures and DragonHPC over many; what the tasks can be, what each needs, how a failed task shows and is rerun, the load on the scheduler, and which to reach for first."
output-file: intro
aliases: [../one-node.html]
---

[Threads](../20-threads.md) use many cores from one process. This section is about the other common case: many independent tasks, each its own process, run as many at a time as the job has cores.

## The loop you may be tempted to write

Say you have 64 tasks, and a job with 8 cores. In bash, the first thing that comes to mind is to start them all in the background and wait:

``` bash
for seed in $(seq 1 64); do
    python ../pi/pi.py count "$seed" > "results/$seed.txt" &
done
wait
```

This works, in the sense that it finishes. But it starts all 64 at once, on 8 cores, which is [oversubscription](../20-threads.md#oversubscription), and with 64,000 input files instead of 64 seeds, it starts 64,000 processes at once, which may well hit the limit on how many processes you can have. And if a task fails, nothing tells you which one: `wait` without arguments returns 0 whatever happened. Limiting it to 8 at a time, and keeping track of which ones failed, is doable in bash, and it is what every way below already does.

## The ways to run them

|  | Runs on | The tasks are | Needs | When a task fails |
|------------------------|------------------------|------------------------|------------------------|------------------------|
| GNU parallel | one node, in one job | any command | GNU parallel, from a module or conda-forge | its exit status counts it, and its job log reruns it |
| Python pool | one node, in one job | calls of a Python function | Python's standard library | its exception is raised in your script when its result is read |
| Job array | many nodes, as one job per array task | any command | Slurm alone | it fails on its own, and `sacct` shows which |
| `mpi4py.futures` | many nodes, in one job | calls of a Python function | mpi4py, on an MPI that works across nodes | as in the pool, on rank 0, and every rank ends |
| Dragon | many nodes, in one job | calls of a Python function, through `multiprocessing` | Dragon, from PyPI, on Python 3.11 to 3.13 | as in the pool, in the head process |

**On one node**, [GNU parallel](20-gnu-parallel.md) runs any command, so a task can be a Python script, a compiled program or a line of bash, and its job log lets you rerun only the tasks that failed, and those that never ran because the job ran out of time, with `--resume-failed`. [A pool](30-python-pool.md) starts each worker once, so Python and NumPy are imported once per worker rather than once per task, which matters when there are many thousands of tasks that take a second each. To rerun only the failed tasks of a pool, have each task catch its exception and return it with its input.

**Beyond one node, as many jobs**, [a job array](40-job-arrays.md) needs nothing but Slurm. Each array task succeeds or fails on its own, so you rerun only the failed ones, with `sbatch --array=` and their indices. The cost is that each array task is a job, which the scheduler, shared by everyone on the cluster, has to schedule and account for, and which starts from nothing, so an array is for tasks that are each worth a job. Many short tasks are better grouped, e.g. as an array of whole nodes each running GNU parallel, at the end of [the page on job arrays](40-job-arrays.md#an-array-of-whole-nodes-each-running-gnu-parallel).

**Beyond one node, in one job**, [`mpi4py.futures`](50-mpi4py-futures.md) and [Dragon](60-dragon.md) both run a pool of workers spread over the nodes of the job, from one Python script. `mpi4py.futures` needs an mpi4py that works across nodes, with everything [the section on MPI](../../software/mpi/10-intro.md) is about, and its rank 0 is the controller rather than a worker. mpi4py itself is on conda-forge and in Spack. Dragon needs no MPI, its head process is not one of the workers, and it gives you the whole of `multiprocessing`, `Process`, `Queue`, `Pipe`, locks, and pools inside pools, rather than an executor. In exchange, it supports only Python 3.11 to 3.13, comes only from PyPI, and at version 0.15 is young. With either, all the results come back to one process, and if the job runs out of time, the tasks it did not finish are lost, unless each task writes its result to a file as it goes.

## Which to reach for first

If the tasks fit on one node in the time of one job, start there: GNU parallel when they are commands, and a pool when they are Python functions. Beyond one node, for tasks that are commands, a job array, or GNU parallel inside one, is simpler. For Python functions, I'd say `mpi4py.futures` or a job array is the safer default for most people, and Dragon the one to try when a pool is limited by one node and getting MPI right is the obstacle: if your code is already a `multiprocessing` pool, trying it on 2 nodes costs two lines.

Every page of this section runs the same 64 tasks of Monte Carlo π, and gets the same answer. The [next page](20-gnu-parallel.md) starts on one node, with GNU parallel.
