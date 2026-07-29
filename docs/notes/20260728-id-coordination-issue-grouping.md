# ID-coordination issue cluster — spec grouping analysis

**Created:** 2026-07-28 · **Revised:** 2026-07-29 — the three closures landed and
verifying them changed the grouping (see *What verification changed*).
Source: `/jim:issue insights` surfaced a 20-issue id-coordination convergence
cluster; this note answers "which deserve a spec, and how to group the work"
without minting 20 specs.

Working note — not a spec. Delete or fold into a roadmap once the groupings are
acted on.

Line/function anchors in this note are as of the revision date.
`skills/file/scripts/jimalloc.sh` moves under consolidation — treat anchors as
dated, and re-verify before planning against them.

## The 20 issues

The cluster: #111, #112, #113, #114, #115, #116, #117, #118, #119, #121, #122,
#123, #124, #126, #127, #129, #130, #132, #133, #134 — of which **#111, #114,
#115 are now closed**.

They are the residue of turning `platform/007`'s allocator foundation (emits
allocate records only — no consumers, no seed, no rename records) into the
project's authoritative, drift-proof ID source.

## Closed (3) — shipped and verified

| Issue | Shipped as | Review | Carve-outs (tracked) |
|---|---|---|---|
| **#111** wire issue display ordinal | `issue/010` | minor-drift, 11/11 AC | `issue_placement` never shipped → #126; per-item batching → #127; review edges → #132, #133, #134 |
| **#114** seed registry from artifacts | `platform/008` | minor-drift, 10/10 AC | duplicate-ordinal fork resolved as *halt-and-report*; vacated high-water for retired groups → #113; residue → #121, #122, #130 |
| **#115** provisional + reconcile | `platform/009` | **aligned**, 13/13 AC | spec-side reconcile deferred → #112/#113; residue → #124, #129 |

Verified live, not just from the review artifacts: the registry on
`refs/heads/jim/registry` holds 64 spec + 4 group + 134 issue records with no
`<group>/000` record, issue ordinals 131–134 were allocator-issued at filing
time, and the suite is 809/809.

## What verification changed

1. **#113 carries three preconditions, not two.** A third surfaced while
   re-verifying the two from `platform/007`'s review: `alloc_next_id_spec`
   filters group membership on the id's *literal* prefix while
   `alloc_resolve_spec` applies the group redirect, so after a `group rename` the
   resolver reports an id taken and the allocator would reissue it
   (`resolve dashboard/001 → ui/001` and `next-id ui → ui/001` over the same
   log). `jimalloc.sh:253-254`'s own docstring defers this to whichever spec
   begins emitting rename records — this one. All three reproduced by executing
   the functions against crafted logs; observed values are recorded in #113.
2. **#113 should split on the group seam, not on appetite.** Its three gates are
   `platform` code (`jimalloc.sh` resolution + high-water): small, emit nothing,
   testable in isolation. Its deliverable is `blueprint` code (`/jim:partition`,
   `rename`, `split` emitting records): heavyweight, cross-group, freezes record
   grammar. The prior "split #113 out if appetite is limited" framing buries the
   unblocking half inside the heavyweight one.
3. **#124 belongs with gate 2, not in the hardening build.** Both change what
   counts toward the issue high-water, in two functions that must agree
   (`alloc_reconcile_realize` vs `alloc_next_num_issue`). Separating them means
   touching the same logic twice with a moving target.
4. **#122 is half closed and its remainder changed shape.** `platform/009`'s
   shared `alloc_publish` gave the seed landing the in-loop erosion re-check
   (both logs — stricter than the allocation path). What remains is that
   `alloc_publish` still inlines its own CAS instead of sharing
   `alloc_origin_cas` / `alloc_local_cas`, so allocation and publish are two
   implementations. That is a refactor, not the "one-to-few-line fix" the
   hardening build assumes.
5. **#112 under `provisional` is a dead end — a dependency the cluster did not
   record.** `allocate spec` already returns `platform/P-<date>-<slug>`, while
   `reconcile spec` hard-fails ("not implemented"), because realizing a
   provisional spec renames a directory. Wiring #112 while
   `id_coordination_unreachable = provisional` therefore mints spec identities
   nothing can realize. This ties **#112 → #129 → rename emission** and must be
   settled in #112's scoping.

