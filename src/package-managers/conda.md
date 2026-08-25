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
