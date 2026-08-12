---
id: 20260812-two-placement-cases-cannot-fail-and-four-guards-have-no-coverage
num: 319
title: "Two placement cases cannot fail and four guards have no coverage"
status: open
priority: medium
labels: [issue, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:42:07Z
updated: 2026-08-12T03:42:07Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

Two placement cases pass regardless of the guard they name, and four guards have
no coverage at all — one of them silently load-bearing for rewrite detection.

## Cases that cannot fail

- `tests/place.sh:1968-1970`, the traversal half of
  `case_place_commit_unknown_token_refuses`. It asserts only rc 2 plus a
  non-empty message for `commit "../../escape"`. Delete the token charset gate
  (`place.sh:709-712`) and the next guard down refuses with the same rc 2 and a
  non-empty message. Fix: pin `'malformed handle token'`.
- `tests/place.sh:1809-1810`, `case_place_direct_read_handle_cannot_commit`.
  Delete the `direct-read` arm (`place.sh:904-907`) and `"direct-read"` falls
  through to `place_handle_dir`, passes `valid-id`, finds no directory, and
  refuses at rc 2 with a non-empty message. Every assertion still passes.

## Guards with no coverage

- **`|| -z "$remote"` on the bookmark advance** (`place.sh:1601`). Delete it and
  rewrite detection silently stops working for every remote-less centralized
  repo, with nothing failing. The `tier == origin` half is pinned; this clause is
  not.
- **The leading-dash tree-entry gate** (`place.sh:1114-1118`) — an entry named
  `-rf.md` is plain, relpath-valid and contained; only this gate refuses it.
- **`place_snapshot`'s regular-files refusal** (`place.sh:1164`) — the gate that
  stops a symlink created by the wrapped command or the agent from becoming a
  published tree entry.
- **Attempts exhausted** (`place.sh:1649`) — every race case loses exactly one
  race; nothing drives five.

Also uncovered: `place_handle_root`'s containment refusal, `place_coord_branch`'s
two refusals, `place_valid_sha`, `cmd_abort` with a garbage token, and the
`--dir`-operand form of the placeholder position rule.

## Proposed action

Add the two distinguishing assertions, then a case per uncovered guard, starting
with the bookmark-advance clause since its removal is invisible today.

## Origin

Post-build review of `issue/011`; the test-integrity region sweep. 2 of 115 cases
fall into the passes-regardless class, down from a systemic finding in the prior
round.
