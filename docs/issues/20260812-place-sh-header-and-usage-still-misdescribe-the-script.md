---
id: 20260812-place-sh-header-and-usage-still-misdescribe-the-script
num: 315
title: "place.sh header and usage still misdescribe the script"
status: open
priority: low
labels: [issue, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:42:10Z
updated: 2026-08-12T03:42:10Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`place.sh`'s header and `usage()` still misdescribe the script in four places, and
two git calls still lack the option-injection guard — all of them items a closed
conformance issue's resolution note claims were fixed.

## The inaccuracies

- **`place.sh:1367-1368`** — `cmd_mode`'s docstring reads "the self-routing
  decision, and the only place the config gate is evaluated". It is not:
  `place_destination` is also called by `cmd_begin` (`:799`), `cmd_commit`
  (`:932`) and `cmd_run` (`:1425`). This exact wording was named in the closed
  issue and is absent from the fixes its Resolution section lists.
- **`place.sh:80`** — "Parses with grep, sed, awk, tr and `read` only" omits two
  tools that do parse: `head -n1` selects the remote name at `:354`, and
  `cut -c1-512` truncates in `place_shown` at `:331`.
- **`place.sh:44` vs `:1658`** — the header synopsis marks `--verb` optional,
  matching the code; `usage()` still prints it as required. Fixed in one of the
  two places.
- **`place.sh:1130` and `:1322`** — `git cat-file blob "$sha"` with no
  `--end-of-options` / `--`. Both arguments are git's own hex output so a leading
  `-` is unreachable, but the file is otherwise consistent on this and the
  resolution note claims the sweep was complete.

Also outstanding from the same package: the publish loop still discards git's
stderr (`place_land:1254`, `:1260`, both `2>/dev/null`), so the non-contention
message can only guess at the cause — the plan item required capturing it.

## Why this matters beyond the text

A resolution note is the durable record of what shipped. When it is more complete
than the change, the next reader inherits a false clean and the item is never
re-derived.

## Proposed action

Fix the four inaccuracies, add the two `--end-of-options`, capture git's stderr in
the publish loop, and correct the resolution note on
`20260807-place-sh-conformance-and-hygiene-pass` to say what was actually done.

## Origin

Post-build review of `issue/011`; conventions region sweep.
