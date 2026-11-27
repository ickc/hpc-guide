---
title: "Reproducibility"
description: "Running an analysis again and getting the same result: what reproducible means, seeds and the order of a sum, freezing an environment, recording the machine, and archiving a result."
listing:
  contents:
    - 10-intro.md
    - 20-determinism.md
    - 30-environment.md
    - 40-machine.md
    - 60-archiving.md
  type: table
  fields: [title, description]
  sort: false
  sort-ui: false
  filter-ui: false
---

This part is about running an analysis again, for a referee, a colleague or yourself a year later, and getting the same result. It starts with what a claim of reproducible says, what is held fixed, what may vary, and when two results count as the same, and then captures the inputs a result depends on, one kind at a time: the seeds and the order of the arithmetic inside your own program, then the software environment it runs with, frozen from a list of names to a lockfile of hashes, then the machine it runs on, which you cannot freeze, and so record. The last page is about archiving a result when you publish it, and ends with a checklist for your own project.
