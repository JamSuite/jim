---
id: 20260731-write-the-fixtures-the-plan-named-but-the-build-skipped
num: 178
title: "Write the fixtures the plan named but the build skipped"
status: open
priority: medium
labels: [spec, issue, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:39:02Z
updated: 2026-07-31T12:39:02Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

## Description

Two fixtures named in the plan's task breakdown were never written.

**"Forced no-op rewrite fails loudly."** No test asserts either realizer's
`rewrite failed` message or the rc-1 path — not
`skills/spec/scripts/reconcile.sh:282` nor
`skills/issue/scripts/reconcile.sh:184`. The behavior is implemented; the
criterion is unevidenced.

It was judged unreachable from the CLI during the build, and that reasoning holds:
the bounded scan and the bounded rewrite were verified to match the *same set* of
inputs, so a scan that finds a field cannot be followed by a rewrite that misses
it. But the rc-1 path has reachable consequences anyway — see the index-regen
abort it enables — so it is worth pinning even though it cannot be reached through
the front door. Exercising the functions directly (the pattern `tests/jimalloc.sh`
uses for pure functions) is the available route.

**"Unclosed fence does not skip the tail."** Also unwritten, and not assertable as
worded: under correct CommonMark semantics an unclosed fence *does* extend to EOF.
The clause described a symptom of the boolean-toggle bug rather than a target
behavior. The nearest real assertions — a 4-backtick block containing a 3-backtick
block, and a `~~~` line inside a backtick block — do exist.

Also missing: a fixture placing both `…alpha` and `…alpha-2` in one remap, which
is the case the sweep's match-ordering argument rests on.

## Fix

Write the no-op-rewrite fixture against both realizers; either drop the
unclosed-fence clause as mis-specified or restate it as the assertion actually
wanted; add the multi-row prefix-overlap fixture.

Finding 8 of `docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.
