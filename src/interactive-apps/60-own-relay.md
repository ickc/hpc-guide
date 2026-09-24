---
title: "Method 3a: through a relay you run"
output-file: own-relay
description: "The job connects out to a server you control; nothing listens on the cluster. Needs that server."
---

Compute nodes often cannot accept connections from outside, but can usually make them:
most clusters let a job reach the internet, for downloading packages if nothing else.
So turn the connection around.
The app listens on the compute node's loopback,
and the job connects *out* to a server you control (a small cloud VM, a machine at your institution)
with `ssh -R`, which makes the app appear on that server's loopback.
From your laptop you then `ssh -L` to the server as you would to anything else.

    compute node --ssh -R (outbound)--> your server <--ssh -L-- laptop

Nothing listens on the cluster network, everything is inside SSH,
and the only party involved besides the cluster is you.
The catch is that you need such a server,
always on and reachable from the cluster,
which is why this is not the one I recommend to everyone.

::: callout-note
The obvious relay is the cluster's own login node,
but on many clusters that does not work:
compute nodes may not be allowed to SSH to login nodes,
or the login node may not accept your own keys.
If it works on yours, set `RELAY_HOST` to the login node,
and you have method 3a without needing a server.
:::

## What you need

- A cluster that uses Slurm (you submit jobs with `sbatch`).
- Compute nodes can connect out to your server over SSH.
  If only web traffic gets out, run your server's `sshd` on port 443 as well and use `RELAY_SSH="-p 443"`.
- A key on the cluster that logs in to your server *without a prompt*,
  since a batch job cannot type a passphrase.
  Make a separate one for this (`ssh-keygen -f ~/.ssh/id_relay`, no passphrase, `RELAY_SSH="-i ~/.ssh/id_relay"`),
  and consider restricting it on the server
  (`restrict,port-forwarding,permitlisten="localhost:8888"` in front of it in `authorized_keys`),
  so the key on the cluster can do nothing but open that one port.
- `python3` on the compute node, only to pick a free port and to run the demo app.

## Running it

On the login node, from this example's directory:

``` bash
RELAY_HOST=me@my-server sbatch launch.sh
```

On your laptop, once the job is running:

``` bash
RELAY_HOST=me@my-server ./connect.sh
```

and open <http://localhost:8888>.

### `launch.sh`, on the cluster

``` {.bash include="examples/own-relay/launch.sh"}
```

### `connect.sh`, on your laptop

``` {.bash include="examples/own-relay/connect.sh"}
```

## Testing

[`examples/own-relay/test.sh`](examples/own-relay/test.sh) needs a relay, so it skips unless `RELAY_HOST` is set.
With one, it submits `launch.sh` and fetches the demo page on the relay, over SSH from the login node.
