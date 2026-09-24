#!/usr/bin/env bash
# Get a shell on a compute node in each of the three ways the page describes.
source "$(dirname "$0")/../common/testlib.sh"

# --pty wants a terminal; script(1) provides one without a human at the keyboard.
command -v script >/dev/null || skip "script(1) is needed to fake a terminal"
LOGIN="$(hostname)"

# on_compute COMMAND: run it in a pseudo-terminal and check it ran on a compute node.
on_compute() {
    local out
    out="$(timeout "$QUEUE_TIMEOUT" script -qec "$1" /dev/null | tr -d '\r')" || fail "$1"
    grep -q '^/dev/pts/' <<<"$out" || fail "no terminal in: $1"
    grep -qvx -e "$LOGIN" -e '/dev/pts/.*' <<<"$out" || fail "still on $LOGIN: $1"
    log "ok: $1"
}

on_compute "srun --nodes=1 --ntasks=1 --pty bash -c 'hostname; tty'"
on_compute "salloc --nodes=1 --ntasks=1 srun --pty bash -c 'hostname; tty'"

submit hold.sh
wait_running "$JID"
on_compute "srun --jobid=$JID --overlap --pty bash -c 'hostname; tty'"
