---
title: "Which way to run many tasks?"
description: "Many independent tasks, each its own process, and the ways to run them: on one node with GNU parallel or a pool of processes in Python, and over many nodes with a job array, mpi4py.futures or DragonHPC."
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

This works, in the sense that it finishes. But it starts all 64 at once, on 8 cores, which is [oversubscription](../20-threads.md#oversubscription), and with 64,000 input files instead of 64 seeds, it starts 64,000 processes at once, which may well hit the limit on how many processes you can have. And if a task fails, nothing tells you which one: `wait` without arguments returns 0 whatever happened. Limiting it to 8 at a time, and keeping track of which ones failed, is doable in bash, and it is exactly what GNU parallel already does.

## The ways to run them

On one node, inside one job:

- [GNU parallel](20-gnu-parallel.md) runs a command once for each line of a task list, as many at a time as the job has cores, and keeps a log from which it reruns only the tasks that failed. The tasks can be any command.
- [A pool of processes in Python](30-python-pool.md) runs calls of a Python function from one script, starting each worker once rather than once per task.

When there are more tasks than one node can get through in the time of one job:

- [A job array](40-job-arrays.md) lets the scheduler run each task, or each batch of tasks, as a job of its own, on whichever nodes are free.
- [`mpi4py.futures`](50-mpi4py-futures.md) spreads a pool of Python workers over every node of one job, with MPI underneath.
- [DragonHPC](60-dragon.md) does the same through Python's own `multiprocessing`, with a runtime of its own instead of MPI.

Every page of this section runs the same 64 tasks of Monte Carlo π, and gets the same answer.
