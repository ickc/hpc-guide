#!/usr/bin/env bash
# Report rendered pages that nothing links to.
#
# A page counts as reachable if any other rendered page links to it — the
# sidebar covers most of them, body links cover the rest. index.html is the
# entry point and is always considered reachable.

set -euo pipefail

DOCS="${1:-src/docs}"

if [[ ! -d ${DOCS} ]]; then
    echo "error: ${DOCS} does not exist — run 'pixi run build' first" >&2
    exit 2
fi

all_pages=$(mktemp)
linked=$(mktemp)
trap 'rm -f "${all_pages}" "${linked}"' EXIT

find "${DOCS}" -name '*.html' -not -path "*/site_libs/*" -printf '%P\n' | sort > "${all_pages}"

# Resolve every local href against the page that contains it, so ./foo.html
# and ../bar/foo.html both normalise to a path relative to the site root.
while IFS= read -r page; do
    grep -o 'href="[^"#?]*\.html[^"]*"' "${DOCS}/${page}" |
        sed 's/^href="//; s/[#?].*$//; s/"$//' |
        while IFS= read -r href; do
            [[ -z ${href} || ${href} == http* || ${href} == //* ]] && continue
            realpath -m --relative-to="${DOCS}" "${DOCS}/$(dirname "${page}")/${href}"
        done
done < "${all_pages}" | sort -u > "${linked}"

orphans=$(comm -23 "${all_pages}" "${linked}" | grep -v '^index\.html$' || true)

if [[ -n ${orphans} ]]; then
    echo "Orphaned pages (rendered but not linked from anywhere):" >&2
    echo "${orphans}" | sed 's/^/  /' >&2
    exit 1
fi

echo "All $(wc -l < "${all_pages}") rendered pages are reachable."
