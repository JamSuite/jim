---
id: 20260812-new-contract-graph-rows-are-unbacked-by-requires-entries
num: 338
title: "New contract graph rows are unbacked by Requires entries"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [blueprint, contracts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T21:53:44Z
updated: 2026-08-13T05:51:45Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

`BLUEPRINT.md`'s Contract Graph gained two rows in the review-remediation round:

    | sdlc      | placement-door (`place.sh` begin/commit) | issue |
    | blueprint | placement-read (`place.sh` begin --read) | issue |

Neither is backed by a `Requires` entry in the consumer's blueprint.

- `docs/specs/sdlc/000-blueprint/spec.md` — its `## Requires` names
  `issue.emitter` and `issue.candidate-batch-contract`; no placement entry.
  `updated: "2026-07-25"`.
- `docs/specs/blueprint/000-blueprint/spec.md` — same two entries, no placement
  entry. `updated: "2026-07-25"`.

The graph is **derived** from the group blueprints' provides/requires faces —
`skills/verify/scripts/jimverify.sh:716`, `:746-749` build edges from `Requires`
alone — and `BLUEPRINT.md`'s own header says so:

    *Derived from the group blueprints' provides/requires faces — regenerated
    on every blueprint write; do not edit.*

So the two rows sit in a table declared un-editable without the declarations that
would regenerate them. The next `/jim:blueprint` write drops both, silently.

The provider half **did** land correctly: `docs/specs/issue/000-blueprint/spec.md`
gained a `place.sh` **placement door** Provides entry (`:74-84`) naming both
external callers, and its Structure line (`:120-124`) records that the group is no
longer faceless. Only the reciprocal consumer declarations are missing.

Consequence beyond the rows themselves: the two genuinely new cross-group
dependencies — `skills/spec/scripts/reconcile.sh` → `place.sh begin`/`commit`, and
`/jim:partition` → `place.sh begin --read` — are invisible to blast-radius
analysis and to `/jim:verify --contracts`. A change to the placement door would
not surface either consumer.

The closing issue's `## Decision` committed to this explicitly ("plus a contract
edge `issue → spec`. Through `/jim:blueprint`, not by hand"); its `## Resolution`
is silent on whether it landed. It did not.

Found by the resolution-note investigator during the fourth review and verified
directly against both consumer blueprints.

## Action

Through `/jim:blueprint`, add the reciprocal `Requires` entries:

- `sdlc` — `issue.placement-door` (the citation sweep drives `begin`/`commit`
  around the issue half of a realization).
- `blueprint` — `issue.placement-read` (the partition surface holds `mode`,
  `begin --read` and `abort`, no publish verb).

Then let the reconcile pass regenerate the graph and confirm both rows survive
regeneration rather than being hand-carried.

Worth a moment's thought while doing it: the `platform` blueprint's
`jimconf.sh` Provides entry (`docs/specs/platform/000-blueprint/spec.md:30-35`)
records only "zero-config defaults when `jimconf.toml` or a key is absent". The
unset-vs-failed distinction that the `issue` group's placement gate now depends on
is declared only in the *consumer's* blueprint (`issue/000-blueprint:107-110`).
The provider should declare the face its consumer relies on.

## Resolution

**2026-08-13.** Both reciprocal `Requires` entries are declared, and the two
rows now derive rather than being hand-carried.

- `docs/specs/sdlc/000-blueprint/spec.md` gained `issue.placement-door`,
  grounded in `sweep_citations`, which drives `place.sh` `mode` / `begin` /
  `commit --verb edit` / `abort` around the issue half of a realization.
- `docs/specs/blueprint/000-blueprint/spec.md` gained `issue.placement-read`,
  grounded in the partition surface's three-verb grant — `mode`,
  `begin --read`, `abort`, no publish verb.

Both edits went through `/jim:blueprint --since`, each with its own violation
fork, stage events and `commit-blueprint`; the reconcile pass then rewrote the
graph. Commits `d69df9d` + `c599fad` (sdlc) and `18c71bd` + `8b19ea2`
(blueprint).

**What pins it.** The rows are no longer content — they are the join of two
`Requires` entries that `jimverify.sh faces` emits mechanically, so the next
reconcile reproduces them from the faces rather than preserving them. Deleting
either entry drops its row on the following pass, which is the property the
issue asked for. Confirmed by re-deriving after the second write: `faces`
returns `issue.placement-door` for `sdlc` and `issue.placement-read` for
`blueprint`, and `jimverify.sh health` reports **25 edges**, up from 23.

**The dead-surface finding cleared itself**, as predicted. It was 1 — the
`place.sh` placement-door Provides entry required by no mapped consumer — and
is 0 across both reconciles. The class's stock remedy ("trim the entry") was
indeed wrong: the entry was correct and the declarations were missing.

**Not taken here:** the tail note about `platform`'s `jimconf.sh` Provides
entry declaring the unset-vs-failed distinction its consumer relies on. That is
`#342` item 4, filed against the same surface, and it belongs to that issue
rather than being folded in silently.

**Found while doing it:** the `sdlc` blueprint's `issue.emitter` entry — one
bullet above the addition — carries a stale eight-skill roster of the class
`#325` tracks. Recorded there with a dated `## Note`, not corrected in this
pass.
