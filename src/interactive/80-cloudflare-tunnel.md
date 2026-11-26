---
title: "Through a Cloudflare quick tunnel"
output-file: cloudflare-tunnel
description: "No account and no setup: the job connects out to Cloudflare and gets a public trycloudflare.com URL. Anyone with the URL reaches your app, so only its token protects it. For a quick look, not for regular use."
---

The [previous page](70-dev-tunnel.md) used Microsoft's relay, with a sign-in in front of it. Cloudflare's `cloudflared` can make a [quick tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/do-more-with-tunnels/trycloudflare/) with no account at all: the job connects out to Cloudflare, and you get an `https://...trycloudflare.com` URL, a new one every time.

## On the cluster

``` {.bash include="../examples/cloudflare-tunnel/launch.sh"}
```

The first time, the job downloads `cloudflared` from its GitHub releases to `~/.local/bin`, for the kind of CPU the compute node has, and later jobs reuse it. Then the app starts on the compute node's loopback, with a token, and `cloudflared tunnel --url` publishes it. `--no-autoupdate` stops `cloudflared` from replacing itself while the job runs. The job reads the URL from `cloudflared`'s log, and writes it, with the token, to `~/.interactive-apps/<job ID>`.

## On your laptop

``` {.bash include="../examples/cloudflare-tunnel/connect.sh"}
```

``` bash
LOGIN_HOST=my-cluster ./connect.sh <job ID>
```

reads the URL and the token from the login node, and opens them in your browser.

## What it means for security

The difference that matters is that this URL is **public**. Nobody has to sign in: anyone who has the URL reaches your app, from anywhere on the internet. The only thing protecting it is the app's own token, so this is only acceptable for an app that has one, with a strong one. JupyterLab's own is strong enough, and the launcher makes one for the demo app. Never turn the token off for this, as some recipes do.

And as with Microsoft's relay, Cloudflare ends the HTTPS and passes the HTTP on, so Cloudflare can read everything that goes through it.[^1]

## Limitations

Cloudflare says quick tunnels are for testing and development, with no promise that they keep working.[^2] Like the previous two pages, it needs the compute nodes to reach the internet, here Cloudflare and, the first time, GitHub.

So I include it only because it is the least effort of anything in this part. For a quick look, with a strong token, it does the job. For regular use, prefer one of the others.

## Which one to use

This part went through several ways to reach a web app on a compute node, so to put them side by side:

- [SSH over srun](50-srun-ssh.md) is the one I recommend. It needs nothing but Slurm and an `sshd`, nothing listens on the cluster network, nobody else is in the path, and it works the same for JupyterLab, RStudio or anything else with a web interface.
- [HTTPS with a self-signed certificate](40-https.md) is the smallest change from the usual recipe, if your app is JupyterLab, and you don't mind checking a fingerprint and a fixed port.
- [Microsoft Dev Tunnels](70-dev-tunnel.md), if you'd rather have only a browser on your laptop, and your work may go through Microsoft.
- [A relay you run](60-own-relay.md), if you have a server of your own and want everything under your control.
- A Cloudflare quick tunnel, only for a quick look.
- Never [the usual recipe](30-services.md), with plain HTTP on the cluster network.

That is the end of this part, and of this guide.

[^1]: Cloudflare can put a sign-in in front of a tunnel too, with a *named* tunnel and Cloudflare Access. But that needs an account and a domain of your own, and is more setup than any other page of this part.

[^2]: It also limits each quick tunnel to 200 requests at a time, and does not support Server-Sent Events, a way for a web page to receive updates from the server.
