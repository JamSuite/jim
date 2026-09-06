---
id: 20260823-identity-argument-parser-accepts-contradictory-and-malformed-inv
num: 358
title: "identity argument parser accepts contradictory and malformed invocations"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, cli, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:21:46Z
updated: 2026-08-24T10:04:18Z
origin: "docs/specs/issue/013-recorded-identity-schemes/review.md"
---

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

## Resolution (2026-08-24)

Fixed in `d576a9e`.

A `need_operand` helper refuses an operand that is absent, empty, or equal to
one of this file's own option names. Both demonstrated cases now exit 2 naming
the flag, and the run stops before the collection is read.

Mode is read from `from_given` / `to_given` rather than from value
non-emptiness. That is the actual root: reading the mode off a surviving value
coupled the exclusivity check to the parser succeeding, so a flag whose operand
went missing left the mode unset and the check with nothing to compare. Fixing
only the operand would have closed the symptom and left that coupling for the
next change to `need_operand` to reopen.

**The Scope section's `--expect` question is answered yes, and it was the
serious one.** All five sites across the three parsers take the gate. An empty
expectation is indistinguishable from asking for no check, so before the fix:

```
migrate.sh identity docs/issues --renormalize --apply --expect
  -> Rewrote recorded identities in 1 issue(s).
     filed-by: "1234+Dev@users.noreply.github.com"  ->  "dev"
```

The drift guard never ran. The flag authorizing a destructive whole-collection
write was consumed as `--expect`'s value, and an empty expectation short-circuits
`gate_apply` at its first line. That is a worse instance than either case this
issue demonstrates, and it was reachable in all three migration subcommands.

**A value that merely looks option-shaped is still carried.** Only this file's
own option names are refused. The recordable-identity set admits a leading
hyphen deliberately — real addresses carry one — and `identity.sh` has cases
pinning `-x` and `--help` as data. Refusing every leading dash would have been
the simpler rule and would have broken them.

Pinned by `case_migrate_identity_usage_refuses_a_flag_where_a_value_belongs`,
`case_migrate_identity_usage_refuses_a_valueless_flag` (trailing and empty), and
`case_migrate_identity_valueless_expect_does_not_disarm_the_guard`, which asserts
the collection is byte-identical after the refusal. All three were run against
the unfixed parser first and fail there.

`case_migrate_identity_option_shaped_values_are_still_accepted` pins the guard's
**boundary** and is recorded as not going red against the unfixed parser — it
goes red against the stricter leading-dash reading instead. Its comment says so,
so it is not read as coverage of the fix.
