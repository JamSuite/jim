---
id: 20260812-place-snapshot-publishes-a-collection-entry-materialization-refu
num: P-20260812-place-snapshot-publishes-a-collection-entry-materialization-refu
title: "place_snapshot publishes a collection entry materialization refuses"
status: closed
priority: medium
labels: [issue, placement, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T07:04:57Z
updated: 2026-08-12T07:32:50Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

A wrapped command can publish a collection entry whose name begins with `-`,
after which every later run refuses to materialize it — a one-way door into an
unreadable collection.

## Mechanism

`place_materialize` (`skills/issue/scripts/place.sh`) gates entries arriving
*from* the destination branch: regular file, plain name, no leading `-`, safe
relpath, contained. `place_snapshot` gates what goes *out* — the collection the
wrapped command or the agent leaves behind — on regular-files only. The
leading-dash rule has no counterpart there.

Reproduced against a placed collection:

```
place.sh run --verb file -- sh -c 'printf x > "$1/-rf.md"' _ '{}'
  -> rc 0; docs/issues/-rf.md lands on the destination branch

place.sh run --read --verb reindex -- true
  -> rc 2, "refusing '-rf.md' ... a collection entry may not begin with '-'"
```

Every read and every write then refuses at the same gate, and the only repair is
by hand on the destination branch.

## Not an injection

The name reaches git as `"$prefix/$name"` — `docs/issues/-rf.md` — so it is never
a leading-dash argument, and `place_build_commit`'s `update-index --cacheinfo`
takes it positionally. This is availability only.

## Proposed action

Give `place_snapshot` the same leading-dash refusal `place_materialize` has, so
the collection cannot be put into a state it cannot be read out of. The two gates
are the same rule at the two ends of the same round trip, and the group's
convention is that a shape the reader refuses is a shape the writer must not
produce.

## Origin

Surfaced while pinning the materialization gate for
`20260812-two-placement-cases-cannot-fail-and-four-guards-have-no-coverage`:
the entry gate had no coverage, and writing the case exposed that only one end
of the round trip enforced it.

## Resolution (2026-08-12)

Fixed in `fb6864e`. `place_snapshot` carries the leading-dash refusal
`place_materialize` already had, so the two ends of the round trip enforce one
rule. Pinned by `case_place_refuses_to_publish_a_leading_dash_entry`, proven to
go red with the gate removed; the entry-side gate is pinned by
`case_place_refuses_a_leading_dash_tree_entry`, added in the same pass.
