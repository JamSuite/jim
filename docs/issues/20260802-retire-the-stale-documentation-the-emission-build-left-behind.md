---
id: 20260802-retire-the-stale-documentation-the-emission-build-left-behind
num: 211
title: "Retire the stale documentation the emission build left behind"
status: open
priority: medium
labels: [docs, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-02T21:35:12Z
updated: 2026-08-02T21:35:12Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

## Description

The blueprint/025 build changed behavior in places whose documentation was not
updated with it. Fifteen sites, all now asserting something the code no longer
does. Grouped by consequence.

**Model-facing — an agent following this will call a retired verb:**

- `skills/partition/SKILL.md:366` — split step 3 still reads "vacated ids never
  re-mint (`next-id` floors via the `op=split` event, AC 11)". Both named
  mechanisms are retired; `jimfile.sh next-id <group>` now returns rc 2. The
  sibling merge step and the methodology were rewritten; this arm was missed.
- `skills/partition/references/partition-methodology.md:326-329` (rename),
  `:533-540` (split), `:734-736` (merge) — the Close passages of the referenced
  full protocol never gained the `partition-batch` step that
  `skills/partition/SKILL.md:328,384,451` now carries. The SKILL body tells the
  orchestrator to read the methodology before running, so the two describe
  different Close choreographies.
- `skills/spec/SKILL.md:389-394` — the stderr→repair table has no row for the
  new untracked cross-parent refusal, which is also the one halt whose remedy
  *is* a re-run (the table's general advice argues against re-running).

**Script contracts contradicting the gate below them:**

- `jimalloc.sh:250-253` — `alloc_canon_specid`'s doc still states the joint-gate
  behavior AC 8 removed ("the record is dropped when EITHER side fails, so an
  over-wide source also drops its destination's establishing claim"). This is
  the first thing a future editor of the width bound reads. Two independent
  reviewers flagged it.
- `jimalloc.sh:99-105` — the record-grammar header added by this build claims
  "every field count above is EXACT … never half-parsed on the fields that did
  read". False for allocate records: a four-field `spec allocate core/003 alpha`
  still registers a live claim. True for rename and realize only.
- `jimalloc.sh:3667` — cites "AC 5" in a comment, which `CLAUDE.md` forbids in
  `skills/*/scripts/`. The rationale bites here specifically: this spec's own
  verbs renumber the specs an ID points at.
- `jimledger.sh:558-561` — `move-spec-dir`'s contract header still says both
  basenames must be `NNN-slug`/`NNN-wip`; the source gate now also admits a
  provisional token.
- `reconcile.sh:265-266, 273-275, 218, 391` — `apply_pending`'s doc still
  enumerates the cross-group halt this build deleted and still says the tracked
  rename goes through the sibling-constrained verb; `rewrite_id`'s signature
  omits its new 4th parameter; `build_remap`'s documented row shape uses one
  `<group>` placeholder where the cross-parent case now differs.
- `reconcile.sh:688-690` — present tense about the removed vacated-id floor.
- `jimpartition.sh:1461` — `merge-map`'s docstring names `jimfile.sh next-id`.

**Architecture and blueprint (present-tense artifacts by jim's own doctrine):**

- `ARCHITECTURE.md:390` — names the deleted `is_prov_basename`, in a paragraph
  that already documents its replacement, so it contradicts itself; `:391` omits
  the cross-parent branch, the `group:` rewrite and the untracked refusal; `:395`
  describes `merge-map`'s current contract via `next-id`.
- `docs/specs/platform/000-blueprint/spec.md:41-42` — still guarantees that
  `next-id` floors past vacated ids; `:113` still enumerates `vacated-max` as a
  live `jimledger.sh` verb and omits its replacement `pair-events`.
- `docs/features/ledger.md:58, 68` — same two errors.
- `tests/jimalloc.sh:229` — "the width gate is applied JOINTLY … so an over-wide
  source is gated on its own side": a rewritten tail left on the original head,
  so the sentence contradicts itself.

## Proposed action

One editorial pass. `ARCHITECTURE.md` goes through `/jim:arch`, not by hand.
`docs/specs/platform/000-blueprint/spec.md` goes through `/jim:blueprint platform`.
The rest are direct edits.

## Root cause worth fixing separately

The plan's retirement task verified itself with `bash tests/jimfile.sh && bash
tests/jimledger.sh`. Both passed, and both were the wrong question: a
retirement's real risk is the omission class — surviving callers and stale
instructions elsewhere in the tree — which no per-script suite can see. A
retirement task's Verify should include a tree-wide sweep for the retired
symbol. That single gap accounts for most of this issue.

Surfaced by the post-build review of blueprint/025 (findings 15, 16, 17, 17a).
