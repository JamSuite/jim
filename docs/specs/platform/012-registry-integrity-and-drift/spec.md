---
title: "Registry integrity and drift"
type: feature
group: "platform"
id: "012"
status: approved
origin:
  - "docs/notes/20260728-id-coordination-issue-grouping.md"
  - "docs/issues/20260726-add-an-only-door-verification-sweep-for-the-id-registry.md"
  - "docs/issues/20260728-registry-drift-catch-up-has-no-incremental-seed-verb.md"
  - "docs/issues/20260729-detect-duplicate-durable-ids-instead-of-silent-last-wins.md"
  - "docs/issues/20260801-re-validate-the-origin-registry-tip-before-git-interpolation.md"
  - "docs/issues/20260727-normalize-seed-reserved-slot-skip-and-spec-ordinal-magnitude.md"
---

# 012 Registry integrity and drift

## Overview

Make the ID registry's health checkable and its drift repairable: a read-only
integrity sweep that verifies the working tree and the registry agree about
every spec and issue identity, and an incremental catch-up that appends the
records a non-empty registry is missing — each reporting what it did not cover
as loudly as what it found.

## Problem Statement

The registry prevents id collisions only while it faithfully represents the
repository, and nothing today detects or repairs divergence between the two. A
spec directory or issue created outside the allocator — old habits, non-jim
tooling, a partition that rewrote identities — leaves the registry answering
below the tree, so the next allocation hands out an id the project already
owns. Both live instances of that state were repaired by hand-editing the
shared coordination branch, because the bootstrap refuses a log that already
has records: there is no sanctioned repair path. And when two registry records
claim one identity, the read path silently resolves to whichever appears last,
so the one place a landed collision would be caught is exactly where it stays
invisible.

## User Stories

- As a jim developer, I can run a registry integrity check in CI so that
  tree-vs-registry drift is caught before an already-owned id is reissued.
- As an operator repairing or adopting a drifted project, I can preview and
  then apply an incremental registry repair so missing records land without
  hand-editing the shared coordination branch.
- As a developer reading a check's clean report, I can see exactly what it
  covered and what it could not, so "clean" always means "checked and sound",
  never "not looked at".
- As a developer resolving an id citation, I am told when the registry holds
  contradictory claims for that identity instead of silently receiving the
  wrong referent.

## Acceptance Criteria

- [ ] **AC 1** A read-only sweep compares every spec directory and issue
  ordinal in the working tree against the coordination branch's records and
  reports each finding under a named drift class. It never mutates the
  registry, the tree, or any local state beyond its own report.
- [ ] **AC 2** Drift classes distinguish at minimum: a tree identity with no
  registry record (the collision risk); a tree/registry pair that disagree
  about the identity they share (mismatch); and registry-internal
  contradictions — duplicate ordinal, duplicate durable id, a reserved-slot
  record. A registry record with no tree counterpart is reported as
  informational, not drift: allocation from another clone and a spec abandoned
  after binding are both legitimate states.
- [ ] **AC 3** The sweep names its non-coverage explicitly: the reserved
  blueprint slots, pending provisional directories, retired or
  partition-source groups, ids known only as rename sources, and — when the
  coordination point could not be refreshed — the registry tip it swept and
  the fact that it is last-seen state. A clean report over a degraded scope is
  distinguishable at a glance from a clean report over everything.
- [ ] **AC 4** The sweep reports coverage denominators: how many tree
  identities and how many registry records it checked, per kind.
- [ ] **AC 5** The sweep's exit status keeps three outcomes distinguishable —
  clean, drift found, could-not-check — so a CI consumer never reads "the
  check could not run" as either a pass or a finding.
- [ ] **AC 6** When the coordination point is unreachable, the sweep still
  runs against the last-fetched registry state and names the staleness per
  AC 3; it does not refuse.
