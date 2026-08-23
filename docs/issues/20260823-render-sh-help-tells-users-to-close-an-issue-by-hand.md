---
id: 20260823-render-sh-help-tells-users-to-close-an-issue-by-hand
num: 369
title: "render.sh help tells users to close an issue by hand"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, docs, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:45:28Z
updated: 2026-08-23T23:45:28Z
origin: "docs/specs/issue/012-schema-and-state-model/spec.md"
---

## Description

## Description

`render.sh`'s help text tells the reader to close an issue by hand, in a way
that now produces an integrity warning.

## What it says

```
Issues live in the configured issues directory. Close one by editing its
`status:` field directly.
```

## Why it is wrong now

An issue that has ever been finished carries an `outcome`. Editing `status:` to
`closed` by hand leaves that field empty, and the index reports the record as
"closed but records no outcome" — a warning written into generated content the
project publishes.

The supported path is `transition.sh close`, which records the outcome
alongside the status and regenerates the index. The help text predates that
verb existing.

## Related staleness in the same area

`place.sh`'s header carries a verb enumeration that no longer matches the verbs
it implements. Both are documentation that drifted from the code beside it, and
both are cheap to correct in one pass.

## Why it matters

Help text is the surface a user reaches when they are already unsure. Pointing
them at a manual edit that the collection's own integrity check then flags
teaches the wrong model of how the collection is maintained.
