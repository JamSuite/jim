# ID-coordination issue cluster — spec grouping analysis

**Created:** 2026-07-28 · **Revised:** 2026-08-05 (thirteenth revision) — **B′
shipped and was reviewed.** Sixteen items built, eleven contracts fully
satisfied, verdict **minor-drift**. The review's finding is a build that
under-reaches: nine contracts were satisfied at the site their issue named and
left unapplied at a sibling nobody enumerated, and `catch-up` is that sibling
three times over — including a reachable path where it reissues a vacated
ordinal and the registry then reports clean. Six fixture claims fell to mutation
testing the build did not run. Eleven issues closed, four held open, fifteen
filed. See *What B′ changed* and `docs/notes/20260805-b-prime-review.md`.
The Sequence is extended in the same pass: step 6 closed, step 7 (B″ — #188
landing first, then the residue sequenced by the rule's doors) and step 8 (the
sdlc pass) added, and D's wait moves from B′ to B″.

**Twelfth revision (2026-08-03)** — **the documentation pass, and what running
the engine over it found.** #211's "fifteen sites" was a claim; re-derived from
the build's own diff it is **twenty**, and the miss that matters is `README.md` —
the front page described two hand-run repair verbs when there are three, because
the build gate regenerates `ARCHITECTURE.md` and nothing else. All twenty are
corrected. *(The review disproved that last sentence: three sites survive, one of
them named here and claimed fixed.)*

Grounding the blueprint half ran nine judges over `platform`: **six hold, four
violated**. Two were folded with restoration obligations recorded, two were
fixed. The fixes exposed a second-order lesson the suite caught twice — see
*What the doc pass changed* — and the width-bound judge caught **this note's own
author** inheriting a site count while re-deriving its neighbour's. Practice 11
is earned, and it is about folds rather than detection.

**Revised:** 2026-08-03 (eleventh revision) — **the
tracker caught up with the code, and the catching-up was itself the finding.**
`blueprint/025` delivered seven of this cluster's issues and closed none of
them, so for a day the collection read seven behind the tree; an eighth (#155)
was resolved by a fork this note had left open and nobody noticed it land. All
eight are now closed with resolutions recorded against what actually shipped.

Worse, and new: **six of that review's twenty findings rode none of the nine
issues it filed.** Each was verified still live in the working tree and is now
filed as #214–#219. So B's residue is **fifteen** issues, not nine — and the
gap earns a tenth practice, because nothing anywhere reconciles a review's
finding count against its filing count. See *What did not close with B*,
*Grouping* → B′, and practice 10.

**Revised:** 2026-08-02 (tenth revision) — **Spec B
shipped.** The registry has writers: `blueprint/025` landed the rename/redirect
grammar, both emission verbs, the lift, and the tree-scan retirement, then the
backfill ran origin-tier over jim's own history. The pre-emission window is
closed — the ground truth that framed every prior revision ("**zero** rename
records") is now 52 rename records, 2 realize records, and `peek spec jim`
answering `053` instead of the spent `001`. The post-build review returned
**major-drift** with 20 findings and the living-intent sensor 2 in-change
violations; nine follow-on issues (#205–#213) carry what did not close. See
*What `blueprint/025` changed* and *Sequence* step 5. The dereferenceability
story is delivered; what remains of the cluster is D, F, the hardening build,
and the emitter edges B left open.

The eighth revision (2026-08-02): **Spec E
shipped as `platform/012`, and the standing prediction held.** The registry is
now *checkable*: a read-only sweep and a catch-up repair verb, the five charter
issues closed (#116, #130, #136, #185, #121's remaining half), three filed
(#201–#203). Review **major-drift**, 15 findings, **two criticals in code the
build wrote fresh** — caught in-session by the fan-out rather than by the next
spec's review, which is the improvement the practices were adopted for. See
*What `platform/012` changed*.

The seventh revision (2026-08-01) was the pre-Spec-E context pass: the registry
re-verified aligned end-to-end, Spec E's scoping forks recorded as dated addenda
on #113, #116, #130, #136 and #185, and #130 raised to high.

The sixth revision (2026-08-01): **C′-fix's
own review is discharged, and practice 7 is earned.** The fifth revision closed
C′-fix with AC 12 holding; the review that build never got has since run, and its
21 findings are resolved: five fixed in place, seven filed as #190–#196, six
deliberately left. Fixing them earned a seventh practice, practice 6's sibling:
a result's *coverage* is as invisible in the artifact as a practice's absence. The
remediation chain terminated: C produced eighteen issues, C′ sixteen, C′-fix
**six** — and the six are adjacent observations rather than defects in shipped
mechanism. See *What C′-fix changed*, which also records the first failure mode
none of this note's practices can see: a practice that did not run leaves no
trace in its own artifact.

The second revision (2026-07-30) is what reshaped the note: Spec A shipped as
`platform/011` and Spec C as `sdlc/017`, both the same day, and C shipped
**major-drift** costing **eighteen issues** — more than the entire hardening
bucket this note had budgeted. The grouping question changed shape there; see
*What `sdlc/017` changed* and *The grouping question, restated*.
Source: `/jim:issue insights` surfaced a 20-issue id-coordination convergence
cluster; this note answers "which deserve a spec, and how to group the work"
without minting a spec per issue.

Working note — not a spec. Delete or fold into a roadmap once the groupings are
acted on. Seven groupings (A, C, C′, C′-fix, E, the pre-B build, and B) have now
been acted on; B′ is the eighth and has shipped.

Line/function anchors in this note are as of the revision date.
`skills/file/scripts/jimalloc.sh` moves under consolidation — treat anchors as
dated, and re-verify before planning against them.

## The cluster — now 83 issues

Original 20: #111, #112, #113, #114, #115, #116, #117, #118, #119, #121, #122,
#123, #124, #126, #127, #129, #130, #132, #133, #134.

Eight added by `platform/011`'s spec, build, and review: #135, #136, #137, #138,
#139, #140, #141, #142.

**Eighteen added by `sdlc/017`** — #143 at scoping, #144, #152, #153 during the
build, and #145–#151, #154–#160 by its post-build review. All eighteen were
filed offline against provisional ordinals and realized in one host batch; the
loop's second clean production run.

**Sixteen added by `sdlc/018` (C′)** — #168 and #170 from its build's candidate
batch, #169 from the same batch (process, not id-coordination, but generated
here), and #171–#183 by its post-build review. Filed on the host against real
ordinals; the provisional path was not exercised this time.

Separately and **not part of this cluster**: #161–#167, seven pre-existing `sdlc`
blueprint drifts surfaced by C′'s `/jim:verify sdlc` pass. They are living-intent
debt in the group C′ happened to touch — agent-handle namespacing, own-skill
sigil, a parenthesized injection slot, retired gate vocabulary, a template brace,
an unbounded bash grant on a read-only probe, and `/jim:plan`'s blacklist gate.
None was introduced by C′; none is id-coordination work. Recorded here only so
the 23 issues filed on 2026-07-31 are fully accounted for.

**Six added by C′-fix** — #184–#189, all from its post-build judge fan-out
except #189 (an incomplete territory sweep the developer caught). Two are process
rather than id-coordination but were generated here: #188 (a suppressed agent
fan-out leaves no trace) and #189. Filed offline against provisional ordinals and
realized in one host batch onto 184–189 — no gap, no collision. Fourth clean
production run of the provisional path, and the first where every marker came
from a build rather than a review.

**Seven added by C′-fix's own review** — #190–#196, the filed half of the 21
findings a five-investigator pass returned over the sdlc/issue-territory changes.
Nine of those findings were regressions from C′-fix itself. Filed offline against
provisional ordinals and realized in one host batch onto 190–196 — contiguous
from 189, no gap, no collision. Fifth clean production run of the provisional
path.

**Three added by `platform/012`'s review** — #201 (the sweep's per-file
frontmatter cost), #202 (rename-replay defects in the integrity classifier,
unreachable until rename emission lands), #203 (the realize halt's blast radius).
Filed offline against provisional ordinals and realized in one host batch onto
201–203 — contiguous from 200, no gap, no collision. Sixth clean production run
of the provisional path, and the first one the new sweep verb independently
verified: `203 records vs 203 files checked`, zero drift, zero pending
provisionals.

**Five adopted by the ninth revision (2026-08-02).** Four are
`platform/012`-session filings the eighth revision's accounting missed — it
counted the review's filings and not the session's: #197 and #199 (realize-path
citation defects observed in the first production spec realize), #198 (the
issue skill's wildcard jimalloc grant, live now that mutating verbs exist), and
#200 (the sanctioned repair path for registry-internal contradictions, whose
grammar half coordinates with Spec B). The fifth, #84, predates the cluster
(filed 2026-07-21 against `blueprint/019`): the ledger-side floor for group
names retired by rename. It joins because its fate hangs on a question Spec B
already owns — whether the tree-scan `next-id` surface survives at all.

**Sixty-three are closed.** The nineteen the fourth revision listed, plus all
sixteen of C′-fix's own (#168–#183), the two it unblocked (#151, #134), all
seven the review filed (#190–#196), Spec E's five charter issues (#116, #130,
#136, #185, and #121's remaining half), the pre-B build's four (#197, #198,
#199, #203), #149 and #189 as bookkeeping — and, on 2026-08-03, **B's eight**
(#84, #113, #123, #143, #152, #154, #155, #202).

Those eight are worth a sentence, because the note asserted them delivered a day
before the tracker agreed. B shipped them on 2026-08-02 and closed none; the
tenth revision counted them closed on the strength of what the code does. Both
readings were right about the code and only one was right about the collection.
#155 is the sharper case: it was parked here as *fork-dependent*, and the fork
resolved silently the moment `spec realize` put the reserved prefix into the
registry parser. Nothing watches a conditional disposition for its condition
becoming true.

That count under-reports the repair work, and deliberately so: **five of the
review's findings were fixed without ever being filed** (two `/jim:review`
liveness defects, the issue-template comment trap, two unguarded awk installs,
and thirteen retired-group references). They were small, all regressions from
this build, and filing-then-closing them would have been bookkeeping. The
accounting here is issue-based, so it cannot see them — the commits are
`6be4ac9`, `4b0d105`, `8f1fb6d`, `998156a`. Six further findings were judged
lower-confidence or lower-stakes and left unfiled, with their anchors recorded
in `docs/notes/20260801-c-prime-fix-handoff.md` § 4.

**None of C′'s fourteen survives.** #149 closed as bookkeeping on 2026-08-02 —
the `sdlc` half of the blueprint fold landed and the `jim` half was deliberately
dropped with the retired blueprint (see *What C′ changed*, item 3). #151 and
#134 closed with C′-fix — the first because its two defective items (#171,
#172/#173) are fixed, the second because the regeneration can no longer be
*skipped* rather than merely checked.

They are the residue of turning `platform/007`'s allocator foundation (emits
allocate records only — no consumers, no seed, no rename records) into the
project's authoritative, drift-proof ID source.

## Closed (63) — shipped and verified

| Issue | Shipped as | Review | Carve-outs (tracked) |
|---|---|---|---|
| **#111** wire issue display ordinal | `issue/010` | minor-drift, 11/11 AC | `issue_placement` never shipped → #126; per-item batching → #127; review edges → #132, #133, #134 |
| **#114** seed registry from artifacts | `platform/008` | minor-drift, 10/10 AC | duplicate-ordinal fork resolved as *halt-and-report*; vacated high-water for retired groups → #113; residue → #121, #122, #130 |
| **#115** provisional + reconcile | `platform/009` | **aligned**, 13/13 AC | spec-side reconcile deferred → #112/#113; residue → #124, #129 |
| **#124** reconcile/allocation high-water split | `platform/011` (as its D4) | minor-drift, 13/13 AC | resolved structurally — see below |
| **#112** wire spec-id allocation | `sdlc/017` | **major-drift**, 8/15 AC clean | the halt, the path helper, the blueprint fold → C′; registry repair → #144 |
| **#135** unrealizable provisional spec identity | `sdlc/017` | **major-drift** | fork resolved as provisional-with-realization; no carve-out |
| **eleven of C′'s fourteen** (#133, #145–#148, #150, #156–#160) | `sdlc/018` | **major-drift**, 16/17 AC | AC 12 unmet → C′-fix; #149, #151, #134 stay open |

Verified live at this revision, not from the review artifacts: after the
2026-07-31 repair the coordination branch holds **62** `spec allocate` + 4
`group allocate` records in `specs.log` — the 60 seeded ones plus `platform/011`
and `sdlc/017`, the first two records jim did not seed — newest `sdlc/017`;
`issues.log` carries ordinals through 160; no `<group>/000` record; suite
903/903.

*(An earlier revision reported "64 spec + 4 group" — 64 is the file's total line
count, not the spec-record count. Corrected above.)*

