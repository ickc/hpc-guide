---
title: "Method 0: a shell on the compute node"
output-file: shell
description: "No port, no tunnel: just a terminal. Enough for anything that runs in one."
---

The easiest way to run something interactively on a compute node is to not run a service at all:
get a shell there and work in it.
If what you want runs in a terminal (IPython, R, a debugger, `htop`, vim, ...),
this is all you need, and nothing on this page opens a port.

## What you need

- A cluster that uses Slurm, i.e. you submit jobs with `sbatch` and `srun`.
- SSH access to a login node.

Account, partition, time limit and so on are whatever your cluster normally needs.
They are left out of the commands below;
add them as options (`-A`, `-p`, `-t`) or set them once in the environment
(`SLURM_ACCOUNT`, `SLURM_PARTITION`, ...).

## Three ways in

### `srun --pty`: allocate and get a shell in one go

``` bash
srun --nodes=1 --ntasks=1 --pty bash -i
```

This asks for an allocation, waits for it, and starts `bash` on the compute node with your terminal attached.
When you `exit`, the allocation is released.

### `salloc`, then `srun`

``` bash
salloc --nodes=1 --ntasks=1
srun --pty bash -i
```

`salloc` gets the allocation and gives you a shell.
Where that shell runs depends on how your cluster is configured:
on some clusters it is on the compute node,
on others it is still on the login node and only the `srun` inside it reaches the compute node.
Run `hostname` to check.
The allocation lives until you exit the `salloc` shell,
so you can start and stop several `srun` in it,
e.g. a shell in one terminal and your program in another.

### Attach to a job that is already running

``` bash
srun --jobid=<JOBID> --overlap --pty bash -i
```

This opens a shell inside an existing allocation,
such as a batch job you submitted earlier.
`--overlap` lets it share the resources the job is already using instead of waiting for free ones.
This is handy for watching a running job (`top`, `nvidia-smi`, looking at files in node-local storage),
and it works with a job script that does nothing but hold the node:

``` {.bash include="examples/shell/hold.sh"}
```

::: callout-tip
Run these from inside `tmux` or `screen` on the login node.
The shell on the compute node then survives your laptop going to sleep or your Wi-Fi dropping,
as long as the login node keeps its session.
:::

## Why this is not enough for web apps

A shell gets *you* onto the node, but not your browser.
Jupyter, RStudio Server, TensorBoard and friends listen on a port and expect a browser to connect to it,
and your laptop cannot reach a port on a compute node directly.
That is what the rest of this section is about.
The `srun` pipe used here turns out to be useful for that too, though: [method 2](50-srun-ssh.md) runs SSH over it.

## Testing

[`examples/shell/test.sh`](examples/shell/test.sh) does all three non-interactively
(it uses `script` to fake a terminal) and checks each shell lands on a compute node.
See [how the examples are tested](10-overview.qmd#testing-the-examples).
