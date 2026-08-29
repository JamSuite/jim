---
id: 20260726-add-an-only-door-verification-sweep-for-the-id-registry
num: 116
title: "Add an only-door verification sweep for the id registry"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-26T19:02:01Z
updated: 2026-08-02T01:07:02Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

The registry only prevents collisions if allocation is the **sole** path to an ID. Nothing stops someone hand-creating `docs/specs/core/007-foo/` or an issue ordinal without the allocator (old habits, non-jim tooling); the allocator later issues `007` and the collision returns.

Add a mechanical, `jim:verify`-style check (CI-able, deterministic floor) that every spec directory and issue ordinal on the coordination branch has a matching registry record. Rogue entries get adopted into the registry or flagged. Allocation-is-the-only-door is enforced by detection, not trust.

Follow-on to `platform/007` (foundation), gap G2; `platform`-group (verify DNA).

## Scoping corrections (2026-08-01)

Recorded while building Spec E context; anchors as of this date.

- **"On the coordination branch" is the wrong preposition.** That branch holds
  only the per-kind logs (`platform/007` Out of Scope) — no spec or issue
  artifact lands there. The sweep reads the *working tree's* spec directories
  and issue frontmatter against the coordination branch's logs.
- **The enumerators already exist.** `alloc_seed_derive_specs` /
  `alloc_seed_derive_issues` (`skills/file/scripts/jimalloc.sh:792`, `:859`)
  walk exactly the artifact set the sweep must compare, boundary gates
  included. Both sides of every ordinal comparison must canonicalize
  (`alloc_canon_specid`), or a hand-authored unpadded ordinal reads as drift.
- **Four artifact classes are legitimately recordless**, and the sweep must
  name each as non-coverage rather than flag it or stay silent: the reserved
  `000-blueprint` slot; pending provisional dirs (`P-<date>-<slug>`, which by
  design never enter the registry); retired / partition-source groups (the
  `jim` group's 52 vacated identities —
  [[20260726-emit-rename-split-redirect-records-and-wire-jim-partition-batche]]);
  and ids appearing only as rename sources (same issue).
- **The "rogue entries get adopted" clause is #130's append by construction.**
  Detect-only sweep with the catch-up verb as the repair
  ([[20260728-registry-drift-catch-up-has-no-incremental-seed-verb]]), or one
  verb with preview/apply modes, is the genuine scoping fork — they are not
  independent features.
- **Two hazards if this rides `/jim:verify`:** "registry" there already means
  the operator command registry (`verify_command_*`), and the registry rung
  maps exit 0 / non-zero / crash → holds / violated / failed, which collides
  with jimalloc's rc 1 doubling as "coordination point unreachable". Exit
  codes must keep "drift found" distinct from "could not check".
- **Nothing for verify to judge today:** the platform blueprint's invariant
  table has no entry for append-only growth, erosion, or the only-door
  property itself. What this sweep enforces is currently invisible to
  `/jim:verify`; folding an invariant in belongs at Spec E's completion gate.

## Resolution (2026-08-02)

Shipped as `jimalloc.sh sweep` in `platform/012`. It compares every spec
directory and issue file against the registry and reports each finding under a
named class — `missing-record`, `mismatch`, `duplicate-ordinal`,
`duplicate-id`, `reserved-slot`, `unreadable-record` — with records that have no
tree counterpart reported as *informational* rather than drift, since another
clone allocating first is a legitimate state.

The design surface this issue predicted — the non-coverage report — is where the
work went. The sweep names reserved blueprint slots, pending provisionals,
groups outside coordination entirely, ids known only as rename sources, records
too malformed to identify, and (when the coordination point could not be
refreshed) the tip it swept plus the fact that it is last-seen state. Exit codes
keep clean, drift and could-not-check apart, so a check that could not run is
never read as a pass — including the case where the tree root itself is absent.

The "adopt" clause resolved as this issue anticipated: it *is* the catch-up
verb's append, and the two share one classification core so detection and repair
cannot disagree about what is missing.

Verified on jim's own registry: 64 spec records vs 64 tree dirs across 4 groups,
203 issue records vs 203 files, zero drift, with the retired `jim` group named
as uncovered.
