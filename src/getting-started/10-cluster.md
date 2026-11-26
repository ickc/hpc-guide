---
title: "What a cluster is"
output-file: cluster
description: "For someone who has an allocation and has only used their laptop: login nodes and compute nodes, the scheduler and why you queue, the shared filesystems, what not to do on a login node, and a map of the rest of this guide."
---

Say you have just been given an allocation on an HPC cluster, and an analysis that takes too long on your laptop. You log in with `ssh`, and get a prompt that looks like the one on your laptop: a Linux shell, with your home directory, where `ls`, `python` and `vim` work as you'd expect. So the obvious thing to do is to copy your script over and run it, as you would at home. That is the one thing you should not do, and the reason why is how a cluster is put together.

## Login nodes and compute nodes

A cluster is many computers, called *nodes*, connected by a fast network and sharing some filesystems. They are not all the same kind.

The node you land on when you `ssh` in is a *login node*. There are only a few of them, and they are shared by everyone who is logged in at the time, which can be hundreds of people. They are for preparing work: editing files, moving data in and out, installing software, compiling, and submitting jobs.

The *compute nodes* are where the work runs, and there are many more of them, from tens to thousands. You don't log in to them directly. Instead, you ask for some of their cores, memory, and time, and once you get them, your work runs there, with those resources to itself for as long as it asked for. Such a request is a *job*.

Type `hostname` to see which node you are on. On a login node, it is usually a name with `login` in it; inside a job, it is the name of a compute node. You'll use this a lot in this guide, as the quickest check of where something actually runs.

The two kinds of node are not always the same kind of machine either. On some clusters the login nodes have a different CPU from the compute nodes, or no GPU where the compute nodes have several, or even a different architecture, e.g. `x86_64` login nodes in front of Arm compute nodes. So something that works on the login node is not guaranteed to work on a compute node, which comes back in [the part on software environments](../package-managers/10-intro.md#where-to-put-your-environments).

## The scheduler, and why you queue

Who gets which compute nodes, and when, is decided by a program called the *scheduler*, or the workload manager. This guide assumes [Slurm](https://slurm.schedmd.com), which is the most common one. You describe what your job needs in a script, hand the script to Slurm, and Slurm puts it in a queue, then starts it on some compute nodes once they are free and it is your turn.

So there is a wait between submitting a job and it starting, from seconds to days, depending on how busy the cluster is and how much you asked for. That may seem like a step back from your laptop, where everything starts at once. But the point of the queue is that while your job runs, the cores and memory it got are yours alone, so it runs at the speed of the hardware rather than at whatever is left over after everyone else. And whose turn it is depends on more than the order of submission: most clusters give a higher priority to projects and users that have used less of their share recently (this is called *fairshare*), and fill gaps in the schedule with small, short jobs that fit in them. So asking for what your job really needs, and no more, gets it started sooner, which is what [the page on job usage](30-job-usage.md) is about.

Your allocation is usually measured in what your jobs use, in core-hours, node-hours or GPU-hours, and your jobs are charged against it. A job is charged for what it asked for, for as long as it ran, whether or not it used it.

## The shared filesystems

Every node, login or compute, sees the same files. That is how the script you write on the login node is there when your job starts on a compute node, and how the job's results are there when you come back. These shared filesystems are network filesystems, and there are usually several of them, each for a different purpose:

- your *home* directory, `$HOME`, mounted on every node, small, and slow under heavy reading and writing, for your configuration, scripts and source code;
- a *project* directory, often `$PROJECTDIR`,[^1] shared with the other members of your project, with a quota of its own, for what you all need to keep for the length of the project;
- a *scratch* filesystem, often `$SCRATCH`,[^2] large and fast, for the data your jobs read and write while you work on them. On many clusters, files on scratch that nobody has used for a while (60 days, on one cluster I have used) are deleted automatically, which is called a *purge* policy.

Each has a quota, and on many clusters, none of them is backed up. So keep a copy of anything you cannot afford to lose somewhere else. Compute nodes may also have storage of their own, e.g. `$LOCALDIR`,[^3] which is not shared: each node sees its own, often only for the length of the job, so a job on several nodes sees a different one on each. But it is much faster for a job that reads or writes many small files. The names, sizes and policies differ from cluster to cluster, so look them up in your cluster's documentation before you put anything big anywhere. The [Storage part](../storage/10-where.md) goes into how to use each of them.

## What not to do on a login node

Since the login nodes are shared by everyone, anything heavy you run there slows them down for everyone else, which is a quick way to annoy the sysadmins of a cluster. What is heavy?

- Your analysis, or anything that uses many cores or a lot of memory for more than a few minutes. That goes in a job.
- Many processes at once, e.g. `make -j` with no number, which starts as many compilers as there are cores, or GNU parallel without `--jobs`. Compiling on the login node is fine. Compiling on all of its cores at once is not.
- Something that keeps running after you leave, such as a JupyterLab server, or an AI coding agent. Some clusters forbid running an agent on a login node outright.[^4]
- Asking the scheduler about your jobs in a tight loop, e.g. `watch -n 1 squeue --me`. The scheduler is shared too, and every query is work for it. Every 15 seconds or so is plenty.

Nothing necessarily stops you. On one cluster I have used, a login shell could keep all 144 cores of the login node busy, with no per-user limit that I could find. So it is up to you. Other clusters do limit each user on a login node, e.g. to a few cores, in which case a heavy program there is not only antisocial but slow. Editing, looking at output, moving files, installing software into an environment, and submitting jobs are what login nodes are for, so do those there without worrying.

## How this guide is organised

The rest of this part is the minimum to get work done: [the next page](20-first-job.md) is your first job, the one after it is about finding out what a job actually used so that you can ask for the right resources, and the last one is a checklist for when a job fails. After that, each part is about one thing, and you can read the ones you need:

- [Software environments](../package-managers/10-intro.md): getting the software your analysis needs onto the cluster, without `sudo`.
- [MPI](../mpi/10-intro.md): running one program across many nodes, on the MPI that knows the cluster's network.
- [Parallelism](../parallel/10-intro.md): making a computation that takes too long on one core use many, from threads to job arrays to workflows.
- [Storage](../storage/index.md): the filesystems, their quotas, and how to move data in and out.
- [Working interactively](../interactive/index.md): editing files on the cluster from your laptop, a shell on a compute node, and JupyterLab or RStudio on one, securely.

The next page starts with the smallest job there is.

[^1]: The name depends on the system: some centres call it something else, and some have no variable for it at all. Look for this kind of storage, shared by a project with its own quota, in your centre's documentation.

[^2]: Again, the name depends on the system, and not every centre sets it. Look for large, fast storage with a purge policy in your centre's documentation.

[^3]: A name some centres use, and others don't; look for node-local storage in your centre's documentation.

[^4]: Where that is the rule, what such a cluster asks instead is that you run the agent on your own computer, and copy the commands it suggests into your terminal on the cluster once you have checked them.
