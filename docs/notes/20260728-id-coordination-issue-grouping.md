# ID-coordination issue cluster — spec grouping analysis

**Created:** 2026-07-28 · **Revised:** 2026-07-30 — Spec A shipped as
`platform/011`; the build surfaced a **live id collision** that changes the
sequencing argument (see *What the build changed*).
Source: `/jim:issue insights` surfaced a 20-issue id-coordination convergence
cluster; this note answers "which deserve a spec, and how to group the work"
without minting a spec per issue.

Working note — not a spec. Delete or fold into a roadmap once the groupings are
acted on. One grouping (A) has now been acted on.

Line/function anchors in this note are as of the revision date.
`skills/file/scripts/jimalloc.sh` moves under consolidation — treat anchors as
dated, and re-verify before planning against them.

## The cluster — now 28 issues

Original 20: #111, #112, #113, #114, #115, #116, #117, #118, #119, #121, #122,
#123, #124, #126, #127, #129, #130, #132, #133, #134.

Eight added by `platform/011`'s spec, build, and review: #135, #136, #137, #138,
#139, #140, #141, #142.

**Four are closed:** #111, #114, #115, #124.

They are the residue of turning `platform/007`'s allocator foundation (emits
allocate records only — no consumers, no seed, no rename records) into the
project's authoritative, drift-proof ID source.

## Closed (4) — shipped and verified

| Issue | Shipped as | Review | Carve-outs (tracked) |
|---|---|---|---|
| **#111** wire issue display ordinal | `issue/010` | minor-drift, 11/11 AC | `issue_placement` never shipped → #126; per-item batching → #127; review edges → #132, #133, #134 |
| **#114** seed registry from artifacts | `platform/008` | minor-drift, 10/10 AC | duplicate-ordinal fork resolved as *halt-and-report*; vacated high-water for retired groups → #113; residue → #121, #122, #130 |
| **#115** provisional + reconcile | `platform/009` | **aligned**, 13/13 AC | spec-side reconcile deferred → #112/#113; residue → #124, #129 |
| **#124** reconcile/allocation high-water split | `platform/011` (as its D4) | minor-drift, 13/13 AC | resolved structurally — see below |

Verified live, not from the review artifacts: the coordination branch holds 64
records in `specs.log` (60 `spec allocate` + 4 `group allocate`) and 142 in
`issues.log`, no `<group>/000` record, ordinals 135–142 realized from provisional
markers, suite 832/832.

*(The prior revision reported "64 spec + 4 group" — 64 is the file's total line
count, not the spec-record count. Corrected above.)*

## Spec A shipped — `platform/011` rename-path correctness

Complete: 12/12 tasks, 13/13 AC, `cd4eeaa..576527a`, 832/832 (+23 tests). Review
**minor-drift**, 0 security regressions, living intent 9/9 invariants holding,
1 contract edge holding.

All four defects were latent — both live logs still hold **zero** rename records
— so this closed the window rather than migrating through it, which was the whole
reason for sequencing it first.

| Defect | Fix |
|---|---|
| D1 a reused name resolved to its former referent | replay anchors on the latest *establishing* record — allocate **or** rename destination |
| D2 a vacated ordinal was reclaimable | the fold counts rename **sources** |
| D3 a renamed group's ordinals stopped counting | membership resolves through `alloc_group_alias_map` |
| D4 allocation and reconcile disagreed | both read one shared fold per kind |

Two design outcomes worth carrying forward:

- **The fold was in three functions, not two.** `alloc_next_id_spec`,
  `alloc_next_num_issue`, and `alloc_reconcile_realize` — none counting rename
  sources. Fixing D2 and D4 as filter edits would have been six coordinated
  changes held in agreement by convention, which is what D4 *was*. Extracting one
  fold per kind made the agreement structural.
- **A ceiling and the gap guarantee are unsatisfiable together.** The plan-phase
  security review raised a Critical on 4-digit ordinals the bootstrap refused;
  capping allocation at 999 to match would have let one crafted record at the
  ceiling deny a group forever. The bootstrap's guard was relaxed to a shared
  digit-length value instead — recoverability was the real requirement, and the
  ceiling was the wrong way to state it.

`next-id` acquired two documented failure modes as a result: an unacknowledged
group redirect (**retryable** via `--follow-redirect`) and ordinal exhaustion
(**terminal**). Spec B and Spec C both consume this and must tell them apart.

