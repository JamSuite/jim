---
id: 20260829-declare-the-mirrored-branch-name-gate-on-platform-s-provides-fac
num: 420
title: "Declare the mirrored branch-name gate on platform's provides face"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, contract-graph, drift]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: [20260829-machine-resolvable-contract-graph]
created: 2026-08-29T05:45:32Z
updated: 2026-08-29T07:48:26Z
origin: "BLUEPRINT.md"
---

## Description

## Description

The contract-graph reconcile classifies `issue` → `platform`
"valid-branch-shape" as a **leak**: the `issue` group requires a surface that
`platform`'s provides face never declares.

The coupling itself is real and correct. `place.sh`'s branch-name gate is a
byte-identical mirror of the allocator's own, marked on both sides in code and
compared by a test. What is missing is `platform`'s half of the *declaration*.

## Where

- `docs/specs/issue/000-blueprint/spec.md` → Requires → `platform.valid-branch-shape`
  — states the mirror, the reason the two must agree, and the one sibling rule
  deliberately not mirrored.
- `docs/specs/platform/000-blueprint/spec.md` → Provides — no entry declares a
  branch-shape definition. The `jimalloc.sh` entry mentions validating "the
  branch through `git check-ref-format` before it reaches git", which is the
  allocator validating branches for its own use, not a surface it publishes for
  another group to mirror.

## The asymmetry, against the case that is done right

The id validator is the same kind of contract and is declared on both sides:

- `issue` publishes it as a Provides entry — `is_valid_id` **validator
  lockstep** — whose text says outright that it "is a cross-group contract
  rather than a local helper" and that "the platform group requires these copies
  to hold the line".
- `platform` carries the matching Requires entry — `issue.validator-lockstep`.

The branch-shape mirror has only the consumer's half. A reader of `platform`'s
blueprint has no way to learn that another group's gate is byte-identical to
`alloc_valid_branch` and will break if it moves.

## Why it matters

The code-level guard holds: both copies carry a `SYNC(valid-branch)` marker and
`case_place_valid_branch_agrees_with_the_allocator_copy` compares them. So this
is not a live drift risk — it is a face that under-reports what the group is
party to.

The consequence is felt at the blueprint tier rather than the code tier. A
regeneration of `platform`'s blueprint reads only `platform`'s own artifacts, so
nothing puts the obligation back; the reconcile reports the same leak on every
run; and any blast-radius question asked about the allocator's branch handling
answers from a graph that does not record the edge.

## The fix

Promote the branch-shape definition to `platform`'s Provides face, mirroring how
`issue` publishes the validator lockstep — an entry naming it as a cross-group
contract whose copies must move together, so a regeneration cannot quietly drop
the obligation.

Severing is the other option the finding names, but it is the wrong one here:
the mirror exists deliberately, and its stated reason — a branch the allocator
would refuse must not be one the placement door accepts — is still true.

## What the reconcile did in the meantime

The derived graph no longer carries the row, because the graph is the join of
declared faces and there is nothing on the provider side to join to. Restoring
the row is a consequence of fixing the face, not a separate step.
