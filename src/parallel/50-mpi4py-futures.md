---
title: "Python tasks over many nodes with mpi4py.futures"
description: "A pool of worker processes that spans the nodes of a job, from one Python script: MPIPoolExecutor launched with srun python -m mpi4py.futures, rank 0 as the controller and every other rank a worker, how to size --ntasks for it, and what happens when a task fails."
output-file: mpi4py-futures
---

[A job array](40-job-arrays.md) goes beyond one node by letting the scheduler run each task as a job of its own. When your tasks are calls of a Python function, there is another way, which keeps the whole computation in one job and one script: a pool of workers, like the one on the [page on one node](30-one-node.md#a-pool-of-processes-in-python), but with its workers spread over every node of the job.

## Why the pool on one node stops there

`ProcessPoolExecutor` starts its workers by forking or spawning processes, and a process can only start other processes on its own node. So asking Slurm for 2 nodes and running `pi_futures.py` gives you a pool on the first node, and a second node doing nothing, for which you are still charged.

What you need is something that can start processes on every node of the job, and send them work. That is what `srun` and MPI already do for MPI programs, as in [the part on MPI](../mpi/10-intro.md), and [`mpi4py.futures`](https://mpi4py.readthedocs.io/en/stable/mpi4py.futures.html) builds a pool on top of them: `MPIPoolExecutor` has the same interface as `ProcessPoolExecutor`, with MPI ranks as its workers.

## The same π, on MPI ranks

Here is Monte Carlo π that way:

``` {.python include="../examples/pi-mpi4py-futures/pi_mpi4py_futures.py"}
```

Compared with `pi_futures.py` on the one-node page, `ProcessPoolExecutor` became `MPIPoolExecutor`, and it is given no number of workers. Each task also returns the name of the node it ran on, so that the output shows where the work went.

It needs mpi4py, and an mpi4py that works across nodes is the subject of [the page on conda and the vendor's MPI](../mpi/30-conda.md). The examples on this page and on the page on [hybrid MPI](70-hybrid-mpi.md) use its first route, conda-forge's external MPICH bound to the vendor's MPI at run time, with NumPy added:

``` {.yaml include="../examples/pi/environment-mpi.yml"}
```

created as before, with `mamba env create --channel-priority flexible -f environment-mpi.yml`. Then the job, on a Cray system:

``` {.bash include="../examples/pi-mpi4py-futures/job.sh"}
```

The first half is the job script of [the conda page](../mpi/30-conda.md#mpich-from-the-vendor-the-rest-from-conda), loading the vendor's MPI and pointing mpi4py at it. The last line is the new part: `srun` starts 8 ranks, 4 on each node, each running `python -m mpi4py.futures pi_mpi4py_futures.py`, and `--cpu-bind=cores` pins each rank to its own core.

`-m mpi4py.futures` is what turns 8 copies of the script into one pool. It runs before your script, and splits the ranks by their number. Rank 0 runs your script as usual, and when the script creates an `MPIPoolExecutor`, rank 0 is its *controller*, which hands out the tasks and collects the results. Every other rank never runs your script's main part: it waits for tasks from rank 0, runs them, and sends back the results, until the pool is closed.[^1] So the output, from rank 0, starts with `7 workers`, then one line per node with how many of the 64 tasks ran there, and ends with the same line as every other strategy:

``` text
pi = 3.141543 from 4294967296 samples
```

The tasks are handed out as the workers become free, as with `ProcessPoolExecutor`, so a worker that gets a quick task simply gets another one sooner, and the work balances itself even when the tasks take different times.

As on one node, the function the workers run has to be one they can find by name, defined at the top level of a module or of the script, and its arguments and results are pickled and sent over MPI. That is cheap for a seed and a count, and for anything that is small compared with how long the task takes.

## How many ranks

Rank 0 is the controller, not a worker. So with *N* ranks you get *N* − 1 workers, and to get *W* workers, you ask for *W* + 1 ranks.

In the job above, 8 ranks on 8 cores give 7 workers, and the controller's core spends the job mostly waiting. On a real job, with whole nodes, that is one core out of hundreds, and simply not worth thinking about: ask for one rank per core, e.g. `--nodes=4 --ntasks-per-node=144 --cpus-per-task=1` on nodes of 144 cores, which gives 575 workers.

If your tasks use threads themselves, give each rank as many cores as it has threads, as on [the page on threads](20-threads.md#asking-for-the-cores): e.g. `--ntasks-per-node=36 --cpus-per-task=4` on the same nodes, `num-threads.sh 4` in the job, and 143 workers with 4 threads each. Then the controller holds 4 cores to itself, which is the cost of keeping the numbers simple.

And as with any pool, more workers than tasks is a waste: with 64 tasks, any worker beyond the 64th never gets one. On a real problem, you'd want many more tasks than workers, so that the ones that finish early pick up the remaining tasks.

## Without `-m mpi4py.futures`

You may find examples that run the script with plain `python pi_mpi4py_futures.py`, or with `mpiexec -n 1`. Then `MPIPoolExecutor` starts its workers itself, as new MPI processes, with MPI's *dynamic process management* (`MPI_Comm_spawn`). That needs the MPI library, and the batch system, to support starting processes after the job has started, and mpi4py's documentation warns that some vendor MPIs do not, and that batch systems on supercomputers may pose additional complications. So on a cluster, I'd always launch with `srun ... python -m mpi4py.futures`, where every rank is started by `srun` at the beginning, and no spawning is needed.[^2]

## When a task fails

It is the same as [on one node](30-one-node.md#when-a-task-fails): when a task raises an exception on a worker, `MPIPoolExecutor` raises it again on rank 0 when its result is retrieved, so go through the results, as `list(pool.map(...))` does here, and the tasks not yet started are cancelled. Then the exception ends your script on rank 0, and under `-m mpi4py.futures` that ends every rank, so a failed task does not leave the job running until its time limit.

## Limitations

The tasks are Python functions, called from one Python script. For tasks that are commands, a job array, or GNU parallel inside one, is simpler.

All the results come back to rank 0. For a count, that is nothing, but if each task returns a large array, they all travel over the network to one process, and have to fit in its memory together. Then it is better for each task to write its result to a file, and return only the file's name.

It needs an mpi4py that works across nodes, with everything that [the part on MPI](../mpi/10-intro.md) is about. And it is one job: if it runs out of time, the tasks it did not finish are lost, unless each writes its result to a file as it goes, so that a rerun can skip them.

The next page is about DragonHPC, which does the same, a pool of processes spanning the nodes of a job, without MPI, through Python's own `multiprocessing`.

[^1]: If the script on rank 0 fails with an exception it does not handle, it calls `MPI.COMM_WORLD.Abort`, which ends every rank, so a failure doesn't leave the workers waiting until the job runs out of time.

[^2]: mpi4py also has `MPICommExecutor`, which turns the ranks of a program you launched with plain `srun python script.py` into a pool, with rank 0 as the controller: in `with MPICommExecutor() as pool:`, `pool` is the pool on rank 0, and `None` on every other rank. It is useful when you cannot change how the script is launched.
