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
updated: 2026-08-12T09:00:02Z
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

## Progress (2026-08-12)

**The unreadable/unparseable half is fixed** in `39661e1` — the half the issue
states unconditionally. A config that is genuinely absent still resolves to the
documented default at rc 0, which is the zero-config path; a path that exists but
is a directory, a dangling symlink, or unreadable now reports a resolver failure
instead of an unset key, and `resolve` forwards it rather than flattening it into
"no override". A key simply not present in the file is still no override — grep's
"no match" must not read as a failure, or every unset key would refuse.

Pinned by `case_jimconf_unreadable_config_refuses` and
`case_jimconf_non_regular_config_refuses`, with
`case_jimconf_absent_config_still_defaults` holding the zero-config path in
place. The first is proven to go red with the readability check removed.

**Three parts remain open, and each is a decision rather than a fix** — the
issue's own proposed action says "consider" and "decide" for two of them:

1. **Single-quoted and bare values.** The grammar matches only `= "…"`, so
   `key = 'v'` or `key = 3` silently become the default. Supporting them widens
   a parser that is deliberately grep-and-sed.
2. **A strict mode for unknown keys in the file.** A typo'd key is silently
   ignored. Refusing one would break every project carrying an extra or
   commented key.
3. **Walk-up to the project root.** `./jimconf.toml` with no walk-up means a run
   started from a subdirectory sees no config at all — arguably the highest-value
   of the three, and the largest change in resolution semantics.
