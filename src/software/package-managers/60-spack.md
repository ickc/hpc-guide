---
title: "Spack"
description: "Building compiled software from source, for the machine you run on, with Spack: what it is for, and a Spack environment from start to finish."
output-file: spack
aliases: [../../package-managers/spack.html]
---

Conda gives you prebuilt packages, and a container gives you a prebuilt operating system. Sometimes what you need instead is compiled software built from source, for the exact machine you run on, against the compilers and libraries the vendor provides. That is what [Spack](https://spack.io) is for.

Spack is a package manager that builds everything from source, in your home directory, without `sudo`. Each package has *variants*, options you choose when you build it, such as `+openmp` to build with OpenMP, or `^openblas` to build against OpenBLAS rather than another BLAS. Spack can also use software already on the system, such as the vendor's compilers and MPI, as *externals*, instead of building its own. Every combination of version, variants, compiler and dependencies gets its own install directory, named by a hash, so builds with different options live side by side.

## When to reach for it

I'd reach for Spack when the software is compiled (C, C++, Fortran), and

- it is not on conda-forge, or the build there does not have the options you need, or
- it has to be built with the vendor's compilers, MPI, or maths libraries to perform well, as is typical of simulation codes that run on many nodes.

Many research codes in that category document a Spack build, and many sysadmins build their modules with Spack, so you may already have used it without knowing.

The cost is time. A Spack build compiles every dependency that is not an external, which can be hundreds of packages and hours of compiling, and if one of them fails, the build log is yours to read. For Python and its usual packages, conda is the better tool.

## A worked example

Get Spack itself by cloning it, into your architecture-dependent prefix from [the introduction](../10-intro.md), and set up your shell:

``` bash
git clone --depth=2 --branch=releases/v1.2 https://github.com/spack/spack.git "${__OPT_ROOT}/spack"
source "${__OPT_ROOT}/spack/share/spack/setup-env.sh"
```

`--branch=releases/v1.2` is the latest release at the time of writing, and `--depth=2` skips most of its history. The second line defines the `spack` command; add it to your `~/.bashrc` if you will use Spack often.[^1]

Then tell Spack what is already on the system:

``` bash
spack compiler find
spack external find
```

The first finds the compilers on your `PATH` (load a compiler module first, if that is how your cluster provides them), and the second finds build tools and libraries, such as `cmake` and `perl`, so that Spack does not build its own.

Then, as with pixi, make an environment for your project, in its directory:

``` bash
spack env create -d .
spack env activate .
spack add fftw +openmp ~mpi
spack spec
spack install -j 8
```

`spack env create -d .` makes an environment in the current directory, as a `spack.yaml`. `spack add` adds FFTW, the FFT library, with OpenMP and without MPI. `spack spec` shows what Spack is going to build, every package with its version, variants and compiler, and is worth reading before you start a build that could take hours. `spack install` builds it, with 8 parallel compile jobs, and writes `spack.lock`, which, like pixi's, records exactly what was built. Commit `spack.yaml`, and someone else can build the same thing.

In a job, activate the environment the same way:

``` bash
source "${__OPT_ROOT}/spack/share/spack/setup-env.sh"
spack env activate /path/to/your/project
```

or, to save starting Spack in every job, write the activation out once, as a plain shell script, with `spack env activate --sh /path/to/your/project > activate.sh`, and `source activate.sh` in the job.

## Build where you run

By default, Spack builds for the microarchitecture of the machine it is running on. `spack arch` shows what that is, for example `linux-rhel9-neoverse_v2`. So, as with conda's [virtual packages](30-conda.md), build on the kind of node your jobs will run on, or say what to build for with `target=`, for example `spack add fftw +openmp ~mpi target=neoverse_v2`. A build for the login node's CPU may run on a compute node with a newer CPU without using its newer instructions, or not run at all on an older one.

A build is also heavy, so ideally run it in an interactive job on a compute node. Spack downloads sources as it builds, though, so on a cluster whose compute nodes cannot reach the internet, it has to run on a login node instead. There, keep `-j` small, since the login node is shared with everyone else.

## MPI

The main reason to use Spack on an HPC is to build against the vendor's MPI and interconnect libraries, as externals, and how to do that properly is in [the MPI part](../mpi/40-spack.md).

That is the last of the package managers. The [next page](../30-tools.md) is about the other kind of software from [the introduction](../10-intro.md): the tools you want everywhere, whatever the project.

[^1]: Since Spack 1.0, the recipes for its packages are in a repository of their own, which Spack downloads the first time it needs them.
