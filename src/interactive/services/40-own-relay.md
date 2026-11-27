---
title: "Through a relay you run"
output-file: own-relay
description: "Turning the connection around: the job connects out to a server of yours with ssh -R, and your laptop connects to the same server. Everything is inside SSH, but you need that server, and it sees your traffic."
aliases: [../own-relay.html]
---

[SSH over srun](30-srun-ssh.md) gets to the compute node through the login node. There is another way around the hop, which turns the connection around. A compute node usually cannot accept connections from outside the cluster, but on many clusters it can make them, if only to download packages. So the job connects *out* to a machine that your laptop can also reach, a *relay*, and your laptop connects to the app through it.

![](hpc-relay.svg){width="80%" fig-alt="JupyterLab or RStudio listens on 127.0.0.1 of the compute node. The compute node connects out to a relay, and the laptop connects to the same relay."}

The app listens on the compute node's loopback, as on the previous page, so again nothing listens on the cluster network. All of your traffic goes through the relay, so whoever runs it is who you are trusting with it. On this page, that is you.

Whether a compute node may connect out at all depends on how your centre has set up its network: some clusters let it reach anywhere, some only the web, and some nothing outside the cluster. Their documentation may say; otherwise, try it from [a shell on a compute node](../20-shell.md), e.g. `curl -sI https://github.com` for the web, or `ssh me@my-server true` for SSH to a server of yours.

## The relay is your own server

If you have a server that both the cluster and your laptop can reach, such as a small cloud VM or a machine at your institution, SSH alone does it. The job runs `ssh -R`, which makes the app appear on the server's own loopback, and from your laptop you `ssh -L` to the server, as you would to anything else.

### On the cluster

``` {.bash include="../../examples/own-relay/launch.sh"}
```

Submit it with your server as `RELAY_HOST`:

``` bash
RELAY_HOST=me@my-server sbatch launch.sh
```

The job starts the app on a free port of its loopback, with a token, as on the previous page, and writes the details to `~/.interactive-apps/<job ID>`. Then `-R 127.0.0.1:8888:127.0.0.1:<app port>` asks the server to listen on port 8888 of *its* loopback, and to pass every connection there back through this SSH session to the app. `RELAY_PORT` picks another port than 8888, and `RELAY_SSH` adds options to `ssh`, such as `-p 443` or a key with `-i`.

`BatchMode=yes` is because a job cannot type a password or a passphrase, so `ssh` fails at once rather than wait for one. `StrictHostKeyChecking=accept-new` trusts the server's host key the first time it is seen, and only that key after it. So before the first job, log in to the server once from the login node, and check the fingerprint it shows you against the server's own, which puts the right key into your `~/.ssh/known_hosts` on the cluster.[^1] `ExitOnForwardFailure` ends the job if the port on the server is taken, and `ServerAliveInterval` keeps the connection from timing out while nothing is going through it.

### On your laptop

``` {.bash include="../../examples/own-relay/connect.sh"}
```

``` bash
LOGIN_HOST=my-cluster ./connect.sh <job ID>
```

reads the relay, its port and the token from the login node, and forwards port 8888 on your laptop to port 8888 on the server's loopback, which is the app. `RELAY_HOST` overrides the relay's name, if your laptop knows it by another name than the cluster does.

### A key for the job, and what it may do

The job needs a key to log in to your server, and since it cannot type a passphrase, that key has none. Anyone who gets it, such as anyone who can read your home directory on the cluster, can log in to your server with it. So make a key for this alone, on the cluster,

``` bash
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_relay
```

submit with `RELAY_SSH="-i ~/.ssh/id_relay"`, and on the server, restrict it to the one thing it is for, by putting options in front of it in `~/.ssh/authorized_keys`:

``` text
restrict,port-forwarding,permitlisten="127.0.0.1:8888",command="/bin/false" ssh-ed25519 AAAA... id_relay
```

`restrict` turns off everything a key can do by default, then `port-forwarding` turns forwarding back on, and `permitlisten` allows only port 8888 on the server's loopback, which is what the job asks for. `command` replaces any command the key asks to run with `/bin/false`, so it cannot get a shell either. With all four, someone who steals the key can open that one port on your server, and nothing else.

## What it means for security

Everything that crosses a network is inside SSH: from the compute node to the server, and from the server to your laptop. Nobody between them can read it, and no third party is involved.

But the two SSH sessions meet on the server, and there, on its loopback, the traffic is plain HTTP again. So whoever has root on the server can read it. That is you, and whoever hosts it for you, e.g. your cloud provider. And every other user of the server can connect to the port, like other users' jobs on a compute node, which is why the token stays on. So use a server that nobody else logs in to.

::: callout-note
The obvious relay is the cluster's own login node, which every compute node can reach. On many clusters that does not work: the compute nodes may not be allowed to SSH to the login nodes, or the login nodes may not accept keys that you added yourself. And where it works, the port it opens is on the login node's loopback, where every other user logged in to that login node can connect to it.
:::

## Limitations

You need the server, always on, and reachable from the compute nodes. If your cluster only lets the compute nodes out to the web, the server's `sshd` has to listen on port 443 too.[^2] And a port on the server can only be held by one job at a time, so two jobs at once need two `RELAY_PORT`s, and two `permitlisten`s for the key.

The [next page](50-dev-tunnel.md) is the same idea with somebody else's relay, for when you don't have a server.

[^1]: Your home directory is shared, so the job reads the same `known_hosts` as the login node.

[^2]: Outgoing traffic on port 443 is usually let through for HTTPS. `sshd` can listen on several ports, with a `Port` line for each in its configuration, and `RELAY_SSH="-p 443"` makes the job use it.