## What the build changed

1. **A live collision exists right now, and Spec A did not prevent it.** The
   registry's newest `platform` record is `platform/010`, all 60 spec records are
   stamped `jim-seed`, and `platform/011` — the spec built *in this very session*
   — has no record at all, because nothing allocates spec ids through the
   allocator:

   ```
   peek spec platform            → platform/011     ← already exists on disk
   jimfile.sh next-id platform   → 012              ← correct
   ```

   The allocator would hand out an id the project already owns. This is the exact
   failure the prior revision's *What A does not buy* paragraph predicted, now
   demonstrated rather than argued — and the demonstration is self-inflicted,
   which is the strongest available evidence that **C and E, not A, are where
   allocation correctness lives**.

2. **#113 is unblocked; its three gates are closed.** Recorded on the issue with a
   per-gate table. Spec B inherits two obligations that did not exist when the
   gates were written: `next-id`'s two distinguishable failure modes, and the fact
   that the returned group is authoritative and may differ from the one requested.

3. **#121 is half closed.** The spec-ordinal *magnitude* half shipped with A — the
   `999` value cap became a shared digit-length check, and a 19-digit ordinal is
   now rejected as malformed rather than wrapping `intmax_t`. The *reserved-slot*
   half is untouched: `core/0-foo` still emits `spec allocate core/000`. Narrower
   than first described, though — with two such directories the seed now halts on
   `duplicate spec ordinal` rather than emitting either.

4. **The provisional/reconcile loop got its first real exercise.** Eight markers
   accumulated offline across two sessions (this sandbox has no coordination
   credentials) and realized on the host in one batch onto 135–142, no gap, no
   collision, against a high-water of 134. That also exercised A's own D4 fix in
   production, since `alloc_reconcile_realize` now draws from the shared fold.

5. **#135 is the concrete form of the #112 → #129 dependency.** The prior revision
   argued it as an unrecorded dependency; it is now a filed issue —
   `allocate spec` under `provisional` mints `platform/P-<date>-<slug>`, which
   `reconcile spec` cannot realize. Settle it inside Spec C's scoping.

Carried forward unchanged from the prior revision: #122's remainder is a refactor
(`alloc_publish` still inlines its own CAS), and #113 splits on the group seam
(`platform` read-path gates vs `blueprint` emission) rather than on appetite.

## Grouping: 5 remaining specs + 1 hardening build + 1 refactor + 3 decisions

Spec A is done. B–F remain.

### ~~Spec A — Rename-path correctness gates~~ · SHIPPED as `platform/011`
Ran as a spec rather than a build, and the fork was worth resolving that way: the
plan-phase security review found a Critical that changed the design (see above),
which a build would have had no gate to catch.

### Spec B — Rename/redirect record emission · #113's deliverable
`blueprint`. **Unblocked** — A closed its three preconditions. Also owns the two
dereferenceability decisions scoped out of A once investigation showed they cannot
affect allocation: whether the emitter must allocate every rename source, and
whether the resolver should count a source as known (a source-only id is
unresolvable today). Both recorded on #113 with measured side effects.
`/jim:partition`, `rename`, and `split` emit redirect records (Shape 1: renumber =
new allocation + redirect tombstone), so trailers frozen in git history stay
dereferenceable; a mass-move batches into one CAS; a pre-edit registry fetch
surfaces the edit-vs-rename conflict before merge; G6 stale-citation
normalization. Also picks up the two carve-outs pointed here by the closures:
`platform/008`'s vacated high-water for retired or partition-source groups (jim's
own retired `jim` group is that case), and `platform/009`'s citation
normalization for realized provisionals.

**New obligation from A:** it consumes a `next-id` that can refuse, and must
distinguish the retryable redirect refusal from terminal exhaustion.

### Spec C — Spec-ID allocator consumer · #112 + #123 + #135
`sdlc`. Reserve `group/NNN` through the allocator at ID-assignment time instead
of deriving it from the tree; #123 (the legacy `jimfile.sh next-id` group/kind
collision for a group named `issue`) is retired once that lands. Independent of
B **for allocation** — it emits allocate records only, like the foundation.
Gated on one decision, not on code: are specs **fail-only** under `provisional`
(cheap, ships now), or does spec provisional **wait for B** (honest, slower)?
#135 is that fork, filed.

