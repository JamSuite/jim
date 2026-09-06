---
id: 20260812-three-surfacing-skill-roster-counts-are-stale
num: 317
title: "Three surfacing-skill roster counts are stale"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T03:42:11Z
updated: 2026-08-12T20:22:35Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

Three rosters of the surfacing skills disagree with each other and with the
canonical one, including two inside files the canonical roster was corrected in.

## The counts

- **`skills/issue/scripts/new.sh:4`** — "every candidate-batch step (**the seven
  surfacing skills**)". Contradicts the same file's gate comment at `:120` ("the
  nine skills that auto-file") and § 7a's "ten".
- **`skills/issue/SKILL.md:211`** — the § 7 untrusted-content roster lists
  **eight** (`spec, research, plan, build, brainstorm, debug, sec, partition`),
  omitting `/jim:review` and `/jim:verify`. Both surface candidates and both file
  untrusted candidate text, so the anti-injection paragraph binds a smaller set
  than § 7a — two paragraphs later — correctly enumerates.
- **`ARCHITECTURE.md:395`** — says "**eight** surfacing skills" three times while
  correctly saying "the **nine** auto-filing skills pass `--auto`" in the same
  paragraph.

The canonical § 7a roster (`SKILL.md:215`) is correct: ten surfacing skills, nine
with a quiet path, "every one but `/jim:partition`".

`ARCHITECTURE.md` is deliberately outside the doc sweep's corpus, so nothing
catches its copy.

## Proposed action

Correct all three to agree with § 7a. **`ARCHITECTURE.md` must be updated through
`/jim:arch`, never by hand** — the skill owns that file's currency. Consider
extending the doc sweep to assert roster agreement across the three sites, since
the canonical one was corrected during the remediation and these three were not.

## Origin

Post-build review of `issue/011`, AC 13.

## Resolution (2026-08-12)

Fixed across `e7982b7` (the two skill sites) and `d409f8d` (`ARCHITECTURE.md`,
through `/jim:arch`, never by hand).

**Not by correcting the counts — by removing them.** This issue proposes
correcting all three to agree with § 7a's "ten". Working it alongside `#45`,
which had filed the same class against § 7a itself a month earlier, showed why
that would have been wrong twice over:

1. **The canonical roster was itself short.** Derived mechanically —
   `grep -l 'scripts/new\.sh \*' skills/*/SKILL.md`, minus the `issue` skill that
   owns the emitter — the consumer set is **eleven**, not ten. `/jim:blueprint`
   files through `new.sh` from its divergence and reconcile-finding offers, and
   appears in none of the four rosters. Correcting the three to match § 7a would
   have propagated that omission into the sites being fixed.
2. **A count is the defect, not the value of the count.** All four rotted the
   same way, at different times, because a consumer accruing has no mechanical
   consequence for prose stating a number.

So each site now states the roster as a property: § 7a names its consumers with
no leading numeral and says the grant is the definition; `new.sh:4`'s "the seven
surfacing skills" becomes "every skill that files through the candidate-batch
contract"; § 7's untrusted-content roster, which had listed eight and omitted
`/jim:review` and `/jim:verify`, now defers to § 7a rather than re-enumerating;
and `ARCHITECTURE.md`'s two counts are restated the same way. The auto-file rule
likewise binds "those that read `auto_issue_file`" instead of "the nine".

**The sweep this issue's proposed action asked to consider now exists.**
`case_docsurfaces_candidate_batch_roster_matches_the_grant` derives the consumer
set from the emitter grant, requires § 7a to name every member, and additionally
fails if a fixed count reappears in the roster prose — so the next consumer to
accrue fails a case instead of silently widening the gap. That answers the "since
the canonical one was corrected during the remediation and these three were not"
observation mechanically rather than by vigilance.

`ARCHITECTURE.md` remains outside the doc sweep's corpus, as this issue notes;
its currency rides `/jim:arch`, which ran for this change.
