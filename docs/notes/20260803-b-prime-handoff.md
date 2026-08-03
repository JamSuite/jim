# Handoff — B′, the emission build's residue

**Written:** 2026-08-03 · **Branch:** `feat/id-coordination` · **Base:** `175047c`
· tree clean · suite **1099/1099** · registry clean at 65/65 specs, 219/219 issues

**What this is.** A context primer for the session that takes on B′. It is
deliberately *descriptive*: it maps the terrain, records what has already been
established so you need not re-derive it, and names the traps this codebase has
sprung on the last two sessions. It does not tell you what to build or in what
order — `docs/notes/20260728-id-coordination-issue-grouping.md` § *Grouping* → B′
carries a suggested sequence and the reasoning behind it, and the sixteen issues
carry the detail. This note is the thing you read first so that everything else
you read afterwards lands somewhere.

**Its relationship to the cluster note.** The cluster note is the authority on
*why* the work is grouped the way it is, what the spec-count discipline is, and
what eleven practices this cluster has cost. It is long and it is history. This
note is the map of the ground as it stands today. Where they disagree, the
repository wins — both are dated documents.

**Anchors are as of `175047c`.** `jimalloc.sh` is 3,789 lines and changes shape
under exactly the work B′ does; treat every line number here as a starting point
to confirm, not a citation to trust.

---

## 1. Where things stand

`blueprint/025` shipped the write half of the ID-coordination registry — rename
and realize record emission, two publish verbs, a lift over historical ledger
events, and the retirement of the tree-scan ordinal path. It works: the registry
has 52 rename-source records from jim's own 2026-07-25 split, a citation frozen
before that split dereferences, and the sweep reports no exception of any class
except the five reserved blueprint slots.

Its post-build review returned **major-drift** with 20 findings, two ACs failing
on reproducible counterexamples. Nine issues were filed at the time; a later
pass found six more findings that had been filed nowhere. Those fifteen, plus
`#138` pulled up from the hardening bucket, are B′.

**B′ has not started.** No code has been written toward it. What *has* happened
is preparation: the tracker was reconciled with the code, the emission build's
documentation was corrected, and a `/jim:verify` run over `platform` established
which of the group's invariants actually hold. Sections 5–7 record what that
bought you.

---

## 2. What B′ is, and the constraint on its shape

Every one of the fifteen records `blueprint/025`'s own unmet or regressed
contract. Under the rule this cluster adopted — *an issue recording a shipped
spec's unmet contract is that spec finishing, not new work* — B′ rides B's slot
and does not raise the project's remaining-spec count. That is a claim about the
planning ledger, not about ceremony: C′ wore a spec, C′-fix did not, and both
rode C's slot.

The cluster note argues B′ fits the **build** shape (no threat-model surface for
`/jim:sec` to open, forks settleable in conversation, blueprint writes going
through their own surfaces). It also names one condition that would change that
— see § 4.

**The build shape's known cost**, from C′-fix: no spec directory means
`/jim:review` has nowhere to land, so the review must be run deliberately rather
than assumed. C′-fix skipped it and the late review returned 21 findings, nine of
them regressions from that build.

---

## 3. The terrain

### The registry's shape

One append-only, space-separated log per kind on a coordination branch, read
through `git cat-file`. Field-order authoritative. **It is untrusted data** — any
clone that can push the branch can write it — so every token read back crosses
`jimfile.sh`'s `is_valid_id` boundary before use, and a malformed record is
degraded and skipped rather than half-parsed.

```
spec  allocate <group>/<NNN> <slug> <date> <who>
group allocate <group> <date> <who>
issue allocate <NNN> <full-id> <date> <who>
spec  rename   <group>/<NNN> <newgroup>/<newNNN> <date> <who>
group rename   <old-group> <new-group> <date> <who>
issue rename   <NNN> <newNNN> <date> <who>
spec  realize  <group>/P-<date>-<slug> <group>/<NNN> <date> <who>
```

