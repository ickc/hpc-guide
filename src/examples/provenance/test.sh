#!/usr/bin/env bash
# Install the pixi example's environment on the login node, then run the job, and
# check that its output starts with a record of what it ran on, this job included.
source "$(dirname "$0")/../common/testlib.sh"

command -v pixi >/dev/null || skip "no pixi here: install it first"
command -v git >/dev/null || skip "no git here"

log "installing the environment"
(cd "$EXAMPLE_DIR/../pixi-job" && pixi install --locked) >"$WORK/install.log" 2>&1 ||
    fail "could not install the environment; see $WORK/install.log"

batch job.sh
lock="$(sha256sum "$EXAMPLE_DIR/../pixi-job/pixi.lock" | cut -d ' ' -f 1)"
expect_output '^== provenance, [0-9]{4}-[0-9]{2}-[0-9]{2}T'
expect_output "^commit    $(git -C "$EXAMPLE_DIR" rev-parse HEAD)(, with uncommitted changes)?\$"
expect_output "^lockfile  $lock  pixi\\.lock\$"
expect_output '^kernel    Linux [^ ]+ [^ ]+$'
expect_output '^cpu       [^ ]'
expect_output "^job       $JID, on [^ ]+\$"
expect_output '^threads   OMP_NUM_THREADS=1$'
expect_output '^pi is about 3\.14[0-9]*, from numpy '
