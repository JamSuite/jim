# ID-coordination issue cluster — spec grouping analysis

**Created:** 2026-07-28 · **Revised:** 2026-07-31 (third revision) — step 0 is
done: the registry repaired from the host and the `provisional` flip committed,
closing #144 and #129. **C′ is now the next move.**

The second revision (2026-07-30) is what reshaped the note: Spec A shipped as
`platform/011` and Spec C as `sdlc/017`, both the same day, and C shipped
**major-drift** costing **eighteen issues** — more than the entire hardening
bucket this note had budgeted. The grouping question changed shape there; see
*What `sdlc/017` changed* and *The grouping question, restated*.
Source: `/jim:issue insights` surfaced a 20-issue id-coordination convergence
cluster; this note answers "which deserve a spec, and how to group the work"
without minting a spec per issue.

Working note — not a spec. Delete or fold into a roadmap once the groupings are
acted on. Two groupings (A, C) have now been acted on.

Line/function anchors in this note are as of the revision date.
`skills/file/scripts/jimalloc.sh` moves under consolidation — treat anchors as
dated, and re-verify before planning against them.

## The cluster — now 46 issues

Original 20: #111, #112, #113, #114, #115, #116, #117, #118, #119, #121, #122,
#123, #124, #126, #127, #129, #130, #132, #133, #134.

Eight added by `platform/011`'s spec, build, and review: #135, #136, #137, #138,
#139, #140, #141, #142.

**Eighteen added by `sdlc/017`** — #143 at scoping, #144, #152, #153 during the
build, and #145–#151, #154–#160 by its post-build review. All eighteen were
filed offline against provisional ordinals and realized in one host batch; the
loop's second clean production run.

**Eight are closed:** #111, #114, #115, #124, plus #112, #135, #144 and #129 on
2026-07-31.

They are the residue of turning `platform/007`'s allocator foundation (emits
allocate records only — no consumers, no seed, no rename records) into the
project's authoritative, drift-proof ID source.

## Closed (8) — shipped and verified

| Issue | Shipped as | Review | Carve-outs (tracked) |
|---|---|---|---|
| **#111** wire issue display ordinal | `issue/010` | minor-drift, 11/11 AC | `issue_placement` never shipped → #126; per-item batching → #127; review edges → #132, #133, #134 |
| **#114** seed registry from artifacts | `platform/008` | minor-drift, 10/10 AC | duplicate-ordinal fork resolved as *halt-and-report*; vacated high-water for retired groups → #113; residue → #121, #122, #130 |
| **#115** provisional + reconcile | `platform/009` | **aligned**, 13/13 AC | spec-side reconcile deferred → #112/#113; residue → #124, #129 |
| **#124** reconcile/allocation high-water split | `platform/011` (as its D4) | minor-drift, 13/13 AC | resolved structurally — see below |
| **#112** wire spec-id allocation | `sdlc/017` | **major-drift**, 8/15 AC clean | the halt, the path helper, the blueprint fold → C′; registry repair → #144 |
| **#135** unrealizable provisional spec identity | `sdlc/017` | **major-drift** | fork resolved as provisional-with-realization; no carve-out |

Verified live at this revision, not from the review artifacts: after the
2026-07-31 repair the coordination branch holds **62** `spec allocate` + 4
`group allocate` records in `specs.log` — the 60 seeded ones plus `platform/011`
and `sdlc/017`, the first two records jim did not seed — newest `sdlc/017`;
`issues.log` carries ordinals through 160; no `<group>/000` record; suite
903/903.

*(An earlier revision reported "64 spec + 4 group" — 64 is the file's total line
count, not the spec-record count. Corrected above.)*

**Four more closed 2026-07-31.** Two on `sdlc/017`'s account — #112 (spec-id
allocation wired, with C′'s carve-outs recorded on it) and #135 (`allocate spec`
under `provisional` now has a realization path, so the trap is closed rather than
merely unreachable) — and two by the host session: #144 (the registry repaired)
and #129 (the `provisional` flip committed as `3d49ce9`).

**#123 was expected to die moot with them, and does not.** The prior revision
recorded it as retired by `sdlc/017`; checking before closing it showed
otherwise. `sdlc/017` retired the `/jim:spec` caller, but `jimfile.sh next-id`
kept its `/jim:partition` caller, and jim's own repo is the collision case:
`next-id issue` errors instead of returning `011`, because `docs/specs/issue/`
is a spec group whose name is also a kind keyword. `/jim:partition merge … into
issue` passes that stdout verbatim as `merge-map`'s `<start>`, so the collision
reaches a live consumer — it fails loudly there rather than mis-assigning, which
is exactly why it stayed invisible. Narrower than filed, still open, and it has
moved from the spec surface to the partition surface.

