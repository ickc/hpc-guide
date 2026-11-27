---
title: "Running a service on a compute node"
output-file: intro
description: "Have you ever wanted to run JupyterLab or RStudio on a compute node of an HPC? The usual recipe leaves the connection unencrypted, and your account open to everyone else on the cluster."
aliases: [../services.html]
---

Have you ever wanted to launch a "service", such as a JupyterLab instance, or RStudio, on a compute node of an HPC? Then you've got a few problems.

First, you need to think about how to bootstrap the environment and launch it on an HPC. Perhaps you'd want to set up a conda environment, or use a container.

Second, you need to launch it on a compute node, i.e. submit a job to the queue, so that you have access to more compute. Doing lightweight analysis on the login node is probably fine, but as soon as what you want to do is relatively computationally intensive, you should run it on a compute node instead, otherwise it could be considered an abuse of resources.

Third, you need to think about how you can connect to that instance *interactively* and *securely*. That's why I specialize the rest of this section to "services": a service is when you'd want it to be interactive, i.e. you change things in real time, see the feedback, and decide what to do next (sort of exploratory data analysis).

![](./hpc-service.svg){width="80%" fig-alt="A laptop connects to the login node with ssh. From the login node to the compute node running JupyterLab or RStudio, the connection is a dashed arrow labelled with a question mark."}

Running an interactive job is in every HPC documentation, and [the previous page](../20-shell.md) showed how to do it, so that's solved. What stumps you is when the thing you interact with is not on the command line, because the usual advice on interactive jobs expects you to interact via the command line. The one remaining piece is how you connect to it securely. Nowadays there are many GUI solutions, often powered by web technologies, native in the browser, or at least reached over a network connection.

You may be tempted to run, in a job,

``` bash
#!/bin/bash
#SBATCH --time=1:00:00
jupyter lab --no-browser --ip="$(hostname -i)" --port=8888
```

then, on your laptop, tunnel to it through the login node,

``` bash
ssh -N -L 8888:<compute node address>:8888 <login node>
```

and open `http://localhost:8888/lab?token=<token>`, with the token printed in the job's output. Like how you would on your own local computer. This looks secure, and that's how it bites people. Between your laptop and the login node it is nearly impossible to have unencrypted traffic: that hop is `ssh`, and every HPC documentation tells you to use it. So following the standard recommendations seems fine, until it doesn't. The problem is the last mile: from the login node to the compute node, the connection is **unencrypted** HTTP. On a multi-tenant system like an HPC, where the login nodes can have any users and the network is shared with all of them, this is a big no-no.

Why is it a bad idea? That plain HTTP carries everything: your token (or RStudio password), your code, and your data. Anyone who can see the traffic between the login node and the compute node can read it, and a man in the middle can change it.[^1] Worse, the app is listening on the compute node's network address rather than on its loopback, so nobody needs to be in the middle at all: anyone on the cluster can connect to the port directly, and the token is the only thing in the way. Whoever has it can use your JupyterLab as well as you can.[^2]

And since services like JupyterLab and RStudio exist to execute code, whoever gets in can run anything as you. You are enabling remote code execution, on your own account: your files, your allocation, your SSH keys.

All this may sound theoretical. But these days, in the agentic era, with LLM agents finding [previously unknown exploitable bugs in real-world software](https://projectzero.google/2024/10/from-naptime-to-big-sleep.html), a zero-day somewhere along the chain is not unimaginable. And when that happens, I think traceability is the strongest point. So don't think that if you don't care about leaking anything, it would be OK. Whatever runs in that session is logged as you, and the traceability requirement is that you do your own due diligence to ensure no one else is running things impersonating you. If you don't encrypt your traffic, you are an accomplice, helping the adversary become much less traceable.

## Which one to use

The rest of this section goes through the ways to do this securely, each on a page of its own, with scripts you can run. Side by side:

- [SSH over srun](30-srun-ssh.md) is the one I recommend. It needs nothing but Slurm and an `sshd`, nothing listens on the cluster network, nobody else is in the path, and it works the same for JupyterLab, RStudio or anything else with a web interface.
- [HTTPS with a self-signed certificate](20-https.md) is the smallest change from the usual recipe, if your app is JupyterLab, and you don't mind checking a fingerprint and a fixed port.
- [Microsoft Dev Tunnels](50-dev-tunnel.md), if you'd rather have only a browser on your laptop, and your work may go through Microsoft.
- [A relay you run](40-own-relay.md), if you have a server of your own and want everything under your control.
- [A Cloudflare quick tunnel](60-cloudflare-tunnel.md), only for a quick look.
- Never the usual recipe above, with plain HTTP on the cluster network.

The [next page](20-https.md) starts with the easiest to understand.

[^1]: An ordinary user cannot simply listen in on a switched network. But someone with root on any node the traffic goes through can, and so can anyone who has compromised one. On a system with thousands of users, you cannot check that nobody has.

[^2]: Some recipes turn even that off, with `--NotebookApp.token=''` for Jupyter or `--auth-none=1` for RStudio Server. Then there is nothing in the way.
