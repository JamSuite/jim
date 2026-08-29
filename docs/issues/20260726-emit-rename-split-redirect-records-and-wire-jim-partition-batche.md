---
id: 20260726-emit-rename-split-redirect-records-and-wire-jim-partition-batche
num: 113
title: "Emit rename/split redirect records and wire /jim:partition batches"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-26T19:01:57Z
updated: 2026-08-03T05:46:40Z
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

## Preconditions — CLOSED (2026-07-30)

**All three gates below are closed.** `platform/011` (rename-path correctness)
shipped complete: 12/12 tasks, 13/13 acceptance criteria, 832/832 suite green,
`cd4eeaa..576527a`. This spec is unblocked — the read path is now correct for
rename records *before* the first one is emitted, which was the whole point of
sequencing that work ahead of this.

What closed, per gate:

| Gate | Closed by |
| :--- | :--- |
| Resolution not anchored for reuse-via-rename-in | The anchor is now the queried id's last *establishing* record — allocate **or** rename destination, whichever is later. Fixtured spec and issue side. |
| next-id counts rename destinations but not sources | One shared fold per kind counts allocate ids, rename destinations, **and** rename sources, so the permanent gap holds for any log shape rather than resting on an emitter invariant. |
| next-id does not alias a renamed group | Group membership resolves through `alloc_group_alias_map`, which reports the resolver's own walk — records in file order, each applied at most once — so the two halves of the registry cannot contradict each other. Multi-hop chains and crafted cycles fixtured. |

**A fourth defect closed alongside them.** `platform/011` also folded in #124
(allocation and reconcile computing different high-waters), because research found
the fold in **three** functions rather than the two the review notes named —
`alloc_next_id_spec`, `alloc_next_num_issue`, and `alloc_reconcile_realize`. That
is why the per-gate fix notes below read as the original trace rather than the
implementation: the fix was structural, not three parallel edits.

**Two new obligations this spec inherits**, neither present when the gates were
written:

1. **`next-id` now has failure modes.** `alloc_next_id_spec` refuses a group that
   has been renamed away, naming the redirect, until the caller passes
   `--follow-redirect`; it also refuses on ordinal exhaustion. The two are
   distinguishable by message and must be treated differently — the redirect
   refusal is **retryable** with acknowledgment, exhaustion is **terminal**. A
   consumer that collapses them makes a recoverable case look fatal. On the
   acknowledged path the returned group is authoritative and may differ from the
   one requested.
2. **The window this spec closes is still open, but narrower.** Both live logs
   held **0** rename records as of this date, so nothing has mis-resolved yet.
   Every fix in `platform/011` was pre-emission; the first record this spec emits
   is what makes the window shut permanently.

The *Inherited constraints* section below still stands — those two decisions were
scoped to `platform/011`, investigated there, and moved here because they are
dereferenceability and ordering concerns that cannot affect allocation.

## Preconditions in platform/007's frozen semantics

**Three** latent edges in `platform/007`'s **frozen** resolution / next-id
semantics. None is reachable in the foundation build (it emits allocate records
only), but this follow-on is the first to emit rename records — so all three must
close **before** the first rename/group-rename record lands, or a citation
mis-resolves and a consumed ordinal is reissued.

**They are no longer this spec's work, and they are now closed.** They were split out to
`platform/011` (rename-path correctness) as `platform`-group read-path fixes,
leaving this spec the `blueprint`-group emission it actually describes; this
spec depends on that one. The edges stay documented here because this spec is
what makes them reachable, and because two of the decisions taken there bind
this spec's emitter (see *Inherited constraints* below). Research for
`platform/011` found the high-water defect at a **third** site the two review
notes did not name — `alloc_reconcile_realize` — so treat the per-edge fix notes
below as the original trace, not the implementation plan.

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
  no issue-side reuse fixture at all today. *(Both now exist —
  `case_jimalloc_resolve_{spec,issue}_reuse_rename_in`.)*

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
  nothing asserts a source does, in either function. *(Both now assert it —
  `case_jimalloc_fold_max_{spec,issue}_counts_rename_source`.)*

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
  exists. *(That deferral docstring is retired, and five fixtures now cover it —
  `case_jimalloc_next_id_spec_group_alias_*`.)* Note this issue's *Scope* covers
  group rename only on the resolution side; the high-water side is this edge.

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

