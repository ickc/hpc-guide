---
title: "When a job fails"
output-file: failed-jobs
description: "A checklist for a job that failed, or ran but not the way it should: the software not loaded, the wrong environment, out of memory, out of time, ranks spread unevenly over the nodes, oversubscription, a race condition, and a job that never starts, each with how it shows up and where in this guide the fix is."
---

[The previous page](30-job-usage.md) was about reading what a job used. The same record, together with the job's output, is where to start when a job fails. This page is a checklist: first where to look, then the ways a job commonly goes wrong, each with how it shows up and where in this guide the fix is. Some of them are not failures at all, as far as Slurm is concerned: the job ends as `COMPLETED`, and is just slow, or wrong.

## Where to look first

Two places, every time. The end of the job's output, where the error message usually is,

``` bash
tail -n 30 slurm-<job ID>.out
```

and what Slurm recorded about it,

``` bash
sacct -j <job ID> --format=JobID,State,ExitCode,Elapsed,Timelimit,ReqMem,MaxRSS
```

which [the previous page](30-job-usage.md#after-the-job-ends-sacct) goes through column by column. Between the two, the error message and the `State`, you can usually tell which item below you are looking at.

One thing to know about `State`: Slurm judges the job by the exit code of the script, which is the exit code of its last command. So if your program fails halfway through the script, and a later command such as `echo done` succeeds, the job is `COMPLETED`, and the failure is only in the output. Putting

``` bash
set -eo pipefail
```

near the top of the script, after the `#SBATCH` lines, makes the script stop at the first command that fails, with that command's exit code, so that the failure shows in `sacct` too.[^1]

## The checklist

- **The software is not there.** The job fails within seconds, as `FAILED`, with an error that ends in one of

  ``` text
  mytool: command not found
  ModuleNotFoundError: No module named 'numpy'
  error while loading shared libraries: libgomp.so.1: cannot open shared object file: No such file or directory
  ```

  The first two are a program, or a Python package, that the job cannot find; the third is a compiled program that starts, but cannot find a library it was built against. Here, `libgomp` is the OpenMP library of the GCC compiler: the program was compiled on the login node with a compiler module loaded, and the job did not load it. In each case, the software is installed, but the job doesn't have the environment that makes it visible, usually because the environment was set up in your terminal rather than in the script: a `module load`, a `conda activate`, or a tool such as direnv that sets things up when you `cd` into your project's directory. Or the script starts with `module purge`, which undoes what the job inherited. The fix is to set up the environment in the script itself, which [the part on software environments](../software/10-intro.md) shows how, for [modules](../software/package-managers/20-modules.md#modules-in-a-job), [conda](../software/package-managers/30-conda.md#using-the-environment-in-a-batch-job) and [pixi](../software/package-managers/40-pixi.md#using-it-in-a-batch-job).

- **The wrong environment.** The environment loads, but it is not the right one for this job, or for these nodes. A program built for another CPU architecture fails with `cannot execute binary file: Exec format error`, which happens when the login nodes and the compute nodes are of different kinds, and is what an [architecture-dependent prefix](../software/10-intro.md#where-to-put-your-environments) prevents. With MPI, it is an environment whose mpi4py, or whose program, was built against another MPI than the one the job runs on: it fails with an error from mpi4py when it starts, or, worse, does not fail at all, but every rank thinks it is alone, rank 0 of a world of 1, and does the whole job by itself. [The section on MPI](../software/mpi/20-check.md) has a check for that, and [the ways to build an environment](../software/mpi/30-conda.md) on the vendor's MPI.

- **Out of memory.** The job ends as `OUT_OF_MEMORY`, or on some clusters as `FAILED`. Its output stops without a traceback or an error from your program, since the kernel killed it outright, with the signal `SIGKILL`, which no program can catch, and the last line is from Slurm's `slurmstepd`, saying it detected an `oom_kill` event. Where the shell reports the exit code of the program, it is 137, which is 128 plus 9, the number of `SIGKILL`. To see it, run the example of [the previous page](30-job-usage.md#an-example) with too little memory, `sbatch --mem=256M job.sh`: on a cluster that enforces the limit, the line it prints at the end never appears. The fix is to measure the peak memory, as on that page, and ask for it with `--mem`, plus a margin. On a cluster that gives each core a share of the node's memory by default, asking for more cores also gets you more memory, but cores your program doesn't use sit idle, charged to you, so asking for the memory itself is better. Or make your program need less, e.g. by working on its data in chunks rather than all at once, as the [Monte Carlo π example](../parallel/10-intro.md) does.

- **Out of time.** The job ends as `TIMEOUT`, with an `Elapsed` equal to its `Timelimit`, and its output ends with a line like

  ``` text
  slurmstepd: error: *** JOB <job ID> ON <node> CANCELLED AT <time> DUE TO TIME LIMIT ***
  ```

  At the limit, Slurm sends the job a signal to stop, and kills it outright a little later if it is still running.[^2] If the job really needed more time, ask for it, as on [the previous page](30-job-usage.md#asking-for-the-right-resources), up to what the partition allows, or split the work into jobs that each fit. But first check that it was working all that time. If the output stops long before the end, the job may have been waiting for something that never happened: in an MPI program, a rank that failed early, with a traceback in the output, leaves the others waiting for it at the next point where they all meet, until the time runs out. [The page on hybrid MPI](../parallel/30-hybrid-mpi.md) has the fix, `python -m mpi4py` or `srun --kill-on-bad-exit=1`, which end every rank as soon as one fails. And a job that was working all along, but slower than you expected, may be one of the next two items.

- **Ranks spread unevenly over the nodes.** An MPI job runs to the end, without an error, but is slower than the arithmetic says it should be. Unless you give `--ntasks-per-node`, Slurm promises only the number of ranks and the number of nodes, not how many ranks go on each node. With a number of ranks that does not divide by the number of nodes, e.g. 6 ranks on 4 nodes, some nodes get 2 ranks and others 1. If every rank runs the same number of threads, the nodes with 2 ranks have twice the threads of the others, and so either more threads than cores, or, if the threads were sized for those nodes, the nodes with 1 rank leave half their cores idle. Either way, the job finishes when its busiest node does. `srun hostname | sort | uniq -c`, inside the job, with the same options as the real `srun`, counts the ranks on each node. The fix is a number of ranks that is a multiple of the number of nodes, given as `--ntasks-per-node`, with ranks times threads equal to the cores of a node, which [the page on hybrid MPI](../parallel/30-hybrid-mpi.md#asking-for-ranks-and-threads) goes through.

- **Oversubscription.** The job runs to the end, without an error, but slower than it should, sometimes several times slower. More threads are running than the job has cores, so they take turns. It happens when a library starts a thread for every core of the node rather than for every core of the job, or when every one of many processes starts a full set of threads, or when `srun` starts tasks without `--cpus-per-task`, so that each task gets one core, whatever `OMP_NUM_THREADS` says. In `top` on the node, a process with many threads at about 100% CPU, one core's worth, is the sign. [The page on threads](../parallel/20-threads.md#oversubscription) explains it, with an example, and the environment variables that prevent it.

- **A race condition.** The job runs to the end, as `COMPLETED`, but the result is wrong, and different every time you run it, while the same program with one thread, or one task, gets it right. Two or more threads, or tasks, are updating the same thing at the same time, and some of the updates are lost. Between threads, it is typically a loop that adds to one counter from every thread: in OpenMP, a `#pragma omp parallel for` that adds to a shared variable without a `reduction(+:hits)` clause, or in Numba, a `prange` loop that adds into an element of an array, which Numba does not turn into a reduction as it does for a plain variable. Between tasks, it is tasks writing to the same file, e.g. the tasks of a job array whose output files have the same name, or the ranks of an MPI program that each think they are rank 0 and all write rank 0's files. The fix between threads is a reduction, where each thread adds up its own share and the shares are added together at the end, as in [the hybrid MPI example](../parallel/30-hybrid-mpi.md#asking-for-ranks-and-threads), and between tasks, a file of its own for each, as in [the job arrays example](../parallel/tasks/40-job-arrays.md#one-submission-for-many-jobs). Either way, check a parallel result against one from a single thread before you trust it, on a small problem.

- **A job that never starts.** The job stays `PD`, pending, and the reason in the last column of `squeue --me` says why. `(Priority)` and `(Resources)` are a normal wait, and `squeue --me --start` may tell you for how long. `(DependencyNeverSatisfied)` is a job that waits for another job that failed, as [the page on job arrays](../parallel/tasks/40-job-arrays.md#the-reduce-after-every-task) explains, and it will never start, so cancel it. A reason naming a limit, e.g. `(PartitionTimeLimit)`, or `(ReqNodeNotAvail)`, means it asked for more than the partition allows, or for nodes that are not available. Some clusters reject such a job when you submit it, and others leave it in the queue; either way, change the request.

Most of these come down to the environment, or to what the job asked for. The environment is the subject of [the next part](../software/10-intro.md), Software environments, which starts with why installing software on a cluster is different from on your laptop.

[^1]: `-e` stops the script at the first command that fails. `-o pipefail` makes a pipeline, e.g. `python analysis.py | tee log.txt`, count as failed if any command in it fails, rather than only if the last one, here `tee`, does.

[^2]: The first is `SIGTERM`, which a program can catch to save its state, and the second `SIGKILL`, after a grace period of 30 seconds by default (`KillWait` in `scontrol show config`). Some programs do save their state when they get `SIGTERM`. `--signal` asks Slurm to send a signal of your choice a while before the limit, so that the program has time to do it, e.g. `--signal=B:USR1@300` for `SIGUSR1` to the batch script 5 minutes before.
