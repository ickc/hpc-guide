---
title: "Software environments"
description: "Installing the software your analysis needs without sudo: the package managers, from modules to conda, pixi, containers and Spack, tools for yourself, an environment around the vendor's MPI, and shipping an environment to the nodes."
listing:
  contents:
    - 10-intro.md
    - package-managers/index.md
    - 30-tools.md
    - mpi/index.md
    - 50-shipping.md
  type: table
  fields: [title, description]
  sort: false
  sort-ui: false
  filter-ui: false
aliases: [../package-managers/index.html]
---

This part is about getting the software your analysis needs onto the cluster, when you cannot use `sudo` and the system's package manager the way you would on your own computer. It starts with the idea everything else rests on, installing into a PREFIX of your own, and then goes through the ways to fill one, from the modules the sysadmins provide, through conda and pixi, which is where I'd recommend most of your software comes from, to containers and Spack for what those can't do. It ends with how to ship an environment to the compute nodes when reading it from the shared filesystem becomes the bottleneck.
