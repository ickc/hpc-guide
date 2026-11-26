#!/usr/bin/env bash
# With 2G the job reports its peak memory, about 1 GiB; with 256M it is killed for running out of memory.
source "$(dirname "$0")/../common/testlib.sh"

[[ -x /usr/bin/time ]] || skip "no /usr/bin/time here"
command -v python3 >/dev/null || skip "no python3 here"

batch job.sh
expect_output '^held 1024 MiB, busy for 60 s$'
rss="$(sed -nE 's/^\s*Maximum resident set size \(kbytes\): ([0-9]+)$/\1/p' "$OUT")"
[[ -n $rss ]] || fail "no maximum resident set size in $OUT"
((rss >= 1024 * 1024)) || fail "a peak of $rss kB is less than the 1 GiB the job held"

# The same job with too little memory: sbatch --wait exits non-zero when the job fails.
JID="$(cd "$EXAMPLE_DIR" && timeout "$((QUEUE_TIMEOUT + 600))" sbatch --wait --parsable --mem=256M --output="$WORK/%j.out" job.sh)" &&
    fail "the job with 256M of memory did not fail"
JID="${JID%%;*}"
JOBS+=("$JID")
OUT="$WORK/$JID.out"
grep -q '^held ' "$OUT" && fail "the job with 256M of memory got to the end ($OUT)"
oom() { [[ $(sacct -j "$JID" -X -n -o State | tr -d ' ') == OUT_OF_ME* ]]; }
retry 60 oom || fail "job $JID did not end as OUT_OF_MEMORY: $(sacct -j "$JID" -X -n -o State)"
