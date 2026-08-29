---
id: 20260828-state-the-capture-kind-rule-correctly-in-the-issue-skill-checkli
num: 416
title: "State the capture kind rule correctly in the issue skill checklist"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [skill-surface, epic]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T11:37:31Z
updated: 2026-08-28T20:27:21Z
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

## Resolution

Fixed in `d4984a8c`. The line now reads *`type` is `issue`, or `epic` when
`--type epic` was given — the kind the flag named, never one inferred from the
subject's wording*.

**Split rather than amended.** The bullet carried two unrelated claims, and only
one was falsified; `claimed-by` and `outcome` being empty at filing time is
still true and now sits on its own line, so a future change to one rule cannot
drag the other with it.

**The wider point this record raised is what actually closes it.** A hand
correction would have fixed the pass that noticed the drift and left the next
one exposed — which is precisely this record's own history, since the line
survived both the build and a remediation pass that each worked from someone
else's list of sites. `case_docsurfaces_capture_kinds_reach_the_checklist` now
derives the vocabulary from the emitter's own `ISSUE_TYPES` array, the way the
lifecycle sweep derives from `TRANSITION_VERBS`, so a third kind cannot reach
the parser while the checklist still forbids it. Red-verified against the exact
pre-fix wording, where it names `epic` as the missing kind.

**The set was derived, not inherited — and it was one site.** A sweep across
every skill body, feature doc, README, WORKFLOW and the issue template found no
other live restatement of the superseded rule; `assets/issue-template.md` and
the two earlier statements in this same file were already correct. So the
"three investigators found it independently" count was the count of readers,
not of sites.

**Scope note.** Only the kind rule is derived. The rest of the capture
checklist is still hand-maintained prose, and this record's suggestion that the
whole checklist might be derived is neither taken nor refused here.
