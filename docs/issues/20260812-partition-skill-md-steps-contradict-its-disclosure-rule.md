---
id: 20260812-partition-skill-md-steps-contradict-its-disclosure-rule
num: 339
title: "partition SKILL.md steps contradict its disclosure rule"
status: open
priority: medium
labels: [partition, placement, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:57Z
updated: 2026-08-12T21:53:57Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

The rule that partition **discloses** issue re-points under a placement rather
than applying them lives in `skills/partition/references/partition-methodology.md`.
`SKILL.md` — the file that actually loads — carries the three read-only grants and
nothing else, and three of its own steps still instruct the unconditional write.

## The contradiction

- `skills/partition/SKILL.md:399-401` (Split step 5) and `:470-471` (Merge step 6)
  both instruct `rewrite-refs` over the `git ls-files` set "+ an issue `updated:`
  refresh + one INDEX regen", with no placement branch.
- `skills/partition/SKILL.md:607` (Validation Checklist) requires the agent to
  *confirm* that regeneration as a completed fact.

Against `partition-methodology.md:573-575`, which says that under a placement
"neither the refresh nor the regeneration happens".

`place.sh`, `route`, and `UNAPPLIED` appear nowhere in `SKILL.md` prose — only in
the `allowed-tools:` line at `:18`. An agent that reads `SKILL.md` and does not
open the reference doc performs exactly the write the round removed.

The methodology's own disclosure is complete and correct: it covers split
(`:492-537`), merge (`:749-755`), and rename (`:284-288`, listing-only on every
arm). `tests/docsurfaces.sh:224-244` pins that text and the grant. Only the
checklist an agent ticks is stale.

## Two smaller gaps in the same surface

**The read handle has no failure-path release.** `partition-methodology.md:517-532`
sequences `begin --read` → scan → `abort` in prose. A scan error, a declined gate,
or an interrupted run between the two strands a routed handle holding a full
materialized copy of the collection under `.git/jim-place/`, with no verb to list
or prune it. The only stated failure branch (`:534-536`) covers `begin --read`
*failing*, not succeeding-then-failing-later.

**The `UNAPPLIED` block names no procedure.** `partition-methodology.md:544-551`
requires the rows be "stated as re-points this run will **not** make and the
operator applies afterwards", but never points at the two-phase door that would
apply them (`skills/issue/SKILL.md:181-193`), and the rows are not offered through
the candidate batch — unlike freeze-on-doubt mentions two paragraphs later
(`:621-623`), which *are* offered as a tracked follow-up. Once the gate scrolls
past, the collection's stale citations have no owner.

## Action

1. Add the placement caveat to `SKILL.md:399-401`, `:470-471` and the checklist
   item at `:607` — "under a branch placement no issue file is in the sweep set;
   the rows are disclosed as `UNAPPLIED`" — and add a merge checklist line carrying
   it too.
2. Extend `case_docsurfaces_partition_discloses_unapplied_issue_repoints` to sweep
   `SKILL.md` for the qualification, not only the methodology.
3. State the handle release as unconditional ("abort in every exit path, including
   a failed scan or a declined gate").
4. Have the `UNAPPLIED` block name `place.sh begin` / Edit / `commit --verb edit`
   as the apply path, and offer the rows as one tracked follow-up through § 7.

Coverage note: `tests/jimpartition.sh` contains no placement case at all — the
disclosure is pinned only as doc text by `docsurfaces.sh`, never as behaviour.
