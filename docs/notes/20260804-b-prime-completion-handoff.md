# Handoff — B′ built and verified, three things left

**Written:** 2026-08-04 · **Branch:** `feat/id-coordination` · **Base:** `093bda7`
· tree clean · suite **1137/1137** (baseline was 1099) · registry clean at 65/65
specs, 219/219 issues · 32 commits since `7e5dd00`, +1019/−147 over 16 files

**What this is.** The successor to `docs/notes/20260803-b-prime-handoff.md`,
written at the point where B′'s *building* is finished and its *closing* is not.
Read that note first only if you need the terrain map — its § 3 (registry shape,
where the machinery lives) and § 9 (adjacent work) still hold. **Its anchors are
dead**: `jimalloc.sh` went 3,789 → 3,980 lines and nearly every function it cites
moved. Current anchors are in § 3 below. Two of its established claims are now
false; see § 6.

---

## 1. Where things stand

**All sixteen B′ items are built, fixtured, and committed.** Fifteen of the
sixteen are fully closed in code; #211's last site (`docs/features/blueprints.md`)
remains deliberately held for the `feat/blueprints` branch, exactly as the prior
note scoped it.

**Two of the three closing obligations are discharged:**

- The **contract-edge phase** ran (the task the prior note carried as "not an
  issue"). 14 edges checked, 10 judged sides, **zero violations**, recorded
  project-tier on the specs-root ledger and self-committed.
- The **two folded invariants are restored** through `/jim:blueprint`, both
  stronger than pre-fold, both grounded in a `--since 175047c platform` engine
  run. The reconcile pass ran and the map's graph is re-stamped.

**What is left is § 4.** The deliberate post-build review has not run — the
session hit its usage window first. Nothing else is in flight; the tree is clean
and every step above is committed.

---

## 2. What shipped

Commits pair `test:` → `fix:` throughout (red before green, verified failing for
the stated reason before each fix). Per issue:

| Issue | What landed |
| :--- | :--- |
| **#214** | `alloc_realize_fold` — the duplicate-realize rule extracted into the record layer. Idempotent duplicate realizes; two records naming different ordinals are a contradiction refused with both positions named. The resolver and the lift both consume it; the accidental first-wins (comparing against a mutated loop variable) is gone. |
| **#209** | Three refusals in the emitters: a **spent** destination (the claim set now carries the replay's `SRC` rows), the **reserved** zero ordinal, and a **redirected destination group** in group mode. Group mode also refuses landing a live claim on a spent name — the same invariant through the sibling door, which the issue did not name. The lift got its own reserved-ordinal gate (it was safe only by the `destination-not-established` side effect). |
| **#209 fork** | `renumber-map` now takes `<child>=<start>` per fresh child, fed verbatim from `peek spec <child>` — the merge-map precedent applied to split. Required, not defaulted, so a forgotten peek fails at map time rather than at Close. A never-seen name still peeks to `001`; a retired name resumes above its high-water. SKILL.md + methodology updated. |
| **#213** | `alloc_group_has_records` counts a group-rename **destination** as coverage. Chained group renames work; pinned on both surfaces (emitter source gate, sweep's `uncovered-groups`). |
| **#207** | The lift's batch decision moved out of the publish builder's memory into `alloc_lift_states`, where the whole row set is visible: both sides are claims, recorded renames index both their sides (so a re-run refuses what an earlier run recorded past), first-recordable-wins marks the *later* duplicate, and the realize kind gained destination closure. The publish builder now appends `emit` rows as-is — preview, payload, and published records are one computation. |
| **#212 + #138 + #206 AC-17** | Ordinal legality is one predicate (`alloc_valid_ord`, seven inline comparisons folded in; the constant is compared in exactly one function). `move-spec-dir`'s exactly-3 gates widened to the canonical `{3,15}` — the >999 dead end is closed. `isord`'s 3-digit floor is recorded as the deliberate canonical-spelling rule. A cross-file fixture extracts every site's value and binds it to the constant, with a tree-wide guard against a *new* script gaining a width literal. |
| **#205** | `check_pending_provisionals` slug-gates each group before the glob. Rename/split byte-identical (already gated at entry); merge no longer reports a traversal component as a clean pass. |
| **#206 remainder** | A concurrently renamed **source** group now refuses with the `group renamed` marker and the redirect named (the retryable shape every split source shares); the destination-group redirect names its real remedy (rewrite the `<new-id>` column, not a plain re-run); the lift's unknown-kind path sanitizes every echoed token; `reconcile.sh` gained a `display_field` sanitizer, used on the unusable-group halt. |
| **#208** | Script half: the provisional list discloses its display cut. Skill half: Step 2 enumerates via `jimfile.sh glob specs` (the instruction previously globbed *numbered* dirs, so it could never fire), presents each basename backtick-quoted one per line capped at ten with a counted tail, and the Validation Checklist restates the obligation where the summary is composed. |
| **#215** | The byte fixture extended to the three `prov_id_boundary` shims (each pinned verbatim — they legitimately differ) and the three `PROV_PREFIX` constants. **Mutation-tested**: loosening a shim fails the case; reverting passes it. |
| **#216** | `alloc_sanitize_field` moved into the record layer as a primitive. The call direction was right (gate a degraded field once, where it is read); the header claimed a purity the code lacked. |
| **#217** | `local c4 canon` restored, dead `g` dropped, pinned by a leak check. |
| **#218** | The memo never warmed **at all**, not merely across passes. Measured through a wrapper: 826 jimfile subprocesses per sweep, 535 of them repeats (the retired group name alone crossed 106 times). `alloc_warm_token_memo` walks the logs in the sweep's own shell before the tree derivations and every later pass fork. **Sweep 14.2s → 9.2s; forks 826 → 291, each distinct token exactly once**, pinned by a crossing-count fixture. |
| **#219** | `alloc_malformed_count` consults `alloc_known_verbs` before counting, so `group realize` lands in one counter, not two. |
| **#210** | The vacuous `vacated-max` case and two orphaned headers deleted; the surviving retirement case's header now says what its case asserts. Five fixtures added: group-arm and issue-arm provenance discriminators, issue self-rename survival, the lift's `group` kind end to end, `pair-events`' three row kinds plus its fail-closed gates, and `move-spec-dir`'s refusal of a malformed provisional source. |

---

## 3. Current anchors (`jimalloc.sh`, 3,980 lines)

Confirm before trusting — this file moves under exactly the work that touches it.

| Anchor | What it is |
| :--- | :--- |
| `:158` `alloc_sanitize_field` | field sanitizer, now a **record-layer** primitive (#216) |
| `:190` `alloc_warm_token_memo` | the pre-fork memo warmer (#218) — advisory by design |
| `:314` `alloc_valid_ord` | **the** ordinal-legality predicate; the constant's only comparison site |
| `:488` `alloc_realize_fold` | **the** duplicate-realize decision (#214) |
| `:525` `alloc_malformed_count` | non-coverage counter, now verb-aware (#219) |
| `:595` `alloc_resolve_spec` | forward-replay; refuses a conflicted provisional |
| `:831` `ALLOC_MAX_ORD_DIGITS=15` | the one named width constant |
| `:1651` `alloc_classify_spec` | integrity classifier (locals restored) |
| `:2701` `alloc_group_has_records` | group coverage, now counting rename destinations (#213) |
| `:3293` `alloc_live_claim_set` | fills `live` **and `spent`** — callers must declare both |
| `:3315` / `:3396` | spec / group partition emitters — the new refusals live here |
| `:3605` `alloc_lift_state` · `:3670` `alloc_lift_states` | the lift's decision + the in-batch guard (#207) |
| `:3782` `alloc_lift_publish_builder` | now appends `emit` rows as-is |

`tests/jimalloc.sh` is 4,504 lines. Width-bound and shim fixtures live in
`tests/jimfile.sh`; `pair-events` and move-gate fixtures in `tests/jimledger.sh`.

---

## 4. What remains

### 4a. The deliberate review — and the trap in running it

The prior note's § 2 named the build shape's known cost: **no spec directory
means `/jim:review` has nowhere to land**. That is now the live problem, and it
has a hazard the note did not anticipate.

**Do not point `/jim:review` at `docs/specs/blueprint/025-…`.** The skill
overwrites `review.md` on a re-run ("latest snapshot wins"). That file is the
**primary source** for every one of #205–#219 — overwriting it destroys the
provenance the whole cluster cites.

Three ways out, in the order I'd try them:

1. **Run the review's method, not its artifact choreography.** Triage the
   `175047c..HEAD` diff into a high-stakes set, fan investigators out over it,
   judge against the sixteen issue contracts (they are the spec surface here),
   and record the result as a dated note under `docs/notes/`. This is what the
   review *is*; only its filing convention assumes a spec.
2. Point the skill at `025` but redirect its write to a new filename — cheaper
   to describe than to do, since the skill hardcodes `{spec-dir}/review.md`.
3. Give B′ a minimal spec directory. Costs an ordinal and contradicts the
   cluster's own "B′ rides B's slot, it is not new work" rule.

Whichever path: the sixteen issues' *Proposed action* sections are the
acceptance criteria to judge against, and several were exceeded rather than
merely met (see § 5).

### 4b. Close the issues

**None of the fifteen are marked closed** — the work landed, the tracker did
not move. Closing is a direct frontmatter edit (`status:` in each issue file);
there is no close verb. `#211` stays open for its surviving site. Both
fold-restoration obligations (#209, #212) are **discharged** — say so in the
closing note, since each issue's body makes restoration a condition of closure.

### 4c. Update the cluster note

`docs/notes/20260728-id-coordination-issue-grouping.md` is the running record
and does not yet know B′ shipped. It needs a *What B′ changed* section and its
per-issue disposition table updated. Two corrections belong there too (§ 6).

### 4d. Still adjacent, still not B′'s

Unchanged from the prior note's § 9: `#161`–`#167` (seven `sdlc` drifts, three
critical — still the highest-criticality open set), `#107`/`#108`/`#186`,
`#153`, `#204`, and `#211`'s survivor. **`#188` did not land** — see § 7.

---

## 5. Established this session — do not re-derive

**The contract graph is sound.** `--contracts` over the whole graph: 14 edges,
310 `CROSS-REF` facts, **every fact lands on a declared edge** (zero leak
candidates), coverage 4/4, two evidence-capped pairs disclosed
(`sdlc→issue`, `sdlc→platform`). Ten judged sides, **all hold**:
`blueprint→jimalloc` (both), `issue→jimalloc` (both), `blueprint→jimledger`
(both), `sdlc→jimledger` (both), `sdlc→jimfile` (provider),
`platform→validator-lockstep` (consumer). No face carries `contract-checks`
data, so every side rode the floor + judge ceiling; the 18-side remainder was
named as unexamined at the fan-out cap. Recorded: `verify finished tier=project
op=contracts edges=14 holds=10 violated=0 … leaks=0 breaking=0 dead=0`.

**Seven platform invariants judged over the change** (`--since 175047c`):
`no-source-eval`, `ref-validation`, `relpath-validation`,
`ledger-commit-discipline`, `tests-under-tests` all **hold**;
`ordinal-single-source` and `blueprint-slot-reserved` came back **violated
in-change** — both because the folded text *understated* the code, which is what
the restoration then fixed. The floor was change-scoped and clean. The registry
rung cannot be range-scoped in `--since` mode (named omission; the on-demand
sweep was clean).

**Two judge observations that are not defects** but are worth keeping:

- **Issue-side mints skip the width recheck** the spec side does. `alloc_next_num_issue`
  and `alloc_reconcile_realize` emit `max+1` without the `alloc_valid_ord`
  recheck that makes the spec side say "group exhausted". Reachable only if a
  crafted record already sits at the 15-digit ceiling. Filed nowhere.
- **`jimalloc`'s provisional acceptor is broader than `jimledger`'s source gate.**
  `is_prov_token` routes through `valid-id`, which admits uppercase and dots;
  `move-spec-dir`'s source shape is lowercase-only. A hand-crafted
  `P-20260801-Foo.bar` would be movable nowhere. The minting path cannot produce
  one, so nothing legitimate is stranded. Filed nowhere.

**Three issues' stated scopes were wrong, all measured this session** (§ 6).

---

## 6. Corrections to the record

**The prior handoff's § 4 width table is wrong in two directions**, and its
§ 7 has one claim that is now false.

1. **The `{1,15}` "accepted set" is not drift.** `jimfile.sh:403`/`:415` are the
   occupancy predicate's *numeric-acceptance* rule — `18` and `018` are one
   ordinal, deliberately, documented in `spec_ordinal_holder`'s own header. It is
   a second coherent rule sharing the ceiling, not a third incompatible width.
   The real defect was `move-spec-dir`'s exactly-3, and that is fixed.
2. **`reconcile.sh` holds a tenth deciding site** the issue never counted (two
   `{3,15}` spellings). Found by the tree-wide sweep written *for* the fixture —
   the omission class the per-file counts could not see. So: nine sites claimed,
   ten real, and the "three incompatible sets" framing was two rules plus one bug.
3. **"`tests/` contains no reference to `ALLOC_MAX_ORD_DIGITS`" is now false** —
   `case_jimfile_ordinal_width_bound_single_sourced` is that reference.

This is the cluster note's practice 7 paying out a third time: a stated scope is
a claim, not a measurement. It has now been wrong in *both* directions —
under-counting sites and over-stating incoherence.

---

## 7. Traps — the prior note's § 8 still applies, plus these

The prior note's eight traps all held this session (the suite really does exceed
a 600s foreground timeout; the coordination remote really is unreachable). Four
additions and one **live warning**:

1. **⚠ The session model changed to Opus 5 at the end of this session.** Trap 8
   in the prior note — the `heron_brook` directive suppressing agent fan-out — is
   **gated on the `opus_5_prompt_bundle` capability**, i.e. it applies to Opus 5
   and not to Fable 5. This session ran 17 subagents on Fable 5 with no
   suppression whatsoever. **The next session runs the review, which is the most
   fan-out-dependent step in the whole cluster, on the model the directive
   targets.** Authorize the fan-out explicitly, and verify the investigators
   actually ran rather than trusting the report. This is `#188`, still open,
   still caught by a person rather than a mechanism.
2. **`alloc_live_claim_set` now fills two arrays.** Any new caller must declare
   `local -A live=() spent=()`. A missing `spent` declaration leaks to global
   scope — the exact class #217 was about.
3. **Four git-heavy test files together exceed a 600s foreground timeout**
   (`jimalloc` + `jimledger` + `jimfile` + `specreconcile`). Run them singly or
   background the set.
4. **`git stash` alone does not isolate a mutation test** when the tree holds
   both test and source edits — stash the *one* file
   (`git stash push -q <path>`), or the filter matches zero cases and the run
   reports `Ran 0 tests` as a pass.

---

## 8. Reference

**Useful, and known to work here:**

```bash
bash skills/file/scripts/jimalloc.sh sweep                     # ~9s now, was ~14s
bash skills/file/scripts/jimalloc.sh lift                      # preview: 54 rows, all `have`
bash skills/verify/scripts/jimverify.sh edges BLUEPRINT.md     # the 14 contract edges
bash skills/verify/scripts/jimverify.sh contracts-check BLUEPRINT.md
bash skills/verify/scripts/jimverify.sh parse docs/specs/platform/000-blueprint/spec.md
bash skills/issue/scripts/render.sh show <num>
bash skills/meta-test/scripts/run.sh                           # background it: 1137 tests
```

**Session shape that worked, again:** reproduce every defect before believing it
and again after fixing it (all four #207 shapes, both #209 contradictions, the
#218 fork count); mutation-test any fixture written for a contract that has never
been observed failing (#215's shim pin, #218's crossing count — both were flipped
deliberately and confirmed to fail); and measure a stated scope rather than
inheriting it, because this cluster has now mis-stated three of them.
