---
title: "Modules"
description: "The software the sysadmins installed for you: how to find it, what loading a module does, loading it in a batch job, and mixing modules with your own environments."
output-file: modules
aliases: [../../package-managers/modules.html]
---

Before installing anything yourself, it is worth knowing what the sysadmins already installed. On nearly every HPC, that software is made available through *environment modules*: each module is a prefix someone else installed, plus a recipe for putting it on your `PATH`.

## Finding and loading modules

``` bash
module avail          # everything you can load
module avail gcc      # only the modules whose name contains gcc
module spider python  # search every module, including ones hidden behind others (Lmod only)
module load gcc       # load the default version
module load gcc/13.2  # or a specific one
module list           # what is loaded now
module unload gcc     # unload one
module purge          # unload everything
```

There are two implementations of the `module` command in use, Lmod and the older Tcl-based Environment Modules. They take the same basic commands, and Lmod adds a few, like `module spider`, which searches modules that only show up after you load something else (for example, the libraries built with a particular compiler).[^1]

What does loading a module actually do? `module show` tells you:

``` bash
module show gcc
```

It prints something like

``` text
prepend_path("PATH","/path/to/gcc/13.2/bin")
prepend_path("LD_LIBRARY_PATH","/path/to/gcc/13.2/lib64")
prepend_path("MANPATH","/path/to/gcc/13.2/share/man")
setenv("CC","gcc")
```

That is all a module is: it puts another prefix in front of your search paths, `PATH` for programs and `LD_LIBRARY_PATH` for the libraries they load, and sets a few variables. Nothing is installed or copied when you load it, and `module unload` takes the same entries off again.

## Modules in a job

A job inherits the modules loaded in the shell you submit it from, because it inherits the environment variables they set. That is convenient, and it is also how a job that worked yesterday fails today: you loaded something else in your shell before submitting it. So make the job load what it needs itself, at the top of the script:

``` bash
#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:10:00

module purge
module load gcc/13.2

gcc --version
```

`module purge` starts from a clean slate, and naming the version means the job still gets the same compiler after the sysadmins change the default. Some clusters have modules loaded by default that you should keep (for example, the one that sets up the scheduler or the interconnect), in which case `module reset` returns to the defaults instead of unloading everything. Your cluster's documentation will say which.[^2]

## Modules and your own environments

A module's Python has the version the sysadmins chose, at the time they chose it, and you cannot add packages to it. A `pip install --user` on top of it goes into `~/.local/lib/python3.X`, which every other Python of the same version picks up too, the ones in your conda environments included.

Be careful about mixing modules with the environments on the following pages. A module prepends to `PATH`, so whichever of the two you set up last wins: load a Python module after activating a conda environment, and `python` is the module's, without the packages you installed. So load modules first, and activate the environment after. A module also prepends to `LD_LIBRARY_PATH`, and anything that looks there for a library can pick up the module's version instead of the one it was built against, which shows up as an error like `` version `GLIBCXX_3.4.30' not found ``. If you need a module and a conda environment in the same job, load as few modules as you can, and if something breaks, `module purge` is the first thing to try. Where you do need both, for MPI, [the section on MPI](../mpi/30-conda.md) shows how to do it properly.

The [next page](30-conda.md) is about conda, which installs software into a prefix of your own.

[^1]: `module --version` tells you which one your cluster has.

[^2]: If a batch script fails with `module: command not found`, the shell running it did not read the system's startup files, which is where `module` is defined. Starting the script with `#!/bin/bash -l`, a login shell, usually fixes it.
