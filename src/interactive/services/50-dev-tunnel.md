---
title: "Through Microsoft Dev Tunnels"
output-file: dev-tunnel
description: "A relay you don't have to run: the job connects out to Microsoft's Dev Tunnels, and you open an https URL after signing in with the same GitHub or Microsoft account. Microsoft sees your traffic."
aliases: [../dev-tunnel.html]
---

On the [previous page](40-own-relay.md), the relay was a server of yours. If you don't have one, somebody else's will do. [Dev Tunnels](https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/overview) is the Microsoft service behind [VS Code's tunnels](../10-editors.md), and it has a program of its own, `devtunnel`, which can publish any port, not just VS Code's. The job connects out to it, and you get an `https://...devtunnels.ms` URL that only opens after you sign in with the same account the job used.

## Once, on the login node

``` {.bash include="../../examples/dev-tunnel/setup.sh"}
```

It downloads `devtunnel` to `~/.local/bin`, for the kind of CPU the login node has, and signs you in. `-g` is to sign in with a GitHub account, and `-d` with a *device code*: it shows a code and a URL, and you enter the code at the URL in a browser anywhere, such as the one on your laptop. Your sign-in is then kept in your home directory, where jobs on the compute nodes can use it.[^1]

## On the cluster

``` {.bash include="../../examples/dev-tunnel/launch.sh"}
```

The app listens on the compute node's loopback, with a token, as on the previous pages. Then `devtunnel host -p <port>` connects out to Microsoft and publishes that port, and prints the URL. `--protocol http` says the app speaks plain HTTP, since it is `devtunnel` that adds HTTPS, between Microsoft and your browser.

Without `--allow-anonymous`, a tunnel is private: only the account that made it can open it. Never add that option. Then anyone who has the URL, or guesses the tunnel's name, would reach your app, with its token as the only thing in the way.

`--expiration 1d` is because a tunnel stays registered with Microsoft until it is deleted or expires. The job deletes its own tunnel when it ends normally, but maybe not after `scancel`, so it expires after a day anyway.[^2]

## On your laptop

``` {.bash include="../../examples/dev-tunnel/connect.sh"}
```

``` bash
LOGIN_HOST=my-cluster ./connect.sh <job ID>
```

There is no tunnel to hold open on your laptop: it reads the URL and the token from the login node, and opens them in your browser. Sign in with the same account you used in `setup.sh`. The first time, Dev Tunnels shows a page warning you that you are about to connect to a developer tunnel. That is expected, and you can carry on, since nobody else can open your tunnel. If the app asks for a token after you sign in, it is the one at the end of the URL `connect.sh` printed.

## What it means for security

The connections from the job to Microsoft and from your browser to Microsoft are both encrypted. But in between, Microsoft's service decrypts the traffic: it is Microsoft's certificate that your browser sees, and Microsoft's servers that end the HTTPS and pass the HTTP on. So Microsoft can read everything, your token, your code and your data, and you are trusting it with all of that.[^3]

You are also trusting your GitHub or Microsoft account. Whoever gets into it can open your tunnels, and whoever gets the sign-in kept in your home directory on the cluster can make tunnels as you.

So it comes down to whether your work may go through a third party. If your centre already recommends `code tunnel` for VS Code, it trusts the same relay.

## Limitations

It needs the compute nodes to reach Microsoft's servers, which depends on your cluster, as on [the previous page](40-own-relay.md). It needs a GitHub or Microsoft account. And there is a sign-in page and a warning page between you and your app, at least the first time.

The [next page](60-cloudflare-tunnel.md) is a relay with less to set up, and no sign-in at all.

[^1]: If your login nodes and compute nodes have different kinds of CPU, run it again on a compute node, from [a shell there](../20-shell.md), with `DEVTUNNEL` set to a path of its own.

[^2]: A tunnel can last from an hour to 30 days. `devtunnel list` shows yours, and `devtunnel delete <tunnel ID>` deletes one.

[^3]: VS Code's own tunnel, `code tunnel`, is different here. It runs an SSH session inside the tunnel, so its traffic is encrypted from end to end, and the relay cannot read it. `devtunnel host` for a web app has nothing like that.
