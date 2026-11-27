---
title: "Which package manager?"
output-file: intro
description: "Modules, conda and mamba, pixi, containers and Spack side by side: what each gives you, whether it is prebuilt or built from source, how you reproduce it, when to reach for it, and which to try first."
---

[The previous page](../10-intro.md) was about the PREFIX that every package manager installs into. This section is about the package managers themselves, and this page is about which one to reach for.

They differ in what they install, and in whether they download prebuilt binaries or build everything from source on your machine. Prebuilt is much faster, and is what you want most of the time. Building from source is slower, but lets you optimize for the exact hardware you run on, and use the compilers and libraries the vendor provides.

|  | Gives you | Prebuilt or from source | Reproduced by | Reach for it for |
|------------------------|------------------------|------------------------|------------------------|------------------------|
| Modules | what the sysadmins installed | done for you | naming the version you load | compilers, MPI, and libraries tuned for the hardware |
| Conda and mamba | environments of conda-forge packages, kept in one place | prebuilt | `mamba env export`, for one platform | nearly everything else |
| Pixi | the same packages, in an environment per project | prebuilt | `pixi.lock`, for every platform | a project you want to reproduce |
| Containers | a whole Linux userland, in one image file | prebuilt image | the image, or its definition file | software published as a Docker image, or that needs system packages |
| Spack | compiled software, built for the machine you run on | from source | `spack.yaml` and `spack.lock` | compiled code that has to be built with the vendor's compilers and MPI |

**[Modules](20-modules.md)** are what the sysadmins already installed, so they are the place to look first. What you find with `module avail` varies a lot from one cluster to another: some have hundreds of modules of research software, others very few. The modules worth using are the ones tied to the machine: compilers, the MPI library, and libraries the vendor has tuned for the hardware, such as BLAS and FFT, or CUDA on a GPU system. These are hard to get right yourself, and the sysadmins have done it for you. For the rest, such as Python and its packages, a module is usually not what you want: it has the version the sysadmins chose, at the time they chose it, and you cannot add packages to it.

::: callout-note
## For example, on a Cray system

On a Cray EX system, the modules are mostly the Cray programming environment, such as `PrgEnv-gnu`, which loads the GNU compilers with Cray MPICH. On the one I have used most, there is almost no research software to load beyond that, so nearly everything else comes from conda.
:::

**[Conda and mamba](30-conda.md)** install prebuilt packages from conda-forge into a prefix of your own. A conda package can be anything, a Python package, but also a C library, a Fortran compiler, R, or a command-line tool, and conda-forge has most of the scientific software you are likely to need. So I'd recommend conda for nearly everything the modules don't give you. Its environments are kept in one place, under the conda installation, and it is up to you to remember which project each one belongs to, and to export it if you want to reproduce it, which works only on the same platform, and only while the channel still has every package it names, as [Freezing an environment](../../reproducibility/30-environment.md#from-names-to-hashes) explains.

**[Pixi](40-pixi.md)** uses the same conda-forge packages, and is designed the other way round: the environment is tied to a project directory, typically a git repository, with a lockfile for every platform the project is for, and tasks to run in it. So I'd reach for pixi for a project you want to reproduce, on your laptop and on the cluster.

**[Containers](50-containers.md)** pack a whole Linux userland into one image file, and inside one you can use `apt` or `dnf`, which are otherwise unavailable to you on a shared system. I'd reach for one when the software you need is published as a Docker image, and installing it any other way is painful, which is common in bioinformatics and in machine learning, or when it needs system packages that are not on conda-forge, or an operating system other than the cluster's. A container also helps when your environment is many thousands of small files, which a shared filesystem handles badly (see [Lustre](../../storage/20-lustre.md)), since an image is a single file, however much is inside it. Otherwise, I would not reach for one for something conda can already give you: a container adds a build and an image to keep track of between you and your software, and buys you nothing if the environment inside it is a conda environment you could have used directly.

**[Spack](60-spack.md)** builds compiled software from source, for the machine you run on, against the compilers and libraries the vendor provides. I'd reach for it when the software is compiled (C, C++, Fortran), and has to be built with the vendor's compilers, MPI, or maths libraries to perform well, as is typical of simulation codes that run on many nodes, or is not on conda-forge with the options you need. Many research codes of that kind document a Spack build. The cost is time: a build compiles every dependency the system does not already provide, which can be hundreds of packages and hours of compiling. For Python and its usual packages, conda is the better tool.

## Which to reach for first

Look in the modules for anything tied to the machine, and get everything else from conda-forge, with conda, or with pixi for a project you want to reproduce. Reach for a container when the software comes as a Docker image or needs an operating system's packages, and for Spack when compiled code has to be built for the machine. They also combine: a container can wrap a conda or Spack environment, and [the section on MPI](../mpi/10-intro.md) builds a conda or a Spack environment around the vendor's MPI, loaded from a module.

The [next page](20-modules.md) starts with what is already there: modules.
