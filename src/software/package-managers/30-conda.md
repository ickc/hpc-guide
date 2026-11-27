---
title: "Conda and mamba"
description: "Why conda, why conda-forge rather than Anaconda's channels, how to install miniforge, and how to use an environment in a batch job."
output-file: conda
aliases: [../../package-managers/conda.html]
---

Modules give you what the sysadmins installed. For the rest, you install into a prefix of your own, and this page is about doing that with conda: why, and how to use it well on an HPC.

## Why conda

If you use Python, the obvious place to get packages is PyPI, with `pip install` (or `uv`). There, the maintainers of each package upload it directly, and that has two disadvantages.

The first is supply chain attacks. There is no layer between you and the maintainer, so compromising a maintainer directly compromises you. The second is packages that are poorly packaged. Poor can mean an environment that is not reproducible, because the package depends on something outside it, or even builds itself at install time with whatever compiler it finds on your machine. For example, the [`setup.py` of pixell](https://github.com/simonsobs/pixell/blob/b41248618ce92277a19a4efccadfc3b7403d67f5/setup.py), a package for maps of the sky, looked for C, C++ and Fortran compilers on your system, and if Cython was missing, ran `conda install cython` and then `pip install cython` from inside its own build. When a build like that fails on another machine, the error messages can be extremely cryptic. Poor can also mean improperly licensed software, such as a package with no licence file. None of this may be true of the packages you use, but it is something you would need to verify per package, including everything they depend on.

Conda exists because scientific Python ran into exactly this. In 2012, at a panel at PyData, Guido van Rossum, the creator of Python, said of the scientific community's packaging problems that

> it really sounds like your needs are so unusual compared to the larger Python community that you're just better off building your own

([the panel](https://www.youtube.com/watch?v=QjXJLVINsSA&t=3555), and [Jake VanderPlas's account of what followed](https://jakevdp.github.io/blog/2016/08/25/conda-myths-and-misconceptions/)). That statement became the catalyst for creating conda, which has since grown into a language-agnostic, multi-platform package manager. Language-agnostic means a conda package can be anything: a Python package, but also a C library, a Fortran compiler, R, Rust, or a shell script. Multi-platform means the same package is built for Linux on `x86_64`, `aarch64` and `ppc64le`, macOS on Intel and Apple Silicon, and Windows, so the same environment file works on your laptop and on the cluster. And the build of a conda package brings its own compilers and libraries, rather than using whatever is on the build machine, so it is close to *hermetic*: an environment that works on your computer is not guaranteed to work on another, but the chance is much higher than with packages that build themselves at install time.

## conda-forge, not Anaconda's channels

Conda installs packages from *channels*, which are like an APT repository if you are familiar with Ubuntu. Out of the box, conda from Anaconda (the company) uses Anaconda's own channels, often called `defaults`. The other big one is [conda-forge](https://conda-forge.org), a [NumFOCUS project](https://numfocus.org/project/conda-forge) run by an independent community of maintainers. Every conda-forge package has a "feedstock" on GitHub with its recipe, and is built openly in CI, for every platform and, where relevant, every Python version and variant. To get a package on conda-forge, the build has to be reproducible, and the licence has to be there. And because it adds layers of maintainers, those of the package and those of conda-forge, between you and the upstream developer, it adds layers of defence against a supply chain attack.

I'd recommend using conda-forge only, for two reasons. It has far more of the scientific packages you are likely to need. And it takes you out of Anaconda's licensing altogether. Use of Anaconda's channels is governed by [Anaconda's terms of service](https://www.anaconda.com/legal/terms/terms-of-service), which have changed more than once, and under which a large organization, as a university is, may need a paid licence. Whether that covers you is a question for your institution, and with conda-forge, which has no such terms, it is a question you never have to ask.

So install [miniforge](https://github.com/conda-forge/miniforge), a minimal distribution of `conda` and `mamba` that uses conda-forge only, not Anaconda or Miniconda. Into the architecture-dependent prefix from [the introduction](../10-intro.md):

``` bash
curl -fsSL "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname -s)-$(uname -m).sh" -o Miniforge3.sh
bash Miniforge3.sh -b -p "${__OPT_ROOT}/miniforge3"
rm Miniforge3.sh
```

`-b` installs without asking questions, and `-p` sets the prefix. Then, rather than letting `conda init` edit your `~/.bashrc`, add these two lines to it yourself, after the lines that set `__OPT_ROOT`:

``` bash
source "${__OPT_ROOT}/miniforge3/etc/profile.d/conda.sh"
source "${__OPT_ROOT}/miniforge3/etc/profile.d/mamba.sh"
```

They define the `conda` and `mamba` commands, including `conda activate`, for whichever architecture you are on.

## Why mamba

mamba is a(n almost) drop-in replacement for conda: `mamba create`, `mamba install` and `mamba activate` take the same arguments as their conda counterparts. It started as a faster solver, the part that works out which versions of which packages fit together. The original conda solver, written in Python, worked correctly but was very slow, and as people built larger and larger environments, solving could take hours. conda has used mamba's solver by default since conda 23.10, so the difference is smaller than it was, but mamba is still faster, and personally I now only use mamba.

micromamba, a single, statically linked binary that needs no base environment of its own, can replace mamba in most situations, but is mostly used by people building CI. I'd recommend miniforge unless you have a reason not to, since most instructions assume a base environment with conda in it.

## Making an environment

Never install your packages into the base environment, the one miniforge was installed into. It holds conda and mamba themselves, and breaking it breaks both. Make a new environment for each project instead, from a file that lists what it needs, like this `environment.yml`:

``` {.yaml include="../../examples/conda-job/environment.yml"}
```

``` bash
mamba env create -f environment.yml
mamba activate numpy-demo
```

The environment is named `numpy-demo`, from the file, and lives in `$__OPT_ROOT/miniforge3/envs/numpy-demo`. You can also give it a path instead of a name, with `-p`, and activate it by its path.

### Variants

conda-forge packages are generally better packaged, and one way that shows is variants: the same package is often built several ways, and you choose which. For example, [you can switch the BLAS implementation](https://conda-forge.org/docs/maintainer/knowledge_base/#switching-blas-implementation) every package in the environment uses:

``` bash
mamba install "libblas=*=*_openblas"
mamba install "libblas=*=*_mkl"
mamba install "libblas=*=*_blis"
```

There are even [builds optimized per microarchitecture](https://conda-forge.org/docs/maintainer/knowledge_base/#microarch), such as `x86_64-v3` and `x86_64-v4` with wider vector instructions. Packages that can use MPI come in variants too, one for each MPI and one without, which [the page on conda and the vendor's MPI](../mpi/30-conda.md) is about.

## Using the environment in a batch job

A batch job runs in a non-interactive shell, which does not read your `~/.bashrc`, so `conda activate` may not be defined there. The most portable way to define it, which works with miniforge, Miniconda and Anaconda alike, is to source the script conda ships for it:

``` {.bash include="../../examples/conda-job/job.sh"}
```

`conda info --base` prints where conda is installed, and `etc/profile.d/conda.sh` under it defines `conda activate`. This needs `conda` itself on your `PATH`, which the job inherits from the shell you submitted it from. (The `${CONDA_ENV:-numpy-demo}` means the environment named in `$CONDA_ENV`, or `numpy-demo` if that is not set.) Each tool also has its own way to do the same, with a choice of shell:

``` bash
eval "$(conda shell.bash hook)"
eval "$(mamba shell hook -s bash)"
eval "$(micromamba shell hook -s bash)"
eval "$(pixi shell-hook -s bash)"
```

### Activate once, on the login node

Every `conda activate` starts Python, which reads hundreds of files from the shared filesystem. For one job, that is a second or two. For a job array of thousands of short tasks, all starting at once, it is thousands of Python start-ups hammering the same filesystem, before any of your work starts.

But a job inherits the environment variables of the shell that submitted it, and activating an environment is, in the end, setting environment variables: `PATH`, `CONDA_PREFIX`, and whatever the packages' own activation scripts set. So when the login nodes and the compute nodes are the same kind of machine, it is a better practice to activate the environment on the login node, once, and let every job inherit it. A heredoc keeps the activation and the job together in one script, `submit.sh`, that you run on the login node:

``` {.bash include="../../examples/conda-job/submit.sh"}
```

Everything between `<<'EOF_JOB'` and `EOF_JOB` is given to `sbatch` as the batch script, on its standard input, the same as if it were a file. The quotes around the first `'EOF_JOB'` stop the shell from expanding any `$` inside it now, so the batch script is passed on as written. `--export=ALL` is what makes the job inherit the environment. It is Slurm's default, but some clusters change the default, so I'd rather say so. And `"$@"` passes on any options you give `submit.sh`, so `./submit.sh --partition=short` works as you'd expect.

### Resolve on the hardware you will run on

There is one exception to the above. When conda solves an environment, it takes into account the machine it is running on, through *virtual packages*. `conda info` lists them:

``` text
       virtual packages : __archspec=1=zen4
                          __cuda=12.4=0
                          __glibc=2.34=0
                          __linux=5.14.0=0
```

`__cuda` is the CUDA version the GPU driver supports, `__archspec` is the CPU microarchitecture, and `__glibc` the version of the system C library. A package can depend on them: the GPU build of a package needs `__cuda`, and a microarchitecture-optimized build needs a matching `__archspec`. So the same `environment.yml` can resolve to different packages on a login node with no GPU and an older CPU than on a compute node with a GPU and a newer one. On such exotic platforms, where login nodes and compute nodes are fundamentally different, it is better to create the environment on the hardware your job will run on, in an interactive job on a compute node. If you can't, you can tell conda what to assume, for example `CONDA_OVERRIDE_CUDA=12.4 mamba env create -f environment.yml` for a GPU environment from a login node without one.

## Sharing an environment

To reproduce an environment elsewhere, export it:

``` bash
# every package, at its exact version and build: analogous to a lockfile
mamba env export > environment.lock.yml
# only what you asked for: re-solved, so newer versions, when it is created again
mamba env export --from-history > environment.yml
```

Then `mamba env create -f environment.lock.yml` reproduces exactly the same environment on a machine of the same platform. Only of the same platform, though: an export from Linux `x86_64` can include packages, such as MKL, that do not exist for `aarch64`. `conda create -n env2 --clone env1` makes a copy of an environment under a new name.

The [next page](40-pixi.md) is about pixi, which uses the same conda-forge packages.
