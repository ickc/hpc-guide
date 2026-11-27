---
title: "Many independent tasks"
description: "Many tasks that need nothing from each other, run as many at a time as there are cores: on one node with GNU parallel or a pool of processes in Python, and over many nodes with job arrays, mpi4py.futures and DragonHPC."
listing:
  contents: "*.md"
  type: table
  fields: [title, description]
  sort: filename
  sort-ui: false
  filter-ui: false
---

This section is about the most common kind of parallel: many tasks that need nothing from each other, such as the same analysis on many input files, or a simulation over many parameters. It starts with which way to run them, and then goes through each, first on one node, then over many.