## Grouping: 6 specs + 1 hardening build + 1 refactor + 2 decisions

One more spec than the prior plan's upper bound of five, entirely because #113
splits in two rather than standing alone. Spec A may reasonably run as a build
instead (see its note), which returns the count to five.

### Spec A — Rename-path correctness gates · #113's 3 gates + #124
`platform`. Amend the frozen resolution / high-water semantics so the first
rename record cannot mis-resolve a citation or reissue a consumed ordinal:
anchor forward-replay on rename-in destinations; count rename sources in the
high-water; alias a renamed group in the membership filter; align reconcile's
filter with `alloc_next_num_issue`. Emits no new records — pure `jimalloc.sh`
semantics plus fixtures (none of the four has a fixture today).

**The sequencing gate.** Every fix here is still a *pre-emission* change: both
live logs hold zero rename records, so nothing has mis-resolved yet and no
migration is owed. That window closes the moment Spec B ships.

**Open fork — spec or build?** By this note's own rule (localized fixes with
fixtures → build, no spec), A qualifies as a build. It is written as a spec here
because it amends semantics `platform/007` deliberately froze and that other
specs' ACs reference, so the amendment deserves a trail. Running it as a build is
a defensible speed call.

### Spec B — Rename/redirect record emission · #113's deliverable
`blueprint`. Depends on **A**. Also owns the two dereferenceability decisions
scoped out of A once investigation showed they cannot affect allocation — whether
the emitter must allocate every rename source, and whether the resolver should
count a source as known (a source-only id is unresolvable today). Both are
recorded on #113 with the measured side effects. `/jim:partition`, `rename`, and `split` emit
redirect records (Shape 1: renumber = new allocation + redirect tombstone), so
trailers frozen in git history stay dereferenceable; a mass-move batches into one
CAS; a pre-edit registry fetch surfaces the edit-vs-rename conflict before merge;
G6 stale-citation normalization. Also picks up the two carve-outs pointed here by
the closures: `platform/008`'s vacated high-water for retired or
partition-source groups (jim's own retired `jim` group is that case), and
`platform/009`'s citation normalization for realized provisionals.

### Spec C — Spec-ID allocator consumer · #112 + #123
`sdlc`. Reserve `group/NNN` through the allocator at ID-assignment time instead
of deriving it from the tree; #123 (the legacy `jimfile.sh next-id` group/kind
collision for a group named `issue`) is retired once that lands. Independent of
A and B **for allocation** — it emits allocate records only, like the foundation.
Gated on one decision, not on code: are specs **fail-only** under `provisional`
(cheap, ships now), or does spec provisional **wait for B** (honest, slower)?
See *What verification changed* #5.

### Spec D — Batch-CAS candidate-batch allocation (§7a rework) · #127
Collapse an end-of-run candidate batch (8 surfacing skills) into one CAS instead
of N sequential pushes. Cross-group blast radius (sdlc + blueprint + issue) and
its own all-or-nothing-vs-partial failure-semantics decision. Independent.

### Spec E — Registry integrity & drift · #116 + #130
Complementary halves — "detect drift" and "fix drift":
- #116 — a `jim:verify`-style only-door sweep: every spec dir / issue ordinal on
  the coordination branch must have a matching registry record.
- #130 — an incremental seed catch-up verb that appends the records missing from
  a *non-empty* log under the same CAS/erosion discipline.

Worth noting #130 has already bitten: all 64 spec records are stamped
`jim-seed`, including `issue/010`, `platform/009`, and `platform/010`, which
post-date the seed and were hand-appended in the 2026-07-28 realignment. The
gap is not hypothetical, which argues its `low` priority is understated.

### Spec F — `issue_placement` / issue content location · #126
Where a filed issue's *content* lives: central branch vs on-branch, the
`issue_placement` config key, the disclosure surface (centralizing publishes
bodies earlier and wider), and reconciliation with the VISION non-goal that issue
capture is a discovery artifact, not a coordination primitive. The one clause of
#111 that did not ship. Genuine undecided design → its own scoping.

