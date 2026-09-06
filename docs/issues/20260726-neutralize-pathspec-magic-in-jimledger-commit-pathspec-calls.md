---
id: 20260726-neutralize-pathspec-magic-in-jimledger-commit-pathspec-calls
num: 108
title: "Neutralize pathspec magic in jimledger commit-* pathspec calls"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [platform, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-26T05:56:09Z
updated: 2026-07-26T05:56:09Z
origin: docs/specs/platform/005-ledger-literal-pathspecs/review.md
---

## Description

## Description

The `relpath-validation` invariant's clause 2 (literal-pathspec neutralization)
is scoped to the two git-mv primitives (`rename-tracked`, `move-spec-dir`). Four
sibling commit verbs in `skills/ledger/scripts/jimledger.sh` hand
config/caller-supplied paths to git pathspecs WITHOUT `--literal-pathspecs`,
carrying the same exposure `valid-relpath` does not neutralize — a leading `:` /
`:(glob)` / `:/` passes `valid-relpath` and `realpath -m` containment as literal
characters, yet git interprets it as pathspec magic:

- `cmd_commit_map` — `git add -- "$map" "$ledger"` and
  `git commit … -- "$map" "$ledger"` (config-derived `$map` / `$specs_dir`).
- `cmd_commit_rename` — `git diff --cached --quiet -- "${paths[@]}"` and
  `git commit … -- "${paths[@]}"`.
- `cmd_commit_split` — the same diff + commit pattern.
- `cmd_commit_merge` — the same.

The `git add -- "$p"` calls in rename/split/merge are mostly defused by a
preceding `[[ -e "$p" ]]` literal-existence guard; the `git commit` /
`git diff --cached` pathspecs have no such guard and remain exposed. The blast
radius is narrower than the git-mv primitives — staging over/under-inclusion of
an already-staged file, not arbitrary tracked-file relocation — so the risk is
lower, but the invariant's own rationale ("valid-relpath does not neutralize
pathspec magic") applies equally.

Surfaced by the `/jim:review` living-intent sensor and a review investigator
during platform/005, which deliberately scoped to the two git-mv primitives; the
`relpath-validation` invariant was folded to match that scope. Issue #107 tracks
the analogous sites in `jimpartition.sh`, NOT these `jimledger.sh` commit sites.

Fork: extend `--literal-pathspecs` (or `GIT_LITERAL_PATHSPECS`) to the commit
verbs' `git add` / `git commit` / `git diff --cached` pathspec calls — per-call,
never a global config (the codebase relies on intentional literal-glob pathspecs
elsewhere, `scripts/jim-deps-refs.sh`) — or judge the sites conformant given
their `[[ -e ]]` and containment guards and record why.
