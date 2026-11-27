---
title: "Package managers"
description: "The ways to fill a PREFIX of your own: modules, conda and mamba, pixi, containers and Spack, which one for what, and each in a batch job."
listing:
  contents: "*.md"
  type: table
  fields: [title, description]
  sort: filename
  sort-ui: false
  filter-ui: false
---

This section goes through the package managers you can use on a cluster without `sudo`, starting with which one to reach for, and then each of them in turn: the modules the sysadmins provide, conda and pixi, which is where I'd recommend most of your software comes from, and containers and Spack for what those can't do.
