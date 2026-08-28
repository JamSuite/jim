---
id: 20260828-leave-cannot-remove-a-membership-naming-a-deleted-umbrella
num: P-20260828-leave-cannot-remove-a-membership-naming-a-deleted-umbrella
title: "leave cannot remove a membership naming a deleted umbrella"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, lifecycle]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T08:46:45Z
updated: 2026-08-28T08:46:45Z
origin: "docs/specs/issue/015-epic-authoring-and-views/plan.md"
---

## Description

## What

`leave <id> <umbrella>` resolves its operand against the collection before it
acts, and refuses when the reference names no record. That is correct for
`join` — you cannot enter an umbrella that does not exist — but it makes
`leave` unable to undo the one membership most in need of undoing.

Reproduced against a record whose `part-of` names a deleted umbrella:

```
$ transition.sh leave 20260102-m 20260101-deleted-umbrella --dir <dir>
error: no single issue matches that umbrella reference
rc=1

$ grep '  part-of:' 20260102-m.md
  part-of: [20260101-deleted-umbrella]
```

The membership survives, and the index reports it on every regeneration:

```
- `20260102-m` names an umbrella not in the collection: 20260101-deleted-umbrella.
```

## Why it matters

The only remaining way to clear it is to hand-edit the record's frontmatter —
which is the friction the lifecycle verbs were introduced to remove, and which
is materially worse under a designated shared branch, where a hand edit means
driving the two-phase publication door manually.

It is also self-perpetuating: the warning is derived, so it returns on every
write by anyone, for as long as the entry stands.

## How the state is reachable

Nothing exotic. An umbrella is a record like any other, and a record can be
deleted, renamed by the id-prefix migration, or realized from a provisional
ordinal into a different durable id. Membership is stored one-sided on the
member by design, so the umbrella's own file records nothing about its members
and no verb updates them when it changes.

## The narrower ask

`leave` should be able to remove a membership the record literally holds,
whether or not the named umbrella still resolves. The asymmetry with `join` is
the point rather than an inconsistency to smooth over: entering a set requires
the target to exist, and leaving one does not.

The shape worth considering: when resolution fails, fall back to comparing the
operand against the record's own `part-of` entries and remove an exact match.
That keeps the reference forms working for the ordinary case and adds a literal
match only where the ladder has nothing to resolve against.

## What this is not

Not a request to weaken `join`, and not a request to repair dangling entries
automatically — a membership naming a record that vanished may well be a
mistake worth seeing rather than silently dropping. The index should keep
reporting it. The ask is only that a developer who reads the warning has a verb
that acts on it.

## Where

`skills/issue/scripts/transition.sh` — the umbrella-resolution block in `main`,
which refuses before `apply_verb` runs, and the `join|leave` arm of
`apply_verb` that composes the new membership list. Line numbers deliberately
omitted: both sites were added by the increment that filed this, so coordinates
taken now are the shortest-lived kind. Both are found by the symbol names.
