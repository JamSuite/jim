---
id: 20260731-fixture-or-revert-the-ordinal-width-narrowing-in-canonicalizatio
num: 175
title: "Fixture or revert the ordinal width narrowing in canonicalization"
status: open
priority: medium
labels: [file, scripts, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:38:40Z
updated: 2026-07-31T12:38:40Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

## Description

`alloc_canon_specid` (`skills/file/scripts/jimalloc.sh:164-181`) rejects an
ordinal wider than `ALLOC_MAX_ORD_DIGITS`. It replaced `alloc_valid_specid` as the
guard at three comparison sites in `alloc_resolve_spec`, and that guard accepted
any `^[0-9]+$`.

Three divergences for inputs that previously resolved:

- **Query side** — `resolve spec grp/1234567890123456` now exits 1 with
  `error: invalid spec id`, whose message does not mention the width policy.
- **Anchor side** — the joint gate drops a record when *either* id fails, so a
  `spec rename <over-wide-src> core/003` no longer anchors and no longer sets
  `known`. An id whose only establishing record is such a rename now reports
  `not allocated` at rc 1.
- **Replay side** — a `spec rename core/003 grp/<16 digits>` is not applied, so
  resolve returns the pre-rename name silently at rc 0.

## Assessment

All three are crafted-log-only: this build cannot mint such a record
(`alloc_next_id_spec` refuses, `alloc_seed_derive_specs` refuses, the fold skips),
and only allocate records are emitted at all. The change is arguably correct
hardening that brings resolve under the width policy the constant already
declares.

But DD 2 specified padding, never width. It rode in from reusing the helper as the
guard, and none of the three divergences is fixtured — the two padding fixtures
would pass under a canon helper with no width check at all.

## Fix

Decide the intent and record it: either fixture the width policy as deliberate
(and say so in the docstring), or restore the prior acceptance at the resolve
sites so canonicalization changes padding only.

Finding 5 of `docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.
