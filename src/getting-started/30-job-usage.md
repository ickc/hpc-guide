---
title: "What your job actually used"
output-file: job-usage
description: "Finding out how much time, memory and CPU a job really used, with sacct after it ends, seff where your cluster has it, and /usr/bin/time -v for the peak memory of each command, so that you can ask for the right resources next time."
---

The job on [the previous page](20-first-job.md) asked for one task and 2 minutes, which was a guess. For your own work, you'll have to guess the first time too: how long it takes, how much memory it needs, how many cores it can use. Guess too little, and the job is killed before it finishes. Guess too much, and it waits longer in the queue, since a bigger request is harder to find room for, and it is charged for everything it asked for, used or not. So after the first run, find out what it actually used, and ask for that, with a margin, next time.

## After the job ends: `sacct`

Slurm keeps a record of every job, and `sacct` reads it:

``` bash
sacct -j <job ID> --format=JobID,JobName,State,ExitCode,Elapsed,Timelimit,NCPUS,TotalCPU,CPUTime,ReqMem,MaxRSS
```

It prints a few lines for one job. The first is the job as a whole. Below it are its *steps*: `<job ID>.batch` is the batch script itself, `<job ID>.extern` is something Slurm runs alongside the job for its own bookkeeping, which you can ignore, and every `srun` in the script gets a step of its own, `<job ID>.0`, `<job ID>.1`, and so on. Some numbers are only on the lines of the steps, so read those too.

The columns, in the order above:

- `State` is how the job ended: `COMPLETED`, `FAILED`, `TIMEOUT`, `OUT_OF_MEMORY` or `CANCELLED`. [The next page](40-failed-jobs.md) goes through what each failure looks like.
- `ExitCode` is two numbers, `code:signal`: the exit code of the script, and the signal that ended it, if one did. `0:0` is a clean exit.
- `Elapsed` is how long it ran, and `Timelimit` how long it asked for.
- `NCPUS` is the number of CPUs (cores, usually) it had.
- `TotalCPU` is the CPU time its processes used, added up over all of them. `CPUTime` is `Elapsed` times `NCPUS`, which is what it could have used, and roughly what it is charged for.
- `ReqMem` is the memory it asked for, and `MaxRSS`, on the lines of the steps, the most memory a task of that step used at any one time, its peak *resident set size*.

`sacct` takes a few seconds after a job ends to have its record. By default, it only shows jobs from today, since midnight, so for older ones, add `-S` with a start time, e.g. `-S now-7days`. And `sacct` with no `-j` lists all of your jobs since then, which is how to find the job ID of a job you've lost track of.

While a job is still running, `sstat -j <job ID>.batch --format=MaxRSS,AveCPU` shows the same kind of numbers for a running step, which is handy for a job that runs for days.

## An example

Here is a small Python script that holds 1 GiB of memory, and keeps one core busy for a minute:

``` {.python include="../examples/job-usage/use_memory.py"}
```

and a job that runs it, asking for 1 core and 2 GB of memory:

``` {.bash include="../examples/job-usage/job.sh"}
```

`--mem=2G` is the memory for the job on each node, here its only node. Submit it with `sbatch job.sh` from the directory with both files, and once it has ended, `sacct` should show an `Elapsed` of about a minute, a `TotalCPU` of about the same, since the one core was busy all the time, and a `MaxRSS` on the `.batch` line of a bit over 1 GiB, out of the 2 GB asked for.

### Peak memory of one command: `/usr/bin/time -v`

The script runs Python through `/usr/bin/time -v`, which runs a command, and once it ends, prints what it used. The output file has it after the script's own output. On a workstation, the same command printed these lines, among others:

``` text
    User time (seconds): 59.90
    System time (seconds): 0.02
    Percent of CPU this job got: 99%
    Elapsed (wall clock) time (h:mm:ss or m:ss): 1:00.07
    Maximum resident set size (kbytes): 1057724
    Exit status: 0
```

`Maximum resident set size` is the peak memory, in kilobytes: 1,057,724 kB is a bit over 1 GiB, the block the script holds plus Python itself. `Percent of CPU` is the CPU time over the elapsed time, so 99% is one core kept busy, and 800% would be 8.

