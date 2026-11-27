---
title: "SSH over srun"
output-file: srun-ssh
description: "The fix specific to Slurm: JupyterLab or RStudio listens only on the compute node's loopback, and one SSH session reaches it, carried by srun. No certificate, no third party, and the same for any app. The one I recommend."
aliases: [../srun-ssh.html]
---

On the [previous page](20-https.md), I said I'd talk about a solution specific to Slurm, that is easy to deploy with minimal setup, and works the same whether it is JupyterLab or RStudio. This is it, and it is the one I recommend: run an SSH server on the compute node for the length of your job, and reach it through Slurm rather than through the network.

## The idea

You cannot SSH to a compute node, but you can already run programs there with `srun`, and `srun` connects the program's input and output to wherever you ran it. That is all [a shell on a compute node](../20-shell.md) is. So two more pieces are needed, and SSH has both:

- `sshd`, the SSH server, has an *inetd mode*, `sshd -i`, in which it speaks SSH on its input and output, instead of listening on a port. So `srun ... sshd -i`, run from the login node, is an SSH server on the compute node that only you can reach, since only you can run `srun` in your own job.
- `ssh`, the client, can use a command as its connection instead of the network, with the `ProxyCommand` option. Make that command `ssh <login node> srun ... sshd -i`, and the `ssh` on your laptop is talking to the `sshd` on the compute node.

Then it is an ordinary SSH session, and SSH does what it always does: it checks who you are, encrypts everything, and forwards a port on your laptop with `-L`. The app listens on the compute node's *loopback* address, `127.0.0.1`, which other nodes cannot connect to at all.

![](./hpc-srun-ssh.svg){width="100%" fig-alt="A laptop connects to the login node with ssh. From the login node, srun starts sshd -i on the compute node, which forwards to JupyterLab or RStudio listening on 127.0.0.1 of the same node."}

Compared with [the usual recipe](10-intro.md), nothing listens on the cluster network, so there is nothing for anyone else on the cluster to connect to, and nothing in plain HTTP travels between nodes. Compared with [HTTPS](20-https.md), there is no certificate to make, no fingerprint to check and no browser warning, since SSH checks the server's key itself. And the app does not have to speak HTTPS, so RStudio is no harder than JupyterLab.

## The scripts

It is two scripts: one you submit on the cluster, and one you run on your laptop. The SSH server needs keys and a configuration of its own, which the first one makes for every job, and the second one fetches.

### On the cluster

``` {.bash include="../../examples/srun-ssh/launch.sh"}
```

Everything for the job goes in `~/.interactive-apps/<job ID>`, which only you can read. Your home directory is shared between the login and compute nodes on nearly every cluster, so that is how the laptop side gets what it needs, through the login node, without reading the job's output.

The job makes two pairs of keys for itself: a *host key*, which is how your laptop knows it is talking to this job's `sshd` and not to someone pretending to be it, and a *client key*, which is how this `sshd` knows it is you. Both are made fresh for every job, and the server lets in only the client key, so nothing here touches your own `~/.ssh`, and the keys are useless once the job ends.[^1] The configuration turns off passwords, and `StrictModes no` lets `sshd` use keys in your home directory, which it would otherwise refuse to do unless your home directory's permissions are as strict as it likes them. `sshd -t` checks the configuration before anything else starts, so a mistake shows up in the job's output rather than as a failed connection later.

`SSHD` is the full path to `sshd`, which it needs to run at all.[^2] Any `sshd` will do, as it runs as you and needs no root: the system's own in `/usr/sbin`, or one you installed. Then the job picks a free port for the app, and a token, which the next section is about, and writes all of it to `info.env`.

The last line is the app. Here it is a small stand-in for JupyterLab that says which node it is running on; replace it with yours.

### On your laptop

``` {.bash include="../../examples/srun-ssh/connect.sh"}
```

Once the job is running, run it with the job ID, and `LOGIN_HOST` set to whatever you type after `ssh` to reach the login node, e.g. an alias from your `~/.ssh/config`:

``` bash
LOGIN_HOST=my-cluster ./connect.sh <job ID>
```

and open the URL it prints. Ctrl-C disconnects, and `scancel <job ID>` on the login node ends the job.

It copies `info.env` and the client key from the login node into a temporary directory, which it deletes when it exits. It trusts exactly the host key the job made, and nothing else, with `StrictHostKeyChecking=yes`: if anything else answers, `ssh` stops rather than asking you. `HostKeyAlias` files that key under a name of its own, so that nothing in your `~/.ssh/config` for that node gets in the way.

