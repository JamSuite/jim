---
id: 20260805-refuse-a-vacated-ordinal-in-catch-up-instead-of-silently-reissui
num: 229
title: "Refuse a vacated ordinal in catch-up instead of silently reissuing it"
status: open
priority: critical
labels: [id-coordination, registry, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T01:53:40Z
updated: 2026-08-05T01:53:40Z
origin: docs/notes/20260805-b-prime-review.md
---

## Description

## Description

`catch-up --apply` reissues an ordinal a rename vacated, silently changing what
every frozen citation to that id dereferences to — and the registry reports clean
afterwards.

`alloc_classify_spec:1714` emits `RENAME-SRC spec <id> "vacated by a rename"`.
`alloc_catchup_compute:3033-3035` harvests **only** the `MISSING` class into
`want_spec`, and its refuse-list at `:3039` greps
`^(MISMATCH|DUP-ORD|DUP-ID|RESERVED|UNREADABLE)` — `RENAME-SRC` appears in
neither. The classifier computes the fact, prints it, and catch-up discards it.

Reproduced end to end against a real git registry, independently by two
investigators (once via a spec rename, once via a group rename):

```
$ jimalloc partition-batch group jim core   →  resolve spec jim/001 → core/001
$ jimalloc sweep                            →  rc 3, rename-source-ids 1
$ jimalloc catch-up --apply                 →  spec allocate jim/001 … jim-catchup
$ jimalloc resolve spec jim/001             →  jim/001     ← referent changed
$ jimalloc sweep                            →  rc 0, rename-source-ids 0   ← clean
```

The failure shape is the worst available: the sweep reports drift, the operator
runs the repair verb, the repair verb corrupts the registry, and the detector then
agrees it is fine. The fresh live claim masks the spent marker, so nothing
downstream can find it again.

Highly reachable. The rename record and the directory move are separate steps, so
an aborted reconcile, a reverted directory move, or a branch merge restoring the
old directory all produce the precondition.

This is a **living-intent divergence**, not only a code gap.
`docs/specs/platform/000-blueprint/spec.md:91-92` asserts a vacated ordinal is
"permanently gapped whatever shape the log takes". That sentence credits the fold,
and the fold does have the property — but catch-up writes around the fold
entirely, so the recorded invariant states a system property the system lacks.

It is also verbatim the harm the emitters' own comment at `jimalloc.sh:3431-3433`
describes. `partition-batch` refuses this pair set by name on both the spec and
group doors; `catch-up` writes it and exits 0.

## Proposed action

Filter `want_spec` by the `RENAME-SRC` set, or add `RENAME-SRC` to the
`CU_BLOCKED` pattern so the operator sees an unrepairable finding rather than a
silent rewrite — the same treatment `MISMATCH` already gets. The information is
already computed in the same pass; this is a wiring gap, not a detection gap.

Then enumerate the remaining write doors against the never-reissue rule rather
than against this issue: `lift` is the third door and also does not consult the
spent set (filed separately).

Fixture: construct a vacated ordinal whose tree directory survives, run
`catch-up --apply`, and assert both that no record is appended and that `resolve`
still follows the rename. Nothing in the catch-up test section covers a spent or
redirected destination today.

## Provenance

Post-build review of the B-prime hardening cluster
(`docs/notes/20260805-b-prime-review.md`, Finding 1). Surfaced by the omission
sweep and independently reproduced by the #209 investigator.