- [ ] **AC 7** A catch-up appends the records missing from a non-empty log,
  derived from the collection the same way the bootstrap derives them:
  preview by default, an explicit apply gate, and the append landing as one
  atomic commit under the same compare-and-swap and erosion discipline as an
  allocation (external constraint: the registry publish contract,
  `docs/specs/platform/007-id-coordination-allocator/spec.md` and
  `platform/008`'s seed). The preview renders each record it would append
  verbatim — never a bare count — and apply's output names the records it
  actually appended rather than echoing the preview, since the append
  recomputes against the current registry tip.
- [ ] **AC 8** Catch-up is idempotent and append-only: re-running after a
  clean apply is a no-op, and no existing record is ever rewritten,
  reordered, or removed.
- [ ] **AC 9** On a mix of appendable gaps and unrepairable drift (the
  mismatch class), apply lands the clean records, names every finding it
  could not repair, and exits non-zero — a partial repair never reads as a
  clean run.
- [ ] **AC 10** Catch-up never invents identity data: appended records derive
  from the tree artifacts (an issue's own recorded creation date where
  present), and their provenance marker distinguishes a catch-up append from
  both the bootstrap and a live allocation.
- [ ] **AC 11** A duplicate identity in the registry is a detected, reported
  condition on the read path: resolving a citation whose identity carries
  multiple claims reports the contradiction rather than silently answering
  from the last record. Holds for issue durable ids and spec ordinals alike,
  and for realization's already-realized lookup.
- [ ] **AC 12** The origin registry tip read back from the remote is
  revalidated at the id boundary before it reaches any git command, matching
  the discipline every other untrusted token on this surface already crosses
  (external constraint: the platform blueprint's `ref-validation` invariant,
  `docs/specs/platform/000-blueprint/spec.md`).
- [ ] **AC 13** The platform blueprint carries a registry-integrity invariant
  at this spec's completion gate — folded through its own write surface,
  never a hand edit (external constraint: the blueprint-write convention,
  `ARCHITECTURE.md` → Data Stores) — wired so `/jim:verify` can run the
  sweep as an operator-configured check with no verify engine change.
- [ ] **AC 14** Every drift class, every informational class, and every named
  non-coverage class is exercised by a fixture that discriminates: removing
  the detection makes the fixture fail (external constraint: adopted
  practices 5 and 7, `docs/notes/20260728-id-coordination-issue-grouping.md`
  § Adopted practice — new guards' fixtures are mutation-tested before being
  trusted).
- [ ] **AC 15** Every token either verb echoes into a report or preview is
  revalidated at the id boundary or sanitized before emission, so a crafted
  registry record can neither forge nor suppress report lines (external
  constraint: the untrusted-content handling posture, `ARCHITECTURE.md` →
  Security Considerations).
- [ ] **AC 16** The shared derivation treats any zero-valued ordinal
  directory (`0-`, `00-`, `000-`-prefixed alike) as the reserved blueprint
  slot — skipped, never derived into a record — so neither the bootstrap nor
  the catch-up can mint the reserved-slot records the sweep classifies as
  drift. Closes the remaining half of #121 (the magnitude half shipped with
  `platform/011`).
- [ ] **AC 17** The new verbs are operator-discoverable without a new skill
  surface: the script's own usage documents both, and README's and
  WORKFLOW's command tables carry sweep and catch-up rows at this spec's
  completion. The in-session path is AC 13's verify wiring; the catch-up
  deliberately remains a hand-run script verb (the prefix-migration
  precedent).

## UI Mockup

Sweep report shape (verb and class names illustrative, not binding):

```
$ <sweep>
sweep: registry @ a1b2c3d (refreshed)     | (last-seen; refresh failed)
  specs:  63 records vs 63 tree dirs, 4 groups checked
  issues: 196 records vs 196 files checked
  drift:
    missing-record   spec   core/007   dir core/007-cache has no record
    mismatch         spec   ui/012    tree ui/012-nav, registry ui/012-navbar
    duplicate-id     issue  20260801-x  claimed by records #44 and #171
  info:
    record-without-tree  spec core/009  allocated elsewhere or unwritten
  not covered:
    reserved slots (5) · pending provisionals (1) · retired groups (jim) ·
    rename-source-only ids (0)
```

## Out of Scope

- **Rename/redirect record emission, and the retired `jim` group's 52-ordinal
  backfill.** Both are Spec B's charter (#113): the backfill's raw material is
  the frozen rename-record grammar, which this spec neither emits nor
  parses beyond what the resolver already does. The sweep names retired
  groups as uncovered; it does not repair them.
- **Automatic repair of mismatch-class drift.** Reported, never auto-resolved
  — a mismatch means tree and registry disagree about history, and choosing a
  winner is an operator decision.
- **Record provenance and authorization.** The sweep verifies tree↔registry
  *consistency*, never that a record was produced by the allocator: a
  well-formed record fabricated by anyone with push access to the
  coordination branch satisfies it — the erosion guard's accepted residual,
  unchanged. The primary control remains coordination-branch protection,
  whose team-setup documentation is the open #118.
- **Any `/jim:verify` engine or skill change.** The AC 13 invariant rides the
  existing operator-configured check machinery.
- **Batch-CAS candidate allocation (Spec D) and issue content placement
  (Spec F).**
