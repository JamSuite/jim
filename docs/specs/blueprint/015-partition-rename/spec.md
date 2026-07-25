---
title: "Partition group rename"
type: feature
group: "blueprint"
id: "043"
status: approved
origin:
  - "docs/brainstorms/20260711-partition-migrate-capabilities.md"
---

# 043 Partition group rename

## Overview

`/jim:partition` gains a `rename` verb — a preflight-guarded, single-gate
operation that migrates a spec group's identity across the partition's living
artifacts and proves the result, built on a classified ripple engine that the
future `split` and `merge` verbs will reuse.

## Problem Statement

No rename surface exists anywhere in jim. When a group's name stops matching
its domain language, the only path is improvisation through map-tier update
machinery that models the event as drop-group + add-group: the ripple set
(sibling blueprint faces, dotted requires keys, prose and check-parameter
mentions, spec directories, in-flight wip dirs) is discovered incrementally
across multiple gate rounds and post-write reconcile findings; commit
choreography is re-derived by hand; in-flight artifacts survive the move by
luck rather than by contract; and the durable ledger record misdescribes what
happened. The partition doctrine says the map is the authoritative partition —
but its own surface cannot express the most basic partition evolution: a group
whose name changes while its meaning continues.

## User Stories

- As a developer maintaining a multi-group jim project, I can rename a spec
  group in one gated operation so that the partition keeps speaking the
  domain's current language without multi-round improvised edits.
- As that developer, I choose at the gate whether the code directory moves in
  the same operation or stays put for a normal-workflow change, so that a
  documentation-tier operation never forces unreviewed code edits on me.
- As a developer auditing project history, I can read a rename as a
  first-class rename event in the ledger, so that the durable record
  describes the true event rather than a fictional drop-and-add.
- As jim's maintainer implementing `split`/`merge` later, I can consume the
  rename's classified ripple output as a stable contract, so that the
  follow-on verbs build on the engine rather than beside it.

## Acceptance Criteria

**Surface**

- [ ] 1. `/jim:partition rename <old> <new>` is routed as a peer token
  alongside the existing mode tokens (`greenfield` / `repartition` / `path` /
  `directory`). No other new verbs are introduced.

**Preflight**

- [ ] 2. Preflight refuses with a named reason — writing nothing — when: the
  project has no context map; `<old>` is not a mapped group; `<new>` is not a
  valid group slug; `<new>` collides with an existing mapped group or an
  existing spec-group directory; or `<old>`'s `000-blueprint` is absent.
  Refusals for a missing map or blueprint point at the partition/blueprint
  surface that establishes the missing artifact.
- [ ] 3. A dirty working tree triggers a warn-and-confirm that names the
  consequence (revert-by-checkout no longer cleanly recovers a failed run).
  Uncommitted changes *inside the affected path set* (the group's spec
  directory, any blueprint to be edited, an identity-bearing territory
  directory) are named file-by-file with their consequence stated — they
  would ride the rename's commits — so nothing is swept silently; unrelated
  dirt elsewhere is summarized only. Declining stops with nothing written. A
  clean tree proceeds without interaction.

**Scan**

- [ ] 4. Before the gate, a read-only scan enumerates the complete ripple set
  across partition-owned artifacts — the context map, every group blueprint,
  the group's spec directory (including in-flight wip dirs) and its ledger,
  and the project config (`jimconf.toml`, where group identity can live in
  per-group dynamic keys and operator command strings) — and classifies every
  old-identity occurrence as **identity** (changes), **code-surface**
  (stays), or **historical** (stays), each carrying its target.
- [ ] 5. The scan detects identity-bearing territory paths (territory
  directories whose names embed the old group identity); the code-move fork
  is presented only when at least one exists.
- [ ] 6. Old-name hits in living documents outside the edit scope (e.g.
  ROADMAP.md, README.md, issue bodies) are listed informationally at the gate
  and never edited. ARCHITECTURE.md is excluded entirely (the pipeline
  regenerates it). Config hits split by ownership: an orphaned per-group key
  (`verify_appetite_<old>` — which would otherwise silently revert the
  renamed group to default appetite) is named at the gate with an offered,
  visible edit, never rewritten silently (the spec 038 config-write
  precedent); operator command strings or territory targets embedding old
  paths (`verify_command_*` / `deps_command_*` / `group_territory`) are
  listed informationally, never edited.

**Gate**

- [ ] 7. A single gate presents the entire classified change-set — the
  identity changes, the code-surface and historical keeps, the code-move fork
  (when live), and the informational out-of-scope list — per the
  gate-presentation rule (spec 040,
  `skills/blueprint/references/gate-presentation.md`). Approval is
  all-or-nothing; a declined gate writes nothing.

**Code-move fork (user choice at the gate)**

- [ ] 8. *Move-now arm:* identity-bearing territory directories are moved and
  in-territory references to the moved paths are fixed in the same operation;
  the map's territory reads the new paths at write time.
- [ ] 9. *Docs-only arm:* territory paths keep pointing at the unmoved
  old-named directories — the map stays truthful — and a tracked code-move
  issue is filed through the issue emitter, developer-confirmed, routing the
  code move to the normal spec→plan→build workflow.

