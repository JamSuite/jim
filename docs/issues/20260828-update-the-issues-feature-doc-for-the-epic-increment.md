---
id: 20260828-update-the-issues-feature-doc-for-the-epic-increment
num: 417
title: "Update the issues feature doc for the epic increment"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T11:37:35Z
updated: 2026-08-28T11:37:35Z
origin: "docs/specs/issue/015-epic-authoring-and-views/review.md"
---

## Description

`docs/features/issues.md` was untouched by the epic increment and by its
remediation pass. It contains zero occurrences of `epic`, `join`, `leave`,
`--type`, `--part-of` or `--epic`.

## The four stale places

1. **`:33-46`** — the Usage block enumerates the verb groups and omits
   `join <id> <umbrella>` and `leave <id> <umbrella>`, and both capture forms
   (`add <subject> --type epic`, `add <subject> --part-of <umbrella>`).

2. **`:101`** — states verbatim: *"Five verbs move it, and they are the
   supported path."* There are seven. The table beneath (`:103-109`) lists the
   five.

3. **`:199-207`** — the Read views section describes `list`'s filter
   vocabulary and `stats`' output with no mention of the `--epic` axis, the
   `Epics: N open · M closed` headline, or the `== Epics ==` rollup.

4. **`:211-218`** — states the index has *"Four sections"* and tables them.
   `index.sh` writes five; its own header comment was corrected to say so.

## Why it stayed

The doc-surface sweep in `tests/docsurfaces.sh` checks lifecycle verbs against
README, WORKFLOW and the skill body — this file is not among the surfaces that
check quantifies over. The first review recorded this as one stale statement;
the post-remediation sweep found four.

## The fix

Bring the doc up to the shipped surface. Then consider whether
`case_docsurfaces_transition_verbs_are_documented` should include
`docs/features/issues.md` in its surface list, since it is the feature doc for
exactly the verbs that check derives.
