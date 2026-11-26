---
title: "Hybrid MPI: ranks with threads"
description: "One MPI program with threads in each rank (MPI+X): sizing --ntasks-per-node and --cpus-per-task, NUMA domains, pinning ranks with srun --cpu-bind and their threads with OMP_PLACES and OMP_PROC_BIND, and checking where every rank and thread really runs, on Monte Carlo π as mpi4py ranks with a pool of threads each."
output-file: hybrid-mpi
---

The last two pages spread a pool of independent tasks over many nodes. This page is about the other way to use many nodes, one MPI program whose ranks work together, and about the case where each of those ranks also uses threads, which is the most common shape of a large simulation code, and the one where placing things on the cores matters most.

## Why ranks with threads

The simplest way to run an MPI program on whole nodes is one rank per core: 144 ranks on a node of 144 cores. Each rank is a process with its own memory, so each has its own copy of whatever every rank needs, e.g. a table of coefficients, or the boundary values it shares with its neighbours, and all of them exchange messages, even with ranks on the same node.

The alternative is fewer ranks, each with several threads, e.g. 2 ranks per node with 72 threads each. The threads of a rank share its memory, so there is one copy per rank rather than per core, and fewer, larger messages between ranks. This is called *hybrid MPI*, or MPI+X, where the X is whatever provides the threads: OpenMP, most often, in C, C++ or Fortran, but also a threaded library, or Numba.

Which split is fastest depends on the program, so it is worth trying a few. But wherever you put the line, the job has to say how many ranks and how many threads, and both have to land on the right cores. To see what the right cores are, you need to know one more thing about the node.

## NUMA domains

A node of a cluster often has 2 CPUs, in 2 sockets, and each CPU has its own memory attached to it. Every core can read all of the node's memory, but memory attached to the other CPU takes longer to reach than its own. Each CPU with its memory is a *NUMA domain* (from non-uniform memory access), and some CPUs are split into several domains even within one socket.

`lscpu` on a compute node shows them:

``` bash
srun --nodes=1 --ntasks=1 --exclusive lscpu | grep -i numa
```

with a line `NUMA node(s):`, and one line per domain with the CPUs that belong to it, e.g. `NUMA node0 CPU(s): 0-71`. `numactl --hardware`, where it is installed, also shows how much memory each domain has.

A thread runs fastest when the memory it uses is in its own domain. Linux puts a page of memory in the domain of the core that first writes to it, so if a rank's threads move between domains, or a rank's threads are spread over both, some of them end up reading the other domain's memory all the time. So a good place to start is one rank per NUMA domain, with its threads on the cores of that domain, e.g. 2 ranks per node of 2 domains.

::: {.callout-note title="For example"}
A node with two 72-core NVIDIA Grace CPUs has 2 NUMA domains, one per CPU, and `numactl -s` on it shows `membind: 0 1`. One rank per CPU, with 72 OpenMP threads each, is a typical mapping there: `--nodes=2 --ntasks-per-node=2 --cpus-per-task=72`.
:::

## Asking for ranks and threads

Here is Monte Carlo π as a hybrid program: MPI ranks, each running its share of the 64 tasks on a pool of threads, as in [the page on threads](20-threads.md), and rank 0 adding up the hits of all of them.

``` {.python include="../examples/pi-hybrid/pi_hybrid.py"}
```

The part that is MPI+X is short: each rank takes every `size`-th seed, starting from its own rank, runs them on `threads` threads, and `comm.reduce` adds up the hits of all the ranks on rank 0. The threads are Python threads running NumPy, which releases the GIL while it draws the points, so they run at once; in a compiled code, the same structure is an OpenMP loop with a `reduction(+:hits)` clause inside each rank, followed by `MPI_Reduce`.[^1] The rest of the script reports where each rank ran, which is the next section.

It runs in the same environment as [the previous pages](50-mpi4py-futures.md), with mpi4py on the vendor's MPI. The job, on a Cray system:

``` {.bash include="../examples/pi-hybrid/job.sh"}
```

The resources are requested per node. `--ntasks-per-node=2` is 2 ranks on each node, and `--cpus-per-task=4` is 4 CPUs for each rank, so the job is 2 nodes × 2 ranks × 4 CPUs, 16 cores. `--ntasks-per-node` times `--cpus-per-task` should be at most the cores of a node, and on whole nodes, equal to it: for the Grace nodes above, 2 × 72 = 144. Small numbers keep this example quick; on a real run you'd add `--exclusive` and fill the nodes.

Then `srun` places the ranks:

- `--cpus-per-task="$SLURM_CPUS_PER_TASK"` gives each rank its 4 CPUs. The job's `--cpus-per-task` is not always passed on to `srun` (Slurm 22.05 stopped doing so, and later versions differ), and without it, each rank gets one CPU, and its 4 threads share it, the oversubscription at the end of [the page on threads](20-threads.md#seeing-it). So it is safest to repeat it on the `srun` line.
- `--cpu-bind=cores` pins each rank to its own cores, so that the operating system cannot move a rank, and its memory, to another NUMA domain. `verbose` makes `srun` print the mask of CPUs it gives each rank, before the program starts.

