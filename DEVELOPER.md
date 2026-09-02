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

## Deployment

The site is served by [Cloudflare Pages](https://pages.cloudflare.com) at
<https://hpc.kolen.dev>. It is not a GitHub Pages site, so nothing here needs a
`.nojekyll` marker or a `docs/` directory committed to the repository — the
rendered output stays untracked and is uploaded straight to Cloudflare.

`.github/workflows/ci.yml` does the whole thing on a push to `main`:

1. **lint** — `pixi run format-check`.
2. **build** — `pixi run build`, then `pixi run linkcheck-except-429`, then
   uploads `src/docs` as an artifact.
3. **deploy** — downloads that artifact and hands it to
   `wrangler pages deploy --project-name=hpc-kolen-dev`.

The build runs once and the deploy is gated on both checks, so a formatting or
link failure stops the publish. Pull requests run steps 1 and 2 only.

That link check runs against the freshly built `src/docs` on disk, never
against the deployed site, which is why `lychee.toml` drops `sitemap.xml` and
`robots.txt` from the crawl: they contain only absolute self-references, so
fetching them would report on whatever is already live rather than on the
output about to be published. For the same reason the linkcheck tasks pass
`--root-dir`: the not-found page links from the site root rather than
relatively (see below), and without a root directory lychee cannot resolve a
`/`-prefixed link against a local file. It has to be an absolute path, so it
lives in the pixi task rather than in `lychee.toml`.

The credentials — `CLOUDFLARE_API_TOKEN` (scoped to *Cloudflare Pages: Edit*)
and `CLOUDFLARE_ACCOUNT_ID` — live in the repository's `production`
**environment**, not in its repository secrets. That is why the deploy job
declares `environment: production`: a job that does not name the environment
cannot read them, and `secrets.CLOUDFLARE_API_TOKEN` silently expands to the
empty string rather than failing outright.

## Fonts

`src/custom.scss` names the families, `src/_quarto.yml` links the stylesheet
that declares them, and [font.kolen.dev](https://font.kolen.dev) serves both
that stylesheet and the faces behind it:

```scss
// src/custom.scss
$font-family-base: 'TeX Gyre Schola', Georgia, 'Times New Roman', serif;
$font-family-monospace: 'JetBrains Mono', SFMono-Regular, Menlo, ..., monospace;
```

```html
<!-- src/_quarto.yml, under format.html.include-in-header -->
<link rel="preconnect" href="https://font.kolen.dev">
<link rel="preconnect" href="https://font.kolen.dev" crossorigin>
<link rel="stylesheet" href="https://font.kolen.dev/assets/faces.css">
```

That site is [ickc/font](https://github.com/ickc/font), the same author's
multilingual font pattern, deployed to Cloudflare Pages, and it publishes those
stylesheets as a [documented
distribution](https://font.kolen.dev/#using-these-fonts-on-another-site) rather
than only as a demo of one. Two properties of the deployment are what make it
usable from here: Pages answers with `access-control-allow-origin: *`, which a
cross-origin font fetch requires, and the `url()` references inside the
stylesheet are relative, so the `.woff2` files follow from that origin without
anything being copied into this repository.

**`faces.css`, not `fonts.css`.** The two differ in what they assert.
`faces.css` is the `@font-face` declarations and nothing else. `fonts.css` is
that file plus the rules that make *font.kolen.dev itself* use them — families
on `body`, `code` and `:lang()` — plus an `@import` of Google Fonts' Noto Sans
TC. This site has already decided what its elements are set in, through the
Bootstrap variables above, and renders no Traditional Chinese, so `fonts.css`
would only add a third-origin stylesheet request per page load and a cascade to
argue with.

**From the head, not from `custom.scss`.** An `@import` in the SCSS ends up
inside the compiled theme bundle, so a browser cannot discover the faces until
it has downloaded and parsed that bundle, and cannot start the `.woff2` files
until it has parsed the stylesheet that arrives after it. A `<link>` in the
head is found by the preload scanner during the initial parse instead, so the
stylesheet is fetched alongside the theme bundle rather than behind it.

**Both `preconnect` lines**, and not because the origin is written twice by
mistake. A font fetch is anonymous-mode CORS and gets a connection pool of its
own, so the `crossorigin` line is the one that warms the font requests; the
stylesheet request is credentialed, uses the other pool, and happens first.
Either line alone leaves half the connection cost in place. This is the
two-line form Google Fonts publishes, for the same reason.

Setting the families through the SCSS variables rather than in a `body` rule is
what makes the navbar, sidebar, headings, buttons and the syntax highlighter
come out in the same font: Bootstrap builds all of them from
`--bs-body-font-family` and `--bs-font-monospace`.

**`$web-font-path: false`**, because flatly and darkly bring a web font of their
own. Both open their compiled bundle with an `@import` of Google Fonts' Lato,
and the variables above leave nothing set in it — but an `@import` is fetched
whether or not anything matches the family, so a third origin would be on the
critical path of every page load for a font no element asks for. Bootswatch
guards that rule with `@if $web-font-path`, so setting the variable to `false`
in `custom.scss` drops it from both bundles.

`faces.css` declares Greek, Hebrew, Chinese and math faces too. Those cost
nothing: an unmatched `@font-face` is never fetched, and this guide is in
English, so a browser downloads only the four Schola faces and the four
JetBrains Mono ones.

The families are repeated in `custom.scss` rather than read from the
`--font-body` and `--font-code` custom properties `faces.css` also exports.
Those would work, but an undefined `var()` is invalid at computed-value time:
if font.kolen.dev were unreachable the declaration would be thrown out whole,
taking the Georgia and Menlo fallbacks with it. Naming the families keeps the
fallback chain a local fact.

### What that origin promises, and what it does not

Depending on someone else's deployment is a trade, and it is worth knowing
which half of it is written down. The two stylesheet paths, the family names
they declare and the two custom property names are fixed. A font file is never
replaced in place: an updated face is published under a new filename with the
stylesheet pointed at it, which is what lets the `.woff2` files be served
`max-age=31536000, immutable` — the eight faces this guide actually fetches
come to about 610 KB, and a returning visitor refetches none of it — while the
4 KB stylesheet in front of them stays short-lived and bustable.

What there is not is a version to pin. Everyone gets the same two URLs, so a
face added, dropped or moved to a newer upstream release arrives here once the
stylesheet's cache entry expires. Reckon on four hours rather than the hour
`faces.css` asks for: Cloudflare serves whichever is higher, the origin's
`max-age` or the zone's Browser Cache TTL, and that zone is on Cloudflare's
four-hour default.

Family names survive such a release. Metrics are not promised with them. An
upstream release may change advance widths, x-height or vertical metrics, and
nothing on either side would catch it — `$font-size-base` and
`$line-height-base` in `custom.scss` are tuned against the current Schola, and
they are what would show it. In exchange this repository carries no font files
and no licence files, since the copy a visitor's browser receives comes from
font.kolen.dev and the OFL and GUST licence texts are published there beside
the faces.

If that trade ever stops being acceptable, the escape hatch is documented:
`src/assets/` in ickc/font is self-contained, licence files included, and
copying it into `src/` here makes this site decide for itself when its fonts
change — and makes it the party doing the distributing, which is what brings
those licence files along.

## How pages are laid out

Every folder under `src/` is a section, and every section looks the same:

```
src/running-jobs/
  index.md                      section intro + a listing of the folder
  10-workflow.md                content
  20-embarassingly-parallel.md  content
  30-oversubscription.md        content
```

There are exactly two kinds of file in a section, and `pixi run format-check`
rejects anything else:

- **`index.md`** — a short intro plus a `listing` that enumerates the folder. It
  holds no content of its own; a section with only one page still gets an
  `index.md` and a separate `10-intro.md`, so no folder is a special case.
- **`NN-name.md`** — a content page. The two-digit prefix sets the order.

`src/404.md` is the one page outside that scheme; see below.

### Adding a page

Drop in a new `NN-name.md` with a `title`, then run `pixi run format`. Nothing
else needs editing: the sidebar picks it up through an `auto` glob in
`src/_quarto.yml`, and the section's `index.md` listing picks it up through its
own glob. Leave gaps in the numbering (10, 20, 30) so pages can be inserted
without renumbering.

`src/_quarto.yml` only names the sections and their order. It never lists
individual pages.

### The not-found page

`src/404.md` renders to `docs/404.html`, and Cloudflare Pages serves it — with a
404 status — for any URL that matches no file. Its presence in the output root
is the whole configuration: Pages infers a project's not-found behaviour from
the files it is given, and a site with no `404.html` falls back to answering
with `index.html` instead, which is why an unknown URL used to land on the home
page.

It is exempt from the `NN-` rule, and `bin/md_formatter.py` names the exemption
in `UNNUMBERED_STEMS`. The exemption is not a convenience: the filename *is* the
contract with Pages here, exactly as `index.md` is with Quarto, so a page named
by contract cannot also carry an order prefix. It gets no `output-file` either,
for the same reason. Being outside every section, it appears in no sidebar and
no listing, and Quarto keeps it out of `sitemap.xml` and the search index.

The one thing to know when editing it: because it is served at URLs of any
depth, Quarto writes its links and assets from the site root (`/mpi/index.html`)
rather than relatively, which it can only do because `site-url` is set in
`src/_quarto.yml`. Links in the source are still written the normal way, to the
source file — Quarto handles the rest.

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
