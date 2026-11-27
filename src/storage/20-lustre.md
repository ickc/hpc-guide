---
title: "Lustre file system"
description: "Working with Lustre, the shared filesystem of many clusters: checking your quota with lfs quota, what metadata servers and object storage targets are, why many small files are the expensive kind, and striping big files."
output-file: lustre
---

The [previous page](10-where.md) went through the kinds of storage a cluster has, and said that your quota has to be checked with the filesystem's own tool. On many clusters, the shared filesystems are [Lustre](https://www.lustre.org), and that tool is `lfs`, which is also how you see how Lustre lays out your files, and change it. `findmnt -T <dir>` tells you whether a directory is on Lustre: its type is `lustre`.

## Checking your quota

On a Lustre file system, use

``` bash
lfs quota -hp $(lfs project -d $d | awk '{print $1}') $d
```

to check the quota available in a certain directory `$d`.

This works where the centre sets the quota per directory, which Lustre calls a *project* quota (a Lustre project, not the project your allocation is for). `lfs project -d` prints the project ID of the directory, and `lfs quota -p` the quota of that project ID, with `-h` for sizes in units you can read.[^1] The output has two halves: how much space you use (`used`) against its `limit`, and how many files you have (`files`) against theirs. The second limit is the one to watch with many small files, since you can run out of files long before you run out of space.

For example, if you have separate storage quota for these directories, `$HOME`, `$SCRATCH` and `$PROJECTDIR`,[^2] then run

``` bash
for d in $HOME $SCRATCH $PROJECTDIR; do
    echo ============================
    echo "Quota for $d:"
    lfs quota -hp $(lfs project -d $d | awk '{print $1}') $d
done
```

to check the quota of them all at once.

::: callout-tip
Write this in a script called `myquota` in your `PATH` or a shell function to reuse it.
:::

`lfs df -h <dir>` shows the size of the whole filesystem, everyone's, and how full each of the targets it is made of is, which brings us to what those targets are.

## What Lustre is

A Lustre filesystem is not one big disk, but many servers, which your node talks to over the network. They come in two kinds.

The *metadata* servers keep the namespace: the names of files and directories, their owners, permissions and timestamps, and where each file's data is. Each stores this on one or more *metadata targets* (MDTs). The *object storage* servers keep the data itself, on many *object storage targets* (OSTs), each of which is in effect one large disk, or rather an array of disks. A file's data is stored as one or more objects, on one or more OSTs. So opening a file is two steps: your node first asks a metadata server where the file's data is, then reads or writes the data from the OSTs directly.

`lfs mdts <dir>` and `lfs osts <dir>` list the targets of the filesystem a directory is on. On one Lustre filesystem I have used, there were 2 MDTs and 6 OSTs, which serve every user of the cluster.

## Why many small files are the expensive kind

That design is what makes Lustre fast for big files: the data of one file can come from many OSTs at once, and many nodes can read and write in parallel, to different OSTs. But every file, however small, still costs a round trip to a metadata server, to open it, to `stat` it, to create it, and to close it. And there are only a few metadata servers, shared by everyone on the cluster.

So reading a thousand files of 1 KB each is a thousand times the metadata traffic of reading one file of 1 MB, for the same data. Do that from a few thousand processes at once, as a job array or a parallel job easily does, and the metadata servers become the bottleneck, for you and for everyone else on the filesystem, so that even an `ls` can hang for users who have nothing to do with your job. This is why starting Python from a conda environment on Lustre in thousands of jobs at once is slow, since that is hundreds of small files per process, which the [page on shipping an environment](../software/50-shipping.md) is about.

The fixes are the same ones as before:

