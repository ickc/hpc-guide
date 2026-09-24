#!/bin/bash
# Once, on the login node:
#     ./setup.sh
# Downloads the devtunnel program and signs you in with a GitHub account, by
# showing a code to enter at a URL in any browser. The login is kept in your
# home directory, so jobs on the compute nodes can use it.
#
# DEVTUNNEL sets where to put the program (default ~/.local/bin/devtunnel).
# Add -m to the login line below to sign in with a Microsoft account instead.
set -euo pipefail
DEVTUNNEL="${DEVTUNNEL:-$HOME/.local/bin/devtunnel}"

case "$(uname -m)" in
    x86_64) platform=linux-x64 ;;
    aarch64) platform=linux-arm64 ;;
    *) echo "no devtunnel build for $(uname -m)" >&2 && exit 1 ;;
esac
if [[ ! -x $DEVTUNNEL ]]; then
    mkdir -p "$(dirname "$DEVTUNNEL")"
    curl -fsSL "https://aka.ms/TunnelsCliDownload/$platform" -o "$DEVTUNNEL"
    chmod +x "$DEVTUNNEL"
fi
"$DEVTUNNEL" user login -g -d
"$DEVTUNNEL" user show
