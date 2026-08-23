---
id: 20260823-identity-argument-parser-accepts-contradictory-and-malformed-inv
num: 358
title: "identity argument parser accepts contradictory and malformed invocations"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, cli, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:21:46Z
updated: 2026-08-23T23:21:46Z
origin: "docs/specs/issue/013-recorded-identity-schemes/review.md"
---

## Description

## Description

`migrate.sh identity`'s argument parser accepts two invocations that mean
something other than what was typed, and reports neither.

## Demonstrated

**A flag is swallowed as a value.**

```
$ migrate.sh identity docs/issues --from --apply --to new@example.test
Identity remap plan — docs/issues

  from  --apply
  to    new@example.test
```

Exit 0. `--apply` became the identity being replaced; apply mode was never
engaged. The accepted identity character set includes the hyphen — deliberately,
because real addresses carry one — so the swallowed flag passes validation
cleanly.

**Mode exclusivity is bypassed by a value-less flag.**

```
$ migrate.sh identity docs/issues --renormalize --from
...
PLAN-HASH: 8967755
```

Exit 0, a full re-normalization. `remap` is only set when `from` or `to` is
non-empty, so a `--from` with no following token leaves it unset — which means
neither the both-modes-given check nor the both-halves-required check ever
runs.

## Why it matters

The second is the serious one. The operator typed two contradictory modes and
received one of them silently. With `--apply` in the mix that rewrites every
recorded identity in the collection on an intent the parser never confirmed —
against a verb whose own design principle is that guessing which rewrite was
meant is the one thing a destructive whole-collection operation must not do.

## Scope

The swallow pattern is shared with `--expect` elsewhere in the same file, so a
fix should consider whether to harden the idiom generally. Identity is the
first place it interacts with a value that is itself validated as recordable
rather than being an opaque hash or path.

Origin: `docs/specs/issue/013-recorded-identity-schemes/review.md` — Findings
4 and 5.