The lesson is small and worth keeping: "retired by X" is a claim about callers,
and this note asserted it from the *spec's* scope rather than from the verb's
call sites.

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

## What `platform/011` changed

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

## What `sdlc/017` changed

Shipped `f930730..781d0b1`, 25 commits, 903/903. Review **major-drift**: three
critical findings, two security regressions, one high-criticality living-intent
violation, and 7 of 15 ACs recorded as drift, partial, or divergent. *(The
review's own summary line and its ledger event both say "15 findings"; the body
numbers sixteen. The count was recorded before the last one was written.)*

1. **The spec that wires the allocator did not itself allocate.** `sdlc/017`
   exists on disk with **no registry record**, exactly like `platform/011`. The
   drift this note tracked as one spec is now two, and shipping the consumer did
   not repair it — the consumer stops *new* drift, it cannot repair drift that
   predates it. `peek spec platform` and `peek spec sdlc` both still answer below
   what the tree holds. Filed as **#144**, and it is now the oldest unpaid debt
   in the cluster: A closed the arithmetic, C closed the door, and the records
   still misrepresent the repo.

2. **One spec produced seventeen issues.** That is the number worth sitting with.
   The hardening bucket this note budgeted holds ten. A single spec out-produced
   it by 70% — so the cluster is not converging on issue count, it is diverging,
   and the generator is the spec-completion gate rather than the backlog.

3. **The verdict flipped on review method, not on code.** The same commit range,
   reviewed by its author without independent investigation, produced
   `minor-drift` and five findings. A ten-investigator fan-out over the same
   regions produced `major-drift`, three criticals and fifteen. Nothing about the
   code changed in between. This is the cheapest available lever in the whole
   cluster and it costs one flag.

