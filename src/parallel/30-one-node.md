---
title: "Many tasks on one node"
description: "Running many independent tasks at once inside one job: GNU parallel with a task list, a job log and resuming what failed, and in Python, a pool of processes with concurrent.futures, or map_parallel as a drop-in for map."
output-file: one-node
---

[Threads](20-threads.md) use many cores from one process. This page is about the other common case on one node: many independent tasks, each its own process, run as many at a time as the job has cores, inside one job.

## The loop you may be tempted to write

Say you have 64 tasks, and a job with 8 cores. In bash, the first thing that comes to mind is to start them all in the background and wait:

``` bash
for seed in $(seq 1 64); do
    python ../pi/pi.py count "$seed" > "results/$seed.txt" &
done
wait
```

This works, in the sense that it finishes. But it starts all 64 at once, on 8 cores, which is [oversubscription](20-threads.md#oversubscription), and with 64,000 input files instead of 64 seeds, it starts 64,000 processes at once, which may well hit the limit on how many processes you can have. And if a task fails, nothing tells you which one: `wait` without arguments returns 0 whatever happened. Limiting it to 8 at a time, and keeping track of which ones failed, is doable in bash, and it is exactly what GNU parallel already does.

## GNU parallel

[GNU parallel](https://www.gnu.org/software/parallel/) takes a command and a list of inputs, and runs the command once for each input, a given number at a time, starting the next as soon as one finishes. It is on many clusters already, as a module or in the system, and it is on conda-forge as `parallel`, which is why it is in the [environment](10-intro.md) of these examples. Here it runs the 64 tasks of Monte Carlo π, 8 at a time:

``` {.bash include="../examples/pi-parallel/job.sh"}
```

where `tasks.txt` is the task list, one line per task, here simply the numbers 1 to 64, made with `seq 1 64 > tasks.txt`. In your case a line may be an input file, or a set of parameters.

`:::: tasks.txt` gives the inputs, one per line of the file, and `{}` in the command is replaced by each one, so the first task runs `python ../pi/pi.py count 1 > results/1.txt`. The command is in single quotes so that the `>` belongs to each task, rather than to `parallel` itself. Each task writes its result to a file of its own, and the last line of the job, the reduce, adds them up.[^1]

`--jobs "$SLURM_CPUS_PER_TASK"` runs as many tasks at a time as the job has CPUs. Without it, GNU parallel runs one per CPU it can see, which usually matches the job, but saying so costs nothing.[^2]

`--joblog joblog.tsv` writes a line for every task that finished: when it started, how long it ran, its exit status, and the command. The start of it, from one run:

``` text
Seq Host    Starttime   JobRuntime  Send    Receive Exitval Signal  Command
1   :   1795722230.994       0.970  0   0   0   0   python ../pi/pi.py count 1 > results/1.txt
3   :   1795722230.995       0.970  0   0   0   0   python ../pi/pi.py count 3 > results/3.txt
4   :   1795722230.996       0.968  0   0   0   0   python ../pi/pi.py count 4 > results/4.txt
```

That log is what makes failures cheap. If some tasks failed, `parallel` exits with the number of tasks that failed, so with `set -e` the job fails too, and the reduce doesn't run on incomplete results. Then you fix the problem, add `--resume-failed` to the same `parallel` command, and resubmit: it reads the log, runs again only the tasks that failed, and the ones that never ran, e.g. because the job ran out of time, and skips the rest. For that to work, the command, the task list, and the log have to stay as they were, since GNU parallel matches the tasks by their line numbers.

### Its citation notice

GNU parallel is free software, under the GPL, which puts no condition on running it. What it does have is a request. Its author asks that if you use it to process data for an article in a scientific publication, you cite it, and run interactively, `parallel` says so: it prints a notice asking you to cite it, once you have run it a few times without telling it you will. The notice says that this helps fund its development, and that if you'd rather pay 10,000 EUR, you don't have to cite it.

`parallel --citation` prints the notice and the reference to cite, BibTeX included, and silences the notice from then on. In a batch job, the notice doesn't appear at all, since it is only printed when its output goes to a terminal. Its documentation also asks you not to put `--will-cite`, which silences it for one run, in scripts that other people run, since they would then never see the request. GNU parallel's [design documentation](https://www.gnu.org/software/parallel/parallel_design.html#citation-notice) explains the reasoning, and points out that since the request is not a legal requirement, it is compatible with the GPL.

So the one thing to do, if you publish results that GNU parallel helped make, is to cite it.

### Limitations

GNU parallel runs its tasks on the node it is started on.[^3] So it is for as many tasks as one node can get through in the time of one job.

Each task is a new process, so each one pays to start: for `pi.py`, Python, and importing NumPy, which reads many files from the shared filesystem. When each task takes minutes, that doesn't matter. When there are many thousands that take a second each, it does, and then it is better to run the tasks inside one long-lived process, which is what the rest of this page is about, at least when your tasks are Python functions.

## A pool of processes in Python

If your tasks are calls of a Python function, Python's standard library can run them on a pool of processes, from one script:

``` {.python include="../examples/pi-futures/pi_futures.py"}
```

`ProcessPoolExecutor` starts the worker processes once, and `pool.map` hands each of them a seed, gets back the hits, and hands it the next, so Python and NumPy are imported once per worker, not once per task. The results come back in order, and here they are added up directly, so no files are needed in between. The job is the same as the others, with 8 CPUs:

``` {.bash include="../examples/pi-futures/job.sh"}
```

Two details matter on a cluster.

The number of workers is `len(os.sched_getaffinity(0))`, the number of CPUs this process may run on, which in a job is the CPUs the job was given. `os.cpu_count()`, the obvious choice, is the number of CPUs of the whole node. On a node shared with other jobs, a pool of that size is oversubscription.[^4]

The pool is started under `if __name__ == "__main__":`. Depending on the platform and the version of Python, worker processes may start by importing your script afresh, and without that line, each of them would start a pool of its own.[^5]

The older interface, `multiprocessing.Pool`, does the same, with `pool.map` too. And if your function spends its time in NumPy, or anything else that releases the GIL, `ThreadPoolExecutor` from the [page on threads](20-threads.md) does it in one process, with nothing copied between processes.

### map_parallel

[map_parallel](https://ickc.github.io/python-map_parallel/), a package I wrote, wraps those pools, and others, behind one function, which is a drop-in replacement for `map`:

``` {.python include="../examples/pi-map-parallel/pi_map_parallel.py"}
```

The serial version is the comment: `map` becomes `map_parallel`, and the rest is the same. By default it runs on a pool of processes, as above, and its `mode` argument switches the backend without changing anything else: `mode="multithreading"` for threads, or `mode="mpi"` for `mpi4py.futures`, which goes beyond one node. It is on PyPI as `map-parallel` and on conda-forge as `map_parallel`, and its [documentation on choosing a backend](https://ickc.github.io/python-map_parallel/backends/) goes through which one suits which kind of work.

The job is the same as for the pool, running `pi_map_parallel.py` instead.

All of these, GNU parallel and the pools in Python, give the same π as the baseline, about 8 times faster, and all of them stop at the edge of the node. The [next page](40-job-arrays.md) is about going beyond it, with the scheduler running the tasks for you.

[^1]: GNU parallel also takes inputs directly on the command line, `parallel 'python ../pi/pi.py count {}' ::: 1 2 3`, with three colons, or from its standard input, `seq 1 64 | parallel ...`, which the [next page](40-job-arrays.md) uses.

[^2]: Each task here is a process with one thread, which is why the job sources `num-threads.sh 1` first. If each of your tasks uses, say, 4 threads, run a quarter as many at a time, `--jobs $((SLURM_CPUS_PER_TASK / 4))`, with `num-threads.sh 4`. To also pin each task to 4 cores of its own, `{%}` in the command is the number of the job slot the task runs in, from 1 to the number of `--jobs`, so `taskset -c $(( ({%} - 1) * 4 ))-$(( {%} * 4 - 1 ))` gives each running task a different set of cores.

[^3]: It can also start tasks on other computers, over `ssh`. On a cluster, the nodes of your job are usually not reachable that way, or only with care, and the way through the scheduler on the [next page](40-job-arrays.md) is simpler.

[^4]: Since Python 3.13, `os.process_cpu_count()` is the same as `len(os.sched_getaffinity(0))`, and it is what `ProcessPoolExecutor` uses when you give it no `max_workers`. Before 3.13, the default was `os.cpu_count()`.

[^5]: How workers start is the *start method*. On Linux, it was `fork` until Python 3.14, which [changed the default](https://docs.python.org/3/library/concurrent.futures.html#processpoolexecutor) to one that does not fork the parent, since forking a process that has threads running can deadlock.
