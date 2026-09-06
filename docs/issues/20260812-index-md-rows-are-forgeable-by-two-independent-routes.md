---
id: 20260812-index-md-rows-are-forgeable-by-two-independent-routes
num: 309
title: "INDEX.md rows are forgeable by two independent routes"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, security, index]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T03:41:37Z
updated: 2026-08-12T09:00:02Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`INDEX.md` rows can be forged by two independent routes, so `list`, `show`,
`stats` and the analyst's graph can be made to serve fabricated issue metadata.

## Route 1 — key-order overwrite via an unencoded `origin`

`skills/issue/scripts/index.sh:521-527` builds each row as ` · `-separated
`key: value` pairs, with `origin` **last**. `skills/issue/scripts/render.sh:157-167`
re-parses that row by splitting on `/ · /` and assigning by key **in order**, so a
later segment overwrites an earlier one.

An `--origin` value containing ` · status: closed` therefore overrides the real
status in `list` and in the analyst's open-set; ` · num: 1` forges the ordinal
that `show <N>` resolves against. `origin` is emitted as a bare plain scalar
(`new.sh:238`, `:270`) — newline-collapsed only, not YAML-encoded — which is what
lets the separator survive.

Title injection is neutralized by ordering (the real `status:` segment comes
after it) but still truncates the displayed title at the first ` · `.

## Route 2 — `printf '%b'` escape expansion in the warnings section

`index.sh` builds `warnings_section` by concatenating untrusted values — a
body-derived wikilink (`:427`), a frontmatter relation target (`:407`), an origin
path (`:486`), a filename-derived slug (`:344`) — and emits it with
`printf '%b'` (`:571`), which expands backslash escapes in those values.

A relation target or wikilink containing a literal `\n## Issues\n- ...` injects
lines into `INDEX.md`. `read_issue_rows` re-opens the section on any later
`^## Issues$` (`render.sh:150-151`), so the fabricated rows are then served by
every read verb.

Every other value written into the index is validated (ids via `is_valid_id`) or
sanitized; the `%b` warning path is the gap.

## Proposed action

Route 1: encode `origin` as a quoted scalar, or strip the ` · ` separator from
index row values, or parse rows positionally rather than by key-in-order. Route
2: use `printf '%s'` for the warnings section, or sanitize each concatenated
value the way the placement name already is at `:476`.

## Related

The encode-or-narrow fork for `origin` is tracked in
`20260808-origin-is-not-yaml-encoded-and-a-bare-brace-argument-is-substitu`; this
issue is the concrete harm that bears on it, and Route 2 is independent of that
decision.

## Origin

Post-build review of `issue/011`; found by the trust-boundary investigator and
the `untrusted-body-never-shell` judge. Both routes are pre-existing.

## Resolution (2026-08-12)

Fixed in `39661e1`.

**Route 1** is broken at the writer, which is where it makes the artifact itself
unforgeable rather than fixing one reader: `row_safe` strips the separator's own
character from every value a row carries, so the row's shape is a property of
this writer and not of its inputs. Parsing positionally in `render.sh` was
considered and not taken — it would leave the forged segment in the committed
index and cover only readers that go through that script, while the analyst reads
`INDEX.md` directly.

The middle dot is removed rather than the three-character sequence, so no
arrangement of spaces around it can reconstitute a separator. The removal is by
`sed` rather than `tr -d`, which under `LC_ALL=C` would delete each byte of the
two-byte encoding wherever it occurred and corrupt any other character sharing
one.

**Route 2** is independent and closed by emitting the warnings section with
`printf '%s'`; the accumulator carries real newlines instead of the two-character
escapes `%b` was expanding.

Pinned by `case_index_row_values_cannot_forge_a_later_key` and
`case_index_warnings_do_not_expand_escapes`, both proven to go red with their
guard removed. Both assert on what a *reader* resolves, not on whether the
attacker's text is present: the text is the issue's own field and is not the
writer's to censor — what must not survive is its ability to form a pair or open
a row.

Note the encode-or-narrow fork this issue points at was settled separately, and
does not close either route: the row is built from the *parsed* value, so ` · `
survives any YAML quoting.
