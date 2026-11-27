---
title: "Workflow managers"
description: "Tasks that depend on each other: from a chain of sbatch --dependency to a workflow manager (make, Snakemake, Nextflow, Parsl), on Monte Carlo π as a Snakefile, and the questions specific to a cluster: one Slurm job per task or everything in one allocation, where the manager's head process runs, throttling its submissions, a working directory on a filesystem with locking, and software for every step."
output-file: workflows
aliases: [../running-jobs/workflow.html]
---

The previous pages ran one computation on many cores, or many nodes. This page is about computations made of steps, where some steps need the output of others: the fourth kind of parallel from [the introduction](10-intro.md), tasks with dependencies.

## The chain you may already have

[The page on job arrays](tasks/40-job-arrays.md#the-reduce-after-every-task) already had a dependency: the reduce job waited for every task of the array with `--dependency=afterok`. A pipeline of more steps can be chained the same way, in a script on the login node:

``` bash
align="$(sbatch --parsable align.sh)"
call="$(sbatch --parsable --dependency=afterok:"$align" call.sh)"
sbatch --dependency=afterok:"$call" merge.sh
```

This works, and for two or three steps, it is fine. But as the pipeline grows, it bites in a few ways. The dependencies are between jobs, while what you care about is files: `call.sh` needs the alignments, and Slurm only knows that some job finished. When a step fails, everything after it waits forever in the queue, and to recover, you have to work out which outputs are complete, and edit the chain to skip the steps that are done. When you change one input, you have to work out which steps it affects.

Workflow managers are useful for reproducible workflow, especially when you have complicated pipelines with complicated data dependencies. Better use one than to roll your own.

## What a workflow manager does

You describe each step by what it reads and what it writes, and the workflow manager works out the order of the steps, which of them can run at once, and which are already done, so that after a failure, or a change, it reruns only what is missing or out of date. It runs the steps on the node it is on, or through Slurm.

Those I'd point you to:

- **make**, e.g. GNU make, on every system already. It knows only files and the times they were changed, which is enough for a simple pipeline on one node.
- **[Snakemake](https://snakemake.readthedocs.io/en/stable/)**, make's rules with inputs and outputs, written in Python, and with a conda environment or container for each rule if you want one.
- **[Parsl](https://parsl.readthedocs.io/en/stable/)**, a Python library, where the steps are Python functions, or commands, decorated as *apps*, and the dependencies are the futures they return, as in `concurrent.futures`, for a workflow that is already a Python program, or that decides what to run next as it goes.
- **[Nextflow](https://docs.seqera.io/nextflow/)**, with a language of its own, where each step is a *process* and data flows between them through *channels*. It is the basis of [nf-core](https://nf-co.re), a large collection of community-maintained pipelines, mostly in genomics: if your field's pipeline is one of them, you run it rather than write one.

The examples use Snakemake and Nextflow, but the questions on this page apply to all of them.

## Monte Carlo π as a workflow

The π of this part is a workflow of two steps: 64 count tasks, then the reduce, which needs all of them. As a Snakefile:

``` {.python include="../examples/pi-workflow/Snakefile"}
```

`rule count` says how to make `results/{seed}.txt` for any `seed`, which is a *wildcard*, and `{wildcards.seed}` puts its value into the command. `rule reduce` needs `expand("results/{seed}.txt", seed=SEEDS)`, the list of 64 files, so Snakemake makes each of them with `count` first. `rule all` comes first, so it is what Snakemake makes by default: `pi.txt`. The `group` line matters only through Slurm, below.

The same, as a Makefile:

``` {.makefile include="../examples/pi-workflow/Makefile"}
```

### Inside one job

The simplest way to run either is inside one job, as [GNU parallel](tasks/20-gnu-parallel.md) did:

``` {.bash include="../examples/pi-workflow/job.sh"}
```

`snakemake --cores "$SLURM_CPUS_PER_TASK"` runs up to 8 jobs of the workflow at a time, as processes on the node of the job, starting each count as soon as a core is free, and the reduce once all 64 are done. The job prints Snakemake's log, then `pi.txt`:

``` text
pi = 3.141543 from 4294967296 samples
```

`job-make.sh` is the same job with `make --jobs "$SLURM_CPUS_PER_TASK"` instead, and prints the same.

Run it again, and nothing happens, since `pi.txt` is there and up to date. If two of the count tasks had failed, the reduce would not have run either, and once you fix the problem, the same command runs only the 2 missing counts and the reduce:

``` text
Job stats:
job       count
------  -------
count         2
reduce        1
all           1
total         4
```

## The questions specific to a cluster

On a cluster, a workflow manager has a few more decisions to make, and its defaults are not always the right ones for your cluster.

### One Slurm job per task, or one allocation for everything

Inside one job, as above, there is no load on the scheduler, and each task starts as soon as a core is free, with no wait in the queue. But it is limited to one node, and the job has to be as large as the busiest moment of the workflow, and as long as all of it.

The other way is for the workflow manager to submit each task as a Slurm job of its own, with the resources that task needs: 1 core for a count, 64 for an assembly, or several nodes for a task that is an MPI program, which its command then runs with `srun`. Snakemake does this with its [Slurm executor plugin](https://snakemake.github.io/snakemake-plugin-catalog/plugins/executor/slurm.html), installed alongside it, and a *profile*, a file of options:

``` {.yaml include="../examples/pi-workflow/profiles/slurm/config.yaml"}
```

used with `snakemake --profile profiles/slurm`. `executor: slurm` makes each job of the workflow a Slurm job, and `default-resources` gives each one 10 minutes and 2 GB unless its rule asks for something else, in a `resources:` section of its own.

A count task takes a second, though, and as a Slurm job of its own, it would mostly wait in the queue, the problem of [job arrays](tasks/40-job-arrays.md#the-limit-overwhelming-the-scheduler). So the profile groups them: `group: "count"` in the Snakefile, with `group-components: count=16`, makes every 16 count tasks one Slurm job, so the 64 tasks are 4 jobs, plus one for the reduce. In a real workflow, do the same for any step with many short tasks, and leave the long ones as a job each.

In Nextflow, the same choice is its *executor*: with `process.executor = 'slurm'`, each task is a Slurm job, sized by the process's `cpus`, `memory` and `time`, and with the default, `local`, the tasks run as processes on the node where Nextflow runs. Parsl asks Slurm for *blocks* of nodes, as jobs, and runs many tasks on the workers inside each.

### Where the head process runs

The workflow manager itself is a process, the *head*, that runs for the whole of the workflow, submitting the tasks as their inputs appear and watching them. If it dies, nothing new is submitted, although the jobs it has already submitted carry on.[^1] There are two places to run it.

**On a login node.** This is the simplest, and it is what the Snakemake Slurm plugin expects: run inside a job, it warns that this "is not recommended". The head mostly waits, so it takes little CPU, but it has to keep running for as long as the workflow does, hours or days, and it ends when your `ssh` connection does, unless it runs in a terminal multiplexer such as `tmux` or `screen`.

::: {.callout-note title="When persistent sessions are not allowed"}
Some clusters forbid `tmux`, `screen` or similar sessions left running on a login node after you disconnect, and may stop them without warning. A cluster that logs you in with short-lived SSH certificates, valid for 12 hours say, does so because a persistent session would bypass that limit. Login nodes may also be assigned at random, so you may not get back to the one where you started a session.
:::

**In a job of its own.** A small, long job, e.g. 2 cores for 12 hours, that runs only the head. This survives logging out, but it needs `sbatch` to work from a compute node, which depends on how your centre has deployed Slurm, so check that first, with `sbatch` or `squeue` in an interactive job. Its time limit has to be longer than the whole workflow, and it holds its cores while it waits. Here is such a driver job, for an nf-core pipeline:

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

where `slurm.config` holds the executor settings of the next section, and those for containers.

So, if your cluster allows a long-lived process on its login nodes, run the head there, in `tmux`, and if it does not, but allows `sbatch` from a compute node, run it in a job. If it allows neither, the workflow has to fit in one allocation, with the head inside it, as in the one-job case above.

### Throttling the submissions

A workflow manager can submit jobs much faster than a person typing `sbatch`, and the scheduler is shared by everyone, so set its throttles, rather than find out the cluster's limits by hitting them. In the Snakemake profile above, `jobs: 4` is the most Slurm jobs it has in the queue at a time, and `max-jobs-per-timespan: 1/1s` the most it submits per second (the default is 100 per second). In Nextflow, the same settings are in the `executor` scope of its configuration:

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

The last two matter as much as the first two, since every check is a call to `squeue` or `sacct`, and a head that checks a hundred jobs every few seconds is a steady load on the scheduler for as long as the workflow runs. Snakemake has `max-status-checks-per-second` and `seconds-between-status-checks` for the same. A throttle makes the workflow no slower in practice, as long as it is above the rate at which the cluster would start your jobs anyway.

### The working directory and file locking

A workflow manager keeps its state in files: for Nextflow, the `.nextflow` directory where you run it, and the *work directory*, `work/` by default, where every task runs in a directory of its own; for Snakemake, the `.snakemake` directory. They have to be on a filesystem that every node can see, since a task on a compute node writes its outputs there and the head reads them, which rules out node-local disk. A task's output may also show up on the head's node only some seconds after the task has finished, which is what Snakemake's `latency-wait` (60 seconds in the profile above) and Nextflow's `exitReadTimeout` are for.

Nextflow also relies on file locking: it locks its cache of completed tasks, which is what `-resume` reads, and on a filesystem without working locks, that fails, or worse, appears to work. Lustre, the filesystem of many clusters, supports locks, but whether they work across nodes is set by an option when it is mounted, `flock`, `localflock` or `noflock`, and `findmnt -t lustre` shows which. So put the working directory on a shared filesystem with `flock`, typically `$SCRATCH` or `$PROJECTDIR`,[^2] which also have the room for the many intermediate files.

Snakemake keeps a lock of its own instead, as files under `.snakemake/locks`, so that two runs of the same workflow don't write to the same directory at once. If the head is killed, e.g. when its job runs out of time, those files stay, and the next run refuses to start until you run `snakemake --unlock` in the same directory.

### Software for every step

The steps of a real pipeline often need a different tool each. Snakemake can give each rule a conda environment of its own, from a file next to the rule, created when it first runs, and Nextflow pipelines from nf-core run each process in a container. Both bring back the questions of [the part on software environments](../software/10-intro.md): create the environments on the kind of node they will run on, and on a filesystem every node sees. On an Arm cluster, containers built for x86-64 do not run at all, and nf-core's `arm64` profile, used above, builds an Arm container for each process on demand, through a service called [Wave](https://docs.seqera.io/wave), when the compute nodes can reach the internet.

## Limitations

A workflow manager is one more tool to learn, with its own language and its own ways of failing, and for two steps, a chain of `sbatch` with `--dependency` is simpler. It adds its own overhead to every task, on top of Slurm's, so a workflow of many tiny tasks is still better grouped, as above, or run inside one allocation. And it makes no single task faster: within each step, the earlier pages of this part still apply.

That is the end of this part. Every way of running in parallel here reads and writes files, often many of them, on filesystems shared by everyone, and the next part, [Storage](../storage/10-where.md), is about those: where to put your data, how much room you have, and how not to overwhelm a shared filesystem with many small files.

[^1]: So after a head dies, `scancel` its stray jobs before you rerun the workflow: Nextflow with `-resume` reuses the tasks that completed, and Snakemake reruns only what is missing.

[^2]: `$SCRATCH` is what many clusters call their scratch space, large and fast but purged of files not used for a while, and `$PROJECTDIR` is what some call the space shared by a project, with its own quota. Neither name is universal, so look for those kinds of storage in your centre's documentation; [the part on storage](../storage/10-where.md) is about the kinds there are.
