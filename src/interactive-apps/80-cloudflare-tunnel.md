---
title: "Method 3c: through a Cloudflare quick tunnel"
output-file: cloudflare-tunnel
description: "No account and no setup, but the URL is public: only the app's own token protects it."
---

Same shape as [method 3b](70-dev-tunnel.md), with Cloudflare's relay instead of Microsoft's.
Cloudflare's `cloudflared` can make a *quick tunnel* with no account at all:
the job connects out, and you get a random `https://...trycloudflare.com` URL.

The difference that matters is that this URL is **public**.
Nobody has to sign in; anyone who has the URL reaches your app.
The only thing protecting it is the app's own token,
so this is only acceptable with an app that has one and with a strong token
(Jupyter's default is fine; the launcher makes one for the demo app).
Quick tunnels are also meant for testing, without any promise that they keep working.

I include it because it is the least effort of anything in this section.
For regular use prefer [method 2](50-srun-ssh.md),
or, if you want a relay, 3b, which at least checks who you are.
(Cloudflare can do that too, with a named tunnel behind Cloudflare Access,
but that needs an account and a domain, and is beyond this guide.)

## What you need

- A cluster that uses Slurm (you submit jobs with `sbatch`).
- Compute nodes can reach the internet: Cloudflare, and GitHub to download `cloudflared` the first time.
- Your home directory is shared between the login and compute nodes.
- `python3` on the compute node.
- An app with its own authentication.

## Running it

On the login node, from this example's directory:

``` bash
sbatch launch.sh
```

and on your laptop:

``` bash
LOGIN_HOST=my-cluster ./connect.sh <JOBID>
```

which looks up the URL, adds the token, and opens it.

### `launch.sh`, on the cluster

``` {.bash include="examples/cloudflare-tunnel/launch.sh"}
```

### `connect.sh`, on your laptop

``` {.bash include="examples/cloudflare-tunnel/connect.sh"}
```

## Testing

[`examples/cloudflare-tunnel/test.sh`](examples/cloudflare-tunnel/test.sh) submits `launch.sh` and fetches the demo page
through Cloudflare, as a browser anywhere would.