`realize` is deliberately *not* a rename: a rename source is an ordinal the group
consumed and can never reissue, and the high-water fold counts it as such, while
a provisional token is no ordinal at all. Giving realization its own verb is what
keeps the reserved form out of the vacating fold structurally rather than by
special-casing.

### Where the machinery lives

`skills/file/scripts/jimalloc.sh` (3,789 lines) holds nearly all of it. The
sections that matter to B′, in file order:

| Anchor | What it is |
| :--- | :--- |
| `:257` `alloc_canon_specid` | per-side ordinal canonicalization + width gate |
| `:363` `alloc_rename_scan` | **the** rename-record reader — one rule, seven former parses |
| `:397` `alloc_realize_scan` | the realize-record reader (its three consumers disagree — #214) |
| `:436` `alloc_malformed_count` | non-coverage counter (double-counts `group realize` — #219) |
| `:500` `alloc_resolve_spec` | forward-replay to the current name |
| `:741` `ALLOC_MAX_ORD_DIGITS=15` | the one named width constant (#212's anchor) |
| `:811` `alloc_fold_max_spec` | the shared spec high-water fold |
| `:907` `alloc_next_id_spec` | allocation arithmetic |
| `:1282` `alloc_is_reserved_ord` | the zero-valued reserved predicate |
| `:1489` `alloc_spec_replay` | the extracted claim replay — emits `LIVE` **and** `SRC` rows |
| `:1561` `alloc_classify_spec` | integrity classifier (lost `local`s — #217) |
| `:2457` `alloc_publish` | the CAS/erosion/retry engine every writer rides |
| `:2623` `alloc_group_has_records` | group-existence predicate (#213's root) |
| `:3199` `alloc_live_claim_set` | corroboration set for the emitters |
| `:3218` `alloc_partition_spec_publish_builder` | spec-mode emitter (#209's root) |
| `:3281` `alloc_partition_group_publish_builder` | group-mode emitter |
| `:3473`–`:3511` `alloc_lift_state(s)` | per-row lift decisions + field re-gating |
| `:3585` `alloc_lift_publish_builder` | the lift's batch guard (#207's root) |
| `:3630` `cmd_lift` · `:3674` `cmd_partition_batch` | the two CLI write verbs |

Supporting cast: `skills/ledger/scripts/jimledger.sh` (1,159 — `pair-events`,
`move-spec-dir`, the seven commit verbs), `skills/file/scripts/jimfile.sh` (1,169
— the id boundary, path composition, occupancy), `skills/partition/scripts/jimpartition.sh`
(2,179 — the preflights and map verbs), `skills/spec/scripts/reconcile.sh` (848 —
the spec realize path). Tests: `tests/jimalloc.sh` is 4,129 lines.

### The two write verbs

`partition-batch` publishes a renumber pair set as allocate + rename per pair, or
one record for a whole group. `lift` turns the specs-root ledger's durable
`moved=` pair events into records. Both recompute their refusals **inside**
`alloc_publish`'s builder on every CAS attempt, so a conflict another clone
introduced between check and commit is caught by the attempt that would have
overwritten it — a design property worth preserving through any edit here.

The lift treats the ledger as a **witness, not an instruction**: a pair is
recorded only where the registry independently establishes its destination and
holds no live claim on its source. Without that, an operator's run would convert
push-writable branch content into registry records under their own authority.

---

## 4. What actually connects the sixteen

The issue numbers are a filing order, not a structure. Four clusters:

### The claim/vacate surface — #207, #209, #213, #214

One question underneath all four: **what establishes a claim, and what vacates
one.** Each is a different reader or writer answering it differently.

- **#209** — `alloc_spec_replay:1546` emits `SRC` rows for ordinals a rename moved
  away from. `alloc_live_claim_set:3202` keeps only `LIVE`. So the emitter cannot
  see that an ordinal was ever spent, and a vacated ordinal can be re-minted; a
  frozen citation then silently resolves to a different spec. The data exists one
  function away from the code that needs it. Also: the reserved `000` slot is
  accepted as a destination, and a destination-group redirect goes unchecked.
- **#207** — the lift's `batch_dst` guard (`:3594`, `:3599`) is in-memory and
  destination-keyed. It leaves no trace, so a second run emits what the first
  refused; and being destination-only, two rows sharing a *source* both emit,
  after which that source is permanently unresolvable on an append-only branch.
- **#213** — `alloc_group_has_records:2642` filters rename sources on `rk == spec`,
  so a group established solely as a *group*-rename destination is invisible. A
  group renamed once cannot be renamed again.
- **#214** — `alloc_realize_scan`'s three consumers apply three rules to a
  duplicated realize key: the resolver takes first, the lift's `rz_of` takes last,
  `alloc_lift_state` calls it a conflict. None refuses, though every other
  duplicate-claim shape in the file is refused with both record positions named.

The cluster note's practice 9 is the frame: *when a build adds a second reader of
an existing structure, the risk is disagreement, not incorrectness.* B extracted
`alloc_spec_replay` precisely to make the classifier and the emitters agree, and
it worked — AC 6 holds. The *realize* replay never got the same treatment, and
`alloc_live_claim_set` narrows the extracted replay's output on the way out.

### The width bound — #212 + #138 + #206's AC-17 clause

One bound, **nine deciding sites**, three mutually incompatible accepted sets:

| Accepted set | Sites |
| :--- | :--- |
| 1–15 | `jimalloc.sh:741` (the constant) · `jimfile.sh:403` · `jimfile.sh:415` |
| 3–15 | `jimfile.sh:371` · `:584` · `:900` · `jimledger.sh:691` |
| exactly 3 | `jimledger.sh:586` · `:587` |

The registry has no lower bound at all (`alloc_valid_specid` is `^[0-9]+$`,
printed `%03d`). **A reachable consequence nothing recorded until now:**
`alloc_next_id_spec` mints a 4-digit ordinal once a group passes 999, `jimfile.sh`
accepts it, and `move-spec-dir`'s gates refuse it on both sides — so a group past
999 can allocate specs the move primitive can never move. No test asserts any two
sites agree; `tests/` contains no reference to `ALLOC_MAX_ORD_DIGITS`.

#138 is the intra-file half of the same problem (the predicate around the constant
inlined at six sites inside `jimalloc.sh`). #206's AC-17 clause is the semantic
question the pass must settle: does the ledger parser lower its floor, or is the
3-digit tree shape recorded as deliberate?

### The reserved slot — #209 (partly), #187, and a chain

Enforced on derivation and reporting: one predicate drives the seed, the
classifier, the sweep and catch-up, and allocator arithmetic can never yield
`000`. **Not** enforced on writers — `partition-batch`, `lift`, `path spec`,
`mv-spec-id`, `move-spec-dir`'s `dst_shape`, `rename-tracked`'s basename gate, and
`pair-events`' `isord` each admit it. The chain matters: `lift` is safe today only
because `refused:destination-not-established` fires first, which stops being true
the moment `partition-batch` mints `<group>/000`. The only zero-ordinal write
guard anywhere is a *caller* (`jimpartition.sh:1486`), not the boundary.

### Leaves — #205, #208, #210, #211's remainder, #215–#219

Independent of each other and of the above. #205 is the single security regression
(a read-only filesystem probe on an unvalidated component, rated `low` by the
review; its `critical` grade is the invariant's criticality). #208 is a blueprint
instruction that cannot fire. #210 is a vacuously-green test plus four fixture
gaps. #215–#219 are the six the filing pass lost.

---

## 5. The fork that decides B′'s shape

**#209's first contradiction collides with the split protocol.** Refusing to
re-mint a vacated ordinal means a split into a group name that was previously
retired cannot densify its fresh children from `001`, which is what
`renumber-map` does today. If closing that hole reshapes `/jim:partition split`
rather than just gating the emitter, the work stops being a local fix.

The cluster note names this as the trigger that would make B′ a spec rather than
a build. It is the one question worth settling before anything is written, and it
is settleable by experiment: jim's own retired `jim` group holds 52 vacated
ordinals and is exactly the shape that would collide.

Everything else in the sixteen is settleable in conversation.

---

## 6. Two invariants are folded open

On 2026-08-03 the `platform` blueprint's `ordinal-single-source` and
`blueprint-slot-reserved` invariants were **deliberately weakened** so they would
stop asserting what the code does not do. This is recorded here because a fold is
invisible in the artifact: the weakened text reads exactly like a considered
statement of intent.

`#212` and `#209` each carry the pre-fold text verbatim and the obligation that
closing is incomplete until the invariant is restored through `/jim:blueprint` at
least as strong as it was. Both can come back *stronger* — a restored claim can
rest on a fixture rather than on convention — and each pre-fold text contains a
clause that should not survive: one confesses agreement-by-convention, the other
names the retired `next-id` mechanism.

The cluster note's practice 11 is this observation generalized.

---

## 7. Established — you need not re-derive these

A `/jim:verify --since 8f1b6dd platform` run on 2026-08-03 dispatched nine judges
over the group's territory. Results, so the same ground is not re-walked:

**Held, with the reasoning traced:**

- `no-source-eval` (critical) — zero `eval` anywhere in scope, zero dot-source;
  every `source` names first-party code. Registry content reaches `alloc_read_log`
  via `cat --`/`git cat-file -p` and is never sourced.
- `ref-validation` (critical) — every git invocation traced. B's new surfaces
  hold: both `partition-batch` modes and the lift validate every token *inside*
  the CAS window; `pair-events` gates awk-side and `alloc_lift_states` re-gates on
  receipt, so that interface is fail-closed on both sides independently.
- `relpath-validation` (critical) — the widened `move-spec-dir` source gate is
  charset-closed (`P-[0-9]{8}-[a-z0-9][a-z0-9-]*`), admitting no `/`, `.`, `:`, or
  leading `-`. All four git path calls in the mv primitives carry
  `--literal-pathspecs`, with two live regressions proving magic is refused.
- `ledger-commit-discipline` (critical) — still exactly seven committing verbs;
  `pair-events` invokes no git and the retired `vacated-max` was non-committing.
- `no-third-party-deps` (critical, mechanical floor) · `tests-under-tests` (medium).

**Not run, and named as such:** the registry rung (`--since` cannot range-scope a
whole-project invocation) and the **contract-edge phase**, whose existence
conditions held — the map has a contract graph, names `platform` as provider to
all three other groups, and the change touched provides-side code in all three
CLIs. That phase is carried into B′ as a task that is not an issue.

**Two coverage limits worth knowing:** `relpath-validation`'s map-territory clause
and `ref-validation`'s issue-group `is_valid_id` copies both live outside
`platform`'s territory, so those `holds` cover the platform half only.

**Also established:** registry and tree agree everywhere (65/65 specs, 219/219
issues, `uncovered-groups 0`, `pending-provisionals 0`, `duplicate-realize-keys 0`);
the contract graph is 23 edges and unchanged; the health hook reports 0 of 5
thresholds crossed.

---

## 8. Traps this codebase has sprung

Each of these cost real time in the last two sessions.

1. **`tests/metatest.sh`'s sandbox contract is load-bearing.** Its cases `cd`
   into a temp dir and expect `scaffold`/`add` to write *there*. PWD-relative
   paths in `metatest.sh` are deliberate, not drift. Anchoring them to the plugin
   tree makes the sandbox tests write into the **production** `tests/` directory.
2. **`testlib.sh` and `run.sh` must not export a locale.** They `source` the test
   files, so any locale they set becomes the one every fixture is matched under —
   `LC_ALL=C` there stops the provenance detector's en/em-dash range from matching
   and turns a real check into a silent pass. Now pinned by its own case in
   `tests/scripthygiene.sh`: gaining the export is the regression.
3. **`run.sh`'s zero-discovery path is intentional.** A sandbox run finding no
   tests and exiting 0 is how `case_metatest_run_no_args_invokes_aggregate_runner`
   avoids recursing into the real suite. The comment says so. Three independent
   judges flagged it as a defect anyway.
4. **`grep -rn … .` here omits the `./` prefix.** A path filter anchored on
   `^\./docs/…` silently matches nothing and looks like a filter with nothing to
   exclude.
5. **The coordination remote is unreachable from this sandbox.** Reads work from
   the last-seen cache; writes refuse (correctly). Issue filing mints provisional
   `P-` ordinals that need `/jim:issue reconcile` from the host. Registry-writing
   verbs (`partition-batch`, `lift`, `catch-up --apply`) cannot be exercised
   end-to-end here — the last backfill ran host-side.
6. **Realize assigns ordinals in glob order, not filing order.** Within one day's
   batch the sort key is the title. Cross-batch ordering is chronological;
   intra-batch is not.
7. **The full suite exceeds a 600s foreground timeout.** Run it backgrounded, or
   run a single `tests/<name>.sh` while iterating.
8. **Agent delegation may be suppressed by a standing session directive.** It
   happened twice now; the `/jim:verify` judge rung ran only after explicit
   authorization, and nothing in the engine's output would have distinguished the
   suppressed run from a clean one. This is `#188`, still open, and the cluster
   note argues it should land before B′'s build phase.

---

## 9. Adjacent, and deliberately not B′'s

- **`#161`–`#167`** — seven `sdlc` blueprint drifts, **three critical and four
  high**, open since 2026-07-31 and untouched through four builds. Correctly
  excluded from the cluster; currently the highest-criticality open set in the
  collection.
- **`#107`, `#108`, `#186`** — literal-pathspec neutralization in `jimpartition`
  and the `jimledger` commit verbs. Two judges reached the commit-family gap
  independently and both scoped it *outside* the invariant, which is written to
  cover only the git-mv primitives. The gap is real and the issues are correct.
- **`#153`** — `run.sh` honors only its first filter argument. Same family as the
  zero-discovery hazard in trap 3: the runner reporting success over work it did
  not do.
- **`#211`'s survivor** — `docs/features/blueprints.md` has zero occurrences of
  `partition-batch` and still describes the pre-registry Close choreography. Held
  for the `feat/blueprints` branch, which lands separately and merges in.
- **`#204`** — one `/jim:blueprint sdlc` run to declare `platform.jimalloc` in the
  Requires face. Rides nothing.

---

## 10. Reference

**Read first:** `docs/notes/20260728-id-coordination-issue-grouping.md` §§
*What `blueprint/025` changed*, *What did not close with B*, *Grouping* → B′,
*Adopted practice*. The per-issue tables at the end are the disposition index.

**Do not re-read cover to cover:** the cluster note's history sections (*What
`sdlc/017` changed*, *What C′ changed*, *What C′-fix changed*, *What
`platform/012` changed*) unless a specific question sends you there. They are
kept as provenance.

**The review that generated B′:**
`docs/specs/blueprint/025-rename-redirect-record-emission/review.md` — its
Findings section is the primary source for every issue #205–#219, and its
*Deviations & feedback* records the retirement-sweep lesson that produced #211.

**Useful, and known to work in this sandbox:**

```bash
bash skills/file/scripts/jimalloc.sh sweep                 # registry vs tree
bash skills/file/scripts/jimalloc.sh peek spec <group>     # advisory next ordinal
bash skills/file/scripts/jimalloc.sh resolve spec <g>/<N>  # forward-replay
bash skills/verify/scripts/jimverify.sh parse <blueprint>  # invariant table
bash skills/ledger/scripts/jimledger.sh pair-events <specs-root>
bash skills/issue/scripts/render.sh show <num|slug>
bash skills/meta-test/scripts/run.sh [<filter>]            # background it
```

**Session shape that worked:** derive claims mechanically rather than inheriting
them (two stated scopes were wrong this week, both under-counted); reproduce a
defect before believing it and again after fixing it; and when a fix breaks a
test, read the test's comment before assuming the test is wrong — twice this
week it was documenting a deliberate contract.
