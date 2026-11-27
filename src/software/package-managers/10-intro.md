---
title: "Which package manager?"
output-file: intro
description: "Modules, conda, pixi, containers and Spack side by side: what each gives you, whether it is prebuilt or built from source, and when to reach for it."
---

[The previous page](../10-intro.md) was about the PREFIX that every package manager installs into. This section is about the package managers themselves, in the order I'd recommend reaching for them:

|  | What it gives you | Prebuilt or from source | Reach for it for |
|------------------------------|------------------------------|------------------------------|------------------------------|
| [Modules](20-modules.md) | what the sysadmins installed for you | done for you | compilers, MPI, and libraries tuned for the hardware |
| [Conda and mamba](30-conda.md) | an environment of packages from conda-forge | prebuilt | nearly everything else |
| [Pixi](40-pixi.md) | the same packages, organized per project, with a lockfile | prebuilt | a project you want to reproduce |
| [Containers](50-containers.md) | a whole operating system's userland, in one image file | prebuilt image | software published as a Docker image, or that needs system packages |
| [Spack](60-spack.md) | compiled software built for the machine you run on | from source | compiled code that has to be tuned to the machine |

The [next page](20-modules.md) starts with what is already there.
