---
title: "Command-line tools for yourself"
description: "Getting the everyday tools the system lacks, from a conda environment of tools, pixi global, or a direct download, and how many people you are trusting each time."
output-file: tools
---

The pages so far were about environments for a project. This one is about the other kind of package manager from [the introduction](10-intro.md): the one for software missing from the system that you want everywhere, regardless of project. A newer `git`, `ripgrep`, `ffmpeg`, `tmux`, `jq`, `gh`: tools you are used to on your laptop, which the cluster has an old version of, or doesn't have at all.

## A conda environment of tools

I have experimented with many ways of installing command-line tools in my home directory on Linux, from compiling them from source to Gentoo Prefix, and this is the best I have found. It uses the fact that conda is a cross-platform, language-agnostic package manager. A conda package does not have to be Python software, and conda-forge has most of the tools you are likely to want. Many of them are, in effect, a download that gets unpacked, but conda does it more conveniently, and more securely, than downloading and unpacking archives by hand.

Make an environment file, say `system.yml`, with the tools you want:

``` yaml
name: system
channels:
  - conda-forge
dependencies:
  - bat
  - fd-find
  - ffmpeg
  - fzf
  - gh
  - git
  - htop
  - jq
  - parallel
  - pixi
  - ripgrep
  - rsync
  - tmux
  - tree
  - zstd
```

and create it at a path under your architecture-dependent prefix, rather than by name:

``` bash
mamba env create -f system.yml -p "${__OPT_ROOT}/system"
```

Then don't activate it. Add its `bin` to the end of your `PATH`, in your `~/.bashrc`:

``` bash
export PATH="${PATH}:${__OPT_ROOT}/system/bin"
```

At the end, so that the system's own version of a tool, where there is one, comes first, and the environment only fills in what is missing. If you would rather have the newer version everywhere, put it at the front instead. Either way, it is always there, in every shell and every job, without activating anything, and it does not get in the way of the project environments you activate on top. To add a tool, add it to `system.yml` and run `mamba env update -f system.yml -p "${__OPT_ROOT}/system" --prune`, and on a new machine, the same file gets you the same tools.

## pixi global

If you use [pixi](40-pixi.md), `pixi global install` does the same, with each tool in its own environment:

``` bash
pixi global install ripgrep fd-find jq
```

The tools go in `$PIXI_HOME/bin`, which is already on your `PATH`, and since `PIXI_HOME` is under `$__OPT_ROOT`, they are per architecture too. One environment per tool means two tools can never conflict over a dependency, at the cost of more disk space. `pixi global list` shows what you have, and `pixi global edit` opens its manifest, so it is as reproducible as the environment file above.

## Package managers that build from source

There are also full package managers for a whole system that can be installed in your home directory and build everything from source there: Homebrew (which, as [the introduction](10-intro.md) explained, can't use its prebuilt packages because you can't write to `/home/linuxbrew`), pkgsrc, and Gentoo Prefix. All of these have various levels of success. Adapting them to an HPC means you are pushing them beyond the typical use cases they are designed for, and it requires some level of expertise to pull this off. Builds take hours, and a build that fails partway is yours to debug. It can often be time consuming to maintain. I'd only go this way if what you need is not on conda-forge.

## mise, and who you are trusting

[mise](https://mise.jdx.dev) has an interesting model. It is a manager of tool versions, and rather than packaging tools itself, it installs them through many *backends*: from its own registry, from [aqua](https://aquaproj.github.io)'s, from PyPI or npm or cargo, or straight from a project's GitHub Releases. It can pin the versions of tools per directory, with a `mise.toml`, and for many tools it is mostly providing a nicer UX over a download.

But as an end user, trust is more difficult to establish, because there are many different layers between you and the software. It is not a single package manager in a sense, so who are you trusting, even?

For example, if you run `mise use -g ubi:sigstore/cosign` ([cosign](https://github.com/sigstore/cosign) is a tool to sign and verify software, i.e. to tell you what else to trust), you are trusting the maintainers of mise, of its `ubi` backend, which downloads from GitHub Releases, and of everything they depend on, sitting at different levels, where compromising any one of them compromises your system. If you know that ultimately you are trusting the GitHub Releases from `sigstore`, then running the following script directly eliminates the unnecessary layers of trust and increases security overall, especially with a binary as sensitive as this one, whose whole job is to decide what else you trust:

``` bash
#!/usr/bin/env bash

set -euo pipefail

__OPT_ROOT="${__OPT_ROOT:-"${HOME}/.local"}"
BINDIR="${__OPT_ROOT}/bin"

# shellcheck disable=SC2312
read -r __OSTYPE __ARCH <<< "$(uname -sm)"

cosign_install() {
    case "${__OSTYPE}-${__ARCH}" in
        Darwin-arm64) filename="cosign-darwin-arm64" ;;
        Darwin-x86_64) filename="cosign-darwin-amd64" ;;
        Linux-x86_64) filename="cosign-linux-amd64" ;;
        Linux-aarch64) filename="cosign-linux-arm64" ;;
        *) exit 1 ;;
    esac
    url="https://github.com/sigstore/cosign/releases/latest/download/${filename}"

    mkdir -p "${BINDIR}"
    if command -v curl > /dev/null; then
        curl -fL "${url}" -o "${BINDIR}/cosign"
    elif command -v wget > /dev/null; then
        wget "${url}" -O "${BINDIR}/cosign"
    fi
    chmod +x "${BINDIR}/cosign"
}

cosign_uninstall() {
    rm -f "${BINDIR}/cosign"
}

case "${1:-}" in
    install)
        cosign_install
        ;;
    uninstall)
        cosign_uninstall
        ;;
    *)
        echo "Usage: __OPT_ROOT=... ${0} [install|uninstall]"
        exit 1
        ;;
esac
```

It works out the OS and architecture with the same `uname -sm` as [the introduction](10-intro.md), picks the matching file from the project's latest release, and puts it in `$__OPT_ROOT/bin`, which, with the `~/.bashrc` from the introduction, is the architecture-dependent one. Run it with `install` to install or update, and `uninstall` to remove it. The same pattern works for any tool that publishes a single binary per platform on its GitHub Releases.

A conda-forge package adds layers too, the package's maintainers and conda-forge's. But as [the page on conda](30-conda.md) explained, those maintainers build the package openly in CI, from a recipe anyone can read, so they are layers of defence. A layer that only passes a download along is one more party to trust, with nobody checking anything in between.

Some software is more than one binary, or more than a conda environment can hold: a whole operating system's worth of libraries, or something only published as a Docker image. That is what the next page, on containers, is for.
