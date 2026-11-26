---
title: "Pixi"
description: "Project-centric environments from conda-forge, with a lockfile per platform and a built-in task runner, and how to use one in a batch job."
output-file: pixi
---

The previous page ended on what conda doesn't do for you: an environment lives in a central place, and it is up to you to remember which project it belongs to, and to export it if you want to reproduce it. [Pixi](https://pixi.sh) uses the same conda-forge packages, and is designed the other way round.

Pixi is like uv, but for conda packages. Its design is project-centric: the environment is tied to a project directory, typically a git repository, rather than kept in a central place, which encourages reproducibility at the level of the project. It bootstraps the environment, writes a lockfile, and runs your tasks, all in one tool. And like a conda environment can include PyPI packages, a pixi environment can too: pixi resolves PyPI dependencies with uv, which is built into it. By the way, pixi is made by the same developer who created mamba.

## A project

Install pixi into your architecture-dependent prefix,

``` bash
curl -fsSL https://pixi.sh/install.sh | PIXI_HOME="${__OPT_ROOT}/pixi" PIXI_NO_PATH_UPDATE=1 bash
```

and add `export PATH="${__OPT_ROOT}/pixi/bin:${PATH}"` to your `~/.bashrc`. `PIXI_HOME` is where pixi installs itself, and `PIXI_NO_PATH_UPDATE` stops the installer from editing your `~/.bashrc` itself.[^1]

Then, in your project's directory,

``` bash
pixi init
pixi workspace platform add linux-64 linux-aarch64
pixi add python=3.13 numpy
```

makes a `pixi.toml`, says which platforms the project is for, and adds two dependencies. Here is the `pixi.toml` of the example on this page, with a task added by hand:

``` {.toml include="../examples/pixi-job/pixi.toml"}
```

and `pi.py`, which estimates π from random points:

``` {.python include="../examples/pixi-job/pi.py"}
```

## The lockfile

`pixi add` also writes `pixi.lock`, which records the exact version and build of every package in the environment, for every platform in `platforms`. The lockfile resolves per platform, so a problem that only shows up on one platform, say a package that does not exist for `linux-aarch64`, is found when you add the dependency on your laptop, rather than when you first try it on the cluster. You get more control and information on the environment you created. Commit both `pixi.toml` and `pixi.lock` to git, and anyone who clones the project, including you on the cluster, gets the same environment.

`pixi install` creates the environment from the lockfile, in `.pixi/` inside the project. You rarely need to run it, because every other command creates or updates the environment when it needs to. Two options control what they are allowed to change:

- `--locked` uses the lockfile, and fails if it is out of date with `pixi.toml`, rather than updating it;
- `--frozen` uses the lockfile as it is, without checking it against `pixi.toml`.

## Tasks

The `[tasks]` table is a built-in task runner, so that you don't need to rely on an ad hoc Makefile, or notes, to remind you what can be done. `pixi run pi` runs `python pi.py` in the environment, creating it first if needed. Run `pixi task list` and see all the tasks you can perform, with their descriptions.

## Using it in a batch job

There are two ways to use a pixi environment in a job, and this job does both:

``` {.bash include="../examples/pixi-job/job.sh"}
```

`cd "$SLURM_SUBMIT_DIR"` goes to the directory you ran `sbatch` from, which is the project, since pixi finds its `pixi.toml` from the current directory. `pixi run --frozen pi` then checks the environment against the lockfile, activates it, and runs the task. `--frozen`, because a job should never be the one to re-solve the environment: it would take time on a compute node, and many clusters' compute nodes cannot reach the internet anyway. So install the environment on the login node first, which is also where you check the lockfile is current:

``` bash
pixi install --locked
sbatch job.sh
```

`pixi run` does its check every time it runs. That is a fraction of a second, which is fine for one command, but adds up if a job runs thousands of short ones. `pixi shell-hook` instead prints the script that activates the environment, and `eval` runs it in the job's shell, once, after which `python` is the environment's for the rest of the job.[^2]

## On a heterogeneous cluster

Because the environment is in `.pixi/` inside the project, a project in your home directory on a heterogeneous cluster has the same problem as `~/.local/bin` in [the introduction](10-intro.md): one `.pixi/envs/default`, which can only hold one architecture's packages, seen by the nodes of both. The fix is to keep environments out of the project, under the architecture-dependent prefix:

``` bash
pixi config set --global detached-environments true
```

and, in your `~/.bashrc`,

``` bash
export PIXI_CACHE_DIR="${__OPT_ROOT}/cache/pixi"
```

With `detached-environments`, pixi keeps each project's environments in `$PIXI_CACHE_DIR/envs` instead of in `.pixi/`, and with `PIXI_CACHE_DIR` under `$__OPT_ROOT`, the nodes of each architecture get their own. The lockfile, which is per platform already, is shared by both.

## pixi global

Pixi can also install command-line tools for yourself, rather than for a project, with `pixi global install`, similar to `pipx`. That is the subject of [the next page](50-tools.md).

[^1]: Or install it with mamba: pixi is on conda-forge too, and [the page on command-line tools](50-tools.md) shows a way to keep tools like it.

[^2]: `pixi shell-hook` prints plain shell, so you can also run it on the login node, save it to a file, and `source` that in your jobs, without pixi on the compute node at all.