## Inherited constraints from platform/011

All three gates above are being closed ahead of this spec by `platform/011`
(rename-path correctness), which this work depends on. Two decisions there land
as constraints on **this** spec and must be settled during its scoping.

### 1. How a vacated citation dereferences

**This is this spec's decision, not `platform/011`'s** — it was scoped there,
investigated, and moved here because it turns out to be a dereferenceability
question with no bearing on allocation. `alloc_resolve_spec` /
`alloc_resolve_issue` have exactly one caller (`cmd_resolve`); the high-water
folds are called by the allocation builders and `peek`. The two share no state,
so nothing decided below can affect which id gets allocated.

**The problem.** `platform/011` makes the permanent gap unconditional by counting
rename *sources* in the high-water, so this spec cannot reissue a vacated ordinal
however it emits. But the resolver's "is this id known to the registry?" gate
counts an id appearing as an allocation, as a rename *destination*, or as a
member of a renamed-into group — and **not** as a rename *source*. So an id whose
only appearance is as a source is unresolvable, even though the replay computes
the right answer internally and only the gate rejects it:

| Log | `resolve spec dashboard/005` |
| :--- | :--- |
| `spec rename dashboard/005 core/001` | **error: not allocated** (rc 1) |
| `spec allocate dashboard/005 …` then the same rename | `core/001` (rc 0) |

The issue resolver behaves identically. That is precisely the property this spec
exists to deliver — a trailer frozen in git history staying dereferenceable — so
the gate's assumption is load-bearing here and nowhere else.

**Three ways to close it.**

1. **Emitter invariant.** Require this spec to emit an `allocate` record for every
   rename source it writes. Resolution then works and the log is self-describing
   (every ordinal traces to an allocation), at the cost of extra records per
   renumber and a decision about sources that predate the registry — a seeded id,
   or one vacated before adoption. Leaves the read path trusting the writer.
2. **Resolver gate.** Count a rename source as known, making resolution work
   regardless of how any emitter behaves.
3. **Both**, which are not exclusive: 2 makes correctness independent of the
   writer, 1 still makes the log tell the whole story.

**Measured side effects of option 2**, from a patched copy run against crafted
logs. It resolves source-only ids as intended (`dashboard/005` → `core/001`), a
never-mentioned id still errors (`ghost/999` → rc 1), and all four shipped
resolution behaviors are unchanged. But:

- **Phantom resolution.** An id never allocated, named only by a crafted rename
  source, resolves: with `spec rename dashbord/007 core/001` present,
  `resolve spec dashbord/007` returns `core/001` (rc 0; today it errors). One
  pushed record makes an arbitrary id resolve to a target of the pusher's
  choosing — the same shape as the silent-namespace-redirect finding on
  `platform/011`, where the developer ruled that redirects must be **visible**.
- **Confident answers over incoherent logs.** `spec rename x/001 a/001` followed
  by `spec rename x/001 b/002` (same source twice, no allocation anywhere)
  resolves `x/001` to `a/001` — the first record silently wins.
- **`resolve` stops being an existence oracle.** rc 1 today means "the registry
  has no knowledge of this id"; after option 2 it narrows to "no record mentions
  it at all." No consumer depends on that yet, which makes changing it cheap —
  but this spec and the spec-consumer wiring are what acquire the dependency, so
  the semantics chosen here is what they inherit. It also gives up a free
  corruption signal for a log state that should be impossible.

**Recommended framing:** apply the visibility rule the developer already set —
resolve the citation *and* disclose that it derives from an unallocated source, so
the phantom and incoherent cases are loud rather than silent. That keeps
dereferenceability without making `resolve` confidently wrong, and it is a
`resolve` output-contract decision best taken before any consumer reads the verb.

