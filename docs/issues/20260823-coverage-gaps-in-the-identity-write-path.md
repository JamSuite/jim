---
id: 20260823-coverage-gaps-in-the-identity-write-path
num: 357
title: "Coverage gaps in the identity write path"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [testing, migration]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:21:50Z
updated: 2026-08-24T21:34:19Z
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

## Resolution (2026-08-24)

Fixed in `5e79803`. Six cases for the four gaps, and each was checked by
mutating the region it covers and confirming the case goes red.

**Two of the four gaps were true of the sibling conversion as well.** This issue
named `apply_identity_plan` in both, and a census of all three applies settled
which of them the rule actually reaches:

| | index-failure case | fault coverage | placement routing |
| :--- | :--- | :--- | :--- |
| `apply_plan` (prefix) | 1 | 2 | 1 |
| `apply_schema_plan` | 1 | **0** | **0** |
| `apply_identity_plan` | 1 | **0** | **0** |

So `schema` gained a staging-failure case and a placement case beside
`identity`'s. Counting the guard per sibling site is what surfaced it — the same
census form that found the third path-composition site earlier in this
remediation.

**The seams were not added.** This issue asks for a fault-injection seam
matching `apply_plan`'s. Both branches are reachable from outside: making the
issues directory unwritable fails the `mktemp` for real. `apply_plan` carries
seams because its failure points sit inside git plumbing, where nothing external
can reach them — so the asymmetry is justified rather than a gap, and a seam
here would be production code whose only purpose is being tested. The `mv`
failure branch is still unproven; it needs a write the unprivileged user cannot
arrange.

**The remap apply gap was the real one, and worse than described.** No test
persisted a remapped value at all, and mutation confirms it: putting `--to`
through the configured form — which is precisely what remap must not do — killed
no case in the suite. It does now.

**The placement case for `schema` pins a refusal, not a success.** Driving it
through the routing loop surfaced that the conversion refuses at the
destination: it recovers each filer from the commit that created its file, and a
materialized collection is outside any work tree. That is already tracked as its
own issue and is fail-closed rather than wrong, so the case pins the current
contract — closing that gap has to change this assertion deliberately rather
than have a green suite hide the change.
