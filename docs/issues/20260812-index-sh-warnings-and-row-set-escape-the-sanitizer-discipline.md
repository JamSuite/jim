---
id: 20260812-index-sh-warnings-and-row-set-escape-the-sanitizer-discipline
num: 333
title: "index.sh warnings and row set escape the sanitizer discipline"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, data-integrity, index]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T21:53:31Z
updated: 2026-08-13T06:36:17Z
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

## Resolution

**2026-08-13.** Both defects are closed in `6e68a22`, alongside the enumeration
half of the control-character finding — the two were taken as one pass because
the second is the mechanism the first rides on.

**1. The row set and the counts derive from one population.** `slugs_seen` is
recorded past the frontmatter gate rather than ahead of it, so a file failing
that gate contributes no row and no count. Pinned by
`case_issues_index_malformed_frontmatter_warning`, extended per this issue's
action to assert the row's absence and both Summary counts.

**2. Four warning values clear the sanitizer**, not the three named here. The
fourth is the refusal quoting a rejected filename — the sharpest of the set,
because it is the only one whose value can carry a literal newline (a relation
target and a wikilink are both drawn from single lines), and because it fires
precisely when the value has already failed `is_valid_id` and is therefore
guaranteed to hold a byte outside the allowlist. It was invisible until the
enumeration stopped mangling the name; with the enumeration fixed and this site
raw, a committed filename forges a second `## Issues` section and a row inside
it. Pinned by `case_issues_index_control_char_name_cannot_forge_a_section`,
`..._warning_values_clear_the_sanitizer`,
`..._invalid_relation_target_is_sanitized` and `..._malformed_wikilink_is_sanitized`.

**Each of the four was proven by neutering its own guard** and watching the case
that names it go red; each neuter was diffed against a saved copy first, so a
pattern that silently missed could not be recorded as a proof.

**One property this issue did not name, now pinned.** `row_safe`'s stages are
ordered, not interchangeable: `tr` runs first because deleting a control byte can
bring the separator's own two bytes together — `C2 01 B7` collapses to a
reconstituted `·` — and `sed` removes it only by running afterwards. Reordering
the three reopens separator forgery. Recorded at the function and pinned by
`case_issues_index_sanitizer_cannot_reconstitute_a_separator`, which counts
separators in a rendered row rather than grepping for the injected text.

**The trivial item is taken:** `resolve_dir`'s docstring sits with
`resolve_dir()` again.

**One knock-on, accepted rather than fixed.** A file with frontmatter delimiters
but no parseable content is no longer in the indexed set, so `render.sh show`
answers `no issue matched` where it previously rendered a blank-titled stub. That
follows `render.sh`'s own rule that an id resolves only against the indexed set,
and the file stays visible through the integrity warning that `stats` passes
through. No test or spec asserted the old behaviour in either direction.

**Verified beyond the suite.** An adversarial pass attacked the sanitizer with
nine fixtures aimed at the real `render.sh` parsers — multibyte and overlong
encodings, NEL/U+2028/U+2029, separator reconstruction, cut-boundary tearing, and
every remaining raw concatenation site — and refuted none of it. Two residues it
recorded, both inert against every reader in this corpus, which are all
byte-oriented under `LC_ALL=C`: the length cap can tear a multibyte character and
leave a dangling lead byte, and line-break-like code points that are not `0x0A`
survive as ordinary bytes.

Suite **1370 → 1376**.
