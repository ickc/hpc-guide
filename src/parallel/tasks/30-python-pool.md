---
title: "A pool of processes in Python"
output-file: python-pool
description: "Running many Python tasks at once inside one job, on a pool of processes with concurrent.futures, and what it takes for an exception in a task to reach your script."
---

If your tasks are calls of a Python function, Python's standard library can run them on a pool of processes, from one script:

``` {.python include="../../examples/pi-futures/pi_futures.py"}
```

`ProcessPoolExecutor` starts the worker processes once, and `pool.map` hands each of them a seed, gets back the hits, and hands it the next, so Python and NumPy are imported once per worker, not once per task. The results come back in order, and here they are added up directly, so no files are needed in between. The job is the same as the others, with 8 CPUs:

``` {.bash include="../../examples/pi-futures/job.sh"}
```

The number of workers is `len(os.sched_getaffinity(0))`, the number of CPUs this process may run on, which in a job is the CPUs the job was given. `os.cpu_count()` is the number of CPUs of the whole node, and on a node shared with other jobs, a pool of that size is oversubscription.[^1]

The pool is started under `if __name__ == "__main__":`. Depending on the platform and the version of Python, worker processes may start by importing your script afresh, and without that line, each of them would start a pool of its own.[^2]

The older interface, `multiprocessing.Pool`, does the same, with `pool.map` too. And if your function spends its time in NumPy, or anything else that releases the GIL, `ThreadPoolExecutor` from the [page on threads](../20-threads.md) does it in one process, with nothing copied between processes.

### When a task fails

A pool runs your function in other processes, so when a task raises an exception, it is raised in a worker, where you don't see it. The pool catches it and raises it again in your script, but only when you ask for that task's result. `pool.map` returns an iterator of the results, and it is going through it, here with `sum`, that asks for them: the exception of the first task that failed is raised there, and the tasks not yet started are cancelled.[^3] So always go through the results. A `pool.map(...)` whose results nobody reads, or a `pool.submit(...)` whose future nobody calls `.result()` on, loses its exceptions without a word, and the script ends as if every task had succeeded.

If you'd rather run every task and collect the failures at the end, than stop at the first one, catch the exception in the task itself, and return it with the task's input:

``` python
def task(seed):
    try:
        return seed, pi.count_hits(seed), None
    except Exception as e:
        return seed, None, repr(e)
```

Then every result says which seed it was, and whether it failed, and the script can list the failed ones, to rerun only those.

[map_parallel](https://ickc.github.io/python-map_parallel/), a package I wrote, is a complete example of this pattern: a drop-in replacement for `map`, on a pool of processes, of threads, or of MPI ranks, with the care above taken for each of them, so that an exception in any task is raised in your script.

This gives the same π as the baseline, about 8 times faster, and it stops at the edge of the node. The [next page](40-job-arrays.md) is about going beyond it, with the scheduler running the tasks for you.

[^1]: Since Python 3.13, `os.process_cpu_count()` is the same as `len(os.sched_getaffinity(0))`, and it is what `ProcessPoolExecutor` uses when you give it no `max_workers`. Before 3.13, the default was `os.cpu_count()`.

[^2]: How workers start is the *start method*. On Linux, it was `fork` until Python 3.14, which [changed the default](https://docs.python.org/3/library/concurrent.futures.html#processpoolexecutor) to one that does not fork the parent, since forking a process that has threads running can deadlock.

[^3]: And leaving the `with` block, as the exception goes up, waits for the tasks that were already running, so the script stops once they have finished.
