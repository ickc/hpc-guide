---
title: "Embarassingly parallel jobs"
output-file: embarassingly-parallel.html
---

There are many ways to launch a bunch of embarassingly-parallel (TODO: def)
tasks on an HPC.

## Slurm job array

How: TODO

Limitation: overwhelming the scheduler

## GNU parallel

TODO

Limitation: license (cite), be careful about [oversubscription](30-oversubscription.md)

## `mpi4py.futures`

Scale beyond 1 node while still embarassingly parallel in Python.

## Hybrid

Nothing prevent you from mixing them, e.g. Slurm job array, where each
have an exclusive node and launch independent tasks in it using GNU parallel to reduce the amount of spam to the scheduler.
