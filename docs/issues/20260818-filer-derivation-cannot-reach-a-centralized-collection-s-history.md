---
id: 20260818-filer-derivation-cannot-reach-a-centralized-collection-s-history
num: 353
title: "Filer derivation cannot reach a centralized collection's history"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, migration, placement, attribution]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-18T22:03:32Z
updated: 2026-08-18T22:03:32Z
origin: "docs/specs/issue/012-schema-and-state-model/plan.md"
---

## Description

## Context

The collection conversion recovers each issue's filer from the commit that
created its file. Under the default placement the collection sits in the
working tree and that reads the right history. Under a branch placement the
collection is materialized into a temporary directory outside any work tree, so
there is no history to read at all; the conversion detects this and refuses,
naming the cause.

Spec `issue/012` anticipated the problem. Handoff Insight 3 records that "when
the collection is centralized on a designated branch, the relevant history is
that branch's, not the working branch's — and files that moved during
centralization may not present their original creating commit," and routed it to
research. It was not taken up there, so no design decision, task or test covers
it, and the build met it as an implementation detail rather than a designed
behavior.

## Why it matters

Two effects, and the second is the serious one.

**The conversion is unavailable exactly where the feature is aimed.** A shared
collection is the motivating case for recording identity at all — separating
one contributor's work from everyone else's only matters once the collection is
centralized. A team in that position cannot convert what they have.

**A naive fix would silently misattribute.** Pointing the derivation at the
destination branch is a small change, and it is the obvious one to reach for.
But if a project centralized by copying its issues onto a new branch, the
commit that adds each file on that branch is the centralization itself. Every
issue would then be attributed to whoever performed the move: present,
plausible, and wrong — and wrong in a way that reads as a real attribution
afterwards, with a per-person view built on top of it.

The refuse-loudly criterion does not protect against this. It catches the
*absence* of an answer, never a confidently wrong one. Today's refusal is safe
because the materialized collection happens to sit outside a work tree, not
because anything recognizes a flattened history.

## What

Decide what correct attribution means when centralization has flattened the
history, then build to that decision. The git invocation is the small half.

Shapes worth weighing, cheapest first:

1. **Read the destination branch's history** at the collection's repo-relative
   path rather than the materialized one. Small, and sufficient for a project
   that has always kept its collection on that branch. Insufficient alone,
   because it is exactly the change that introduces the misattribution above.
2. **Recognize a flattened history and refuse it.** A collection whose files
   nearly all share one creating commit is a record of a migration, not of
   filing. Detecting that turns the dangerous case into a loud one, and extends
   refuse-loudly to cover a wrong answer rather than only a missing one.
3. **Follow the history through the centralization** where it remains
   reachable, so the original filing commits are still the source.
4. **Require the conversion before centralizing** and say so, treating a
   collection centralized beforehand as having no recoverable filer.

(2) is the part that should not be skipped whichever of the others is chosen.

## Constraints

- Refuse-loudly must be extended to cover a confidently wrong answer, not only
  a missing one; that is the property this issue exists to add.
- The derivation costs one version-control invocation per file. Acceptable for
  a one-shot conversion, unacceptable on any read path.
- No new identity layer: the recorded value stays whatever version control
  supplies, unmodified.