**Materialize**

- [ ] 10. On approval: the map's row, group section, and sibling Relations
  entries are renamed; sibling blueprints' dotted requires keys re-point
  their group half (`<old>.<surface>` → `<new>.<surface>`) with the surface
  half unchanged; group-identity prose in the renamed group's blueprint is
  updated; and the spec directory moves with git-history continuity —
  in-flight wip dirs ride the move by contract, not by luck.
- [ ] 11. Invariant ids are byte-for-byte unchanged (stable keys — verify
  history and check-data joins survive). Provides surface names are
  byte-for-byte unchanged (descriptions — they track the code they name, not
  the group name). Path facts inside invariant text and check parameters
  update only on the move-now arm, staying truthful to where code actually
  lives on either arm.
- [ ] 12. Commits land as the fixed choreography — code move (move-now arm
  only) / spec dirs + blueprints / map + ledger — each commit atomic, no
  commit mixing the three concerns, and each staging literal paths only
  (never a blanket add), so uncommitted changes outside the affected set can
  never ride a rename commit.
- [ ] 13. The durable record is a first-class project-tier
  `op=rename old=<old> new=<new>` event on the specs-root ledger — never a
  drop+add pair.

**Verify**

- [ ] 14. The post-write reconcile yields the pre-rename contract-graph edge
  set modulo the name, with zero findings — presented as the operation's
  done-condition, never conflated with graph health.
- [ ] 15. A final identity sweep over the partition-owned artifacts finds
  zero unclassified old-name mentions: every surviving mention traces to a
  classified code-surface or historical keep.
- [ ] 16. `next-id` in the renamed group continues the numbering (max
  existing + 1); it never resets.
