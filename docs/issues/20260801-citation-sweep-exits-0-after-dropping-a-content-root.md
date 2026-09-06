---
id: 20260801-citation-sweep-exits-0-after-dropping-a-content-root
num: 190
title: "Citation sweep exits 0 after dropping a content root"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [scripts, spec, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-01T06:36:03Z
updated: 2026-08-01T10:01:09Z
origin: "20260801-c-prime-fix-handoff.md (retired; see 5e712bf)"
---

## Context

`sweep_citations` in `skills/spec/scripts/reconcile.sh` resolves four configured
content roots before sweeping. Two of its rejection paths warn and `continue`
**without setting `sweep_failed`**:

- `skills/spec/scripts/reconcile.sh:369` — a root that cannot be resolved
- `skills/spec/scripts/reconcile.sh:377` — a root resolving outside the worktree

## Problem

When either path is taken, some citations are rewritten and others are not,
`INDEX.md` is never regenerated for the dropped root, and the function still
returns **exit 0**. The caller gets no signal that the sweep was partial, so a
half-rewritten citation graph reads as a clean run.

This is verbatim the failure shape the C-prime-fix removed elsewhere in this
same function: a partial operation reporting success. The accumulate-and-continue
discipline is already present a few lines down — the `awk_rc` guard at `:507`
sets `sweep_failed=1` and continues — so the dropped-root paths are the
inconsistent ones.

## Proposed action

Set `sweep_failed=1` before each of the two `continue`s. One line each; the
existing `return "$sweep_failed"` at the end of the function already propagates.

## Provenance

Reported by the five-investigator review of the sdlc/issue-territory changes
(`docs/notes/20260801-c-prime-fix-handoff.md` § 4, finding N1). Anchor
re-confirmed 2026-08-01 — the missing assignment is visible in the source. The
downstream consequence follows directly from the control flow but was not
reproduced end-to-end.

## Resolution (2026-08-01)

Fixed. Both drop sites set `sweep_failed=1`, and the declaration moved to the
top of the function — it sat below the root-resolution pass, so a later
`local … =0` would have reset whatever the drops recorded. The empty-roots early
return carries the flag out too, though no CLI path reaches it: the specs root
must resolve for `--apply` to get that far.

Covered by `case_specreconcile_sweep_dropped_root_fails_the_run`, which is
mutation-tested — with the flag removed it fails.
