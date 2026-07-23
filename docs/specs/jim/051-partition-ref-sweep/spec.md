---
title: "Partition ref sweep mis-rewrites typed refs on renumbering moves"
type: bug
group: "jim"
id: "051"
status: approved
origin:
  - "docs/issues/20260723-fix-ripple-engine-sweep-order-for-renumbered-self-refs.md"
  - "docs/specs/jim/048-partition-merge/review.md"
---

# 051 Partition ref sweep mis-rewrites typed refs on renumbering moves

## Overview

On a renumbering partition move (split or merge under `spec_migration: rewrite`), the materialize sweep rewrites typed `group/NNN` refs inside moved spec bodies to wrong targets — stale numbers on renumbered refs, and (split extraction arm) mispointed group names on refs to specs that never moved. The archive silently rots: wrong refs may collide with real spec ids, so no dangling-ref detection can surface them.

## Defect Profile

- **Steps to Reproduce:**
  1. In a git repo, track a moved-body fixture containing the typed ref `src/002`, with the renumber remap `src/002 → target/008` (the renumber-append shape both split and merge produce).
  2. Run the materialize sweep in its documented order: `rewrite-identity src target <file>`, then `rewrite-refs <remap> <file>`.
  3. Observe the ref. — *Manifestation 1.*
  4. For the split extraction arm: track a fixture moved to a fresh child whose body cites `old/005`, a spec that **stays in the continuing remainder**. Run the two sweeps in **either** order.
  5. Observe the ref. — *Manifestation 2.*
- **Actual Behavior:**
  - *Manifestation 1 (split + merge, documented order):* the ref reads `target/002` — the number-preserving identity pass rewrites the token first, so the remap key `src/002` no longer matches and the renumber never lands. `target/002` may collide with a real pre-existing spec of the target group.
  - *Manifestation 2 (split extraction arm, order-independent):* the ref reads `child/005` — the identity pass group-renames a ref whose target never left the remainder. Reordering the sweeps does **not** fix this: the remap's remainder row (`old/005 → old/005`) is a no-op, after which the identity pass still clobbers the token.
- **Expected Behavior:** After materialize, every typed `group/NNN` ref in a moved body points at the referenced spec's actual post-materialize id: renumbered refs carry the remapped group *and* number (`target/008`); refs to remainder specs are left untouched (`old/005`).
- **Environment:** jim `feat/blueprint` @ 94fee17; `skills/partition/scripts/jimpartition.sh` (`rewrite-identity`, `rewrite-refs`); the split (047) and merge (048) materialize flows in `skills/partition/SKILL.md` and `references/partition-methodology.md`. Root cause: the identity pass's blanket number-preserving typed-ref rewrite is only sound when no renumber remap exists (rename, 043); when a remap exists, typed refs belong to the reference sweep exclusively. Both manifestations reproduced empirically on 2026-07-23; surfaced by the 048 post-build review (pre-existing, latent since 047).

## Acceptance Criteria

- [ ] After a renumbering split or merge materialize under `rewrite`, every typed `group/NNN` ref inside a moved spec body points at the referenced spec's post-materialize id — group and number both agree with the gate-presented remap.
- [ ] On a split extraction arm, a moved body's typed ref to a spec that remains in the continuing remainder still points at that remainder spec after materialize.
- [ ] Rename (043) behavior is unchanged: typed refs re-point group-only, number preserved, and existing rename tests pass without modification.
- [ ] The documented sweep order in the split and merge materialize flows agrees with what the engine actually guarantees — no prose/mechanism divergence remains.
- [ ] Regression test covers the reported scenario: fixtures over both the split and merge arms exercising (a) a renumbered intra-group ref in a moved body and (b) an extraction-arm ref to a remainder spec.

## Out of Scope

- **Archive audit / repair** of previously materialized runs — no renumbering split or merge has corrupted this repo; fix-only per scoping decision.
- **A post-materialize ref-integrity tell** (verifying every typed ref points at an existing spec dir) — declined; it cannot catch mispoints at real ids, which is the dangerous case.
- **Rename (043)** — its number-preserving typed-ref rewrite is correct (no renumbering) and stays as-is.
- **`forward` / `immutable` modes** — no reference is edited in these modes by design; the ledger remap remains the bridge.
- **Refs dangling before the move** (typed refs to ids absent from the remap) — degrade unchanged; no new handling.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the architect — not requirements, not exclusions. Treat each as a starting point to evaluate, not a directive.*

### Insight 1: Reorder the sweeps (reference sweep before identity rewrite)

- **Relates to AC:** *"every typed ref points at the post-materialize id"* (AC #1)
- **Surfaced as:** issue #87's primary proposal — run the number-changing reference sweep before the number-preserving identity rewrite.
- **Levelled-up requirement (already in the ACs):** post-materialize ref correctness, stated as archive state rather than sweep mechanics.
- **Deflection reason:** Delegation (mechanism choice is the plan's).
- **Architect note:** Empirically fixes manifestation 1 but **not** manifestation 2 — reordering alone is an incomplete fix. May still be worth adopting as part of the full fix.
- **Routing hint:** Architect to decide.

### Insight 2: Scope the identity rewrite away from remap-covered typed refs

- **Relates to AC:** *"a moved body's ref to a remainder spec still points at that remainder spec"* (AC #2)
- **Surfaced as:** issue #87's alternative proposal — skip typed `group/NNN` refs in the identity pass when the remap will re-point them.
- **Levelled-up requirement (already in the ACs):** remainder refs survive materialize untouched.
- **Deflection reason:** Delegation (mechanism choice is the plan's).
- **Architect note:** The extraction-arm evidence makes some form of remap-aware scoping *necessary*, not optional — candidate shapes: a skip-typed-refs flag on the identity verb, passing the remap in, or restricting the identity pass to bare-token/path kinds during split/merge materialize. Must preserve rename's typed-ref rewrite (no remap exists there). A side benefit: the two verbs become order-independent for typed refs, removing fragility from the prose-documented sweep order. Verify whether `renumber-map` emits remainder rows as identity mappings — it determines whether "remap-covered" can be computed from the remap file alone.
- **Routing hint:** Architect to decide.

## Open Questions

- [x] ~Priority of the underlying issue (#87)~ → bumped medium → high: manifestation 2 silently mispoints at real spec ids in a shipped surface.
- [x] ~Scope extras (archive audit, ref-integrity tell)~ → declined; fix-only.