- fewer, bigger files: pack many small inputs into one, with `tar`, or into a format meant for it, such as HDF5, rather than one file per sample;
- small files on node-local storage, staged in and out as on [the previous page](10-where.md#staging-in-and-out-of-node-local-storage);
- fewer metadata operations: don't `ls` or `find` a big directory in a loop, or check for a file's existence thousands of times, and don't put hundreds of thousands of files in one directory.

## Striping big files

A file's *layout* says which OSTs its data is on. By default, it is usually on one OST: the *stripe count* is 1. A file with a stripe count of 4 is split into chunks of the *stripe size*, which are spread over 4 OSTs in turn, round robin, so that reading it reads from 4 OSTs at once. That is *striping*, and it is the one Lustre setting worth knowing about for big files.

To see a file's layout, or the default for new files in a directory, use `lfs getstripe`:

``` bash
lfs getstripe big.h5     # the layout of a file
lfs getstripe -d data/   # the default layout of new files in a directory
```

`lmm_stripe_count` is the stripe count, `lmm_stripe_size` the stripe size in bytes, and `obdidx` lists the OSTs the file is on. On one Lustre filesystem I have used, the default was a stripe count of 1 and a stripe size of 1 MiB.

To change it, set a default on a directory with `lfs setstripe`:

``` bash
mkdir data
lfs setstripe -c 4 -S 8M data
```

`-c` is the stripe count, here 4, and `-S` the stripe size, here 8 MiB. `-c -1` stripes over every OST there is. Files created in `data/` from then on get that layout, and so do directories created in it, which pass it on in turn. Files that are already there keep the layout they had, since a file's layout is fixed when it is created: `lfs setstripe` on an existing file fails with `stripe already set`. To change the layout of a file that already exists, `lfs migrate` rewrites it onto a new one:

``` bash
lfs migrate -c 4 -S 8M big.h5
```

which copies all of its data, so it takes as long as copying the file does. `lfs setstripe -d data` removes the directory's own default again, so that new files get the filesystem's.

### Pools

Some Lustre filesystems group their OSTs into *pools*, e.g. one of flash and one of spinning disks, and `lfs pool_list <dir>` lists them, if there are any. On one Lustre filesystem I have used, there were two pools, `flash` with 2 smaller OSTs and `disk` with 4 much larger ones, and new files went to `flash` by default. `-p` chooses the pool:

``` bash
lfs setstripe -p disk -c 4 -S 8M data
```

and the stripe count is then over the OSTs of that pool, so `-c -1` means every OST in the pool. Ask for more stripes than the pool has OSTs, and a file gets as many as there are, without an error.[^3] Which pool is meant for what is up to your centre, so check its documentation before you move your data off the default.

### When to bother, and when not to

Striping helps a file that is big, gigabytes rather than megabytes, and read or written by many processes at once, e.g. an MPI program writing one shared file with MPI-IO, or many tasks reading the same large dataset. Then more stripes means more OSTs serving it at once. Some centres recommend a stripe count for files like that in their documentation, which is the place to start.

It does not help, and makes things worse, for small files: each stripe is one more object on one more OST, so a small file with many stripes is that many more servers to contact to open it, for no gain. Nor does it help much for many big files that are each read by one process: with a stripe count of 1, different files already land on different OSTs, so the load is spread anyway. So for most users, the default layout is fine, and I'd only stripe a directory that holds a few very large files read in parallel. If in doubt, measure: time reading or writing one such file with and without the stripes, before you set it for everything.

## What's next

Lustre is fast for big files, as long as you keep the small ones off it. The data still has to get onto the cluster in the first place, and the results off it, which is [the next page](30-moving-data.md).

[^1]: If the project ID it prints is 0, the directory has no project quota of its own, and your quota is probably per user or per group instead, which `lfs quota -h -u "$USER" "$d"` and `lfs quota -h -g "$(id -gn)" "$d"` show.

[^2]: As on the previous page, these names depend on the system: substitute whatever your centre calls each of them.

[^3]: `-C` instead of `-c` puts several stripes of a file on the same OST, which Lustre calls *overstriping*. You are unlikely to need it.
