---
id: 20260730-align-the-registry-with-tree-scan-era-spec-ordinals
num: 144
title: "Align the registry with tree-scan-era spec ordinals"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-30T10:32:41Z
updated: 2026-07-31T06:38:04Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/plan.md
---

## Description

The coordination registry does not hold allocate records for the specs created
while `/jim:spec` still derived ordinals from the tree. `platform/011` and
`sdlc/017` both exist on disk with no record, so the allocator's high-water sits
below what the project already owns and `peek`/`allocate spec` will offer an
ordinal that is taken.

This is the live failure `sdlc/017`'s problem statement names, and shipping the
consumer does not fix it: the consumer stops *new* drift, it does not repair
drift that predates it.

The repair is a one-time developer action, not a shipped verb.

**Correction (2026-07-31): `seed --apply` cannot do it.** This issue originally
named seed as the repair path. Seed is bootstrap-only — it refuses a registry
whose logs already carry records:

```
error: registry already seeded (specs.log/issues.log already have records);
refusing to re-seed
```

(`jimalloc.sh:1652`.) `specs.log` holds 60 records, so that door is closed. The
verb that *would* do this — an incremental catch-up appending only the records a
non-empty log is missing, under the same CAS and erosion discipline — is
[[20260728-registry-drift-catch-up-has-no-incremental-seed-verb]], and its `low`
priority looks increasingly wrong for exactly this reason.

**So the repair today is the hand-append**, two `spec allocate` records carrying
each spec's own creation date in the informational date field:

```
spec allocate platform/011 rename-path-correctness 20260729 <who>
spec allocate sdlc/017 coordinated-spec-identity 20260730 <who>
```

Append-only growth keeps the erosion guard satisfied (it checks that the
per-clone baseline stays a byte-prefix of the current log), and parenting the
commit on the branch tip makes the ordinary push the compare-and-swap — the same
`cat-file` → `hash-object` → `mktree` → `commit-tree` → `push` plumbing the
allocator itself uses, so the working tree is never touched.

It must run **from the host**, against the real coordination point — the mvm
agent sandbox cannot reach the coordination remote, which is why the build could
not do it.

**Do it before scoping anything new in `platform` or `sdlc`.** Both groups now
allocate through the allocator, and both would be handed an ordinal the tree
already holds: `peek spec platform` → `platform/011`, `peek spec sdlc` →
`sdlc/017`, each of which exists on disk. The creation-side halt only catches an
exact *name* collision
([[20260730-spec-creation-halts-only-on-an-exact-name-collision]]), so the
rename would succeed and leave two directories on one ordinal — after the
duplicate record was already published durably. That also poisons this repair,
since the log it reconstructs from would then conflict with the tree.

Verify afterwards that `peek spec platform` → `012` and `peek spec sdlc` → `018`.

Standing detection and repair machinery is separate work
([[20260726-add-an-only-door-verification-sweep-for-the-id-registry]] and
[[20260728-registry-drift-catch-up-has-no-incremental-seed-verb]]); this issue is
only the one-time alignment.

## Resolution (2026-07-31)

Repaired from the host. Two `spec allocate` records appended to `jim/registry`,
each carrying its spec's own issuance date taken from that spec's ledger
(`spec started`), not the repair day:

```
spec allocate platform/011 rename-path-correctness 20260729 jrko
spec allocate sdlc/017 coordinated-spec-identity 20260730 jrko
```

Landed as `b1aedca..19c4328` — an ordinary fast-forward push, which is what the
compare-and-swap is: the commit was parented on the tip read at the start, so a
concurrent writer would have caused a rejection rather than an overwrite. The
diff is the two added lines and nothing else; the `issues.log` blob is carried
through byte-identical.

Verified — the two id surfaces now agree, where the disagreement *was* the
defect:

| group | `peek spec` | `next-id` | `resolve spec` |
|---|---|---|---|
| `platform` | `platform/012` | `012` | `platform/011` |
| `sdlc` | `sdlc/018` | `018` | `sdlc/017` |

A sweep of the remaining groups confirmed the append disturbed nothing: registry
record counts match tree directory counts for `blueprint` (24), `issue` (10),
`platform` (11) and `sdlc` (17), discounting each group's non-allocated
`000-blueprint`.

Two things worth carrying into the next registry repair:

- **Check the byte-prefix property explicitly**, rather than reasoning that an
  append implies it. That prefix relation is precisely what the erosion guard
  tests, so it is the check that predicts whether every clone will accept the
  result.
- **Re-derive the dates from each spec's ledger** rather than trusting a prepared
  procedure. A stale date in a repair record is not detectable later — the keyed
  find-or-allocate lookups read that field.

The retired `jim` group was found to have the same class of gap during the
verification sweep, and is deliberately **not** repaired here: it needs the
vacated-ordinal floor rather than a backfilled allocate record, and it belongs to
[[20260726-emit-rename-split-redirect-records-and-wire-jim-partition-batche]].
