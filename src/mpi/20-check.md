---
title: "Does your MPI span the nodes?"
description: "The symptom of an MPI that is not wired up to the cluster, a job that runs but does not scale, and a short mpi4py program that checks whether all the ranks form one world across the nodes."
output-file: check
---

[The introduction](10-intro.md) said that an MPI from conda, launched with `srun`, gives every process a world of its own. This page is about what that looks like, and how to check for it, because it does not look like an error.

## The symptom

Say you need mpi4py, and do what you would on your own computer:

``` bash
mamba env create -f environment.yml
```

with this `environment.yml`, which asks for mpi4py, and MPICH as the MPI under it, both from conda-forge:

``` {.yaml include="../examples/mpi-hello/environment.yml"}
```

Then you ask for 2 nodes, 4 tasks on each, and launch your program with `srun`. Every one of the 8 processes starts, imports mpi4py, and initializes MPI. None of them can find the others, since conda's MPI does not understand what Slurm tells it, so each one decides it is alone, and becomes rank 0 of a world of size 1.

Nothing about that is an error from MPI's point of view. A program written to split its work between the ranks sees one rank, does all of the work, and writes its output, and so do the 7 others, at the same time, to the same files if it writes any. The job finishes in about the time it would take on one core, rather than 8 times faster, and if you didn't look closely, you'd conclude that your program "doesn't scale". The allocation is spent, and the result may even be correct, 8 times over.

## The check

So before you trust an MPI environment with a real run, check that the ranks form one world, with a program that does nothing else. Here is one in Python, with mpi4py, which also works as a check of the MPI under a compiled program, as long as mpi4py is built against the same MPI:

``` {.python include="../examples/mpi-hello/mpi_hello.py"}
```

Every rank takes part in an `allreduce`, which adds up a 1 from each of them, so the sum is the number of ranks that actually communicated. Then rank 0 collects the name of the node each rank is on, prints a report, and says whether one world spans every rank.

Run it with a job script set up exactly the way your real MPI job is, the same modules and the same environment, on at least 2 nodes, since a world on one node tells you nothing about the network between them:

``` {.bash include="../examples/mpi-hello/job.sh"}
```

## Reading the output

With the environment above, each of the 8 processes is rank 0 of its own world, so each of them prints the report, 8 times in all, every time with

``` text
world size: 1
allreduce sum: 1 (expected 1)
nodes in world: 1
```

and ends with `RESULT: FAIL - ranks did not join a single MPI world`, so the job fails too. That is the singleton world: the program ran, and no MPI communication happened at all.

With an MPI that is wired up properly, as on the [next page](30-conda.md), you get one report, from the one rank 0, and on Isambard 3 it looks like this:

``` text
MPI library: MPI VERSION    : CRAY MPICH version 8.1.30.9 (ANL base 3.4a2)
world size: 8
allreduce sum: 8 (expected 8)
nodes in world: 2
  x3003c0s13b4n0: 4 ranks
  x3003c0s15b1n0: 4 ranks
RESULT: PASS - one MPI world spans every rank
```

The first line tells you which MPI mpi4py is running on, here the vendor's, Cray MPICH. The world has all 8 ranks, all 8 took part in the sum, and they are on 2 nodes, 4 on each, as the job asked for.

A pass means the ranks form one world across the nodes. It does not by itself prove that they talk over the fast network rather than a slower one: on the next page, one route passes this check without using it. For that, the first line, which MPI is running, is the thing to look at.

[The next page](30-conda.md) is about how to get the second output rather than the first, with conda.
