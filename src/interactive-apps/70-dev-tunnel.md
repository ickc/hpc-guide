---
title: "Method 3b: through Microsoft Dev Tunnels"
output-file: dev-tunnel
description: "The job connects out to Microsoft's relay; you sign in to open it. The relay behind VS Code tunnels."
---

This is method 3a with somebody else's relay.
[Dev Tunnels](https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/overview) is the Microsoft service behind
VS Code's `code tunnel`, and its `devtunnel` program can publish any port, not just VS Code's.
The job connects out to it, and you get an `https://...devtunnels.ms` URL that only opens after you sign in
with the same account the job used.

So there is nothing listening on the cluster and no server of your own to run.
In exchange Microsoft's relay is in the path of your traffic, and you need a GitHub or Microsoft account.
If your cluster already recommends `code tunnel` for VS Code, this trusts nobody new.
If your project's data must not go through a third party, use [method 2](50-srun-ssh.qmd) instead.

::: callout-tip
If you already use `code tunnel` on a compute node,
you do not need any of this:
start your app on the node's loopback and use VS Code's *Forward a Port*,
which rides the same tunnel.
:::

## What you need

- A cluster that uses Slurm (you submit jobs with `sbatch`).
- Compute nodes can reach the internet, or at least `*.devtunnels.ms` and `*.visualstudio.com`.
- A GitHub (or Microsoft) account.
- Your home directory is shared between the login and compute nodes, which is where the sign-in is kept.
- `python3` on the compute node, only to pick a free port and to run the demo app.

## Running it

Once, on the login node, from this example's directory:

``` bash
./setup.sh
```

It downloads `devtunnel` and shows a code to enter at a URL, in any browser.

Then for each session, on the login node:

``` bash
sbatch launch.sh
```

and on your laptop:

``` bash
LOGIN_HOST=my-cluster ./connect.sh <JOBID>
```

which looks up the URL and opens it.
The first time, Dev Tunnels shows a page warning that you are about to connect to a developer tunnel;
that is expected, and it is only you who can get past it.

### `setup.sh`, once on the cluster

``` {.bash include="examples/dev-tunnel/setup.sh"}
```

### `launch.sh`, on the cluster

``` {.bash include="examples/dev-tunnel/launch.sh"}
```

### `connect.sh`, on your laptop

``` {.bash include="examples/dev-tunnel/connect.sh"}
```

## Notes

- **Leftover tunnels.** A tunnel stays registered until it is deleted or expires.
  The job deletes its own when the app exits, but not after `scancel`,
  so the launcher gives it a one-day expiry.
  `devtunnel list` shows them and `devtunnel delete <ID>` removes one.
- **Jupyter.** If pages load but something misbehaves (e.g. kernels not connecting),
  try adding `--host-header unchanged` to the `devtunnel host` line.

## Testing

[`examples/dev-tunnel/test.sh`](examples/dev-tunnel/test.sh) skips unless `devtunnel` is installed and signed in.
Otherwise it submits `launch.sh`, gets an access token for the tunnel the way the browser does after you sign in,
and fetches the demo page through Microsoft's relay.
