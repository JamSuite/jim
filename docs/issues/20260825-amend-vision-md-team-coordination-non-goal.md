---
id: 20260825-amend-vision-md-team-coordination-non-goal
num: 380
title: "Amend VISION.md team-coordination non-goal"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [vision, strategy]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-25T10:50:59Z
updated: 2026-08-27T20:43:47Z
origin: "docs/specs/issue/014-read-view-filter-composition/spec.md"
---

## What

`VISION.md` § Non-Goals still states that issue capture is in scope "only as a
*discovery artifact* surfaced during the jim workflow and saved for later
analysis, **not as a team-coordination primitive**."

That is no longer true of the shipped product.

## What changed under it

- Spec `issue/012-schema-and-state-model` added `claimed-by` to the record and
  shipped `claim`, `release`, and `start` as lifecycle verbs. Holding an issue
  is a coordination primitive by any reading.
- Spec `issue/013-recorded-identity-schemes` made the recorded identity
  consistent across contributors so by-person views do not split one person
  into several — work that only makes sense if by-person views are intended.
- The read-view filter composition spec adds `--claimed-by` and `--filed-by`,
  which turn the stored identity into a queryable one.

## Why it matters

The brainstorm that produced this line of work took the contention head on and
recorded a decision: *"VISION contention is not a blocker. Owner/assignment is
being built; the vision gets amended if it needs to be."* The building happened;
the amendment did not.

A strategic document that contradicts shipped behavior is worse than a silent
one — `/jim:spec`'s own flow reads `VISION.md` as a locked constraint and
raises divergence conversationally, so every future spec in this area starts by
arguing with a stale line.

## Fix shape

Run `/jim:roadmap`'s sibling `/jim:vision` and amend the non-goal to distinguish
what jim does do (record who filed and who holds a discovery, and let a
contributor filter on it) from what it still does not (assignment workflows,
notification, capacity, sprints — the Jira/Linear surface the non-goal is
actually pointing at).

## Resolution

Fixed in `ac8da2d`, through `/jim:vision`.

The non-goal now states that recording and querying who filed and who holds a
discovery is in scope, along with rolling that record up, and names the
excluded surface explicitly: assigning work to someone else, notification,
capacity planning, sprints, boards, and due dates. The distinguishing line is
push versus pull — claiming is self-service, and the schema increment shipped
no verb for assigning work to anyone else.

**The amendment is wider than what was filed, in two places.** This record
asked for `filter on it`; the text says `querying and rolling up`, chosen so
that epic progress rollups fall inside the boundary rather than reopening this
argument one increment later. And it excludes `boards` and `due dates`, which
this record did not list. Both were deliberate; neither was requested.

**The goal was met observably rather than by assertion.** The stated goal was
that a spec scoped in this area should stop opening by arguing with a stale
line. The epic authoring spec was scoped immediately after the amendment
landed, reads `VISION.md` as a locked constraint like every other spec, and
raised no divergence.

**Nothing pins this.** It is a prose change with no test case, and the wording
can drift back without anything failing. Recorded here rather than left for a
later coverage sweep to report as a gap.

**Sibling sweep — one live site, and it is this one.** The claim appears in
five other places, none of them live: an issue body from 2026-07-28 and the
2026-08-17 brainstorm, both correctly quoting what `VISION.md` said when they
were written; `docs/specs/issue/001-issue-tracking/spec.md`, a historical
statement of the same; this record; and the generated index. `BACKLOG.md`
mentions Linear as a possible storage backend, which is a different subject.
No other live document restates the non-goal, so no sibling edit was needed.
