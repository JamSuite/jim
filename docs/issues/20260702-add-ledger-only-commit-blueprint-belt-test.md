---
id: 20260702-add-ledger-only-commit-blueprint-belt-test
num: 31
title: "Add ledger-only commit-blueprint belt test"
status: closed
priority: low
labels: [jimledger, tests]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-02T09:30:16Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/003-blueprint-update-guard/review.md
---

## Description

## Context

Spec 031's fix-only edge has `commit-blueprint` run when every proposed
blueprint edit was withheld at the violation fork: `spec.md` is unchanged, so
the path-scoped commit carries `ledger.md` alone. The post-build review
(finding 4) confirmed this rests on git pathspec-commit semantics — sound,
but no case in `tests/jimledger.sh` exercises the ledger-only variant; the
existing `commit-blueprint` case dirties both files.

## What

Add a belt case to `tests/jimledger.sh`: append a ledger line with `spec.md`
committed-and-unchanged, run `commit-blueprint`, assert the commit succeeds
and contains only `ledger.md`. Optionally vary the commit message for the
ledger-only case — `docs(blueprint): update 000-blueprint` currently
overstates what a fix-only run landed.

## Resolution

Added `case_jimledger_commit_blueprint_ledger_only` to `tests/jimledger.sh`:
seeds a committed clean blueprint, appends a fix-only guard-outcome ledger line
leaving `spec.md` untouched, runs `commit-blueprint`, and asserts rc 0, the
commit carries `spec/ledger.md` alone (no `spec.md`), and the tree is clean
after. Locks in the git pathspec-commit behavior review Finding 4 flagged as
untested. Full `jimledger.sh` suite green (44/44).

The optional commit-message variation is intentionally **not** done — it would
add branching to `cmd_commit_blueprint` to detect an unchanged `spec.md`, and
the overstated message is cosmetic (the ledger line itself is the durable
record). Left as a deliberate non-change, not an oversight.
