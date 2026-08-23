---
id: 20260823-issue-face-does-not-declare-the-validator-lockstep-contract
num: 367
title: "issue face does not declare the validator-lockstep contract"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, blueprint, contract]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:45:32Z
updated: 2026-08-23T23:45:32Z
origin: "docs/specs/issue/012-schema-and-state-model/spec.md"
---

## Description

## Description

The contract graph carries one leak: `platform` declares a requirement on
`issue.validator-lockstep`, and the `issue` group's Provides face declares no
such entry. The guarantee is real and holding — only the declaration is absent.

## The state

`platform`'s face requires:

> `issue.validator-lockstep` — the two `is_valid_id` copies in the issue group

`issue`'s face contains no `validator-lockstep` entry at all.

## The guarantee itself holds

Verified: the three copies of `is_valid_id` — in `jimfile.sh` (platform's own),
`index.sh` and `render.sh` (the issue group's two) — are byte-identical, cksum
`3250514351`, 508 bytes each. A change touching `index.sh` was checked against
this edge and the function was untouched.

So this is a declaration gap, not a breakage.

## Why it matters

The reconcile pass reports it as a leak on every run, and a leak that is known
and permanent trains readers to ignore the leak count — which is the counter
that would otherwise tell them a real one appeared.

More concretely: `issue` cannot know that `platform` depends on those two
copies staying in lockstep, because its own face never says so. The next person
editing `is_valid_id` in `index.sh` has no declaration telling them it is a
contract rather than a local helper.

## A judgment call worth stating

An earlier reconcile pass cleared this edge. Recording it now is a change of
judgment about the same evidence, not a newly-appeared regression — worth
saying plainly so it does not read as drift that crept in.

## Direction

Declare `validator-lockstep` on the `issue` group's Provides face, with the
byte-identical guarantee stated, so the requirement and the provision agree.
