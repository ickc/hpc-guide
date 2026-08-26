#!/usr/bin/env bash
# Check that every numbered page declares a permalink matching its name.
#
# Files are named NN-name.md so the numeric prefix controls sidebar and listing
# order. The prefix would otherwise leak into the URL, so each page repeats its
# name as `output-file: name.html`, which keeps permalinks stable when pages are
# renumbered. This checks the two never drift apart.

set -euo pipefail

SRC="${1:-src}"
status=0

while IFS= read -r page; do
    base=$(basename "${page}" .md)
    expected="${base#*-}.html"
    actual=$(sed -n '/^---$/,/^---$/{s/^output-file:[[:space:]]*//p;}' "${page}" | head -n1)

    if [[ -z ${actual} ]]; then
        echo "${page}: missing 'output-file: ${expected}' in front matter" >&2
        status=1
    elif [[ ${actual} != "${expected}" ]]; then
        echo "${page}: output-file is '${actual}', expected '${expected}'" >&2
        status=1
    fi
done < <(find "${SRC}" -name '[0-9][0-9]-*.md' | sort)

# Every content page is either a section index or a numbered page; anything
# else would sort unpredictably in the sidebar and listings.
while IFS= read -r page; do
    echo "${page}: expected 'index.md' or an 'NN-name.md' numbered page" >&2
    status=1
done < <(find "${SRC}" -name '*.md' -not -name 'index.md' -not -name '[0-9][0-9]-*.md' | sort)

if ((status == 0)); then
    echo "All numbered pages declare a matching permalink."
fi
exit "${status}"
