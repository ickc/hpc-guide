---
title: "Where to put your data"
output-file: where
description: "The kinds of storage a cluster has (home, scratch, project and node-local), what each is for, its quota, backups and purge policy, how to find yours, and staging data in and out of node-local storage."
---

The last part ended with jobs that read and write many files, on many nodes at once. Where those files live matters as much as how the jobs run: put them in the wrong place, and a job that should take minutes takes hours, fills up your quota half way, or loses its results. [Getting started](../getting-started/10-cluster.md#the-shared-filesystems) introduced the kinds of storage briefly. This page goes through each of them in more detail, then how to find them on your cluster, and how to use the fastest of them, the storage local to each node.

The recipe you may already have is to put everything in your home directory: it is where you land when you log in, and it is there on every node. So you copy your data there, run your jobs from there, and write the results there too. That works for a while, and then it bites. Home is usually the smallest of the filesystems, so a big run fills it, and once your home is full, things that have nothing to do with your job start to fail too, from your shell's history to the editor you log in with. And home is slow under heavy reading and writing, so a few hundred processes reading from it at once is slow for you and for everyone else on it.

## The kinds of storage

The names below are environment variables some centres set, but none of them is universal, and some centres set none at all. So look for each *kind* of storage in your centre's documentation, whatever it is called there. Where your centre has no variable for one, I'd recommend defining one yourself, in your `~/.bashrc`, so that your scripts can use the same name everywhere.

### Home, `$HOME`

Your home directory is mounted on every node, login and compute, and it is where your configuration files, your scripts, and your source code go. It is small, often tens of gigabytes, and its latency is high: each file operation takes a while, which you won't notice when you edit a script, but you will when a job opens thousands of files there.

Home is the one most likely to be backed up, or to keep snapshots you can restore from, on the clusters that back up anything at all. But on many clusters, nothing is backed up, home included. It is not purged.

For a job on several nodes, home is shared, so every node sees the same files, which makes it fine for the job script and the small configuration files it reads at the start. It is not the place for the data.

### Scratch, `$SCRATCH`

Scratch is the large, fast filesystem, meant for the data your jobs read and write while you work on it.[^1] Its quota is usually measured in terabytes rather than gigabytes. It is fast for big files, read and written in large chunks, but like every shared filesystem, it is slow for many small files, for reasons [the page on Lustre](20-lustre.md#why-many-small-files-are-the-expensive-kind) goes into.

The catch is that it is subject to a *purge* policy: files that nobody has used for a while, e.g. for 60 days, are deleted automatically, without asking you. So scratch is for work in progress, never for the only copy of anything. When a result is worth keeping, copy it to your project directory, or off the cluster altogether, which is [the page on moving data](30-moving-data.md). And don't `touch` your files to keep them from being purged: the policy is there so that the filesystem has room for everyone, and some centres forbid exactly that.

It is not backed up either. For a job on several nodes, scratch is shared like home, so every node sees the same files, and it is where a multi-node job normally reads its inputs from and writes its outputs to.

### Project, `$PROJECTDIR`

A project directory is shared by the members of a project, with a quota of its own, separate from each member's.[^2] It is for what you all need for the length of the project: shared datasets, the environments everyone uses, and the results worth keeping. It is usually not purged, but it is often deleted some time after the project ends, so it is still not an archive.

Its speed is that of the filesystem it is on, which may well be the same one as scratch. Whether it is backed up is, again, up to your centre. Since it is shared by the project, also check who can read and write what you put there, with `ls -l`, before you rely on it, e.g. that the files you made can be read by the rest of your group.

### Node-local, `$LOCALDIR`

Some clusters give each compute node storage of its own, usually a local SSD, or a directory in memory.[^3] This is the fastest storage you have for many small files, since nobody else is using it, and there is no network between your job and the disk.

But it is only available on that node, and often only for the duration of the job: the directory is made when the job starts, and deleted when it ends. So it has no quota you can check in advance, only its size, which is in your centre's documentation, or in `df -h` inside a job. It is not backed up, and anything you leave on it is gone after the job.

For a job on several nodes, this is where to beware: each node has its own, and a file written on one node is not there on another. So a job has to *stage* its data in, copying what it needs onto each node at the start, and stage its results out, copying them back to a shared filesystem before the job ends, which needs to be done carefully, and is [the last section of this page](#staging-in-and-out-of-node-local-storage).

### At a glance

|                  | Home                         | Scratch          | Project                     | Node-local            |
|------------------|------------------------------|------------------|-----------------------------|-----------------------|
| For              | configuration, scripts, code | data in progress | what the project keeps      | data during one job   |
| Size             | small                        | large            | large, per project          | the node's disk       |
| Backed up        | sometimes                    | no               | sometimes                   | no                    |
| Purged           | no                           | yes              | not while the project lasts | at the end of the job |
| Many small files | slow                         | slow             | slow                        | fast                  |
| Seen from        | every node                   | every node       | every node                  | that node only        |

## How to find yours

Start with your centre's documentation, which has a page on storage with the names, sizes and policies of each. Then check what your account actually sees. The quickest check is the environment variables:

``` bash
echo "$HOME" "$SCRATCH" "$PROJECTDIR" "$LOCALDIR" "$TMPDIR"
env | grep -i -E 'scratch|project|local|tmp'
```

Run them on the login node, and again inside a job (the interactive `srun --pty bash -i` from [the first job page](../getting-started/20-first-job.md#interactive-jobs)), since a node-local directory is usually set only in a job. An empty line means that variable is not set there, not that the kind of storage doesn't exist, so the documentation is still the authority.

Then, to see which filesystem a directory is on, use `findmnt -T`:

``` bash
findmnt -T "$SCRATCH"
```

which prints the mount point that directory is under, where it comes from, and the filesystem type, e.g. `lustre` for Lustre, `gpfs` for IBM Storage Scale, `beegfs`, `nfs`, or `xfs` and `tmpfs` for a local disk and memory. Home, scratch and project may well turn out to be directories on one and the same filesystem, told apart only by their quotas and purge policies.

`df -h` is the wrong tool for how much room you have left. On a shared filesystem, it shows everyone's free space, not yours, or on some clusters the quota of the directory, with nothing in the output to say which. And it says nothing about the other limit, on the number of files, which is the one many small files run into first. How much room you have is your quota, checked with the filesystem's own tool. For Lustre, that is `lfs quota`, on [the next page](20-lustre.md#checking-your-quota). Other filesystems have their own, e.g. `mmlsquota` for IBM Storage Scale, and many centres provide a command of their own that summarises every quota you have, named in their documentation.

For node-local storage, `df -h` is the right tool, inside a job, since the node's disk is yours for the length of the job (or shared only with the other jobs on that node):

``` bash
df -h "${LOCALDIR:-${TMPDIR:-/tmp}}"
```

If it says `tmpfs`, it is in memory rather than on a disk, and whatever you put there counts against the memory of your job.

## Staging in and out of node-local storage

Say your job reads a thousand small input files, and writes one result for each. On a shared filesystem, that is a few thousand file operations, each going over the network to a server everyone else is using too. On node-local storage, they are local and fast. So the pattern is:

1.  keep the inputs packed into one file on the shared filesystem, e.g. a tarball made with `tar -cf inputs.tar in/`;
2.  at the start of the job, unpack it onto node-local storage, which reads one big file from the shared filesystem;
3.  do the work there;
4.  pack the results into one file, and copy it back to the shared filesystem, before the job ends, *including when the work fails*.

The last step is the one that needs care. If the work fails half way, or runs out of time, the results so far are still worth having, if only to see where it went wrong. But once the job ends, the node-local directory is deleted, and they are gone. Here is a job that does all four, with a Python script, `work.py`, standing in for the work:

``` {.bash include="../examples/stage-local/job.sh"}
```

``` {.python include="../examples/stage-local/work.py"}
```

`$INPUT` and `$RESULTS` default to the directory you submitted from, but you'd point them at scratch, e.g. `INPUT=$SCRATCH/inputs.tar RESULTS=$SCRATCH/results sbatch job.sh`, since `sbatch` passes your environment on to the job. `$LOCAL` is node-local storage: `$LOCALDIR` if your centre sets it, otherwise `$TMPDIR`, which some clusters set to a directory for each job, and otherwise `/tmp`. The job ID in the name keeps two jobs on the same node apart.

`stage_out` is the fourth step, and `trap stage_out EXIT` runs it whenever the script exits, whether the work succeeded or not: with `set -e`, a failing command makes the script exit, which runs it too. That leaves the job being stopped from the outside, by its time limit or by `scancel`, where Slurm sends the job `SIGTERM`, and kills it outright a little later (30 seconds, by default).[^4] So the second `trap` catches `SIGTERM`, stops the work, and exits, which runs `stage_out` in time if packing the results is quick. To leave more room, `--signal=B:USR1@60` asks Slurm to send the script `SIGUSR1` about 60 seconds before the time limit, which the same `trap` catches.[^5] That is also why the work runs in the background, with `&` and then `wait`: bash runs a `trap` only once the command in the foreground finishes, while `wait` returns as soon as a signal arrives.

The results come back as one tarball per job, `$RESULTS/<job ID>.tar`, which you unpack where you need them, e.g. with `tar -xf`. The job prints how many files it staged in and out, so you can see in its output that the staging worked, e.g. that a job whose work failed half way still staged out the 500 results it had.

### On several nodes

On several nodes, each node needs its own copy of the inputs, and has its own results to stage out. Slurm can copy a file to every node of a job for you, with [`sbcast`](https://slurm.schedmd.com/sbcast.html), run from inside the job, which is one more reason to pack the inputs into one file first, since it copies a single file, not a directory:

``` bash
sbcast "$INPUT" "$LOCAL/inputs.tar"
```

where `$LOCAL` has to exist on every node already, e.g. made with `srun --ntasks-per-node=1 mkdir -p "$LOCAL"` first. Then unpack it with one task per node, the same way, and stage out the same way at the end, with the node's name in each tarball's name (`$(hostname).tar`) so that the nodes do not overwrite each other's. The [page on shipping an environment](../software/50-shipping.md) does the same with a packed environment rather than data. If all you need on each node is the program itself, `srun --bcast` copies it to every node before running it there.

That is more to get right, and with a `trap` on each node rather than one. So before you write your own, check what your centre already provides, since some centres have integrated node-local storage into Slurm:

- a private `/tmp` for each job, from a Slurm plugin that gives every job its own `/tmp` and `/dev/shm`, removed when the job ends, so that two jobs on a node never see each other's files;[^6]
- a [burst buffer](https://slurm.schedmd.com/burst_buffer.html), fast storage you ask for in the job script (with `#DW` lines on a Cray system with DataWarp, or `--bb` options), which Slurm stages in before the job starts and stages out after it ends, so the job itself never waits for it;
- a filesystem made for the length of the job out of the local disks of all its nodes, which every node of the job can see. BeeOND, from the makers of BeeGFS, is one, and it is the centre that has to set it up, from the scripts Slurm runs before and after each job.

Your centre's documentation says which of these it has, if any, and how to ask for them.

Node-local storage is the fast option, but it is not always there, and staging takes care. For everything else, your data lives on a shared filesystem, and on many clusters that is Lustre, the subject of [the next page](20-lustre.md): how to check your quota on it, why many small files are the expensive kind, and how to spread a big file over many disks.

[^1]: `$SCRATCH` is what many clusters call it, but not every cluster sets it, and some call it something else, e.g. `$SCRATCHDIR`. Look for a large, fast filesystem with a purge policy in your centre's documentation.

[^2]: `$PROJECTDIR` is a name some centres use, others use another, and some have no variable for it at all, only a path. Look for storage shared by a project, with its own quota, in your centre's documentation.

[^3]: `$LOCALDIR` is a name some centres use, and others don't, or call it something else, e.g. `$TMPDIR`, or have only `/tmp`. Look for node-local storage in your centre's documentation.

[^4]: That grace period is `KillWait` in Slurm's configuration, which `scontrol show config | grep KillWait` shows.

[^5]: The `B:` sends the signal to the batch script only, rather than to every process of the job. Slurm checks the time limits only every so often, so the signal can come up to a minute earlier than asked for. Give it more than 60 seconds if your results take longer to pack.

[^6]: The plugin is `job_container/tmpfs`, called `namespace/tmpfs` in recent versions of Slurm, and its [configuration](https://slurm.schedmd.com/job_container.conf.html) is in `job_container.conf`. `scontrol show config | grep -i -E 'JobContainer|Namespace'` shows whether your cluster uses it.
