---
id: 20260802-retire-the-stale-documentation-the-emission-build-left-behind
num: 211
title: "Retire the stale documentation the emission build left behind"
status: closed
priority: medium
labels: [docs, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-02T21:35:12Z
updated: 2026-08-05T12:55:00Z
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

## Scope re-derived, and widened (2026-08-03)

The "fifteen sites" above is a **claim, not a measurement** — the reporter was
subject to the same incompleteness the finding describes. Re-derived
mechanically: the retired-symbol set was extracted from the build's own diff
(removed function definitions and dispatch arms), then each symbol swept
tree-wide with dated artifacts excluded and every hit classified by hand.

Everything listed above is confirmed still live. Five more sites and classes
were not listed, and one of them is the highest-visibility surface in the repo.

**1. `README.md:200` — the project's front page undercounts the repair verbs.**
"Two hand-run allocator verbs keep that true" plus a code block showing only
`sweep` and `catch-up`. `lift` is a third verb of exactly that family — hand-run,
previewed, repairs the registry from durable history — and it does not appear.
This is the surface no pipeline phase refreshes: the build gate regenerates
`ARCHITECTURE.md` and nothing else.

**2. `docs/features/blueprints.md` — zero occurrences of `partition-batch`.**
The feature doc describes `rename`, `split` and `merge` without the registry
Close step that `skills/partition/SKILL.md:328,384,451` now carries. Same defect
as the methodology finding above, one surface further out, and also
user-facing.

**3. `ARCHITECTURE.md:282, :284` — the per-spec narrative still presents
`vacated-max` as a live `jimledger.sh` verb**, describing its signature and its
`op=split` grammar ownership. `:308` and `:393` correctly announce the
retirement, so the document contradicts itself. Only `:390`, `:391` and `:395`
are listed above.

**4. `tests/jimpartition.sh:2386, :2420` — the twin of `jimpartition.sh:1461`.**
Both comments state that `merge-map`'s `<start>` "copies `next-id`'s output" and
describe "the floored `next-id` past a dir-max of 5". The start now comes from
`jimalloc.sh peek spec`. The script-side site is listed above; its test-side
sibling is not — the same fix-one-miss-the-sibling shape this issue's own root
cause describes.

**5. `skills/issue/scripts/new.sh:138` — a comment explains current behavior by
reference to a retired mechanism** ("the local clone suffixes it the same way
`next-id`'s tree scan did"). `CLAUDE.md` scopes script comments to current
behavior.

**Verified correct, needing no change** — recorded so the next sweep does not
re-derive them: `README.md:56`/`:188`/`:189` and `skills/file/SKILL.md:10`/`:28`
(both `next-id` and `next-num` still exist, and the spec-ordinal caveat is
already written); `ARCHITECTURE.md:90`, `:308`, `:391`, `:393` (updated by the
build's `/jim:arch` run); `tests/jimfile.sh:143-152`, which asserts the
retirement correctly. `WORKFLOW.md` carries no occurrence of any retired symbol.

**Out of scope, pointed elsewhere:** `docs/specs/jim/000-blueprint/spec.md:89-90`
still enumerates `mv-spec` and the pre-retirement `jimfile.sh` verb set. That is
the retired group's blueprint holding authoritative-looking content, which is
[[20260725-give-retired-group-directories-a-sanctioned-end-of-life]]'s subject,
not this issue's.

## Progress — 19 of 20 corrected (2026-08-03)

Everything above is fixed except one site, deliberately held back.

**Done.** The three model-facing surfaces (the split step's retired verb, the
methodology's three Close passages, the spec skill's repair table); all seven
script-contract headers, including the `AC 5` citation this file's own rule
forbids; `tests/jimalloc.sh`'s self-contradicting sentence and
`tests/jimpartition.sh`'s two `next-id` comments; `README.md`'s repair-verb
count and the new `lift` paragraph; `docs/features/ledger.md`;
`ARCHITECTURE.md` via `/jim:arch`; and the platform blueprint's two Provides
claims via `/jim:blueprint --since`.

**Deferred, not missed:** `docs/features/blueprints.md` — zero occurrences of
`partition-batch`, so the feature doc still describes a Close choreography the
skill no longer runs. Separate updates to that file are landing on their own
branch first; this correction rides them rather than racing them.

This issue stays open on that one site.

## Disposition corrected (2026-08-05)

The recorded disposition — every site retired except `docs/features/blueprints.md`,
held for `feat/blueprints` — is **false**. Three more sites survive, and two are
missed siblings of sites that *were* fixed.

| site | state |
| :--- | :--- |
| `ARCHITECTURE.md:395` | **named here and claimed fixed.** The remediation commit edited this very line — appending a retirement marker — and left the stale `merge-map … <start> taken verbatim from next-id` clause on it. `jimfile.sh next-id spec platform` exits 2, "answers for issues only". |
| `README.md:62` | "Two registry-integrity verbs", over a 2-row table with no `lift` row. Missed sibling of site 15, fixed at `:199-215`. |
| `ARCHITECTURE.md:393` | present-tense `vacated-max`, the only unmarked one in the file; filed here under "verified correct, needing no change". |
| `docs/features/blueprints.md` | the declared survivor. Also carries a second stale claim at `:152`. |

**A fix here introduced a defect.** The commit that renamed the heading to
`### Registry integrity — jimalloc.sh sweep / catch-up / lift` (`:199`) left
`README.md:62`'s in-page anchor pointing at the old slug. The link is dead.

**Beyond this issue's list.** `WORKFLOW.md` contains **zero** occurrences of
`lift` — the registry-integrity table at `:89-92` lists only `sweep` and
`catch-up`. This issue cleared `WORKFLOW.md` with "carries no occurrence of any
retired symbol", a check structurally incapable of noticing a *missing new* verb.
Retirement and introduction need separate checks.

`ARCHITECTURE.md` was not regenerated in the range at all (header still reads
`Last updated: 2026-08-03`), so `:282` and `:395` document a `renumber-map`
invocation that now fails at arity, and `:390` still asserts the exact sentence
issue #212 was filed to falsify. A `/jim:arch` run is the closure for those.

Also unlisted: `skills/spec/SKILL.md:411` and `skills/spec/assets/spec-template.md:5`
still describe a spec id as "a 3-digit zero-padded ordinal", which the widened
ordinal bound falsified.

This issue stays open for `docs/features/blueprints.md`, as scoped. The newly
found sites are tracked separately.

Source: post-build review of the B-prime cluster,
`docs/notes/20260805-b-prime-review.md` (Finding 9).

## Resolution (2026-08-05)

All eleven sites verified against the current tree and **all eleven are already
fixed** — the split step no longer names either retired mechanism, the three
methodology Close passages all carry `partition-batch`, the stderr→repair table
has its untracked cross-parent row, and the four script-contract docstrings match
their code. Closing on verification rather than on assertion, which is what this
issue's own disposition failed to do the first time.

The one thing the audit found still open is not on this list and is filed
separately: this issue's root-cause note says a retirement's real risk is the
omission class, and that class is exactly where the rule about artifact citations
in script comments sits — **95 violations across nine scripts**, concentrated in
one file. The earlier pass fixed the single citation it was pointed at and never
swept the rule, which is the shape this issue describes, happening to this issue.

The root cause itself is now mechanised: `tests/docsurfaces.sh` sweeps the doc
corpus for retired symbols, so a retirement pass no longer verifies itself with
per-script suites that cannot see the omission class.
