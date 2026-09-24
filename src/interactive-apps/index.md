---
title: "Running apps interactively on compute nodes"
description: "Jupyter, RStudio, VS Code and friends on a compute node, reached securely from your laptop."
listing:
  contents: ["*.md", "*.qmd"]
  type: table
  fields: [title, description]
  sort: filename
  sort-ui: false
  filter-ui: false
---

You want to run something interactive, like JupyterLab, RStudio Server, VS Code or a Dask dashboard,
on a compute node rather than on the shared login node, and use it from the browser or editor on your laptop.
You can SSH to the login node, but not to the compute node,
so something has to carry your connection across that last hop.
The obvious ways to do that leave your app open to every other user of the cluster.
This section goes through the ways that don't,
each with scripts you can run and a test showing it actually works.

Start with the [overview](10-overview.qmd).
