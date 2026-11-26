---
title: "DragonHPC: multiprocessing over many nodes"
description: "DragonHPC, a runtime that makes Python's multiprocessing span every node of a job: what it is and how it launches under Slurm, Monte Carlo π on a Pool over 2 nodes, where it sits next to mpi4py.futures, Parsl and dask, and its limits: Python 3.11 to 3.13, pip only, and a fast transport that is not open source."
output-file: dragon
---

[The previous page](50-mpi4py-futures.md) spread a pool of Python workers over many nodes with MPI underneath. [DragonHPC](https://dragonhpc.github.io/dragon/doc/_build/html/index.html), or Dragon, does the same without MPI: it is a runtime that runs on every node of your job, and makes Python's own `multiprocessing` start its processes on all of them.

## The same Pool, over many nodes

If you have a script that uses `multiprocessing.Pool`, Dragon's [introduction](https://dragonhpc.github.io/dragon/doc/_build/html/start.html) asks for two changes: `import dragon` before `multiprocessing`, and `set_start_method("dragon")` before anything starts a process. Then you run the script with `dragon script.py` instead of `python script.py`. Here is Monte Carlo π that way:

``` {.python include="../examples/pi-dragon/pi_dragon.py"}
```

It is the pool of the [one-node page](30-one-node.md#a-pool-of-processes-in-python), as `multiprocessing.Pool` rather than `ProcessPoolExecutor`, with those two changes, and with each task returning the name of its node, as on the previous page.

`import dragon` is what makes this work: it replaces the classes of `multiprocessing` with Dragon's own, which is why it has to come first, and `set_start_method("dragon")` selects them.[^1] From then on, every process that `multiprocessing` starts, whether by `Process` or by `Pool`, is placed by Dragon, round-robin over the nodes of the job. Since it is `multiprocessing` itself that is replaced, libraries that use it underneath get Dragon too. `concurrent.futures.ProcessPoolExecutor`, which starts its workers through `multiprocessing`, also runs on it as it is.

The number of workers is `mp.cpu_count()`. With Dragon, that is the number of CPUs of all the nodes together, so one worker per CPU of the job.[^2]

## Installing it

Dragon is on PyPI as `dragonhpc`, and only there. It supports Python 3.11, 3.12 and 3.13, with wheels for Linux on x86-64 and on aarch64 (and for macOS). So the environment is a conda environment with Python and NumPy, and pip for Dragon:

``` {.yaml include="../examples/pi-dragon/environment.yml"}
```

The Python version is pinned to one that Dragon supports. Dragon needs no MPI, no compiler, and nothing from the system's modules, since everything it needs is in its wheel.

On more than one node, Dragon prints a message at run time about its transport, the part that carries data between nodes, until you tell it which one to use. In the open-source version, that is TCP, which you configure once, after creating the environment:

``` bash
conda activate pi-dragon
dragon-config add --tcp-runtime=True
```

## The job

``` {.bash include="../examples/pi-dragon/job.sh"}
```

`--nodes=2 --exclusive` asks for 2 whole nodes, and there is no `srun` in the script. `dragon` is the launcher: when it finds that it runs inside a Slurm job, it starts its runtime on every node of the job itself, with an `srun` of its own, one process per node, and with `--cpu_bind=none`, so that Slurm pins nothing and Dragon decides where its processes run.[^3] Your script runs once, as the *head* process, and the workers of its pool are processes on all the nodes, started by the runtime.

The output starts with the number of workers, the CPUs of the 2 nodes, then one line per node with the number of tasks that ran there, and ends with

``` text
pi = 3.141543 from 4294967296 samples
```

followed by a line of Dragon's own, `+++ head proc exited, code 0`, when the head process ends.

Outside a job, on a login node of a cluster with Slurm, `dragon` refuses to start, with `RuntimeError: Executing in a Slurm environment, but with no job allocation.` `dragon -s script.py` forces it to run on the node you are on, which is how you'd try a script out in an interactive job on one node, and `dragon --nodes 2` uses only 2 of the nodes of a larger job.

## What it is underneath

Dragon is not a layer over MPI. It has its own communication layer, which it calls *Channels*, in shared memory within a node, and through a *transport agent* between nodes. So it does its own message passing, independently of MPI, and none of the questions of [the part on MPI](../mpi/10-intro.md), which MPI and whether it was built for the network, apply to it.

There are two transport agents. The TCP agent is the default for the open-source package, and sends data between nodes over TCP, on whichever network interface it picks.[^4] The other is *HSTA*, the high-speed transport agent, which uses libfabric or UCX for "MPI-like performance" over Slingshot or InfiniBand, and is configured with `dragon-config add --ofi-runtime-lib=...` or `--ucx-runtime-lib=...`, pointing at the directory with the system's `libfabric.so` or `libucp.so`. HSTA is not open source: Dragon's [page on running across nodes](https://dragonhpc.github.io/dragon/doc/_build/html/uses/multinode.html) says that it "is currently not available in the opensource version of Dragon", and to contact HPE about it, and its source is not in the [repository](https://github.com/DragonHPC/dragon), which has the TCP agent. Yet the wheel on PyPI, as of version 0.15.0, does include a compiled `dragon-hsta`, with back ends for libfabric and UCX. So the wheel and the documentation disagree, and the fast transport, if you use it, is a binary you cannot rebuild yourself.

Underneath the Python, the same layer is available from other languages. The lower-level *native* API is described as having cross-language support for C, C++ and Fortran, the documentation has a C reference for Channels and its other core pieces, and `dragon-config -l` and `-o` print the options to compile and link a program against Dragon's C and C++ API. So a compiled program can talk to Python processes in the same runtime, but it does so through Dragon's API, not through MPI.

## Where it sits

I think it is closest to `mpi4py.futures`, from the previous page. Both run inside one allocation, from one script, as a pool of workers spread over its nodes, with tasks handed out as workers become free. The differences: Dragon needs no MPI, and so none of the work of getting an MPI that spans the nodes; its head process is not one of the job's ranks, so there is no controller rank to size for; and what it gives you is the whole `multiprocessing` API, `Process`, `Queue`, `Pipe`, locks, and pools inside pools, rather than an executor. In exchange, `mpi4py.futures` works with any MPI program and any Python, and comes with mpi4py, which is on conda-forge and in Spack.

It is less like [Parsl](https://parsl.readthedocs.io/en/stable/), which is a workflow system: Parsl gets its resources by asking a *provider*, such as Slurm, for *blocks* of nodes, i.e. jobs it submits for you, and runs its tasks on workers inside them, so it decides how many jobs to submit, and can grow and shrink. Dragon starts from the job you already have. The two can also be combined: Dragon has an experimental executor for Parsl, which runs Parsl's tasks on a Dragon pool.

And it is less like [dask](https://docs.dask.org/en/stable/), whose distributed scheduler runs tasks on workers too, but whose point is its parallel arrays and dataframes, built on top of them. The nearest thing Dragon has to that is its distributed dictionary, below.

## Big results, and the head process

`Pool.map` sends every result back to the head process, as with `mpi4py.futures`, so large results all land in one process's memory. Dragon's answer is the *distributed dictionary*, `DDict`: a dictionary whose contents are spread over the memory of the nodes, and which every process of the job can read and write, through Channels. A task can store its large result in it under a key, and return only the key, and the next step reads it from there, without the head process ever holding all of it. Dragon's documentation suggests it also as a cache of data read once from the filesystem, and in place of intermediate files between the stages of a pipeline.

## Threads in each process

The example has one thread per worker, as `num-threads.sh 1` says. If each task uses threads, the arithmetic is the one of the previous page: a pool of `mp.cpu_count() // 4` workers, with `num-threads.sh 4`, keeps the job's CPUs busy without oversubscription.

Pinning is less simple. Dragon's `srun` uses `--cpu_bind=none`, so Slurm doesn't pin anything, and the workers of a `multiprocessing.Pool` may run on any CPU of their node. The native API's `Pool` takes a *policy*, which can set the CPUs a process may run on (`cpu_affinity`), so the pieces are there to give each worker its own set of cores and let OpenMP's `OMP_PLACES` and `OMP_PROC_BIND` work within it. But Dragon's documentation has no worked example of that combination, so for a program that is threads inside processes and needs careful placement, the [next page](70-hybrid-mpi.md), with MPI, is the well-trodden way.

## Scale

Dragon's introduction says that they "regularly test Dragon `Pool()` with over 50,000 workers on hundreds of nodes on a Cray EX supercomputer". Its benchmarks include a [comparison with a pool written in MPI](https://dragonhpc.github.io/dragon/doc/_build/html/benchmarks/pool_v_mpi.html), on a Cray EX with Slingshot: for tasks of equal length, MPI was faster on one node and equal up to 4 nodes, and Dragon was 32 times faster on 32 nodes, which they attribute to how Dragon handles many workers reporting back to one process at once; for tasks of unequal length, Dragon was faster throughout. Those are the developers' own numbers, on their own system, and the documentation gives no figure for the latency of a single task.

## Limitations

- **Python 3.11 to 3.13 only.** A newer Python, or an older one, has no Dragon, which matters if your environment is pinned for other reasons.
- **Only on PyPI.** It is not on conda-forge, nor in Spack, as of November 2026, so it comes into a conda environment through pip, with the usual care about mixing the two.
- **The fast transport is not open source**, as above. With the open-source TCP agent only, data between nodes goes over TCP.
- **Not all of `multiprocessing`.** Its documentation lists `Manager`, `sharedctypes`, `Listener`, `Client` and `multiprocessing.dummy` as not implemented, and file descriptors cannot be shared between processes, which some code relies on.
- **It is young.** At version 0.15, its interfaces may still change, and its documentation is behind its releases in places, as with HSTA above.

None of these matter for the Monte Carlo π here, and if your code is already a `multiprocessing` pool, trying it on 2 nodes costs two lines. But for most people, I'd say `mpi4py.futures` or a job array is the safer default, and Dragon the one to try when a pool is limited by one node and getting MPI right is the obstacle.

The [next page](70-hybrid-mpi.md) is about the other side of using many nodes: one MPI program whose ranks communicate, with threads inside each rank, and placing both on the cores.

[^1]: Dragon's documentation calls this *patching*: `import dragon` swaps Dragon's classes into `multiprocessing` before your code subclasses any of them, which is also why switching the start method back to another one in the middle of a program breaks classes that inherit from `multiprocessing`'s.

[^2]: All the CPUs, regardless of which ones the job may use: restricted to 8 of a workstation's 32 CPUs with `taskset`, `mp.cpu_count()` under Dragon still returns 32. That is why the job asks for whole nodes. On a node shared with other jobs, give the pool a number of workers yourself. And on nodes with two logical CPUs per core, use half as many workers, as in the tip on [physical cores](20-threads.md#asking-for-the-cores).

[^3]: That is from Dragon's source, `dragon/launcher/wlm/slurm.py` in version 0.15.0, which runs `srun --nodes=N --ntasks=N --cpu_bind=none` over the nodes of the job. It also supports PBS, and, without a scheduler, a launch over `ssh` to a list of hosts, which needs password-less `ssh` between all of them.

[^4]: By default, it prefers the interfaces of the high-speed networks of Cray systems, named `hsn` on Slingshot, and `--network-prefix` chooses another. A prefix that matches no interface makes the runtime hang, according to its documentation.