- **Erosion-guard changes, coordination-branch protection docs (#118), and
  allocator read-path performance (#142).**

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point
to evaluate, not a directive.*

### Insight 1: Catch-up as a batch-publish builder

- **Relates to AC:** *"append as one atomic commit under the same CAS and
  erosion discipline as an allocation"* (AC 7)
- **Surfaced as:** pre-spec analysis — the bootstrap and both reconcilers were
  consolidated onto the shared batch publish (`alloc_publish`,
  `skills/file/scripts/jimalloc.sh:1615`), which already provides the in-loop
  erosion re-check on both logs, tier CAS, bounded retry, and baseline
  arming; the only thing catch-up bypasses is the seed builder's empty-log
  precondition (`:1695`).
- **Levelled-up requirement (already in the ACs):** the *guarantees* (atomic,
  CAS-guarded, erosion-checked, idempotent) are the ACs; the shared-builder
  route is how to get them cheaply.
- **Deflection reason:** Delegation
- **Architect note:** derive via the seed's own enumerators
  (`alloc_seed_derive_specs` / `_issues`) and subtract records already
  present, canonicalizing both sides (`alloc_canon_specid`) so a padding
  variant is one identity. Decide the rule for a group whose spec records
  exist but whose `group allocate` record is absent, and the spec-record
  date stamp (the seed stamps today; the 2026-07-31 hand repair carried
  issuance dates; dates are advisory by platform/007's own contract).
- **Routing hint:** Architect to decide

### Insight 2: Sweep enumeration and the record-without-tree class

- **Relates to AC:** *"compares every spec directory and issue ordinal in the
  working tree against the coordination branch's records"* (AC 1, AC 2)
- **Surfaced as:** the enumerators already exist (the seed derivation walks
  exactly this artifact set, boundary gates included); and #116's original
  wording "on the coordination branch" is the wrong preposition — the branch
  holds only the logs, so the sweep reads the working tree against them
  (corrected on the issue 2026-08-01).
- **Levelled-up requirement (already in the ACs):** AC 2's
  informational-not-drift classification: a record without a tree counterpart
  is normal distributed lag (another clone allocated first) or an ordinal
  deliberately burned by an abandoned binding — flagging it as drift would
  make every multi-clone project permanently dirty.
- **Deflection reason:** Delegation
- **Architect note:** keep the enumerators' *filesystem* walk (not
  `git ls-files`) as the tree-enumeration source, and name the choice: an
  allocated-but-uncommitted spec directory must read as tree-present, or the
  sweep miscalls its own registry record as record-without-tree — demonstrated
  live on 2026-08-01, when this spec's directory was allocated, realized, and
  swept while still untracked.
- **Routing hint:** Architect to decide

### Insight 3: Exit-code contract must serve two consumers

- **Relates to AC:** *"exit status keeps clean, drift found, and
  could-not-check distinguishable"* (AC 5)
- **Surfaced as:** `/jim:verify`'s operator-check rung maps exit 0 → holds,
  non-zero → violated, crash → failed (`skills/verify/SKILL.md`, operator
  registry contract), while the allocator's existing convention uses rc 1
  for every hard failure including "coordination point unreachable".
- **Levelled-up requirement (already in the ACs):** three distinguishable
  outcomes; the mapping onto verify's rung is the constraint that shapes
  which numbers mean what.
- **Deflection reason:** Constraint-Sourcing — external constraint, sourced
  to `skills/verify/SKILL.md` (registry-check outcome mapping).
- **Architect note:** also mind the vocabulary hazard: inside `/jim:verify`,
  "registry" already means the operator command registry
  (`verify_command_<name>`) — name the invariant and its configured check to
  avoid the collision.
- **Routing hint:** Architect to decide

### Insight 4: The origin-tip fix has one locus

- **Relates to AC:** *"the origin registry tip is revalidated before it
  reaches any git command"* (AC 12)
- **Surfaced as:** the unvalidated value lives in `alloc_origin_tip`
  (`skills/file/scripts/jimalloc.sh:1012-1026`); both consumers call it, so
  validating inside the function covers every interpolation site. The
  discipline to mirror is `jimledger.sh resolve_head` — git's own output
  re-crosses `jimfile.sh valid-id` before reuse. Anchor detail on issue #185
  (2026-08-01 addendum).
- **Deflection reason:** Delegation
- **Routing hint:** Architect to decide

### Insight 5: Duplicate detection has three sites, not one

- **Relates to AC:** *"holds for issue durable ids and spec ordinals alike,
  and for realization's already-realized lookup"* (AC 11)
- **Surfaced as:** the last-wins shape exists at three read-path sites —
  the issue resolver, the spec resolver's replay anchor, and the realize
  path's already-realized map. Anchors recorded on issue #136 (2026-08-01
  addendum). The seed already halts on both duplicate classes; the read path
  mirrors neither.
- **Deflection reason:** Delegation
- **Routing hint:** Architect to decide

## Open Questions

- [x] ~Does #121's reserved-slot fix land before this spec, or does catch-up
  inherit it?~ → folded into this spec as AC 16: the derivation half is the
  write side of the reserved-slot rule AC 2 makes load-bearing, and it lives
  in the function this spec already touches. #121's remaining half rides
  here.
- [x] ~Where does the operator-facing documentation live?~ → no new skill
  (AC 17): the script's usage plus README/WORKFLOW rows; in-session access
  is the AC 13 verify invariant; catch-up stays a deliberate hand-run verb
  per the prefix-migration precedent.
- [x] ~Detect/repair split~ → two verbs: a read-only, CI-able sweep and a
  separate preview-then-apply catch-up.
- [x] ~`/jim:verify` integration~ → blueprint invariant wired as a configured
  check only; no engine code.
- [x] ~Retired-group backfill~ → named as uncovered; the backfill rides
  Spec B, whose record grammar it is.
- [x] ~Offline sweep behavior~ → runs against last-seen state with the
  staleness named; apply still requires reachability.
- [x] ~Partial repair semantics~ → append the clean records, name the rest,
  exit non-zero.
