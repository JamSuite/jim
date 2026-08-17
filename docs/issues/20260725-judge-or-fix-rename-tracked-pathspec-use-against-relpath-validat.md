---
id: 20260725-judge-or-fix-rename-tracked-pathspec-use-against-relpath-validat
num: 100
title: "judge or fix rename-tracked pathspec use against relpath-validation"
status: closed
priority: medium
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-25T08:04:42Z
updated: 2026-07-26T06:04:06Z
origin: BLUEPRINT.md
---

## Description

The relpath-validation rule's letter says an untrusted path is never handed to git as a pathspec, but cmd_rename_tracked in skills/review/scripts/jimledger.sh runs `git ls-files -- "$old"` on a valid-relpath'd (not slug-composed) argument; valid-relpath does not neutralize pathspec magic. Downstream guards (sibling constraint, containment, git-mv failure) narrow exploitation. The invariant is withheld from the platform blueprint (fail-closed) until judged or fixed.

Fork: fix (enumerate `git ls-files` without a pathspec and filter in bash, matching the rule's own prescription) or judge the site conformant and restore the row with the clause clarified.

## Resolution — fix-the-code (spec platform/005)

Resolved by spec `platform/005` (ledger-literal-pathspecs). The fork was answered
**fix-the-code**, with a mechanism upgrade over the original prescription:
instead of enumerating `git ls-files` and filtering in bash, the fix hands every
untrusted path to git under `git --literal-pathspecs`, the git-native pathspec
analogue of the existing `--end-of-options` ref-safety gate.

- Scope covered **both** git-mv primitives, not just `cmd_rename_tracked`: the
  four path→git calls (`ls-files` + `mv`) in `cmd_rename_tracked` and
  `cmd_move_spec_dir`. (The script's live home is
  `skills/ledger/scripts/jimledger.sh` — the path in the description above was
  stale.)
- The `relpath-validation` invariant was restored to the platform blueprint,
  then **folded** (narrowed) after the post-build review's living-intent sensor
  found the restored wording over-claimed `commit-*` coverage; clause 2 now
  scopes literal-pathspec neutralization to the git-mv primitives, matching the
  code.
- Regression tests (long-form `:(glob)…` and short-form `:/…`, both primitives)
  guard against recurrence.

Follow-on exposure surfaced during the work, tracked separately (out of scope
here): `#107` (`jimpartition.sh` rewrite verbs) and `#108` (`jimledger.sh`
`commit-*` pathspec calls).