**Now the demonstrated fix for a live defect,** not a theoretical improvement —
see *What the build changed* #1.

### Spec D — Batch-CAS candidate-batch allocation (§7a rework) · #127
Collapse an end-of-run candidate batch (8 surfacing skills) into one CAS instead
of N sequential pushes. Cross-group blast radius (sdlc + blueprint + issue) and
its own all-or-nothing-vs-partial failure-semantics decision. Independent.

### Spec E — Registry integrity & drift · #116 + #130 + #136
Complementary halves — "detect drift" and "fix drift":
- #116 — a `jim:verify`-style only-door sweep: every spec dir / issue ordinal on
  the coordination branch must have a matching registry record.
- #130 — an incremental seed catch-up verb that appends the records missing from
  a *non-empty* log under the same CAS/erosion discipline.
- #136 — the resolver's durable-id map silently takes the last of a duplicate
  pair; detecting that is the same integrity concern.

**#130's `low` priority is now demonstrably wrong.** The prior revision argued
the gap "has already bitten" from three hand-appended records. It is worse than
that: `platform/011` was created during this work and is *absent* from the
registry, so `peek spec platform` currently returns an id that exists on disk. A
detect-and-repair verb is what stands between the registry and a reissued id, and
nothing else does.

### Spec F — `issue_placement` / issue content location · #126
Where a filed issue's *content* lives: central branch vs on-branch, the
`issue_placement` config key, the disclosure surface (centralizing publishes
bodies earlier and wider), and reconciliation with the VISION non-goal that issue
capture is a discovery artifact, not a coordination primitive. The one clause of
#111 that did not ship. Genuine undecided design → its own scoping.

### One grouped hardening build (10) — no spec
Localized fixes, each a testable one-to-few-line change with a test per fix.
Six from the `008`/`009`/`010` reviews:
- #119 retry the unreachable-detection path + generalize the exhaustion message
- #121 normalize the seed reserved-slot skip *(magnitude half shipped with A)*
- #132 `new.sh` mixed-pin (`--slug` XOR `--num`) registry/on-disk skew
- #133 fence-bound reconcile's provisional detection to the frontmatter block
- #134 check `reconcile.sh`'s index-regen exit code (don't swallow it)
- #117 `moved-to` tombstone guarding coordination-branch relocation

Four from `platform/011`:
- #140 fixture the `allocate spec` acknowledgment path (the consent gate shipped
  with only its `peek spec` half fixtured — behavior verified by hand)
- #141 fixture the terminal exhaustion refusal (one record reaches it)
- #138 collapse the ordinal-width predicate into a validator (one shared *value*,
  but the predicate around it is inlined at five sites)
- #142 memoize the id-validation boundary (~56ms/record of forks; measured linear,
  and log length is attacker-influenceable)

