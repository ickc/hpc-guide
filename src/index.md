---
title: "HPC Guide"
subtitle: "Getting your analysis done on an HPC cluster, by example"
listing:
  id: parts
  contents:
    - getting-started/index.md
    - software/index.md
    - parallel/index.md
    - storage/index.md
    - interactive/index.md
  type: table
  fields: [title, description]
  sort: false
  sort-ui: false
  filter-ui: false
---

This guide is for you if you have an allocation on an HPC cluster and an analysis in mind, whether you are a scientist, a research software engineer, a PhD student or a postdoc, and want to use the machine well enough to get it done, without first having to know the landscape. It assumes Slurm and Linux, and not much else: nothing here is specific to one cluster, and where the name of something differs between clusters, it says what to look for in yours.

It is written to be read as a book, from one page to the next, and each part builds on the ones before. If you are new to clusters, start at [Getting started](getting-started/10-cluster.md). If you know what you are after, each part can also be read on its own, and its first page says where it picks up.

Most pages are built around examples: a job script, a program, a configuration file, explained line by line. Each one is a real file in [the guide's repository](https://github.com/ickc/hpc-guide/tree/main/src/examples), which you can download and run, and the page shows exactly what is in it. In the part on parallelism, every page solves the same problem, a Monte Carlo estimate of π, so that you can compare the ways of running it.

## The parts

::: {#parts}
:::

## Where this comes from

Much of this guide is reworked from things I have written or made before, for other occasions:

- my talk on reproducibility in computational research, in November 2025;
- the documentation of the [SO:UK Data Centre](https://github.com/simonsobs-uk/data-centre), from 2023 and 2024;
- a hands-on workshop on using a national HPC service, in April 2026, and the research notes and test jobs, on conda and MPI, Lustre, and interactive apps, that came out of using that service;
- my contributions to the documentation of other projects, on conda, pixi and MPI;
- my talks on JAX and Numba, in 2025, and posts on my blog about running services on a compute node.
