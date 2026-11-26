---
title: "Working interactively"
listing:
  contents: "*.md"
  type: table
  fields: [title, description]
  sort: filename
  sort-ui: false
  filter-ui: false
aliases: [../text-editors/index.html]
---

So far, everything in this guide has been run as a batch job: you submit it, and read what it wrote afterwards. This part is about working on the cluster as you go: editing files on it from your laptop, getting a shell on a compute node, and running web apps such as JupyterLab and RStudio on a compute node, then using them from the browser on your laptop.

That last one is where the usual recipe leaves your work open to everyone else on the cluster, so most of this part is about doing it securely, each way with scripts you can run.
