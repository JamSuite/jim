---
id: 20260812-new-contract-graph-rows-are-unbacked-by-requires-entries
num: P-20260812-new-contract-graph-rows-are-unbacked-by-requires-entries
title: "New contract graph rows are unbacked by Requires entries"
status: open
priority: high
labels: [blueprint, contracts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:44Z
updated: 2026-08-12T21:53:44Z
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
