---
title: "Finish coordinated spec identity"
type: bug
group: "sdlc"
id: "018"
status: approved
origin:
  - "docs/specs/sdlc/017-coordinated-spec-identity/spec.md"
  - "docs/specs/sdlc/017-coordinated-spec-identity/review.md"
  - "docs/notes/20260728-id-coordination-issue-grouping.md"
  - "docs/issues/20260730-gate-the-realized-spec-ordinal-and-stop-silent-record-loss.md"
  - "docs/issues/20260730-spec-creation-halts-only-on-an-exact-name-collision.md"
  - "docs/issues/20260730-define-how-a-provisional-spec-dir-resolves-through-the-path-help.md"
  - "docs/issues/20260730-fold-spec-id-sequencing-to-admit-provisional-identities.md"
  - "docs/issues/20260730-the-shared-spec-fold-resolves-group-aliases-twice.md"
  - "docs/issues/20260730-two-defects-in-the-spec-citation-sweep.md"
  - "docs/issues/20260730-close-the-coordinated-spec-identity-fixture-gaps.md"
  - "docs/issues/20260730-document-provisional-spec-identity-and-the-reconcile-surface.md"
  - "docs/issues/20260730-fix-jim-spec-checklist-contradicting-its-provisional-branch.md"
  - "docs/issues/20260730-spec-realize-exhaustion-emits-rows-before-halting.md"
  - "docs/issues/20260730-spec-reconcile-scan-and-id-rewrite-anchor-to-different-regions.md"
  - "docs/issues/20260730-harden-the-spec-realize-path-against-silent-failures.md"
  - "docs/issues/20260728-reconcile-sh-provisional-detection-not-fence-bounded.md"
  - "docs/issues/20260728-reconcile-sh-swallows-the-index-regen-exit-code.md"
---

# 018 Finish coordinated spec identity

## Overview
`sdlc/017` shipped coordinated spec identity complete but not correct: its
post-build review found three critical defects, two security regressions, and a
contradicted high-criticality invariant behind a green 903-case suite. This
spec is `sdlc/017` finishing — its fifteen acceptance criteria actually
holding, each defect fixed together with the fixture that would have caught it.

