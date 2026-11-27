---
title: "What reproducible means"
description: "What a claim that an analysis is reproducible says: what is held fixed, what may vary, and when two results count as the same; the five Rs, from re-runnable to replicable; a real pipeline checked by a looser rule than identical bytes; and a map of the inputs the rest of this part captures."
output-file: intro
---

The rest of this guide was about getting an analysis to run on a cluster. This part is about getting it to run again: for a referee who asks for one more figure, for a colleague who takes the project over, or for you, a year later.

Say you rerun it, and a number in your results table has changed in its sixth digit. Or the job does not run at all, because a module it loads is gone. Was the analysis reproducible? That depends on what you claimed when you said it was.

## What a claim of reproducible says

Any claim that a result is reproducible says three things, whether or not it says them out loud: what is held fixed, what is allowed to vary, and what counts as the same result. Rerunning a job on the same cluster with the same data holds nearly everything fixed and lets only the time vary. Rerunning it on another cluster lets the machine vary too, and handing the paper to another group, who write their own code, lets almost everything vary but the method.

The third of these is an *equivalence relation*: a rule that says when two results count as the same.[^1] The strictest is bit-identical, every byte of the output the same. Looser ones are the same within a tolerance, e.g. agreeing to 10 significant digits; the same distribution, for a stochastic simulation rerun with other seeds; and the same conclusion, for a study repeated by someone else. None of them is right in general, so you choose the one that fits what you are claiming, and say which. A change in the sixth digit fails bit-identical, and passes a tolerance only if the tolerance is looser than that.

## The five Rs

Benureau and Rougier, in [a paper on what it takes to turn code into a scientific contribution](https://doi.org/10.3389/fninf.2017.00069), set out five things a program should be, from re-runnable to replicable, and each is an answer to the same three questions:[^2]

|  | Held fixed | Varies | Counts as the same | In this part |
|------------------------|------------------------|------------------------|------------------------|------------------------|
| Re-runnable | the code, and a description of an environment it runs in | the system and libraries around it, as time passes | it runs again | [the environment](30-environment.md), [the archive](60-archiving.md) |
| Repeatable | the code, its inputs and its seeds, on the same machine | nothing but the run | the same output, run after run | [seeds and the order of a sum](20-determinism.md) |
| Reproducible | the code, the data, the parameters and the exact environment | who runs it, and on which computer | the same result | the environment, [the machine](40-machine.md), workflows, the archive |
| Reusable | --- | what the code is used for, and the code itself | others can run it, understand it and change it | beyond this part |
| Replicable | the method, as the paper describes it | the code, written anew | the same result | beyond this part |

The first three build on each other: a program that does not run cannot repeat, and one that does not give the same output twice on your machine will not give it on someone else's. This part is about those three, with the third, on a cluster, as the goal. Reusable is about the code being fit for others to build on, and replicable about someone checking your method with code of their own, and both are beyond what this part covers.

## A looser rule, on a real pipeline

Bit-identical is not always the right rule, and sometimes it is not available at all. [nf-core/bacass](https://nf-co.re/bacass), a pipeline that assembles bacterial genomes, is tested by running it on a small dataset and comparing the MD5 checksums of its outputs, the assemblies among them, with those recorded in its repository, and its CI runs those tests on `x86_64`. Run it on an Arm (`aarch64`) cluster, with every tool built for Arm, and the programs doing the work are different binaries, compiled from the same source, which nothing promises will write the same bytes. So a run there is checked by its structure instead: every output of the assembly is there, and the number of contigs and the total length of each assembly are close to what they should be for that genome. That is a looser equivalence than the checksums, and it is the one that fits the claim that run makes, that the pipeline assembles the genome on that machine.

## Capture every input

So reproducibility is always about making sure you capture every stateful aspect as an input, and claiming an equivalence relation between any outputs that are not byte-identical. Byte-identical output is sometimes achievable, but that is not what defines reproducibility in practice.

A *stateful aspect* is anything the result depends on that nobody wrote down as an input: the seed of a random number generator, the order in which a parallel sum was added up, the version of every library, the CPU it ran on. An input you did not capture still changes the result, only without anything recording that it changed. So the work is to find each of them, and to fix it where you can, and record it where you cannot.

## This part

Each page of this part captures one kind of input. [The next page](20-determinism.md) is about the ones inside your own code: seeds, and the order in which a parallel program adds up its results, which decides whether its output is the same to the last bit. [Freezing an environment](30-environment.md) is about the software it runs on, from an `environment.yml` that says `numpy` to a lockfile that names every package by its hash. [The page after it](40-machine.md) is about the machine, the part of the environment that belongs to the centre, its modules, MPI, GPU driver, kernel and CPU, which you cannot lock, and so record in every job. Then a section on workflows, pipelines of many steps, each with its inputs and an environment of its own. [The last page](60-archiving.md) is about archiving a result, so that its inputs can still be found when someone asks for them, and ends with a checklist for your own project.

The parts before this one already did some of this. [Software environments](../software/10-intro.md) built environments from files, and every page of [Parallelism](../parallel/10-intro.md) printed the same estimate of π, to the last digit, whatever ran it, for reasons the next page goes into.

[^1]: Strictly, a tolerance is not an equivalence relation: one result can be within it of a second, and the second of a third, without the first being within it of the third. So compare every rerun with one reference result, rather than each with the one before.

[^2]: The words are not used the same way everywhere. Claerbout's *reproducible*, the same code rerun on the same data, was the ACM's *replicable*, until the ACM swapped its two terms in 2020, and Goodman and colleagues have a third scheme, of methods, results and inferential reproducibility. [Plesser (2018)](https://doi.org/10.3389/fninf.2017.00076) traces how the confusion came about. This part uses Benureau and Rougier's.
