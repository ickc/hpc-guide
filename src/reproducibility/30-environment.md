---
title: "Freezing an environment"
description: "Why an environment.yml, a module load or a README's 'Python 3' gives a different environment months later; the ladder from names to versions to a lockfile and an image's digest, and what each lockfile pins; locking from the recipe rather than exporting after drift; containers; and what a lockfile does not cover."
output-file: environment
---

[The previous page](20-determinism.md) was about the inputs inside your program. The largest input outside it is the software it runs with, and this page is about freezing that, with the files [Software environments](../software/10-intro.md) already introduced.

## The recipe

The recipe you probably have is one of these: an `environment.yml` that lists `numpy`, a batch script that starts with `module load python`, or a README that says the code needs Python 3. Each of them worked on the day it was written, and each of them is a list of names.

## Why it bites

A name is looked up every time it is used, and what it finds changes:

- Create the environment from the same `environment.yml` months later, and the solver picks the newest versions that fit, which are not the ones you had. Packages have had new releases since, and conda-forge also [corrects the metadata of packages it has already published, and marks broken ones](https://conda-forge.org/docs/how-to/emergencies/remove-broken-packages/), after which no solve picks them.
- `module load python` loads the default version, which the sysadmins change from time to time, as [the page on modules](../software/package-managers/20-modules.md#modules-in-a-job) warned.
- The cluster's operating system is upgraded, and with it the system's libraries and compilers, and the modules built on them.
- Someone ran `pip install` into the environment since, so it is no longer what any file says.
- The environment was in `$SCRATCH`,[^1] and the purge took half of its files.
- A URL that a build downloaded from is gone.

An OS upgrade looks like a problem of time, but that is an illusion, and so is each of the others. What changed is what a name in the recipe resolves to: `numpy`, `python`, the system's C++ library, a URL. So the fix is to write down what each name resolved to, at a level you choose.

## From names to hashes

There are four levels, each pinning more than the one before:

|  | Example | Pins |
|----|----|----|
| Names | `numpy` in an `environment.yml` | nothing: the solver chooses again every time |
| Versions | `numpy=2.3` | the versions you wrote, while their dependencies are chosen again |
| A lockfile | `pixi.lock`, or an export of an environment | every package in the environment, at its exact build |
| An image's digest | `python@sha256:...` | every byte of a container image |

Versions are what most `environment.yml` files have, and a version is still a name: a channel can publish a new build of the same version, as a registry can point a tag at another image, so either can come to mean a different file, which a hash cannot. The level that matters is the lockfile, and the four kinds of lockfile pin different things, so check what yours records:

| Made with | Records | With a hash | For |
|------------------------------|------------------------------|------------------------------|------------------------------|
| `mamba env export` | every package's name, version and build | no | the platform it was exported on |
| `conda list --explicit --md5` | every package's URL | the MD5 of each, checked when it is installed | the platform it was exported on |
| `pixi.lock` | every package's URL, from conda-forge and from PyPI | the SHA-256 of each | every platform in `pixi.toml` |
| `spack.lock` | every package's version, variants, compiler and target | a hash of each package's spec, and Spack checks the sources it downloads against the checksums in its recipes | the targets it was concretized for |

The pages on [conda](../software/package-managers/30-conda.md#sharing-an-environment), [pixi](../software/package-managers/40-pixi.md#the-lockfile) and [Spack](../software/package-managers/60-spack.md#a-worked-example) show how to make each. The difference between the first two shows when a package is marked broken: `mamba env create` from an export runs a solve, which no longer finds it, while `conda create --file` from the explicit list downloads it by its URL, which still works. And only `pixi.lock` covers more than one platform in one file. So for a conda environment, I'd recommend `conda list --explicit --md5 > linux-64.txt`, one such file made on each platform you run on, and for a project, pixi, which does this for you.[^2]

## Lock from the recipe, not from the environment

A lockfile records an environment, so which environment it records matters. Export one that was changed by hand since it was made, a `pip install` here and a `mamba install` there, and the lockfile records what is there now, with nothing to say how it got there, or how to make it again with one package newer, or on another platform. So change the environment only through its recipe: edit the `environment.yml` or the `pixi.toml`, solve it again into a new environment, and lock that. With conda, that is `mamba env create -f environment.yml` and then `conda list --explicit --md5` of the new environment. Pixi does it by itself, since `pixi add` changes `pixi.toml` and `pixi.lock` together.

## A container is not frozen either

A container image holds a whole userland, so it looks frozen. But its definition usually runs `apt-get update` or a solve when it is built, as the one on [the page on containers](../software/package-managers/50-containers.md#running-and-building-an-image) does: it starts from `condaforge/miniforge3:latest` and solves `numpy`, so building it again next month gives a different image. So keep both: the definition file, for how the image was made, and the digest of the image you ran, for exactly what it was.

A registry names every image by its digest, `sha256:` followed by a hash of its contents, alongside whichever tags point to it. Pull by the digest rather than the tag,

``` bash
apptainer pull python.sif docker://python@sha256:<digest>
```

and start a definition file `From:` a digest rather than `:latest`. Keep the `.sif` file you ran as well: [pulling the same Docker image twice gives two different `.sif` files](https://apptainer.org/docs/user/latest/docker_and_oci.html), since the conversion writes metadata such as dates into it.

## Limitations

A lockfile pins what would be downloaded, not that it can still be downloaded: a channel can drop a package, and a registry an image, which is what archiving, at the end of this part, is about. It says nothing about what the cluster provides, the modules, the MPI, the GPU driver, the kernel and the CPU, which you cannot lock, only record. And one recipe solved for two platforms gives two environments, with different packages in them, such as MKL, which conda-forge has for `x86_64` and not for `aarch64`, and so possibly different numbers from the same code.

The next page is about that part of the environment, the one that belongs to the centre, and how to record it in every job.

[^1]: `$SCRATCH` is what many clusters call their scratch space, large and fast but purged of files not used for a while. Not every cluster sets it, and some use another name, so look for that kind of storage in your centre's documentation; [the part on storage](../storage/10-where.md) is about the kinds there are.

[^2]: Make the environment again from the list with `mamba create -p /path/to/env --file linux-64.txt`. Since conda 24.9, `--sha256` records SHA-256 hashes instead of MD5.
