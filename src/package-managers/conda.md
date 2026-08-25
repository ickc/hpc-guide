# Why conda

Conda solves a unique packaging issue (TODO: quote Guido)
in the Python ecosystem and has grown into a language agnostic,
multi-platform package manager. (TODO: what this means)

# Why mamba

mamba is a(n almost) drop-in replacement of conda.
TODO: fast
TODO: Anaconda licensing situation and why using mamba with conda-forge is a clean cut.

# Why micromamba

Single static binary, in most situations can replace mamba,
but often is used by people building CI. (People are too
used to having a base Python environment in conda even if
they are not using full anaconda distribution anymore.)

# Why pixi

Project centric design (tie to a git repo rather than a central one
that you need to remember which project you're associating with, encouraging project level reproducibility),
environment bootstrap, and task runner
all-in-one.

# How to load the environment

TODO: expand and explain

```sh
# best portability (miniforge3/conda/anaconda)
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate ...
# tool specific (has other choices of shell as well)
eval "$(conda shell.bash hook)"
eval "$(mamba shell hook -s bash)"
eval "$(micromamba shell hook -s bash)"
eval "$(pixi shell-hook -s bash)"
```

# Tips

When resolving a conda environment, on exotic platforms where login nodes
and compute nodes has fundamental differences (such as existence of GPU/CUDA, even CPU microarch(? TODO: double check)), it is better to resolve
the conda environment using the hardware that your job will run on (i.e.
compute node) because it would resolves differently depending on these factors TODO

However, when login node and compute node doesn't have these differences, it is a better practice to
load the environment from login node first before submitting jobs (to minimize overhead for massively parallel applications),
introduce heredoc (TODO) as a pattern to encapsulate this while being performant.
