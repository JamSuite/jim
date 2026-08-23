---
id: 20260801-re-validate-the-origin-registry-tip-before-git-interpolation
num: 185
title: "Re-validate the origin registry tip before git interpolation"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [platform, scripts, id-coordination, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-01T00:22:45Z
updated: 2026-08-02T01:07:02Z
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

## Anchor refresh (2026-08-01)

The function is `alloc_origin_tip`, not `alloc_resolve_remote_tip`
(`skills/file/scripts/jimalloc.sh:1012-1026`; field-1 extraction still at
`:1018`). Both consumers — `alloc_cas_append` and `alloc_publish` — call it,
and the tip reaches git at more sites than the two filed: `git cat-file -p
"$tip:$logfile"` (`:1198`, `:1209`, `:1645-1646`) and as the CAS parent
through `alloc_build_commit` / `alloc_seed_commit`. Validating inside
`alloc_origin_tip` covers every site.

The asymmetry is sharper than filed: the local tier of both consumers takes
its tip from `git rev-parse --verify --quiet --end-of-options`; only the
origin arm trusts `ls-remote` text raw. The discipline to mirror is
`jimledger.sh resolve_head` (`skills/ledger/scripts/jimledger.sh:95-107`):
git's own output re-crosses `jimfile.sh valid-id` before reuse.

## Resolution (2026-08-02)

Fixed in `platform/012`. The tip `alloc_origin_tip` extracts from `ls-remote`
now crosses `alloc_valid_token` before it is returned — the single locus this
issue identified, so both consumers and every interpolation site downstream of
them are covered by one gate. An empty tip (the branch does not exist yet) stays
legal; anything non-empty that fails the boundary is a hard failure rather than
a degraded read.

Fixtured with a PATH-shimmed `git` that advertises a crafted tip, and
mutation-tested: with the guard neutered the case fails on the value handed
back (`--upload-pack=touch`), not merely on the exit code.
