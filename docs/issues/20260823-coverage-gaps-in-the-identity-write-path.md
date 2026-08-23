---
id: 20260823-coverage-gaps-in-the-identity-write-path
num: 357
title: "Coverage gaps in the identity write path"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [testing, migration]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:21:50Z
updated: 2026-08-23T23:21:50Z
origin: "docs/specs/issue/013-recorded-identity-schemes/review.md"
---

## Description

## Description

The identity rewrite's write path has four coverage gaps. None is a known
defect; each is a place where a defect would not be caught.

## The gaps

**The remap apply path is never exercised.** All six `--from`/`--to` cases stop
at the preview; every apply case uses `--renormalize --apply`. Remap is the one
mode that persists the operator's supplied value verbatim rather than a
form-derived one, and that specific behaviour is unique to the remap-plus-apply
combination — so the thing most particular to it is the thing untested.

**No fault-injection seam for `apply_identity_plan`.** Its sibling `apply_plan`
has `MIGRATE_FAIL_STAGING` and `MIGRATE_FAIL_COMMIT` seams with dedicated tests
for the mid-run failure branches. `apply_identity_plan`'s mktemp, awk and mv
failure branches are correct by inspection and unproven by test.

**No case pairs `identity` with an active placement branch.** Placement routing
coverage exists for `migrate.sh prefix --apply`, but nothing drives the new
subcommand — with its new `--from`/`--to` flags — through the routing loop
end-to-end.

**`transition.sh`'s index-failure path has no test.** It is the pattern the
migrate fixes were modelled on, and the only one of the three without a
failure-injection case of its own.

## Why it matters

The most valuable defect of this increment was found by running the verb
against the real collection, not by the tests that passed over it — every
fixture used addresses the alias mapping said nothing about, so the gap sat in
the blind spot between them. These four gaps are the same shape: regions where
the fixtures do not reach.

Origin: `docs/specs/issue/013-recorded-identity-schemes/review.md` — Finding 13.
