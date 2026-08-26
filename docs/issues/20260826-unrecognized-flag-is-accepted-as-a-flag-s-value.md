---
id: 20260826-unrecognized-flag-is-accepted-as-a-flag-s-value
num: 397
title: "Unrecognized flag is accepted as a flag's value"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, read-views, filters]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:34:18Z
updated: 2026-08-26T02:34:18Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## Description

## What

`need_operand` refuses an operand that is one of *this file's own* option names,
so `--label --priority` is caught. It does not refuse an operand that is
flag-shaped but unrecognized, so:

```
$ render.sh list --label --nosuchflag <dir>
rc 0 — `--nosuchflag` is bound as a label alternative
```

Standing alone, the same token is recognized as a flag and refused with
`unknown filter flag: --nosuchflag`. The parser therefore holds two opinions
about the same text depending on where it sits.

## The gap between the criterion and the decision

The acceptance criterion reads: *"A flag given with no value, or with a value
that is another flag, is refused rather than treated as absent."* The plan's
design decision narrowed this to "a flag whose operand is another **known**
flag", and the implementation follows the decision.

The narrowing has a stated rationale, and it is a good one: the recordable
identity set admits a leading hyphen deliberately, so `--claimed-by
-dev@example.test` must keep working. But that rationale concerns *single*-hyphen
values. The carve-out as written also swallows double-hyphen tokens, which no
address wears.

## Fix shape

Refuse a `--`-prefixed operand; carry a single-hyphen one through. That matches
the stated rationale exactly and closes the gap against the criterion, without
breaking the leading-hyphen address case the decision was protecting.