(#124 closed with A; #122 is below.)

### One small refactor — #122's remaining half
Factor the shared land step (tier select → CAS → arm baseline) so the allocation
path and `alloc_publish` share one implementation, generalizing the commit
builder over one-or-many blobs. Not a correctness gap — guarantees are equivalent
today — so this can park indefinitely. Kept out of the hardening build because
it touches the allocation path rather than a leaf.

### Decisions + docs (3) — no spec
- **#129** — run jim's agent profile as `id_coordination_unreachable =
  provisional`? The machinery exists (`platform/009`) and works: eight markers
  filed offline and realized cleanly on the host this session. The flip is still
  sitting uncommitted in `jimconf.toml`. Carries a dependency: under
  `provisional`, Spec C mints unrealizable spec identities until B ships (#135).
  Decide the two together.
- **#118** — coordination-branch protection / team setup docs (middle protection
  profile: direct push allowed, force-push + deletion denied).
- **#139** — the test suite acquired a non-POSIX `timeout` dependency with A.
  Justified (a non-terminating walk hangs with no error message) but currently
  undeclared. Accept it explicitly, widen the invariant's scope deliberately, or
  bound the walk in-process.

### Deferred with no demand — #137
A group that exhausts its ordinal space now fails loudly rather than minting an
unseedable id. Recovering it (renumber vs widen vs split) has no demand — the
largest live group holds 24 specs against a 15-digit limit — so this is a trend
marker with a recorded destination, not queued work.

## Sequence

Ordered for **correct allocation** — a flow that cannot hand out an id the
project already owns. Step 1 is done; the collision it did not prevent is why the
remaining order stands unchanged.

**1. ~~A, alone.~~ DONE** — `platform/011`. The arithmetic over the records
present is now correct, and the pre-emission window is closed on all four
defects.

**2. C — the keystone, and now urgent.** No longer "spec-allocation correctness
is theoretical until the consumer is wired" — it is *concretely broken*:
`peek spec platform` returns `platform/011`, which exists. Every spec record is
`jim-seed`-stamped because nothing has ever allocated through the allocator.
C's blocker remains a decision, not code — settle the provisional-spec fork
(#135) and #129 with it.

**3. E — the baseline.** A correct fold over records that misrepresent the repo
still hands out a consumed id, and that is the present state, not a risk. C stops
*new* drift; only E detects and repairs the drift already there. Note C and E are
mutually reinforcing rather than ordered: C without E leaves the existing gap, E
without C means repairing drift that keeps regenerating.

**4. B, later.** Its allocation-relevant piece is the vacated-ordinal floor —
`jimfile.sh next-id` floors past vacated ids via the ledger's split/merge events
while the allocator's fold has no floor record at all. The rest of B (redirect
emission, citation dereferenceability, the batched mass-move) is a
dereferenceability story, valuable but not allocation. Now unblocked whenever it
is wanted.

**Free-floating:** D, F, the hardening build, #118, #139, and the #122 refactor —
any time, any order.

**What A bought, and what it did not.** It bought correct arithmetic over the
records present, and it bought the closing of the rename window — the one item
here whose cost rises with delay. It did not make the records represent the repo
(E), did not make anything go through the allocator (C), and did not establish
the vacated floor (B). The live collision above is the proof: A shipped complete,
and the allocator still offers an id the project owns.

## Per-issue disposition (all 28)

| # | Pri | Disposition |
|---|---|---|
| 111 | high | **closed** — shipped as `issue/010` |
| 114 | high | **closed** — shipped as `platform/008` |
| 115 | med  | **closed** — shipped as `platform/009` |
| 124 | low  | **closed** — shipped as `platform/011`'s D4 |
| 113 | high | Spec B (record emission) — its 3 gates closed by `platform/011` |
| 112 | high | Spec C (spec-group consumer; settle the provisional fork) |
| 123 | med  | Spec C (legacy next-id path, retired by #112) |
| 135 | med  | Spec C (the provisional-spec fork, filed) |
| 127 | high | Spec D (batch-CAS) |
| 116 | med  | Spec E (only-door sweep) |
| 130 | low  | Spec E (catch-up verb — **priority demonstrably wrong**, see above) |
| 136 | low  | Spec E (duplicate durable-id detection) |
| 126 | med  | Spec F (issue_placement) |
| 117 | low  | hardening build |
| 119 | low  | hardening build |
| 121 | med  | hardening build (reserved-slot half only; magnitude half shipped) |
| 132 | low  | hardening build |
| 133 | low  | hardening build |
| 134 | low  | hardening build |
| 138 | low  | hardening build (`platform/011` residue) |
| 140 | med  | hardening build (`platform/011` residue — test gap) |
| 141 | med  | hardening build (`platform/011` residue — test gap) |
| 142 | med  | hardening build (`platform/011` residue) |
| 122 | low  | half closed by `platform/009`; remainder is a standalone refactor |
| 129 | med  | decision (provisional agent profile) — decide with Spec C |
| 118 | med  | docs (coordination-branch protection / team setup) |
| 139 | low  | decision (`timeout` test dependency) |
| 137 | low  | deferred, no demand (exhausted-group recovery) |

## Net

28 issues → **5 remaining specs** (B, C, D, E, F), **1 hardening build of 10**,
**1 optional refactor**, **2 doc/decision items + 1 deferred**, **4 closed**.

The headline is not the arithmetic. It is that the cluster's centre of gravity
moved: A was the item with a closing window, and it is spent. What remains
between jim and an allocator that cannot reissue an id is **C** (make something
allocate through it) and **E** (make the records match the repo) — and the live
`platform/011` collision means that is a present defect, not a future risk.
