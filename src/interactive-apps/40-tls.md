---
title: "Method 1b: HTTPS on the node"
output-file: tls
description: "The smallest change from the usual recipe: same ssh -L tunnel, but encrypted all the way to the node."
---

This is [method 1a](30-plain-http.md) with one change: the app speaks HTTPS instead of HTTP,
using a self-signed certificate made for the job.
You still tunnel with `ssh -L` and open a URL, so if you already use the usual recipe, this is the least to relearn.

What it fixes: nobody on the cluster network can read your token or your traffic any more.
What it does not: the app still listens on the cluster network, so anyone can *connect* to it.
They just get nowhere without the token, which is therefore the only thing keeping them out.
Use a strong one: Jupyter's default token is fine; don't replace it with a short password.
If you would rather have nothing listening on the network at all, use [method 2](50-srun-ssh.md).

## What you need

- A cluster that uses Slurm (you submit jobs with `sbatch`).
- SSH access to a login node, and `ssh` on your laptop.
- Your home directory is shared between the login and compute nodes.
- `python3` and `openssl` on the compute node.
- The login node can connect to the compute node's network address.
  That is what the usual recipe relies on too.
  The launcher uses the address the node's own name resolves to;
  set `LISTEN_IP` if your cluster wants another one.

## Running it

On the login node, from this example's directory:

``` bash
sbatch launch.sh
```

On your laptop, with the login node as you would name it after `ssh`:

``` bash
LOGIN_HOST=my-cluster ./connect.sh <JOBID>
```

It prints the URL, with the token, and the certificate's fingerprint.
Your browser will warn you that the certificate is self-signed:
check the fingerprint matches (click the padlock or the warning to see it), then accept it.
That check is what makes a self-signed certificate safe,
so don't skip it.

### `launch.sh`, on the cluster

This one works with any app, because `tls_proxy.py` adds the TLS in front of it.
Replace the demo app line with yours, listening on `127.0.0.1:$APP_PORT`.

``` {.bash include="examples/tls/launch.sh"}
```

### `connect.sh`, on your laptop

``` {.bash include="examples/tls/connect.sh"}
```

### `tls_proxy.py`

``` {.python include="examples/tls/tls_proxy.py"}
```

## Jupyter can do it by itself

Jupyter serves HTTPS directly when given a certificate,
so for Jupyter you can skip the proxy and replace the last two commands of `launch.sh` with

``` bash
jupyter lab --no-browser --ip="$LISTEN_IP" --port="$TLS_PORT" \
    --certfile="$SESSION/cert.pem" --keyfile="$SESSION/key.pem"
```

The token is then Jupyter's own, printed in the job's output, rather than `APP_TOKEN`.
RStudio Server, TensorBoard, a Dask dashboard and most other apps cannot, and need the proxy.

## Testing

[`examples/tls/test.sh`](examples/tls/test.sh) submits `launch.sh` and fetches the demo page from the login node
over HTTPS, trusting only the job's certificate.
That is exactly the hop `connect.sh`'s tunnel hands over to;
the laptop-to-login part before it is your normal SSH login.