### 2. Keep the two next-id surfaces from disagreeing mid-move

Surfaced by `platform/011`'s research. jim has **two** independent next-id
computations, and this spec is what first makes them capable of disagreeing:

- `jimfile.sh next-id <group>` — a scan of the spec directory tree, floored past
  vacated ids via the specs-root ledger. What `/jim:spec` and `/jim:partition`
  call today.
- the allocator's registry fold, reached through `peek spec` / `allocate spec`,
  which `platform/011` teaches to alias a renamed group.

After that aliasing lands, a group rename has two observable states: the
`group rename` record exists in the registry, and the spec directories have
actually moved on disk. Between those two points the tree scan and the registry
fold answer differently for the same group. This spec owns both halves of that
window — it emits the record *and* performs the move — so it owns the ordering
that makes the window safe (or provably empty).

Note the two surfaces already differ in a related way: the tree scan floors past
vacated ids through the ledger's split/merge events, while the registry fold has
no floor record at all — the same gap that leaves the retired-group high-water to
this spec (see `platform/008` Out of Scope). Worth deciding whether this spec
converges the two surfaces or documents them as deliberately separate.

## Inherited constraint from sdlc/018 — the width gate is joint, not per-side

Recorded 2026-07-31 from the C′-fix build's fork analysis; the width policy half
is settled there, this half is not, and it is this spec's to take.

`alloc_canon_specid` (`skills/file/scripts/jimalloc.sh:164-181`) replaced
`alloc_valid_specid` as the guard at three comparison sites in
`alloc_resolve_spec`. The prior guard accepted any `^[0-9]+$`; the canon helper
rejects an ordinal wider than `ALLOC_MAX_ORD_DIGITS`.

**The narrowing itself is settled as deliberate**
([[20260731-fixture-or-revert-the-ordinal-width-narrowing-in-canonicalizatio]]):
that constant exists because recoverability was the real requirement, so an
ordinal wider than it is one the registry could not be rebuilt from, and `resolve`
must not return an id the seed cannot reproduce.

**What is not settled is that the gate is applied jointly.** A rename record is
dropped when *either* side fails canonicalization, so an over-wide **source** — a
tombstone, by construction — kills the establishing record of an otherwise
perfectly representable destination:

| Log | `resolve spec core/003` |
| :--- | :--- |
| `spec rename <16-digit-src> core/003` as its only establishing record | **error: not allocated** (rc 1) |
| the same, with `spec allocate core/003` present | `core/003` (rc 0) |

The replay side fails in the opposite direction and more quietly: a
`spec rename core/003 grp/<16 digits>` is not applied at all, so `resolve` returns
the **pre-rename** name at rc 0 — a confident wrong answer rather than a refusal.

**Why it lands on this spec.** It is the same question as *Inherited constraints
→ 1* asked from the other side: what a rename **source** is allowed to do to the
resolver's `known` gate. There the source's absence from the gate makes a valid
citation unresolvable; here the source's *unrepresentability* does the same thing
to its destination. Both live logs still hold zero rename records, so this is
crafted-log-only today — and the first rename record this spec emits is what makes
it reachable, which is exactly the sequencing argument the *Preconditions* section
already makes for the other three edges.

**Recommended resolution: gate per side.** Canonicalize each side independently
and let a record anchor whichever side is representable. A source that the width
policy cannot express is a fact about the tombstone, not about the destination —
dropping the destination's establishing record punishes the wrong id.

**Interaction to settle alongside option 2 above.** If this spec counts a rename
source as known, per-side gating stops being tidiness and becomes load-bearing:
a source-only id's resolvability would otherwise depend on that source clearing a
width gate it was never minted under. Take the two decisions together.

## Demonstrated live (2026-07-31)

That last paragraph stopped being an argument. A verification sweep after the
`platform`/`sdlc` registry repair
([[20260730-align-the-registry-with-tree-scan-era-spec-ordinals]]) found the
retired `jim` group disagreeing across the two surfaces:

