---
title: "Archiving a result"
output-file: archiving
description: "Keeping every input of a result where it can still be found when you publish it: a manifest of hashes for the data, the code at a tag, the lockfiles and the packages they name, the container image and the jobs' records; a DOI from Zenodo and the source in Software Heritage, each with a hash beside it; and a checklist for your own project, drawn from the whole of this part."
---

Each page of this part captured some of the inputs of a result: the seeds and the order of the arithmetic inside your program, the environment it runs with, the machine it ran on, and the steps of its workflow. This last page is about keeping them, when you publish the result, so that a referee, a reader, or you, years later, can still find every one of them.

## The recipe

The recipe in most papers is a sentence or two: the code is on GitHub, and the data is available on request. Both are names, and like the names in an `environment.yml`, what they point to can change, or disappear. A repository can be renamed, made private or deleted, and a branch moves with every push. Whole forges have shut down, Gitorious, Google Code and CodePlex among them. Data on request depends on someone still having it, and on a cluster, the places it is most likely to be are scratch, which is purged, and the project directory, which is [often deleted some time after the project ends](../storage/10-where.md#project-projectdir). And a lockfile, as [Freezing an environment](30-environment.md#limitations) said, pins what would be downloaded, not that it can still be downloaded.

So when you publish, put every input in an archive that undertakes to keep it, and give each a hash, which identifies it wherever a copy turns up.

## The data

A manifest is a file with a line for each file of the data, its SHA-256 and its path:

``` bash
find data -type f -exec sha256sum {} + | sort -k 2 > data.sha256
```

`find ... -exec sha256sum {} +` hashes every file under `data`, and `sort -k 2` sorts the lines by path, so that two manifests of the same data are the same file. To check a copy of the data against it, from the directory that holds `data`,

``` bash
sha256sum -c --quiet data.sha256
```

prints nothing when every file matches, and otherwise each file that does not, or is missing, and exits with an error. It checks only the files in the manifest, so it does not notice one added since. Hashing reads every byte, so for terabytes, run it in a job. The manifest itself is small, and goes into the git repository with the code. For data that changes as you work, [DVC](https://dvc.org) and [DataLad](https://www.datalad.org) keep hashes like these for you, alongside git.

## The code and its environment

Tag the commit the results came from, and push the tag:

``` bash
git tag -a v1.0 -m "The code for the paper, as submitted"
git push origin v1.0
```

A tag is a name too, and `git tag -f` moves it, so give the commit's hash in the paper as well, the one at the top of every job's record from [the page on the machine](40-machine.md#record-it-in-every-job).

The lockfiles are committed with the code, and so is the definition file of any container, with the digest of the image you ran, as in [Freezing an environment](30-environment.md#a-container-is-not-frozen-either). What a lockfile does not hold is the packages themselves, which stay on the channel for as long as it serves them. So for a result you expect to be asked about, archive the environment that ran too: the `.sif` file of the image, or a conda environment packed with conda-pack, as on [the page on shipping an environment](../software/50-shipping.md#any-prefix-with-conda-pack). Either is for one platform, and large, but it is the bytes that ran, where the lockfile has only their names. Archive the outputs of the jobs that made the numbers in the paper as well, each with the record it starts with.

## Zenodo and Software Heritage

[Zenodo](https://zenodo.org) is an archive run by CERN and open to anyone, which gives each record a DOI. It is also connected to GitHub: [switch on a public repository](https://docs.github.com/en/repositories/archiving-a-github-repository/referencing-and-citing-content) in Zenodo's GitHub settings, and Zenodo archives it, with a new DOI, each time you make a release on GitHub. Each version has a DOI of its own, and a *concept DOI* stands for all of them, resolving to the latest. [Cite the version's](https://zenodo.org/help/versioning), since that is the one that does not change. The data, the image and the jobs' outputs go into a record too. As of November 2026, a record can hold 50 GB, and more can be requested; data larger than that goes to your field's repository, or your institution's, with its manifest in the code either way.

[Software Heritage](https://archive.softwareheritage.org) archives source code, with its whole history. [Save Code Now](https://archive.softwareheritage.org/browse/origin/save/) asks it to archive your repository, from its URL, with no account. Its identifier for a commit is the commit's hash with `swh:1:rev:` in front, so the hash in the paper finds the code there, even once the repository it came from is gone.

A DOI is a name, which resolves to wherever Zenodo says the record is. Zenodo's [policy](https://about.zenodo.org/policies) is to keep a record for the lifetime of the repository, with best efforts to move everything elsewhere if it ever closes, and a record can be withdrawn, which leaves a page saying why. So give the hashes next to the DOI: the commit, and the SHA-256 of each file you archived, with the hash of the manifest standing for the data, so that a copy found anywhere, on Zenodo, in Software Heritage or on a colleague's disk, can be checked against what the paper says.

## Limitations

What the jobs ran on is in their records, and nowhere else in the archive, which is why a rerun on another machine is checked against the tolerance you declared, rather than bit for bit. And an image or a packed environment runs on its own platform only, so for another, it is the recipe and the lockfile that make the environment again.

## The checklist

Before you publish, check your project against this list:

- [ ] The claim says what is held fixed, what may vary, and which equivalence a rerun has to meet ([what reproducible means](10-intro.md)).
- [ ] Every random number comes from a generator whose seed is an input, recorded with the results ([seeds, and the order of a sum](20-determinism.md)).
- [ ] Every parallel sum adds integers, is exact, or combines its pieces in a fixed order, and the number of threads and ranks is set by the job ([seeds, and the order of a sum](20-determinism.md#the-fixes-cheapest-first)).
- [ ] The environment is installed from a lockfile, one for each platform, made by solving the recipe, rather than by exporting an environment changed by hand ([freezing an environment](30-environment.md)).
- [ ] A container is pulled by its digest, and its definition file and `.sif` are kept ([freezing an environment](30-environment.md#a-container-is-not-frozen-either)).
- [ ] The variants a result depends on, such as the BLAS and the MPI, are chosen in the recipe ([recording the machine](40-machine.md#choose-variants-in-the-recipe)).
- [ ] Every job records what it ran on at the top of its output ([recording the machine](40-machine.md#record-it-in-every-job)).
- [ ] Every step of a pipeline has an environment of its own, pinned in the same way.
- [ ] The data has a manifest of SHA-256 hashes, and `sha256sum -c` passes on the copy you archive.
- [ ] The code is at a tag, and the paper gives the commit's hash.
- [ ] The code, the lockfiles, the definition files, the manifests, the jobs' outputs and the image are archived, with a version DOI, and the source is in Software Heritage.
- [ ] Someone has rerun it from the archive alone, in a fresh clone, with an environment made from its lockfile, and the result meets the equivalence you declared.

That is the end of this part, and of this guide.
