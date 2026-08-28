---
id: 20260828-document-the-close-side-resolution-note-convention
num: P-20260828-document-the-close-side-resolution-note-convention
title: "Document the close-side resolution note convention"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [skill-surface, docs, lifecycle]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T20:44:41Z
updated: 2026-08-28T20:44:41Z
origin: "docs/specs/issue/015-epic-authoring-and-views/remediation.md"
---

## Description

## Description

Closing an issue in this project appends a `## Resolution` section to the
record's body. The convention is visible in the history — `docs(issues): close
380 with its resolution`, `close 381 with its resolution` — and the sections
are substantial: what landed and in which commit, what pins the fix or
explicitly does not, where the change went wider than the record asked, and
what a sibling sweep covered.

None of that is written down. `skills/issue/SKILL.md`, `docs/features/issues.md`
and `WORKFLOW.md` contain no statement of it.

## Where it should be and is not

The `close` dispatch bullet in `SKILL.md` documents `--as <outcome>`, that any
developer may close any issue, that the holder record is preserved, and that
`--as duplicate` requires the superseding issue in `duplicates`. It then says
to present the script's output and stop. A reader following it produces a
correct status flip and no resolution.

The Validation Checklist has a capture half ("Before writing (capture / `add`
only)") and a transition half. The transition half checks that the move went
through `transition.sh`, that a refusal was reported as it came back, that no
outcome was invented, and that an `unchanged` result was not retried. It does
not ask whether the close recorded why.

## Why the gap matters more for close than for capture

A capture that omits something is visibly thin — the body is the whole record,
and its absence is the first thing a reader sees. A close that omits its
resolution looks complete: `status: closed`, `outcome: done`, a refreshed
stamp, an index that counts it correctly. Every field a reader would check is
populated and correct. What is missing is the half that cannot be re-derived —
which commit carried the fix, whether a test pins it, what was deliberately
left alone, and where the fix diverged from what was filed.

That is the failure shape `docs/notes/process-improvements.md` calls a false
success: the omission presents as a finished record rather than as an error.

## How it surfaced

Four issues were closed with the fields set and no resolution written. The
developer asked whether resolution notes had been added; they had not. The
sections were then written from the `#380` precedent found by reading git
history, which is the only place the convention is stated.

## The fix

State the rule where the verb is. Two candidate sites, and they are not
alternatives:

- the `close` dispatch bullet, so a reader meets it at the point of use;
- the Validation Checklist's transition half, which is the enforceable form —
  it is the surface an agent applies literally.

Worth deciding at the same time whether the rule is unconditional. A close
`--as wontfix` or `--as obsolete` plausibly needs a reason more than a `done`
does, and a `done` whose commit is already named in the closing commit's
trailer is the weakest case for a long section — but the weakest case is still
not "nothing".

## Related

`#416` fixed a checklist rule that had gone stale and closed by deriving the
rule from the emitter's own vocabulary rather than by hand-correcting the
prose. There is no equivalent mechanical source here: whether a resolution was
written is a property of the body, not of a declared constant, so this one is
prose that has to be stated rather than derived.
