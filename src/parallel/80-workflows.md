---
title: "Workflow managers"
description: "Tasks that depend on each other: from a chain of sbatch --dependency to a workflow manager (make, Snakemake, Nextflow, Parsl), on Monte Carlo π as a Snakefile, and the questions specific to a cluster: one Slurm job per task or everything in one allocation, where the manager's head process runs, throttling its submissions, and a working directory on a filesystem with locking."
output-file: workflows
aliases: [../running-jobs/workflow.html]
---

The previous pages were about running one computation on many cores, or many nodes. This page is about computations made of steps, where some steps need the output of others: the fourth kind of parallel from [the introduction](10-intro.md), tasks with dependencies.

## The chain you may already have

[The page on job arrays](40-job-arrays.md#the-reduce-after-every-task) already had a dependency: the reduce job waited for every task of the array with `--dependency=afterok`. A pipeline of more steps can be chained the same way, in a script on the login node:

``` bash
align="$(sbatch --parsable align.sh)"
call="$(sbatch --parsable --dependency=afterok:"$align" call.sh)"
sbatch --dependency=afterok:"$call" merge.sh
```

This works, and for two or three steps, it is fine. But as the pipeline grows, it bites in a few ways. The dependencies are between jobs, while what you care about is files: `call.sh` needs the alignments, and Slurm only knows that some job finished. When a step fails, everything after it waits forever in the queue, and to recover, you have to work out which outputs are complete, edit the chain to skip the steps that are done, and resubmit. When you change one input, you have to work out which steps it affects. And the script that submits all this is itself a small piece of software, which you write, debug, and maintain for every pipeline.

Workflow managers are useful for reproducible workflow, especially when you have complicated pipelines with complicated data dependencies. Better use one than to roll your own.

## What a workflow manager does

You describe each step by what it reads and what it writes, and the workflow manager works out the rest: the order of the steps, from which outputs are inputs of which steps; which steps can run at once; and which are already done, so that after a failure, or a change, it reruns only what is missing or out of date. It then runs the steps, on the node it is on, or through Slurm.

Those I'd point you to:

- **make**, e.g. GNU make. The oldest, made for building software, and on every system already. It knows only files and the times they were changed, and runs commands, so it is enough for a simple pipeline on one node.
- **[Snakemake](https://snakemake.readthedocs.io/en/stable/)**, which takes make's idea of rules with inputs and outputs, with Python to write them in. It is widely used in bioinformatics and data analysis, and can give each rule its own conda environment or container.
- **[Parsl](https://parsl.readthedocs.io/en/stable/)**, a Python library, where the steps are Python functions, or commands, decorated as *apps*, and the dependencies are the futures they return, as in `concurrent.futures`. It suits a workflow that is already a Python program, or that decides what to run next as it goes.
- **[Nextflow](https://docs.seqera.io/nextflow/)**, with a language of its own, where each step is a *process* and data flows between them through *channels*. It is the basis of [nf-core](https://nf-co.re), a large collection of community-maintained pipelines, mostly in genomics, and if your field's pipeline is one of them, you run it rather than write one.

The rest of this page uses Snakemake and Nextflow for the examples, but the questions in it apply to all of them.

## Monte Carlo π as a workflow

The π of this part is a workflow of two steps: 64 count tasks, then the reduce, which needs all of them. As a Snakefile:

``` {.python include="../examples/pi-workflow/Snakefile"}
```

`rule count` says how to make `results/{seed}.txt` for any `seed`, which is a *wildcard*, and `{wildcards.seed}` puts its value into the command. `rule reduce` needs `expand("results/{seed}.txt", seed=SEEDS)`, the list of 64 files, so for it to run, Snakemake has to make each of them, with `count`. `rule all` comes first, so it is what Snakemake makes by default: `pi.txt`. The `group` line matters only through Slurm, below.

The same as a Makefile, for comparison:

``` {.makefile include="../examples/pi-workflow/Makefile"}
```

Both are the same three facts: each count file comes from a seed, the reduce needs all of them, and the result is `pi.txt`.

### Inside one job

The simplest way to run either is inside one job, as GNU parallel did on [the one-node page](30-one-node.md):

``` {.bash include="../examples/pi-workflow/job.sh"}
```

`snakemake --cores 8` runs up to 8 jobs of the workflow at a time, as local processes on the node of the job, starting each count as soon as a core is free, and the reduce once all 64 are done. The job prints Snakemake's log, then the contents of `pi.txt`:

``` text
pi = 3.141543 from 4294967296 samples
```

`job-make.sh` is the same job with `make --jobs "$SLURM_CPUS_PER_TASK"` instead, and prints the same.

Run it again, and nothing happens, since `pi.txt` is there and up to date. If two of the count tasks had failed, the reduce would not have run either. Then fix the problem and run the same command again, and it runs only the 2 missing counts and the reduce:

``` text
Job stats:
job       count
------  -------
count         2
reduce        1
all           1
total         4
```

That is what the chain of `sbatch` could not do by itself.

## The questions specific to a cluster

On your own computer, there is nothing more to it. On a cluster, a workflow manager has a few more decisions to make, and the defaults are not always the right ones for the cluster you are on.

### One Slurm job per task, or one allocation for everything

Inside one job, as above, everything runs on one node, with no load on the scheduler, and each task starts as soon as a core is free, with no wait in the queue. But it is limited to one node, the job has to be as large as the busiest moment of the workflow, and as long as all of it.

The other way is for the workflow manager to submit each task as a Slurm job of its own, with the resources that task needs: 1 core for a count, 64 for an assembly. Snakemake does this with its [Slurm executor plugin](https://snakemake.github.io/snakemake-plugin-catalog/plugins/executor/slurm.html), installed alongside it, and a *profile*, a file of options:

``` {.yaml include="../examples/pi-workflow/profiles/slurm/config.yaml"}
```

used with `snakemake --profile profiles/slurm`. `executor: slurm` makes each job of the workflow a Slurm job, and `default-resources` gives each one 10 minutes and 2 GB unless its rule asks for something else, which a rule does with a `resources:` section of its own.

But that brings back the problem of [job arrays](40-job-arrays.md#the-limit-overwhelming-the-scheduler): a count task takes a second, and a Slurm job for each of the 64 is mostly waiting in the queue. So the profile groups them: `group: "count"` in the Snakefile, with `group-components: count=16`, makes every 16 count tasks one Slurm job, which runs them on 16 cores, so the 64 tasks are 4 jobs, plus one for the reduce. In a real workflow, it is worth doing the same for any step with many short tasks, and leaving the long ones as a job each.

Nextflow makes the same choice with its *executor*. With `process.executor = 'slurm'`, each task is a Slurm job, sized by the process's `cpus`, `memory` and `time`; with the default, `local`, the tasks run as processes on the node where Nextflow runs, so inside one job, on one node. Parsl is in between: it asks Slurm for *blocks* of nodes, as jobs, and runs many tasks on the workers inside each, which keeps the number of jobs small without giving up going beyond one node.

Running each task through Slurm is also what lets a single task be an MPI program over several nodes, since each task gets an allocation of its own, which the task's command can then use with `srun`.

### Where the head process runs

Whichever executor you use, the workflow manager itself is a process, the *head*, that runs for the whole of the workflow: it submits the tasks, watches them, and submits the next ones as their inputs appear. If it dies, nothing new is submitted, although the jobs it has already submitted carry on.[^1] So where it runs matters, and there are two choices.

**On a login node.** This is the simplest, and it is what the Snakemake Slurm plugin expects: it warns when you run it inside a job, that this "is not recommended", and to run Snakemake directly on the login node. The head mostly waits, so it takes little CPU. But it has to keep running for as long as the workflow does, hours or days, and it ends when your `ssh` connection does, unless it runs in a terminal multiplexer such as `tmux` or `screen`, which some clusters do not allow to persist.

::: {.callout-note title="For example, on Isambard 3"}
Isambard's [guide to the login nodes](https://docs.isambard.ac.uk/user-documentation/guides/login/#working-on-the-login-node) says that long-running `tmux`, `screen` or similar sessions left running on login nodes are against its security policy, and may be terminated without warning: its SSH certificates are valid for 12 hours, and a persistent session would bypass that. Login nodes are also assigned at random, so you may not get back to the one where you started a session.
:::

**In a job of its own.** A small, long job, e.g. 2 cores for 12 hours, that runs only the head, which then submits the tasks as jobs of their own. This survives logging out, and is accounted like any other job. But it needs `sbatch` to work from a compute node, which is allowed on many clusters but not all, so check that first, with `sbatch` or `squeue` in an interactive job. Its time limit has to be longer than the whole workflow, and it holds its cores while it waits. Here is such a driver job, for an nf-core pipeline:

``` bash
#!/bin/bash
#SBATCH --job-name=nextflow
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=12:00:00
set -euo pipefail

# The head only: Nextflow submits every task of the pipeline as a Slurm job of its own.
nextflow run nf-core/bacass -r 2.6.1 -profile test,arm64 -c slurm.config --outdir results -resume
```

where `slurm.config` holds the executor settings of the next section, and those for containers. A third choice, a big allocation with everything inside it and the head in it too, is the one-job case above.

So, if your cluster allows a long-lived process on its login nodes, run the head there, in `tmux`, and if it does not, but allows `sbatch` from a compute node, run it in a job. If it allows neither, the workflow has to fit in one allocation.

### Throttling the submissions

A workflow manager can submit jobs much faster than a person typing `sbatch`, and the scheduler is shared by everyone, as on [the page on job arrays](40-job-arrays.md#the-limit-overwhelming-the-scheduler). Every one of them has settings to slow it down, and it is worth setting them, rather than finding out the cluster's limits by hitting them.

In the Snakemake profile above, `jobs: 4` is the most Slurm jobs it has in the queue at a time, and `max-jobs-per-timespan: 1/1s` the most it submits per second (the default is 100 per second). In Nextflow, the same settings are in the `executor` scope of its configuration:

``` groovy
process {
    executor = 'slurm'
}

executor {
    queueSize         = 32         // at most 32 jobs in the queue at a time (the default is 100)
    submitRateLimit   = '10/1min'  // at most 10 submissions a minute
    pollInterval      = '30 sec'   // how often to check whether a task has finished
    queueStatInterval = '2 min'    // how often to ask Slurm for the state of the queue
}
```

The last two matter as much as the first two: every check is a call to `squeue` or `sacct`, and a head that checks a hundred jobs every few seconds is a steady load on the scheduler for as long as the workflow runs. Snakemake has `max-status-checks-per-second` and `seconds-between-status-checks` for the same.

A throttle makes the workflow no slower in practice, as long as it is above the rate at which the cluster would start your jobs anyway.

### The working directory and file locking

A workflow manager keeps its state in files: which tasks ran, with which inputs, and where their outputs are. For Nextflow, that is the `.nextflow` directory where you run it, and the *work directory*, `work/` by default, where every task runs in a directory of its own; for Snakemake, the `.snakemake` directory. On a cluster, two things follow.

They have to be on a filesystem that every node can see, since a task on a compute node writes its outputs there and the head reads them, which rules out node-local disk. They also see the latency of that filesystem: a task's output may only show up on the head's node some seconds after the task has finished, which is what Snakemake's `latency-wait` (60 seconds in the profile above) and Nextflow's `exitReadTimeout` are for.

And Nextflow relies on file locking: it locks its cache of completed tasks, which is what `-resume` reads, and on a filesystem without working locks, that fails, or worse, appears to work. Lustre, the filesystem of many clusters, supports locks, but whether they work across nodes is set by an option when it is mounted, `flock`, `localflock` or `noflock`, and `findmnt -t lustre` shows which. So put the working directory on a shared filesystem with `flock`, typically your scratch or project space, which also has the room for the many intermediate files.[^2]

Snakemake keeps a lock of its own instead, as files under `.snakemake/locks`, so that two runs of the same workflow don't write to the same directory at once. If the head is killed, e.g. when its job runs out of time, those files stay, and the next run refuses to start until you run `snakemake --unlock` in the same directory.

### Software for every step

Lastly, the steps of a real pipeline need software, often a different tool for each. Snakemake can give each rule a conda environment of its own, from a file next to the rule, created when it first runs, and Nextflow pipelines from nf-core run each process in a container. Both are good for reproducibility, and both bring back the questions of [the part on software environments](../package-managers/10-intro.md): create the environments on the kind of node they will run on, and on a filesystem every node sees. On an Arm cluster such as Isambard 3, containers built for x86-64 do not run at all, and nf-core pipelines have an `arm64` profile for that, used above as `-profile test,arm64`, which builds an Arm container for each process on demand, through a service called [Wave](https://docs.seqera.io/wave), when the compute nodes can reach the internet.

## Limitations

A workflow manager is one more tool to learn, with its own language and its own ways of failing, and for two steps, a chain of `sbatch` with `--dependency` is simpler. It also adds its own overhead to every task, on top of Slurm's, so a workflow of many tiny tasks is still better grouped, as above, or run inside one allocation. And none of them makes a single task faster: within each step, the earlier pages of this part still apply.

That is the end of this part. Every way of running in parallel here reads and writes files, often many of them, on filesystems shared by everyone, and the next part, [Storage](../storage/index.md), is about those: where to put your data, how much room you have, and how not to overwhelm a shared filesystem with many small files.

[^1]: So after a head dies, `scancel` its stray jobs before you rerun the workflow: Nextflow with `-resume` reuses the tasks that completed, and Snakemake reruns only what is missing.

[^2]: Node-local disk does support locks, but each node sees only its own, and it is often wiped at the end of the job, so it cannot hold a working directory that tasks on other nodes write to.