## Defect Profile
- **Steps to Reproduce (exemplar — the bypassable drift halt, #150):**
  1. Place a crafted record `spec allocate sdlc/18 alpha 20260728` on the
     coordination branch (it is push-writable; the allocator's `have` branch
     re-emits an ordinal verbatim, gated `^[0-9]+$` rather than canonicalized).
  2. Hold a pending `sdlc/P-20260728-alpha` locally, with `018-alpha` already
     present in the tree.
  3. Run the spec realizer (`/jim:spec reconcile` → `--apply`).
- **Actual Behavior:** `ord=18` is used as a path component, a glob, a git
  argument, and frontmatter with no revalidation — the one registry/tree-derived
  token the flow never gates. Occupancy is matched as a literal string, so
  `18-*` passes the existing `018-alpha`: two directories on one numeric
  ordinal, `id: "18"`, exit 0. The durable `moved=` record is then rejected by
  `record_realized`'s own gate and silently dropped, so the provisional→real
  mapping never enters the ledger. No halt, no warning, on either count.
- **Expected Behavior:** the realized ordinal is revalidated like every other
  untrusted token, occupancy is decided numerically, the drift halt that
  `sdlc/017` AC 13/14 promise actually fires on both the realize and creation
  paths, and a rejected durable record is loud.
- **Environment:** jim at `8c2ae74`, suite 903/903 green — every defect below
  is silent to the suite by omission, by a shared assumption, or by
  deliberately reused code.

The full defect set — fourteen issues, all from `sdlc/017`'s post-build review
except the two pre-existing issue-side twins:

| # | Pri | Defect |
|---|---|---|
| 150 | critical | Realized ordinal never revalidated → duplicate-ordinal dirs + silent ledger-record loss (both security regressions) |
| 146 | critical | Path helper composes a fabricated directory for a provisional spec, at five call sites |
| 149 | critical | `spec-id-sequencing` invariant contradicted in two blueprints, unfolded |
| 156 | high | Creation-side halt detects only an exact-name collision |
| 159 | high | Shared fold resolves group aliases twice, durably double-issuing an ordinal |
| 160 | high | Citation sweep: fence tracker is char/length-blind; path-vs-typed pick drops the slug |
| 145 | medium | Nine named fixture gaps |
| 147 | medium | WORKFLOW.md / README.md / spec template still imply a numeric id |
| 148 | medium | `skills/spec/SKILL.md` contradicts itself in four places |
| 157 | medium | Exhaustion emits rows before halting, contradicting its docstring |
| 158 | medium | Scan and rewrite anchor to different regions → silent no-op rewrite |
| 151 | low | Realize-path silent-failure batch (4 items) |
| 133 | low | Twin: issue-side `reconcile.sh` detection/rewrite region mismatch |
| 134 | low | Twin: issue-side `reconcile.sh` swallows the index-regen exit code |

#133/#134 are the same two bugs as #158 and #151 item 3 in the issue-side
realizer — fixing one file and leaving its twin is how the pattern spread, so
both scripts are fixed in one pass.

## Acceptance Criteria
- [ ] Every acceptance criterion of `sdlc/017`
      (`docs/specs/sdlc/017-coordinated-spec-identity/spec.md`) holds against
      the code as this spec leaves it: the review's recorded drift (AC 5),
      partials (AC 7, AC 9), divergences (AC 13, AC 14), and weakly-met lines
      (AC 2, AC 6, AC 10) are each resolved, and each executable criterion is
      evidenced by at least one fixture.
- [ ] A realized ordinal is revalidated at the established id boundary before
      it is used as a path component, a glob, a git argument, or written into
      frontmatter; a non-conforming ordinal halts that identity loudly and
      writes nothing for it. *(External Constraint — the coordination point is
      push-writable, so every registry/tree-derived token passes the single id
      boundary; sourced to `platform/007`'s injection-guard AC via `sdlc/017`
      AC 13.)*
- [ ] Ordinal occupancy is decided numerically on both halves of the contract:
      on the realize path, a padding-variant record (`18` against an existing
      `018-…`) and a bare-`<NNN>` occupant directory both collide and halt; on
      the creation path, with `001-bar` in the tree and absent from the
      registry, binding ordinal `001` halts loudly naming the registry-vs-tree
      drift instead of writing `001-foo`.
- [ ] The allocator reports spec ordinals canonically zero-padded to the
      documented 3-digit form on every branch that emits one, so a `have`
      answer and a `new` answer agree in shape — and two spellings of one
      ordinal are one identity at every site the flow compares ordinals
      (tree occupancy, registry resolve replay, and the realize path's
      find-or-allocate key readback), so a crafted unpadded record can
      neither split a resumed realization from its own prior record nor
      re-open the duplicate-ordinal seam. Fixtured by resuming a realization
      against a log holding an unpadded record. *(External Constraint — the
      ordinal form is the documented project convention; sourced to
      `ARCHITECTURE.md` → Spec Archive.)*
- [ ] A realization whose durable `moved=` mapping is rejected surfaces loudly
      — a warning and a failure status, never a silent drop with exit 0.
- [ ] On a reused-group-name log, no allocator read path — `next-id`, `peek`,
      or realize — reports an ordinal the current group already holds, and no
      path publishes a duplicate record; the fixture covers the reused-name
      log against both `next-id` and realize.
- [ ] Ordinal exhaustion halts before emitting any row in both allocator paths
      (`next-id` and realize), matching the documented contract, and is
      fixtured in both.
- [ ] A provisional spec's artifact paths resolve correctly at every site that
      composes one — the provisional token is honored as the whole directory
      basename, the composed tokens are validated at the composition boundary,
      and no caller (including the plan template's persisted back-reference)
      fabricates a `P-…-<name>` directory. The provisional path shape is
      fixtured; none exists today.
- [ ] Detection and rewrite in both realizers (spec-side and issue-side)
      anchor to the same leading-frontmatter region: a file whose only
      matching identity line sits in the body is never treated as pending, and
      a rewrite that changed nothing is reported as that identity's failure,
      never silent success.
- [ ] Both realizers surface a failed index regeneration — a non-zero regen
      status is reported, never swallowed.
- [ ] The citation sweep treats fenced content correctly — a 4-backtick outer
      fence is not closed by an inner 3-backtick fence, a `~~~` line inside a
      backtick block does not toggle it, and an unclosed fence does not
      silently skip the rest of the file — verified against the 4-backtick
      shapes present in the swept corpus today. A path citation whose group is
      the first path segment keeps its slug rather than becoming a dead link.
- [ ] The realize path cannot silently do the wrong thing where it currently
      can: the rename primitives refuse rather than nest when the target
      appears as a directory late; an absolute spelling of the configured
      specs dir is normalized or rejected at the guard rather than splitting
      tracked/untracked behavior; an uncommitted provisional spec's own-body
      citations are swept, or their staleness is explicitly warned about.
- [ ] The `spec-id-sequencing` invariant is restated through the blueprint
      surface in both the `sdlc` and `jim` blueprints so it covers both
      identity states a bound spec can legitimately hold — a
      coordination-allocator-minted 3-digit ordinal, or a reserved provisional
      token pending realization — naming the allocator as the minting
      mechanism; afterward a `/jim:verify` pass of each group scores the
      invariant as holding. *(External Constraint — blueprints change only
      through their own surface, never a hand edit; sourced to
      `ARCHITECTURE.md` → Core Components → Skills, the blueprint-update
      machinery.)*
- [ ] The user-facing docs describe the shipped world: `WORKFLOW.md`,
      `README.md`, and the spec template document provisional identity and the
      reconcile surface, and `skills/spec/SKILL.md`'s four self-contradictions
      are reconciled — including a refusal-table row for the `fail`
      unreachable-mode carrying the message a developer actually sees and its
      retry guidance.
- [ ] The nine named fixture gaps from #145 are closed, each fixture asserting
      the behavior that would have caught the shipped defect rather than the
      behavior that shipped.
- [ ] Regression test covers the reported scenario: the crafted
      padding-variant record against an occupied tree halts with a non-zero
      exit and no write, on both the realize and creation paths.
- [ ] The full suite passes. A pre-existing fixture is modified only where it
      encoded a corrected defect's behavior, and each such modification is
      named in the build record. *(External Constraint — adapted from
      `sdlc/017` AC 15: the allocator's other shipped behaviors hold
      unchanged; the adaptation is scoped by this spec's no-migration
      posture.)*

## Out of Scope
- **Registry rename/redirect record emission**, including lifting the
  realization `moved=` mappings into registry redirect records — the
  rename-emitting follow-on's charter (#143, #113).
- **A pending provisional identity when its group moves** — realization across
  a group rename, partition split/merge with pending provisional specs, and
  the cross-parent move primitive's `P-` gate (#152, #154). Same follow-on.
- **Registry drift detection and repair** — the only-door sweep, the
  incremental catch-up verb, duplicate durable-id detection (#116, #130,
  #136), and the retired `jim` group's registry absence, which stays
  deliberately unrepaired.
- **The hardening-build leaves:** the tree-scan verb's group/kind collision
  (#123), `run.sh` honoring only its first filter argument (#153), and
  single-sourcing the provisional identity grammar (#155).
- **Migration or compatibility shims of any kind.** The coordination system
  has no external users yet: behavior corrections land outright, and a rough
  edge that needs a manual fix during the remaining transition is acceptable.
- **New capability.** This spec adds nothing beyond `sdlc/017`'s recorded
  contract.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point
to evaluate, not a directive — except where marked pre-decided, which records
a fork the developer has already settled.*

### Insight 1: One shared numeric ordinal-occupancy predicate (pre-decided)

- **Relates to AC:** *"Ordinal occupancy is decided numerically on both halves
  of the contract"* (AC 3)
- **Surfaced as:** the fork pre-decided in the grouping note: #150 and #156
  are the same missing check on two paths.
- **Levelled-up requirement (already in the ACs):** the AC fixes the
  observable — padding variants and bare-ordinal occupants collide on both
  paths.
- **Deflection reason:** Delegation — predicate placement and shape are the
  architect's.
- **Architect note:** one shared "does any sibling hold this ordinal,
  numerically?" predicate consumed by both the creation path and the realize
  path, comparing under `10#$ord`, with the allocator's `have` branch
  normalized to `%03d` (AC 4) so the asymmetry that feeds the bypass is gone
  at the source. A shared predicate is what stops a third path from being
  missed later. Sequencing: this lands first — it makes #151's silent ledger
  drop unreachable and gives #145's first two fixtures something to assert;
  the creation-side halt rides the same predicate immediately after.
- **Routing hint:** Pre-decided by developer — implement as noted.

### Insight 2: Teach the path helper a provisional form (pre-decided)

- **Relates to AC:** *"A provisional spec's artifact paths resolve correctly
  at every site that composes one"* (AC 8)
- **Surfaced as:** the fork pre-decided in the grouping note: extend
  `cmd_path` rather than declare provisional paths read-only.
- **Levelled-up requirement (already in the ACs):** the AC fixes the
  observable — no site fabricates a `P-…-<name>` directory.
- **Deflection reason:** Delegation — call-site mechanics are the architect's.
- **Architect note:** a provisional form that takes the token as the whole
  basename, mirroring the three-argument form `mv-spec-id` grew for the same
  reason, validating `id`/`name` at composition. The rejected alternative —
  "provisional paths are read, never composed" — leaves five call sites each
  remembering an undocumented rule, one of which (`/jim:research`, auto-spawned
  by `/jim:plan`) fires unattended. The plan template's `{id}-{name}`
  back-reference needs the same treatment either way.
- **Routing hint:** Pre-decided by developer — implement as noted.

### Insight 3: Restate the invariant to admit both identity states (pre-decided)

- **Relates to AC:** *"The `spec-id-sequencing` invariant is restated through
  the blueprint surface in both blueprints"* (AC 13)
- **Surfaced as:** the fork pre-decided in the grouping note.
- **Levelled-up requirement (already in the ACs):** the AC fixes the
  observable — both blueprints admit both states and a verify pass scores the
  invariant holding.
- **Deflection reason:** Delegation — the fold goes through
  `/jim:blueprint --from-review` for `sdlc` and a separate pass for `jim`
  (outside this group), never a hand edit.
- **Architect note:** restatement direction: minted by the coordination
  allocator, either a 3-digit zero-padded ordinal unique within its group or a
  reserved provisional token pending realization. The `jim` copy needs its own
  pass since it sits outside `sdlc/017`'s review scope.
- **Routing hint:** Pre-decided by developer — implement as noted.

### Insight 4: Fold resolution contract — resolve exactly once

- **Relates to AC:** *"Group aliases are resolved exactly once on every
  allocator read path"* (AC 6)
- **Surfaced as:** #159's two candidate fixes — the fold accepts a
  pre-resolved group and skips its own resolution, or callers pass the raw
  group and the fold owns it.
- **Levelled-up requirement (already in the ACs):** the AC fixes the
  observable — no read path reports an already-taken ordinal on a
  reused-group-name log.
- **Deflection reason:** Delegation — which layer owns resolution is the
  architect's; the defect is two layers each believing the other did not
  resolve, so the chosen contract must be explicit in the docstring.
- **Architect note:** the shared fold was the right design (it is why the
  realize path inherited the defect instead of adding a second one); the fix
  belongs in the fold's contract, not in either caller.
- **Routing hint:** Architect to decide.

### Insight 5: Reuse an existing fence tracker

- **Relates to AC:** *"The citation sweep treats fenced content correctly"*
  (AC 11)
- **Surfaced as:** #160 — jim already ships two correct trackers (the issue
  migrator's and the index scanner's), each recording the opening marker and
  closing only on a ≥-length run of the same character; the sweep's is a
  weaker third implementation.
- **Levelled-up requirement (already in the ACs):** the AC fixes the
  observable fence semantics.
- **Deflection reason:** Delegation — which tracker to reuse, and how to share
  it, is the architect's.
- **Architect note:** prefer reuse over a third implementation; if sharing
  proves awkward across skill script boundaries, the `SYNC:`-comment +
  byte-identity-fixture discipline is the repo's precedent for a knowingly
  duplicated check.
- **Routing hint:** Architect to decide.

## Open Questions
- [x] ~Run as a build or a spec?~ → A spec: #150 is two security regressions
  and a build has no `/jim:sec` gate; #149 is a blueprint write across two
  groups; the design forks needed a decision surface (pre-paid in scoping).
- [x] ~Author new ACs or inherit `sdlc/017`'s?~ → Inherit: this spec's
  Definition of Done is 017's fifteen ACs actually holding, each evidenced by
  a fixture. The drift stays attached to the spec that drifted.
- [x] ~Encode the completion-gate practices (investigator fan-out,
  living-intent sensor) in this spec?~ → No: the review phase's default
  behavior runs both; `sdlc/017`'s miss was a session anomaly, not a config
  gap.
- [x] ~Any compatibility obligations toward existing registry records or
  consumers?~ → None: the coordination system has no external users yet, so
  corrections land outright with no migration code.
