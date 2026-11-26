#!/usr/bin/env bash
# Stage many small files in, work on them on the node, and check that the
# results are staged out both when the work succeeds and when it fails half way.
source "$(dirname "$0")/../common/testlib.sh"

# 1000 small files, in/0000.txt ... in/0999.txt, each holding a number.
mkdir -p "$WORK/in"
for i in $(seq 0 999); do
    printf -v name '%04d' "$i"
    echo "$i" >"$WORK/in/$name.txt"
done
tar -cf "$WORK/good.tar" -C "$WORK" in
# The same, with a bad input half way.
echo "not a number" >"$WORK/in/0500.txt"
tar -cf "$WORK/bad.tar" -C "$WORK" in
export RESULTS="$WORK/results"

export INPUT="$WORK/good.tar"
batch job.sh
expect_output "^staged in 1000 files on "
expect_output "^staged out 1000 files to "
[[ "$(tar -xOf "$RESULTS/$JID.tar" out/0999.txt)" == 998001 ]] || fail "wrong result for 0999.txt"

# The job fails on the bad input, and what it did before that is still staged out.
export INPUT="$WORK/bad.tar"
(cd "$EXAMPLE_DIR" && timeout "$((QUEUE_TIMEOUT + 600))" sbatch --wait --parsable --output="$WORK/%j.out" job.sh) >"$WORK/bad.jid" &&
    fail "the job with a bad input succeeded"
JID="$(head -n1 "$WORK/bad.jid")"
JID="${JID%%;*}"
JOBS+=("$JID")
OUT="$WORK/$JID.out"
expect_output "ValueError"
expect_output "^staged out 500 files to "
