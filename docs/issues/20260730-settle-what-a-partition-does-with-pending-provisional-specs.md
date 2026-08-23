---
id: 20260730-settle-what-a-partition-does-with-pending-provisional-specs
num: 154
title: "Settle what a partition does with pending provisional specs"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [partition, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-30T10:55:24Z
updated: 2026-08-03T05:46:40Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

## Description

`skills/partition/scripts/jimpartition.sh` treats a reserved provisional
identity two different ways, and neither was chosen deliberately.

**On a split it aborts the whole remap.** Each `renumber-map` assign row is
gated at `:1362`:

    if [[ ! "$src" =~ ^[0-9]{3}(-wip)?$ ]]; then
      echo "... bad source shape: $src" >&2; rc=1; break
    fi

so a `P-` source does not skip — it fails the map, rc 1, no output. One pending
spec blocks the entire split. (Corrected 2026-07-30: this issue first recorded
it as "passed over", which is what the *merge* path does, not the split path.)

**On a merge it skips silently.** `:1450` selects with

    [[ "$bn" =~ ^[0-9]{3}(-.*)?$ ]] || continue

so the directory is left behind in the source group: not renumbered, not moved,
not mentioned. `partition-methodology.md:418` carries the same assumption.

Skipping is the fail-safe direction — the directory is left intact rather than
renamed into a shape the realizer would no longer recognize — but the outcome is
silent, and it interacts badly with realization afterwards. If the partition
renamed the group, the pending spec now sits under a name the allocator will
resolve away from, which is the halt condition tracked in
[[20260730-realization-cannot-follow-a-group-renamed-since-issuance]].

Decide deliberately, and say so wherever it lands:

- **Refuse** — `split-preflight` / the merge equivalent reports pending
  provisional specs as a structural blocker, so the developer realizes them
  first. Simplest, and matches the preflight's existing habit of refusing
  structural failures rather than working around them.
- **Or carry them** — renumber is meaningless for a provisional identity (it has
  no ordinal), so carrying means moving the directory to the target group and
  leaving the token intact, which needs the cross-parent move the sibling issue
  above also needs.

The two issues are best settled together: both are "what happens to a pending
provisional identity when the group beneath it moves".

Whichever way it lands, make the split and the merge agree — an abort on one
path and a silent skip on the other is not a decision, it is two accidents.

## The same blind spot in blueprint synthesis

`skills/blueprint/SKILL.md:63` instructs the synthesis to "Glob the group's
**numbered** spec directories under the specs root", so a pending provisional
spec is excluded from a group's `000-blueprint` with no note that anything was
left out. Decide this alongside the partition question: it is the same
"group-level operation cannot see a pending identity" defect, and a blueprint
that silently omits in-flight work is the more consequential of the two.

Surfaced by `sdlc/017`'s post-build review. Amended 2026-07-30 when the
review's investigated second pass superseded its first.

## Resolution (2026-08-03)

Settled as **refuse**, and settled symmetrically — which was this issue's real
ask. `blueprint/025` added a shared `pending_provisionals` detection helper to
`jimpartition.sh` and called it from all three preflights, so rename, split and
merge now meet the same wall and name every pending identity. The prior state —
a hard failure on one path and a silent skip on another — was, as filed, two
accidents rather than a decision.

The blueprint-synthesis half was instructed but not made enforceable, so it does
not close here. The exclusion note added at `skills/blueprint/SKILL.md:63` cannot
fire (the same sentence directs a glob over *numbered* directories, which never
surfaces a `P-` basename), and the CHECK fact truncates at 512 bytes with no
note. That half continues as
[[20260802-make-the-blueprint-pending-provisional-disclosure-enumerable-and]].

The merge preflight's unvalidated source set — passed into the new filesystem
probe without a slug gate, where its two siblings gate at entry — is
[[20260802-blueprint-divergence-partition-registry-boundary-slug-gate]].
