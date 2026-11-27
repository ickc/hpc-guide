---
title: "Spack and the vendor's MPI"
description: "Composing a Spack environment with the vendor's MPI: libfabric as an external at the very least, the vendor's MPI and PMI as externals preferably, why not to build Open MPI on an MPICH system, and how to check which network an MPICH uses."
output-file: spack
aliases: [../../package-managers/spack-mpi.html, ../../mpi/spack.html]
---

[The previous page](30-conda.md) composed a conda environment with the vendor's MPI. This page does the same for an MPI program built from source with [Spack](../package-managers/60-spack.md).

## What Spack does by default

Ask Spack for a package that needs MPI, and unless told otherwise, it builds an MPI too, from source, along with everything that MPI depends on, including the library it talks to the network through. On a Cray system that is libfabric, and the libfabric Spack builds has whatever providers, the drivers for each kind of network, its defaults give it, rather than being the one the vendor built for that network.[^1] The result can form a world across nodes, and still not use the fast network.

So you tell Spack about the vendor's libraries as [externals](../package-managers/60-spack.md), in the `packages:` section of the environment's `spack.yaml`, or of a `packages.yaml` that applies to all of your environments.

## At the very least, libfabric

The minimum is the vendor's libfabric as an external, and not buildable, so that Spack cannot fall back to building its own:

``` yaml
packages:
  libfabric:
    buildable: false
    externals:
    - spec: libfabric@1.22.0 fabrics=cxi
      prefix: /path/to/libfabric
```

`spec` says what the external is, a libfabric of that version with the `cxi` fabric, and `prefix` where it is installed, which you substitute: on a Cray system, `module show libfabric` shows it, and so does `pkg-config --variable=prefix libfabric` with the module loaded. `buildable: false` is the important line: without it, Spack is free to build a libfabric anyway, if it decides that another version fits the rest of the environment better. With it, any MPICH Spack builds is built against the vendor's libfabric, and talks to the network through it. This is still worse than not building an MPI at all, though.

## Better, the vendor's MPI itself

Better is to add the vendor's MPI, and the vendor's PMI that it uses to talk to Slurm, as non-buildable externals too, and tell Spack that this is the MPI to use. Then Spack builds no MPI, and your program is built against the vendor's, as if you had compiled it with the vendor's compiler wrappers yourself. On a Cray system, an environment that builds the [OSU micro-benchmarks](https://mvapich.cse.ohio-state.edu/benchmarks/) this way is

``` {.yaml include="../../examples/spack-mpi/spack.yaml"}
```

`providers: mpi: [cray-mpich]` makes Cray MPICH the package that provides MPI to everything else, and the three externals are Cray MPICH, Cray's PMI, and libfabric. The versions and prefixes are your system's, and change when the vendor's software is upgraded, so take them from the modules, and replace each `/path/to/...` with them: `module show cray-mpich` (or the module for your vendor's MPI) shows where it is installed, and the same for `cray-pmi` and `libfabric`. On a Cray system, `MPICH_DIR` is also set to Cray MPICH's prefix once a programming environment is loaded, and `pkg-config --variable=prefix cray-pmi` gives Cray PMI's.

::: callout-note
## Your centre may have one already

Some centres maintain a `packages.yaml` for their system, with the vendor's MPI, PMI, libfabric and compilers already as externals, and their Spack documentation says where to find it. If yours does, start from it rather than writing your own. With it, `spack spec` shows `cray-mpich` and `libfabric` marked `[e]`, for external.
:::

Build it as in [the Spack page](../package-managers/60-spack.md), with `spack install` in the environment, and run it on 2 nodes with:

``` {.bash include="../../examples/spack-mpi/job.sh"}
```

`osu_latency` measures how long a message takes from one rank to the other, for a range of message sizes. It refuses to run in anything but a world of exactly 2 ranks, so it fails rather than reports when the ranks are in worlds of their own, and with one rank on each node, the latency it reports is that of the network between them.

## Don't build Open MPI on an MPICH system

On a system whose vendor MPI is derived from MPICH, as Cray's is, the vendor's MPI cannot stand in for Open MPI, which has an ABI of its own, so building Open MPI with Spack means building a whole MPI stack of your own, with none of the vendor's tuning, and none of the vendor's support when it goes wrong. I don't recommend it, unless you have an advanced reason to, such as an application that only works with Open MPI.

## Which network does it use?

To see what an MPICH was built to talk to the network through, after loading the environment, run

``` bash
mpirun --version | grep -- '--with-device=ch[0-9]:'
```

MPICH's `mpirun` prints the options MPICH was configured with, and the device is the part that talks to the network. If you see something like `ch4:ofi`, it is using libfabric (libfabric is the library of OFI, OpenFabrics Interfaces), which with the externals above is the vendor's.[^2] Together with `mpi_hello.py` from [the check](20-check.md), or `osu_latency` above, that tells you both that the ranks form one world, and that they talk through the library that drives the network.

The [next page](../50-shipping.md) is about what to do when the environment, however you built it, is the bottleneck: when a job spends longer reading its software from the shared filesystem than it should.

[^1]: On Slingshot, that is the `cxi` provider of libfabric. `fi_info -p cxi`, with the vendor's libfabric loaded, shows whether it is there.

[^2]: The vendor's MPI may have no `mpirun` at all, if it expects you to launch with `srun`. In that case, `mpichversion` from the same MPICH shows the device as `MPICH Device: ch4:ofi`, as Cray MPICH's does.
