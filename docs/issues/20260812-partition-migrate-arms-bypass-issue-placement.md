---
id: 20260812-partition-migrate-arms-bypass-issue-placement
num: 314
title: "Partition migrate arms bypass issue placement"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T03:41:32Z
updated: 2026-08-12T20:02:19Z
origin: docs/specs/issue/011-issue-placement/review.md
---

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

## Resolution (2026-08-12)

Implemented in `3b937c1`, as decided.

**The disclosure reads the destination, not the checkout.** That was the one open
sub-decision. Scanning the working-tree copy would need no grant and no network,
but under a placement that copy is a stale fork — it can name lines the
destination does not have, miss ones it does, or be absent entirely on a branch
created after centralization. A listing that reads authoritative and is not is
worse than silence, which is the failure mode this whole disclosure exists to
avoid. So the methodology reads the real collection through
`place.sh begin --read`, records each hit as a `file:line` row against the
**destination-relative** path, and releases the handle with `abort`. The
methodology says explicitly never to edit inside that directory: a read handle
publishes nothing and discards its materialized copy, so an edit there is lost
silently.

**Where it surfaces.** The gate's REFERENCES block gains an
`UNAPPLIED — issue collection at <branch>` subsection, held separate from the
rows that *will* be applied and never omitted while the placement is active — a
gate silent about the collection reads as a collection with nothing to re-point.
A degraded read (handle failure, or an unreachable remote serving last-seen) says
so on that line rather than presenting an empty list.

**Three consequential edits beyond the gate**, each a place the old assumption
was load-bearing: materialize's `updated:` refresh and single `INDEX.md`
regeneration do not happen (no issue file is in the sweep set); `commit-split`'s
path list no longer carries the issue `INDEX.md`, which is what keeps the
changeset exactly one gate's worth of work — the property routing would have
broken; and the zero-unclassified verify sweep scopes the issue class out, since
its survivors are the disclosed rows and counting them as failures would fail
every placement run for doing exactly what the gate said. They are reported as
**verification owed**, with a count, rather than dropped.

**Correction to this issue's own text.** It names "rename, split and merge
materialization" as editing issue files. Only **split** and **merge** do. The
rename arm already lists issue bodies under its informational out-of-scope
mentions as "listed, never edited", so a placement changes nothing it writes —
but it does change what the *listing* should be read from, and that arm now says
so too. Merge inherits the rule by pointer rather than restating it, since its
sweep assembly is already documented as identical to split's.

**The grant is read-only by construction**: `place.sh mode`, `begin --read`, and
`abort *`. `case_docsurfaces_partition_discloses_unapplied_issue_repoints` binds
both halves — the methodology stating the skip, where it reads from, and the
constraint behind it; and the grant carrying no `commit` or `run` verb, since a
publish verb here would be the routing that was rejected, reinstated by accident.
Proven red by swapping the read grant for a publish one.