`source ../pi/num-threads.sh` sets the number of threads to `SLURM_CPUS_PER_TASK`, here 4, for every threaded library, and the script starts 4 threads of its own.

The script runs as `python -m mpi4py pi_hybrid.py`, rather than `python pi_hybrid.py`, because of what happens when a rank fails. Each rank runs its share on its own, then meets the others at `comm.reduce`. If one rank raises an exception before it gets there, that rank ends, and the others wait at the reduce for a rank that will never come, until the job runs out of time. With `-m mpi4py`, an exception that nothing catches calls `MPI_Abort`, which ends every rank of the job at once, with the traceback in the output. `srun --kill-on-bad-exit=1` does the same from Slurm's side, ending the whole step as soon as one task exits with an error, which works for any MPI program, compiled ones included.

### Threads within the rank

Pinning the rank is half of it. Within its 4 cores, the threads can still move from core to core, and with OpenMP, that is what the other variables of `num-threads.sh` are for. `OMP_PROC_BIND=spread` pins each thread to a place of its own, spread over the CPUs the rank may use, and `OMP_PLACES=threads` makes each logical CPU a place. Since a pinned rank may use only its own CPUs, each rank's threads stay within the rank's cores, and so within its NUMA domain.[^2]

So there are two levels, and each has its own setting: Slurm pins the ranks (`--cpus-per-task` and `--cpu-bind=cores`), and the OpenMP runtime pins the threads within each rank (`OMP_PLACES` and `OMP_PROC_BIND`). Getting one right without the other gives you ranks on the right cores with threads wandering inside them, or threads pinned within a rank that itself wanders over the node.

### Where the ranks go

Which cores a rank gets is set by `srun`'s `--distribution`. By default, Slurm takes each rank's CPUs from one socket and puts the next rank on the next socket, round-robin, so with 2 ranks per node and 2 sockets, each rank gets a socket of its own. That is what you want whenever a socket is one NUMA domain, which is common but not universal, hence the check below.

## Checking where everything runs

None of this shows in the result: π comes out the same wherever the threads run. So check the placement once, on a short run, before relying on it. The job above reports it in two ways.

`--cpu-bind=verbose` makes `srun` print one line per rank, to the job's output, with the node, the rank, and the mask of CPUs it was bound to, as a hexadecimal number: `0xf` is CPUs 0 to 3, `0xf0` is CPUs 4 to 7.

`pi_hybrid.py` reports it from inside, which is what the program actually sees. Each rank reads the CPUs it may run on with `os.sched_getaffinity(0)`, and finds their NUMA domains in `/sys/devices/system/node/node*/cpulist`, the same lists `lscpu` shows. Rank 0 prints one line per rank,

``` text
rank 0 on <node>: 4 threads on CPUs <list>, NUMA node <domain>
```

and then the line every strategy ends with:

``` text
pi = 3.141543 from 4294967296 samples
```

What to look for: every rank has as many CPUs as it has threads; no two ranks on the same node share a CPU; and, with one rank per domain, the two ranks of a node are in different NUMA domains, with each rank in only one. A rank with one CPU, or with CPUs in two domains, is the thing to fix.

The same check in your own program can be as simple as running `srun` with the same options on a command that prints its affinity, before the real one:

``` bash
srun --cpus-per-task="$SLURM_CPUS_PER_TASK" --cpu-bind=verbose,cores \
    bash -c 'echo "$(hostname) rank $SLURM_PROCID: CPUs $(taskset -cp $$ | cut -d: -f2)"'
```

which prints, for each rank, the node and the CPUs it may run on. For the threads within a rank, OpenMP has `OMP_DISPLAY_AFFINITY=TRUE`, which makes the runtime print where each of its threads is pinned, when the first parallel region starts.

While the job runs, `top` on its node, as on [the page on threads](20-threads.md#seeing-it), shows each rank at about 400% CPU when its 4 threads are busy, and less when they share cores.

## Finding the split

Once the placement is right, the number of ranks per node is the one thing left to choose. Keep ranks times threads equal to the cores of the node, and try a few splits, e.g. 2 × 72, 4 × 36, 8 × 18 and 144 × 1 on nodes of 144 cores, on a run long enough to be representative, and compare the elapsed times in `sacct`. Start from one rank per NUMA domain, and let the timings decide. Some programs also have constraints of their own, e.g. a number of ranks that has to divide the grid evenly.

That is the last way of running one computation over many nodes in this part. The [next page](80-workflows.md) is about computations made of many steps, where some need the results of others, and the tools that keep track of what to run when.

[^1]: An MPI program whose threads may call MPI has to say so when it starts, with `MPI_Init_thread`. When only the main thread calls MPI, outside the parallel regions, as here, `MPI_THREAD_FUNNELED` is enough. mpi4py asks for the highest level, `MPI_THREAD_MULTIPLE`, by default.

[^2]: On nodes with two logical CPUs per core, `OMP_PLACES=cores` makes each physical core a place instead, so that two threads of the same rank don't share a core while another core is idle. See the tip on [physical cores](20-threads.md#asking-for-the-cores).
