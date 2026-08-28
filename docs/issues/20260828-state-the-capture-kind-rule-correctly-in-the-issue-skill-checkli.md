---
id: 20260828-state-the-capture-kind-rule-correctly-in-the-issue-skill-checkli
num: P-20260828-state-the-capture-kind-rule-correctly-in-the-issue-skill-checkli
title: "State the capture kind rule correctly in the issue skill checklist"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [skill-surface, epic]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T11:37:31Z
updated: 2026-08-28T11:37:31Z
origin: "docs/specs/issue/015-epic-authoring-and-views/review.md"
---

## Description

`skills/issue/SKILL.md:382`, in the Validation Checklist under "Before writing
(capture / `add` only)", still reads:

> `- [ ] `type` is `issue`, and `claimed-by` and `outcome` are both empty:
>   nothing is held or finished at the moment it is filed.`

That is the rule the epic increment reverses. It contradicts two statements
earlier in the same file — `SKILL.md:34` (`--type <issue|epic>`) and `:160`
("`issue`, or `epic` when the capture asked for an umbrella").

## Why it matters

The checklist is written as a literal pre-write gate. An agent applying it to
an epic capture meets a rule that its own correct draft fails, and the two
available readings are both bad: ignore the checklist, or "fix" the draft by
setting `type` back to `issue` and file an ordinary issue where an umbrella
was asked for.

## How it survived

The line predates the increment (`b2b68b7`). The build's plan told it to delete
the equivalent claim from `new.sh`'s comment and from the `type` field bullet;
the remediation pass then worked from the review finding's enumeration of four
sites. The file had five. Neither pass derived the set — both inherited it.

Three independent investigators reached this in the post-remediation review.

## The fix

Amend to state what is now true — `type` is `issue`, or `epic` when `--type
epic` was given.

## The wider point

The doc-surface sweep added by the same increment
(`case_docsurfaces_capture_flags_reach_the_emitter_invocation`) quantifies over
the emitter's own flag parser, so a new flag cannot go undocumented in the
invocation. It does not quantify over the surfaces that restate the emitter's
*semantics* in prose, which is where this survived. Worth considering whether
the checklist should be derived rather than hand-maintained.
