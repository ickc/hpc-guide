---
title: "Text editors"
description: "Editing files on the cluster in real time: editors that run in the terminal, and editors that run on your laptop with a server on the cluster, with what each costs the shared login node."
output-file: editors
aliases: [../text-editors/intro.html]
---

[The last part](../storage/30-moving-data.md) ended with your data in the right place. This last part of the guide is about working on the cluster as you go, rather than through batch jobs, and it starts with the most basic case, editing a file there.

There are many text editors you can run on a remote UNIX system such as an HPC. The key problem to solve is how you can edit text files on a remote system in real time, without having to transfer them back and forth by hand.

There are two classes of text editors you can use.

## Terminal based text editors

These run on the cluster itself, in the terminal you logged in with:

- [nano](https://www.nano-editor.org)
- [GNU Emacs](https://www.gnu.org/software/emacs/)
- [Vim](https://www.vim.org)
- [Helix](https://helix-editor.com)

If you don't know where to start, nano is a good option, often available by default on many HPC systems (though not on all of them). If the one you want is not there, you can install it yourself, as [the page on tools for yourself](../software/30-tools.md) shows.

## GUI based text editors with a remote mechanism

- [VS Code](https://code.visualstudio.com) with [Remote - SSH](https://code.visualstudio.com/docs/remote/ssh)
- [Zed](https://zed.dev) with [Remote Development](https://zed.dev/docs/remote-development)
- [JupyterLab](https://jupyterlab.readthedocs.io)

All of these have a sort of client-server model, so that you can edit as if it is local, while the main computation and IO happen on the remote server. VS Code and Zed run their user interface on your laptop, and a server of their own on the cluster, which they start and talk to over SSH. JupyterLab uses the browser as the client directly (where its main selling point is not text editing but notebook editing).

The one main caveat in deciding which one(s) to use is the resources they consume.

VS Code consumes more resources, because of how inefficient it is in itself,[^1] but also because its extensions often fork a lot of processes, which can be constraining. E.g. some HPC systems reduce the number of processes you may have on the login node to a much smaller number (say 900), which a typical VS Code setup can easily go over. `ulimit -u` shows the limit you have.[^2]

Zed is much more efficient in this aspect, but much younger in its ecosystem, and also its more restrictive design might mean you'll be missing some features coming from VS Code. E.g. VS Code being a browser makes writing extensions using web technology, such as MathJax or KaTeX, almost trivial, while that is incredibly hard to do in Zed, because it doesn't render general HTML, CSS and JavaScript. But it is much more HPC friendly, because it uses very little resources, and HPC login nodes are very limited shared resources.

## Editing on a compute node

As a side note, using any of these requires extra attention when you want to work on the compute nodes, say you're running an interactive notebook there. This has nothing to do with the text editors themselves, but with the fact that you want to perform interactive tasks on a compute node, where you often need an extra hop: laptop → login node → compute node. You can SSH to the login node, but usually not to a compute node.

### VS Code tunnels

VS Code has a way of its own around that hop, [Remote Tunnels](https://code.visualstudio.com/docs/remote/tunnels). You run `code tunnel` on the cluster, which can be in a job on a compute node, and it connects out to a relay run by Microsoft. VS Code on your laptop, or in a browser at vscode.dev, connects to the same relay, after you sign in to the same GitHub or Microsoft account on both ends. Nothing listens on the cluster, and you don't need SSH to the node.

But from then on, the way into the job is through Microsoft rather than through the cluster: another hole into the compute nodes, which does not go through the centre's own login, whatever that checks (your SSH key, a certificate, a second factor). Whoever gets into your GitHub or Microsoft account gets a shell on the cluster as you. That is why some centres prohibit it, while others document it as the way to use VS Code on a compute node. So look in your centre's documentation, or its acceptable use policy, for VS Code or tunnels, and ask its helpdesk if it says nothing. It also needs the compute node to reach the internet, which some clusters allow and some don't. The relay is Microsoft's Dev Tunnels service, which [a later page](services/50-dev-tunnel.md) uses for any web app.

The rest of this part is about that hop: [the next page](20-shell.md) is a shell on a compute node, which is all a terminal editor needs, and [the section after it](services/10-intro.md) is about web apps such as JupyterLab, why the usual recipe for them bridges the login node and the compute node with insecure HTTP, and how to do it securely.

[^1]: Its own documentation asks for at least 1 GB of RAM on the remote host, and recommends at least 2 GB and 2 cores, for the server alone.

[^2]: It counts every process of yours on that login node, from all your sessions, and on Linux every thread too. When you hit it, the next program you start fails, often with a message like `fork: retry: Resource temporarily unavailable`, and that can be your shell as well as VS Code.
