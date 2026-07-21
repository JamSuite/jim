---
id: 20260708-partition-spec-migration-mode
num: 68
title: "Extend /jim:partition with a spec-migration mode (move specs into new groups)"
status: closed
priority: medium
labels: [partition, migration, freeze-history]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-08T07:53:09Z
updated: 2026-07-21T06:05:54Z
origin: conversation
---

## Resolved 2026-07-21 — shipped as spec 046 (spec-migration)

The design fork this issue tracks — *is a moved spec's recorded group identity
an immutable historical fact, or a live pointer that should track the move?* — is
settled. Spec 046 makes it a project-level `spec_migration` preference (`rewrite`
default / `forward` / `immutable`) and records the reconciled doctrine: the spec
**directory** is the live group binding, a numbered spec's **body** identity is
preference-governed, and the ledger `op=rename` event is the durable old→new
bridge in every mode (the `000-blueprint` re-identifies in every mode; the
preference governs numbered specs 001+).

**Shipped for rename.** `rewrite` re-homes a moved numbered spec's identity via
the deterministic `jimpartition.sh rewrite-identity` verb (mechanical floor +
gatherer freeze-on-doubt on ambiguous prose); `forward` freezes bodies behind the
ledger alias; `immutable` is stated not-applicable to a rename and runs as
`forward`. Built, reviewed `aligned`, ARCHITECTURE.md / WORKFLOW.md / README.md
refreshed.

**Split/merge re-homing** — per-child assignment and merge id-collision — was
explicitly deferred to its own future specs and is now **unblocked** against the
settled doctrine. Its design proceeds via the tabled brainstorm
[docs/brainstorms/20260716-partition-split.md](../brainstorms/20260716-partition-split.md),
not this issue. Closing: the freeze-history fork is resolved and the tabling on
split/merge is lifted.

## Update 2026-07-16 — rename now moves the dir; split/merge blocked on this

Verified against the jim source this session. The Context below was written
pre-043 and describes **repartition** mode (spec 038), which still does not move
specs. But the **rename** verb (spec 043, shipped 2026-07-11) changed the
picture, and the split/merge design line now blocks on the unresolved fork this
issue tracks.

**What rename does today.** Two distinct things to numbered specs:

- **Directory** — `jimledger.sh rename-tracked` git-mv's the *whole* spec dir
  `docs/specs/<old>/ → docs/specs/<new>/` (history-continuous; in-flight `wip`
  dirs ride along). Numbered specs *physically move* into the new group's dir.
- **Internal identity** — numbered-spec (`NNN-*`) body is classified
  **historical** and frozen: `group:` frontmatter, body mentions, and
  `Spec: <old>/NNN` trailers keep the old name. (The `000-blueprint` *is*
  re-identified — only specs 001+ freeze.)

So the state is **"half-moved"**: files sit under the new dir but still identify
as the old group. Severity is **archive-coherence, not functional** — group is
*path-derived* (the directory name); no script reads a numbered spec's `group:`
frontmatter or `Spec:` trailer. But it undercuts VISION's "archive as a reliable
reference": a spec filed under `<new>/` that reads `group: <old>` is incoherent
to a reader.

**This reframes #68.** The issue as filed covers repartition's
*don't-move-at-all*. The rename era opened a **second, narrower gap this text
didn't name**: dir moves, identity freezes. Both reduce to one unanswered design
fork:

> **What does a spec's recorded group identity mean when the group's identity
> changes — an immutable historical fact, or a live pointer that should track the
> move?**

**Why this now blocks split/merge.** In rename the domain continues under a new
name, so a frozen `Spec: <old>/NNN` is arguably a truthful historical fact. In
**split** (1→N) and **merge** (N→1) the source identity *ceases to exist* — every
moved spec points at a group that is simply gone, and split must additionally
*decide which child* each spec belongs to. Both split arms are in scope
(extraction *and* symmetric N-way); the symmetric arm makes this unavoidable.
Split/merge mechanism design is **tabled** on this issue.

Full blocking context and the tabled split brainstorm:
[docs/brainstorms/20260716-partition-split.md](../brainstorms/20260716-partition-split.md).

## Description

## Context

`/jim:partition` (shipped as spec 038) deliberately does **not** move numbered
specs. Its repartition mode migrates only *living* artifacts — the context map,
group blueprints, and future spec filing — while numbered specs stay frozen
where they are (AC #13: "No mode of this skill moves, renumbers, or edits a
numbered spec directory"), rooted in the spec 029 freeze-history doctrine and
reinforced by VISION's "the spec/research/plan archive becomes a go-to reference
for onboarding and decision history."

The consequence: after a repartition, existing specs remain filed under
now-retired group ids, their `Spec: <group>/<NNN>` trailers and directory homes
pointing at groups the new map no longer declares. They are stranded under a
partition authority that has been superseded.

## What

Extend `/jim:partition` with a spec-migration capability that re-homes existing
numbered specs into the new groups a repartition establishes — so that after a
migration the spec archive is coherent with the live partition, not split
between a retired group layout and a current one.

## The crux — this reopens freeze-history

This is not a small extension. Moving specs directly contradicts the doctrine
`/jim:partition` was built to honor. Before any of this is built, the design
fork to resolve is whether the coherence benefit can be had **without** breaking
the immutable-history property VISION depends on:

- **Move vs. forward.** A redirect/alias index (old id → new group home) may
  deliver discoverability without physically relocating or renumbering the
  frozen artifact. Decide whether re-homing is a physical move or a forwarding
  layer over an untouched archive.
- **Id + trailer semantics.** Spec ids are per-group (`Spec: dashboard/001`).
  Re-homing implies a new id or a collision in the destination group, and 038
  put reference-rewriting explicitly out of scope. How are ids, `Spec:`
  trailers, and inbound cross-references handled?
- **Git-history continuity.** A physical move must preserve blame/log continuity
  for the relocated files.
- **Surface + `--retire` interaction.** Is this a `/jim:partition` sub-mode or a
  distinct verb, and how does it compose with the `--retire` arm that already
  marks a superseded group's blueprint as retired — do that group's specs follow
  the same pointer?

## Relation

Extends [[20260703-build-the-partition-migration-skill]] (#34, shipped as spec
038). Sequenced behind the current #22 verification-engine work; filed now so the
freeze-history reopening has a tracked home rather than living only in
conversation.
