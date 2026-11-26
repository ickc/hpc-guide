---
title: "Containers"
description: "What Apptainer is for on an HPC, when you would reach for it rather than conda, and a container built and run in a batch job."
output-file: containers
---

The previous page ended with software that is more than a conda environment can hold. A container packs a whole Linux userland, the libraries and tools an operating system would normally provide, into one image, so that the software inside sees the system it was built for, whatever the host is running.

On your laptop, that is Docker. On an HPC, it is usually [Apptainer](https://apptainer.org) (formerly Singularity), because Docker needs a daemon running as root, which a shared system will not give you.[^1] Apptainer runs a container as you, with your own permissions, and by default mounts your home directory, the current directory and `/tmp` inside it, so a program in a container reads and writes your files as if it were not in one.

::: callout-note
## Which one your cluster has

Clusters differ in what they offer: one I have used has `singularity` rather than `apptainer`, and Podman-HPC, a version of Podman adapted for HPC, as well. The commands on this page are the same with `singularity` in place of `apptainer`.
:::

## When to reach for one

Containers are orthogonal to the other package managers in this part: a container can wrap a conda or Spack environment, and inside one you can use `apt` or `dnf`, which are otherwise unavailable to you on a shared system. So I'd reach for one when

- the software you need is published as a Docker image, and installing it any other way is painful, which is common in bioinformatics and in machine learning, or
- it needs system packages that are not on conda-forge, or an operating system other than the cluster's.

A container also helps when your environment is many thousands of small files, which a shared filesystem handles badly (see [Lustre](../storage/20-lustre.md)), since an image is a single file, however much is inside it.

And I would not, for something conda can already give you. A container adds a build and an image to keep track of between you and your software, and buys you nothing if the environment inside it is a conda environment you could have used directly.

## A worked example

Apptainer can run a Docker image directly, converting it into its own format, a `.sif` file, as it downloads it:

``` bash
apptainer pull python.sif docker://python:3.13-slim
apptainer exec python.sif python3 --version
```

`apptainer exec IMAGE COMMAND` runs one command inside the container, and `apptainer shell IMAGE` gives you a shell in it to look around.

To add packages, you build your own image from a definition file, which starts from an existing image and runs commands in it. Here is one starting from conda-forge's miniforge image, so that the packages inside come from conda-forge too, in `numpy.def`:

``` text
Bootstrap: docker
From: condaforge/miniforge3:latest

%post
    mamba install -y -n base python=3.13 numpy
    mamba clean -afy
```

``` bash
apptainer build numpy.sif numpy.def
```

`%post` runs once, at build time, as root inside the container, which is where you can `apt-get install` too. Whether you can build on the cluster depends on whether it allows unprivileged builds (Apptainer uses user namespaces, or `--fakeroot`, for this). If it does not, build the image on your own Linux machine, or in CI, and copy the `.sif` over: it is just a file.

In a job, the container is one more word in front of your command:

``` bash
#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:10:00

srun apptainer exec numpy.sif python3 -c 'import numpy; print(numpy.__version__)'
```

A few options you will probably need sooner or later:

- `--bind "$SCRATCH"` (or wherever your data is)[^2] mounts a directory that is not mounted by default. Your home directory, the current directory and `/tmp` already are.
- `--nv` makes the NVIDIA GPUs and driver of the host available inside the container, and `--rocm` the AMD ones.
- `--cleanenv` stops the container inheriting your environment variables, so that, for example, a `PYTHONPATH` set outside does not leak in.

`apptainer pull` and `apptainer build` keep a cache of the layers they download, in `~/.apptainer/cache`, which can grow to many gigabytes. Set `APPTAINER_CACHEDIR` to put it somewhere with more space.

## Limitations

A container brings its own userland, but not its own kernel or hardware. It still runs on the host's kernel and drivers, which is why `--nv` exists. And an image is built for one CPU architecture: most images published on Docker Hub, and the prebuilt images many pipelines use, are `x86_64` only, and will not run on an Arm (`aarch64`) node. On an Arm cluster, check that an image has an `arm64` version before you plan around it, or build your own from a definition file as above. The same goes for the interconnect: an MPI program in a container has to use an MPI library compatible with the host's, so that it can use the fast network between nodes, and that is a subject of its own, in [the MPI part](../mpi/10-intro.md).

If what you need is compiled software built for the machine, with the vendor's compilers and libraries, a container is usually the wrong tool, and Spack, the next page, is the right one.

[^1]: Apptainer is the Linux Foundation's continuation of Singularity, and SingularityCE is a separate fork by Sylabs, with the same commands. Some clusters offer rootless Podman instead, or as well.

[^2]: `$SCRATCH` is what many clusters call their scratch space, large and fast but purged of files not used for a while. Not every cluster sets it, and some use another name, so look for that kind of storage in your centre's documentation; [the part on storage](../storage/index.md) is about the kinds there are.
