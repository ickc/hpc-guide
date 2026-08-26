#!/usr/bin/env bash
# Check (or fix, with --fix) page naming and permalink front matter.
#
# Files are named NN-name.md so the numeric prefix controls sidebar and listing
# order. The prefix would otherwise leak into the URL, so each page declares
# `output-file: name`, which keeps permalinks stable when pages are renumbered.
#
# The extension is deliberately omitted: Quarto appends the one belonging to
# each output format, so a page renders to name.html and name.pdf rather than
# name.html.pdf. Quarto resolves the output path before any filter runs, so
# this cannot be derived by a Lua filter — hence --fix.

set -euo pipefail

fix=0
[[ ${1:-} == --fix ]] && { fix=1; shift; }
SRC="${1:-src}"
status=0

while IFS= read -r page; do
    base=$(basename "${page}" .md)
    expected="${base#*-}"
    actual=$(sed -n '/^---$/,/^---$/{s/^output-file:[[:space:]]*//p;}' "${page}" | head -n1)

    if [[ ${actual} == "${expected}" ]]; then
        continue
    fi

    if ((fix)); then
        if [[ -n ${actual} ]]; then
            sed -i "0,/^output-file:.*$/s//output-file: ${expected}/" "${page}"
        else
            sed -i "0,/^title:.*$/s//&\noutput-file: ${expected}/" "${page}"
        fi
        echo "${page}: set output-file: ${expected}"
    elif [[ -z ${actual} ]]; then
        echo "${page}: missing 'output-file: ${expected}' in front matter" >&2
        status=1
    else
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

if ((status == 0 && fix == 0)); then
    echo "All numbered pages declare a matching permalink."
fi
exit "${status}"
