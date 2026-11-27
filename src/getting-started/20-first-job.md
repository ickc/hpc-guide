---
title: "Your first job"
output-file: first-job
description: "A batch script and what each part of it does; submitting it with sbatch, watching it with squeue and cancelling it with scancel; reading its output, following it with tail -F while it runs, and why that output can lag; and a pointer to interactive jobs."
---

[The previous page](10-cluster.md) said that your work runs on the compute nodes, as a job you hand to the scheduler. This page is the smallest such job: what goes in it, how to submit it, and how to see what it did.

## A batch script

A *batch job* is a shell script with a few extra lines at the top. Here is one, which prints the name of the node it runs on and its own job ID:

``` {.bash include="../examples/hello/job.sh"}
```

Save it as `job.sh` on the cluster. It has three parts.

The first line, `#!/bin/bash`, says which shell runs the script, as in any shell script.

The lines starting with `#SBATCH` are the *directives*. To bash they are comments, so it ignores them, but Slurm reads them as the options of the request, the same as if you had given them on the command line. Here they ask for one task (one process) on one node, for at most 2 minutes, and name the job `hello`, which is what you'll see in the queue. Slurm stops reading directives at the first line that is not a comment, so they have to come before any command; an `#SBATCH` line further down is silently ignored.

`--time` is the time limit, written as `hours:minutes:seconds` (or `days-hours:minutes:seconds`). It is a hard limit: once the job reaches it, Slurm ends it, whether or not it has finished. It is also one of the things the scheduler uses to decide when the job can start, so it pays to ask for about what the job needs, which [the page on job usage](30-job-usage.md) is about.

Everything after the directives is the body, ordinary bash, which runs on the compute node once the job starts. Anything you'd type in a terminal can go in it. `$SLURM_JOB_ID` is one of the environment variables Slurm sets in every job, and `env | grep ^SLURM_` inside a job lists the rest.

Depending on your cluster, you may also have to say which project to charge the job to, with `--account`, and which *partition* to run it in, with `--partition`. A partition is a group of nodes with its own limits, e.g. one for short jobs and one for long ones, or one for each kind of node. These go in the script as two more `#SBATCH` lines, or on the command line. `sinfo` lists the partitions you can use, and your cluster's documentation will say which project name to use.[^1]

## Submitting it: `sbatch`

On the login node, in the directory where `job.sh` is,

``` bash
sbatch job.sh
```

`sbatch` hands the script to Slurm and returns at once, printing `Submitted batch job` followed by the job ID, a number that is how you refer to this job from now on. The job itself runs later, whenever Slurm starts it.

An option given to `sbatch` on the command line overrides the same directive in the script, so `sbatch --time=00:05:00 job.sh` runs it with a 5-minute limit without editing it.

