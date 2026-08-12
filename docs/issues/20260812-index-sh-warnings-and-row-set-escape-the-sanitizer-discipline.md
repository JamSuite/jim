---
id: 20260812-index-sh-warnings-and-row-set-escape-the-sanitizer-discipline
num: 333
title: "index.sh warnings and row set escape the sanitizer discipline"
status: open
priority: high
labels: [issue, data-integrity, index]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:31Z
updated: 2026-08-12T21:53:31Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

Two integrity defects in `index.sh` that the round's row-forgery fix did not
cover. Both concern untrusted frontmatter reaching the committed `INDEX.md`.

## 1. A slug is admitted before the frontmatter gate

`skills/issue/scripts/index.sh:361-375` appends to `slugs_seen` at `:368`, then
gates on frontmatter at `:372-375`:

    slugs_seen+=("$slug")
    …
    [[ -z "$fm" ]] && continue

The counters at `:410-414` come *after* the gate. So a file with missing or
malformed frontmatter yields a row — `` - `<slug>` — (untitled) · status: open ``
— while contributing nothing to `Open:`/`Closed:`. The index asserts a row its own
Summary denies.

`case_issues_index_malformed_frontmatter_warning` (`tests/issues.sh:669`) asserts
only that the warning appears; it does not assert the row's absence, so this is
live and unpinned. It is also the mechanism the control-character enumeration
defect rides on.

## 2. The warnings section escapes the sanitizer discipline

Every row value clears `row_safe` (`index.sh:279-281`: strip `\000-\037\177`,
strip the middle dot, `cut -c1-512`) at `:552-557`. Three warnings values do not:

- `index.sh:517` — `$origin_value`, a raw frontmatter scalar
- `index.sh:428` — `$target`, a raw relation value that failed `is_valid_id`
- `index.sh:448` — `$wl`, a raw wikilink value that failed `is_valid_id`

Newline injection is not possible here (the parse is line-oriented), so this is
not a row-forgery route. But an unbounded value lands whole in a committed
artifact, and ESC/CR bytes reach anyone who `cat`s `INDEX.md` and the analyst that
reads it. That is precisely the shape of the length-cap regression just fixed at
`:507` for the placement name.

The branch is live in the common case: `jimconf.sh:96` defaults `issue_placement`
to the sentinel `branch`, which is the arm that *runs* the origin lint.

The closed row-forgery issue's own proposed action offered "or sanitize each
concatenated value the way the placement name already is" — the alternative was
taken and these three were left.

## Action

1. `index.sh:368` — append to `slugs_seen` only after the frontmatter gate passes,
   so the row set and the counts derive from the same population. Extend
   `case_issues_index_malformed_frontmatter_warning` to assert no row is rendered.
2. `index.sh:517`, `:428`, `:448` — route each through `row_safe`, plus the
   backtick strip for values sitting inside a code span, as `:507` already does.
   Pin with a case planting a control character and an over-long value in an
   `origin:` and asserting the committed index carries neither.

Trivial, same file: `index.sh:259-261` is `resolve_dir`'s docstring, but
`row_safe`'s docstring and body were inserted between it and `resolve_dir()` at
`:283`, so the file reads as if `row_safe` is documented twice and `resolve_dir`
not at all.
