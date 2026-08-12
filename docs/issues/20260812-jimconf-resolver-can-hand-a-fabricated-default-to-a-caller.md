---
id: 20260812-jimconf-resolver-can-hand-a-fabricated-default-to-a-caller
num: 311
title: "jimconf resolver can hand a fabricated default to a caller"
status: open
priority: medium
labels: [conf, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:42:09Z
updated: 2026-08-12T03:42:09Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`jimconf`'s resolver collapses several read *failures* into a key's default at
rc 0, so a caller that correctly refuses on a failed resolve can still be handed
a fabricated value it cannot distinguish from a real one.

## Mechanism

`skills/conf/scripts/jimconf.sh:143-148` (`parse_value`) returns early on
`[[ ! -f "$file" ]]` and otherwise greps with stderr suppressed; `resolve`
(`:212-224`) ignores its status and falls through to `default_for` whenever the
output is empty. All of the following therefore yield the default at rc 0, with
no message:

- `jimconf.toml` present but **not readable** (grep exits 2, output empty)
- `jimconf.toml` that is not a regular file (directory, dangling symlink)
- a value written **single-quoted or bare** — the grammar matches only `= "…"`
- an **empty or whitespace-only** value (deliberate, but indistinguishable)
- a **typo'd key** — there is no strict mode
- **CWD is not the project root** — jimconf reads `./jimconf.toml` with no
  walk-up, so a run started from a subdirectory sees no config at all

For `issue_placement` the fabricated default is `branch`, i.e. "do not
centralize", so a project with a configured destination silently writes to the
working branch. `place.sh` was deliberately hardened to refuse a failed resolve
and cannot detect this class, because the failure never reaches it.

## Why file it here

This is jimconf's shared read path, not the issue group's — it affects every key
uniformly. It surfaced while judging the placement gate's "never silently falls
back" guarantee, which the gate honors and the resolver undercuts.

## Proposed action

Distinguish "file absent" from "file unreadable / unparseable" and exit non-zero
on the latter; consider a strict mode that refuses an unknown key, and decide
whether a walk-up to the project root is wanted.

## Origin

Post-build review of `issue/011`, AC 10.
