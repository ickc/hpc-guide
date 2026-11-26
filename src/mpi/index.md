---
title: "MPI"
listing:
  contents: "*.md"
  type: table
  fields: [title, description]
  sort: filename
  sort-ui: false
  filter-ui: false
---

This part is about running an MPI program across nodes on the MPI the vendor installed, which is the one that knows the cluster's network and its scheduler. It starts with what MPI is and why the vendor's MPI matters, then a check for the most common way an MPI job goes wrong without telling you, and then how to compose an environment around the vendor's MPI, with conda and with Spack.
