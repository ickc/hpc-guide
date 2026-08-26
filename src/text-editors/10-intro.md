---
title: "Introduction"
output-file: intro.html
---

There are many text editors you can run on a remote UNIX system such as an HPC.
The key problem to solve is how can you edit text files on a remote system in real time,
without having to manually transferring them back and forth?

There are two classes of text editors you can use:

## Terminal based text editors

TODO: add links

- nano
- emacs
- vim
- helix

If you don't know where to start, nano is a good option, often time available by defaults on many HPC systems (not Isambard though).

## GUI based text editors with a remote mechanism

- VSCode with Remote SSH
- Zed editor with "Remote Development"
- Jupyterlab

All of these has a sort of client server model so that you can edit as if it is local but main computations and IO
are happening on the remote server.
Jupyterlab uses browser as the client directly (where main selling point is not text editing but notebook editing).
Each of these deserves its own page for introduction.
The one main caveat to decide which one(s) to use is the resource consumed.

VSCode consumes more resources because of how inefficient it is in itself,
but also how its extensions often forks a lot of processes which can be constraining.
E.g. some HPC systems might reduce the `ulimit` you have on the login node on a much smaller amount (say 900)
which can easily be went over for a typical VSCode setup.

Zed is much more efficient in this aspect, but much younger in its ecosystem,
and also its more restrictive design (e.g. VSCode being a browser makes writing extensions using web technology,
such as MathJax/KaTeX almost trivial, while incredibly hard to do in Zed because it doesn't render general HTML/CSS/JS)
might means you'll be missing some features coming from VSCode.
But it is much more HPC friendly because it uses very little resources,
and HPC login nodes are very limited shared resources.

As a sidenote, using any of these requires extra attension when you want to edit files on the compute nodes
(say you're running an interactive notebook on the compute nodes).
This has nothing to do with the text editors themselves,
but the fact that you want to perform interactive tasks on the compute
where you often need extra hopping: local -> login -> compute.
We'll talk about this pattern in TODO and some of its pitfalls if setup incorrectly.

TODO: mention how to hop over SSH, security implications, and if setup incorrectly leads to security risks
(such as bridge login-compute through insecure HTTP).
Also mention code tunnel, why it is useful, and why it might be another security problem that some HPC centres
would restrict you from using it.
