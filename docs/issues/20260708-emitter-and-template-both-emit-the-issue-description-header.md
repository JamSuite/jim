---
id: 20260708-emitter-and-template-both-emit-the-issue-description-header
num: 69
title: "Emitter and template both emit the issue Description header"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issues-system, emitter, template]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-08T20:37:32Z
updated: 2026-07-29T20:09:12Z
origin: conversation
---

## Description

Surfaced while spot-checking the 033-origin issues (#36–#38): filed issues
carry a malformed lead. #33 has a doubled `## Description` header; others (the
033 batch) had an empty `## Description` immediately followed by `## Context`.

## Root cause

The issue-file emitter and the template both own the `## Description` header:

- `skills/issue/scripts/new.sh:204` unconditionally prepends
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
- Backfill the malformed bodies already in the collection, then regenerate
  `INDEX.md`.

## Real backfill scope (verified 2026-07-29)

The original "backfill the one existing instance" was written off a spot-check
and understates this by roughly 57×. Across 134 issue files, both variants named
above are present:

- **6 doubled `## Description` headers** — #33, #107, #108, #109, #110, #121.
  These render visibly wrong (two identical headings in a row) and are the half
  worth fixing.
- **51 empty `## Description` immediately followed by another `##` heading** —
  the caller opened its body with `## Context` (or similar), so the emitter's
  heading leads an empty section. Cosmetically inert.

A backfill can defensibly cover only the 6; the 51 are a judgment call about
whether an empty section is worth a mass edit.

Note that `180ce8b` (2026-07-28) already hand-swept 7 host-handoff bodies for
the doubled variant. It was a manual fix of the symptom in one batch — it left
the dual-emit root cause and every other malformed body untouched, which is why
new captures can still produce both shapes.

All three root-cause fixes above remain unimplemented as of this verification:
the emitter still prepends unconditionally, the template still carries the
heading, and `SKILL.md` still documents `--body-file` with no prose-only note.

## Why low

No behavioral impact — malformed presentation only; indexing and the wikilink
graph are unaffected. Note the shape of the work, though: the three root-cause
fixes are small and one-time, while the backfill is a scripted sweep over the
collection rather than the single hand edit originally implied.