### One grouped hardening build (6) — no spec
**#119, #121, #132, #133, #134, #117** — localized review-finding fixes, each a
testable one-to-few-line change with a test per fix:
- #119 retry the unreachable-detection path + generalize the exhaustion message
- #121 normalize seed reserved-slot skip + cap spec-ordinal magnitude
- #132 `new.sh` mixed-pin (`--slug` XOR `--num`) registry/on-disk skew
- #133 fence-bound reconcile's provisional detection to the frontmatter block
- #134 check `reconcile.sh`'s index-regen exit code (don't swallow it)
- #117 `moved-to` tombstone guarding coordination-branch relocation

(#124 moved to Spec A; #122 is below.)

### One small refactor — #122's remaining half
Factor the shared land step (tier select → CAS → arm baseline) so the allocation
path and `alloc_publish` share one implementation, generalizing the commit
builder over one-or-many blobs. Not a correctness gap — guarantees are equivalent
today — so this can park indefinitely. Kept out of the hardening build because
it touches the allocation path rather than a leaf.

### Decision + docs (2) — no spec
- **#129** — run jim's agent profile as `id_coordination_unreachable =
  provisional`? The machinery exists (`platform/009`), and the flip is already
  sitting uncommitted in `jimconf.toml`. Now carries a dependency it did not
  have: under `provisional`, Spec C mints unrealizable spec identities until
  Spec B ships. Decide the two together.
- **#118** — coordination-branch protection / team setup docs (middle protection
  profile: direct push allowed, force-push + deletion denied).

## Sequence

Ordered for **correct allocation** — the goal being a flow that cannot hand out
an id the project already owns. That is a different order than
what-unblocks-what, because the two biggest gaps are not code in A or B.

**1. A, alone.** It emits nothing, touches one file plus fixtures, and each defect
reproduces in seconds against a crafted log. It is also the only item whose window
can close, since the live logs still hold no rename record.

**2. C — the keystone.** Nothing allocates spec ids through the allocator *at
all* today: all 64 spec records are `jim-seed`-stamped, so spec-allocation
correctness is theoretical until the consumer is wired. C's blocker is a decision,
not code — settle the provisional-spec fork (and #129 with it).

**3. E — the baseline.** A correct fold over records that misrepresent the repo
still hands out a consumed id. This already happened: three specs post-dating the
seed were hand-appended, and without that patch the allocator would have reissued
`platform/009`. Detection (#116) and repair (#130) are what make the registry
trustworthy rather than hand-maintained.

**4. B, later.** Its allocation-relevant piece is the vacated-ordinal floor —
`jimfile.sh next-id` floors past vacated ids via the ledger's split/merge events
while the allocator's fold has no floor record at all. The rest of B (redirect
emission, citation dereferenceability, the batched mass-move) is a
dereferenceability story, valuable but not allocation.

**Free-floating:** D, F, the hardening build, #118, and the #122 refactor — any
time, any order.

**What A does *not* buy.** Correct arithmetic over the records present. It does
not make the records represent the repo (E), does not make anything go through the
allocator (C), and does not establish the vacated floor (B). Shipping A is not
"allocation is now correct."

## Per-issue disposition (all 20)

| # | Pri | Disposition |
|---|---|---|
| 111 | high | **closed** — shipped as `issue/010` |
| 114 | high | **closed** — shipped as `platform/008` |
| 115 | med  | **closed** — shipped as `platform/009` |
| 113 | high | Spec A (3 correctness gates) + Spec B (record emission) |
| 124 | low  | Spec A (high-water filter agreement) |
| 112 | high | Spec C (spec-group consumer; settle the provisional fork) |
| 123 | med  | Spec C (legacy next-id path, retired by #112) |
| 127 | high | Spec D (batch-CAS) |
| 116 | med  | Spec E (only-door sweep) |
| 130 | low  | Spec E (catch-up verb — priority likely understated) |
| 126 | med  | Spec F (issue_placement) |
| 119 | low  | hardening build |
| 121 | med  | hardening build |
| 132 | low  | hardening build |
| 133 | low  | hardening build |
| 134 | low  | hardening build |
| 117 | low  | hardening build |
| 122 | low  | half closed by `platform/009`; remainder is a standalone refactor |
| 129 | med  | decision + docs (provisional agent profile) — decide with Spec C |
| 118 | med  | docs (coordination-branch protection / team setup) |

## Net

20 issues → **6 specs** (5 if Spec A runs as a build), **1 hardening build of
6**, **1 optional refactor**, **2 doc/decision items**, **3 closed**.
