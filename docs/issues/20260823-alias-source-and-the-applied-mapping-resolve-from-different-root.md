---
id: 20260823-alias-source-and-the-applied-mapping-resolve-from-different-root
num: 356
title: "alias_source and the applied mapping resolve from different roots"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, migration, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:21:49Z
updated: 2026-08-25T06:52:54Z
origin: "docs/specs/issue/013-recorded-identity-schemes/review.md"
---

## Description

The re-normalization preview reports which alias mapping is in play using one
resolution root, and applies the mapping using another. Under a routed
placement the two can disagree, and the disclosure can then be wrong in the
direction that matters.

## What happens

`alias_source` locates the mapping relative to the collection directory:

```
git -C "$dir" rev-parse --show-toplevel
git -C "$dir" config --get mailmap.file
```

The mapping actually applied to each value resolves relative to the invoking
process's working directory, because `identity.sh`'s lookup runs plain
`git check-mailmap` with no `-C`.

In the ordinary case these are the same repository and nothing diverges. Under
`issue_placement` routing they need not be: the wrapped command runs with no
`cd`, so the working directory stays wherever the developer was standing, while
the directory operand can be a materialized copy with no `.git` at all.

## The failure

`alias_source` finds no repository at the materialized directory and the
preview states:

```
Alias mapping: none found — identities resolve through the form alone.
```

while values are in fact being resolved through whatever mapping the
developer's own checkout carries. An operator approving that plan has been told
the opposite of what happened.

## Why it matters

The disclosure exists so an operator sees the transform before approving it
rather than inferring it from the result afterwards. A disclosure that can be
confidently wrong is worse than none, because it is relied upon.

## Direction

Make presence and application agree on one root. The application side is the
one that decides what gets recorded, so it is the sounder anchor — but the
choice is worth making deliberately rather than by which function was edited
last.

Origin: `docs/specs/issue/013-recorded-identity-schemes/review.md` — Finding 9.

## Resolution (2026-08-25)

Anchored on the application side, in `6eefd6e`.

`alias_source` resolves the mapping from this process's own working directory —
the root `map_alias` already applies from, since the lookup is invoked with no
directory of its own. Its `<dir>` parameter is gone rather than left unused,
and `render_alias_disclosure` loses the parameter it existed to forward.

**The choice, made deliberately.** The application side decides what gets
recorded, so a disclosure that disagrees with it is the half that is wrong. The
alternative — rooting the lookup at the collection — would have made the
recorded identity depend on which directory a collection was materialized into,
which is the same defect facing the other way.

**Census.** Every version-control call in the group's identity path was checked
for the same split. The rule holds everywhere else: a fact about the collection
(`git status` for the recovery note, the work-tree gate the filer recovery
needs) is rooted at the collection directory, and a fact about identity
resolution (`check-mailmap`, the configured `user.email`) answers from the
process root. This was the one site on the wrong side of that line.

`case_migrate_identity_disclosure_and_lookup_share_a_root` pins it with a
collection the repository does not contain — the shape a routed placement
materializes. Before the fix, the plan printed `old@personal.example -> dev`
directly above the line "Alias mapping: none found".
