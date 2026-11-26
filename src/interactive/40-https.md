---
title: "HTTPS with a self-signed certificate"
output-file: https
description: "The easiest fix to understand for the unencrypted last mile: make JupyterLab speak HTTPS itself, with a certificate you make once. It works, and the same trick applies anywhere, but it is tedious, and for RStudio it gets complicated."
---

On the [previous page](30-services.md), I showed the recipe you may be tempted to use to run JupyterLab on a compute node, and why it is a bad idea: the last mile, from the login node to the compute node, is unencrypted HTTP. On this page I'll go through the easiest fix to understand, although a somewhat tedious one: make JupyterLab speak HTTPS itself, with a self-signed certificate.

As a reminder, the recipe was to run, in a job,

``` bash
#!/bin/bash
#SBATCH --time=1:00:00
jupyter lab --no-browser --ip="$(hostname -i)" --port=8888
```

then, on your laptop, tunnel to it through the login node,

``` bash
ssh -N -L 8888:<compute node address>:8888 <login node>
```

and open `http://localhost:8888/lab?token=<token>`, with the token printed in the job's output. That last part is less reliable than it sounds: on some clusters, the job's output only shows up on the login node after a delay, or only when the job ends.[^1] So below, you make the token yourself, before the job, and you never need to read the job's output at all.

## The one-time setup

HTTPS needs a certificate, and a key that goes with it. Normally a certificate is signed by a certificate authority that your browser trusts, which is how your browser knows it is talking to the right server. A compute node has no domain name for an authority to sign, so instead you sign your own.

You do this once, on the login node, and every job reuses it. In the same place, make the token too:

``` {.bash include="../examples/jupyter-https/setup.sh"}
```

`umask 077` makes sure the files are created readable by you only. The certificate is for `localhost` because, through the tunnel, that is what your browser connects to, and it lasts a year, after which you run this again.[^2]

Since your browser has no authority to vouch for this certificate, you are the one who vouches for it. You do this by its fingerprint, a hash of the certificate:

``` bash
openssl x509 -in ~/.jupyter-tls/cert.pem -noout -fingerprint -sha256
```

Note it down; you'll need it once.[^3]

The key and the token are the secrets here. Whoever has the key can pretend to be your JupyterLab, and whoever has the token can use it, whenever a job of yours is running. So treat `~/.jupyter-tls` like your SSH keys: don't copy it around, and if you think it has leaked, delete it and make a new one.

## Modifying the original command

JupyterLab can serve HTTPS directly, given a certificate and a key, and it takes its token from `JUPYTER_TOKEN` if set. So the job becomes

``` {.bash include="../examples/jupyter-https/job.sh"}
```

The port is now a random-looking one rather than Jupyter's default, 8888, which is everyone's first choice. The last option is so that, if the port is taken anyway, the job fails rather than quietly moving to another port, which you would only find out about from the job's output.[^4]

Without the job's output, the one thing left to find out is which node the job is running on. `squeue --me` shows it, under `NODELIST`, once the job has started. The tunnel on your laptop is exactly the same `ssh -L` as before, with that node:

``` bash
ssh -N -L 28417:<node>:28417 <login node>
```

and you open `https://localhost:28417/lab?token=<token>`, with the token from `~/.jupyter-tls/token`. Since the token does not change, neither does that URL.

The first time, your browser will warn you that the certificate is not trusted. That is expected: it is self-signed. Before you accept it, open the certificate from the warning page, and check that its SHA-256 fingerprint is the one you noted down. Then accept it, and your browser remembers it for `localhost:28417`, so the next job, with the same certificate, opens without a warning.[^5]

Don't skip that check, as it is the whole point. A man in the middle between the login node and the compute node can hand your browser a certificate of their own, and the browser would give you the same warning. The fingerprint is what tells you apart.[^6]

I have tested this to work in Chrome and Firefox. Safari takes one more step.[^7]

## Limitations

This fixes the eavesdropping: nobody on the cluster network can read your token, your code, or your data any more. It does not change the fact that JupyterLab is still listening on the compute node's network address. Anyone on the cluster can still connect to the port, and the token is the only thing in the way. Now they cannot sniff it, but it is also the same token for every job, for a year, sitting in your home directory.

Once your browser accepts the certificate, taking that back is harder than it should be, and how far the trust goes depends on the browser. Chrome and Firefox keep an exception of their own, while for Safari you trust the certificate in macOS itself, and I could not find where macOS keeps that to remove it again. Until the certificate expires, whoever has the key can pretend to be `https://localhost` to that browser, or, after the Safari step, to your whole Mac, and deleting `~/.jupyter-tls` and making a new one does not change that. So the key on the cluster matters more than it looks.

