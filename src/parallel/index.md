---
title: "Parallelism"
description: "Making a computation use many cores and nodes, by the kind of parallel it is: threads, many independent tasks, ranks that communicate, and workflows."
listing:
  contents: "*.md"
  type: table
  fields: [title, description]
  sort: filename
  sort-ui: false
  filter-ui: false
aliases: [../running-jobs/index.html]
---

This part is about making a computation that takes too long on one core use many: first working out which kind of parallel it is, then threads in one process, many independent tasks on one node with GNU parallel or a pool of processes, job arrays across nodes, Python tasks spread over nodes with `mpi4py.futures` and DragonHPC, MPI with threads in each rank, and workflows of tasks that depend on each other. Every page solves the same problem, a Monte Carlo estimate of π, so that the ways compare.
