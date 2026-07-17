---
id: 20260717-post-approval-correction-evolution-flow-edit-approved-plans-and-
num: 15
title: "Post-approval correction/evolution flow: edit approved plans and propagate fixes to code and migrations"
status: open
priority: high
labels: [skill, plan, correction, lifecycle, workflow]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-17T22:21:05Z
updated: 2026-07-17T22:21:05Z
origin: docs/research/20260717-competitive-landscape-sdd-skills.md
---

## Description

## Why / the real problem

This is a **reframe of the earlier "post-ship spec-lifecycle" candidate**, narrowed to the actual pain the developer hits.

It is **NOT** about amending a spec mid-draft — jim already does that well (`/jim:spec` Step 13 differential update, `/jim:plan` Step 5 differential update; Claude Code also does it fairly naturally).

The real pain is **correcting / evolving an artifact that has already been APPROVED (and usually already BUILT / shipped)**, and getting jim to *actually edit the approved plan/spec in place* rather than annotating it — **and** propagating that one correction coherently across the whole linked chain.

**Concrete real-world example (developer):** an early spec/plan defined a **database table column incorrectly**. Asking jim/Claude to go back and amend the *approved plan* that caused it was "like pulling teeth" — it added comments/notes into the plan instead of editing it, and required very specific per-artifact hand-holding: "modify this in the plan, modify this in the code, modify this in the migration, correct the mistake." The model treats approved/complete artifacts as sacrosanct and won't drive the correction end-to-end.

## Two structural reasons jim resists this today

1. **Reluctance to touch approved/complete artifacts.** The model defaults to annotating (`note: this is wrong`) rather than editing something marked `status: approved` / `complete`.
2. **`/jim:build` scope discipline actively forbids it.** `skills/build/SKILL.md` → *Scope Discipline*: "Do NOT modify `spec.md` or `plan.md` content — the only allowed change is marking tasks `[x]`," and build never re-opens a completed plan. So there is **no first-class flow** to (a) reopen/correct the source design record and (b) push the fix through code + migration + tests.

## What already exists (verified this session)

- `/jim:spec` Step 13 — spec differential update via Edit.
- `/jim:plan` Step 5 — plan differential update via Edit ("Read existing plan fully… Use Edit, not Write").
- So the *edit mechanism* exists. The **gaps** are: reluctance to edit `approved`/`complete` artifacts; no build-time correction mode; and **no cross-artifact propagation** (correcting the plan doesn't correct code + migration; the human must hand-drive each layer).

## Goal

A first-class **correction / post-approval evolution** workflow that:
1. **Willingly re-opens and edits an already-approved (or complete) plan and/or spec** to reflect the *corrected* design — a living document, not a wrong design decorated with a "this is wrong" note.
2. **Traces the defect through the artifact chain and drives the fix across every affected layer coherently:** spec AC ↔ plan (design decision / interface contract / task) ↔ code ↔ DB migration/schema ↔ tests — without the human enumerating each site.
3. **Records what was corrected and why** (provenance), so the institutional-memory archive reflects the correct design rather than "wrong + comment."

## Open design questions (for `/jim:spec` time)

- **New skill vs. enhancement?** A new skill (e.g. `/jim:correct` / `/jim:evolve` / `/jim:amend`) vs. strengthening the existing differential-update paths + a build-time correction mode. (Recommend at least a dedicated entry point so the "I am consciously correcting an approved artifact" intent is explicit.)
- **Overriding the "don't touch approved artifacts" guardrail safely** — an explicit, human-confirmed *correction mode* that authorizes editing `approved`/`complete` plans, distinct from `/jim:build`'s hard "never modify plan.md" rule. How do the two coexist without weakening build discipline?
- **Cross-artifact propagation — how does the skill know the chain?** Leverage what already maps it: the plan's **Requirements Coverage Summary** (AC → task), **File Manifest** (task → files), and **Interface Contracts**. The corrective flow can walk AC → task → files → migration from these.
- **Relationship to bug specs / `/jim:debug`.** When is correcting the *source* artifact better than filing a *new* bug spec/increment? (Correcting the design record keeps memory accurate; a new increment preserves history but can leave the original plan wrong.) Define the boundary.
- **Status transitions.** Does correcting a `complete` plan move it to a `correcting` state? How to re-run only the affected build task(s) under TDD — write the regression test that reproduces the defect *first*, then apply the corrected implementation?
- **Migrations are special.** Correcting an *already-applied* DB migration usually means a **new forward/corrective migration**, not rewriting the old one. The skill must: edit the plan/design record to be *correct going forward*, but generate a **corrective forward migration** rather than editing migration history. This distinction is easy to get wrong and worth calling out explicitly in the spec.

## Rough acceptance sketch

- Given "column X was defined wrong in plan P (already approved/complete)," the flow: **edits P's design/contract/task in place** to the correct definition (not a note); **identifies** the affected code + migration + tests via the File Manifest / Coverage Summary; **drives** the corrective changes (regression test first, code fix, corrective forward migration) under jim's TDD + gates; **records** the correction rationale.
- The developer does **not** have to enumerate each artifact to touch — the skill derives the propagation set.

## References

- `skills/spec/SKILL.md` Step 13 (spec differential update); `skills/plan/SKILL.md` Step 5 (plan differential update); `skills/build/SKILL.md` → *Scope Discipline* (the "never modify plan/spec" guardrail this flow must *consciously* override in correction mode); bug spec type + `/jim:debug`.
- Landscape-doc origin of the idea (originally framed as OpenSpec delta-vs-canonical lifecycle; **this issue reframes it** to the real pain = correcting/evolving approved+shipped artifacts and propagating the fix): `docs/research/20260717-competitive-landscape-sdd-skills.md`.
