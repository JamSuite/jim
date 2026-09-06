---
id: 20260808-cmd-begin-flattens-a-containment-refusal-to-an-io-failure
num: 280
title: "cmd_begin flattens a containment refusal to an IO failure"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, invariant]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-08T18:49:45Z
updated: 2026-08-11T08:55:48Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

`cmd_begin` reclassifies a containment refusal (rc 2) as an IO/engine failure
(rc 1), where its sibling call site preserves the code.

## Mechanism

`skills/issue/scripts/place.sh:651-655`:

```bash
if [[ "$PLACE_BASE_TIP" == "$PLACE_WORK_TIP" ]]; then
  place_snapshot "$handle/collection" base || { rm -rf -- "$handle"; return 1; }
else
  place_base_snapshot "$PLACE_BASE_TIP" "$prefix" "$handle/base.d" base \
    || { rm -rf -- "$handle"; return 1; }
fi
```

`place_base_snapshot` itself is correct — it captures and returns
`place_materialize`'s status (`:406-411`) — and `cmd_run` preserves it:

```bash
place_base_snapshot "$PLACE_BASE_TIP" "$prefix" "$PLACE_WORK/base" before || return $?
```

Only `cmd_begin` flattens it. Per the script's own EXIT CODES header (`:50-58`),
rc 2 is "config or validation refusal" and rc 1 is "IO or engine failure", so the
flattening tells the caller the wrong category.

## Severity

Low. The caller still sees a non-zero status, so nothing escapes and no publish
follows — unlike the sibling defect on the same path, where
`if ! place_materialize …; then local mrc=$?` yields rc **0** for the same class
of refusal (tracked separately as #263).

Both live in `cmd_begin`, both concern how a containment refusal is reported, and
both were touched by the fix pass without being corrected. They are best fixed in
one edit.

## Proposed action

Replace both `|| { rm -rf -- "$handle"; return 1; }` guards with a form that
captures and returns the real status, matching `cmd_run:1192`. While there, fix
the `if ! …; then $?` construct above it — inside the body of `if !`, `$?` is the
status of the negated pipeline and is always 0.

## Test

No case drives `begin` against a hostile tree at all. `place_seed_traversal`
(`tests/place.sh:89-107`) is exercised only through `run`, which is why both
defects are uncaught.

## Resolution (2026-08-11)

Fixed in `8ffdc5b`, alongside its sibling on the same path. Both guards in
`cmd_begin` return the status they were refused with, matching `cmd_run`.
