---
id: 20260801-re-validate-the-origin-registry-tip-before-git-interpolation
num: P-20260801-re-validate-the-origin-registry-tip-before-git-interpolation
title: "Re-validate the origin registry tip before git interpolation"
status: open
priority: medium
labels: [platform, scripts, id-coordination, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-01T00:22:45Z
updated: 2026-08-01T00:22:45Z
origin: docs/specs/platform/000-blueprint/spec.md
---

## Description

## Description

`alloc_resolve_remote_tip` reads the origin-tier registry tip out of
`git ls-remote` field 1 (`skills/file/scripts/jimalloc.sh:1018`) and interpolates
it later at `:1198` and `:1645` without passing it back through the id boundary.

The sibling pattern in `jimledger.sh` does re-validate: `resolve_head` runs git's
own output through `validate_sha` before use. So the two scripts disagree about
whether git's output is trusted once it comes back.

## Why it matters

The value comes from a *remote* — the coordination branch is push-writable, and
`ls-remote` output is attacker-influenceable by anyone who can write a ref there.
Every other untrusted token in this script crosses `jimfile.sh valid-id` before
reaching git; this one is the exception, and it reaches git as a revision
argument.

Narrow in practice: git's own ref-name rules constrain what can appear, and the
CAS compares the value rather than executing it. It is the asymmetry that is
worth closing — the invariant `ref-validation` asserts *every* untrusted ref is
validated before git interpolation, and this is the one site where that holds by
git's grammar rather than by jim's gate.

## Fix

Re-validate the resolved tip through the same boundary the rest of the script
uses, matching `jimledger.sh resolve_head`'s discipline.

Surfaced by a `/jim:verify --since` judge on the `ref-validation` invariant
during the C′-fix build; recorded as an adjacent observation, not a breach of the
invariant as written.
