---
id: 20260828-leave-cannot-remove-a-membership-naming-a-deleted-umbrella
num: 413
title: "leave cannot remove a membership naming a deleted umbrella"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: "jrko"
outcome: done
labels: [issue, lifecycle]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T08:46:45Z
updated: 2026-08-29T00:55:55Z
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

## Resolution

Fixed in `db567f08`.

`leave` consults the record's own `part-of` entries before the resolver. An
entry the record literally holds never reaches `resolve.sh`; anything else
falls through unchanged, so ordinals and slug prefixes work exactly as before —
neither is ever literally a membership entry.

**Literal-first rather than the fallback this record proposed**, settled with
the developer. Two things decided it. `resolve.sh` writes its refusal to stderr
as it fails, so a fallback running afterward would repair the record and exit 0
having already printed `error: no issue matches that reference`. And a dead
entry that happens to prefix a live record would resolve away to that record,
remove nothing, and report success — the entry surviving silently, which is the
failure this record exists to end. Consulting the record first avoids both, and
the ordinary reference forms are unaffected either way.

**The asymmetry is preserved, and is now tested rather than incidental.** `join`
still refuses an umbrella that does not resolve, even when the record already
holds that exact entry — the input an over-broad fix waves through.

**Verified against this record's own scenario**, not only in the suite: a member
holding `20260101-deleted-umbrella` with no such record. `leave` exits 0, writes
`part-of: []`, prints nothing on stderr, and the regenerated index carries no
dangling-umbrella warning.

**Four cases, two of them guards.** Two failed before the fix — clearing the
dead entry, and leaving live siblings in place. Two passed before and after by
design: they exist to catch an over-broad fix rather than to prove the feature.

That distinction paid for itself. The first version of the `join` guard
asserted only that a refusal happened, and removing the `verb == leave` guard
**still passed it** — `join` refused for a different reason, because the
literal path leaves the kind empty and the containment check then rejects it.
The case now asserts *which* refusal, and the mutation fails it. A guard that
accepts any failure is not a guard.

**Safety is unchanged.** On the leave path the operand is only compared; the new
list is composed from the record's own entries, so an unresolved string never
reaches the file. `join`, where the operand does land in the record, keeps
resolving and validating as before.

**This changes a published face.** The `transition.sh` Provides entry says
containment is enforced on the way in only, so `leave` stays available to repair
a violation a hand edit introduced. That repair now covers a second class the
entry does not mention. The change is **additive** — a widened guarantee, not a
weakened one — and is left for the group's next blueprint pass rather than
hand-written here.

**What this does not do.** It does not repair dangling entries automatically and
does not quiet the index warning, both of which this record explicitly ruled
out. A membership naming a record that vanished stays visible until a developer
decides to clear it; the change is only that deciding to is now enough.
