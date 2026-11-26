#!/usr/bin/env bash
# Install the environment from the lockfile on the login node, then run the job.
source "$(dirname "$0")/../common/testlib.sh"

command -v pixi >/dev/null || skip "no pixi here: install it first"

log "installing the environment"
(cd "$EXAMPLE_DIR" && pixi install --locked) >"$WORK/install.log" 2>&1 ||
    fail "could not install the environment; see $WORK/install.log"

batch job.sh
[[ "$(grep -Ec '^pi is about 3\.14[0-9]*, from numpy ' "$OUT")" -eq 2 ]] ||
    fail "expected two estimates of pi in $OUT"
