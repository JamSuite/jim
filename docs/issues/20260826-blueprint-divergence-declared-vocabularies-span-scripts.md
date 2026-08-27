---
id: 20260826-blueprint-divergence-declared-vocabularies-span-scripts
num: 402
title: "Blueprint divergence: declared vocabularies span scripts"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, drift]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T19:36:21Z
updated: 2026-08-27T11:21:07Z
origin: "docs/specs/issue/000-blueprint/spec.md"
---

## Description

## The invariant

`declared-vocabularies` (high) in the `issue` group's blueprint: every vocabulary
a rule quantifies over is a declared constant, and every site that quantifies
iterates that constant rather than restating its members. A guard, a parser
dispatch and a test that each enumerate the same set independently agree only by
coincidence, and the one that is short is silent about it.

`resolved: fix the code`

## The divergence

Two vocabularies are each declared twice, in different scripts, with nothing
tying the copies together:

```
skills/issue/scripts/index.sh:78       readonly ISSUE_OUTCOMES=(done wontfix duplicate obsolete)
skills/issue/scripts/transition.sh:54  readonly ISSUE_OUTCOMES=(done wontfix duplicate obsolete)

skills/issue/scripts/index.sh:77       readonly ISSUE_TYPES=(issue epic)
skills/issue/scripts/render.sh:76      readonly TYPE_TOKENS=(issue epic)
```

The outcome vocabulary is restated a third time as prose:

```
skills/issue/scripts/render.sh:544  close <id> [--as <o>]   finish it; <o> is done | wontfix | duplicate |
```

## Why they agree only by coincidence

- **No `SYNC` marker on any of the four declarations.** The group's other
  cross-copy guarantees carry one — `is_valid_id`, the timestamp shape, the
  branch-name gate — and `cross-copy-lockstep` is what holds those in step. These
  four are outside that mechanism entirely.
- **No test cross-checks any pair.** `grep -rn TYPE_TOKENS tests/` returns
  nothing at all: the `--type` filter vocabulary is never compared against the
  vocabulary `index.sh` validates the same field with.
- **The one test that exercises the outcome set samples it.**
  `case_transition_close_accepts_the_other_outcomes` at
  `tests/issues.sh:4383` loops `for o in wontfix obsolete` — two of four
  members, hand-typed, rather than reading the declaration.
- **The test helper that does read declarations reads only one script.**
  `index_vocabularies` in `tests/issues.sh` discovers `ISSUE_[A-Z_]+` constants
  from `index.sh` alone, so a divergence in `transition.sh`'s copy is invisible
  to it.

## What is not affected

The discipline holds well *within* each script. `render.sh` declares its
vocabularies once and every dispatch and guard iterates them through `in_list`,
and the test helpers `script_vocabulary` / `render_vocabulary` /
`index_vocabularies` read a vocabulary from the code's own declaration rather
than retyping its members. The set of frontmatter fields sanitized before they
are judged is derived from a declaration too, not restated. The gap is at the
seams between scripts, not inside them.

## Fix shape, and the part worth deciding first

A `SYNC` marker on each pair plus a cross-script test would match how this group
already holds `is_valid_id` and the timestamp shape in step, and would put both
vocabularies under the mechanism that exists for exactly this.

The awkward member is the prose. `render.sh:544` sits inside a single-quoted
heredoc, so it cannot interpolate a constant even in principle — it is a
hand-typed copy by construction. Either the help text is restructured so the
vocabulary can be composed into it, or that third copy stays hand-typed and
wants its own assertion comparing the help output against the declaration.
Deciding which comes first, because it decides whether this is a marker-and-test
change or a help-surface change.

The two vocabularies also differ in kind: `ISSUE_OUTCOMES` is the same name and
the same members in both scripts, while the type vocabulary wears two different
names (`ISSUE_TYPES`, `TYPE_TOKENS`) for one set. The second is the easier one
to leave diverging, and the harder one to notice.

## Provenance

Surfaced by the living-intent sensor over the range that fixed the index's
lifecycle classification. The duplication predates that change; it reached the
fork because the sensor selects judges by what the change touches, not by what
introduced the finding.

## Census extended

A later `/jim:verify --since` grounding run judged this invariant again and
confirmed both instances above, then found four more. The record was two of
six.

**`new.sh` retypes two vocabularies as `case` literals.** Rather than
iterating the declared arrays, it inlines them:

```
priority)  low|medium|high|critical
status)    open|closed
```

The priority list restates `PRIORITY_TOKENS` in a different order. The status
list is worse: it is a **silent subset** of `STATUS_TOKENS=(open active
closed)`, dropping `active` with no comment saying why filing time is narrower
than the lifecycle. Filing an `active` issue is not a thing anyone should do —
a capture is always `open` — so the subset is probably intended, and that is
exactly the problem this invariant names: an intended narrowing and an
accidental omission are indistinguishable when the set is retyped rather than
derived.

**Two tests hand-retype partial slices of `transition.sh`'s vocabularies.**
`tests/issues.sh` loops two of the four `ISSUE_OUTCOMES`; `tests/place.sh`
loops four of the five transition verbs, with `close` silently missing. Both
sit in the same file as tests that read `render.sh`'s and `index.sh`'s
constants mechanically off the script — so the discipline exists in the corpus
and these two did not get it.

**Where the discipline does hold**, worth recording so a fix does not
over-reach: inside `render.sh` every quantifying site iterates its own declared
arrays, `index.sh`'s vocabularies are exercised by tests that discover them off
the script, and `is_valid_id` is SYNC-marked across three files with a
cross-file test pinning byte agreement. The failure is at the seams between
scripts, not within them.

## Fix shape, revised

The two same-file duplications need a marker and a test binding them, as
`is_valid_id` has. The cross-script cases need a decision this record cannot
make for them: either one script owns each vocabulary and the others read it,
or every copy carries a SYNC marker and a test compares them. The test-side
retyping is the cheapest of the six and the most clearly wrong — those loops
should read the constant, which is what their neighbours in the same file
already do.
