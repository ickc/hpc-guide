---
title: "Storage"
description: "The kinds of storage a cluster has and which to use for what, Lustre, and moving data on and off the cluster."
listing:
  contents: "*.md"
  type: table
  fields: [title, description]
  sort: filename
  sort-ui: false
  filter-ui: false
---

This part is about where your data lives on a cluster, and how it gets there: the kinds of storage there are, from your home directory to the disk of each compute node, with their quotas, backups and purge policies, and how to stage data in and out of node-local storage in a job; then Lustre, the shared filesystem of many clusters, how to check your quota on it, and why many small files are slow there; and last, how to move data onto the cluster and the results off it with `rsync`.
