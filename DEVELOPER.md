# Developing this site

The site is a [Quarto](https://quarto.org) website built from `src/`, with
[pixi](https://pixi.sh) providing the toolchain. Everything below runs through
pixi tasks, so `pixi install` is the only setup step.

| Task | What it does |
| --- | --- |
| `pixi run build` | render the site into `src/docs` |
| `pixi run serve` | live preview on `$QUARTO_PORT` (8018) |
| `pixi run format` | normalise markdown and derive permalinks |
| `pixi run format-check` | fail if anything is unformatted — this is what CI runs |
| `pixi run linkcheck` | check the rendered site's links with lychee |
| `pixi run clean` | remove generated files |

## How pages are laid out

Every folder under `src/` is a section, and every section looks the same:

```
src/running-jobs/
  index.md                      section intro + a listing of the folder
  10-workflow.md                content
  20-embarassingly-parallel.md  content
  30-oversubscription.md        content
```

There are exactly two kinds of file, and `pixi run format-check` rejects
anything else:

- **`index.md`** — a short intro plus a `listing` that enumerates the folder. It
  holds no content of its own; a section with only one page still gets an
  `index.md` and a separate `10-intro.md`, so no folder is a special case.
- **`NN-name.md`** — a content page. The two-digit prefix sets the order.

### Adding a page

Drop in a new `NN-name.md` with a `title`, then run `pixi run format`. Nothing
else needs editing: the sidebar picks it up through an `auto` glob in
`src/_quarto.yml`, and the section's `index.md` listing picks it up through its
own glob. Leave gaps in the numbering (10, 20, 30) so pages can be inserted
without renumbering.

`src/_quarto.yml` only names the sections and their order. It never lists
individual pages.

## The permalink contract

The `NN-` prefix orders the sidebar and listings, but it must not reach the URL
— otherwise reordering a page would break every link to it. So each content
page declares the name it renders to:

```yaml
---
title: "Workflow managers"
output-file: workflow
---
```

`src/running-jobs/10-workflow.md` then renders to `running-jobs/workflow.html`.
Renumbering the file changes nothing that anyone can link to.

Two details matter:

- **The extension is omitted.** Quarto appends the one belonging to each output
  format. With `output-file: workflow.html`, adding a PDF format would render
  `workflow.html.pdf`.
- **You do not write this by hand.** `pixi run format` derives it from the
  filename. It cannot be a Quarto filter: Quarto resolves output paths before
  any filter runs, so the value has to be in the source before the render
  starts.

## Linking between pages

Link to the **source** file, not the rendered one:

```markdown
be careful about [oversubscription](30-oversubscription.md)
```

Quarto resolves that to the target's output path — honouring `output-file` — and
rewrites it with the right relative depth. Linking to `oversubscription.html`
directly would bypass that and break when a page moves.

## The formatter

`bin/md_formatter.py` normalises each file's body by round-tripping it through
pandoc, and derives `output-file` from the filename under
`--derive-output-file`. It is generic: it takes files, directories, or globs,
and forwards filters to pandoc with `-F`.

### Pandoc is not a formatter

Pandoc is a converter, and using it as a markdown formatter is an abuse of it.
It is a routine and useful abuse, but only if you know the limitations going in:

- **It escapes aggressively on round trip.** A bare `$` comes back as `\$`, a
  bare `>` as `\>`, bracketed text as `\[like this\]`. This is simply what
  pandoc does, not a diagnosis of the source.
- **Formatting detail is barely configurable.** Fenced code is written as
  ``` ``` sh ``` with a space; a non-breaking space is inserted after an
  abbreviation, so `i.e. x` becomes `i.e.\u00a0x` and is invisible in an editor.
  Neither is adjustable.

The lack of knobs is the point, in the same way it is the point in Black: there
is one canonical form, so nobody argues about style in review. Take the whole
package or use something else.

### Reading the escapes

An escape is not by itself a sign that anything is wrong — see above, pandoc
escapes whether or not it needs to. It is worth a case-by-case look, though, and
the question to ask is whether the plain text is carrying structure that the
document could carry properly instead. Where it is, create the structure:

- `[TIPS]` was a literal marker standing in for an admonition. It is now a
  `::: {.callout-tip}` block, which Quarto renders as a real Tip.
- `$HOME` in prose was a shell variable written as words. It is now a code span.

Where the answer is no, leave the escape alone. It renders identically.

### Front matter

YAML front matter is deliberately kept away from pandoc. Pandoc parses metadata
values as markdown and re-escapes them on the way out, so a listing's
`contents: "*.md"` comes back as `contents: \*.md`. Here the escape does break
things, because Quarto parses front matter with its own YAML parser rather than
through pandoc, and so reads the backslash literally. `quarto inspect` reports
`"contents": "\\*.md"`, the glob matches nothing, and the section listing
renders empty with no error. Pandoc also sorts metadata keys and drops quoting.

So only the body round-trips; the front matter is copied through untouched apart
from `output-file`.

Formatting is expected to change nothing about the rendered site.
