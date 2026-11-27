---
title: "Moving data on and off the cluster"
output-file: moving-data
description: "Getting data onto the cluster and the results off it: rsync and why it beats scp for anything you may need to resume, packing many small files first, data-transfer nodes and Globus."
---

The previous pages were about where your data should live on the cluster. It has to get there first, from your laptop, or a server in your group, and the results have to come back off it at the end, since nothing on scratch lasts. Both are run from wherever the data is, over `ssh`, so everything below works in either direction.

The recipe you may know already is `scp`, which copies files over `ssh` the way `cp` copies them locally:

``` bash
scp -r data/ my-cluster:/path/to/scratch/
```

where `my-cluster` is whatever you type after `ssh` to log in, and `/path/to/scratch` the full path of your scratch directory on the cluster. For one small file, that is fine. But for a big transfer, it bites: if it is interrupted, by your laptop going to sleep, or the Wi-Fi dropping, there is no way to pick up where it left off, and running it again copies everything again from the beginning, including the files that had already arrived.

## `rsync`

`rsync` does the same job, and more carefully. It compares what is on both ends first, and copies only what is missing or has changed, so running it again after an interruption carries on where it stopped. The command I'd recommend for a transfer of any size is

``` bash
rsync -a --partial --info=progress2 data/ my-cluster:/path/to/scratch/data/
```

`-a` is *archive* mode: it copies directories recursively, and keeps the files' timestamps, permissions and symbolic links as they are, which is also how `rsync` tells, on the next run, which files have not changed. `--partial` keeps a file that was only partly copied when the transfer was interrupted, rather than deleting it, so that the next run continues that file too, instead of starting it again, which matters most for one big file. `--info=progress2` prints one line of progress for the whole transfer, rather than one per file.[^1]

The trailing slash on `data/` matters. With it, `rsync` copies the *contents* of `data` into the destination, `/path/to/scratch/data/`. Without it, `rsync data my-cluster:/path/to/scratch/data/` copies the directory itself into the destination, and you end up with `data/data`. So write both with a trailing slash, the source and the destination, and the two directories then mirror each other. If you are unsure what a command will do, add `-n` (`--dry-run`) and `-v`, which lists what it would copy without copying anything.

To copy the results back, swap the two:

``` bash
rsync -a --partial --info=progress2 my-cluster:/path/to/scratch/results/ results/
```

Two more things to know. `rsync` has to be installed on both ends, which it is on almost every cluster and every Linux or macOS machine.[^2] And `-z` compresses the data on the way, which helps over a slow connection for data that compresses well, such as text, and only costs CPU time for data that is already compressed, such as images or `.gz` files.

### Why not `$SCRATCH` in the path

You may be tempted to write the destination as `my-cluster:'$SCRATCH/data/'`, so that the cluster fills in its own path. That does not work with a recent `rsync` (version 3.2.4 or later), which protects its arguments from the shell on the other end, so `$SCRATCH` reaches it as a literal `$SCRATCH` rather than as your scratch directory.[^3] So find the full path once, e.g.

``` bash
ssh my-cluster 'echo $SCRATCH'
```

and write that path instead. If it prints an empty line, your centre may set the variable only in a login shell, so log in and `echo $SCRATCH` there.

## Many small files: pack them first

`rsync` and `scp` both handle each file one by one, so a directory of a hundred thousand small files is slow to copy however fast the connection is, and on the cluster's end, each of those files is another file to create on a shared filesystem, which [the page on Lustre](20-lustre.md#why-many-small-files-are-the-expensive-kind) explains is the expensive kind. So pack them into one file first:

``` bash
tar -czf data.tar.gz data/
rsync -a --partial --info=progress2 data.tar.gz my-cluster:/path/to/scratch/
```

`-c` creates an archive, `-z` compresses it with gzip, and `-f` names the file. For data that is already compressed, leave out the `-z` (and the `.gz`). Then, on the cluster, you can unpack it on scratch with `tar -xzf data.tar.gz`, or better, keep it packed and unpack it onto node-local storage in each job, as on [the first page of this part](10-where.md#staging-in-and-out-of-node-local-storage). The same goes for the way back: pack the results on the cluster, and copy the one file.

## Which node, and other tools

From your laptop, `my-cluster` is usually a login node, and the transfer runs there. That is fine, since moving data in and out is one of the things login nodes are for. But a big transfer uses a share of a node and a network connection that everyone logged in to it also uses, so some centres provide dedicated *data-transfer nodes* for it, with a hostname of their own, and often a faster connection to the outside. If your centre has them, use them for anything big: everything above works the same, with their hostname in place of `my-cluster`. Your centre's documentation says whether it has them, and how big a transfer it wants you to move there.

Some centres also offer [Globus](https://www.globus.org), a service that moves data between two places that both have it set up, e.g. the cluster and your university's storage. You start a transfer from its web page, and it runs on its own, without your laptop having to stay connected, retries what fails, and checks the files when they arrive. For terabytes, that is easier than babysitting `rsync`, if your centre and the other end both support it.

That is the end of this part. With your data in the right place, the next part, [Working interactively](../interactive/10-editors.md), is about working on the cluster in real time rather than through batch jobs, starting with how to edit files there.

[^1]: `-P` is short for `--partial --progress`, which prints the progress of each file instead. That is fine for a few big files, and a wall of output for many small ones.

[^2]: The `rsync` that comes with macOS is either a very old version or a reimplementation, depending on the version of macOS, and may not know `--info=progress2`. If it complains, install a recent `rsync` on your Mac, e.g. with Homebrew.

[^3]: Without the single quotes, it is worse: `"$SCRATCH"` is filled in by the shell on your laptop, from your laptop's `$SCRATCH`, which is most likely empty.
