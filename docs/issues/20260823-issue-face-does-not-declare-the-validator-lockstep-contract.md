---
id: 20260823-issue-face-does-not-declare-the-validator-lockstep-contract
num: 367
title: "issue face does not declare the validator-lockstep contract"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: "jrko"
outcome: done
labels: [issue, blueprint, contract]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:45:32Z
updated: 2026-08-25T05:16:50Z
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

## Resolution (2026-08-25)

Fixed in `a353589`, with the derived graph rewritten in `649485c`. The fix
landed inside a full regeneration of the group's blueprint rather than a
targeted edit, because the enumeration below could not be reached any other
way.

**The rule reached three couplings where this issue named one.** A census of
every sync marker in the repo found three byte-identity couplings crossing the
`issue`/`platform` boundary, not one:

- `is_valid_id` — `jimfile.sh` + `index.sh` + `render.sh`, 508 bytes each,
  compared by a test, and the only one either face declared
- `valid-branch` — `place.sh` mirrors the allocator's gate, compared by a test,
  declared by neither face
- `ts-shape` — three issue-group timestamp guards plus a fourth copy in
  `jimfile.sh`, and only the three are compared

A fourth marker, `write-contained`, is *deliberately* asymmetric and says so in
its own comment; recording it as lockstep would have asserted something false.

The face now declares the validator lockstep as this issue asked, and records
the branch-shape mirror on the Requires side. That closes the leak this issue
names and opens a new one — `issue` now requires `platform.valid-branch-shape`,
which platform's face does not declare — which is the coupling becoming visible
rather than a regression. The ts-shape gap is filed separately.

**One thing the fix had to change beyond its wording.** `jimverify.sh faces`
recognizes only Provides entries whose first token is backticked; a bold-first
entry is invisible to it. Written in the obvious shape the new entry would have
been readable by a person and absent from every mechanical consumer of the face
— half a declaration, which is the failure this issue is about. Reshaping it
moved the face counters from 22/9 to 23/10. Two pre-existing entries, the § 7a
candidate-batch contract and the untrusted-content discipline, are still
bold-first and still invisible.

The regen also corrected a stale Requires claim unrelated to this issue: the
face credited `platform.jimfile-cli` with ordinal minting via `next-id` and
`next-num`, and the group calls neither — minting moved to the allocator.
