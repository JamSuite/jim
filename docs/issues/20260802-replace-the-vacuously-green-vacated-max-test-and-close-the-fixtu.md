---
id: 20260802-replace-the-vacuously-green-vacated-max-test-and-close-the-fixtu
num: 210
title: "Replace the vacuously-green vacated-max test and close the fixture gaps"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [test-integrity, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-02T21:35:13Z
updated: 2026-08-05T02:25:13Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

## Description

**A test survived a verb's retirement as a vacuous green.**
`tests/specreconcile.sh:1401-1413`
(`case_specreconcile_realized_event_inert_to_vacated_max`) still invokes
`jimledger.sh vacated-max`, which blueprint/025 removed. It captures stdout with
stderr suppressed, before and after a realization, and asserts the two are
equal. Both are now the empty string — the verb falls through to `usage`, writes
to stderr, and returns rc 2 which the case never checks. Confirmed by running
the verb against a real `op=split` event that would previously have returned
`009`: output is empty.

So the case passes, its name still advertises coverage of a real guarantee (that
a realization record raises no vacated floor), and it asserts nothing at all.
This is the one place the retirement produced a silently-passing test rather
than a failing one, which is why the build did not notice.

The guarantee itself is still worth holding — it is now carried by the registry
fold instead (a realize record raises no high-water, fixtured at
`tests/jimalloc.sh:646-651`). So the case should be removed rather than
rewritten, unless there is a realizer-side observable worth pinning.

**Orphaned scaffolding left by the same retirement:** `tests/jimfile.sh:154` and
`tests/jimledger.sh:1649` are section headers with no cases beneath them;
`tests/jimledger.sh:1633`'s header still describes the section as
"vacated-max (vacated-id floor source)" though its single surviving case asserts
retirement.

## Fixture gaps found alongside

Four behaviors shipped without a test that would fail if they regressed:

1. **The group-arm provenance fix.** `tests/jimalloc.sh:2373` asserts only the
   prefix `^DUP-ORD\tspec\tui/001\t`, and its scenario produces "records 2 and 3"
   under both the old and new code. The discriminating fixture is
   `allocate a/001` / `group rename a b` / `allocate b/001`, asserting
   `records 2 and 3` (the old code would say `records 1 and 3`). AC 6 says
   "fixtured per shape"; this shape is code-only.
2. **The issue self-rename fix and the issue-arm provenance change** — both
   shipped unfixtured; no test feeds an issue self-rename to a classifier.
3. **`refused:duplicate-in-batch`, the lift's `group` kind, and
   `jimledger.sh pair-events`** have no tests at all.
4. **The widened `move-spec-dir` source gate** gained a positive case and a
   destination-closure case, but no negative asserting a malformed `P-`-shaped
   *source* is refused — the one surface the build widened.

## Proposed action

Delete the vacuous case and the two orphaned headers; add the four fixtures
above. The first is the highest value: it is the only one guarding a fix that
already shipped.

Surfaced by the post-build review of blueprint/025 (findings 14, 20c).

## Resolution (2026-08-05)

The vacuous `vacated-max` case and both orphaned headers are deleted, and the
surviving retirement case's header now states what its body asserts (proven
non-vacuous by re-adding a `vacated-max` dispatch arm and watching it go red).
Five fixtures added: the group-arm and issue-arm provenance discriminators,
issue self-rename survival, the lift's `group` kind end to end, `pair-events`'
three row kinds plus its fail-closed gates, and `move-spec-dir`'s refusal of a
malformed provisional source.

Every one was mutation-tested independently: **13 of 13 mutations red**. The
fail-closed gate fixture asserts the safe outcome — rc 0 *and empty stdout*, no
row leaving the parser — rather than merely that an error appeared, and each of
its three gates was shown individually load-bearing by a separate leak mutation.
No fixture in this set is vacuous.
