# AGENTS.md

Instructions for writing this guide, for agents and people alike. Read [DESIGN.md](DESIGN.md) first: it is why the
guide is the way it is, and every rule here follows from it. [DEVELOPER.md](DEVELOPER.md) is how the site is built.

## Before you write

- Read the page before and the page after the one you are writing, and the pages they link to. The guide is read
  in order, so a page has to pick up where the last one left off.
- For the voice, and for how the guide teaches, read `src/interactive/30-services.md` and `40-https.md`, which
  are the template the rest follows.
- Grep for what the guide already covers, and link to it rather than repeat it.

## Writing a page

- **Shape.** One plain sentence picking up from the previous page; what the reader is trying to do; the recipe
  they may already know; why it bites; the fix, as commands or files, with each option explained after the
  block; its limitations; a closing sentence pointing to the next page.
- **Audience.** Assume little. Define each term once, where it first appears. Example first, then why.
- **Voice.** First person. Hedged opinions ("I think", "I'd recommend"), flat verdicts ("is simply not true"),
  explicit connectives (so, but, which is why), concrete numbers. Detail that interrupts goes in a footnote.
  Oxford -ize spelling with British vocabulary.
- **Never write** a balanced antithesis ("Nothing about X; it only does Y"), a short punchy sentence after a long
  one, "It's not X, it's Y", "not just X but Y", the rule of three, an em-dash reversal for rhythm, "Here's the
  thing", "In short", or an inspirational closing line. Prefer commas, colons, parentheses and footnotes to em
  dashes.
- **No caveats about the guide itself** ("untested", "may not work on your system", "work in progress"). The
  alpha banner is the only one. A tool's real limitation is content, and stays.
- **Lists** only for what the reader scans or checks themselves against: a checklist, a set of options. Otherwise
  prose.

## Generic, by concept

- **Never name a facility**, i.e. an HPC centre or system, anywhere: text, callouts, links, comments or example
  scripts, including the system the examples were tested on. Describe a system by its hardware and software ("a
  Cray EX system", "with Slingshot", "on one cluster I have used"). One centre's policy becomes what "some
  clusters" do. Whether something is allowed depends on how each centre deploys it: say so, and how to check.
- **No hard-coded paths or usernames.** Name storage by environment variable and by concept: `$HOME`, `$SCRATCH`,
  `$PROJECTDIR`, `$LOCALDIR`, each with a footnote at its first use on a page, saying that the name varies and
  what kind of storage to look for, and linking to `src/storage/10-where.md`. Otherwise use obvious placeholders
  (`/path/to/...`, `my-cluster`, `myproject`). Standard system paths such as `/tmp` are fine.
- Assume Slurm and Linux, and nothing else.

## Patterns, not packages

- Spell out a pattern with standard tools (`concurrent.futures`, `mpi4py`, `srun`), including how its errors
  surface: an executor raises a task's exception only when its result is retrieved, and a rank that fails leaves
  the others waiting unless the program runs under `python -m mpi4py` or `srun --kill-on-bad-exit=1`.
- The author's own packages are mentioned, not depended on. `map_parallel` is mentioned once, in
  `src/parallel/30-one-node.md`.
- Never link to the author's blog.

## Accuracy

- Check every claim against a source, or by running it. Drop what the sources contradict.
- No invented output, version numbers or dates. Use real output from a source or a run, and where a measurement
  was not made on a cluster, say where it was.
- Never attribute a habit, a preference or an experience to the author that a source does not state.
- Put the date in the prose for anything time-sensitive ("as of November 2026").
- Check a fact about a facility in that facility's documentation before generalising it.

## Examples

- A runnable example is a file under `src/examples/<name>/`, embedded with the `include` attribute, with a
  `test.sh` that follows the contract in DEVELOPER.md (exit 0 pass, 1 fail, 77 skip). No `.md` files in
  `src/examples/`, since they would be rendered as pages. Scripts that run on compute nodes stick to bash and
  the Python standard library where they can.
- Every page of the parallelism part solves Monte Carlo π, 64 tasks of 2^26 points, and every strategy ends with
  `pi = 3.141543 from 4294967296 samples`.
- The tests need a Slurm login node: `SBATCH_ACCOUNT=... SBATCH_PARTITION=... pixi run test-examples [NAME...]`.
  CI never runs them.

## Sources and credit

- The author's earlier work may be reused freely, content and wording. It is relicensed under the guide's
  licences without mentioning its original licence, and acknowledged once, at the end of `src/index.md`.
- Where a source was written by an agent rather than by the author, take its facts, never its wording.
- Other centres' documentation, e.g. NERSC's, is for reference only, never copied.
- Third-party code vendored here keeps its own licence, recorded in `REUSE.toml`.

## Repository

- `src/_quarto.yml`, `src/shared.scss`, `src/_extensions/copyright-year/`, `src/graph.md`,
  `src/_paragraphic.html` and `src/_mobile-toc.html` come from ickc/quarto-template: never edit them here. The
  site's own settings are in `src/_quarto-site.yml`, its styles in `src/custom.scss`.
- A part is a folder with an `index.md` (a `description`, a short intro, the listing) and `NN-name.md` pages. A
  new part goes into the sidebar in `src/_quarto-site.yml`, the home page listing, and `src/404.md`.
- Link to source files, not to `.html`. A page that moves gets `aliases:` with its old path.
- Run `pixi run format` before every commit, since CI checks it, and `pixi run build` to see the result.

## Pull requests

- Branch from `main`, one pull request per piece of work, with `Closes #N` for the issues it resolves, and no
  attribution lines.
- A pull request that adds or rewrites content gets a close review before it is merged: is it correct, does it
  teach well, is it in the voice, does it read on from the page before. Moving or refactoring needs only a check.
- Merge only when CI is green, checking the exit status of `gh pr checks` itself: a pipe after it hides a
  failure.