And it is tedious. A certificate and a token to make and keep safe, a fingerprint to check, and a warning to click through, more than once. A fixed port that someone else may have taken. And it only works this simply because JupyterLab can serve HTTPS itself.

### Can the same trick work with RStudio in a container?

Technically, yes, but it becomes much more complicated. On an HPC you would most likely run the open-source RStudio Server, from a container, and the open-source edition cannot serve HTTPS: that [is a feature of Posit Workbench](https://forum.posit.co/t/configuring-ssl-certificates-in-rstudio-server-pro/109980), the commercial edition. So the certificate needs something else to serve it, a reverse proxy running next to RStudio on the compute node, which speaks HTTPS to your browser and plain HTTP to RStudio, so that the plain HTTP never leaves the node.

That proxy is one more program to get onto the cluster and configure, and not just any proxy will do. RStudio thinks it is serving plain HTTP, and redirects your browser accordingly, to `http://`, unless the proxy is one that understands HTTP and tells it otherwise. Then the container itself needs care: [Rocker's recipe](https://rocker-project.org/use/singularity.html) for running RStudio Server with Apptainer already needs several directories bind-mounted, a password, and a handful of options. And on a node shared with other users' jobs, they can reach RStudio's plain HTTP port too, without going through the proxy, since loopback is shared by everyone on the node. So it can be done, but by now it is no longer the easy-to-understand option.

## Conclusion

This is simple, but tedious. It is technically easy, and there is nothing HPC-specific about it: the same trick, a self-signed certificate and a check of its fingerprint, can be applied anywhere you run a service over a network you don't trust. But it works this simply only for apps that can serve HTTPS themselves, and the RStudio you are likely to run on an HPC is not one of them. On [the next page](50-srun-ssh.md), I'll talk about a solution specific to HPC, or rather to Slurm, that is easy to deploy with minimal setup, and works the same whether it is JupyterLab or RStudio.

[^1]: Slurm writes the job's output to `slurm-<job ID>.out` from the compute node. Whether and when the login node sees it depends on the program buffering its output, on the shared filesystem caching it, and on whether the cluster writes it somewhere local first and copies it over at the end. Flushing the output, e.g. with `PYTHONUNBUFFERED=1`, fixes only the first.

[^2]: `-nodes` leaves the key unencrypted, so that JupyterLab can read it without asking you for a passphrase. The last three options limit the certificate to the one thing it is for, telling your browser which server it is talking to. Without them, `openssl` makes a certificate that is also allowed to sign other certificates. You don't need that, and if you ever told your computer to trust this certificate, anyone with the key could make a certificate for any website, and your computer would accept it.

[^3]: Once per browser, that is. You'll need it again when you connect from another browser or another laptop, when your browser forgets that you accepted the certificate (Firefox remembers it until you remove the exception, while some other browsers remember it only for a while, or until you clear your browsing data), and when you make a new certificate after a year, which comes with a new fingerprint to note down. Each time, it is the same check as the first.

[^4]: It fails when something else on the node is already listening on that port: another user's job, if your cluster shares nodes between jobs, or another job of yours on the same node. A random-looking port makes that unlikely, but not impossible. If it does fail, pick another number, below 32768 to stay out of the range Linux hands out for outgoing connections, and use it in both the job and the tunnel.

[^5]: This is why I make the certificate once rather than once per job. With a new certificate every job, there is a new fingerprint to check every job, and a warning every job, and once that becomes routine, it is tempting to click through without checking. With one certificate, you check once, and from then on a warning means something: someone else's certificate is on the other end, and that is when to stop.

[^6]: And you can trust the fingerprint you are comparing with because you read it on the login node over `ssh`, which is already encrypted.

[^7]: In Safari, accepting the certificate on the warning page is not enough. JupyterLab opens, but as soon as you start a kernel, its status stays "disconnected", and JupyterLab's log shows `SSL: SSLV3_ALERT_CERTIFICATE_UNKNOWN` errors. The kernel talks to your browser over a WebSocket, which is a separate connection from the page, and Safari does not apply the certificate you accepted to it, so it refuses the connection. Instead, you trust the certificate in macOS itself. In the certificate you opened from the warning to check the fingerprint, expand "Trust", set "Secure Sockets Layer (SSL)" to "Always Trust", leave the rest as they are, and confirm with your password. Your whole Mac then trusts it for `localhost`, which is where the options that stop it signing other certificates matter.
