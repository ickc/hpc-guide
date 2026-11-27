---
title: "Which kind of parallel is yours?"
description: "From a computation that takes too long on one core to the kind of parallelism it needs: many independent tasks, threads in one process, ranks that communicate, or tasks that depend on each other, on one node or many, and the Monte Carlo π example every page of this part solves."
output-file: intro
aliases: [../running-jobs/embarassingly-parallel.html]
---

The previous part ended with an environment, and an MPI, that work on every node. But MPI is only one answer to a more common question, which is probably the one that brought you to an HPC in the first place: you have a computation that takes too long on one core, and you want it to use many. The first step is to work out what kind of parallel your computation is, because each kind has its own tools, and the wrong one either doesn't speed anything up or makes a mess of the scheduler.

## The kinds of parallel

It helps to sort the problems into four classes, by asking what the pieces of your computation need from each other.

**Many independent tasks.** You run the same analysis on 500 input files, or sweep 1000 combinations of parameters, or repeat a simulation with 200 different random seeds. Each run is a *task*, and no task needs anything from another while it runs: they could run in any order, or all at once, and give the same results. This is called *embarrassingly parallel*: there is no clever way to split the work, since it comes already split, and the only problem left is how to run many tasks at once. At the end there is often a step that collects the results of all the tasks into one, which is called a *reduce*. It is the easiest kind to speed up, and for many analyses, it is the kind you have.

**One process using many cores.** Your program is one process, and it can use more than one core by itself, through *threads*: several streams of work inside the same process, sharing its memory, so they cannot go beyond one node. You may not have written any of them, since NumPy's linear algebra, OpenMP and Numba start threads on their own.

**Ranks that communicate.** The pieces need to exchange data while they run, e.g. a simulation on a grid split between processes, where each one needs the values at the edges of its neighbours' part every step. That is MPI, the subject of [the section on MPI](../software/mpi/10-intro.md) in the previous part, and it is the one kind that spans many nodes as one program.

**Tasks with dependencies.** A pipeline: some tasks need the output of others, e.g. align every sample, then call variants on each, then merge them all. Each step may well be embarrassingly parallel on its own, but there is an order between them, and once there are more than a couple of steps, you want a *workflow manager* to keep track of what to run when.

To tell which one yours is, ask what would happen if you ran each piece on a different computer, with no connection between them. If they could all finish and you'd only need to collect their outputs at the end, they are independent tasks. If they'd stop and wait for each other, they communicate, and that is MPI (or threads, if it all fits on one node). If some could start only once others had finished, they have dependencies.

Real computations mix these. Each of your 500 tasks may use 4 threads, or each step of a pipeline may be an array of independent tasks. That is fine, and the pages of this part combine them as they go.

## One node or many

The other question is how big. A node of a cluster has tens to a hundred or more cores, so a lot of computations fit on one node, and on one node things are simpler: everything shares one operating system, one memory, and one local disk, and the scheduler sees one job.

Going beyond one node needs one of two things. Either the scheduler starts the pieces on different nodes for you, as separate jobs, or something inside your job starts processes on the other nodes of its allocation, which is what `srun` and MPI do. Threads, Python's `multiprocessing`, and GNU parallel on its own all stay on the node they start on.

## A short guide

Crossing the two gives the pages of this part:

|  | One node | Many nodes |
|----------------------------------------|----------------------------------------|----------------------------------------|
| [Many independent tasks](tasks/10-intro.md) | [GNU parallel](tasks/20-gnu-parallel.md), or [a pool of processes in Python](tasks/30-python-pool.md) | a Slurm [job array](tasks/40-job-arrays.md), [`mpi4py.futures`](tasks/50-mpi4py-futures.md), or [DragonHPC](tasks/60-dragon.md) |
| One process, many cores | [threads](20-threads.md) | not possible: threads share memory |
| Ranks that communicate | [MPI](../software/mpi/10-intro.md) | MPI, with threads in each rank ([hybrid MPI](30-hybrid-mpi.md)) |
| Tasks with dependencies | a [workflow manager](40-workflows.md) | a [workflow manager](40-workflows.md) |

## The example: Monte Carlo π

Every page of this part solves the same problem, so that you can compare the ways of running it. It is a classic: draw random points uniformly in a square of side 1, and count the *hits*, the points that land inside the quarter of a circle of radius 1 centred on a corner. The quarter circle has area π/4 and the square has area 1, so the fraction of hits is close to π/4, and 4 times it is an estimate of π. The more points, the closer the estimate.[^1]

It is embarrassingly parallel: the points are independent, so the work splits into tasks of any size, each with its own random seed, and the reduce adds up the hits and the points of all the tasks. Here the problem is 64 tasks of 2^26^ (about 67 million) points each, so about 4.3 billion points in all. It is all in one small Python file, with NumPy:

``` {.python include="../examples/pi/pi.py"}
```

`count_hits` is the task: given a seed, it draws the points in chunks of 65,536 at a time, so the memory it needs stays small, and returns the number of hits. Each task gets its own seed, from 1 to 64, so that the tasks draw different points.[^2] From the command line, `python pi.py count 1 2 3` runs 3 tasks and prints one line for each, the hits and the number of points, and `python pi.py reduce` adds up such lines, from files or from its input, and prints the estimate.

The examples run in one conda environment, with NumPy, and GNU parallel for a later page:

``` {.yaml include="../examples/pi/environment.yml"}
```

Create it on the cluster, as in [the page on conda](../software/package-managers/30-conda.md), with `mamba env create -f environment.yml`. The baseline is the whole problem on one core, the 64 tasks one after another:

``` {.bash include="../examples/pi/job.sh"}
```

and its output ends with

``` text
pi = 3.141543 from 4294967296 samples
```

Every strategy in this part prints this same line, from the same 64 tasks,[^3] so you know it did all of the work, once. What changes is how long it takes, which `sacct -j <job ID> --format=JobID,Elapsed,TotalCPU` shows for any job: the time from start to end, and the CPU time of all its processes added up. On one core the two are about equal; if a job had 8 cores and used them all, the CPU time is about 8 times the elapsed time.

The files are all under [`examples/`](https://github.com/ickc/hpc-guide/tree/main/src/examples) in the guide's repository: `pi/` holds `pi.py`, the environment (and a second one, for the pages that use MPI), and `num-threads.sh`, which the [next page](20-threads.md) is about; each other directory is one strategy, and is meant to be submitted from inside it, since the batch scripts find `pi.py` at `../pi/`.

The next page starts with the kind that needs no change to how you run your program, only to what you ask the scheduler for: threads. It is also where oversubscription is explained, running more threads than cores, which every other page has to avoid.

[^1]: It is a slow way to compute π: the error shrinks only as one over the square root of the number of points, so each extra digit takes 100 times as many. That is fine here, since its pieces are independent, and the answer is known, so you can tell when a run gets it wrong.

[^2]: Each task's random numbers come from `np.random.default_rng([seed, ROOT_SEED])`, a list of the task's own seed and one shared by all of them, which is how [NumPy's documentation](https://numpy.org/doc/stable/reference/random/parallel.html) recommends giving each worker an independent stream. Adding the task's number to a root seed, the obvious alternative, is the one it singles out as unsafe.

[^3]: To the last digit, as long as it runs with the same build of NumPy: the tasks draw the same points whichever way they are run.
