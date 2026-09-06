---
id: 20260726-neutralize-pathspec-magic-in-jimpartition-rewrite-identity-rewri
num: 107
title: "Neutralize pathspec magic in jimpartition rewrite-identity/rewrite-refs"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [partition, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-26T04:46:06Z
updated: 2026-07-26T04:46:06Z
origin: docs/specs/platform/005-ledger-literal-pathspecs/research.md
---

## Description

## Description

Two sites in `skills/partition/scripts/jimpartition.sh` (blueprint group) share
the same untrusted-path→git-pathspec exposure that platform spec
`005-ledger-literal-pathspecs` fixes in the ledger primitives: a valid-relpath'd
(but not slug-gated) path is handed to `git ls-files` as a pathspec, and
`valid-relpath` does not neutralize pathspec magic (a leading `:` such as
`:(glob)`/`:/`/`:(exclude)` survives to git).

- `cmd_rewrite_identity` — `jimpartition.sh:1694` `git ls-files -- "$f"` (gated
  by `valid-relpath` 1688 + realpath worktree containment 1691).
- `cmd_rewrite_refs` — `jimpartition.sh:1850` `git ls-files -- "$f"` (same
  gating).

Both are `ls-files`-only tracked-checks — the actual edits go through awk, not
git, so there is no `git mv` sink here (unlike the ledger primitives).

Surfaced during `/jim:research` for platform spec 005, which stayed in the
platform group by decision. This follow-on lives in the **blueprint** group
(jimpartition.sh territory).

Fork: apply the same per-call literal-pathspec neutralization
(`--literal-pathspecs` / `GIT_LITERAL_PATHSPECS`) to both `git ls-files` calls,
mirroring the platform fix — or judge the sites conformant given their guards
and record why. Note: apply per-call, never a global git config — the codebase
relies on intentional literal-glob pathspecs elsewhere (`scripts/jim-deps-refs.sh`).

Relates to the platform-blueprint `relpath-validation` invariant, whose intent
is project-wide; if that invariant is restored noting project-wide
applicability, these sites are the outstanding blueprint-group conformance gap.
