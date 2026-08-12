---
id: 20260812-three-surfacing-skill-roster-counts-are-stale
num: 317
title: "Three surfacing-skill roster counts are stale"
status: open
priority: low
labels: [issue, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:42:11Z
updated: 2026-08-12T03:42:11Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

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
