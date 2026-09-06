---
id: 20260812-two-argument-read-shape-bypasses-placement-and-creates-a-stray-d
num: 318
title: "Two-argument read shape bypasses placement and creates a stray directory"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T03:41:33Z
updated: 2026-08-12T09:34:16Z
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

## Resolution (2026-08-12)

Fixed in `c13caa9`, though not quite where the finding pointed.

`dir_given` now requires the candidate to *be* a directory for `list`, and
`cmd_list` reads its arguments by shape rather than count: a collection is the
trailing argument and only when it is one — which is both the form a caller
naming one uses and the form the placement re-exec appends. Everything before it
must be a filter, so `list open high` refuses instead of adopting `high`.

**`stats` and `show` were deliberately left on count**, against the finding's
"in every shape". Requiring a directory there routes the invocation, and the
re-exec appends the real collection as a trailing argument while those verbs read
theirs positionally — so the bad token would bind as the collection and the real
one be ignored, which is worse than the bypass it was meant to close. Their
operand is a directory or nothing, with no filter to confuse it with, so each
verb refuses a bad one outright instead.

The stray-directory half is closed at the single place that creates one, which
covers every verb at once rather than four guards: a read never brings a
collection into being.

Pinned by `case_issues_placement_two_filters_do_not_bypass_placement`,
`case_render_read_verbs_create_no_directory` and
`case_render_unconfigured_collection_reads_as_empty` — the last holding the
other side of the same guard, since a collection resolved from config that does
not exist is an ordinary empty project and refusing it would break every project
before its first filing.

This bears on `20260627-read-verb-list-creates-a-stray-directory-from-a-non-filter-arg`
(#18), which the finding names as its root, but does **not** close it: that issue
records three triggers and one — a direct `index.sh` run from a non-root CWD,
which never passes through `ensure_index` — is untouched here. Its Progress
section records which two are closed.
