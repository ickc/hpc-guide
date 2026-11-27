---
title: "MPI and the vendor's MPI"
description: "What MPI is, why the MPI the vendor installed is the one that knows the network and the scheduler, why you launch with srun, and the MPICH ABI, which lets software from conda run on the vendor's MPI."
output-file: intro
aliases: [../../mpi/intro.html]
---

So far, this part has mostly treated a package as something that either works or doesn't. MPI is where that stops being true: an MPI program can install and run to the end without an error, while not doing what you asked for. This section is for you if you have an MPI program, whether you wrote it, use one someone else wrote, or use mpi4py from Python, and have never had to think about which MPI it runs on.

## What MPI is

MPI, the Message Passing Interface, is how a program runs as many processes, on one node or on many, that work on one problem together by sending each other messages. Each process is a *rank*, numbered from 0, and all the ranks of a run together form the *world*, `MPI_COMM_WORLD`. When rank 0 adds up a number from every other rank, that is a message from each of them to rank 0, and if the ranks are on different nodes, the message goes over the network between the nodes.

MPI is a standard, not a program. What you install is an *implementation* of it, a library (`libmpi.so`) that your program is linked against, and there are two main families: [MPICH](https://www.mpich.org) and [Open MPI](https://www.open-mpi.org). Many others are derived from MPICH, including the MPI that a vendor such as HPE Cray ships with its machines. mpi4py is the same: it is a Python wrapper around whichever `libmpi.so` it was built against.

## Why the vendor's MPI

What makes an HPC an HPC, rather than a room of computers, is mostly the network between the nodes, the *interconnect*, which is much faster than ordinary Ethernet. An MPI only uses it if it was built against the library that drives that network, with the driver for that particular hardware.[^1] The MPI the vendor installed, usually as a module, was built for exactly that.

It also knows the scheduler. When you launch 8 ranks on 2 nodes, each process has to find out its rank, how many others there are, and how to reach them. The scheduler knows all of that, and tells the processes through an interface called PMI, the Process Management Interface. The vendor's MPI is built to talk to the PMI that Slurm provides on that cluster.

An MPI from conda-forge, or one you build yourself without care, knows neither. It brings its own copy of the networking libraries, built to run anywhere, and so without the driver for your network, and it may not understand the PMI your Slurm offers. conda-forge [says as much](https://conda-forge.org/docs/user/tipsandtricks/#using-external-message-passing-interface-mpi-libraries): on HPC systems, its own MPI "often either does not work at all or functions in unexpected ways".

## Launching with `srun`

So you launch an MPI program with `srun`, inside a job:

``` bash
srun python mpi_hello.py
```

`srun` starts one process for each task in the job's allocation (8, for `--nodes=2 --ntasks-per-node=4`), on the right nodes, and gives each of them what it needs to find the others through PMI. The vendor's MPI picks that up, and the processes form one world. `srun --mpi=list` shows which kinds of PMI your Slurm offers.

You will see instructions that use `mpirun` or `mpiexec` instead. Those come with an MPI, and each launches processes its own way. If your `mpirun` comes from conda, it can form a world across nodes, because it can ask Slurm which nodes the job has and start its processes on them. But it uses its own MPI, with its own networking libraries, so it does not use the fast network the way the vendor's MPI does. When I tested this on a Cray EX system with Slingshot, conda-forge's Open MPI, launched with its own `mpirun`, formed one world of 576 ranks across 4 nodes, but without loading the library for the Slingshot interconnect at all, so it was most likely talking over TCP. conda-forge's MPICH, launched with its own `mpiexec`, ran on one node but failed to start on 4. And either of them launched with `srun` gave every process a world of its own, which is the subject of [the next page](20-check.md).

## The MPICH ABI

So the MPI has to be the vendor's. But the rest of your software, mpi4py, or h5py with MPI, or a whole analysis environment, comes from conda, built against conda's MPI. That is where the MPICH ABI comes in.

An ABI, an application binary interface, is what a compiled program expects of a library at the level of the machine code: the names of its functions, and the sizes and layout of its types. The source code of an MPI program is portable between MPI implementations, since they all implement the same standard, but the compiled program is not, unless the two have the same ABI. MPICH and the MPIs derived from it agreed on one, through the [MPICH ABI Compatibility Initiative](https://www.mpich.org/abi/), announced in 2013, and Intel MPI, MVAPICH and Cray's MPI are among them. So a program compiled against conda-forge's MPICH runs unchanged against the vendor's `libmpi.so.12`, as long as that is the `libmpi.so.12` the dynamic linker finds when it starts.

That is the idea the rest of this section builds on. conda-forge has builds of MPICH that are empty, so that everything else in the environment is built against MPICH, while the library itself comes from the vendor at run time. Open MPI has an ABI of its own (its library is `libmpi.so.40`), so none of this works between an Open MPI and an MPICH: a program built against one cannot run on the other.

Before fixing anything, though, you need to know whether your MPI is broken in the first place, which is less obvious than it sounds. [The next page](20-check.md) is a check for that.

[^1]: On many systems that library is [libfabric](https://ofiwg.github.io/libfabric/), which has a *provider* for each kind of network; on others it is UCX. An MPI built against libfabric without the provider for your network falls back to whatever else it can find, such as TCP over the ordinary network, or fails.