4. **The 903-case suite was silent on every critical.** Each one is either an
   omission (nothing asserts the path helper's provisional shape), a boundary the
   tests share an assumption with (the unpadded ordinal), or a defect in code the
   build reused *on purpose* (the double-resolving fold). Test-passing and
   contract-satisfying diverged completely over this range — which is the
   strongest argument in this note against treating a green build as done.

5. **The living-intent sensor never ran, and it was the mechanism that would have
   caught the highest-cost finding.** `spec-id-sequencing` (high criticality) is
   declared in `sdlc`'s and `jim`'s blueprints and is now false in **both** halves
   by deliberate design — a provisional identity is not three digits, and the
   minting mechanism is no longer `next-id`. Nothing folded either declaration
   (**#149**). The next `/jim:verify` of either group must score every provisional
   spec a violation or silently reinterpret its own invariant.

6. **Two of three plan deviations were the same plan defect** — an instruction
   naming the right change in the wrong place. Task 6 pointed at
   `rename-tracked`'s non-existent basename gate when it meant `move-spec-dir`'s;
   the consequence of leaving that unnamed is **#152**/**#154**, since
   `move-spec-dir` is exactly the primitive a partition needs and refuses.

7. **Provisional mode is dogfooded and works.** All eighteen issues were filed
   offline and realized in one host batch onto 143–160 — no gap, no collision,
   against a high-water of 142. Second clean production exercise. **#129's flip is
   what filed these** — de facto in force at the time of writing, and committed
   the next day as `3d49ce9`.

## The grouping question, restated

The original question was "which of 29 issues deserve a spec". That question is
now secondary. The live question is: **how does this cluster absorb eighteen
issues from a single spec without minting a spec per pile** — and the answer has
to attack the generator, not just sort the pile.

**The rule this revision adopts:** an issue that records a shipped spec's *unmet
contract* is not new work. It is that spec finishing. It does not earn a new
grouping and it does not raise the spec count — it rides in one remediation pass
attached to the spec that produced it, occupying that spec's slot.

Applied to `sdlc/017`'s eighteen: **twelve** are C's own unmet contract (below as
**C′**), **three** join a grouping that already exists (#143, #152, #154 → B),
**two** are leaves (#153, #155 → hardening), and **one** — #144 — is not spec
work at all but a host action that should happen before anything else.

C′ additionally *absorbs* two pre-existing hardening items, #133 and #134, so
C's eighteen cost the hardening bucket nothing net (two out, two in; it later
grows by one for an unrelated reason — #123 below). The reason for the absorption
is the point of the whole exercise: both are defects in the issue-side
`reconcile.sh`, and C shipped
a spec-side `reconcile.sh` carrying **the same two bugs** — a detection/rewrite
region mismatch (#158) and a swallowed index-regen exit code (#151c). Fixing one
file and leaving its twin is how the pattern spread in the first place.

Net effect: **eighteen new issues, zero net new specs.** C′ occupies C's slot;
nothing else in the grouping grows.

## Grouping: 5 remaining specs + 1 hardening build + 1 refactor + 2 open items

A and C are done. C′, B, D, E, F remain.

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

**New obligations from C (`sdlc/017`, shipped 2026-07-30) — three issues, one
question.** B grows by exactly one theme: *what happens to a pending provisional
identity when the group beneath it moves.*

- **#143** — spec realization records every provisional→real mapping as a durable
  ledger redirect; B lifts those into registry redirect records, which forces the
  provisional-source grammar decision: a `P-` token is not a legal rename source
  in the frozen grammar.
- **#152** — realization cannot follow a group renamed since issuance. It fails
  safe (a loud halt, the rest of the batch lands, the manual path converges), but
  the fix needs the cross-parent move neither primitive can express today:
  `rename-tracked` enforces same-parent, `mv-spec-id` composes inside the source
  group. `move-spec-dir` *is* that primitive and refuses a `P-` source — which is
  the change C's plan described as its task 6 and mis-attributed.
- **#154** — a partition aborts its whole split remap on a provisional source and
  silently skips it on a merge, and blueprint synthesis excludes it with no note.
  Same question, group-level operations instead of realization.

All three want the same two decisions (widen `move-spec-dir`'s source gate; decide
whether a pending identity is carried or refused), so they scope together. #152
also carries a latent defect worth taking whenever B is picked up regardless of
the rest: nothing rewrites a spec's frontmatter `group:` field, harmless today
only because the group never changes across a realization.

### ~~Spec C — Spec-ID allocator consumer~~ · SHIPPED as `sdlc/017`
`#112` + `#135` closed; `#123` narrowed, not retired. Spec creation now binds through
`allocate spec` at write time (peek-advisory at interview open, so an abandoned
interview burns no ordinal), the legacy tree-scan path is stranded, and offline
sessions complete on a provisional identity that `/jim:spec reconcile` realizes.
The forks resolved during scoping held: #135 → provisional-with-realization (not
fail-only; jim must not break offline) and binding at allocate-at-write. #123 did
**not** die with it — see *Closed*; its surviving caller is `/jim:partition`.

**Shipped complete, but not correct.** See *What `sdlc/017` changed*. The
mechanism is right and the drift is real: the halt that makes the whole thing
safe is bypassable, the path helper composes directories that do not exist, and
the group's own blueprint now contradicts the code. Those are C's ACs, not new
scope — hence C′.

### Spec C′ — Finish `sdlc/017` · 12 of C's issues + #133 + #134
`sdlc`, with allocator-side work in `platform`. **The keystone's second half.**

| Class | Issues |
|---|---|
| Criticals | #146 path helper · #149 blueprint invariant fold · #150 ordinal gate + silent record loss (both security regressions) |
| Highs | #156 creation-side halt · #159 double alias resolution in the shared fold · #160 citation sweep (fence tracker + path-vs-typed pick) |
| Correctness residue | #157 exhaustion contract · #158 scan/rewrite region mismatch · #151 realize-path silent-failure batch |
| Absorbed twins | #133 · #134 — the same two bugs in the issue-side `reconcile.sh` |
| Closing the loop | #145 fixtures · #147 user docs · #148 skill self-contradiction |

**Run it as a spec, not as a build** — three reasons, and they are the reasons
the hardening-build shape does not fit:

1. **#150 is two security regressions.** A build has no `/jim:sec` gate. The
   accepted residual in C's own security review (a crafted record is *detected*,
   not prevented) is exactly the vector that drives them — and there it is not
   detected, because the padding gate landed on one rename primitive and not the
   other. An accepted residual is only as good as the detection justifying it.
2. **Three genuine forks need a decision surface** (pre-decided below, so scoping
   should be short rather than absent).
3. **#149 is a blueprint write across two groups.** That belongs at a spec's
   completion gate, through `/jim:blueprint --from-review` — never a hand edit.

**Scope it explicitly as remediation.** C′ inherits `sdlc/017`'s fifteen ACs
rather than authoring new ones; its Definition of Done is "those ACs actually
hold, each evidenced by a fixture." That framing is what keeps the spec count
flat — C′ occupies C's slot instead of reading as a sequel — and it keeps the
ledger honest, because the drift stays attached to the spec that drifted rather
than being laundered into a second aligned spec.

**The three forks, pre-decided here so C′'s scoping is cheap:**

- **#146 — teach `cmd_path` a provisional form** (taking the token as the whole
  basename, validating `id`/`name` there), rather than "a provisional spec's
  paths are read, never composed." The alternative leaves five call sites each
  remembering an undocumented rule; one of them fires unattended.
- **AC 14's halt — one shared numeric ordinal-occupancy predicate**, consumed by
  both the creation path and the realize path, rather than two asymmetric checks.
  #150 and #156 are the same missing check on two paths; fixing them as one
  predicate is what stops the third path from being missed later.
- **#149 — restate the invariant to cover both identity states**: minted by the
  coordination allocator, either a 3-digit zero-padded ordinal unique within its
  group or a reserved provisional token pending realization. Fold into `sdlc`
  *and* `jim`; the `jim` copy needs its own pass since it is outside C's group.

**Sequence inside C′:** #150 first (it makes #151's silent ledger drop
unreachable and #145's first two fixtures meaningful), then #156 on the shared
predicate, then the rest in any order.

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

**#144 split, and its urgent half was not E's — that half is now done.** The
one-time alignment landed from the host on 2026-07-31: two hand-appended records
carrying each spec's own issuance date, `b1aedca..19c4328`. Note the mechanism
this note first assumed — `seed --apply` — does **not** work: seed is
bootstrap-only and refuses a log that already has records
(`jimalloc.sh:1652`). That refusal is precisely the hole #130 fills, and it is
the third independent piece of evidence in this note that #130's `low` priority
is wrong: without an incremental catch-up verb, every future instance of this is
a hand-edit of a coordination branch.

The *standing* half — detecting and repairing this class of drift automatically —
is E's charter and stays here. E also inherits the retired-`jim` instance
recorded under Spec B: emitting records fixes future splits, backfilling the 52
ordinals the 2026-07-25 split already vacated does not follow from it.

### Spec F — `issue_placement` / issue content location · #126
Where a filed issue's *content* lives: central branch vs on-branch, the
`issue_placement` config key, the disclosure surface (centralizing publishes
bodies earlier and wider), and reconciliation with the VISION non-goal that issue
capture is a discovery artifact, not a coordination primitive. The one clause of
#111 that did not ship. Genuine undecided design → its own scoping.

### One grouped hardening build (11) — no spec
Localized fixes, each a testable one-to-few-line change with a test per fix.

One returned from the dead:
- #123 `next-id`'s group/kind collision — assumed retired with `sdlc/017`, but
  `/jim:partition` still calls the verb and jim's own `issue` group is the
  collision case. An explicit `next-id spec <group>` form is the cleanest fix

Four from the `008`/`009`/`010` reviews:
- #119 retry the unreachable-detection path + generalize the exhaustion message
- #121 normalize the seed reserved-slot skip *(magnitude half shipped with A)*
- #132 `new.sh` mixed-pin (`--slug` XOR `--num`) registry/on-disk skew
- #117 `moved-to` tombstone guarding coordination-branch relocation

*(#133 and #134 moved to C′ — their spec-side twins are C's, and the two must be
fixed in one pass or the pattern keeps spreading.)*

Two from `sdlc/017`:
- #153 `run.sh` honors only its first filter argument, so a multi-filter Verify
  command silently checks less than it claims — which is how C's plan carried a
  task whose second half never ran
- #155 single-source the provisional identity grammar, or adopt the `is_valid_id`
  discipline (`SYNC:` comments + a byte-identity fixture); it is written three
  times across a trust boundary today

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

### Decisions + docs (2 open, 1 closed) — no spec
- **~~#129~~ — DECIDED and committed 2026-07-31 (`3d49ce9`).** jim's agent
  profile runs `id_coordination_unreachable = provisional`. The dependency that
  gated it was gone: #135's unrealizable-spec-identity trap closed when C shipped
  spec-side realization, so provisional no longer mints anything that cannot be
  settled. Three clean production runs behind it by then, and it was already in
  force in the working tree — relied upon but unrecorded, which is what finally
  forced the decision rather than any new argument.
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
project already owns. Steps 1 and 2 are done, and neither delivered that
property, which is why the order below front-loads the two cheapest items.

**0. ~~#144's manual half + #129's commit.~~ DONE 2026-07-31.** Two `spec
allocate` records appended to the coordination branch from the host
(`b1aedca..19c4328`), each carrying its spec's own issuance date; the
`provisional` flip committed as `3d49ce9`. `peek spec` and `next-id` now agree in
both repaired groups (`platform` → 012, `sdlc` → 018), and a sweep found record
counts matching tree counts across all four live groups. #144 and #129 are
closed; the repair details live on #144.

**1. ~~A, alone.~~ DONE** — `platform/011`. Correct arithmetic over the records
present; the pre-emission rename window closed on all four defects.

**2. ~~C.~~ DONE** — `sdlc/017`. Spec creation goes through the allocator and the
offline path settles. Shipped major-drift; see C′.

**3. C′ — finish C.** The halt that makes coordinated identity *safe* is
bypassable today (#150, #156), and the group's blueprint contradicts its own code
(#149). Until C′ lands, C's guarantee is a claim rather than a property, and the
two security regressions sit on a surface a crafted registry record reaches.
This outranks E: a broken halt on a wired path is worse than stale records on an
unwired one.

**4. E — the baseline.** A correct fold over records that misrepresent the repo
still hands out a consumed id. Step 0 repairs today's instance by hand; E is what
stops it recurring — the only-door sweep (#116), the catch-up verb (#130), and
duplicate detection (#136). C stopped *new* drift; only E detects and repairs
what is already there.

**5. B, later.** Its allocation-relevant piece remains the vacated-ordinal floor,
and that piece stopped being theoretical on 2026-07-31: the step-0 verification
sweep found the retired `jim` group answering `peek spec jim` → `jim/001` against
`next-id jim` → `053`, because the registry holds no `jim/` records — and no
`group allocate jim` record either. The 2026-07-25 split rewrote 52 identities in
the tree and wrote **nothing** to the registry, so the whole group fell out of
coordination. Recorded on #113. Consequence is narrow (reachable only by scoping
into a retired group, which the doctrine forbids), so it was left unrepaired.

The rest — redirect emission, citation dereferenceability, the batched mass-move,
and the three provisional-under-a-moving-group issues (#143, #152, #154) — is a
dereferenceability story: valuable, not allocation. Unblocked whenever wanted.

Note B splits the same way #144 did: **emission is B's, repairing the instance
that predates it is E's.** Shipping B fixes future splits; `jim/001`–`jim/052`
stay unrecorded until something backfills them.

**Free-floating:** D, F, the hardening build, #118, #139, and the #122 refactor —
any time, any order.

**What A and C bought, and what they did not.** A bought correct arithmetic over
the records present and closed the rename window. C bought a door: nothing can
now create a spec id outside the allocator. Neither made the records represent
the repo (E, and step 0 for today's instance), and C did not make its own door
lock (C′). The proof is unchanged in form and worse in degree: two specs exist on
disk that the registry has never heard of, and one of them is the spec that
wired the allocator.

## Adopted practice — the reason C′ exists

Three changes, all process, none of which cost a spec or an issue. They are here
because the cluster's real cost driver is no longer the backlog, it is the
completion gate that lets a spec ship with its contract unmet.

1. **Run the review's investigator fan-out before closing the ledger, not after.**
   On C it was the entire difference between `minor-drift`/5 findings and
   `major-drift`/15 over an unchanged commit range. One flag, one review pass.
2. **Run the living-intent sensor on the shipping group before the completion
   gate.** #149 is a high-criticality invariant that a spec contradicted *by
   design*, in two blueprints, and nothing forced the fold. The fold-back loop's
   value is not the report it writes — it is the contradiction it refuses to let
   pass silently.
3. **At plan time, assert that each named verb has the property its task
   assumes.** Two of C's three plan deviations were the same defect: an
   instruction naming the right change in the wrong place. One of them
   (`rename-tracked` vs `move-spec-dir`) went on to generate #152 and #154.

A fourth, weaker but free: a green suite is not evidence. All 903 passed while
three criticals shipped, because each was an omission, a shared assumption, or
deliberately reused code. Treat "tests pass" as necessary and say nothing more
about it in a completion gate.

## Per-issue disposition (all 46)

| # | Pri | Disposition |
|---|---|---|
| 111 | high | **closed** — shipped as `issue/010` |
| 114 | high | **closed** — shipped as `platform/008` |
| 115 | med  | **closed** — shipped as `platform/009` |
| 124 | low  | **closed** — shipped as `platform/011`'s D4 |
| 112 | high | **closed** — `sdlc/017` wired the spec-group consumer |
| 135 | med  | **closed** — `sdlc/017` shipped the realization path |
| 123 | med  | hardening build — **narrowed, not moot**; `/jim:partition` still calls `next-id` |
| 144 | high | **closed** — registry repaired from the host 2026-07-31; standing half → Spec E |
| 146 | crit | Spec C′ (path helper composes a fabricated dir, 5 call sites) |
| 149 | crit | Spec C′ (blueprint invariant fold, `sdlc` + `jim`) |
| 150 | crit | Spec C′ (ordinal gate + silent record loss — 2 security regressions) |
| 156 | high | Spec C′ (creation-side halt; same predicate as #150) |
| 159 | high | Spec C′ (shared fold double-resolves group aliases) |
| 160 | high | Spec C′ (citation sweep: fence tracker + path-vs-typed pick) |
| 145 | med  | Spec C′ (the nine named fixture gaps) |
| 147 | med  | Spec C′ (WORKFLOW / README / spec-template) |
| 148 | med  | Spec C′ (skill self-contradiction, four sections) |
| 157 | med  | Spec C′ (exhaustion emits before halting) |
| 158 | med  | Spec C′ (scan/rewrite region mismatch) |
| 151 | low  | Spec C′ (realize-path silent-failure batch, 4 items) |
| 133 | low  | Spec C′ *(moved from hardening — issue-side twin of #158)* |
| 134 | low  | Spec C′ *(moved from hardening — issue-side twin of #151c)* |
| 113 | high | Spec B (record emission) — gates closed by `platform/011`; retired-group gap now demonstrated live |
| 143 | med  | Spec B (lift realization redirects into the registry) |
| 152 | med  | Spec B (realization cannot follow a renamed group) |
| 154 | med  | Spec B (partition + blueprint vs pending provisional specs) |
| 127 | high | Spec D (batch-CAS) |
| 116 | med  | Spec E (only-door sweep) |
| 130 | low  | Spec E (catch-up verb — **priority demonstrably wrong**, see above) |
| 136 | low  | Spec E (duplicate durable-id detection) |
| 126 | med  | Spec F (issue_placement) |
| 117 | low  | hardening build |
| 119 | low  | hardening build |
| 121 | med  | hardening build (reserved-slot half only; magnitude half shipped) |
| 132 | low  | hardening build |
| 138 | low  | hardening build (`platform/011` residue) |
| 140 | med  | hardening build (`platform/011` residue — test gap) |
| 141 | med  | hardening build (`platform/011` residue — test gap) |
| 142 | med  | hardening build (`platform/011` residue) |
| 153 | low  | hardening build (`sdlc/017` residue — `run.sh` filter args) |
| 155 | med  | hardening build (`sdlc/017` residue — triplicated grammar) |
| 122 | low  | half closed by `platform/009`; remainder is a standalone refactor |
| 129 | med  | **closed** — `provisional` committed as `3d49ce9` |
| 118 | med  | docs (coordination-branch protection / team setup) |
| 139 | low  | decision (`timeout` test dependency) |
| 137 | low  | deferred, no demand (exhausted-group recovery) |

## Net

46 issues → **5 remaining specs** (C′, B, D, E, F), **1 hardening build of 11**,
**1 optional refactor**, **1 doc item + 1 decision + 1 deferred**, **8 closed**.
The host action is done.

**The spec count did not move.** C shipped and C′ took its slot; eighteen new
issues distributed into work that already existed. That is the answer to "how do
we build this out without an excessive number of specs" — not finer grouping, but
a rule: *an issue recording a shipped spec's unmet contract belongs to that spec,
not to a new one.*

The headline has moved again, though. A's lesson was that the cluster's centre of
gravity was C and E, not A. C's lesson is sharper and less comfortable: **the
constraint is no longer which specs to write, it is whether a spec finishes.**
One spec shipped green, complete, and ledger-closed while three critical defects
and two security regressions rode along inside it — and the only thing that
surfaced them was a review method, applied after the fact, that costs one flag.
Until that runs before the completion gate, every remaining spec in this note
(B, D, E, F) should be assumed to carry its own C′.