The proxy command is the heart of it: `ssh` to the login node, and from there `srun` into the job, to start `sshd -i` with the job's configuration. Each option of `srun` matters. `--jobid` and `--overlap` are as in [getting into a running job](../20-shell.md); `--ntasks=1` starts one `sshd`, not one per task of the job; and `--unbuffered` makes `srun` pass on every byte as it comes. Without it, `srun` holds on to the output until it has a buffer full, the SSH handshake stalls, and nothing says why.

The rest are the options for the session itself: `ExitOnForwardFailure` so that it stops if your local port is taken, rather than carry on without the forward, `ServerAliveInterval` to keep it from timing out while you are reading, and `-L`, which forwards port 8888 on your laptop to the app's port on the compute node's loopback. `LOCAL_PORT` picks another local port.

## JupyterLab and RStudio

For JupyterLab, the last line of `launch.sh` becomes

``` bash
JUPYTER_TOKEN="$APP_TOKEN" jupyter lab --no-browser --ip=127.0.0.1 --port="$APP_PORT"
```

`--ip=127.0.0.1` is what makes it listen on loopback only, and `--port` is the port `connect.sh` forwards to. The token is the one the job made, so the URL `connect.sh` prints opens it.

For RStudio Server, take the `rserver` command from [Rocker's recipe](https://rocker-project.org/use/singularity.html) for running it in a Slurm job with Apptainer, keep its password, and add `--www-address=127.0.0.1 --www-port="$APP_PORT"`, for the same reasons. Then you open `http://localhost:8888` and sign in with that password. No proxy is needed in front of it, since the plain HTTP never leaves the compute node: between your laptop and the node, it is inside SSH.

The same goes for anything else with a web interface, such as TensorBoard or a Dask dashboard: make it listen on `127.0.0.1` and on `$APP_PORT`.

## Why the token still matters

Loopback is private to the node, but not to you. Every process on that node can connect to `127.0.0.1`, including other users' jobs, if your cluster shares nodes between jobs. So nobody can reach the app from another node, or read its traffic, but someone with a job on the same node can still connect to its port, and then the app's own token or password is the only thing in the way. That is why `launch.sh` makes a strong token for every job and gives it to the app, rather than turning it off.[^3]

## You get a shell too

The same connection, without `-N` and `-L`, is an ordinary SSH login to the compute node, inside your job's allocation. So `connect.sh` with its last line changed to

``` bash
exec ssh \
    -o ProxyCommand="$PROXY" \
    -o HostKeyAlias="srun-ssh-$JOBID" -o UserKnownHostsFile="$TMP/known_hosts" -o StrictHostKeyChecking=yes \
    -o IdentitiesOnly=yes -i "$TMP/client_key" \
    "$CLUSTER_USER@$NODE"
```

gives you a shell there, which you can use for anything you would use `ssh` for, such as `scp` or `rsync` with the same options. Slurm's environment variables, such as `SLURM_JOB_ID`, are not set in it, since `sshd` starts every session with a clean environment.

## Limitations

It needs an `sshd` on the compute node that you can run. Nearly every Linux system has one in `/usr/sbin`, since it is how you log in, but a compute node is not always a full system. If it has none, install OpenSSH yourself, e.g. from conda-forge, as [the part on software environments](../../software/index.md) shows, and set `SSHD` to it when you submit, as in `SSHD=/path/to/sshd sbatch launch.sh`.

`connect.sh` logs in to the login node five times: four to fetch the details and keys, and one to carry the session. With an SSH key, you won't notice. But if your cluster asks for a password or a second factor every time you log in, it will fail, since it cannot type them for you. SSH can share one login between connections, which fixes that: put this in your `~/.ssh/config` on your laptop,

``` sshconfig
Host my-cluster
    ControlMaster auto
    ControlPath ~/.ssh/cm-%C
    ControlPersist 10m
```

where `my-cluster` is your `LOGIN_HOST`, then log in once with `ssh my-cluster` as usual, and `connect.sh` reuses that login for 10 minutes after the last connection has closed.

There is one more hop than in the usual recipe, and two SSH sessions, one inside the other. In practice, I don't think you'd notice the difference for JupyterLab or RStudio.

And it relies on your cluster letting the login node `srun` into your job, which is what Slurm does by default. The [next page](40-own-relay.md) is about a different way around the hop, for when you want the job to be reachable from somewhere other than the login node: the job connects out to a relay.

[^1]: After a `scancel`, the job may not get to delete them, and the directory can simply be deleted by hand.

[^2]: `sshd` refuses to start unless it is started by its absolute path.

[^3]: If you ask for the whole node, with `#SBATCH --exclusive`, nobody else's job runs on it, and then nobody else can reach the port at all. But that is a whole node charged to your project, for one app.
