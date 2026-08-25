---
title: "HPC Guide"
subtitle: "A guide to be effective on utilizing HPC resources"
---

This guide collects practical advice for getting real work done on HPC systems:
how to build and bootstrap software environments without `sudo`, how to run jobs
efficiently, and how to work with the storage and tooling you find on a typical
cluster.

## Contents

- [Package managers](package-managers/index.md) — bootstrapping environments on
  systems where you cannot use the system package manager.
  - [Conda, mamba, micromamba & pixi](package-managers/conda.md)
  - [Conda & MPI](package-managers/conda-mpi.md)
  - [Spack](package-managers/spack.md)
  - [Spack & MPI](package-managers/spack-mpi.md)
- [MPI](mpi/index.md) — composing an environment against the vendor-provided MPI.
- Running jobs
  - [Workflow managers](running-jobs/workflow.md)
  - [Embarassingly parallel jobs](running-jobs/embarassingly-parallel.md)
  - [Oversubscription](running-jobs/oversubscription.md)
- Storage
  - [Lustre file system](lustre.md)
- [Text editors](text-editors/index.md) — editing files on a remote system.
