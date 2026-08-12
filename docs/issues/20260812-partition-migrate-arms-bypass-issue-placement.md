---
id: 20260812-partition-migrate-arms-bypass-issue-placement
num: 314
title: "Partition migrate arms bypass issue placement"
status: open
priority: high
labels: [issue, placement, partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:41:32Z
updated: 2026-08-12T09:45:03Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`/jim:partition`'s rename, split and merge materialization edits issue files and
regenerates `INDEX.md` on the checked-out branch, without routing through
`place.sh`.

## Mechanism

`skills/partition/references/partition-methodology.md:470, 512-514, 520-524,
709-710`. The sweep set is assembled from
`git ls-files -- <specs-root> <issues-dir> <brainstorms-dir> <debug-dir>` — the
working tree. `rewrite-refs` re-points citations inside issue files; touched
issue files get an `updated:` refresh and **one `INDEX.md` regeneration after the
batch**; the result — explicitly including "the reference-edit files, and the
issue `INDEX.md`" — is committed on the checked-out branch by
`jimledger.sh commit-split` / `commit-merge` / `commit-rename`.

These are body edits, a frontmatter change, and an index regeneration. None
routes. `skills/partition/SKILL.md:18` grants `index.sh`, `Write` and `Edit` but
no `place.sh`.

There is an additional incoherence: if that regeneration is ever run as a bare
`index.sh` (no directory argument) it *would* route, publishing an index of the
destination's collection while the reference rewrites sit unrouted in the working
tree.

## Proposed action

Decide whether a partition migration is in scope for placement at all. If it is,
route the issue-file half through `place.sh`'s two-phase door and give the
partition skill the grant. If it is not, say so explicitly in the spec's Out of
Scope and in the methodology, so the divergence is chosen rather than inherited.

## Origin

Post-build review of `issue/011`; the omission class under AC 3.

## Decision (2026-08-12)

**Out of scope for the write — but detected and disclosed, not silently
skipped.** Under a non-`branch` placement the partition run states in its gate
that the issue-collection re-points are not applied, and emits them location-only
so they can be applied afterwards.

Routing the issue half was rejected on a constraint this issue does not name:
`jimledger.sh commit-split` commits "the reference edits, and the issue
`INDEX.md`" as one changeset behind one all-or-nothing gate — the partition
spec's own fixed two-commit choreography. Routing splits that into a
working-branch commit plus a destination-branch commit that can independently
defer (unreachable remote) or refuse (conflict), so a gate approved
all-or-nothing would land partly. That is a partition-spec invariant
`issue/011` has no standing to trade away.

Declaring it out of scope and stopping there was also rejected: it leaves the
collection citing retired spec ids permanently while the sweep reports zero
touched, which is the silent staleness AC 3 exists to forbid. Saying so in a
spec's Out of Scope does not stop it happening.

The middle follows the precedent this group already set in WP10 for the origin
lint: the skip is stated, not silent — a check that cannot be grounded says so
rather than being inferred from absence.

**Not yet implemented.**
