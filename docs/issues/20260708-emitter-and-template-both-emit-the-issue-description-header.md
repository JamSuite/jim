---
id: 20260708-emitter-and-template-both-emit-the-issue-description-header
num: 69
title: "Emitter and template both emit the issue Description header"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: "jrko"
outcome: done
labels: [issues-system, emitter, template]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-08T20:37:32Z
updated: 2026-09-06T09:10:13Z
origin: conversation
---

## Description

Surfaced while spot-checking the 033-origin issues (#36–#38): filed issues
carry a malformed lead. #33 has a doubled `## Description` header; others (the
033 batch) had an empty `## Description` immediately followed by `## Context`.

## Root cause

The issue-file emitter and the template both own the `## Description` header:

- `skills/issue/scripts/new.sh:437` unconditionally prepends
  `\n## Description\n\n` before `cat`-ing the `--body-file` bytes.
- `skills/issue/assets/issue-template.md:36` also shows `## Description` as
  part of the authored body shape.

Nothing else in `skills/` emits the header — those two are the whole conflict.
The caller-facing contract is silent about it in three places: `SKILL.md` step 6
and §7a both document `--body-file` with no note on what the emitter supplies,
and the emitter's own header comment (`new.sh:9-13`) describes `--body-file` as
appending "those bytes verbatim" — the place a caller would look for the
contract, and the place the omission actually bites.

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
- Say the same thing in the emitter's own `--body-file` header comment, so the
  contract is stated where the script states the rest of its contract.
- Backfill the malformed bodies already in the collection, then regenerate
  `INDEX.md`.

The first three are small, one-time, and cheaper than they look: the emitter
keeps the header and only the template loses it, so the full-file parity
fixture at `tests/issues.sh:3177-3205` — which pins the emitted body lead
exactly — stays green. The backfill is the expensive half; see the scope and
sequencing below.

## Real backfill scope (re-verified 2026-09-06)

Every earlier estimate here was taken against a smaller collection and is now
wrong by roughly 4×. Across **421** issue files:

- **180 doubled `## Description` headers.** The caller mirrored the template
  into its body file, so the emitter's prepend lands on top of the caller's own
  heading. These render visibly wrong — two identical headings in a row — and
  are the half worth fixing.
- **87 empty `## Description` followed by an H2 sibling** (`## Context`,
  `## What`, `## Problem`, and in two cases `## Resolution`). The caller opened
  its body with its own section, so the emitter's heading leads an empty one.
  Cosmetically inert.
- **5 empty `## Description` followed by an H3.** Not malformed — `### …` is a
  subsection *of* Description, which is ordinary nesting. Earlier counts here
  folded these into the empty class; a sweep must leave them alone.
- **2 files carrying no `## Description` at all** — a third shape not named
  before. Both were hand-edited after filing, so this is an editing artifact
  rather than an emitter path, and a sweep should not try to restore the header.
- 147 well-formed.

A backfill can defensibly cover only the 180; the 87 are a judgment call about
whether an empty section is worth a mass edit. Where the empty heading precedes
`## Resolution`, the sweep must not disturb the close-side note.

**Sequencing.** The backfill is a scripted rewrite over the whole collection,
and the tool for it is the subject of two open issues — #404 (`backfill.sh`
rewrites the collection with no preview gate) and #403. Running a 267-file sweep
through an ungated rewriter is the wrong order; #404 lands first.

**The defect is live, not historical.** Of the 20 most recent captures, 5 are
doubled and 6 empty, including files filed on 2026-08-28 and 2026-08-29. Both
malformed shapes are still being produced by current capture paths.

Note that `180ce8b` (2026-07-28) already hand-swept 7 host-handoff bodies for
the doubled variant. It was a manual fix of the symptom in one batch — it left
the dual-emit root cause and every other malformed body untouched, which is why
new captures can still produce both shapes.

All root-cause fixes above remain unimplemented: the emitter still prepends
unconditionally, the template still carries the heading, and neither `SKILL.md`
nor the emitter's own header comment states that `--body-file` is prose only.

## Why low

No behavioral impact — malformed presentation only; indexing and the wikilink
graph are unaffected, so the grade still stands on impact. It no longer stands
on effort: the four root-cause fixes are small and one-time, but the backfill is
a 267-file sweep gated behind another open issue, not the single hand edit
originally implied. The malformed share also grows with every capture until the
root cause is fixed, so the cheap half is worth doing ahead of the sweep.

## Resolution — 2026-09-06 (done)

All four bullets shipped, across three commits.

**Root cause** (`0345a301`). The emitter keeps the heading and every other site
yields: `issue-template.md` no longer carries `## Description`, both `SKILL.md`
body-file steps and the emitter's own usage block state that `--body-file` is
prose only. Emitting nothing new left the full-file parity fixture at
`tests/issues.sh` green, which is what kept the fix small.

**The sweep** (`c4b48df7`, `2d40ec2a`). Hosted as `backfill.sh heading` rather
than a throwaway script — see the correction below. One rule covers both
shapes: remove a `## Description` whose next non-blank line is another `##`
heading. It iterates to a fixed point, since collapsing a pair can expose the
survivor to the same condition, and it walks the frontmatter and code fences so
a heading inside either stays content. A `###` beneath the heading is ordinary
nesting and is spared.

Applied to the collection: 267 of 421 records repaired — 177 keeping one
heading, 90 left with none. The remaining 154 were already well-formed, nesting
a `###`, or carrying no heading at all. The diff is the evidence: across all
267 files it removes exactly two kinds of line, a blank and `## Description`,
and adds none; `INDEX.md` did not change, because the index carries no body
content.

**What pins it:** ten cases in `tests/issues.sh`, each mutation-checked.
Matching any heading level instead of `##` fails the subsection case; removing
the fixed-point iteration fails six; dropping the fence walk fails the fenced
case.

**A correction to this record's own reasoning.** The scope section above called
the sweep a one-time repair, and it is not. `0345a301` made the emitter the sole
owner *by documentation only* — it still prepends unconditionally, so a caller
that repeats the heading produces the doubled shape again. That is why the
repair is a committed, tested verb rather than a script run once and discarded,
and it is the argument that overturned the vehicle originally proposed here.

**Left undone, deliberately.** The emitter could refuse to prepend when the body
already opens with a `##` heading, which would close the class at the mechanism
instead of at the instruction and make this verb genuinely historical. That is a
change to the emitter's contract rather than a repair of the collection, so it
is not folded in here.

Also unchanged: the 2 records carrying no `## Description` at all. Both were
hand-edited after filing, so restoring a heading would invent structure their
authors removed.
