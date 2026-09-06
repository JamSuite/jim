---
id: 20260802-halt-one-identity-not-the-batch-on-a-contradicted-realize-key
num: 203
title: "Halt one identity, not the batch, on a contradicted realize key"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [allocator, reconcile, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-02T00:47:12Z
updated: 2026-08-02T06:52:07Z
origin: docs/specs/platform/012-registry-integrity-and-drift/review.md
---

## Description

## Description

The spec-side realize path halts the **whole batch** when two registry records
claim the (group, slug, date) triple a pending identity resolves against. The
prior behavior halted only the offending identity and let the rest of the batch
land — which is what the consumer still documents (`skills/spec/scripts/reconcile.sh`
header: "Other identities in the batch are unaffected"), and what its fixture in
`tests/specreconcile.sh` asserts for the neighbouring case.

The halt itself is correct and deliberate: two claimants make the readback
ambiguous, and answering from the later record is how a resumed realization
adopts an ordinal that is not its own. What regressed is the blast radius.

The triggering condition is reachable through ordinary use, not only by a hostile
push: the derivation stamps **today's date** on every spec record it derives, and
the ordinal dedupe checks ordinals rather than slugs. So bootstrapping a group
that holds two specs with the same title-slug (`003-auth-fix`, `012-auth-fix`)
mints two records keyed on one triple. A provisional spec issued in that group on
that same day then keys onto the pair, and every pending identity in the batch is
refused — not just that one.

Two further gaps make the state hard to leave:

- the integrity sweep cannot name it. The classifier keys duplicate detection on
  the canonical spec id, so a duplicated *triple* raises no finding;
- the catch-up verb appends only what is missing, so nothing clears it.

## Proposed action

Two decisions, ideally settled together:

1. **Blast radius.** Return a per-identity `blocked` state from
   `alloc_reconcile_realize_spec` instead of failing the whole call, so an
   ambiguous identity is refused while its neighbours realize — restoring the
   consumer's documented contract. This changes the realize row grammar
   (`<pending>\t<id>\t<new|have>`), so both consumers move together.
2. **Detection.** Give the sweep a class for a duplicated realize key, so a
   condition that blocks realization is visible before someone hits it.

## Provenance

Surfaced by the post-build review of the registry-integrity spec
(`docs/specs/platform/012-registry-integrity-and-drift/review.md`, Finding 8),
which traced the reachable path through the derivation's date stamping.

## Resolution (2026-08-02)

Fixed in the pre-B build. Both realize paths — the spec side's duplicated
(group, slug, date) triple and the issue side's duplicated durable id, which
carried the same batch-wide halt — now refuse the contradicted identity alone,
as a `<pending>\t-\tblocked` row with the claimants named on stderr, while the
rest of the batch lands. Both consumers surface the refusal loudly per
identity (the spec realizer applies nothing for it, the issue realizer leaves
`num:` provisional), and a blocked identity consumes no ordinal, so a repaired
registry realizes it later with no gap burned.

Detection landed with it: the realize-claim rule is extracted into one shared
reader (`alloc_spec_claim_keys`) and the sweep names ambiguous keys under a
`realize hazards` section — an advisory rather than drift, because both
records are individually valid and the allocator itself can mint the pair, so
a healthy registry keeps its clean exit and the configured verify mapping
stays honest. Commits `fc5468b`, `443344e`, `46dd893`; fixtured at the
function, builder, sweep, and both-consumer levels.
