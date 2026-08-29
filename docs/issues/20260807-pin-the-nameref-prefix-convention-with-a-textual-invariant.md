---
id: 20260807-pin-the-nameref-prefix-convention-with-a-textual-invariant
num: 259
title: "Pin the nameref-prefix convention with a textual invariant"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [testing, bash, refactor]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-07T10:59:35Z
updated: 2026-08-07T10:59:35Z
origin: docs/specs/issue/011-issue-placement/plan.md
---

## Description

## Description

A bash nameref whose own variable name matches the array it is pointed at
resolves to itself. Bash does not error — it yields an **empty array**, so the
loop over it simply does nothing and the function returns success.

This bit twice while building `issue/011`:

- `place_publish` declared `local -n before="$4"` and was called with the name
  `before`. Every changed path silently disappeared from the tree build, so the
  commit landed with an unchanged tree. Visible only as "the file is not on the
  destination branch" three assertions later.
- `place_regraft` declared a plain `local ... upstream` loop variable that
  shadowed the caller's `upstream` array of the same name, breaking the
  snapshot written through the nameref.

Both were found by bisecting assertions, not by any error message. The fix in
both cases was a per-function prefix (`_pp_`, `_rg_`, `_ps_`, `_ch_`, `_sv_`,
`_ld_`), and the rule is currently recorded as a comment in `place.sh` above
`place_snapshot`.

A comment is the weakest form this rule can take. The failure it prevents is
silent, and the next person to add a nameref will be in a different file.

## Proposed action

Add a textual-invariant case to `tests/scripthygiene.sh` (the existing home for
corpus-wide bash rules) asserting that every `local -n` / `declare -n`
declaration under `skills/*/scripts/*.sh` names its nameref with a leading
underscore. That is a shape no ordinary local carries, so a nameref can never
collide with a caller's variable name.

All 10 namerefs in the repo today live in `skills/issue/scripts/place.sh` and
all conform, so the invariant holds on the current tree and exists to guard the
eleventh.

## Notes

Scope is one file today, which is the argument against. The argument for is that
the check is three lines, the failure mode is silent rather than loud, and the
convention is otherwise discoverable only by reading a comment in a file the
next author may not be editing.
