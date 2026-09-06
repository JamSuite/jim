---
id: 20260828-document-the-close-side-resolution-note-convention
num: 418
title: "Document the close-side resolution note convention"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [skill-surface, docs, lifecycle]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T20:44:41Z
updated: 2026-08-29T06:23:18Z
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

## Correction — 2026-08-28

**The claim that the convention is not written down is wrong.**
`docs/notes/process-improvements.md` carries *A resolution note is the durable
record*, which states it directly — a dated `## Resolution` naming what shipped,
the commit, and the case that pins it — and adds a `## Correction` instrument
for a note that overclaims. It has been there for two rounds.

The sweep behind that sentence covered `skills/issue/SKILL.md`,
`docs/features/issues.md` and `WORKFLOW.md`. It did not cover the notes file,
so it found the operator surfaces and missed the one place the rule actually
lived — an enumeration too narrow in exactly the way this collection has a rule
against.

**What survives is the sharper half.** The convention is documented in the
retrospective record and absent from the point of use. An executor reading the
`close` dispatch, the feature doc or the validation checklist meets no rule and
produces a complete-looking close; the rule reaches only whoever reads
retrospectives, which is not who runs the verb. The gap persisting across two
rounds *while the rule was written down* is the argument for moving it, not
against it.

So the fix narrows: not "write it down" but **state it where the verb is**, with
the checklist's transition half as the enforceable form. The two candidate sites
and the open question about `--as wontfix` versus a bare `done` are unchanged.

This correction is appended rather than replacing the description above, because
the overclaim is itself information about how the record was made.

## Resolution — 2026-08-29

Fixed in `70a110e1`.

The Correction's narrowed fix is what landed: not "write it down" but state it
where the verb is. Four surfaces carry it now, two of them the ones the
Correction named as the real gap.

- **`skills/issue/SKILL.md`, the `close` dispatch bullet** — the point of use.
  Names what the fields cannot carry, requires a dated `## Resolution`
  committed with the transition, and closes the open question below.
- **`skills/issue/SKILL.md`, the Validation Checklist's transition half** — the
  enforceable form, the surface an executor applies literally.
- **`docs/features/issues.md`** and **`WORKFLOW.md`** — the two human-facing
  surfaces the original description named. The feature doc also records the
  `## Correction` instrument, which had the same problem: documented only in
  the notes file.

**The open question is answered: unconditional.** A `wontfix` or `obsolete`
explains itself nowhere else, and a `done` whose commit already rides the
closing trailer still owes the part a trailer cannot hold — what pins it, what
was left alone, where the work diverged. Length is proportional to what
happened; absence is not one of the lengths.

**Pinned by `case_docsurfaces_close_records_its_resolution`**, which asserts the
bullet and the checklist *separately* — deleting the checklist item fails one
assertion and deleting the bullet's unconditional clause fails the other, each
proved by mutation. A single "the word appears somewhere in SKILL.md" check
would have passed both mutations, which is the failure mode this collection has
a rule against. Suite 1,693 green.

**What this does not do.** There is still no mechanical source for whether a
given close actually wrote its resolution — that is a property of a body, not of
a declared constant, exactly as the description says. The new case pins that the
*rule is stated*, never that a particular close obeyed it. The checklist is the
only enforcement, and it is an executor-applied one.

**The Correction stands as the record of how this was filed.** Its claim that
the convention was undocumented was wrong; its diagnosis — that a rule
documented only in the retrospective record is enforced only on whoever reads
retrospectives — is what this change acts on.