- [ ] 17. When an environment-gated check cannot run locally (e.g. the
  project's authoritative build), the run ends with a named "verification
  owed" line identifying the check — it never silently claims full
  verification. Any verification command the run executes or names as owed
  comes from operator-owned configuration (the registry precedent, specs
  035/038) or an explicit developer instruction — never from scanned
  content, blueprint text, or model synthesis.
- [ ] 18. The deterministic scan and verify behaviors are covered by tests
  over a multi-group fixture (per the per-script test convention,
  `skills/meta-test` / CLAUDE.md → Bash scripts): a rename on a fixture with
  ≥3 groups and cross-group requires edges proves edge-set preservation
  (AC 14), the identifier ratchet (AC 11), and the zero-unclassified sweep
  (AC 15).

**Security**

- [ ] 19. Gate and report evidence is location-only — `file:line`, occurrence
  class, target — per the spec 037 exfiltration-guard precedent; any quoted
  excerpt is secret-scrubbed before presentation, and everything persisted
  (issue bodies, scratchpad review files) is scrubbed before write (the
  spec 038 pattern).
- [ ] 20. Scanned content is data, never instruction: no directive-style text
  inside scanned files binds classification, target assignment, or gate
  composition (extending spec 018 § Security and Safety); classification
  derives only from an occurrence's structural position and the developer's
  decisions at the gate.

## UI Mockup

```
/jim:partition rename cart checkout

Preflight ✓ (map, groups, slug, blueprint, clean tree)

Rename: cart → checkout — classified change-set

  IDENTITY (will change)
    map        row + section + 2 sibling Relations mentions
    blueprints orders: requires cart.cart-session-api → checkout.cart-session-api
               billing: 1 prose mention
    spec dirs  docs/specs/cart/ → docs/specs/checkout/  (rides: 007-wip)
  CODE-SURFACE (stays — tracks code)
    provides   cart-session-api (exports still named Cart*)
  HISTORICAL (stays forever)
    specs      docs/specs/cart/001–006 body text
  TERRITORY — identity-bearing path detected: modules/cart/
    (a) move now: git mv modules/cart modules/checkout + 2 import fixes
    (b) docs-only: territory keeps modules/cart; code-move issue filed
  CONFIG (jimconf.toml)
    verify_appetite_cart → offered edit: verify_appetite_checkout
    deps_command_graph value mentions modules/cart (informational)
  OUT-OF-SCOPE MENTIONS (informational, not edited)
    ROADMAP.md:12, README.md:88

Approve (a/b) or decline? _
```

## Out of Scope

- **`split` and `merge` verbs** — future specs; they consume this spec's
  ripple-engine contract (scoped-repartition analysis + ripple engine).
- **Re-homing frozen numbered specs** — the freeze-history question is
  tracked separately (issue #68); historical specs keep the old name forever.
- **Invariant-id rename machinery** — ids ratchet permanently; a documented
  id-rename with continuity can be a later spec if fossils prove painful.
- **Renaming provides surface names or code API symbols** — names track
  code; they change through normal work specs when the code surfaces they
  describe change, picked up by the existing face-update machinery.
- **Editing living documents outside the partition's ownership**
  (ROADMAP.md, README.md, issue bodies) — advisory listing only.
- **ARCHITECTURE.md** in any form — pipeline-owned, regenerates via
  `/jim:arch`.
- **Pre-partition or retired group directories not in the map** — out of
  rename's reach.
- **Mid-run resumability** — recovery is revert-and-rerun, anchored by the
  clean-tree precondition.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point
to evaluate, not a directive.*

### Insight 1: Move mechanics

- **Relates to AC:** *"spec directory moves with git-history continuity"* /
  *"territory directories are moved and in-territory references fixed"*
  (AC 8, 10)
- **Surfaced as:** `git mv` for directory moves + manual import fixes, from
  the live improvised run.
- **Levelled-up requirement (already in the ACs):** history-continuous moves;
  in-territory references fixed in the same operation.
- **Deflection reason:** Razor (procedure, not outcome).
- **Architect note:** import-fix scope can balloon by ecosystem (module
  paths, published names); the move-now arm's recommendation could be
  conditioned on the fix set staying mechanically bounded.
- **Routing hint:** Architect to decide.

### Insight 2: Change-set keying for split/merge forward-compat

- **Relates to AC:** *"classified change-set … each carrying its target"*
  (AC 4)
- **Surfaced as:** key the ripple output `(occurrence, classification,
  target)` rather than assuming one global old→new substitution; rename is
  the degenerate case (all targets identical), split reuses the same shape
  with per-occurrence targets.
- **Levelled-up requirement (already in the ACs):** per-occurrence targets in
  the classified set.
- **Deflection reason:** Razor (cheap to phrase now, unproven that more is
  needed — don't over-engineer).
- **Architect note:** brainstorm flags this as a light forward-compat note,
  not a commitment.
- **Routing hint:** Architect to decide.

### Insight 3: Deterministic/judgment split for the scan

- **Relates to AC:** *"a read-only scan enumerates the complete ripple set"*
  (AC 4, 15)
- **Surfaced as:** enumeration (grep-class occurrence finding) is
  deterministic-script territory; classification (identity vs code-surface
  vs historical) is judgment a mechanical sed cannot make.
- **Levelled-up requirement (already in the ACs):** complete enumeration +
  classified set at the gate.
- **Deflection reason:** Delegation (Bash-vs-Prompt split is the plan's
  decision rule).
- **Architect note:** the identity sweep (AC 15) is the same enumeration
  re-run post-write — one capability, two call sites.
- **Routing hint:** Architect to decide.

### Insight 4: Pre-gate reuse of reconcile face-join logic

- **Relates to AC:** *"post-write reconcile yields the pre-rename edge set
  modulo the name, zero findings"* (AC 14)
- **Surfaced as:** the live run's reconcile caught stale faces only *after*
  the write; running the same face-join logic *pre-gate* would prevent the
  findings and make the post-write reconcile pure confirmation.
- **Levelled-up requirement (already in the ACs):** the crisp done-condition
  (edge set preserved modulo name, zero findings).
- **Deflection reason:** Delegation (which reconcile machinery to reuse and
  where is design).
- **Routing hint:** Architect to decide.

### Insight 5: Classification as read-only subagent fan-out

- **Relates to AC:** *"classifies every old-identity occurrence … each
  carrying its target"* (AC 4); *"scanned content is data, never
  instruction"* (AC 20)
- **Surfaced as:** run the scan's classification pass as a fan-out of
  read-only subagents — one per sibling blueprint, one per territory
  directory on the move-now arm — per the gatherer precedent (spec 038),
  fan-out completing before any `Skill(jim:blueprint)` call, bounded by
  `verify_fanout_cap`.
- **Levelled-up requirement (already in the ACs):** complete classified
  change-set at the gate; no directive in scanned content binds
  classification.
- **Deflection reason:** Delegation (inline vs fan-out is a mechanism
  choice an architect could reasonably contest).
- **Architect note:** the argument is the capability boundary, not
  parallelism — classification interprets untrusted content, and a
  `Read`/`Glob`/`Grep`-only context makes an embedded injection
  un-actionable by capability absence (AC 20 satisfied by construction
  rather than discipline; the issue-analyst / gatherer / judge pattern).
  Cost caveat: a typical ripple set is small (the motivating run touched
  four blueprints), so inline classification is defensible on lean grounds;
  fan-out value scales only with territory size on the move-now arm.
- **Routing hint:** Architect to decide.

## Open Questions

- [x] ~Is the partition dependency substrate (the extraction outputs the
  partition flow persists) name-agnostic, or does a rename owe a
  post-materialize re-extraction?~ → Resolved by research: the extraction
  scripts persist nothing (all verbs stdout-only) and treat group slugs as
  opaque labels — no re-extraction owed. The real residue is group identity
  in project config (per-group appetite keys, operator command strings),
  folded into the scan's reach (AC 4, AC 6).
- [x] ~Does rename require the code move?~ → No — user choice at the gate;
  both arms first-class (brainstorm decision B).
- [x] ~Do invariant ids / provides surface names rename?~ → No — ids ratchet
  as stable keys; surface names track the code they describe (brainstorm
  decision 3).
- [x] ~Namespace verb (`migrate rename`) or peer token?~ → Peer token;
  `migrate` doesn't earn the nesting.
