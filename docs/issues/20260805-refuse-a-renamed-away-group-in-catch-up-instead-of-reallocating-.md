---
id: 20260805-refuse-a-renamed-away-group-in-catch-up-instead-of-reallocating-
num: 247
title: "Refuse a renamed-away group in catch-up instead of reallocating it"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, registry, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-05T09:50:22Z
updated: 2026-08-05T10:21:33Z
origin: "20260728-id-coordination-issue-grouping.md (retired; see 5e712bf)"
---

## Description

`alloc_group_present:2015` matches only a literal `group allocate <group>`
record. It consults neither the alias map (`alloc_group_alias_map:854`) nor
`alloc_group_has_records:2701`, so a group name that a `group rename` moved away
from reads as *absent* — and catch-up mints a fresh `group allocate` for it.

Every other call site of that predicate is preceded by a redirect check.
Catch-up's is not:

| call site | verb | redirect guarded by |
| :--- | :--- | :--- |
| `:2188` | `allocate spec` | `alloc_next_id_spec:1015-1018` refuses upstream — "group renamed" |
| `:3373` | `partition-batch spec` | `alloc_group_redirect` at `:3367-3372`, immediately above |
| `:3474` | `reconcile spec` | `grp` was already resolved through the alias map at `:1288` |
| **`:3067`** | **`catch-up`** | **nothing** |

The consequence is that a retired group name becomes live again, and the registry
then holds both `group rename <old> → <new>` and `group allocate <old>`.
`alloc_group_redirect` still answers `<new>`, so the resurrected name is a claim
that nothing dereferences — the group-level twin of the vacated-ordinal reissue,
reached through the same verb and invisible to the same detector.

Reachable by the same preconditions: the rename record and the directory move are
separate steps, so an aborted reconcile, a reverted move, or a branch merge
restoring the old directory all leave a tree group whose name the registry has
retired.

## Proposed action

Give catch-up's group hoist the redirect check its three siblings already have,
and refuse rather than mint — a renamed-away group is an operator decision about
which name is right, not an absence to append over. The refusal belongs in
`CU_BLOCKED` so it names the finding and exits non-zero, the treatment
`MISMATCH` already gets.

Fixture: a group rename whose source directory survives in the tree; assert
catch-up appends no `group allocate` for the retired name and exits non-zero.
Nothing in the catch-up test section constructs a renamed-away group today.

## Provenance

The evidence pass that settled B″'s two pre-code forks
(`docs/notes/20260728-id-coordination-issue-grouping.md`, Sequence step 7).
Surfaced by enumerating the never-reissue rule's doors rather than the filed
issue's — the second of two cells the vacated-ordinal issue does not name.

## Resolution (2026-08-05)

Fixed, and it needed more than the proposed redirect check.

The detection moved into the detector rather than the verb. `alloc_classify_spec`
now folds the group alias map once and emits `GROUP-RETIRED`
(`tree-group-renamed-away`) for any tree group the registry has renamed away,
naming where the group now answers. It joins `drift_rows` and the spec-side
`CU_BLOCKED`, so the sweep reports it and catch-up refuses — the two agreeing by
construction rather than by a check bolted onto one of them.

**Reporting it is not sufficient on its own.** A spec under the retired name that
the registry has never seen classifies as an ordinary `MISSING` record, so
catch-up would have named the retired group in its blocked list and appended the
claim under it anyway. Specs whose group is retired are now dropped from the
append set as well; the fixture asserts both the refusal and that nothing at all
was written.

Group *absence* is still deliberately unclassified — a group whose allocate
record is missing while its specs are present raises nothing, matching the
append rule. A group *contradiction* is a different thing, and the header now
says so.

Three mutations red: the emit removed, the class dropped from the refuse set,
and the withholding removed.
