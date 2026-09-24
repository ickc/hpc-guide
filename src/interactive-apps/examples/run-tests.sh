#!/usr/bin/env bash
# Run the examples' tests on a login node and summarise them.
#
#     ./run-tests.sh                  every example
#     ./run-tests.sh srun-ssh tls     only these
#
# The tests run in parallel, since most of their time is spent waiting in the
# queue. Pass Slurm options the usual way, e.g. SBATCH_ACCOUNT=... SBATCH_PARTITION=...
set -uo pipefail
cd "$(dirname "$0")" || exit

if (($#)); then names=("$@"); else names=(*/test.sh) && names=("${names[@]%/test.sh}"); fi

logs="$(mktemp -d)"
for name in "${names[@]}"; do
    bash "$name/test.sh" >"$logs/$name.log" 2>&1 &
    pids+=($!)
done

failed=0
for i in "${!names[@]}"; do
    wait "${pids[$i]}"
    case $? in
        0) result=PASS ;;
        77) result=SKIP ;;
        *) result=FAIL && failed=1 ;;
    esac
    printf '%-20s %s\n' "${names[$i]}" "$result"
    [[ $result == PASS ]] || sed 's/^/    /' "$logs/${names[$i]}.log"
done
rm -rf "$logs"
exit "$failed"