Re-verified 2026-08-01 (seventh revision): **63** spec + 4 group records —
`sdlc/018` joined, allocated at creation by the wired consumer, the first spec
record the allocator itself minted; `issues.log` through 196, matching 196
issue files; high-waters match the tree in all four live groups; suite
975/975. Registry and tree currently agree everywhere except the retired `jim`
group (#113).

Re-verified 2026-08-03 (eleventh revision), after the backfill and the
bookkeeping pass — the first sweep in this note's history with **no exceptions
of any class except the reserved slots**:

```
specs:  65 records vs 65 tree dirs; 4 group records vs 4 tree groups
issues: 219 records vs 219 files checked
  reserved-slots 5 · pending-provisionals 0 · uncovered-groups 0
  rename-source-ids 52 · unidentifiable 0 · unknown-verb 0
  duplicate-realize-keys 0
```

`peek spec jim` answers `053`; `resolve spec jim/029` answers `blueprint/001`
with the unallocated-source note. Suite 1097/1097. The retired-`jim` exception
that qualified every prior verification is gone — it was the last one.

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

## What C′ changed

Shipped as `sdlc/018`, `457d2ff..ff8853e`, 26 commits, 954/954 (+51 fixtures).
Review **major-drift**: 13 findings, 0 security regressions, 16 of 17 ACs met.

1. **AC 12 is unmet, and it is the one that mattered.** The criterion reads: *the
   realize path cannot silently do the wrong thing where it currently can.* Each
   of its three clauses shipped a **new** silent-wrong-thing:

   - The portable nesting guard built for its first clause assumes `mv` preserves
     the inode. It does not — on `EXDEV` `mv` copies and deletes, which is the
     default for renaming a lower or merged directory on **overlayfs**, i.e. the
     normal filesystem in containers and microVMs. The guard then reports a hard
     failure on a *correct* rename and instructs the operator to hand-repair a
     directory that is already right, while the realizer skips the frontmatter
     rewrite, the sweep and the ledger row — ordinal already published, `P-`
     basename gone, retry unable to find it. Half-applied and stranded (**#171**).
   - The absolute-specs-dir canonicalization built for its second clause derives
     its path relative to the worktree top while every consumer is CWD-relative,
     so `--apply` from a subdirectory silently no-ops at exit 0 while the preview
     from that same directory lists work to do (**#172**) — and it stopped one
     line short of the sweep's own roots, where the identical absolute-spelling
     defect survives and silently skips index regeneration (**#173**).
   - The verified-rewrite hardening interacts with the regen-exit-code fix to
     create a path that aborts *before* regeneration (**#174**).

   Sixteen of seventeen ACs are met, the suite is green, and every defect
   `sdlc/017`'s review recorded is closed. AC 12 is the exception, and it is the
   criterion the whole spec was named for.

2. **The adopted practices ran, and they worked — which is the good news and the
   limit of the news.** Practice 1 (investigator fan-out before closing the
   ledger) ran with eight investigators and produced every finding above; the
   author's own read of the same code had produced none of them. Practice 2
   (living-intent sensor on the shipping group) ran and forced the `sdlc`
   blueprint fold at an explicit violation fork. Practice 4 held: the suite was
   green throughout and said nothing about any of the four.

   But the fan-out runs *after* the build. It caught the defects; it did not
   prevent them, and C′ shipped its ledger closed with AC 12 unmet exactly as C
   did. The lever the third revision identified is real and it is not sufficient.

3. **AC 13 named a retired group, and five artifacts carried that forward
   unchecked.** `sdlc/017`'s review located `spec-id-sequencing` by matching its
   id across blueprint **files**, and reported `jim`'s copy five days after the
   group was split and its blueprint retired. #149, this note, C′'s AC 13, its
   research, and its plan task all inherited the pair without reading `status:`.
   `/jim:verify` and the reconcile pass both enumerate through the map and
   exclude a retired group correctly — the review's sweep is the outlier
   (**#169**). Caught at build time only because the developer asked why a
   retired blueprint was being edited; AC 13 was then amended in place to scope
   the restatement to blueprints a live group's verification consults.

4. **The generator has not stopped, but it has changed shape.** C produced 18
   issues, C′ produced 16. The difference is what they are: C's were three
   criticals plus two security regressions in *shipped* mechanism; C′'s are one
   critical, three highs, and nine medium/low, with **zero** security regressions
   and containment verified intact. The remediation is not converging to zero, it
   is converging to smaller.

5. **The defects cluster in new guards, not corrected ones.** Both defects
   `sdlc/017` actually shipped are properly closed, and both survived hostile
   review: the region-bounded frontmatter parsing was proven correct *by
   construction* (scan and rewrite predicates are the same set), and the citation
   sweep withstood every constructed counterexample. Everything that broke was
   code written fresh for AC 12 — and new guards have no prior fixture shape to
   inherit. The nesting guard is the sharpest case: its race cannot be produced
   deterministically from the CLI, so its fixtures exercise the function directly
   and never the wiring, which is precisely where #171 lives.

6. **Zero pre-existing fixtures were modified** — 928 test insertions, 0
   deletions. Nothing had to be un-taught, which corroborates C's post-mortem
   finding that its suite was silent by *omission* rather than by encoding wrong
   behavior.

7. **The build did not close the issues it fixed.** All fourteen were still
   `status: open` after the ledger closed; no plan task covered closing them.
   Eleven were closed during the review, three deliberately not (above). Worth
   folding into the completion gate rather than leaving to whoever notices.

## What C′-fix changed

Shipped as a build, no spec. 38 commits, 954/954 → 969/969 (+15 fixtures), zero
pre-existing fixtures modified. All sixteen of its issues closed, plus #151 and
#134. **AC 12 holds.**

1. **The generator finally decayed.** C produced 18 issues, C′ 16, C′-fix **6** —
   and the composition changed more than the count. C's were criticals and
   security regressions in shipped mechanism; C′'s were one critical, three highs
   and nine medium/low; C′-fix's are five adjacent observations (an unvalidated
   `ls-remote` tip, a pathspec asymmetry, an unfixtured option, a latent path
   composer, an unswept territory class) plus one process finding. Nothing it
   filed is a defect in mechanism it shipped. Four rounds in, the remediation
   chain reached a fixed point.

2. **C′'s own lesson reproduced exactly, and was caught in time.** C′ concluded
   that *new guards have no prior fixture shape to inherit*. C′-fix wrote one new
   guard — `move-spec-dir`'s occupancy gate — and shipped it **defective**, in
   precisely the predicted shape: the fixture covered the within-group case, and
   the defect lived in the cross-group one, where the self-exclusion argument
   silently skipped a genuine holder and let a renumber land two directories on
   one ordinal at rc 0. The difference from C and C′ is *when* it was caught —
   inside the same session, by the fan-out, rather than by the next spec's review.
   The practice works; it just has to actually run.

3. **Which is the finding that matters, and it is new: a practice that did not
   run leaves no trace in its own artifact.** The `/jim:verify` grounding run for
   the blueprint update had its judge fan-out suppressed by a harness-injected
   prompt directive, so its judge rung ran inline instead. It reported **10
   invariants, 0 violations** — indistinguishable, in the artifact, from a clean
   run. Re-run with the fan-out over the same code it returned **two** violations:
   the `move-spec-dir` defect above, and an invariant restatement that overstated
   what the code guarantees.

   Every practice this note adopted assumes its own mechanism ran. None of them
   detects its own absence. `/jim:verify` and `/jim:review` already name
   degradations they *can* see — an `UNSCOPED` floor, a capped fan-out, the
   appetite in force — and a fan-out that never ran belongs in that list.
   Tracked as **#188**.

4. **The developer caught what the engine and the author both missed.** #189 is a
   territory gap: three test files fell outside every group's declared territory.
   One was found and repaired; the other two were **mis-triaged as belonging to
   other groups without checking**, by the same pass that was cataloguing
   territory violations. No mechanism caught the half-sweep — a person asking
   "wasn't there another one?" did.

5. **Two decisions were reversed mid-build, both toward doing more work.** The
   `mv-spec` retirement was first recommended *against* on the grounds that it
   would force a blueprint write and so trip the criterion that sends work to a
   spec. That reasoning was wrong: declining to run a tool is not a reason to
   leave dead code in the tree, and the `--since` adapter exists precisely so an
   out-of-pipeline change can refresh a blueprint cheaply. Both doc surfaces were
   then corrected through their own skills rather than by hand. Second, the
   suppressed fan-out was initially accepted and merely *named* as a degradation
   rather than challenged — see item 3 for what that cost.

6. **The `--since` grounding path got its first real exercise**, and the retired
   verb was the ideal test of it: removing `mv-spec` edited a Provides face, which
   put the **breaking** detector directly over the removal. It reported zero,
   independently corroborating a caller sweep it had no knowledge of.

## What `platform/012` changed

Shipped `129e4ba..30236d0`, 23 commits, 1006/1006 → 1048/1048 (+42 fixtures).
Review **major-drift**: 15 findings, 2 security regressions, 2 criticals — both
fixed in the same session, before the ledger closed.

1. **The registry is checkable now, and the first thing it checked was itself.**
   `sweep` reports 64 spec records vs 64 tree dirs across 4 groups and 203 issue
   records vs 203 files, zero drift — and names the retired `jim` group as
   uncovered, which is the one class of group a tree-vs-registry comparison
   structurally cannot see. That case was designed in at plan time from a
   security finding, and it fired correctly on the real instance rather than on a
   fixture.

2. **The prediction this note has made four times held again, and hardest yet.**
   *What a spec builds fresh is where its defects live.* The three riders that
   repaired existing behavior — tip validation, reserved-slot normalization,
   marker parametrization — shipped clean. Both criticals were in code written
   for an AC:

   - the in-run cache added to the id boundary indexed on the raw token, so a
     record short a field produced an empty array subscript. A **single
     truncated line pushed to the branch broke `resolve` for every clone** —
     where the same input previously resolved fine, because the file's contract
     is that a malformed record is degraded and skipped;
   - the repair verb **manufactured the contradiction the sweep exists to
     detect**. The classifier treated a record with an unusable sibling field as
     absent while the resolvers counted it as a claim, so the identity read
     missing, `catch-up --apply` appended a second record and exited 0, `resolve`
     then refused — and the next sweep reported clean.

   Both were reproduced end to end before being believed, and again after being
   fixed.

3. **Both criticals had one root cause, and it is worth naming as a class.**
   Three readers of one log — the classifier, the resolvers, the realize path —
   applied three different rules for *what establishes a claim*. That single
   disagreement produced the append bug, the "clean report over an unreadable
   registry" gap, and the padded-vs-bare ordinal split where the sweep read clean
   and `resolve` said not-allocated. One rule now decides it. When a build adds a
   second reader of an existing data structure, the question to ask at plan time
   is not "is the new reader correct" but "does it agree with the old one".

4. **The fan-out earned its cost; verifying it earned more.** Ten investigators
   produced 15 findings the author's own read produced none of. But of the three
   reported criticals, **one was refuted by execution** — two investigators
   independently reasoned that `@`/`*` bypass the id boundary through the cache,
   and both were wrong about bash subscript semantics. That is the second
   consecutive build where a reasoned-from-source finding died on contact with a
   shell (#195, #196 were the first pair). The practice is not "run the fan-out"
   but **"run the fan-out, then reproduce its criticals before believing them"**.

5. **Practice 7 caught its own author.** The build's mutation audit claimed
   coverage of "every classifier class" while grading per *class* rather than per
   *kind × class* — three issue-side emit sites had no discriminating fixture as
   a result. The audit note now states the scope it actually measured. A coverage
   claim is only as good as its bounds, and the person best placed to overstate
   them is the one who wrote the audit.

6. **A plan decision was wrong on measurement, not on judgment.** DD 4 predicted
   the sweep's cost would be the id boundary and named #142 as the escalation
   path. Profiled on the live collection: the classification cores are 167 ms of
   ~14 s, and the cost is per-file frontmatter `sed` forks in the *existing*
   derivation. Filed as #201 with the phase table, and #142 carries a note not to
   close one against the other. Worth generalizing: a plan's performance premise
   is a hypothesis, and the build is where it gets tested.

7. **The verify registry rung ran here for the first time.** No
   `verify_command_*` had ever been configured in this repo, so the rung existed
   and had never executed. `registry-tree-consistency` on the platform blueprint
   plus `verify_command_id-sweep` in `jimconf.toml` closes that — exit 0 →
   `holds`, observed. The exit-code contract (`3` drift, `4` could-not-check) was
   designed against that mapping at plan time.

8. **A one-time-migration contract changed under a second consumer.** The
   provisional-issue skip was added to the shared derivation for the sweep's
   benefit, and it silently rewrote what `seed --apply` does — from refusing a
   tree with a pending provisional to seeding everything else without it. The new
   ordering is genuinely safer, but the bootstrap now says what it passed over,
   which it did not before. Shared code has more than one contract.

## What `blueprint/025` changed

The registry gained the write half of a grammar it had only ever parsed. Zero
rename records existed anywhere when the build started, which is what made the
shape change free: strictness could be tightened and `<who>` made required with
no migration exposure, because there was nothing to migrate.

**One rule replaced seven.** `alloc_rename_scan` is the single rename-record
reader; both resolvers, the alias map, both high-water folds, both integrity
classifiers, group coverage, and the sweep fold its output. Shape is decided in
one place — exact six fields, a gated `<date>`, a required `<who>` in the write
side's own charset — which retired the trailing-token leniency that had lived
unnoticed in a fixture. Canonicalization is reported **per side**, so an
unrepresentable source no longer drops its destination's establishing claim: the
joint gate's cost, pinned as a known defect since A, now paid.

**Resolution reaches further and says less confidently.** A citation whose only
registry appearance is as a rename source now dereferences, with a stderr note
that no allocation stands behind the answer; a walk that stops at a destination
the registry cannot represent discloses rather than answering as though the
record were absent. One unallocated source vacated twice stays a refusal — it
has no single referent to name.

**Realization got its own verb.** `spec realize` keeps the reserved `P-` form
out of rename parsing entirely, so the vacating fold can never count a
provisional as a consumed ordinal — the fold-safety #143 asked for, structural
rather than special-cased. It is emitted **live**, in the same CAS batch as the
realization's allocate, so no window exists where the ordinal is durable and the
citation that became it resolves nowhere. That left the lift as pure repair,
which sharpened its idempotency from a nicety into its whole contract.

**Two writers, both corroborating inside the CAS window.** `partition-batch`
publishes a renumber pair set as allocate + rename per pair (Shape 1, the
charter's), or one record for a whole group; `lift` turns the specs-root
ledger's durable pair events into records. Both recompute their refusals inside
the publish builder on every attempt, so a conflict another clone introduced
between check and commit is caught by the attempt that would have overwritten
it. The lift treats the ledger as a **witness, not an instruction**: a pair is
recorded only where the registry independently establishes its destination and
holds no live claim on its source — without that, an operator's run would
convert push-writable content into registry records under their own authority.

**The tree-scan path is gone, not patched.** `jimfile.sh next-id` answers for
issues only and `jimledger.sh vacated-max` retired with the caller it floored.
Two computations of one number can disagree mid-move; #84 (the rename floor) and
#123 (the group/kind collision) were both defects *of that path*, so they ceased
to exist rather than being fixed. The registry now records a vacated ordinal as
a rename source, which any clone reads — where the old floor inferred it from a
ledger event a fresh clone may never have seen.

**The backfill closed the instance that predates emission.** 52 pairs from the
2026-07-25 split plus 2 realizations, each carrying `jim-lift` and the day the
identity actually moved. `peek spec jim` moved `001 → 053`; the sweep reports
`uncovered-groups 0` and `rename-source-ids 52`; `resolve spec jim/029` answers
`blueprint/001` with the unallocated-source note. A commit trailer written before
the split now dereferences.

**What it did not close.** The review found two ACs with reproducible
counterexamples — a chained group rename is impossible (`alloc_group_has_records`
does not recognise a group established only as a rename *destination*), and the
lift's batch guard leaves no trace, so a second run writes what the first
refused. Three more contradictions the emitter still accepts: a vacated ordinal
re-minted, the reserved `000` slot as a destination, and an unchecked
destination-group redirect. The living-intent sensor added a critical
`partition-registry-boundary` violation (merge-preflight probes the filesystem
with an unvalidated group, where its two siblings gate at entry) and a `high`
`present-tense` one (the new blueprint disclosure echoes untrusted directory
names into a gate summary unsanitized). Those nine ride #205–#213.

**And six more rode nothing at all** (found 2026-08-03, eleventh revision). The
review reported **twenty** findings; the filing pass produced **nine** issues,
and the difference was never reconciled by anything. Each of the six was
verified still live in the working tree before filing — no fix had landed after
the review closed:

| Finding | Now | What it is |
|---|---|---|
| 7 | **#214** | a duplicated realize key is resolved by *position*, not refused, and `alloc_realize_scan`'s three consumers disagree — the resolver takes first, the lift's `rz_of` takes last, `alloc_lift_state` calls it a conflict |
| 18 | #217 | `alloc_classify_spec` lost `local` on `c4` and `canon`; `g` left dead |
| 19 | #219 | `alloc_malformed_count`'s selector admits `spec:group`, so one crafted `group realize` line lands in two counters a comment says are reported apart on purpose |
| 20a | #218 | the id-boundary memo no longer warms across passes — the extraction moved record-side validation into subshells |
| 20b | #216 | the pure record layer now calls the reporting layer's sanitizer |
| 20e | #215 | AC 15's byte fixture covers the shared body but not the three `prov_id_boundary` shims or three `PROV_PREFIX` constants, *where the rule's entire security content lives* |

**#214 is the one that matters**, and it is this spec's own lesson turned back
on it. `blueprint/025` extracted the claim replay precisely so the classifier
and the emitters could not disagree about "already claimed" — practice 9,
applied deliberately, and it worked. The *realize* replay got no such treatment,
so the same three-readers-one-rule shape survives in the file that was rewritten
to eliminate it. 20e is second: single-sourcing was pinned at the layer that was
hard to keep in agreement and left unpinned at the layer that decides the
boundary.

**Practice confirmed, and one added.** Practice 9 (one rule per structure) paid
again: extracting the claim replay is what let the emitter and the classifier
agree on "already claimed" — AC 6's *decided once* was unachievable with two
replays. The new one: **a retirement's Verify must sweep the tree for the
retired symbol, not just run the tests of the files it edited.** The plan's
retirement task verified with two per-script suites; both passed, and both were
the wrong question. That single gap produced a vacuously-green test, a
model-facing instruction still teaching a retired verb, and eleven stale
documentation sites.

## What the doc pass changed

A documentation cleanup, one `/jim:verify --since` run, two folds and two fixes.
Cheap work that produced three findings worth more than the cleanup.

1. **A stated scope is a claim, and this note proved it twice in one session.**
   #211 said fifteen sites. Re-derived mechanically — retired symbols extracted
   from the build's diff, each swept tree-wide, every hit classified — it is
   twenty. The five it missed include `README.md` (the repair-verb count) and
   `docs/features/blueprints.md`, both surfaces no pipeline phase refreshes.
   Then the `ordinal-single-source` judge found **#212 undercounted the same
   way**: nine deciding sites in three incompatible accepted widths, not three.
   That count had been re-stated here in the very pass that re-derived #211's —
   inherited, not measured. Practice 7 names this exact failure, and naming it
   did not prevent it.

2. **The engine found four violations, and none of them was B's doing.**
   `script-preamble`, `bash-source-relative`, `ordinal-single-source` and
   `blueprint-slot-reserved` all failed; all four are drift older than the
   emission build, surfaced only because `--since` classifies every violation
   `in-change` by construction. The prediction this note has made six times —
   *what a spec builds fresh is where its defects live* — held once more in the
   negative: the four criticals over B's own new code (`no-source-eval`,
   `ref-validation`, `relpath-validation`, `ledger-commit-discipline`) all hold,
   with the judges confirming the widened `move-spec-dir` gate is charset-closed
   and the lift's ledger interface fail-closed on both sides independently.

3. **The suite caught the fixer twice, and the second one is the keeper.**
   Fixing `bash-source-relative` by anchoring `metatest.sh`'s paths broke a
   deliberate contract — the sandbox tests `cd` into a temp dir precisely so
   `scaffold` writes there — and the broken run wrote a stray test file into the
   **production** `tests/` directory. Then adding `export LC_ALL=C` to
   `testlib.sh` stopped the provenance detector's en/em-dash range from matching,
   converting a real check into a silent pass. A harness must not impose a
   collation on what it runs; that is now pinned by its own case, asserting the
   two framework files export **no** locale, because gaining it is the
   regression.

   Both were caught by fixtures exercised through the front door, which is
   practice 5 paying out on the repair side rather than the build side.

4. **Three independent judges converged on a non-defect.** `run.sh:54`'s
   CWD-relative discovery was flagged by `tests-under-tests`,
   `bash-source-relative`, and noted again in passing — same mechanism each time,
   a mis-cwd'd run reporting `Ran 0 tests` at exit 0. It is deliberate: the
   runner's zero-discovery path is what keeps the sandbox tests from recursing
   into the real suite, and a test comment says so. Convergence of independent
   readers is evidence about a *mechanism*, not about whether it is a defect —
   the fixtures were the tiebreaker, exactly as practice 8 says for criticals.
   The residual hazard is real but narrower than three judges made it look, and
   it is the same shape as #153.

## What B′ changed

Sixteen items, all built, `175047c..HEAD` — 34 commits, +1654/−147 over 18 files,
suite 1099 → 1137. Reviewed **minor-drift**: judged against each issue's own
*Proposed action*, eleven of the sixteen are fully satisfied and the code is
correct wherever it was measured.

**The rule layer, decided once each.** `alloc_realize_fold` holds the duplicate-realize
decision and all three former readers consume it (`rz_of` is gone). Ordinal
legality is one predicate around one constant compared in exactly one function.
`alloc_group_has_records` counts a rename destination, so chained group renames
work at unbounded depth. The lift's batch decision moved out of the publish
builder's memory into `alloc_lift_states`, closing the cross-run idempotency hole
and repelling a reorder attack because the decision is log-anchored. Three
contradictions refused at the partition emitters, plus a sibling the issue never
named. The id-boundary memo warms once per token: 826 → 291 forks, 1.54×.

**What the review found is a build that under-reaches.** Nine of the sixteen
contracts were satisfied at the site the issue named and left unapplied at a
sibling nobody enumerated. `catch-up` alone appears three times — missing #209's
refusals, missing #218's warm, and absent from every door matrix drawn. It is
also the most serious finding in the cluster: `catch-up --apply` reissues an
ordinal a rename vacated, silently changing what a frozen citation dereferences
to, and the registry then reports clean. The classifier computes the fact and the
verb discards it. Pre-existing, and legible only because B′'s own new invariant
named the rule.

**And a second pattern, in the fixtures.** Six fixture claims from this cluster
were overturned by mutation testing the build did not run, and in every case the
tested half worked while the untested half was blind: the `PROV_PREFIX` pin was
mutation-tested on its shims and not its constants; the lift's reserved gate is
asserted "on either ordinal side" and exercised only on destinations; five of the
lift's nine guards survive deletion with all 1137 tests green, including the
cross-run source closure #207's own wording covers. `refused:destination-conflict`
is emitted from three sites and asserted nowhere.

The mechanical form of both lessons: **a contract names a site, and a site is not
a class.** Two of the review's four cross-cutting sweeps found what thirteen
contract-scoped investigators could not, by enumerating the rule's doors instead
of the issue's.

Eleven issues closed on this evidence; four stay open because their proposed
action is genuinely short. Fifteen new issues filed — one critical, four high.
*(An earlier statement here said three high; re-counted from the realized
priorities it is four — #226, #227, #228, #233. Practice 7, once more, on the
sentence announcing the practice's own findings.)*
Full record: `docs/notes/20260805-b-prime-review.md`.

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
region mismatch (#158) and a swallowed index-regen exit code (#151 item 3). Fixing one
file and leaving its twin is how the pattern spread in the first place.

Net effect: **eighteen new issues, zero net new specs.** C′ occupies C's slot;
nothing else in the grouping grows.

## Grouping: 2 remaining specs + 2 builds + 1 refactor + open items

A, C, C′, C′-fix, E, the pre-B build, B and B′ are done. **D and F remain as
specs**; two builds remain — **B″** (B′'s residue plus its foldable leftovers,
detailed at *Sequence* step 7) and the grouped hardening build.

### ~~Spec A — Rename-path correctness gates~~ · SHIPPED as `platform/011`
Ran as a spec rather than a build, and the fork was worth resolving that way: the
plan-phase security review found a Critical that changed the design (see above),
which a build would have had no gate to catch.

### ~~Pre-B build — settle the realize-row contract · #203 + #197 + #199 + #198~~ · DONE 2026-08-02

Shipped the same day it was scoped: `fc5468b..d9951dc`, seven commits,
1048/1048 → 1055/1055, zero pre-existing fixtures modified except the two that
asserted the batch-wide halt #203 ruled a regression — rewritten deliberately
to the per-identity contract. The issue-side realize path carried the **same**
batch-wide halt (its own comment promised "must not brick an unrelated
realization" while the return bricked the batch), so both kinds moved
together — the twin discipline applied before the twin was filed. All three
reproductions ran before belief (practice 8): an all-blocked batch, the
registry-level readback after a mixed apply, a triple-claimed key. The review
pass returned observations only: the sweep gained one more full-log pass for
the hazard line (small next to the derivation cost #201 tracks — noted so the
profile is not mis-attributed), and the issue-side preview shows a blocked
identity as its `-` ordinal since that surface's 2-field contract drops the
state column.

The record below is what the build was scoped to be, kept for provenance.

New at the ninth revision. A build, not a spec — the C′-fix shape, and the
criteria hold the same way: no security regressions in scope, forks settleable
in conversation, no blueprint write. Three of the four are defects in shipped
mechanism, observed in the first production spec realize (2026-08-01); none
needs B's grammar decisions.

- **#203 is why this sequences first.** The batch-wide halt is a regression
  against a contract the consumer still documents
  (`skills/spec/scripts/reconcile.sh` header: "Other identities in the batch
  are unaffected"), reachable through ordinary use — and the fix changes the
  realize row grammar (a per-identity `blocked` state, both consumers moving
  together). B's consumers inherit whatever this settles; settling it mid-B
  would move the contract under the spec consuming it. The detection half (a
  sweep class for the duplicated realize key) rides along, and feeds #200's
  class list.
- **#197** — untracked files are invisible to the realize citation sweep, and
  the post-sweep index regen resurrected a citation the same run had just
  rewritten. **#199** — the realized spec's own H1 keeps the bare provisional
  token, which matches neither sweep pattern. Same file family, same
  observation session.
- **#198 rides as the grant-narrowing minute.** The issue skill's wildcard
  jimalloc grant now auto-permits `catch-up --apply`, and B is about to widen
  the allocator's verb surface again. Narrow to `peek issue` before that
  happens, not after.

Run the review deliberately afterward — C′-fix's one cost was assuming the
build shape bought it.

**Bookkeeping alongside, not build work:** close #149 with a note (verified
this revision: the `sdlc` invariant now admits both identity states and names
the allocator; the `jim` half was deliberately dropped with the retired
blueprint — the body still demands a fold that is done, at a priority it no
longer carries). Close #120/#125 — duplicates of each other, and both
satisfied: `tests/jimalloc.sh` has been in platform's territory since C′-fix
repaired the map. Run the #189/#110 territory pass through the blueprint
surface whenever convenient — pre-B is mildly better, so B's territory-scoped
verify runs start without permanent stray noise. #188 lands whenever, ideally
before B's build phase: it guards exactly the review machinery B will rely on.

### ~~Spec B — Rename/redirect record emission~~ · SHIPPED as `blueprint/025` · reviewed **major-drift**
`blueprint`. All 18 ACs implemented, 15 plan tasks done, backfill executed. Its
five assigned issues (#113, #143, #152, #154, #202) and both scoping riders
(#84, #123) are delivered — #84 and #123 died structurally with the tree-scan
retirement rather than being patched. See *What `blueprint/025` changed*. The
review's verified AC failures and the sensor's violations ride #205–#213; the
original framing below is kept as the record of what B was scoped to do.

**Unblocked** — A closed its three preconditions. Also owns the two
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

**Pre-spec analysis (2026-08-02, ninth revision).** A context pass ahead of
scoping, verified against the working tree rather than this note's dated
anchors. What it found, and what the interview must settle:

- **The read path is done waiting; the write path does not exist.** The frozen
  grammar is parsed by every reader — resolver replay, alias map, the shared
  fold (rename sources counted), classifier, sweep — and the allocate encoders
  are still the only encoders. B's fresh code is exactly: rename encoders, a
  partition batch builder over `alloc_publish` (the one-CAS template exists;
  the reconcile builders are the pattern to copy), and the realize lift.
  Practices 5–9 apply to precisely that list.
- **Rename records have no `<who>` slot.** Allocates end `<date> <who>` — which
  is where the `jim-seed`/`jim-catchup` provenance markers live — while renames
  end at `<date>`. Extending the frozen shape is a grammar change every parser
  rides; not extending it ships anonymous rename records, and the retired-`jim`
  backfill batch is exactly where provenance will be missed. A fork no prior
  revision named.
- **`op=rename` ledger events carry no `moved=`** — group-rename records must
  derive from `old=`/`new=` tokens, not a pair list. And the ledger's `moved=`
  parser gates ordinals at exactly three digits while the registry accepts
  3–15, so the backfill lift must reconcile the two widths.
- **The G6 citation clause is mostly built already.** Since #113 was filed,
  `sdlc/017` shipped the realize citation sweep and the partition side has its
  remap-driven `rewrite-refs`. B's citation work is verify-and-narrow, not
  build; the live gaps are #197/#199, which the pre-B build takes.
- **#84 and #123 ride one decision B already owns** — #113's
  two-next-id-surfaces constraint. Converge `/jim:partition` onto the allocator
  and both die; keep the tree-scan path and #123 needs its explicit
  `next-id spec <group>` form while #84 needs its `maxid=` rename arm. Deciding
  the surface without deciding them would split the decision, so both move here
  as scoping riders (from the hardening bucket and from outside the cluster
  respectively).
- **#200 is consulted, not absorbed.** B's grammar work must not foreclose a
  precedence/tombstone record kind — one design decision recorded in B's spec;
  the repair procedure stays #200's.
- **#155 is fork-dependent.** If the realize lift mints a `P-`-bearing record
  kind, the triplicated provisional grammar enters the registry parser for the
  first time and single-sourcing becomes load-bearing — it rides B. If B keeps
  `P-` out of the frozen grammar (the fold-safety argument in #143 points that
  way), it stays in the hardening bucket.
- **Moved out:** #189 to the map pass (bookkeeping, not spec work); #203 to the
  pre-B build. #106 gets one sentence in B's rationale — only its
  reference-repointing half is adjacent. #107/#186 stay hardening riders on
  files B happens to edit.
- **One spec, not two.** The straddle is real — emitters and grammar in
  `platform` territory, the partition consumer in `blueprint`, the realize path
  in `sdlc` — and the tempting split (a platform grammar spec consumed by a
  blueprint emission spec) recreates the exact failure `platform/012` paid two
  criticals for: readers of one structure applying different rules. Emitter,
  classifier, and resolver semantics are one decision surface (practice 9), so
  they stay in one spec. C′ set the precedent for a home group with declared
  cross-group work: home `blueprint`, platform writes named — let the
  assignment advisor confirm.

Carried in unchanged: the two resolver decisions pre-framed on #113
(source-known gate with disclosure; per-side width gating — take together), the
refuse-vs-carry fork with split and merge agreeing (#152/#154), the backfill
ship-with-emitter-vs-one-time-repair decision, and A's consumer obligations
(redirect refusal is retryable, exhaustion is terminal, the returned group is
authoritative).

### ~~B′ — finish `blueprint/025` · a build, not a spec~~ · SHIPPED · #205–#219 + #138 · reviewed **minor-drift**
New at the eleventh revision. Sixteen items: the nine B's review filed, the six
that rode nothing (above), and #138 pulled out of the hardening bucket because
it and #212 are one decision at two scopes. Two of the sixteen shrank at the
twelfth revision — #211 is 19-of-20 done, and #206's output-hygiene half gained
one more edge from the grounding run — and two grew obligations rather than
items: #209 and #212 each now carry a folded invariant to restore. Alongside
them sits one task that is not an issue at all: the contract-edge phase the
grounding run skipped.

**It rides B's slot.** Every one of the fifteen records `blueprint/025`'s own
unmet or regressed contract, so by the rule this note adopted it is that spec
finishing, not new work. The remaining-spec count stays at two.

**Run it as a build.** The three criteria that sent C′ to a spec and C′-fix to a
build resolve the same way C′-fix's did:

1. **One security regression, already localized.** #205 is a new filesystem
   probe on an unvalidated component — real, and rated `low` by the review
   because no gating bypass results and the probe is read-only. Its `critical`
   grade is the *invariant's* criticality, not the finding's severity. There is
   no threat-model surface for `/jim:sec` to open.
2. **The forks are settleable in conversation** — with one exception, below.
3. **The blueprint writes go through their own surfaces.** #211 needs
   `/jim:blueprint platform` and `/jim:arch`; C′-fix established that this is not
   a reason to widen the ceremony.

**One escalation trigger, and it is real.** #209's first contradiction — a
vacated ordinal re-minted — collides with the split protocol, which densifies
fresh children to `001..N`. Refusing the re-mint means a split into a group name
that was previously retired cannot densify from `001`. If that turns out to
reshape `/jim:partition split` rather than just gate the emitter, B′ becomes a
spec. Decide this **first**, before writing anything.

**Resolved without escalation.** `renumber-map` now takes `<child>=<start>` per
fresh child, fed verbatim from `peek spec <child>` — the merge-map precedent
applied to split. Required rather than defaulted, so a forgotten peek fails at
map time instead of at Close. A never-seen name still peeks to `001`; a retired
name resumes above its high-water. The protocol was not reshaped, so B′ stayed a
build. Proven load-bearing by counterfactual: on a registry where `checkout/001..012`
were retired, a hard-coded `001` map is refused as "vacated by an earlier rename"
where the peek-fed `013` succeeds.

One thing this fork did not anticipate, found by the review: the start gate is
still `^[0-9]{3}$`, so a group past 999 peeks to `cart/1000` and `renumber-map`
refuses the value the skill instructs an operator to copy verbatim. B′'s own
width widening and its split fix disagree above 999. Tracked.

**Sequence inside B′ — correctness first, because these write unrecoverable
contradictions to a shared append-only branch through the documented Close:**

1. **#207, #209, #213, #214.** One surface (`partition-batch`, `lift`, the two
   replays) and one question: *what establishes a claim, and what vacates one.*
   #209's `a→X`+`a→Y` case makes a source permanently unresolvable; #213 blocks
   the rename Close for any group already renamed once; #214 is the realize
   replay's version of the same disagreement. **Do not split these** — that is
   the exact class `platform/012` paid two criticals for, and the reason B
   extracted the claim replay in the first place. Take
   `skills/partition/SKILL.md:366` from #211 in this pass too: it is one line,
   and it teaches an agent mid-partition to call a verb that now returns rc 2.
2. **#212 + #138 + #206's AC-17 floor.** One bound, three files, six inlined
   predicates, no test asserting any two agree — and the three sites do not
   accept the same set, since the registry has no lower bound while
   `jimledger.sh:689` floors at three digits. Settle the floor semantics and
   single-source in one pass; this is the seam the note has called load-bearing
   since the seventh revision.
3. **#205, #206's remainder, #208, #215, #216, #217, #218, #219** — gates,
   fixtures, hygiene. #215 belongs near #212: both are single-sourcing pinned at
   the wrong layer.
4. **#210** — the vacuous test, the orphaned headers, and the four fixture gaps.
   Last because it is the cheapest and the least coupled. *(#211 left this step
   at the twelfth revision: 19 of its 20 sites are corrected, and the survivor —
   `docs/features/blueprints.md` — is held for its own branch rather than B′.)*
   *(That 19-of-20 count is wrong, and the review disproved it: `ARCHITECTURE.md:395`
   was claimed fixed but the remediation commit edited that line and left the
   stale clause on it, and `README.md:62` and `ARCHITECTURE.md:393` are missed
   siblings of sites that were fixed. `WORKFLOW.md` has no occurrence of `lift`
   at all — the clearing check was "carries no occurrence of any retired symbol",
   which cannot see a missing new verb.)*

**Two invariants are folded open, and closing them is part of B′'s definition of
done.** The twelfth revision weakened `ordinal-single-source` and
`blueprint-slot-reserved` in the `platform` blueprint so they would stop
asserting what the code does not do. Each fold is a **waypoint**: #212 and #209
carry the pre-fold text verbatim and the obligation to restore it through
`/jim:blueprint`, at least as strong as it was. Both should come back *stronger*
— a restored claim can rest on a fixture rather than on convention, and each
pre-fold text contains a clause that must not survive (one confesses
agreement-by-convention; the other names the retired `next-id` mechanism). **B′
is not done while either invariant still reads as folded.**

**Both restored** through `/jim:blueprint`, both stronger than pre-fold on the
clause that mattered, and both pre-fold confessions retired. The obligation is
discharged. The review qualified the result in two ways worth carrying:
`ordinal-single-source` now *overstates* — it claims the fixture "fails when a
new width literal appears in any script", and the guard is range-literal-only,
blind to exactly-N literals, awk `length()`, `${#x}` comparisons, and any file
whose basename collides with its exclusion list. The fold understated the code;
the restoration overshoots it. And `blueprint-slot-reserved` gates two of the
four write paths the fold explicitly named, dropping the disclosure of the other
two. Both are tracked as fixes rather than re-folds — folding correct rules down
to match incomplete code is the cycle this note keeps paying for.

**One task carried in that is not an issue: run the contract-edge phase.** The
grounding run skipped it, and its existence conditions held — the map has a
contract graph, it names `platform` as provider to all three other groups, and
the change touched provides-side code in all three CLIs. It is the one rung that
would have surfaced cross-group impact, and nothing else in B′ covers it.

**It ran, and it was worth running.** 14 edges, 310 `CROSS-REF` facts, every fact
landing on a declared edge, coverage 4/4, ten judged sides all holding, zero
violations — recorded project-tier with `skipped=18` naming the unexamined
remainder. The post-build review then ran it again change-scoped and it earned
its keep the second time: three of four affected edges came back **breaking** on
their consumer side. The 999 collision above is one of them, and the sharpest
finding in the cluster came from it — B′'s widening of `move-spec-dir` *removed
the loud refusal that was masking* `jimpartition.sh:1566`'s narrower gate, so a
representable spec is now dropped from a merge map silently, at rc 0. That
failure mode is introduced by the change, not merely exposed by it, and no
single-group rung could have seen it.

**Run the review deliberately**, and land **#188** before the build phase — it
guards exactly the machinery B′ will lean on, and it has been "whenever, ideally
before B" since the ninth revision without landing. The grounding run is the
argument: its judge fan-out was suppressed by a standing session directive, ran
only after an explicit authorization, and nothing in the engine's own output
would have distinguished the suppressed run from a clean one. Second recorded
instance, and both were caught by a person rather than by a mechanism.

**#188 did not land, and there is now a third instance.** B′'s own build ran 17
subagents unsuppressed on Fable 5; the review that followed ran on Opus 5, the
model the directive targets, and its fan-out happened only because the operator
authorized it explicitly and unprompted. Three for three caught by a person. The
review needed 17 investigators against a `review_fanout_cap` of 10 — so the cap
was also raised by hand, and `jimconf.toml` still reads 10.

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

### ~~Spec C′ — Finish `sdlc/017`~~ · SHIPPED as `sdlc/018` — **AC 12 unmet**
`sdlc`, with allocator-side work in `platform`. Eleven of its fourteen issues
closed; #149, #151 and #134 stay open (see *The cluster*). See *What C′ changed*.
The residue is **C′-fix** below — a build, not a fourth spec.

The record below is what C′ was scoped to be, kept for provenance.

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

### ~~C′-fix — a build, not a spec~~ · SHIPPED — **AC 12 holds** · reviewed
All sixteen closed, plus #151 and #134; six new issues (#184–#189). See *What
C′-fix changed*. The build shape was right — no `/jim:sec` gate was needed, the
forks settled in conversation, and the two blueprint writes it did turn out to
need went through their own surfaces (`/jim:blueprint --since`, `/jim:arch`)
rather than becoming a reason to widen the ceremony.

**The one cost of the build shape was the review.** Running as a build meant no
spec directory, so `/jim:review`'s normal flow had nowhere to land and the build
shipped unreviewed. Reviewed after the fact, it returned 21 findings — **nine of
them regressions from the build itself**. The build shape remains right for the
same three criteria; what it does not buy is the review, and that has to be run
deliberately rather than assumed away. Disposition: five fixed, seven filed
(#190–#196), six left. Detail in `docs/notes/20260801-c-prime-fix-handoff.md` § 4.

The record below is what C′-fix was scoped to be, kept for provenance.

The four findings that leave AC 12 unmet, plus C′'s smaller review residue.
**This is a hardening build**, and it is worth saying why, since the same three
criteria sent C′ the other way:

1. **No security regressions.** C′'s review found zero, and containment on the
   widened sweep was verified intact. There is nothing for `/jim:sec` to gate.
2. **Two small forks, not three genuine ones** — whether canonicalization's
   ordinal-width narrowing is deliberate (#175), and one width policy across the
   predicate and `next-id` (#181). Both are settleable in a sentence at build
   time; neither reshapes a design.
3. **No blueprint write.** The `sdlc` fold already landed at C′'s completion gate.

The core four: **#171** nesting guard (critical — the one that strands a
realization), **#172** `--apply` from a subdirectory, **#173** sweep roots,
**#174** issue-index regen abort. Then the residue: **#175** width narrowing,
**#176** path-arity help, **#177** unchecked awk exit, **#178** the two fixtures
the plan named and the build skipped, **#179** the spec-template comment trap,
**#180** symlink write-through, **#181** invariant edges, **#182** issue-side
resolve padding, **#183** `mv-spec` prose.

Closing #171–#174 is what makes AC 12 hold and lets #151 and #134 close.

**Do not run this as C″.** The rule this note adopted — an issue recording a
shipped spec's unmet contract belongs to that spec — is about *spec count*, not
about ceremony: it says the work rides in C's slot, not that it must wear a spec.
C′ needed a spec for reasons that no longer apply.

### Spec D — Batch-CAS candidate-batch allocation (§7a rework) · #127
Collapse an end-of-run candidate batch (8 surfacing skills) into one CAS instead
of N sequential pushes. Cross-group blast radius (sdlc + blueprint + issue) and
its own all-or-nothing-vs-partial failure-semantics decision. Independent.

### ~~Spec E — Registry integrity & drift~~ · SHIPPED as `platform/012` · reviewed
All five charter issues closed (#116, #130, #136, #185, #121's remaining half);
three filed (#201–#203). Review **major-drift**, 15 findings, two criticals in
freshly-written code — both fixed before the ledger closed. See
*What `platform/012` changed*.

Every pre-spec prediction below held, which is the useful part of keeping the
record: the repair machinery *was* `alloc_publish` plus a builder; the sweep's
real design surface *was* its non-coverage report (it grew a fifth class —
records too malformed to identify — because a degraded record appeared in no
number anywhere); the exit-code fork *was* the load-bearing one; the blueprint
invariant landed at the completion gate as `registry-tree-consistency`; and the
retired-`jim` backfill stayed with Spec B while the sweep names the group
uncovered. The one prediction that missed was the cost model — see item 6 of
*What `platform/012` changed*.

The record below is what Spec E was scoped to be, kept for provenance.

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
nothing else does. *(Raised to high on the issue, 2026-08-01.)*

**#144 split, and its urgent half was not E's — that half is now done.** The
one-time alignment landed from the host on 2026-07-31: two hand-appended records
carrying each spec's own issuance date, `b1aedca..19c4328`. Note the mechanism
this note first assumed — `seed --apply` — does **not** work: seed is
bootstrap-only and refuses a log that already has records
(`jimalloc.sh:1707` as of the seventh revision). That refusal is precisely the
hole #130 fills, and it is
the third independent piece of evidence in this note that #130's `low` priority
is wrong: without an incremental catch-up verb, every future instance of this is
a hand-edit of a coordination branch.

The *standing* half — detecting and repairing this class of drift automatically —
is E's charter and stays here. E also inherits the retired-`jim` instance
recorded under Spec B: emitting records fixes future splits, backfilling the 52
ordinals the 2026-07-25 split already vacated does not follow from it.

**Pre-spec analysis (2026-08-01, seventh revision).** A context pass ahead of
scoping; the per-issue corrections live as dated addenda on #116, #130, #136
and #185. What the interview must settle, and what it can lean on:

- **The repair machinery exists.** `alloc_publish` already gives any batch
  writer the in-loop erosion re-check, tier CAS, bounded retry and baseline
  arming; the catch-up verb reduces to a new builder plus four recorded
  semantics decisions (date stamp, provenance marker, empty-group rule,
  conflict handling — on #130).
- **The sweep's real design surface is its non-coverage report.** Four
  artifact classes are legitimately recordless (reserved slot, pending
  provisionals, retired groups, rename-source-only ids — on #116); practices
  6 and 7 make naming them the acceptance criterion. The one genuine
  structural fork is the detect/repair boundary: #116's "adopt" clause *is*
  #130's append.
- **Placement:** allocator verbs in platform territory with a reconcile-style
  thin wrapper is the precedent; a `/jim:verify` ride-along via a `registry:`
  check is possible but collides with verify's operator-registry vocabulary
  and its exit-code mapping (0 / non-zero / crash → holds / violated /
  failed, vs jimalloc's rc 1 doubling as "unreachable"). Design exit codes so
  drift stays distinct from could-not-check.
- **The platform blueprint has no invariant for E's property** — nothing
  covers append-only growth, erosion, or only-door, so `/jim:verify` is blind
  to exactly what E enforces. Fold one in at E's completion gate.
- **The retired-`jim` backfill has a mechanical source** — the ledger's
  `moved=` pairs, which are B's frozen `spec rename` shape, not catch-up
  allocates (detail on #113). The lean E answer is the sweep naming the group
  known-uncovered and the backfill riding B; decide rather than default.
- **E is almost entirely new code** — two detectors and a writer verb, the
  exact profile practices 5–7 exist for: fixture the wiring, mutation-test
  new guard fixtures before trusting them, run the fan-out before the ledger
  closes and name it if it did not run (#188).
- #136 is wider than filed (two spec-side last-wins siblings, anchors on the
  issue); #185 is a one-function fix in `alloc_origin_tip` covering both
  callers.

### Spec F — `issue_placement` / issue content location · #126
Where a filed issue's *content* lives: central branch vs on-branch, the
`issue_placement` config key, the disclosure surface (centralizing publishes
bodies earlier and wider), and reconciliation with the VISION non-goal that issue
capture is a discovery artifact, not a coordination primitive. The one clause of
#111 that did not ship. Genuine undecided design → its own scoping.

### One grouped hardening build (11) — no spec
Localized fixes, each a testable one-to-few-line change with a test per fix.

(#123 fell out entirely: B retired the tree-scan path, so the explicit
`next-id spec <group>` form this bucket held as a fallback has nothing left to
disambiguate. #84 died the same way. Neither needed the two-next-id-surfaces
decision resolved — the surface itself is gone.)

Three from the `008`/`009`/`010` reviews:
- #119 retry the unreachable-detection path + generalize the exhaustion message
- #132 `new.sh` mixed-pin (`--slug` XOR `--num`) registry/on-disk skew
- #117 `moved-to` tombstone guarding coordination-branch relocation

*(#121's reserved-slot half moved to Spec E on 2026-08-01 — its sweep flags
`<group>/000` records as drift while its catch-up reuses the derivation that
could still mint one, so detect and derive settle the rule together.)*

*(#133 and #134 moved to C′ — their spec-side twins are C's, and the two must be
fixed in one pass or the pattern keeps spreading.)*

One from `sdlc/017`:
- #153 `run.sh` honors only its first filter argument, so a multi-filter Verify
  command silently checks less than it claims — which is how C's plan carried a
  task whose second half never ran

*(#155 left this bucket by resolving its own fork. It was parked here as "rides
B if the realize lift mints a `P-`-bearing record kind"; `spec realize` does, so
B single-sourced the grammar under the `SYNC:` discipline and #155 closed
2026-08-03. Its residue — the fixture stopping at the shared body — is #215, in
B′.)*

Three from `platform/011`:
- #140 fixture the `allocate spec` acknowledgment path (the consent gate shipped
  with only its `peek spec` half fixtured — behavior verified by hand)
- #141 fixture the terminal exhaustion refusal (one record reaches it)
- #142 memoize the id-validation boundary (~56ms/record of forks; measured linear,
  and log length is attacker-influenceable). Note B *regressed* this at the sweep's
  call sites — the memo no longer warms across passes (#218, in B′)

Three from C′-fix:
- #184 fixture `spec-ordinal-holder`'s `--root` (the option exists so a gate never
  reads a different tree than the one it guards; nothing asserts that today, and
  the guard it serves already shipped one defect its fixtures did not cover)
- #186 reconcile literal-pathspec use between the commit and rename verb families
  — `--` stops option parsing, not pathspec magic, and `valid-relpath` does not
  reject a leading `:`; establish reachability before choosing the fix
- #187 refuse the reserved slot in the generic `path spec` composer, or record
  that the guarantee is scoped to the dedicated arm

One from `platform/012`:
- #201 the registry sweep's per-file frontmatter cost — measured, not guessed:
  ~6.9 s of a ~14 s sweep is `alloc_seed_derive_issues` forking `sed` per field
  per file, against 167 ms in the two classification cores. It is a bootstrap
  path that now runs on every CI check, which is what makes it worth fixing.
  Distinct from #142; neither closes the other

**#138 left this bucket at the eleventh revision, upward.** It was already the
load-bearing item here — C′-fix's `next-id` change made it a sixth inlined site,
and a `/jim:verify` judge scored `ordinal-single-source` **partial** on exactly
that. B then found a *third file* holding the same bound in a third spelling
(`jimledger.sh:689`), and made the bound decide, per side, whether a
destination's establishing claim survives. So it is no longer a leaf fix with a
test: it is one decision surface spanning three files, it belongs with #212, and
both are in B′ step 2.

What is left in this bucket is genuinely leaves — which is the first time that
has been true.

(#124 closed with A; #122 is below.)

### One small refactor — #122's remaining half
Factor the shared land step (tier select → CAS → arm baseline) so the allocation
path and `alloc_publish` share one implementation, generalizing the commit
builder over one-or-many blobs. Not a correctness gap — guarantees are equivalent
today — so this can park indefinitely. Kept out of the hardening build because
it touches the allocation path rather than a leaf.

### Decisions + docs (3 open, 1 closed) — no spec
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
- **#200** — the sanctioned repair path for registry-internal contradictions.
  **No longer speculative** (eleventh revision): B's grammar half landed without
  foreclosing a precedence/tombstone kind, and the *demand* arrived with it —
  #207 and #209 are contradictions the shipped emitters actually write, and
  #209's re-minted ordinal is unrecoverable on an append-only branch. The class
  list now holds #203's duplicated realize key, #207's double rename source,
  #209's re-mint and reserved-slot destination, and #214's duplicated realize
  key. Settle it inside B′'s scoping rather than after it.

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

**3. ~~C′ — finish C.~~ DONE** — `sdlc/018`. The halt is no longer bypassable
(#150, #156 closed), the path helper resolves both identity states (#146), and
the `sdlc` blueprint no longer contradicts its code (#149's live half). Shipped
**major-drift** with **AC 12 unmet**; see *What C′ changed*.

**3a. ~~C′-fix — make AC 12 hold.~~ DONE** — a build, no spec. The nesting guard
reads a copied rename as landed (#171), `--apply` refuses off the worktree top
rather than silently discarding its own preview (#172), the sweep's roots
normalize (#173), and the index regeneration can no longer be skipped (#174).
`mv-spec` retired. AC 12 holds; #151 and #134 closed with it. See *What C′-fix
changed*.

**4. ~~E — the baseline.~~ DONE** — `platform/012`. The registry can now be
checked (`sweep`) and repaired (`catch-up`) without hand-editing the shared
branch, duplicate claims are refused on the read path instead of resolving to
whichever record came last, and the advertised origin tip crosses the id boundary
like every other untrusted token. The property this step existed to buy — a flow
that cannot hand out an id the project already owns — is now *verifiable* rather
than argued: the sweep answers it on demand, and `/jim:verify` runs it as a
configured check. See *What `platform/012` changed*.

**E grew by one from C′-fix:** #185, the origin registry tip read from
`git ls-remote` and interpolated into a git argument without crossing the id
boundary its siblings all cross. It is the allocator's one unvalidated remote
input, which puts it in E's territory rather than the hardening bucket's.

Two obligations carry in, in the spirit of practice 6: E writes an only-door
sweep and a catch-up verb, both of which are *detectors*, so each needs to report
what it did **not** cover as loudly as what it found.

**4a. ~~The pre-B build + bookkeeping.~~ DONE 2026-08-02** — same session as
the ninth revision. All four shipped with fixtures at every level, the two
existing halt fixtures deliberately rewritten to the restored contract, and
the issue-side twin of #203's halt fixed in the same pass. #149, #120 and #125
closed as bookkeeping. The #189/#110 map pass landed the same day through the
project-tier map update (`e2a5635`): `tests/specreconcile.sh` declared under
`sdlc`, `tests/scripthygiene.sh` under `platform` (decided over the
recorded-exception alternative — platform already holds the project-wide
script rules, and its blueprint's Structure names the file), reconcile clean
at 22 edges / zero findings. Suite 1055/1055; see the Pre-B build section's
shipped note. The original scoping follows.

#203 first:
the batch-wide realize halt is a regression against a contract its consumer
still documents, reachable through ordinary use, and the fix changes the
realize row grammar — settle that contract before B builds consumers on it.
#197 and #199 ride in the same pass (same file family, same
first-production-realize observation), and #198 is the grant-narrowing minute
before B widens the allocator's verb surface again. Alongside, as bookkeeping:
close #149 (the `sdlc` fold verified live, the `jim` half deliberately
dropped), close #120/#125 (satisfied duplicates), and run the #189/#110
territory map pass through the blueprint surface. #188 whenever, ideally
before B's build phase.

**5. ~~B, next.~~ DONE 2026-08-02 — shipped as `blueprint/025`.** The
vacated-ordinal floor described below stopped being a live defect the moment the
backfill landed: `peek spec jim` answers `053`, and it does so from the
registry's own rename records rather than from a ledger event a fresh clone may
not share. The split-versus-repair division below — "emission is B's, repairing
the instance that predates it is E's" — resolved differently than planned: B
built one **lift** mechanism and ran it over existing history, so the backfill
*is* the emitter's own repair verb rather than separate work. `jim/001`–`jim/052`
are recorded. Everything below is the pre-ship framing, kept as the record.

Its allocation-relevant piece remains the vacated-ordinal floor,
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

**5a. The bookkeeping pass. DONE 2026-08-03.** B's eight closed with
resolutions, the six untracked findings filed as #214–#219 and realized onto
contiguous ordinals, index and sweep clean, suite 1097/1097. Not build work —
but it is what makes the sequence below trustworthy, since every step of it is
stated in issue numbers.

**6. ~~B′ — finish B.~~ DONE — built 2026-08-04, reviewed 2026-08-05,
minor-drift.** All sixteen items shipped (`175047c..68c2bdb`, 34 commits, suite
1099 → 1137); the #209 re-mint fork resolved without reshaping the split
protocol, so it stayed a build. Eleven contracts fully satisfied and closed;
#208, #211, #215 and #216 stay open on their own short remainders. The review's
finding is systematic under-reach — nine contracts satisfied at the named site
and left unapplied at siblings nobody enumerated, `catch-up` that sibling three
times — plus six fixture claims overturned by mutation testing the build never
ran. Fifteen filed as #220–#234. See *What B′ changed* and *Grouping* → B′.

**7. ~~B″ — finish B′, and land #188 first.~~ DONE — built and shipped
2026-08-05.** The fifteen (#220–#234) plus the
three foldable leftovers (#208, #215, #216). It rides B's slot by the same rule
B′ did, and the build shape holds the same way: every security-adjacent fix is
a narrowing, and the blueprint writes go through their own surfaces.

**#188 goes first, actually landing this time.** It has been "whenever, ideally
before the build phase" since the ninth revision; there are now three recorded
suppression instances, all caught by a person, and it guards exactly the
fan-out machinery every step below leans on. The same pass sets
`review_fanout_cap` explicitly in `jimconf.toml` (the key is unset today; B′'s
review needed 17 investigators against the default 10) and files practice 10's
gate as an issue — the findings-vs-dispositions arithmetic is the countable
practice the thirteenth revision argued should be adopted next.

**#188 landed 2026-08-05, on its fifth time of asking.** Each delegating surface
now names an undispatched fan-out in its own existing degradation vocabulary, and
both `/jim:verify` and `/jim:review` carry `undelegated=<n>` on their finished
events. The item the issue merely asked jim to *consider* — refusing to report a
clean result — turned out to be the cheapest part, because verify's outcome
vocabulary already had the right home: `failed` means *could not check*, so an
undispatched judge is `failed` with reason `undelegated` and can never read
`holds`. No new outcome, no new knob, no `jimledger.sh` change.

Two doors the issue's own list did not name, found by enumerating the rule's
doors rather than the issue's: **`/jim:issue insights`**, where a suppressed
dispatch does not thin the verb but *violates* the `issue` blueprint's declared
`insights-capability-boundary` (`high`) — it now refuses and stops rather than
reading bodies in a `Write`-capable context; and **`/jim:partition`**, whose "the
cap bounds concurrency, never coverage" left it with no concept of reduced
coverage at all. That is B′'s review lesson applied on its first outing, and it
paid on the first try.

Pinned by `tests/fanoutdisclosure.sh` (3 cases, 9/9 mutations red) rather than by
convention — and the counter case sweeps **by rule, not by site**: a *new*
recitation of a finished event that omits the counter fails, which pinning the
known sites would not have caught. The remaining two items of this bullet —
`review_fanout_cap` and practice 10's gate — did not ride it. The cap is a cost
lever that is the operator's call, not a defect.

**Two forks to settle before code**, the same way the #209 fork was:

- **#229's refuse semantics** — when `catch-up` meets a tree directory whose
  ordinal is a rename source, is that a blocked drift class demanding manual
  repair, or something catch-up may act on? Refusing leaves the repair
  question standing, so consult #200's class list in the same conversation —
  B′ refused the contradictions at the emitters and settled no repair path.
- **#228's above-999 story at the partition layer** — the canonical bound is
  already decided as `{3,15}`, so this is likely widening `jimpartition.sh`'s
  start gate and making `merge-map` refuse loudly instead of silently dropping
  a representable spec at rc 0. If it reshapes the split protocol instead,
  that is the escalation trigger that makes B″ a spec.

**Both forks settled 2026-08-05, before code, over a four-investigator evidence
pass. B″ stays a build** — #228 does not reshape the split protocol.

**#229 — refuse; and the issue's own two proposed actions are both wrong.** The
mechanism is an intersection nobody named. With the directory still sitting on
the vacated ordinal, `alloc_classify_spec` emits **both** `MISSING` (`:1698`,
keyed on the id having no live claim) and `RENAME-SRC` (`:1714`) for the same id
— and it is `MISSING` that catch-up harvests. `RENAME-SRC` alone is the *healthy*
post-rename state, which is exactly why the sweep excludes it from `drift_rows`
at `:2916`. So adding it to `CU_BLOCKED` would wedge `catch-up` on every registry
that has ever had a rename, and filtering `want_spec` by it repairs silently at
rc 0 — the shape practice 6 forbids. The drift is the *intersection*, a tree
directory occupying a spent ordinal, and it needs its own class.

**The #200 consultation resolves the other way than the fork assumed: this is not
a #200-class problem, and refusing leaves nothing standing.** #200's classes —
`duplicate-ordinal`, `duplicate-id`, `reserved-slot`, `unreadable-record`, plus
the duplicate realize key and the realize `CONFLICT` — are all registry-*internal*:
two records contradict, an operator must pick a winner, and repairing one needs a
corrective-write primitive the grammar does not have (seven encoders, zero
tombstone / precedence / revoke). A directory on a vacated ordinal is
tree-vs-registry drift where the registry is internally consistent and *right*.
Its repair is a filesystem action — move the directory to the rename destination,
or renumber it above the group's peek — and `resolve` already follows rename
chains to name that destination. Refusing therefore routes to an instrument that
already exists rather than deferring to one that does not, and #200's scope is
untouched.

**Scope: the rule's four doors, not the issue's one.** `catch-up` × spec, ×
issue (byte-identical at `:3041`–`:3045`), × group (`alloc_group_present:2015`
matches only a literal `group allocate` record, consulting neither the alias map
nor `alloc_group_has_records`, so a renamed-away name takes a fresh claim), and
`lift`, which declares and fills `spent` at `:3673`–`:3674` and never reads it —
safe today only as a side effect of `destination-not-established`. That is
`catch-up`'s third consecutive appearance as the door an id-coordination fix
skipped.

**#228 — share the `{3,15}` bound.** Widening is purely a validator change: the
verb sequence, the tab-delimited `MAP` grammar and the human gate are all
width-agnostic, `%03d` is a minimum field width rather than a cap,
`renumber-map` already sorts numerically at `:1488`, and the pipeline's producer
(`peek`) and its consumer (`partition-batch spec`, via `alloc_valid_ord`) both
accept 15 digits already. The 999 cap is a third, undocumented refusal mode
sitting between a wider producer and a wider consumer — which is why the
composition failure was invisible from either side.

**Eight gates, not six**, and the two the issue missed are the dangerous ones.
`jimpartition.sh:1567` is a fixed three-character slice (`onum="${bn:0:3}"`), so
widening `:1566` alone would truncate `1000-foo` to `100` and emit a *wrong* MAP
row — silent corruption, strictly worse than the silent drop being fixed. And
`merge-map`'s scan at `:1563` is a bare `LC_ALL=C` glob credited as pre-sorted,
which holds only while every basename is three digits.

**The re-divergence fix is the fixture, not a shared verb.** `tests/jimfile.sh:1556`
greps a comma-bounded `\{[0-9]+,[0-9]+\}`; `jimpartition.sh` spells `{3}` without
a comma, so the file was never *exempted* from the width guard — it is invisible
to it. `ARCHITECTURE.md:390` already names this seam as the one place in the
ordinal machinery where a divergence would not be caught structurally. Teaching
the guard to see uncomma'd spellings closes it at zero runtime cost; routing
`:1566` through a `jimfile.sh` predicate instead would put a subprocess fork in a
per-directory scan loop, in the same pass that is fixing a fork-amplification DoS
(#233).

**B″ SHIPPED 2026-08-05** — `a9feede..da3ff7b`, 20 commits, suite 1148 → 1182.
All nineteen items closed (#208, #211, #215, #216, #220–#234), both pre-code
forks settled on evidence before any code, and the build stayed a build.

**Practice 10 applied to B″ itself**, since this is the pass that filed its gate.
Twelve findings, twelve dispositions, no remainder:

| Disposition | Count | What |
| :--- | ---: | :--- |
| **filed + fixed** | 2 | the never-reissue rule's two unnamed doors — `catch-up` × group, and the lift's unread spent set |
| **filed, open** | 2 | practice 10's own gate; 95 artifact citations in script comments |
| **fixed inline** | 6 | `UNREADABLE` undocumented in the row grammar · `scripts/` unswept for the locale export · the stray sweep blind to nested paths · the width sweep rooted at one production root · a leaked `read` target in `render.sh` · a stage list re-spelled instead of named |
| **folded** | 3 | `script-preamble`, `ordinal-single-source`, `tests-under-tests` — text overstating its mechanism |
| **map** | 1 | two test files no group's territory claimed |

**Three findings came from the verify judges, not from the issues** — and all
three were gaps in sweeps this same session wrote *and mutation-tested*. That is
the sharpest lesson of the pass and it refines practice 7: mutation testing
proves an assertion **discriminates**; it cannot tell you the **corpus was too
small**. A sweep that is green because it looked in too few places is
indistinguishable, from the inside, from one that is green because the corpus is
clean. Only a reader who does not share the author's map of where to look can
tell those apart — which is the concrete argument #188 was making in the abstract.

**The pre-code forks paid for themselves.** #229's two proposed actions were
*both* wrong — one would have wedged `catch-up` on every registry that has ever
renamed, the other repaired silently at rc 0 — and the real defect was an
intersection nobody had named. #228 undercounted its gates by two, and the pair
it missed would have turned an omission bug into a corruption bug. Neither would
have been caught by implementing the issue as written.

**Then sequence by the rule's doors, not the issue's** — the review's own
lesson. Draw the door matrix first (emitters / catch-up / lift × spec / group /
issue) and check every cell:

1. **The vacate/claim rule's remaining doors** — #229 (the critical: catch-up
   reissues a vacated ordinal and the registry then reports clean) and #223
   (the issue-side mint's missing ceiling recheck — the mint rule's sibling
   door).
2. **The width bound's partition doors** — #228.
3. **The memo rule's doors** — #233 (scope the warmer's case list to the log
   it warms, which closes the fork-amplification DoS) with #234 (warm catch-up
   and lift) in the same pass over the same function family.
4. **Sanitizer and header truth** — #232, #220 + #216.
5. **The fixture-blindness batch, mutation-tested per assertion** — #224 +
   #215, #225, #226, #222, #227, #221, #230. Six fixture claims fell in the
   review precisely because this step did not run; per-assertion mutation is
   the definition of done here, not a follow-up.
6. **Docs** — #231, #208's remainder, and `ARCHITECTURE.md` regenerated
   through `/jim:arch` (still stamped 2026-08-03, still documenting the
   retired `renumber-map` arity). #211's survivor is now unblocked:
   `feat/blueprint` merged into this branch on 2026-08-05, and
   `docs/features/blueprints.md` still carries zero occurrences of
   `partition-batch` or `lift`.

Run the review deliberately at the end, method-not-artifact as B′'s was — with
#188's degradation-naming in place, which is the point of landing it first.

**8. The sdlc pass — outside the cluster, scheduled here so it stops losing.**
#161–#167 (three critical, four high) have been open since 2026-07-31 and
untouched through five builds; with the pre-cluster #52 and #53 they are the
highest-criticality open work in the whole collection, and every B-cycle
generates enough residue to defer them another round. Take them after B″ and
before D, with #204's one-line `/jim:blueprint sdlc` run riding along.

**Free-floating:** D, F, the hardening build, #118, #139, #200's repair-path
half, and the #122 refactor — any time, any order. Two qualifications the
eleventh revision adds: **#200 stops being speculative** (B's #207 and #209 are
the registry-internal contradictions its repair path was reserved for, and
#209's re-mint is unrecoverable on an append-only branch — so consult it inside
B′ rather than after), and **D should follow B′** — not because it is blocked,
but because D adds another batch writer over the claim structure, and practice 9
says the question *does the new reader agree with the old one* belongs at plan
time. Let D inherit one settled rule instead of a contradicted one.
*(Thirteenth revision: both qualifications move forward one step. B′ settled no
repair path, so #200 is consulted inside B″'s #229 fork; and the claim rule
stays contradicted at `catch-up` until #229 lands, so **D's wait moves to
B″**.)*

**What A and C bought, and what they did not.** A bought correct arithmetic over
the records present and closed the rename window. C bought a door: nothing can
now create a spec id outside the allocator. Neither made the records represent
the repo (E, and step 0 for today's instance), and C did not make its own door
lock (C′). The proof is unchanged in form and worse in degree: two specs exist on
disk that the registry has never heard of, and one of them is the spec that
wired the allocator.

## Adopted practice — the reason C′ exists, and what guards it

**Status after the doc pass (2026-08-03): an eleventh practice, and it is the
first about a legitimate process step rather than a failure.**

11. **A fold is a waypoint; record the restoration target verbatim.** Folding a
    blueprint invariant to match reality is the right move when the code
    contradicts it — the alternative is a document that lies. But the fold
    silently rewrites *intent*: what was an assertion becomes a description, and
    the next reader has no way to tell a deliberate temporary weakening from a
    considered statement of what the group is for. Nothing in the surface marks
    the difference, and the pre-fold text survives only in git.

    So a fold has two halves, and only the first is automatic. Write the
    weakened text, **and** record on the issue that owns the fix: the pre-fold
    text quoted verbatim (so restoration is mechanical, not archaeological), the
    obligation that closing is incomplete until the invariant returns through
    `/jim:blueprint` at least as strong, and which clauses of the old text should
    *not* come back — a fold is also the moment to notice that the original
    conceded too much or named a mechanism since retired.

    The general form, and why it belongs beside the others: every practice above
    detects something that went wrong. This one guards a step that went
    *right* — and whose correctness is exactly what makes the loss invisible.

**Status after the bookkeeping pass (2026-08-03): a tenth practice, and it is
the first one that is purely arithmetic.**

10. **Reconcile a review's finding count against its filing count.** B's review
    reported **20** findings. Its filing pass produced **9** issues. Six of the
    eleven remaining were neither fixed nor deliberately left — they were simply
    lost, and nothing anywhere noticed, because no artifact holds both numbers.
    The review records its findings; the issues record themselves; no third thing
    says *every finding has a disposition*.

    This is practice 7's sibling once more — a result whose coverage is invisible
    in the result — but with a property none of the others have: **the check is
    mechanical.** The ledger already stores `findings=N`. A completion gate can
    demand N dispositions, each one of *fixed in session* (with a commit),
    *filed* (with an issue), or *left* (with a reason). C′-fix's review actually
    did this — "five fixed, seven filed, six left" — but it did it in prose, in a
    handoff note, by hand. Making it a counted obligation of the review artifact
    is a small change that closes a gap four practices of judgment did not.

    The same arithmetic catches the sibling failure this pass also found:
    **a shipped spec that closes none of its issues.** C′ recorded that exact
    observation as item 7 of *What C′ changed* — "the build did not close the
    issues it fixed" — and B then did it again, seven issues' worth. A lesson
    recorded in a working note has no mechanism behind it. **Not yet tracked**
    (#188 is the nearest neighbour and is about a different absence).

**Status after the C′-fix review (2026-08-01): practice 6 has a sibling.**
C′-fix shipped unreviewed — running as a build left no spec directory for
`/jim:review` to land in — so the review ran late and returned 21 findings, nine
of them regressions from that build. Fixing them exposed two failures of the same
kind, and neither is visible in the artifact that reported it:

- **The finding under-scoped itself.** T3 was *the* twin-miss finding — its
  entire subject was "fixed one, missed the sibling" — and it stated its scope as
  nine references under `agents/`. A wider sweep found four more on live skill
  surfaces. The pass that catches an incomplete sweep swept incompletely, and
  reported a count that read as exhaustive.
- **The project could not detect its own unrepresentativeness.** H1's hardcoded
  `BLUEPRINT.md` is byte-identical to what the resolver returns *here*, so it was
  a no-op in every local check and broke only where the map is configured
  elsewhere or absent — the un-partitioned majority. No test, no review, and no
  run against this repo could have surfaced it.

7. **The coverage of a result is not visible in the result.** Practice 6 says a
   practice that did not run leaves no trace in its artifact; this is its
   sibling — a practice that ran over *less than it appears to* leaves no trace
   either, and reads identically to one that ran over everything. Two corollaries,
   both concrete. A finding's stated scope is a claim, not a measurement:
   re-derive it before acting, and never inherit the reporter's grep — the
   reviewer who wrote it was subject to the same incompleteness it describes. And
   a green check against this repo is evidence about this repo: where code
   hardcodes a value that a configured resolver would also return, the two
   coincide locally and nothing here can tell them apart, so the check must run
   against a configuration where they differ. The general form: before trusting a
   clean result, ask what it was computed over — and when that is unrecoverable
   from the artifact, the artifact is incomplete. The actionable half for jim is
   the same shape as #188's: a review finding should carry the scope it was
   derived from, so the next reader can re-derive rather than inherit. **Not yet
   tracked.**

**Status after C′-fix (2026-08-01): the practices are load-bearing, and a sixth
is now earned that guards the practices themselves.** Practice 1 caught the one
defect C′-fix shipped — inside the same session, which is the improvement over C
and C′, where the equivalent finding waited for the next spec's review. Practice
5 (below) predicted that defect's shape precisely. Practice 4 held again.

But practice 1 **almost did not run**: a harness-injected prompt directive
suppressed the judge fan-out, the rung ran inline instead, and it reported zero
violations over code that contained two. Nothing in the report distinguished that
from a clean run. So:

6. **A practice that did not run must say so.** Every practice here detects
   something about the code; none detects its own absence, which makes a
   suppressed practice indistinguishable from a satisfied one. `/jim:verify` and
   `/jim:review` already name the degradations they can see — an `UNSCOPED`
   floor, a capped fan-out, an appetite threshold, an unconfigured registry — and
   "the fan-out did not run" belongs in exactly that list, in the report and in
   the ledger counters. Stronger still: a skill whose contract rests on
   independent judgment should decline to report a clean result at all when its
   independence was removed. Tracked as **#188**.

**Status after C′ (2026-07-31): all four ran, all four worked, and the spec still
shipped with AC 12 unmet.** Practice 1 produced all 13 review findings where the
author's own read produced none; practice 2 forced the blueprint fold at an
explicit fork; practice 3's discipline is what caught AC 13 naming a retired
group; practice 4 held exactly as stated. They are keepers — and they are
detection, not prevention. Every one of them fires at or after the completion
gate, which is why C′ still shipped its headline criterion unmet. **A fifth is
now earned, and it is the first one that acts before code exists:**

5. **A guard written for a race that cannot be reproduced from the CLI needs its
   wiring fixtured, not just its function.** Both of C′'s worst defects (#171,
   #172) live in code whose tests call the function directly because the
   condition — a concurrent writer, a subdirectory CWD — cannot be staged through
   the command surface. The function was correct in isolation and wrong in
   context, twice. When a plan proposes a guard whose fixture cannot go through
   the front door, that is the signal to fixture the *caller* and to state the
   guard's premise explicitly as a claim to check (#171's premise, "`mv`
   preserves the inode", is false and was never written down).

The original three, unchanged — they are here because the cluster's real cost
driver is no longer the backlog, it is the completion gate that lets a spec ship
with its contract unmet.

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

**Two more from `platform/012` (2026-08-02), both about the review rather than
the build:**

8. **Reproduce a critical before believing it.** E's fan-out reported three
   criticals; one was refuted by a thirty-second shell experiment, after two
   investigators independently reasoned it into existence from bash subscript
   semantics. This is the second consecutive build where a reasoned-from-source
   finding died on contact with a shell — #195 and #196 were the first pair, and
   both were caught the same way. Reading generates findings; running confirms
   them. A review that reports an unreproduced critical is reporting a
   hypothesis, and should label it as one. The corollary for the fixes: re-run
   the same reproduction against the fix, so "fixed" is also a measurement.

9. **A second reader of an existing structure is a disagreement risk, not a
   correctness risk.** Both of E's criticals came from one root cause — the
   classifier, the resolvers, and the realize path applied three different rules
   for what establishes a claim — and no reader was wrong on its own. The
   question belongs at plan time, beside practice 3's verb assertion: *when a
   task adds a reader of a structure something already reads, what makes the two
   agree?* Convention is the answer that fails; a shared predicate is the one
   that holds (this is `platform/011`'s shared-fold lesson, arriving a second
   time from a different direction).

## Per-issue disposition (all 83)

| # | Pri | Disposition |
|---|---|---|
| 111 | high | **closed** — shipped as `issue/010` |
| 114 | high | **closed** — shipped as `platform/008` |
| 115 | med  | **closed** — shipped as `platform/009` |
| 124 | low  | **closed** — shipped as `platform/011`'s D4 |
| 112 | high | **closed** — `sdlc/017` wired the spec-group consumer |
| 135 | med  | **closed** — `sdlc/017` shipped the realization path |
| 123 | med  | **closed** — `blueprint/025`; died with the tree-scan path, the consumer converged on `peek spec`; two prose sites → #211 |
| 144 | high | **closed** — registry repaired from the host 2026-07-31; standing half → Spec E |
| 146 | crit | **closed** — `sdlc/018`; path helper grew a provisional arity |
| 149 | crit | **closed** — bookkeeping 2026-08-02; `sdlc` fold verified live, `jim` half deliberately dropped with the retired blueprint |
| 150 | crit | **closed** — `sdlc/018`; ordinal gated, dropped record now loud |
| 156 | high | **closed** — `sdlc/018`; halt enforced inside the rename primitives |
| 159 | high | **closed** — `sdlc/018`; fold takes a pre-resolved group |
| 160 | high | **closed** — `sdlc/018`; marker-recording fence tracker + either-side-slash pick |
| 145 | med  | **closed** — `sdlc/018`; all nine fixtures landed |
| 147 | med  | **closed** — `sdlc/018`; WORKFLOW / README / template / config rows |
| 148 | med  | **closed** — `sdlc/018`; four contradictions plus a fifth found in review |
| 157 | med  | **closed** — `sdlc/018`; realize buffers before emitting |
| 158 | med  | **closed** — `sdlc/018`; scan and rewrite proven the same region |
| 151 | low  | **closed** — C′-fix; items 1–2 fixed (#171, #172, #173), items 3–4 by `sdlc/018` |
| 133 | low  | **closed** — `sdlc/018`; issue-side twin fixed in the same pass |
| 134 | low  | **closed** — C′-fix; regeneration can no longer be skipped, only checked |
| 113 | high | **closed** — `blueprint/025`; both emitters, the lift, and the backfill origin-tier; residue → #205–#219 |
| 143 | med  | **closed** — `blueprint/025`; a distinct `spec realize` verb, emitted live in the realization's own CAS |
| 152 | med  | **closed** — `blueprint/025`; all four points, incl. the `group:` rewrite; missing repair-table row → #211 |
| 154 | med  | **closed** — `blueprint/025`; settled as *refuse*, symmetric across all three preflights; synthesis half → #208 |
| 84  | med  | **closed** — `blueprint/025`; the floor's consumer is retired, and rename sources now carry the guarantee |
| 127 | high | Spec D (batch-CAS) |
| 116 | med  | **closed** — `platform/012`; sweep ships with a five-class non-coverage report |
| 130 | high | **closed** — `platform/012`; catch-up appends under the shared CAS, refuses an unseeded log |
| 136 | low  | **closed** — `platform/012`; refused on both resolvers and both realize maps, reported by the sweep |
| 126 | med  | Spec F (issue_placement) |
| 117 | low  | hardening build |
| 119 | low  | hardening build |
| 121 | med  | **closed** — `platform/012`; one numeric predicate reserves every zero spelling |
| 132 | low  | hardening build |
| 138 | low  | hardening build (`platform/011` residue) |
| 140 | med  | hardening build (`platform/011` residue — test gap) |
| 141 | med  | hardening build (`platform/011` residue — test gap) |
| 142 | med  | hardening build — partly done in-process by `platform/012`'s token cache; NOT the sweep's dominant cost (see 201) |
| 153 | low  | hardening build (`sdlc/017` residue — `run.sh` filter args) |
| 155 | med  | **closed** — `blueprint/025`; fork resolved to B, `SYNC:` discipline adopted; fixture residue → #215 |
| 122 | low  | half closed by `platform/009`; remainder is a standalone refactor |
| 129 | med  | **closed** — `provisional` committed as `3d49ce9` |
| 118 | med  | docs (coordination-branch protection / team setup) |
| 139 | low  | decision (`timeout` test dependency) |
| 137 | low  | deferred, no demand (exhausted-group recovery) |

| 168 | med  | **closed** — C′-fix; six context blocks, incl. one naming the retired `jim` group |
| 169 | high | **closed** — C′-fix; the sweep establishes liveness through the map |
| 170 | med  | **closed** — C′-fix; trap disarmed on the failure path, expansion made safe |
| 171 | crit | **closed** — C′-fix; a copied rename reads as landed, wiring fixtured |
| 172 | high | **closed** — C′-fix; refuses off the worktree top (the filed fix was foreclosed) |
| 173 | high | **closed** — C′-fix; roots normalize, and a stray root no longer disables all four |
| 174 | high | **closed** — C′-fix; both realizers accumulate, regeneration always runs |
| 175 | med  | **closed** — C′-fix; width policy deliberate, fixtured, joint-gate question → #113 |
| 176 | med  | **closed** — C′-fix; six help sites carry the provisional arity |
| 177 | med  | **closed** — C′-fix; awk status gated before install |
| 178 | med  | **closed** — C′-fix; one clause restated, and the named pair did not discriminate |
| 179 | med  | **closed** — C′-fix; notes off the parsed value lines, pinned mechanically |
| 180 | med  | **closed** — C′-fix; scoping and containment separated, not traded |
| 181 | low  | **closed** — C′-fix; one width policy, `move-spec-dir` gated |
| 182 | med  | **closed** — C′-fix; the seed emits the canonical spelling |
| 183 | low  | **closed** — C′-fix; `mv-spec` **retired**, both doc surfaces via their own skills |
| 184 | low  | hardening (`--root` shipped unfixtured) |
| 185 | med  | **closed** — `platform/012`; the advertised tip crosses the boundary in its single reader |
| 186 | med  | hardening (commit verbs omit the rename verbs' literal-pathspec semantics) |
| 187 | low  | hardening (generic path composer accepts the reserved slot) |
| 188 | high | **closed** — 2026-08-05; every delegating surface names an undispatched fan-out, `undelegated=` on both finished events, an undispatched judge is `failed` not `holds`; insights refuses, partition withholds |
| 189 | med  | **closed** — map pass 2026-08-02; both files declared, `scripthygiene` decided to platform, reconcile clean |
| 190 | high | **closed** — sweep fails on a dropped root; mutation-tested |
| 191 | high | **closed** — installer guarded in all three sites; mutation-tested |
| 192 | high | **closed** — compose guarded; harm reproduced under mutation |
| 193 | low  | **closed** — `--root` passed; divergence unreachable, defense in depth |
| 194 | high | **closed** — guidance keyed on stderr, with the destructive repair removed |
| 195 | med  | **closed** — premise incorrect; show-toplevel already resolves. Dedup kept |
| 196 | med  | **closed** — not a defect; guard is covered, proven by mutation |
| 197 | med  | **closed** — pre-B build; untracked enumeration under the symlink discipline, regen rebuilds from rewritten sources |
| 198 | high | **closed** — pre-B build; grant narrowed to `peek issue`, ahead of B widening the verb surface |
| 199 | med  | **closed** — pre-B build; the own-H1 is a self-identity site, sweep grammar unchanged |
| 200 | med  | decision — repair-path design; demand now real (#207/#209 write the contradictions), settle inside B′ |
| 201 | med  | hardening — the sweep's per-file frontmatter cost (measured, ~6.9s of ~14s) |
| 202 | med  | **closed** — `blueprint/025`; all four shapes over one shared claim replay; fixture residue → #210 |
| 203 | high | **closed** — pre-B build; per-identity `blocked` on both realize paths, hazard class in the sweep |

*(#161–#167 are `sdlc` blueprint drift surfaced by C′'s verify pass, not
id-coordination work — excluded from this table and from the 83. Worth one line
anyway at the eleventh revision: **all seven are still open, three critical and
four high**, untouched through four builds. Correctly excluded, and now the
highest-criticality open set in the collection.)*

## Outside the 83 — B's residue (15) + B′'s residue (15) + #204

Not cluster issues: they did not exist when the cluster was enumerated, and they
belong to the emitter's edges rather than to the coordination problem. The
fifteen are B′'s; #204 is a single blueprint run and rides nothing. Priorities as
filed. (B′ was scoped at **sixteen** items — these fifteen plus #138, pulled up
from the hardening bucket to join #212. In the event #138 had already been
delivered and closed by the emission spec, so B′ ran the fifteen; #212's pass
covered the ground #138 named regardless.)

Disposition as of the post-build review, 2026-08-05. **Closed** means the issue's
own *Proposed action* is delivered and verified; **open** means that action is
itself short, not that the tracker lagged.

| # | Pri | Disposition |
|---|---|---|
| 205 | crit | **closed** — slug-gated before the glob; 20-payload attack matrix, rename/split byte-identical. The pre-fix leak was worse than this issue's repro showed: with a directory at the traversal target it reflected basenames from outside the repo |
| 206 | med  | **closed** — all three bullets; both remedies followed through to `rc=0` and the counterfactual confirmed failing. Four sibling echoes and the marker's missing consumer tracked on |
| 207 | crit | **closed** — cross-run hole reproduced on `a000a70^` and closed at HEAD; reorder attack repelled; preview == payload == published across six shapes. Residual fixture coverage tracked on |
| 208 | med  | **open** — the enumeration step and checklist line shipped; the sanitizing boundary did not, and "consumers" plural got one consumer. The cut discloses *that* it cut, never how many, and misreports a cut that did not happen |
| 209 | high | **closed** — three contradictions plus the sibling door; all five gates mutation-discriminating; fold-restoration discharged. `catch-up` is the third write door and is tracked on |
| 210 | med  | **closed** — vacuous case and both orphaned headers gone, five fixtures added, **13 of 13 mutations red**. The strongest fixture result in the cluster |
| 211 | med  | **open** — the 19-of-20 count is disproven: `ARCHITECTURE.md:395` was claimed fixed and is not, and `README.md:62` / `ARCHITECTURE.md:393` are missed siblings. Stays open for `docs/features/blueprints.md` as scoped |
| 212 | med  | **closed** — one predicate, one constant compared in exactly one function, `>999` closed at the primitives; fold-restoration discharged. Scope was **eleven** gates across four files, not nine or ten — third mis-statement in this cluster. The guard's blind spots and the partition layer tracked on |
| 213 | high | **closed** — reproduced on a true pre-fix checkout *and* under single-hunk isolation; chain depth unbounded, both surfaces pinned |
| 214 | med  | **closed** — one decision site proven by exhaustive enumeration, `rz_of` gone, fold mutation-proven. The realize *writer* never consults it — tracked on |
| 215 | med  | **open** — shims pinned verbatim and mutation-tested; the three `PROV_PREFIX` values are a `sort -u` set-compare blind to both deletion and re-quoting. The measured half works; the unmeasured half is the blind one |
| 216 | low  | **open** — the sanitizer moved and is a genuine record-layer primitive; `jimalloc.sh:76` still declares the section "pure … no git" while `alloc_read_log` forks git inside it |
| 217 | low  | **closed** — locals restored, dead `g` dropped, leak check discriminates per name. It is name-pinned to one function and would not have caught the misses found elsewhere in this range |
| 218 | med  | **closed** — 826 → 291 forks, each distinct token once; 1.54× reproduced across 8 interleaved pairs, outputs byte-identical. Cross-kind over-coverage and the un-warmed siblings tracked on |
| 219 | low  | **closed** — exhaustive 7×3 known + 6 unknown matrix; the pre/post diff is exactly one row. `group allocate` lands in zero counters — pre-existing, tracked on |
| 204 | low  | one `/jim:blueprint sdlc` run — declare `platform.jimalloc` in the Requires face |

*(#214–#219 are the six the review found and the filing pass lost; see* What did
not close with B*. #204 is not review residue — it was surfaced during B's
scoping, parked in a handoff note, and filed durably; it appeared in no prior
revision of this note.)*

**B′'s residue repeats the pattern one generation on: fifteen more (#220–#234),
realized 2026-08-05.** Twelve from the post-build review and three divergences
the accompanying verify run filed against the platform blueprint's invariants:
one critical (#229), four high (#226, #227, #228, #233), ten medium. Together
with the four items above that stayed open (#208, #211, #215, #216) they are
**B″'s charter**; the sequencing and the two pre-code forks live at *Sequence*
step 7.

*(#201–#203 came from `platform/012`'s review. **All three are adjacent
observations, not defects in shipped mechanism** — the two criticals that review
found were fixed in the same session rather than filed, which is why the count is
three and not five. #202 is unreachable until rename emission lands, so it
belongs with Spec B rather than ahead of it; #203 is a behavior regression this
build introduced against a contract its consumer still documents, and is the one
worth taking soonest.)*

*(#190–#196 ran as one build rather than folding into Spec E — they were one
surface, six of the seven in the realize/sweep path, which is why one review
surfaced them all. **Three of the seven were real**: #190, #191, #192, all one
shape, a write whose failure reports as success. #193 hardens a divergence no
input can produce; #194 was a documentation defect whose documented repair
destroyed work.*

***Two were wrong.** #195's failure cannot occur — `git rev-parse
--show-toplevel` already returns a symlink-resolved path — and #196's guard was
covered all along. Both were filed as investigator reasoning explicitly marked
unreproduced, and both were caught by mutation-testing the fixtures written for
them: #195's refused to fail, #196's existing case did fail when the guard was
neutered. That is practice 7 paying for itself twice in one build, and the
reason the filed bodies separated confirmed-in-source from reasoned-from-code.)*

## Net

83 issues → **2 assigned to the 2 remaining specs** (D: #127 · F: #126), **11
to the grouped hardening build**, **1 optional refactor** (#122), **1 doc item +
2 decisions + 1 deferred** (#118 · #139, #200 · #137), **65 closed**.

The closed 65 are: the 49 the tenth revision's own accounting reached, the pre-B
build's four (#197, #198, #199, #203), #149 and the map pass's #189 — **B's
eight**, closed 2026-08-03 rather than 2026-08-02: #113, #143, #152, #154 and
#202 delivered outright; #84 and #123 dead structurally with the tree-scan
retirement rather than patched; #155 delivered by the fork it was parked on —
and **#138**, which this note assigned to B′ but which the emission spec had
already delivered and closed, so it never rode B′ at all — and **#188**, the
process item, closed 2026-08-05 ahead of B″ as the thirteenth revision's Sequence
sequenced it.
2 + 11 + 1 + 4 + 65 = 83. The enumeration still closes.

**B's residue is new work, not reopened work — and it is sixteen, not nine.**
The review, the sensor and the six findings the filing pass lost became
#205–#219, plus #204 from B's scoping. None existed when this cluster was
enumerated; all belong to the emitter's edges rather than to the coordination
problem the cluster was about. They are outside the 83 and enumerated in *B's
residue* above. (#110, #120, #125 stay outside the cluster and closed the same
day — the latter two duplicates of each other, already satisfied since C′-fix
repaired the map.)

**The spec count still has not moved, and this time it went down.** C shipped and
C′ took its slot; C′ shipped and its residue became a *build*, not a fourth spec.
Sixteen more issues distributed into work that already existed. The rule held
twice: *an issue recording a shipped spec's unmet contract belongs to that spec,
not to a new one* — and the corollary this revision adds is that the rule governs
the spec **count**, not the ceremony: C′-fix rides in C's slot without wearing a
spec, because none of the three criteria that made C′ a spec still apply.

The headline has moved again, though. A's lesson was that the cluster's centre of
gravity was C and E, not A. C's lesson was that **the constraint is no longer
which specs to write, it is whether a spec finishes** — one spec shipped green,
complete, and ledger-closed while three critical defects and two security
regressions rode along inside it.

C′ tested that lesson and returned an uncomfortable result. Every practice the
third revision adopted was applied: the fan-out ran, the sensor ran, the plan's
verbs were checked, the suite stayed green and was correctly discounted. They
worked — 13 findings the author's own read had missed. **And the spec still
shipped with its headline criterion unmet**, because all four practices detect at
or after the completion gate rather than preventing before it.

So the constraint refines rather than moves: it is not whether a spec finishes,
it is **whether the thing a spec builds fresh gets the same scrutiny as the thing
it repairs.** C′ closed both of C's shipped defects cleanly — proven correct by
construction, hostile review survived. Every defect it shipped was in new code
written to satisfy an AC, guarded by fixtures that could not reach the guard's own
wiring. B, D, E and F should each be assumed to carry not a C′, but a C′-fix:
smaller, cheaper, and concentrated in whatever each one builds that has never
existed before.

**C′-fix confirmed that reading and then went one layer past it.** It wrote
exactly one new guard, and shipped it defective in exactly the predicted shape —
its fixture covered the in-group case and the hole was in the cross-group one. So
the rule holds a third time and can be relied on. But the defect was caught by a
judge fan-out that **very nearly did not run**, suppressed by a directive injected
into the harness rather than written by anyone here; the run that skipped it
reported ten invariants and zero violations, and looked exactly like a clean one.

That is the constraint's next form, and it is not about specs at all:
**every practice in this note assumes its own mechanism ran, and none of them
checks.** The fan-out, the sensor, the plan-time verb assertion, the discounted
green suite — each detects something about the *code*. None detects its own
absence, so a suppressed practice is indistinguishable in the artifact from a
practice that ran and found nothing. Tracked as #188, and the cheapest fix is the
one these skills already apply to every other degradation they can see: say so.

The corollary for B, D, E and F: assume each carries a C′-fix, **and** check that
the machinery meant to find it actually ran before believing a clean report.

**E tested that corollary, and it came back cleanly for the first time.** The
prediction held — E shipped two criticals, both in code written fresh for an AC,
none in the three riders that repaired existing behavior. What changed is *when*:
the fan-out ran before the ledger closed, both criticals were reproduced,
fixed, and re-verified inside the same session, and the spec closed with its
contract actually met rather than with a finding filed against it. C shipped
three criticals and closed anyway. C′ shipped its headline criterion unmet. E
shipped two criticals and did not close until they were gone. That is the loop
finally working end to end.

Two things E adds that the practices did not have:

- **Reproduce a critical before believing it.** Of E's three reported criticals,
  one was refuted by a thirty-second shell experiment after two independent
  investigators reasoned it into existence. Reading is how findings are
  generated; running is how they are confirmed. A review that reports an
  unreproduced critical is reporting a hypothesis.
- **When a build adds a second reader of an existing structure, the risk is
  disagreement, not incorrectness.** Both of E's criticals came from one such
  disagreement, and neither reader was wrong on its own. That question — *does
  the new reader agree with the old one* — belongs at plan time, next to the
  existing practice of asserting each named verb has the property its task
  assumes.

The remaining specs are **D and F** (B shipped 2026-08-02). B carried E's
rename-shaped residue where it belonged — #202 in scope, #203 discharged ahead
of it by the pre-B build so the realize-row contract was settled before the spec
consuming it existed. E detected what B had to emit correctly; the pre-B build
repaired what E regressed before B leaned on it. Both held: #202 closed inside
B, and no realize-row surprise reached it.

**The ninth revision grew the cluster by five and the spec count by zero.**
The rule's corollary applied a second time: #203, #197 and #199 record shipped
mechanism's regressed or unmet contracts (`platform/012`'s realize halt,
`sdlc/017`'s citation sweep), so they ride those specs' slots as a build —
none of the three criteria that make a spec is present. And B absorbed #84 and
#123 without growing: they are not new work, they are one decision B already
owned — whether the tree-scan `next-id` surface survives — now with its
instances attached. The runway to B was short and deliberate: one small build,
three closures, one map pass — and all of it landed the same day, in-session.
Next is the interview.

**The eleventh revision grew nothing and corrected the record.** B shipped what
this cluster was built to reach — the registry writes, the citations
dereference, the retired group is covered, the sweep reports no exception of any
class but the reserved slots. Every prediction the note has made about *where*
defects live held again: B's are in `partition-batch`, the lift, and the two
replays, all written fresh for an AC; nothing it repaired came back.

What is new is smaller and more awkward. The cluster's two most durable
lessons — *a spec must close the issues it fixes*, and *a result's coverage is
invisible in the result* — both recurred in the same build, and both had already
been written down here. C′ recorded the first as an observation in July; B did
it again in August, seven issues' worth. Practice 7 named the second in general
terms; B's review then filed nine follow-ons for twenty findings and nothing
compared the numbers.

So the constraint's next form is not about specs, or about reviews, or about
what a build creates fresh. It is: **a lesson recorded in prose does not
execute.** Every practice this note has adopted lives in this file, and this
file runs nowhere. Practice 10 is the first one deliberately chosen for being
*arithmetic* — a count against a count, checkable at a gate — and that property
matters more than its subject. The ones worth adopting next are the ones that
can be counted.
