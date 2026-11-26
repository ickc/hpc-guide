---
title: "Installing software without sudo"
description: "Why the usual way of installing software does not work on an HPC, what a PREFIX is, the kinds of package manager you can use instead, and where to put what they install."
output-file: intro
---

Sooner or later, your job needs software that the cluster does not have: a newer Python, a library your analysis depends on, or a command-line tool you are used to on your laptop. On your own computer, you would install it with the system package manager, `sudo apt install ffmpeg` on Ubuntu or `sudo dnf install ffmpeg` on Fedora. On an HPC, that does not work, and the reason why shapes everything in this part.

## No `sudo`, so you need a PREFIX

The system package manager installs into directories owned by root, which is why it needs `sudo`. On a shared system, you don't have `sudo`, and the sysadmins will not install everything everyone asks for. They do provide some software, through modules, which is the [next page](20-modules.md). For everything else, you install it yourself, into a directory you can write to.

That directory is called a *PREFIX*: the directory a piece of software is installed into. Inside it are a few standard directories, `bin` for programs, `lib` for libraries, `include` for headers, and `share` for everything else. For example, `bash` is typically installed under the prefix `/usr`, so it is `/usr/bin/bash`, and the libraries it needs are in `/usr/lib64`. If you have ever built something from source with

``` bash
./configure --prefix="$HOME/.local"
make
make install
```

then you have chosen a prefix: the program ends up in `~/.local/bin`, and its libraries in `~/.local/lib`.

So the first requirement of a package manager on an HPC is that it can install into an arbitrary PREFIX of your choosing. That rules out more than you may think. For example, Homebrew's prebuilt packages on Linux are built for the prefix `/home/linuxbrew/.linuxbrew`, which you cannot create without `sudo`. Anywhere else, Homebrew falls back to building everything from source.

Why can't a package built for one prefix simply be put in another? Because the prefix is written into the files that are installed. A Python script's first line names the Python it runs with, as an absolute path such as `#!/home/you/miniforge3/bin/python`. A compiled program records where to find its libraries (its RPATH), and configuration files name the directories they live in. Move the directory, and all of these point to where it used to be.[^1] Unless you are sure the software you installed is designed to be portable, you should assume it is not. Conda has a trick to make its packages relocatable, which is how it can install into any prefix, and which we will come back to [at the end of this part](80-shipping.md).

## Kinds of package manager

There are two kinds of package manager you will want on an HPC, by what they are for:

- those for the software that is missing from the system, that you depend on, but that the sysadmins might not be willing to install for you, such as `ffmpeg`, or a newer `git`;
- those that bootstrap an environment for your research project to run in, such as Python with NumPy and SciPy, at the versions your project needs.

Some can do both, and some are specialized. There is also a second axis: whether they download prebuilt binaries, or build everything from source on your machine. Prebuilt is much faster, and is what you want most of the time. Building from source is slower, but lets you optimize for the exact hardware you run on, and use the compilers and libraries the vendor provides.

The rest of this part goes through them in the order I'd recommend reaching for them:

- [Modules](20-modules.md): what the sysadmins already installed for you, mostly compilers, MPI, and libraries tied to the hardware.
- [Conda and mamba](30-conda.md): prebuilt, does both, and the one I use for nearly everything.
- [Pixi](40-pixi.md): the same packages as conda, organized per project, with a lockfile.
- [Command-line tools for yourself](50-tools.md): how to get the tools you use every day, and how much to trust what installs them.
- [Containers](60-containers.md): when you need a whole operating system's worth of packages, or someone already made an image.
- [Spack](70-spack.md): built from source, for compiled software that has to be tuned to the machine.
- [Shipping an environment to the compute nodes](80-shipping.md): when the shared filesystem becomes the bottleneck.

## Where to put your environments

Before you install anything, decide where it goes, because HPC systems are becoming increasingly heterogeneous. Your `$HOME` is usually on a network filesystem mounted on every node. If the same `$HOME` is also mounted on nodes with a different CPU architecture, say `x86_64` and `aarch64` (Arm), you are going to run into the following issue. You put a binary somewhere, say `~/.local/bin/jq`, and it runs fine on one node. Then you SSH into a node of the other architecture, run it again, and get

``` text
bash: /home/you/.local/bin/jq: cannot execute binary file: Exec format error
```

A program compiled for one architecture cannot run on the other, and the same goes for a whole conda environment. Worse, if you install it again from the second node, you overwrite the first.

::: callout-note
## For example

On one cluster I have used, the Arm (`aarch64`) nodes and a smaller set of `x86_64` nodes share one Lustre filesystem, home directories included, and each kind has its own login nodes. So the same `~/.local/bin` is seen from both architectures.
:::

The fix is an architecture-dependent prefix: put everything you install under a directory named after the operating system and the architecture of the node you are on. Add this to your `~/.bashrc`:

``` bash
# The OS and CPU architecture of this node, e.g. Linux and aarch64.
read -r __OSTYPE __ARCH <<< "$(uname -sm)"
# Everything installed for this architecture goes under here.
export __OPT_ROOT="${HOME}/.local/opt/${__OSTYPE}-${__ARCH}"
export PATH="${__OPT_ROOT}/bin:${PATH}"
```

`uname -sm` prints the kernel name and the machine architecture, such as `Linux aarch64`, so on an Arm node `__OPT_ROOT` is `~/.local/opt/Linux-aarch64`, and on an `x86_64` node it is `~/.local/opt/Linux-x86_64`. From now on in this part, everything gets installed under `$__OPT_ROOT`: programs into `$__OPT_ROOT/bin`, miniforge into `$__OPT_ROOT/miniforge3`, and so on. Each node sees the copy built for it, and installing on one never overwrites the other.[^2]

That leaves one thing to be careful about. By default, a Slurm job inherits the environment variables of the shell you submit it from, `$PATH` and `$__OPT_ROOT` included. So submit a job from a login node of the same architecture as the compute nodes it will run on, and the paths it inherits are the right ones.

Architecture is not the only thing to consider. Environments are many small files, often tens of thousands of them, and they can be several gigabytes, so check your home quota before you start. And don't put them on a scratch filesystem that is purged of files not used for a while, or one day your environment will be missing half of its files.

With a prefix decided, the next page starts with the software that is already there: modules.

[^1]: This is also why a very long prefix can cause trouble. Linux has long limited the first line of a script to 127 characters (256 in recent kernels), so conda, given a prefix longer than that, writes `#!/usr/bin/env python` instead, which runs whichever `python` comes first on your `PATH`, and that may not be the one in the environment.

[^2]: The name is the one my own dotfiles use. Anything that includes the architecture works, as long as you use it consistently.