```
peek spec jim      → jim/001      ← an ordinal the 2026-07-25 split retired
next-id jim        → 053          ← correct; floors past the vacated range
```

`next-id` is right because it consults the specs-root ledger's `op=split` remap
(`jimfile.sh:341-357`). `peek` answers `001` because the registry holds **no
`jim/` records at all** — and, checked directly, no `group allocate jim` record
either. The seed derived group records from the tree, `docs/specs/jim/` retains
only `000-blueprint`, and the seed skips that reserved slot, so the entire group
fell out of coordination when the split rewrote its 52 identities into
`sdlc` / `blueprint` / `issue` / `platform`.

**The durable statement of the gap:** `op=split` rewrites identities in the tree
and writes nothing to the registry, so every split silently drops the source
group's spent ordinals out of coordination. `allocate spec jim` would mint
`jim/001` today.

Narrower in consequence than the repaired case — reachable only by scoping into a
retired group, which the partition doctrine already forbids, and no live group is
affected — so it was left unrepaired rather than patched.

**One thing this issue's scope does not reach.** Emitting redirect records fixes
*future* splits. The `jim` split already happened under `identity=rewrite` and
left nothing behind, so `jim/001`–`jim/052` stay unrecorded even after this ships
unless something backfills them. That repair half belongs with the registry
integrity work ([[20260726-add-an-only-door-verification-sweep-for-the-id-registry]],
[[20260728-registry-drift-catch-up-has-no-incremental-seed-verb]]) — the same
emission-vs-repair split the `platform`/`sdlc` case had, and the second time in
two days that "a consumer stops new drift, it does not repair drift that predates
it" has been the operative sentence.

## Backfill source located (2026-08-01)

The repair half has a mechanical source: the specs-root ledger's
`partition finished` events carry the complete `moved=jim/NNN:<group>/NNN`
pair list for the 2026-07-25 split, and `jimledger.sh vacated-max` already
parses that grammar (`skills/ledger/scripts/jimledger.sh:651-694`). Those
pairs are exactly the frozen `spec rename <old> <new> <date>` record shape —
so the backfill is this issue's emission grammar applied retroactively, not a
catch-up append of allocate records (a rename source counts toward the fold's
high-water, which is all the floor needs). Spec E's sweep should name the
retired group as known-uncovered; whether the backfill ships with this
issue's emitter or as a one-time repair alongside it is a decision for
whichever spec lands first.

## Resolution (2026-08-03)

Delivered by `blueprint/025`. `jimalloc.sh partition-batch` publishes a renumber
pair set as allocate + rename per pair (Shape 1, this issue's) or as one record
for a whole group; `lift` turns the specs-root ledger's durable pair events into
records. Both recompute their refusals inside the publish builder on every CAS
attempt, so a conflict another clone introduced between check and commit is
caught by the attempt that would have overwritten it. The lift treats the ledger
as a **witness, not an instruction**: a pair is recorded only where the registry
independently establishes its destination and holds no live claim on its source.

The two dereferenceability decisions pre-framed here landed as source-known
**with disclosure** (a citation whose only registry appearance is a rename source
resolves, with a stderr note that no allocation stands behind the answer) and
per-side width gating (an unrepresentable source no longer drops its
destination's establishing claim).

The backfill half this issue scoped out — `jim/001`–`jim/052` — ran origin-tier
from the host as part of the same emitter, so it became the lift's own repair
rather than separate work. Verified: `resolve spec jim/029` answers
`blueprint/001` with the unallocated-source note, and the sweep reports
`uncovered-groups 0` / `rename-source-ids 52`.

The emitter's own edges did not all close with it — see [[20260802-refuse-the-three-contradictions-partition-batch-still-writes]],
[[20260802-fix-the-lift-s-cross-run-idempotency-hole-and-one-sided-batch-gu]]
and [[20260802-unblock-the-chained-group-rename]].
