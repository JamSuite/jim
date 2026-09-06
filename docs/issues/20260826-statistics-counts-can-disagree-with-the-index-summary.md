---
id: 20260826-statistics-counts-can-disagree-with-the-index-summary
num: 395
title: "Statistics counts can disagree with the index summary"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, read-views, index]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:34:45Z
updated: 2026-08-26T11:22:53Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## What

`index.sh` and `render.sh` now classify a record's lifecycle state at different
points in the sanitizing pipeline, so the two can report different counts for
the same collection.

- `index.sh` compares the **raw** frontmatter value when it builds the
  `## Summary` block's Open/Closed counts.
- `render.sh stats` compares the **sanitized** value it reads back out of the
  Issues row.

`row_safe` strips control characters between those two points.

## Reproduce

An issue whose frontmatter carries `status: "closed<0x01>"` — a `closed`
followed by a control byte, which is not whitespace and so is not trimmed:

```
$ grep -E '^- (Open|Closed):' <dir>/INDEX.md
- Open: 1
- Closed: 0

$ render.sh stats <dir>
  Open: 0 · Closed: 1
```

Two numbers for one collection, in and beside one file.

## How it arrived

The read-view filter work moved `stats`'s counts off the index's Summary lines
and onto the rows, so that a filtered and an unfiltered census would be one code
path rather than two. That is the right shape — but the previous code echoed the
Summary verbatim and therefore could not disagree with it, and the new code can.

## Which one is right

Arguably `render.sh`'s: the sanitized value is what every reader of the index
sees, and it is what every other view already acts on. The divergence is the
problem rather than either number.

## Fix shape

Compare the sanitized value on both sides — `index.sh` would classify from
`row_safe`'s output rather than the raw scalar. That is a one-line change with a
wide blast radius (it moves the Summary numbers for any collection holding such
a value), so it wants its own test.

Requires an embedded C0 control byte in a frontmatter scalar to observe, so this
is adversarial or corruption-shaped input rather than an ordinary typo.

## Resolution

Fixed in `74a91d2`. `index.sh` sanitizes `status`, `outcome` and `type` once,
immediately after the frontmatter read and before anything judges them, so
classification and display are one value rather than two.

**The count was one of three sites.** The same raw value reached both
vocabulary checks, so `type: "issue<0x01>"` produced `unrecognized type: issue`
— a warning printing the sanitized value it had not judged, naming as
unrecognized a member of the vocabulary it was checked against. `outcome`
behaved identically across all four of its members. Fixing only the Summary
would have left two warnings a reader cannot act on.

**The row emitter now drops its own pass over those three.** They have one
assignment site each, fed by the sanitized value, so re-applying an idempotent
transform there is the re-derivation being removed rather than defence in
depth. That is also measurable: doing both took a 402-record regeneration from
41s to 52s, and every mutating verb regenerates through this path.
Sanitize-once-and-emit is flat against the original.

What the second pass was worth is pinned by test instead.
`case_issues_index_classified_scalars_cannot_forge_a_row_field` feeds each
judged scalar a value carrying the row's own ` · ` separator and asserts no
forged pair and no control byte reach the row; neutralizing the sanitize makes
it fail on all three fields, so it pins the guarantee rather than restating it.

`case_issues_index_vocabularies_are_judged_after_sanitizing` loops the
vocabularies `index.sh` declares — discovered from the script, not listed — and
fails on one with no field mapping, so a vocabulary cannot enter the script
without entering the case.

**Blast radius, measured rather than estimated:** regenerating this
repository's own 402-issue collection produces a byte-identical `INDEX.md`. The
numbers move only for a collection holding a control byte in a judged scalar.

**Not closed by this:** `row_safe` is three processes per call and runs about
eleven times a record, which is most of the 41s a 402-record regeneration
costs. That is a separate observation, not this defect.
