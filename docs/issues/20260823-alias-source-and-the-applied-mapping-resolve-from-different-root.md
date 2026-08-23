---
id: 20260823-alias-source-and-the-applied-mapping-resolve-from-different-root
num: 356
title: "alias_source and the applied mapping resolve from different roots"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, migration, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:21:49Z
updated: 2026-08-23T23:21:49Z
origin: "docs/specs/issue/013-recorded-identity-schemes/review.md"
---

## Description

## Description

The re-normalization preview reports which alias mapping is in play using one
resolution root, and applies the mapping using another. Under a routed
placement the two can disagree, and the disclosure can then be wrong in the
direction that matters.

## What happens

`alias_source` locates the mapping relative to the collection directory:

```
git -C "$dir" rev-parse --show-toplevel
git -C "$dir" config --get mailmap.file
```

The mapping actually applied to each value resolves relative to the invoking
process's working directory, because `identity.sh`'s lookup runs plain
`git check-mailmap` with no `-C`.

In the ordinary case these are the same repository and nothing diverges. Under
`issue_placement` routing they need not be: the wrapped command runs with no
`cd`, so the working directory stays wherever the developer was standing, while
the directory operand can be a materialized copy with no `.git` at all.

## The failure

`alias_source` finds no repository at the materialized directory and the
preview states:

```
Alias mapping: none found — identities resolve through the form alone.
```

while values are in fact being resolved through whatever mapping the
developer's own checkout carries. An operator approving that plan has been told
the opposite of what happened.

## Why it matters

The disclosure exists so an operator sees the transform before approving it
rather than inferring it from the result afterwards. A disclosure that can be
confidently wrong is worse than none, because it is relied upon.

## Direction

Make presence and application agree on one root. The application side is the
one that decides what gets recorded, so it is the sounder anchor — but the
choice is worth making deliberately rather than by which function was edited
last.

Origin: `docs/specs/issue/013-recorded-identity-schemes/review.md` — Finding 9.
