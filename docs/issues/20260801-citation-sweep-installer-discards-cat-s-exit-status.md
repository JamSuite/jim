---
id: 20260801-citation-sweep-installer-discards-cat-s-exit-status
num: 191
title: "Citation sweep installer discards cat's exit status"
status: closed
priority: high
labels: [scripts, spec, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-01T06:36:04Z
updated: 2026-08-01T10:01:09Z
origin: "20260801-c-prime-fix-handoff.md (retired; see 5e712bf)"
---

## Description

## Context

The citation sweep's awk rewrite is guarded — `skills/spec/scripts/reconcile.sh`
checks `awk_rc` and refuses to install a partial rewrite. The **installer
itself** is not guarded:

```
skills/spec/scripts/reconcile.sh:513
      cat -- "$tmp_out" > "$f"
```

## Problem

The awk guard covers the *producer* but not the *consumer*. `cat`'s exit status
is discarded, so:

- A read-only target reports `REWROTE` for a rewrite that never landed.
- An ENOSPC part-way through the `cat` truncates a tracked file, unrecoverably,
  and still reports success.

It is the mirror image of the fix that guarded the awk exit: the same
"non-zero exit discarded, success reported" shape, one step later in the
pipeline.

## Proposed action

Check the install's exit status and treat a failure the same way the awk guard
does — report the file on stderr, set `sweep_failed=1`, `continue` to the next
file rather than aborting the batch. The same treatment applies to the two
sibling installers now guarded in `skills/partition/scripts/jimpartition.sh`,
whose awk exit is checked but whose `cat` is not.

## Provenance

Reported by the five-investigator review of the sdlc/issue-territory changes
(`docs/notes/20260801-c-prime-fix-handoff.md` § 4, finding N2). Anchor
re-confirmed 2026-08-01 — the unchecked `cat` is visible in the source. The
ENOSPC and read-only consequences were reasoned from the code, not reproduced.

## Resolution (2026-08-01)

Fixed in all three places: the citation sweep's installer and both siblings in
`jimpartition.sh`, whose awk exit was already checked but whose install was not.

Covered by `case_specreconcile_sweep_uninstallable_target_fails`, which stages a
read-only target and is mutation-tested — with the guard removed it fails and
the target is overwritten.
