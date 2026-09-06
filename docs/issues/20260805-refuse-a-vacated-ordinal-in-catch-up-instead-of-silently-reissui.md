---
id: 20260805-refuse-a-vacated-ordinal-in-catch-up-instead-of-silently-reissui
num: 229
title: "Refuse a vacated ordinal in catch-up instead of silently reissuing it"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, registry, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-05T01:53:40Z
updated: 2026-08-05T10:21:33Z
origin: "20260805-b-prime-review.md (retired; see 5e712bf)"
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

## Resolution (2026-08-05)

Fixed — but not by either action this issue proposed, because both are wrong.

**The mechanism was an intersection nobody named.** With the directory still
sitting on the vacated ordinal, `alloc_classify_spec` emits **both**
`RENAME-SRC` (keyed on the vacancy) and `MISSING` (keyed on the id having no
live claim) for the same id — and it is `MISSING` that catch-up harvests. So:

- Adding `RENAME-SRC` to `CU_BLOCKED` would wedge `catch-up` on **every**
  registry that has ever had a rename. The class fires for the healthy
  post-rename state, which is exactly why the sweep excludes it from
  `drift_rows`.
- Filtering `want_spec` by it repairs the corruption *silently*, at rc 0 — a
  repair verb that quietly skips what it could not fix, which is the shape the
  cluster's own practice 6 exists to forbid.

The drift is the intersection: a tree artifact occupying a spent ordinal. It is
now its own class, `SPENT-TREE` (`tree-on-vacated-ordinal`), on both the spec
and issue sides, and it is the **only drift class whose repair is not a record**
— the registry is internally consistent and correct, and the artifact must move
to the id `resolve` names or renumber above the group's peek. It joins
`drift_rows` (sweep rc 3) and both `CU_BLOCKED` patterns (catch-up rc 3, nothing
appended). `RENAME-SRC` keeps its counted-only, non-drift meaning for the
settled case, with the suppression guard mirroring the tree loop's branch
conditions exactly so an unreadable id skipped there is not lost by both.

**The #200 consultation this fork required resolves the other way than assumed:
this is not a #200-class problem, and refusing leaves nothing standing.** Those
classes — `duplicate-ordinal`, `duplicate-id`, `reserved-slot`,
`unreadable-record`, plus the duplicate realize key and the realize `CONFLICT` —
are all registry-*internal*: two records contradict, an operator must pick a
winner, and repairing one needs a corrective-write primitive the grammar does
not have (seven encoders, zero tombstone / precedence / revoke). This is
tree-vs-registry drift where the registry is right. Refusing routes to an
instrument that already exists rather than deferring to one that does not, so
#200's scope is untouched.

**Three more doors of the same rule closed with it**, per the review's lesson
that a contract names a site and a site is not a class: `catch-up` × issue,
`catch-up` × group (filed separately, and it needed the specs under the retired
group withheld too, not merely reported), and the `lift`, which declared and
filled the spent set without reading it (also filed separately).

Fifteen mutations, all red, each aimed at one assertion — including the two that
pin the classes apart in both directions: `SPENT-TREE` must not swallow a plain
missing record, and a vacancy whose tree moved must stay settled.