Why measure memory with this, when `sacct` has `MaxRSS`? Because `sacct` doesn't watch the memory all the time. It takes a sample every so often, every 30 seconds by default, so a peak shorter than that can fall between two samples, and a job killed for running out of memory may show a `MaxRSS` lower than what killed it.[^1] `/usr/bin/time -v` gets the peak from the kernel when the command ends, so it doesn't miss it. And it is per command, so in a script that runs several programs, one after another, you see which one needs the memory.

Write it as `/usr/bin/time`, the full path, or `command time`. A plain `time -v` doesn't work in bash, since `time` alone is a keyword of bash, which knows no `-v`. And `/usr/bin/time` is a separate program, GNU time, which most Linux systems have, but not all: if `ls /usr/bin/time` says there is none, ask your sysadmins, or install it yourself, which [the part on software environments](../software/10-intro.md) shows how.[^2]

## `seff`, where your cluster has it

Many clusters also have `seff`, a script that comes with Slurm but is not always installed. `seff <job ID>` reads the same record as `sacct`, and turns it into two percentages: `CPU Efficiency`, which is `TotalCPU` over `CPUTime`, and `Memory Efficiency`, which is the peak memory over the memory asked for. That is the quickest way to see whether a job used what it asked for. Since it reads the same samples as `sacct`, it can miss a short peak of memory in the same way.

## Asking for the right resources

With those numbers, the next job can ask for about what it needs. Each resource has its own tradeoff.

**Time.** Ask for the `Elapsed` of a representative run, plus a margin for a slower node or a bigger input, e.g. half as much again. Too tight, and the job is killed just before it finishes, which wastes the whole run. But don't ask for the longest time the partition allows "to be safe", as a shorter job starts sooner: the scheduler fills the gaps before bigger jobs with smaller, shorter ones that fit in them, which is called *backfill*, and a job that asks for a week never fits in a gap. `sinfo -o "%P %l"` shows the longest time each partition allows. If your work needs more than that, it has to be split into jobs that each fit, e.g. by saving its state at the end of each job and continuing from it in the next, or, if it is many independent pieces, as a [job array](../parallel/tasks/40-job-arrays.md).

**Memory.** Ask for the peak, from `/usr/bin/time -v` or `MaxRSS`, plus a margin, with `--mem` for each node or `--mem-per-cpu` for each core, e.g. `--mem=4G` (the units are `K`, `M`, `G` and `T`, and a number alone is in megabytes). If you ask for nothing, you get the cluster's default, which on many clusters is an amount per core, so a 1-core job gets only that core's share of the node. `scontrol show config | grep -i DefMem` shows the default, and so does `scontrol show partition`, for each partition. Unlike time, too much memory costs little more than a longer wait, unless your cluster charges for it, but too little gets the job killed, which is the subject of [the next page](40-failed-jobs.md).

**Cores.** Divide `TotalCPU` by `Elapsed`: that is how many cores the job kept busy, on average. If it is close to `NCPUS`, the job used what it asked for. If it is about 1 when you asked for 8, your program runs on one core, and the other 7 sat idle, charged to you. Either it can only use one, in which case ask for one, or it could use more but wasn't told how many it had. A program that runs one process with many threads is told with the right request and the right environment variables, which [the page on threads](../parallel/20-threads.md) goes through, along with *oversubscription*, more threads than cores, which wastes them in a way that doesn't show in `TotalCPU` as plainly. More cores never make a program faster on their own: something in it has to use them, which is what [the part on parallelism](../parallel/10-intro.md) is about.

These numbers also tell you when something went wrong, which is where [the next page](40-failed-jobs.md) picks up: what a failed job looks like, and where to find the fix.

[^1]: How often it samples is the cluster's choice, `JobAcctGatherFrequency` in its Slurm configuration, and so is how it measures, which on some clusters makes the peak exact. `scontrol show config | grep -i JobAcctGather` shows both.

[^2]: For a program that starts many processes, `/usr/bin/time -v` reports the peak of the largest one, not of all of them together. For those, the `MaxRSS` of the step, which adds up the processes of each task, is the one to look at.
