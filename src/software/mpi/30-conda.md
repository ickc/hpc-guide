---
title: "Conda and the vendor's MPI"
description: "Three ways to run a conda environment's MPI programs across nodes: conda-forge's external MPICH bound to the vendor's MPI, mpi4py built from source against it, and, last, conda-forge's Open MPI with its own mpirun."
output-file: conda
aliases: [../../package-managers/conda-mpi.html, ../../mpi/conda.html]
---

[The previous page](20-check.md) showed what goes wrong when an environment brings its own MPI. This page is about three ways to get it right with conda, in the order I'd recommend them. Each one is checked with the same `mpi_hello.py`, on 2 nodes, and since the job scripts below live in their own directories next to it, they run it as `../mpi-hello/mpi_hello.py`.

The examples use mpi4py, because it is easy to test, but the same goes for any conda-forge package built against MPI, such as `h5py=*=mpi_mpich_*`.

## MPICH from the vendor, the rest from conda

This is the route I'd recommend for most people, and it is the MPICH ABI from [the introduction](10-intro.md) put to work. conda-forge publishes *external* builds of MPICH, under the label `conda-forge/label/mpi-external`. They are [empty packages](https://conda-forge.org/docs/user/tipsandtricks/#using-external-message-passing-interface-mpi-libraries): they tell the solver that there is an MPICH, so that mpi4py and everything else is built against MPICH, but they install no MPI library at all. At run time, the library comes from the vendor.

The environment asks for the external build explicitly:

``` {.yaml include="../../examples/conda-mpich/environment.yml"}
```

and is created with

``` bash
mamba env create --channel-priority flexible -f environment.yml
```

The label is listed before `conda-forge`, and `mpich * external_*` asks for a build whose name starts with `external_`, which only the label has. `--channel-priority flexible` is there because many conda installations use strict channel priority, and with strict priority, the ordinary `conda-forge` channel can hide the external builds even though the label comes first, and then the solver finds no MPICH that matches.

In the job, the vendor's MPI has to be loaded, and its `libmpi.so.12` has to be where the dynamic linker looks for it. On a Cray system, the job script is

``` {.bash include="../../examples/conda-mpich/job.sh"}
```

`PrgEnv-gnu` is the Cray programming environment with the GNU compilers, which loads Cray MPICH, and the libfabric it talks to the network through. It also sets `MPICH_DIR` to where Cray MPICH is installed, and `lib-abi-mpich` under it is the copy of Cray MPICH with the MPICH ABI, named `libmpi.so.12` like MPICH's. Since the environment has no `libmpi.so.12` of its own, putting that directory on `LD_LIBRARY_PATH` is all it takes for mpi4py to find it. Without that line, mpi4py fails to import, since there is no MPI library to load. On another system, you load whichever module provides the vendor's MPI, and point `LD_LIBRARY_PATH` at the directory with its `libmpi.so.12`, if the module doesn't already.

On a Cray EX system with Slingshot, this gives the PASS from the previous page, with Cray MPICH as the MPI library and 8 ranks over 2 nodes. When I tested it with 576 ranks on 4 nodes, the libraries it loaded were Cray MPICH, Cray's libfabric, Cray's PMI, and `libcxi`, the library for the Slingshot network, which is the evidence that it uses the fast network.

This is convenient, but it is not the most direct way to use the vendor's MPI: everything in the environment was built against conda-forge's MPICH, and only runs on the vendor's through the ABI. For production runs where MPI performance matters, I'd build mpi4py against the vendor's MPI directly, which is the next route.

## mpi4py built from source against the vendor's MPI

Here conda provides only Python and pip, with this environment:

``` {.yaml include="../../examples/conda-mpi4py-source/environment.yml"}
```

and mpi4py is built from source, with the vendor's compiler and MPI loaded. On a Cray system:

``` {.bash include="../../examples/conda-mpi4py-source/install.sh"}
```

`MPICC` tells mpi4py's build which compiler to compile and link with. `cc` is Cray's compiler wrapper, which adds Cray MPICH by itself, and `-shared` is because mpi4py is a shared library that Python loads. `--no-binary mpi4py` makes pip build it rather than download a prebuilt one, and `--no-cache-dir` and `--force-reinstall` make sure it does, even if a built copy is already around. On another system, `MPICC=mpicc`, with the vendor's MPI module loaded, is the usual equivalent. Run this on the kind of node the job will run on, as in [the conda page](../package-managers/30-conda.md) of the previous part.

The job is the same as before, without the `LD_LIBRARY_PATH` line, since mpi4py is now linked against the vendor's libraries directly:

``` {.bash include="../../examples/conda-mpi4py-source/job.sh"}
```

Load the same modules in the job as for the build. On the same system, this also passes, with Cray MPICH, and the mpi4py it builds links directly to Cray MPICH, Cray's libfabric and PMI, and `libcxi`.

The cost is that you now build a package yourself, and anything else in the environment that needs MPI, h5py say, has to be built the same way, or come from the first route.

## Open MPI, with its own `mpirun`

Some applications require Open MPI specifically. Since a vendor MPI derived from MPICH cannot stand in for Open MPI, there is no external route, and what you can do from conda is use conda-forge's Open MPI as it is, with this environment:

``` {.yaml include="../../examples/conda-openmpi/environment.yml"}
```

Launched with `srun`, it gives you the singleton worlds of the previous page.[^1] So it has to be launched with its own `mpirun`, told to get the job's nodes from Slurm and to start the processes through it:

``` {.bash include="../../examples/conda-openmpi/job.sh"}
```

The vendor's MPI is left unloaded, since this Open MPI brings everything it needs. `--prtemca ras slurm` and `--prtemca plm slurm` select the parts of Open MPI's launcher that read the allocation from Slurm and start processes with it. `--np 8` is the number of ranks, and `--map-by ppr:4:node:PE=1` places 4 processes per node, with one core each, which `--bind-to core` pins them to.

This passes the check, and forms one world across the nodes. But it is not using the fast network the way the vendor's MPI does. When I tested it with 576 ranks on 4 nodes, it passed, but did not load `libcxi`, and the evidence pointed to TCP over the nodes' network interfaces, rather than the libraries the vendor's MPI uses for the network. So I'd only use this when an application really needs Open MPI, and building Open MPI yourself for the system is not an option.[^2]

::: callout-tip
## Which one?

If you only need mpi4py, or a conda-forge package with an MPICH variant, start with the first. If MPI performance matters, build mpi4py against the vendor's MPI. Use Open MPI from conda only when the application leaves you no choice, and expect it not to use the network the way the vendor's MPI does. Whichever you choose, run `mpi_hello.py` in it first.
:::

Conda is the right tool when MPI is one dependency among many in a Python environment. For compiled MPI codes, the ones built from source that spend their time communicating, [the next page](40-spack.md) is about doing the same with Spack.

[^1]: On the Cray EX system I tested this on, each process prints "No PMIx server was reachable" before it starts on its own. PMIx is the kind of PMI Open MPI 5 expects.

[^2]: conda-forge's own documentation also notes that its MPI builds lack some features that speed up communication even within a node, such as XPMEM for MPICH and CMA for Open MPI.
