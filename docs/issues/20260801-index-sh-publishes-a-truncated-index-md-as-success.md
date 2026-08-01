---
id: 20260801-index-sh-publishes-a-truncated-index-md-as-success
num: P-20260801-index-sh-publishes-a-truncated-index-md-as-success
title: "index.sh publishes a truncated INDEX.md as success"
status: open
priority: high
labels: [scripts, issue]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-01T06:36:06Z
updated: 2026-08-01T06:36:06Z
origin: docs/notes/20260801-c-prime-fix-handoff.md
---

## Description

## Context

`skills/issue/scripts/index.sh` composes `INDEX.md` into a temp file inside a
brace block, then atomically renames it:

```
skills/issue/scripts/index.sh:509-532
  {
    printf '# Issue Index\n\n'
    ...
  } > "$tmpfile"

  mv "$tmpfile" "$dir/$INDEX_FILENAME" || { ... }
```

The `mv` is guarded. The **write block is not** — its exit status is never
checked.

## Problem

The script's own contract at `:45-46` states:

> On success: exit 0, INDEX.md updated atomically.
> On parse/IO failure: exit non-zero, previous INDEX.md untouched.

An ENOSPC part-way through the block leaves a truncated `$tmpfile`, which the
`mv` then atomically publishes **over a good INDEX.md**, and the script returns
0. That contradicts the contract in both halves: the failure is neither
non-zero nor does it leave the previous INDEX.md untouched.

Every sibling emitter guards this same write — `new.sh:208`,
`backfill.sh:135`, `issue/reconcile.sh:182`. `index.sh` is the only one that
does not.

The blast radius is wider than one file: both reconcilers key their "index
failed to regenerate" error off this exit code, so a truncation propagates to
them as a clean result.

## Proposed action

Check the write block's exit status before the `mv`, matching the sibling
pattern: on failure, report on stderr, remove the temp file, and exit non-zero
without renaming — which is exactly what the contract already promises.

## Provenance

Reported by the five-investigator review of the sdlc/issue-territory changes
(`docs/notes/20260801-c-prime-fix-handoff.md` § 4, finding P1). Pre-existing,
not introduced by that build. Anchors re-confirmed 2026-08-01: the unchecked
block, the contract text, and the three guarded siblings all read as described.
The ENOSPC consequence was reasoned from the code, not reproduced.
