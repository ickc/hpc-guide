---
title: "Method 2: SSH over srun"
output-file: srun-ssh
description: "The app stays on the node's loopback; one SSH session reaches it through Slurm. Recommended."
---

This is the method I recommend.
The app listens on the compute node's loopback (`127.0.0.1`), which nothing else on the cluster can reach,
and your laptop gets to it through a real SSH session that runs *over Slurm* instead of over the network.
Nothing listens on the cluster network at all, and there is no third party involved.

## How it works

You cannot SSH to a compute node, but you can already run programs there with `srun`,
and `srun` connects that program's input and output to your terminal
(that is all [method 0](20-shell.md) is).
`sshd`, the SSH server, has an "inetd mode" (`sshd -i`) in which it talks SSH on its input and output
instead of listening on a port.
Put the two together and `srun ... sshd -i` is an SSH server on the compute node that you can reach
from wherever you can run `srun`.
SSH lets you use a command as the connection instead of a network socket (`ProxyCommand`),
so from the laptop it is one ordinary `ssh -L` port forward:

    laptop --ssh--> login node --srun--> sshd -i on the compute node --> 127.0.0.1:APP_PORT

Only you can attach to your own job with `srun`, SSH does the encryption and authentication end to end,
and the keys are made fresh for every job.

## What you need

- A cluster that uses Slurm (you submit jobs with `sbatch` and run things in them with `srun`).
- SSH access to a login node, and `ssh` on your laptop.
- Your home directory is shared between the login and compute nodes,
  which is true on nearly every cluster.
- `python3` on the compute node, only to pick a free port and to run the demo app.
- An `sshd` program on the compute node that you can run.
  It does not need root or to be the system's SSH service:
  the launcher uses `sshd` from your `PATH`, falling back to `/usr/sbin/sshd`,
  and you can point `SSHD` at another one.
  If your cluster has none, you can install `openssh` yourself (e.g. with [a package manager](../package-managers/index.md)).

## Running it

On the login node, from this example's directory:

``` bash
sbatch launch.sh
```

It prints its job ID. On your laptop, with the login node as you would name it after `ssh`:

``` bash
LOGIN_HOST=my-cluster ./connect.sh <JOBID>
```

and open <http://localhost:8888>.
`LOCAL_PORT` picks another local port. Ctrl-C disconnects; `scancel <JOBID>` ends the job.

To use your own app, replace the last line of `launch.sh`.
Whatever it is, it must listen on `127.0.0.1` and on `$APP_PORT`, e.g.

``` bash
jupyter lab --no-browser --ip=127.0.0.1 --port="$APP_PORT"
```

Jupyter's token is still printed in the job's output as usual.
It is less critical here, since nobody else can reach the port in the first place,
but leave it on.

### `launch.sh`, on the cluster

``` {.bash include="examples/srun-ssh/launch.sh"}
```

### `connect.sh`, on your laptop

``` {.bash include="examples/srun-ssh/connect.sh"}
```

## Notes

- **`--unbuffered` is not optional.** Without it `srun` holds back output,
  and the SSH handshake stalls without an error.
- **You get a shell too.** The same connection without `-N -L` is a normal SSH login to the compute node,
  inside the job's allocation.
  The Slurm environment variables are not set in it, since `sshd` starts a clean environment.
  This should also let an editor's remote-SSH mode (e.g. VS Code Remote-SSH) connect to the compute node
  with the same `ProxyCommand`, although I haven't tested that.
- **Leftovers.** The session keys live in `~/.interactive-apps/<JOBID>`.
  They only open that job, so they are useless once it ends,
  and the directory can be deleted if `scancel` left it behind.

## Testing

[`examples/srun-ssh/test.sh`](examples/srun-ssh/test.sh) submits `launch.sh`, runs `connect.sh` on the login node
(with `LOGIN_HOST` empty, which skips the laptop-to-login hop),
and fetches the demo page through the tunnel.
The hop it skips is your normal SSH login, which you already know works.
