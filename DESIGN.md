# Design philosophy

Why the guide is the way it is. [DEVELOPER.md](DEVELOPER.md) has how the site is built, and
[AGENTS.md](AGENTS.md) the rules that follow from this page for whoever writes it, a person or an agent.

## Who it is for

Scientists, research software engineers, PhD students and postdocs who have an allocation and an analysis in
mind, and want to use the machine well enough to get it done. They are not HPC specialists, and what they lack
most is not a reference for each tool, but the landscape: which kind of problem they have, which tools exist for
it, and what tends to go wrong. Every centre already documents its own system, so there is no need for another
guide that repeats that. What is missing is the layer above it, which is much the same on every cluster.

So the guide assumes little, explains each term once, where it first appears, and teaches by example: a command
or a script first, then why each part of it is there.

## A book, not a reference

It is meant to be read from one page to the next. The parts form a tree, sorted by the kind of problem the reader
has rather than by tool. Parallelism, for example, is sorted into many independent tasks, threads, ranks that
communicate, and workflows, and only then into the tools for each, on one node or on many. Each page opens by
picking up from the one before, and ends by pointing to the next, so that a reader who starts at the beginning
never meets something unexplained.

Where there are several ways of doing the same thing, such as the ways to run many independent tasks, or to reach
a web app on a compute node, they form a section of their own, which starts with a page comparing them: what each
is for, the tradeoffs, and which to reach for first. The page on each one is then about that one only. A reader
on the page about DragonHPC has already chosen it, and wants to know how to run it, so how it compares with
`mpi4py.futures` belongs on the page where they choose.

It is selective. The material it grew from had far more in it than it uses, much of it specific to one system,
or one scheduler. A tool or a detail goes in only if this reader needs it to get their work done, and the rest is
a link to the tool's own documentation.

## Problem first

Most pages follow the shape of the HPC series on my blog, which is where this started: what you are trying to
do, the recipe you may already know, why it bites, the fix as commands you can run, with every option explained,
and then the fix's own limitations. The reader usually arrives with the recipe, from a colleague or an old README,
so starting from it is starting from where they are, and seeing why it bites is what makes the fix stick.

## By concept, not by facility

Nothing in the guide is specific to one cluster, although most of it was tested on one. Names change from one
centre to the next, and so do paths and policies, but the concepts don't: a home directory mounted everywhere,
small, and slow under heavy I/O; scratch that is fast but purged; storage shared by a project; storage local to
one node, for the length of a job. So the guide names things by what they are, uses an environment variable where
centres commonly set one, with a footnote that the name varies, and tells the reader what to look for in their own
centre's documentation. No facility is named, and no real path or username appears, since a reader who sees one
copies it, and on their cluster it is wrong.

Where a concrete system makes the point clearer, it is described by its hardware and software, e.g. a Cray EX
system with Slingshot, or a node of two 72-core Grace CPUs, and what one centre's policy says becomes what some
clusters do. Whether something is allowed at all, such as submitting a job from a compute node, or a tunnel out
of one, depends on how each centre has deployed it, so the guide says so, and how to check.

## Patterns, not packages

Where there is a pattern to learn, the guide spells it out with standard tools, `concurrent.futures`, `mpi4py`
and `srun`, so that the reader understands what a library would be doing for them, and can recognise it in any
library. That includes the parts that need care, such as how an exception in a task reaches your script, which is
where most hand-written versions go wrong. My own packages that implement such a pattern, e.g. map_parallel, are
mentioned once, as a complete example, rather than used: following a guide should not mean taking on a dependency.

## Examples are real files, and tests

Every example is a file under `src/examples/`, embedded in its page, so the page shows exactly what runs, and the
two cannot drift apart. Each example is also a test, which submits it with Slurm and checks its output. None of
them can run in CI, since CI has no cluster, so the suite is built to be easy to rerun by hand on any Slurm login
node, whenever there is one to hand.

One problem runs through the whole part on parallelism, a Monte Carlo estimate of π. Its answer is known, and its
pieces are independent, so every way of running it can be checked against the same line of output, and compared
by how long it takes. A different example on every page would allow neither.

## The voice

It is written in my voice, in the first person, as the blog is: hedged where it is my opinion ("I'd recommend"),
flat where it is a fact ("this is a big no-no"), and with the detail that would interrupt the argument in
footnotes. Not in the voice of a documentation site, and not in the aphoristic voice of a language model either:
no balanced antitheses, no punchlines, no rules of three.

A page is succinct, and on point: it says what the reader needs to get the thing done, and stops. The first
person is for a recommendation, not for thinking aloud: no "I think it is closest to…", weighing one tool
against another on a page that is about one of them. Nor does a page show how its claims were checked: the
source file and version a fact was read from, or a benchmark recounted to prove a point, is of no use to the
reader, who gets the fact, and a link where they would want to read on.

## No caveats about itself

The guide does not hedge about its own state on its pages: no "untested", no "this may not work on your system".
One banner, on every page, says that it is in alpha, and that is the caveat. A caveat on every page tells the
reader nothing about which page to trust, and makes every page harder to read. The real limitations of a tool,
e.g. that GNU parallel stays on one node, are content, and stay.

## Every claim checked

Every claim a page leans on is checked, against a source or by running it, and dropped if the sources contradict
it. A fact about a facility is checked in that facility's documentation before it is generalised. Sample output
is real output, never made up, and where it was measured somewhere other than a cluster, the page says where.
Nothing is attributed to me that I didn't say or do. Most readers cannot yet tell a right answer from a plausible
one, and will copy what the guide says, so it has to be right.

## Security is part of the teaching

An HPC is shared by thousands of users, and what runs under your account is traceable to you. So where a recipe
has a security cost, the page says who can see what, and whom you are trusting, as the part on working
interactively does for every method: plain HTTP on the cluster network, a self-signed certificate, SSH over
`srun`, and relays run by you, by Microsoft or by Cloudflare.

## Licence

The text is CC BY-SA 4.0: reuse it, with credit, and keep what you make from it as open. The code is BSD-3-Clause,
so that a reader can paste a job script into their own work. My earlier work that the guide reworks is relicensed
under the same two licences, and acknowledged once, at the end of the home page, rather than on every page it
touches.
