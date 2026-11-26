---
title: "Shipping an environment to the compute nodes"
description: "Packing an environment into one file and unpacking it onto node-local storage at the start of a job, with a plain tarball or conda-pack, for many short jobs or clusters without a shared filesystem."
output-file: shipping
---

Every page so far has assumed that your environment lives on the shared filesystem, and that every job reads it from there. That is usually fine. But a conda environment is tens of thousands of small files, and starting Python in it reads hundreds of them. If you run thousands of short jobs at once, that is thousands of processes asking the shared filesystem for the same small files, which is slow for you and for everyone else on it (the [page on Lustre](../storage/20-lustre.md) explains why small files are the expensive kind). And some clusters have no shared filesystem on the compute nodes at all.

The fix is to pack the environment into a single file, which the shared filesystem is good at serving, and unpack it at the start of each job onto storage local to the node, which is fast for small files.

## What has to match

This comes back to the PREFIX from [the introduction](10-intro.md). For software installed in a prefix on one computer to run on another, these must match:

1.  the OS, say Linux;
2.  the CPU architecture, such as `x86_64` or `aarch64`;
3.  the prefix directory;
4.  any other dependencies outside the prefix directory.

The first two match if you build the environment on the cluster, on the same kind of node the jobs run on. The fourth is what conda is good at: a conda environment brings its own libraries rather than using the system's, so the prefix is self-contained. Archive it, unpack it on another node, and it will not complain about a missing library it was using from outside.

That leaves the prefix. Unless you are sure the software you installed is designed to be portable, you should assume it is not, and that it only works at the path it was installed at. There are two ways to deal with that.

## The same prefix everywhere

The first is to install the environment at the path you will unpack it to, so the prefix matches without anything having to be relocated. Choose a path that exists and is writable on every compute node, such as one under `/tmp`, and install a whole miniforge there, in an interactive job on a compute node:[^1]

``` bash
bash Miniforge3.sh -b -p /tmp/myenv
/tmp/myenv/bin/mamba install -y -n base python=3.13 numpy
mkdir -p ~/envs
tar -czf ~/envs/myenv.tar.gz -C /tmp myenv
```

Then, in each job,

``` bash
tar -xzf ~/envs/myenv.tar.gz -C /tmp
source /tmp/myenv/bin/activate
```

`bin/activate` is the activation script of miniforge's base environment, which is why I installed miniforge itself at that path rather than an environment inside one: it can be activated with nothing but the files in the tarball.

This works as long as no two jobs on the same node unpack to the same `/tmp/myenv` at the same time. Many clusters give each job a private `/tmp`, in which case it is fine, but if yours shares `/tmp` between the jobs on a node, two jobs will overwrite each other's environment. For that, you need a prefix you can choose per job.

## Any prefix, with conda-pack

The second way is [conda-pack](https://conda.github.io/conda-pack/). Conda environments are designed to be relocatable: when a package is built, the prefix it was built at is recorded in its files as a placeholder, and conda replaces the placeholder with the real prefix when it installs the package. conda-pack packs an environment into a tarball, and its `conda-unpack` does that replacement again, for wherever you unpack it.

Pack the environment once, on the login node:

``` bash
mkdir -p ~/envs
mamba env create -f environment.yml -p ~/envs/shipped
~/envs/shipped/bin/conda-pack -p ~/envs/shipped -o ~/envs/shipped.tar.gz
```

with this `environment.yml`, which has `conda-pack` in it, so that there is only one environment to make (it can just as well be in another):

``` {.yaml include="../examples/ship-env/environment.yml"}
```

Then the job unpacks it into a directory of its own, on the node:

``` {.bash include="../examples/ship-env/job.sh"}
```

`$TMPDIR` is the job's own temporary directory, on clusters that set one, and otherwise this falls back to `/tmp`.[^2] The job ID in the path keeps two jobs on the same node apart. `trap ... EXIT` deletes the unpacked copy when the job ends, whether it succeeded or not, so it does not fill up the node's disk. `bin/activate` is a small activation script conda-pack adds to the tarball, and `conda-unpack` rewrites the prefixes, which only needs to happen once per unpacking.

Before relying on `/tmp`, check what it is with `df -h /tmp` on a compute node. If it says `tmpfs`, it is in memory rather than on a disk, and the unpacked environment counts against the memory of your job.

A job on more than one node has to unpack the environment on each of them, once per node, before running anything:

``` bash
srun --ntasks-per-node=1 bash -c 'mkdir -p "$LOCAL/env" && tar -xzf "$TARBALL" -C "$LOCAL/env" && source "$LOCAL/env/bin/activate" && conda-unpack'
```

with `LOCAL` and `TARBALL` exported, as in the job above.[^3]

## Is it worth it?

Unpacking takes time. The environment in this example unpacks in a second or two, but a large one with compilers and MPI can take a minute: on one cluster I have used, a big analysis environment took around 50 seconds. So for a job that runs for hours, it does not matter either way, and for jobs a minute long, the unpacking can take longer than the work.

Where it pays off is when the start-up reads are the problem, not the unpacking: many processes in one job, each starting Python, all reading from the node-local copy instead of the shared filesystem. So rather than thousands of short jobs, each unpacking its own environment, run fewer, longer jobs that each unpack once and then run many tasks, which is the subject of [the part on parallelism](../parallel/10-intro.md). A [container](60-containers.md) is the other way to get there, since an image is already a single file.

That is the end of this part. The next part is about MPI, and how to compose an environment from conda or Spack with the MPI library the vendor provides, which is where most of the remaining trouble with environments on an HPC is.

[^1]: Not on a login node, where everyone shares the same `/tmp`, and which may not be the same kind of machine.

[^2]: Some centres give each job node-local storage under a name of their own instead, such as `$LOCALDIR`, often only for the length of the job, and on a job of several nodes, each node has its own. Look for that kind of storage in your centre's documentation; [the part on storage](../storage/10-where.md) is about the kinds there are.

[^3]: If you use pixi, [pixi-pack](https://github.com/Quantco/pixi-pack) does the same for a pixi environment.
