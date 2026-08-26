---
title: "Introduction"
output-file: intro
---

## Introduction

Package managers for HPC has unique requirements:

- no `sudo` (implies you can't use the system provided package manager such as `dnf` or `apt`)
- as a corollary, must be installable to arbitrary PREFIX (TODO: explain PREFIX) as you can't write to `/home/linuxbrew/` for example.

There are also two kinds of package managers:

- those for missing system softwares that you depends but the sysadmin from the system might not be willing to install for you, e.g. ffmpeg
- those that boostrap an environment for your research project to run

Some can do both, some are specialized.

And there are different kinds on a different axis: built from source or prebuild binaries

## System package managers on HPC

Build from source:

- homebrew (can't use prebuilt as you can't write to `/home/linuxbrew`)
- srcpkg
- gentoo prefix

All these has various levels of success. Adapting it to HPC means you're pushing them beyond typical usecases they are designed for.
It requires some level of expertise to pull this off, and can often be time consuming to maintain.

Prebuilt:

- mise

Mise has an interesting model (TODO: expand intro), but as an end user, trust is more difficult to establish because there are many different layers between them (it is not a single package manager in a sense, who are you trusting even?)
And in some cases it is just providing a nicer UX.

E.g. if you run `mise use -g ubi:isambard-sc/clifton`, you are trusting multiple layers of maintainers sitting at different levels where compromising either one makes your system compromised. If you know that ultimately you are trusting GitHub Releases from `isambard-sc`, then running the following script directly eliminates unnecessary layers of trust and increase security overall (especially with a binary as sensitive as this one):

```sh
#!/usr/bin/env bash

set -euo pipefail

__OPT_ROOT="${__OPT_ROOT:-"${HOME}/.local"}"
BINDIR="${__OPT_ROOT}/bin"

# shellcheck disable=SC2312
read -r __OSTYPE __ARCH <<< "$(uname -sm)"

clifton_install() {
    case "${__OSTYPE}-${__ARCH}" in
        Darwin-arm64) filename="clifton-macos-aarch64" ;;
        Darwin-x86_64) filename="clifton-macos-x86_64" ;;
        Linux-x86_64) filename="clifton-linux-musl-x86_64" ;;
        Linux-aarch64) filename="clifton-linux-musl-aarch64" ;;
        *) exit 1 ;;
    esac
    url="https://github.com/isambard-sc/clifton/releases/latest/download/${filename}"

    mkdir -p "${BINDIR}"
    if command -v curl > /dev/null; then
        curl -fL "${url}" -o "${BINDIR}/clifton"
    elif command -v wget > /dev/null; then
        wget "${url}" -O "${BINDIR}/clifton"
    fi
    chmod +x "${BINDIR}/clifton"
}

clifton_uninstall() {
    rm -f "${BINDIR}/clifton"
}

case "${1:-}" in
    install)
        clifton_install
        ;;
    uninstall)
        clifton_uninstall
        ;;
    *)
        echo "Usage: __OPT_ROOT=... ${0} [install|uninstall]"
        exit 1
        ;;
esac
```

## Package Managers that does both

Prebuilt:

- [conda/mamba/micromamba/pixi](20-conda.md)

Built from source:

- [spack](40-spack.md)

## Where to put your new environments

HPC systems become increasingly heterogenious. If the HPC system you have access to have a network mounted `$HOME`
and the same `$HOME` is mounted on nodes with a different architecture say `x86_64` vs. `aarch64` or even different OS (Linux vs. FreeBSD)
then you are going to run into the following issue:

- put a binary somewhere, say `~/.local/bin/binary_here`, runs fine on one node
- SSH into another node and then run `binary_here` again: TODO: paste an example error here

The solution is: arch dependent prefix TODO
