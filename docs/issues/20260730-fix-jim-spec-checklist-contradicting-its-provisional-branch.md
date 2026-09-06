---
id: 20260730-fix-jim-spec-checklist-contradicting-its-provisional-branch
num: 148
title: "Fix jim spec checklist contradicting its provisional branch"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [spec, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-30T10:55:23Z
updated: 2026-07-31T12:40:00Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

`skills/spec/SKILL.md` now has two sections that contradict each other.

Step 8 binds spec identity through the allocator and, when the coordination
point is unreachable under `provisional` mode, writes frontmatter carrying the
reserved token:

    id: "P-<date>-<slug>"

The skill's own Validation Checklist still requires:

    - [ ] `id` is 3-digit zero-padded, sequential within group

So a spec scoped offline fails the checklist of the skill that produced it. The
checklist is the pre-presentation gate, so this is self-inconsistency in the
authority on what a well-formed spec looks like, not merely stale prose.

Fix: amend the checklist item to admit the reserved provisional form — naming it
as the offline case that `/jim:spec reconcile` later replaces with a real
ordinal — so the checklist describes both states a bound spec can legitimately
be in.

While there, check the neighbouring frontmatter items for the same drift.

## Three more contradictions in the same file

Widened 2026-07-30 by the review's investigated second pass. All four are prose
the build's edits made inconsistent rather than prose it wrote, so they belong
in one reconciling pass:

- **`:86`** — "for a new spec you'll assign the next id when you open the ledger
  below" flatly contradicts `:92` ("The id is **not** assigned here") and `:189`
  ("The identity is assigned here, at write time — never earlier"). It is also
  the last surviving tree-derivation cue in the file.
- **`:359`** — Step 13's "If creating new: follow the normal generation path
  (step 8) with a new ID" offers no `<peek>-wip` placeholder, while Step 8's
  rename is mandatory and sourced from exactly one, with no branch for its
  absence.
- **The refusal table (`:112-113`)** never names the `fail` unreachable-mode.
  It lists `group renamed` and `group exhausted` only, while the message a
  developer actually sees under `fail` (`coordination remote '<r>' is
  unreachable`) matches neither row. Add the row, and give it retry guidance —
  the spec claims "bounded retries" and nothing in the skill says so.

Surfaced by `sdlc/017`'s post-build review. Widened 2026-07-30 from the
checklist item alone to all four sections.
