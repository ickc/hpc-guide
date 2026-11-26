---
title: "A shell on a compute node"
output-file: shell
description: "srun --pty for a shell in a new allocation, salloc to keep one and run several things in it, and srun --overlap to get into a job that is already running."
---

The [previous page](10-editors.md) was about editing files on the cluster. But as soon as what you want to run interactively is more than a quick look, say a Python or R session that loads a big dataset, or a debugger on your program, it should run on a compute node rather than on the login node, which is shared with everyone else. So the first thing to know is how to get a shell on a compute node.

You may know the batch way already: write a job script, `sbatch` it, and read its output afterwards. An interactive job is the same request to the scheduler, but with your terminal attached to it, so you type and see the result as you go. There are three ways to get one, depending on whether you want the allocation to last longer than one shell, and on whether you already have a job running.

## `srun --pty`: a shell in a new allocation

``` bash
srun --nodes=1 --ntasks=1 --pty bash -i
```

This asks Slurm for one node, waits in the queue until it gets it, and starts `bash` there with your terminal attached. `--pty` is what attaches it: it runs the command in a pseudo-terminal, so that `bash` behaves as it would when you log in, with a prompt, line editing and Ctrl-C. `bash -i` makes it an interactive shell, which reads your `~/.bashrc`. Your account, partition and time limit go on the same line, as they would in a job script, e.g. `srun -A myproject -p mypartition --time=1:00:00 ...`.

Type `hostname` to see that you are on a compute node now. When you `exit` the shell, the allocation ends with it.

## `salloc`, then `srun`

``` bash
salloc --nodes=1 --ntasks=1
srun --pty bash -i
```

`salloc` gets the allocation and gives you a shell, and the allocation lasts until you exit that shell. In it, every `srun` runs on the allocated node, without waiting in the queue again. So you can start and stop several things in one allocation: a shell in one, your program in another, and the program again after you've fixed it.

Where the `salloc` shell itself runs depends on your cluster. On some it is already on the compute node, and on others it is still on the login node, and only what you start with `srun` reaches the compute node.[^1] Again, `hostname` tells you which.

## Getting into a job that is already running

``` bash
srun --jobid=<job ID> --overlap --pty bash -i
```

This opens a shell inside an allocation you already have, such as a batch job that is running now. `--jobid` says which job, and `--overlap` lets the new shell share the job's resources with what is already running in it, rather than wait for resources that the job is already using.

This is handy for watching a running job from the inside: `top` to see whether it uses the cores you asked for, `nvidia-smi` for its GPUs, or the files it writes on the node's local disk, which you cannot see from the login node. It also works with a job that does nothing but hold the node for you:

``` {.bash include="../examples/shell/hold.sh"}
```

`sleep infinity` never ends by itself, so the job lasts until its time limit, or until you `scancel` it. In practice, this is your real job script, and you get into it to see how it is doing.

::: callout-tip
Run these from inside `tmux` or `screen` on the login node. Then the shell on the compute node survives your laptop going to sleep or your Wi-Fi dropping, since it is the login node that holds the connection to it.[^2] Some clusters do not allow such a session to keep running after you disconnect, as [the page on workflows](../parallel/80-workflows.md#where-the-head-process-runs) explains, so check yours before you rely on it.
:::

## Limitations

An interactive allocation is used whether you type in it or not. The cores and the time are yours, and are charged to your project, from the moment the shell starts until you exit it, even while you are reading the output or at lunch. So exit when you are done, rather than leave it to the time limit.

And a shell gets *you* onto the compute node, but not your browser. JupyterLab, RStudio and the like listen on a port and expect a browser to connect to it, and your laptop cannot reach a port on a compute node. That is what the [next page](30-services.md) is about, and what the rest of this part solves. The `srun` you have seen here turns out to be part of the answer too.

[^1]: That is the cluster's choice, the `use_interactive_step` option of `LaunchParameters` in its Slurm configuration. With it, `salloc` starts the shell on the allocated node; without it, `salloc` starts the shell where you ran it.

[^2]: If your cluster has several login nodes behind one address, note which one you are on (`hostname`), as you have to log in to that one again to get back to your `tmux` session.
