#!/usr/bin/env bash
# The sums in order change with the number of pieces, but not from one run to the next,
# and the exact sums are the same for every number of pieces, and the same as math.fsum.
source "$(dirname "$0")/../common/testlib.sh"

command -v python3 >/dev/null || skip "no python3 here"

batch job.sh
# The job runs the script twice; every line below is in the output of both runs.
count() { grep -cE "$1" "$OUT" || true; }
[[ $(count 'math\.fsum of the whole list: -792\.0369761826319$') -eq 2 ]] ||
    fail "math.fsum is not -792.0369761826319 in both runs ($OUT)"
for row in '1  -792\.0369761826661' '8  -792\.0369761826179' '64  -792\.0369761826325'; do
    [[ $(count "^ +$row .* -792\.0369761826319$") -eq 2 ]] ||
        fail "no row '$row ... -792.0369761826319' in both runs ($OUT)"
done
