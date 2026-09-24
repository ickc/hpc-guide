---
title: "Method 1a: plain HTTP on the node (don't)"
output-file: plain-http
description: "What many cluster guides tell you to do. Unencrypted, and open to everyone on the cluster."
---

This is the method you will find in a lot of documentation, including some written by the facilities themselves,
so it is worth knowing what it looks like and why not to use it.

The job starts the app listening on the compute node's network address, e.g.

``` bash
jupyter lab --no-browser --ip="$(hostname -i)" --port=8888
```

and you tunnel to it from your laptop through the login node:

``` bash
ssh -N -L 8888:<compute node address>:8888 my-cluster
```

The tunnel is encrypted between your laptop and the login node,
which makes this look safe, but it stops there.
From the login node to the compute node the traffic is plain HTTP,
unencrypted, on a network shared by every user of the cluster, and it carries your Jupyter token
(or RStudio password), your code, and your data.
And because the app listens on the network rather than on loopback,
anyone logged in to the cluster can connect to it directly, tunnel or not.
A Jupyter token is the right to run any code as you,
so anyone who reads it or guesses it gets your account.

Don't use this. The smallest change that fixes it is [method 1b](40-tls.md):
same workflow, but over HTTPS.
