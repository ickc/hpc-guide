---
title: "DragonHPC: multiprocessing over many nodes"
description: "DragonHPC, a runtime that makes Python's multiprocessing span every node of a job: Monte Carlo π on a Pool over 2 nodes, installing it, how it launches under Slurm, threads in each worker, a distributed dictionary for big results, and its limits: Python 3.11 to 3.13, PyPI only, and a fast transport that is not open source."
output-file: dragon
aliases: [../dragon.html]
---

[The previous page](50-mpi4py-futures.md) spread a pool of Python workers over the nodes of a job. [DragonHPC](https://dragonhpc.github.io/dragon/doc/_build/html/index.html), or Dragon, does it with Python's own `multiprocessing`: it is a runtime that runs on every node of your job, and makes `multiprocessing` start its processes on all of them.

## The same Pool, over many nodes

If you have a script that uses `multiprocessing.Pool`, Dragon's [introduction](https://dragonhpc.github.io/dragon/doc/_build/html/start.html) asks for two changes: `import dragon` before `multiprocessing`, and `set_start_method("dragon")` before anything starts a process. Then you run the script with `dragon script.py` instead of `python script.py`. Here is Monte Carlo π that way:

``` {.python include="../../examples/pi-dragon/pi_dragon.py"}
```

It is the [pool of processes](30-python-pool.md) on one node, as `multiprocessing.Pool` rather than `ProcessPoolExecutor`, with those two changes, and with each task returning the name of its node, so that the output shows where the work went.

`import dragon` replaces the classes of `multiprocessing` with Dragon's own, which is why it has to come first, and `set_start_method("dragon")` selects them. From then on, every process that `multiprocessing` starts, whether by `Process` or by `Pool`, is placed by Dragon, round-robin over the nodes of the job. Libraries that use `multiprocessing` underneath get Dragon too, `concurrent.futures.ProcessPoolExecutor` included.

The number of workers is `mp.cpu_count()`, which under Dragon is the number of CPUs of all the nodes together, so one worker per CPU of the job. It counts every CPU of each node, whichever ones the job may use, which is why the job asks for whole nodes. On a node shared with other jobs, give the pool a number of workers yourself, and on nodes with two logical CPUs per core, use half as many, as in the tip on [physical cores](../20-threads.md#asking-for-the-cores).

When a task raises an exception, `pool.map` raises it again in your script, once every task has finished, as [`multiprocessing.Pool`](https://docs.python.org/3/library/multiprocessing.html#multiprocessing.pool.AsyncResult.get) does on one node.

## Installing it

Dragon is on PyPI as `dragonhpc`, and only there. It supports Python 3.11, 3.12 and 3.13, with wheels for Linux on x86-64 and on aarch64 (and for macOS). So the environment is a conda environment with Python and NumPy, and pip for Dragon:

``` {.yaml include="../../examples/pi-dragon/environment.yml"}
```

The Python version is pinned to one that Dragon supports. Dragon needs no MPI, no compiler, and nothing from the system's modules, since everything it needs is in its wheel.

On more than one node, Dragon prints a message at run time about its transport, the part that carries data between nodes, until you tell it which one to use. In the open-source version, that is TCP, which you configure once, after creating the environment:

``` bash
conda activate pi-dragon
dragon-config add --tcp-runtime=True
```

## The job

``` {.bash include="../../examples/pi-dragon/job.sh"}
```

`--nodes=2 --exclusive` asks for 2 whole nodes, and there is no `srun` in the script. `dragon` is the launcher: inside a Slurm job, it starts its runtime on every node of the job itself, with an `srun` of its own, one process per node, and with `--cpu_bind=none`, so that Slurm pins nothing and Dragon decides where its processes run. Your script runs once, as the *head* process, and the workers of its pool are processes on all the nodes, started by the runtime.

The output starts with the number of workers, the CPUs of the 2 nodes, then one line per node with the number of tasks that ran there, and ends with

``` text
pi = 3.141543 from 4294967296 samples
```

followed by a line of Dragon's own, `+++ head proc exited, code 0`, when the head process ends.

Outside a job, on a login node of a cluster with Slurm, `dragon` refuses to start, with `RuntimeError: Executing in a Slurm environment, but with no job allocation.` `dragon -s script.py` forces it to run on the node you are on, which is how you'd try a script out in an interactive job on one node, and `dragon --nodes 2` uses only 2 of the nodes of a larger job.

## Threads in each worker

The example has one thread per worker, as `num-threads.sh 1` says. If each task uses threads, say 4, a pool of `mp.cpu_count() // 4` workers, with `num-threads.sh 4`, keeps the job's CPUs busy without oversubscription.

Nothing pins the workers, though: with `--cpu_bind=none`, those of a `multiprocessing.Pool` may run on any CPU of their node. The `Pool` of Dragon's native API takes a *policy*, which can set the CPUs each process may run on (`cpu_affinity`), and is where to start if your threads need pinning.

## Big results

`pool.map` sends every result back to the head process, so large results all land in its memory. For those, Dragon has a [distributed dictionary](https://dragonhpc.github.io/dragon/doc/_build/html/ref/dragon/dragon.DDict.html), `DDict`, whose contents are spread over the memory of the nodes, and which every process of the job can read and write. A task can store its large result in it under a key, and return only the key, and the next step reads it from there, without the head process ever holding all of it.

## Limitations

- **Python 3.11 to 3.13 only.** A newer Python, or an older one, has no Dragon, which matters if your environment is pinned for other reasons.
- **Only on PyPI.** It is not on conda-forge, nor in Spack, as of November 2026, so it comes into a conda environment through pip, with the usual care about mixing the two.
- **The fast transport is not open source.** Between nodes, the open-source version carries data over TCP. The high-speed transport, for Slingshot or InfiniBand, is [not part of it](https://dragonhpc.github.io/dragon/doc/_build/html/uses/multinode.html).
- **Not all of `multiprocessing`.** `Manager`, `sharedctypes`, `Listener`, `Client` and `multiprocessing.dummy` are [not implemented](https://dragonhpc.github.io/dragon/doc/_build/html/devguide/multiprocessing.html#limitations), and file descriptors cannot be shared between processes, which some code relies on.
- **It is young.** At version 0.15, its interfaces may still change.

The [next page](../30-hybrid-mpi.md) is about the other side of using many nodes: one MPI program whose ranks communicate, with threads inside each rank, and placing both on the cores.
