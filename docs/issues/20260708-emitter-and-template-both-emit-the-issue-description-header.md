---
id: 20260708-emitter-and-template-both-emit-the-issue-description-header
num: 69
title: "Emitter and template both emit the issue Description header"
status: open
priority: low
labels: [issues-system, emitter, template]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-08T20:37:32Z
updated: 2026-07-08T20:37:32Z
origin: conversation
---

## Description

Surfaced while spot-checking the 033-origin issues (#36–#38): filed issues
carry a malformed lead. #33 has a doubled `## Description` header; others (the
033 batch) had an empty `## Description` immediately followed by `## Context`.

## Root cause

The issue-file emitter and the template both own the `## Description` header:

- `skills/issue/scripts/new.sh:151` unconditionally prepends
  `\n## Description\n\n` before `cat`-ing the `--body-file` bytes.
- `skills/issue/assets/issue-template.md:18` also shows `## Description` as
  part of the authored body shape.

A drafting caller that mirrors the template into its body file writes a second
`## Description` (→ #33's doubling); one that starts its body with `## Context`
instead leaves an empty Description section (→ the 033 batch). Neither breaks
indexing — `index.sh` parses line-oriented and wikilinks still resolve — so the
impact is cosmetic, but every capture path is exposed.

## Proposed fix

Make the emitter the sole owner of the header:

- Drop `## Description` from `issue-template.md`'s body placeholder so the
  template shows only the prose the caller supplies.
- Add a one-line note to `skills/issue/SKILL.md` step 6 (and the 7a
  candidate-batch emitter call) that `--body-file` is prose only — the emitter
  supplies the `## Description` heading.
- Backfill the one existing instance: fix #33's stored body, then regenerate
  `INDEX.md`.

## Why low

No behavioral impact — malformed presentation only; indexing and the wikilink
graph are unaffected.
