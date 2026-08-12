---
id: 20260812-two-argument-read-shape-bypasses-placement-and-creates-a-stray-d
num: 318
title: "Two-argument read shape bypasses placement and creates a stray directory"
status: open
priority: high
labels: [issue, placement, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:41:33Z
updated: 2026-08-12T03:41:33Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

A read verb given two arguments opts out of placement on argument *count* alone,
so `/jim:issue list open high` reads a directory named `high` instead of the
destination — and creates it.

## Mechanism

`skills/issue/scripts/render.sh:670-685`. `dir_given` returns "a directory was
named" on count for three of the four shapes:

- `stats|insights-graph` on `$# >= 1`
- `show` on `$# >= 2`
- `list` on `$# >= 2` — an unconditional `return 0`

Only the `list` one-argument branch applies the `! is_filter_token && [[ -d "$1" ]]`
test that the routing-classification fix added.

`skills/issue/SKILL.md:34-37` substitutes the whole remaining argument string into
`render.sh list <remaining-args>`, so `/jim:issue list open high` — two valid
filter tokens — becomes `render.sh list open high`. `dir_given` returns true,
placement is never consulted, `high` is adopted as the collection,
`index.sh:301`'s `mkdir -p` creates `./high/` in the developer's checkout with an
`INDEX.md` in it, and the run prints `Issues — high` / `_No matching issues._` at
**rc 0** while the destination branch's collection goes unread.

The only tell is the directory name in the header line, which `SKILL.md:53`
instructs the agent to present verbatim.

## Related

`20260627-read-verb-list-creates-a-stray-directory-from-a-non-filter-arg` (#18)
is the root of the stray-directory half and remains open; the placement bypass is
new. The `stats <token>` and `show <id> <token>` shapes are exposed by the same
count test, though less reachable from the documented flows.

## Proposed action

Make `dir_given` require the candidate to be an existing directory in every
shape, not just `list`'s lone-argument branch — and have `cmd_list` refuse a
second token that is neither filter nor collection, mirroring the guard already
added for the one-argument case.

## Origin

Post-build review of `issue/011`, AC 5.
