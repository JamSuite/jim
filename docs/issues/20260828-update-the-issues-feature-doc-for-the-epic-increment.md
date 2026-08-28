---
id: 20260828-update-the-issues-feature-doc-for-the-epic-increment
num: 417
title: "Update the issues feature doc for the epic increment"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T11:37:35Z
updated: 2026-08-28T20:28:03Z
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

## Resolution

Fixed in `b58b4d5c`, and the doc-surface question this record left open is
answered yes.

**Five stale places, not the four filed.** The Usage block, the "five verbs"
claim and its table, the read-views section, and the "four sections" index
claim were all as recorded. The fifth: *Interactive capture* described
`add <subject>` with neither flag — the section a reader would actually consult
to learn how to file an umbrella. It was found by deriving the set from the
doc's own structure instead of working from this record's line numbers, which
is the same failure the sibling checklist record is.

**The sweep now covers this file, which is the durable half.** This is the
feature doc for exactly the verbs that
`case_docsurfaces_transition_verbs_are_documented` derives from
`TRANSITION_VERBS`, and it was the one surface that check
did not quantify over — which is why the drift survived. The probe now accepts
a verb followed by a space as well as by its closing backtick, because this doc
names its verbs with operands (`` `join <id> <umbrella>` ``); `closed` and
`claimed-by` still fail to match, since the character after the verb decides
it. Red-verified against the pre-fix doc, where it names exactly
`issues.md:join` and `issues.md:leave`.

**The remaining count claims were checked rather than assumed.** "Four groups"
of integrity warnings and "three sections" of insights are both still accurate;
they were verified against what the doc itself lists rather than left for the
next sweep to find.

**Arguability, as recorded.** No acceptance criterion required updating this
file, so it stays the weaker of the build-scope four. What is not arguable is
the check: a doc that restates a derived vocabulary and is not swept is a
surface that will go stale again.