The job starts in the directory you submitted it from, and by default, with the environment variables of the shell you submitted it from. That is convenient, but it also means a job can depend on something you happened to do in that shell before submitting it, such as loading a module. Put everything the job needs in the script itself, so that it runs the same way tomorrow, which comes back in [the part on software environments](../software/package-managers/20-modules.md#modules-in-a-job).

## Watching it: `squeue`

``` bash
squeue --me
```

lists your jobs that are in the queue or running, one per line. The `ST` column is the state: `PD` for pending, i.e. waiting in the queue, `R` for running, and `CG` for completing, i.e. finished and being cleaned up. For a pending job, the last column says why it is waiting, e.g. `(Priority)` when other jobs are ahead of it, or `(Resources)` when it is next but the nodes it needs are still busy. For a running one, it is the node it runs on. `squeue --me --start` shows when Slurm expects your pending jobs to start, if it has worked that out yet.

Once a job has ended, it disappears from `squeue`. A small job like this one may well have come and gone before you type the command. That is normal, and the next page is about how to look at a job afterwards.

Check every now and then rather than all the time. If you want to keep an eye on the queue, `watch -n 15 squeue --me` reruns it every 15 seconds, which is plenty: the scheduler is shared by everyone, and every query is work for it.[^2]

## Cancelling it: `scancel`

``` bash
scancel <job ID>
```

cancels a job, whether it is pending or running. `scancel -u "$USER"` cancels all of yours, which is handy right after you have submitted a hundred jobs with the same mistake in them.

## Reading its output

Whatever the job prints, its output and its errors alike, goes to a file named `slurm-<job ID>.out`, in the directory it was submitted from. So once it ends,

``` bash
cat slurm-<job ID>.out
```

shows `Hello from` followed by the name of a compute node, and the job ID. Compare that name with `hostname` on the login node: they are different computers.

`--output` changes the name of the file, e.g. `#SBATCH --output=hello-%j.out`, where `%j` is replaced by the job ID, so that each job gets its own file. `--error` sends the errors to a separate file. I'd keep them together, at least while you are working out what a job does, since an error message makes most sense next to the output just before it.

### Following it while it runs: `tail -F`

For a job that runs for a while, you don't need to wait until it ends to see how it is doing:

``` bash
sbatch job.sh
tail -F slurm-<job ID>.out
```

`tail -F` prints the end of the file, and then everything that is added to it, as it is added, until you press Ctrl-C. The capital `F` matters. With `-f`, `tail` gives up straight away if the file doesn't exist yet, which it doesn't while the job is still in the queue, since Slurm creates it only when the job starts. With `-F`, `tail` says it cannot open the file, keeps trying, and starts following it as soon as it appears.

`tail` has no idea whether the job has ended. When it has, `tail` just sits there, waiting for more, so it is up to you to notice that the job is done, from its last line, or from `squeue`, and press Ctrl-C.

### Why the output can lag

You may find that the output shows up in bursts, or not at all until the job ends, even though your program prints as it goes. There are a few reasons, and only the first is in your hands.

The program may *buffer* its output. When its output is a file rather than a terminal, a program usually collects what it prints and writes it out a few kilobytes at a time, which is much more efficient, but means that nothing appears until a buffer is full. Python does this, and so do C programs. For Python, `python -u` or `export PYTHONUNBUFFERED=1` in the script turns it off; for a compiled program that prints through C's standard library, `stdbuf -oL <command>` makes it write each line as it is printed.[^3]

Then, the job writes the file on the compute node, and you read it on the login node, through the shared filesystem. How soon the login node sees what the compute node wrote depends on how that filesystem caches, which can be some seconds.

And some clusters write the job's output to a disk on the compute node while it runs, and copy it to where you asked for it only when the job ends. Then there is nothing to follow until the end. Your cluster's documentation will say whether it does this.

## Interactive jobs

A batch job runs without you: you submit it, and read what it wrote afterwards. Sometimes you want to type commands on a compute node instead, e.g. to check that your program starts there at all, or to try something in Python on a big dataset. `srun --nodes=1 --ntasks=1 --time=00:30:00 --pty bash -i` gives you a shell on a compute node, after waiting in the queue like any job, and the allocation ends when you `exit` the shell. That and the other ways to get a shell on a compute node are the subject of [a page of their own](../interactive/20-shell.md), in the part on working interactively. Remember that an interactive job is charged for every minute it is open, whether you type in it or not.

Now that the job has run, [the next page](30-job-usage.md) is about finding out what it actually used.

[^1]: You can also set them once in your `~/.bashrc`, as environment variables that `sbatch` reads, e.g. `export SBATCH_ACCOUNT=<project>` and `export SBATCH_PARTITION=<partition>`, so that you never have to write them in a script.

[^2]: If what you want is to wait for a job to end, e.g. in a script, `sbatch --wait job.sh` does that: it returns only once the job has ended, with the job's exit code.

[^3]: `stdbuf` works by changing the buffering of C's standard library from the outside, so it does nothing for a program that buffers its output in its own way, which Python does. For your own code, you can also flush the output yourself after each line that matters, e.g. with `print(..., flush=True)` in Python.
