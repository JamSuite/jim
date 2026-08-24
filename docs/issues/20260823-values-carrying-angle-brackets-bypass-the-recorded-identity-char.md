---
id: 20260823-values-carrying-angle-brackets-bypass-the-recorded-identity-char
num: 365
title: "Values carrying angle brackets bypass the recorded-identity charset gate"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, identity, security, regression]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:37:25Z
updated: 2026-08-24T07:29:54Z
origin: "docs/specs/issue/000-blueprint/spec.md"
---

## Description

## Description

The blueprint invariant `identity-validated-before-record` states that a
recorded identity "clears one positively enumerated character set before it is
written, and a value outside it is refused exactly as an absent one." It no
longer holds. A value carrying `<` or `>` is silently reduced to a different,
shorter value and recorded, instead of being refused.

## Demonstrated

```
junk<attacker@evil.example  ->  attacker@evil.example   rc=0, recorded
a<b                         ->  b                       rc=0, recorded
a>b                         ->  a                       rc=0, recorded
x<y<z@example.com           ->  z@example.com           rc=0, recorded
```

## Mechanism

Alias resolution runs ahead of the charset gate — deliberately, because a
mapping is keyed on addresses and extracting first would leave it nothing to
match. The value is handed to the mapping lookup wrapped in angle brackets, so
a value that already contains one produces malformed bracket structure. Git
echoes back a normalized single contact, and the extraction that reads the
answer takes the text after the **last** `<`. The result is a charset-clean
substring, which then passes the gate on its own merits with no memory that the
original value was disallowed.

## Reach

Every write path except the explicit remap: the filer at filing, the holder at
a transition, the filer the conversion recovers from history, and the
re-normalization. `--from`/`--to` is immune because it validates directly with
no mapping step ahead of it.

## Why it matters

This is a regression. Before alias resolution was introduced, validation ran on
the raw value and anything carrying `<` or `>` was refused. Two documents state
the property that is now false: `identity.sh`'s own SECURITY MODEL header
("only that set is accepted, and everything outside it is refused") and
`ARCHITECTURE.md` § Security Considerations → Recorded identity.

The recorded value is what by-person views attribute work to, so a value that
silently becomes a *different* identity is an attribution the collection cannot
justify.

## Direction

The gate needs to see the value the caller supplied, not only the value the
mapping handed back. Judging the pre-image against the accepted set before it
is composed into the lookup argument would preserve both properties — the
mapping still runs first, and an out-of-set value is still refused. No test
currently exercises a bracket-bearing value through any verb.

Origin: `docs/specs/issue/013-recorded-identity-schemes/review.md` — Finding 1,
and the living-intent violation resolved `fix` at the blueprint fork.

## Resolution (2026-08-24)

Fixed in `2da3693`.

The gate runs at the top of `map_alias`, ahead of the composition, rather than
in the two callers. That is where the bracket assumption is actually made:
`map_alias` is what wraps the value as `<$value>`, so the requirement travels
with the argument it protects and a caller reaching the lookup by another route
later cannot reopen the door. It also subsumed the standalone `IDENTITY_MAX`
check `map` and `normalize` each carried, whose only job was bounding what
reached that same command.

The direction proposed above is what landed; only its placement differs.

**A capability was deliberately narrowed.** A mapping keyed on a value the
accepted set does not admit can no longer fire, because the value is refused
before the lookup is consulted. That is what "refused exactly as an absent one"
requires, and the alternative is the mapping deciding what is recordable.
`case_identity_a_mapping_cannot_admit_an_unrecordable_value` pins it, so the
narrowing is not read as a defect and restored.

Pinned by `case_identity_bracket_bearing_values_are_refused_whole` — every
bracket position through `validate`, `map` and `normalize` — and
`case_identity_resolve_refuses_a_bracket_bearing_environment_identity`, the
ambient path a filing and a transition both take. Both were run against the
unfixed script first and fail there.

The two documents named above are corrected: `identity.sh`'s SECURITY MODEL
header in the same commit, and `ARCHITECTURE.md` § Security Considerations →
Recorded identity in `b00ad3d` via `/jim:arch`.
