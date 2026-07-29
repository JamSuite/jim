---
id: 20260726-emit-rename-split-redirect-records-and-wire-jim-partition-batche
num: 113
title: "Emit rename/split redirect records and wire /jim:partition batches"
status: open
priority: high
labels: [id-coordination, partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-26T19:01:57Z
updated: 2026-07-29T21:03:10Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

`platform/007` defines the rename and group-rename record grammar and forward-replay resolution but **emits allocate records only**. This follow-on makes `/jim:partition`, `rename`, and `split` emit the redirect records (Shape 1: a renumber is a new allocation plus a redirect tombstone, never a mutation), so that trailers frozen in git history stay dereferenceable forever.

Scope:
- A split/partition mass-move becomes one registry commit = one push = one CAS (batch atomicity; no partial renumbering ever visible).
- Group renames are one `group rename` record; resolution applies the group redirect before the ordinal lookup.
- A pre-edit registry fetch surfaces the concurrent edit-vs-rename warning before the git-level rename/modify conflict lands at merge.
- Fold in G6: every ID consumer (skills, humans, plain grep) must become resolution-aware, or jim opportunistically normalizes stale citations in tree content when it touches a file anyway.

Follow-on to `platform/007` (foundation); this is the `blueprint`-group consumer slice.

## Preconditions in platform/007's frozen semantics

**Three** latent edges in `platform/007`'s **frozen** resolution / next-id
semantics. None is reachable in the foundation build (it emits allocate records
only), but this follow-on is the first to emit rename records — so all three
must be closed here, **before** the first rename/group-rename record lands, or a
citation mis-resolves and a consumed ordinal is reissued. Add fixtures for each.

Two came from the `platform/007` post-build review; the third surfaced when
those two were re-verified. All three were reproduced by executing the functions
directly against crafted logs (see *Verification* below) — the observed values
are recorded per edge.

- **Resolution is not anchored for reuse-via-rename-in.** `alloc_resolve_spec` /
  `alloc_resolve_issue` set the forward-replay anchor only on an `allocate`
  match (`skills/file/scripts/jimalloc.sh:177` / `:230`), not when the queried
  id is a rename *destination* (`:180` / `:233`, which set `known=1` but leave
  the anchor behind). So a name renamed away and later reused by renaming a
  *different* spec onto the freed name resolves to the *old* referent, not the
  current one — the "mis-resolve to the wrong referent" AC 5 forbids. Replay
  starts too early and re-applies the departed spec's rename.
  **Observed:** with `dashboard/001` renamed to `core/009` and `other/003` later
  renamed onto `dashboard/001`, `resolve spec dashboard/001` returns
  `core/009`; correct is `dashboard/001`. Issue side is identical:
  `resolve issue 7` returns `9`; correct is `7`.
  **Fix:** also set the anchor on the last rename whose destination equals the
  queried id. Reuse-via-*allocate* is already anchored correctly and fixtured
  (`tests/jimalloc.sh:129`) — mirror it for rename-in, spec and issue. There is
  no issue-side reuse fixture at all today.

- **next-id counts rename destinations but not sources.** The high-water folds
  in allocate ids and rename destinations, not rename sources
  (`alloc_next_id_spec` `:255-276`; `alloc_next_num_issue` `:281-298`). The
  permanent-gap guarantee (AC 3) therefore rests on an unenforced invariant:
  that every rename source has its own prior `allocate` record.
  **Observed:** over a log of just `spec rename dashboard/005 core/001`,
  `next-id dashboard` returns `dashboard/001` — reclaiming every ordinal up to
  005.
  **Fix:** either count rename sources in the fold or otherwise guarantee the
  invariant. `tests/jimalloc.sh:220` asserts a rename *destination* counts;
  nothing asserts a source does, in either function.

- **next-id does not alias a renamed group, so resolution and allocation
  contradict each other.** `alloc_next_id_spec` filters group membership on the
  id's *literal* prefix (`:271`), so ids allocated under a group's old name stop
  counting the moment the group is renamed — while `alloc_resolve_spec` *does*
  apply the group redirect (`:193-196`). The two halves of the registry then
  disagree about whether an id is taken.
  **Observed:** over `spec allocate dashboard/001`, `spec allocate
  dashboard/002`, `group rename dashboard ui`, `resolve spec dashboard/001`
  returns `ui/001` while `next-id ui` also returns `ui/001` — the resolver says
  the name is taken and the allocator would hand it out again.
  **Fix:** apply the group redirect to the membership filter before folding.
  `jimalloc.sh:253-254`'s own docstring already defers this to "the spec that
  begins emitting rename records" — this one. No group-rename next-id fixture
  exists. Note this issue's *Scope* covers group rename only on the resolution
  side; the high-water side is this edge.

## Verification (2026-07-29)

- **The window is still open.** Both live logs on the coordination branch hold
  **zero** rename records (64 spec + 4 group + 134 issue records, all
  `allocate`), so no citation has mis-resolved and no ordinal has been reclaimed
  yet. Every fix above is still a pre-emission change, not a migration.
- **Line anchors above were refreshed.** The four resolve anchors the review
  cited (`:169`/`:172`/`:222`/`:225`) were exact at `platform/007`'s reviewed
  head (`8c683cf`) and have since drifted uniformly +8 as `platform/008`'s seed
  encoders landed above them. The old `:247-266` next-id range is replaced with
  both function ranges — at 007's head it reached `alloc_next_id_spec` but
  stopped short of `alloc_next_num_issue`, so the issue-side fold was never
  actually in the cited span. Treat all anchors here as of this date; the
  `alloc_publish` consolidation shows this file moves.

See `docs/specs/platform/007-id-coordination-allocator/review.md` (Findings 1
and 2) for the original trace of the first two.

## Inherited constraint — emit an allocation for every rename source

All three gates above are being closed ahead of this spec by
`platform/011` (rename-path correctness), which this work depends on. One
decision there lands as a constraint on **this** spec's emitter and must be
settled during its scoping.

`platform/011` guarantees the permanent gap two ways: defensively, by counting
rename *sources* in the high-water so a vacated ordinal is unreclaimable for any
log shape; and by recording the invariant that every rename source should carry
its own prior `allocate` record. The defensive fold means this spec **cannot**
reissue a vacated ordinal even if it emits a rename whose source was never
allocated — the guarantee no longer depends on the emitter behaving.

The open question is whether that is sufficient, or whether this spec should
*additionally* be required to emit an allocation record for every rename source
it writes:

- **Defensive fold alone** — simpler emitter; the registry may then contain a
  rename source with no allocation, which is representable but means the log no
  longer tells the whole story of where an ordinal came from.
- **Also emit the source's allocation** — the log becomes self-describing (every
  ordinal traces to an allocation), at the cost of extra records on every
  renumber and a decision about what to write when the source predates the
  registry (a seeded id, or one vacated before adoption).

Settle this when scoping; do not let the defensive fold's existence decide it by
default. Recorded in `platform/011`'s Open Questions as the reciprocal.
