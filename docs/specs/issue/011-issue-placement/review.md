---
spec: "issue/011"
type: feature
base_sha: "f024b9e378c27935874da4a6533bcfbc6bc648cc"
head_sha: "3c1a78f57834e6fca19a259dddd71f509e166ee5"
commits: 15
commits_test: 0
commits_feat: 11
commits_fix: 0
commits_refactor: 0
files_changed: 19
insertions: 2905
deletions: 32
spec_runs: 1
spec_interruptions: 0
spec_duration_seconds: 6385
research_runs: 1
research_interruptions: 0
research_duration_seconds: 1062
plan_runs: 1
plan_interruptions: 0
plan_duration_seconds: 34395
sec_runs: 2
sec_interruptions: 0
sec_duration_seconds: 37569
build_runs: 1
build_interruptions: 0
build_duration_seconds: 13717
review_runs: 2
review_interruptions: 0
review_duration_seconds: 42661
artifacts_present: [spec, research, security, plan, ledger]
plan_deviations: 4
security_regressions: 5
invariant_violations: 5
contract_violations: 2
alignment: major-drift
date: "2026-08-07"
---

# Review — issue/011 Issue placement (second pass)

## Summary

**`major-drift`.** This is the second review of this spec. The first found four
reproducible data defects; a fix pass closed them, and this review was run over
the result.

Three of the four original fixes hold up under independent scrutiny. The fourth
— the deferred-publication resumption — **introduced a new critical defect of
exactly the class it was written to close**: a mutation that was deferred while
the remote was unreachable is silently dropped, at rc 0, if the next reachable
run's first push loses a race. The AC #13 gate added in the same pass works, but
rests on a fail-open default that three artifacts describe as fail-closed.

The honest summary is that the fix pass traded four reproducible defects for one
critical, three high, and a longer tail — and that the defects it introduced are
narrower and rarer than the ones it removed, but not different in kind.

**Range reviewed.** The ledger's recorded `head_sha` (`3c1a78f`) is the build's
finish and predates the fix pass, so the frontmatter metrics above describe the
build alone. This review covers `f024b9e..2f7e6ed` — **41 commits, 55 files,
+5722/−67** — using `jimledger.sh files-range`/`diff-range` rather than the
build-pinned `files`/`diff` verbs. Both ranges are reported under *Metrics*.

**Coverage.** 14 investigators + judges dispatched at `thorough` depth against a
`review_fanout_cap` of 10 — the developer authorized exceeding it. 12
investigators over the change (deferred resumption, CAS threading, the direct
arm, the emitter gate, AC-13 consumer coverage, index regeneration, rewrite
detection, test non-vacuity, default-path invariance, the omission class,
security, the remaining ACs), all 12 returned; **0 undelegated**. The
living-intent sensor then ran 8 invariant judges + 2 contract-edge judges.
Blueprint liveness was checked: `issue` is live in `BLUEPRINT.md` (rc 0, declared
territory).

Everything the fan-out found in the fix pass is in code this reviewer wrote. That
is the intended use of the fan-out, and it is why the verdict is not a
self-assessment.

## Alignment vs spec

| AC | Verdict | Note |
| :--- | :--- | :--- |
| 1 — one key, `branch` sentinel | satisfied | the sentinel returns before the coordination-branch lookup, so a junk `id_coordination_branch` cannot break a default project |
| 2 — default behavior unchanged | **satisfied** | independently traced: no new code path, no new subprocess, and `place_resolve_tips` / the bookmark / `place_reindex` are all unreachable under the default. The whole-argument substitution change is behaviorally identical for the empty-token passthrough case |
| 3 — every write lands at the destination | **partial** | `reconcile.sh -c <cfg>` still skips routing (F16); `render.sh list <non-filter-token>` bypasses routing and creates a stray dir (F17); `issues`-path drift in the direct arm publishes the wrong thing at rc 0 (F9); body edits/status changes have a documented two-phase route but no mechanical one |
| 4 — one commit per mutation | satisfied | verified on both tiers; no empty commit on a no-op, including the stale-index case |
| 5 — reads serve the destination | **partial** | fixed for the offline read (#267) and the index (#276); `insights` still analyses two collections (F5) |
| 6 — freshness, loud degrade | **partial** | the read now serves what it last saw; a mid-run tier degradation still lands locally with no disclosure (F8) |
| 7 — writes never silently lost | **violated** | F1 (critical) and F2 (high) — both new |
| 8 — orphan bootstrap | satisfied | parentless commit, collection alone, create-if-absent CAS on both tiers |
| 9 — coordination branch refused | satisfied | follows the configured name; fails closed when the guard cannot be established |
| 10 — junk value refused | **partial** | the refusal is correct and propagates, but all six doors test an explicit directory *before* consulting the gate |
| 11 — dangling origin tolerated | **partial** | rc 0 and nothing blocked; the published index churns per-mutator (tracked #273), and the regression test uses a non-path-shaped origin so the AC's case is still unexercised (F23) |
| 12 — rewrite detected | **partial** | a genuine force-push is still detected; the retry loop never re-checks (F12) and direct mode never checks at all (F13) |
| 13 — auto-file keeps a scrub moment | **satisfied, with a caveat** | the degrade, the disclosure and the `issue_placement_ack` escape are all mechanical and reachable on every publishing path, and all nine consumers honor them. But the trigger is a caller-supplied declaration whose default is "reviewed" — see F3 |

## Alignment vs plan

Four deviations, all disclosed, two approved during this session:

- **DD 9 and Open Question `plan.md:269` are superseded** (approved this
  session). The plan records "Where AC #13 is enforced → §7a + `issue_placement_ack`",
  and task 11 scopes that edit to `skills/issue/SKILL.md` alone. The first
  review proved that reasoning wrong for a behavioral branch; AC #13 is now
  enforced in the emitter. The plan text still asserts the disproved design.
- **DD 5 is inverted.** It states "the destination's index is always current —
  **reads never regenerate**", and rejects "committing regen from the read path"
  because it "turns reads into writes". The fix pass made reads regenerate
  (in a discarded copy, so reads still commit nothing). Resolved fix-code at the
  blueprint fork, but the plan's DD text now describes the opposite of the code.
- **`place.sh mode` verb** (approved at build) — not in the plan's interface
  contract.
- **`JIM_PLACE_ACTIVE` not set** (disclosed at build) — task 7's contract names
  it; a boolean that also suppresses routing would reinstate security Finding 10.

Task 13's additions-only evidence **still holds** over the full range: `tests/`
shows +1960/−3, and all three deletions are the unavoidable `tests/jimconf.sh`
key-registry assertions. The fix pass rewrote test cases that this spec's own
build had added, so they net as additions against the baseline.

## Alignment vs architecture

Conventions hold in the fix pass: `set -uo pipefail` + `LC_ALL=C`, no
third-party deps, BASH_SOURCE-relative composition, no spec IDs in script
comments, trusted-enum commit subjects, `--literal-pathspecs`. No `eval`, no
`source`, no unquoted expansion reaching a command.

Gaps:

- `ARCHITECTURE.md`'s bookmark sentence states a property the code holds only on
  the plumbing path (F19).
- Three artifacts state an inverted fail-direction (F3).
- 25 of 41 commit subjects exceed CLAUDE.md's 50-character limit — 10 of the 14
  fix-pass commits among them (F26).
- `place_commit_changes`' contract comment documents nine parameters; the
  signature takes ten (F27).
- `place_land`'s two `git update-ref` calls are the only git invocations in
  `place.sh` without `--end-of-options` (F28).

## Findings

### F1 — the `ahead` deferral arm loses the deferred commit on a lost race

**Critical. New in the fix pass.** `place_resolve_tips` runs once
(`place.sh:1183`), but `place_commit_changes` re-reads the tip on every retry
(`:1280`) without re-resolving the triple. In the `ahead` state `PLACE_BASE_TIP`
is the local head (`:370-372`), so `before` is a snapshot that **already
contains** the deferred content. Attempt 1 relies on the deferred commit being
the parent. When that push loses a race, attempt 2 re-parents onto the new remote
tip, and the deferred paths are in neither `touched` set at `:1039-1044` —
`before == after` for them — so they are never replayed. `place_land` then
force-advances the local ref past them and `place_advance_bookmark` records the
result, so no later run detects it either.

Net: rc 0, no stderr, the deferred mutation gone from both remote and local
branch. AC #7: "No mutation is ever silently dropped."

The `diverged` arm does not have this bug — its base is the merge-base, so every
deferred path lands in `touched`. The fix shape is that an `ahead` state that
loses a race *is* a `diverged` state on the next attempt: recompute the base as
`merge-base(PLACE_WORK_TIP, new_tip)` inside the retry loop. The same defect
reaches the two-phase flow, which persists only `tip` and the base snapshot.

### F2 — the `diverged` arm has no conflict check on attempt 1

**High. New in the fix pass.** `place_regraft`'s conflict rule — refuse at rc 3
rather than erase a concurrent edit — runs only on attempt ≥ 2 (`:1255`). In the
ordinary race that suffices, because the concurrent edit arrives after the tip
read and the push is rejected. In the deferred/diverged case the teammate's edit
is **already at the remote tip** when the run reads it, so `place_build_commit`
writes our blob over theirs, the push is a fast-forward, and it **succeeds**.
Their published content is reverted at rc 0 with no path named — only the generic
"moved on … being reapplied" line. The symmetric case is covered at
`tests/place.sh:892` and returns rc 3; this asymmetry is unguarded and untested.

### F3 — the `--auto` gate is fail-open, and three artifacts claim the inverse

**High (security). New in the fix pass.** `auto` initializes to `0`
(`new.sh:65`) and the gate is `if (( auto )) && …` (`:119`). A skill on the quiet
path that **omits** `--auto` therefore skips the gate entirely and publishes the
unreviewed batch — precisely what AC #13 exists to prevent. The safe-sounding
case is the other omission.

Three artifacts assert the opposite: `new.sh:117-118`, `skills/issue/SKILL.md:247`,
and `ARCHITECTURE.md:395` all say a caller that forgets the flag "gets the
interactive bargain rather than a silent publish, which is the safe direction to
fail."

The mechanism works as built — all nine consumers pass the flag and handle rc 4,
independently verified — so AC #13 is satisfied today. What is not defensible is
a security property documented as holding that the code inverts. The genuinely
fail-closed polarity is the inverse (treat every filing as unreviewed; the
interactive path opts out with `--reviewed`), which is a design fork with a real
cost: every interactive caller, including `/jim:issue add`, then carries a flag.
Reported, not prescribed. The compensating control is `tests/docsurfaces.sh`,
weakened by F21.

### F4 — `cmd_begin` returns rc 0 when the containment gate refuses

**High (security). Pre-existing; the fix pass edited the line and left it.**
`place.sh:644-648` uses `if ! place_materialize …; then local mrc=$?`. Inside the
body of `if !`, `$?` is the status of the negated pipeline — always 0. A Critical
containment refusal reaches the caller as **success with empty stdout**, so an
agent following `SKILL.md`'s contract holds an empty `<dir>` and edits relative
paths in the project checkout. Nothing escapes the temp root and no publish
follows, so this is a lost signal rather than a filesystem escape.

The fix pass changed this very line (`$tip` → `$PLACE_WORK_TIP`) without fixing
the bug the first review had already filed. `cmd_run:1192` and `place_regraft:1035`
both get it right with `|| return $?`. Still the only `if ! cmd; then x=$?` in the
repo, and still untested — the traversal fixture is driven only through `run`.

### F5 — `insights` analyses two different collections

**High. Pre-existing, tracked as #266, still live.** `agents/issue-analyst.md:45`
still says "Read the individual `docs/issues/*.md` bodies". Steps 1–2 use the
handed `<dir>`; step 3 does not. Under a placement the roster, ordinals and graph
come from the destination while the bodies come from the branch-local collection
— and the view header renders `<dir>`, labelling the result as the destination's.
Slugs present only at the destination fail to read; slugs present in both
silently supply the stale body. The analyst is the terminal reader, so nothing
downstream can catch it. The same defect bites any project whose `issues` key is
not `docs/issues`, placement or not.

### F6 — the local-tier retry reads `tip` before `ref_old`

**Medium. New in the fix pass.** `place.sh:1286-1287` (and `:1282-1283`) read the
tip and the CAS old-value as two separate `git rev-parse` invocations, tip first.
A racer landing between them yields `tip=B, ref_old=C`; the run then builds on
`B` and swaps against `C`, which **matches**, so `git update-ref` — which has no
fast-forward check — replaces `C` at rc 0. The racer's mutation is lost silently.

The window is one process spawn, on the local tier, inside the retry path — which
is entered only under active contention, i.e. exactly when a racer is running.
Both *initial* capture sites (`:1168`, `:627`) are correctly ordered, and
`jimalloc.sh` avoids this by reading the ref once. Swapping the two lines
restores the conservative order.

### F7 — the `diverged` arm publishes an index omitting the other side

**Medium. New in the fix pass.** In the diverged case `INDEX.md` is regenerated
over `PLACE_COLL`, materialized from the local head, so it never saw the
teammate's issue — but it differs from the base snapshot and is therefore
written. The published tree carries their issue file and an index that omits it.
`place_regraft` handles this correctly by excluding `INDEX.md` from the graft and
regenerating over the merged result; attempt 1 in the diverged case has no merged
directory and no equivalent. Self-heals on the next write.

### F8 — a mid-run tier degradation lands locally with no disclosure

**Medium.** `place_commit_changes:1279-1284` degrades origin→local on its own,
but both deferral notices key on state fixed before the loop — `cmd_run:1212` on
`unreachable` (computed at `:1174`) and `cmd_commit:748` on the handle's recorded
`tier`. A run whose remote drops mid-loop commits locally and returns rc 0 saying
nothing. Resumption picks it up, so nothing is lost, but AC #7 says the
degradation is reported.

### F9 — `issues`-path drift in the direct arm publishes the wrong thing at rc 0

**Medium.** `cmd_commit`'s direct arm re-resolves `prefix` (`:707`) while the
handle arm reads it from recorded state. If `issues` changes between `begin` and
`commit`, `place_direct_publish` reindexes and stages the **new** prefix;
`index.sh` creates it, so `git status` is non-empty, the early-return does not
fire, and a fresh empty-collection `INDEX.md` is committed and pushed to the
shared branch. The agent's actual edits under the old prefix are never committed,
and the caller sees rc 0.

### F10 — `commit direct` with no preceding `begin` runs no dirty guard

**Medium (security).** The token is a fixed literal, callable at any time; the
arm's own comment concedes "there is no evidence in the token that a `begin` ever
happened at all". The HEAD and sentinel re-checks added by the fix pass close the
branch-switch harm, but nothing re-runs the dirty guard — and it genuinely cannot
be re-run, because at commit time the mutation's own edits *are* the dirty state.
So `place.sh commit direct --verb close --id <valid>` publishes whatever
uncommitted work sits in the collection: security Finding 9's harm, on the one arm
where nothing proves the guard ran. Closing it needs a different shape (a
begin-issued marker), not a guard call.

### F11 — a placed read hard-fails where the group's read discipline is tolerant

**Medium. New in the fix pass.** `place.sh:1199` is
`place_reindex "$PLACE_COLL" || return 1`. `render.sh`'s own `ensure_index` is
deliberately the opposite (`|| true`, commented "tolerant of failure"). An IO
failure inside `index.sh` now turns a read that would previously have served the
destination's existing index into rc 1. Defensible under "never serve a stale
view", but it is a behavior change on a read path that diverges from the group's
stated discipline, was not decided deliberately, and is untested.

### F12 — the retry loop never re-checks for a rewrite

**Medium.** `place_commit_changes` re-fetches the tip on every retry and calls
`place_check_rewrite` nowhere in the loop. If the rejection was caused by a
force-push, the run regrafts onto the rewritten tip, lands, and advances the
bookmark to a commit built on it — so the rewrite is neither disclosed nor
detectable afterwards. Narrow (a lost race concurrent with a rewrite), but it
erases its own evidence.

### F13 — direct mode has no rewrite detection at all

**Medium.** `cmd_run` routes to `place_direct` and `cmd_begin` returns early;
neither reaches `place_check_rewrite`. AC #12 says "the read verbs", and a read
verb run from a checkout of the destination performs no ancestry check whatever.

### F14 — §7a's canonical emitter snippet omits the flag it requires

**Medium (security). New in the fix pass.** `skills/issue/SKILL.md:226-230` is
billed as *the* emitter call shape — and the blueprint's Provides face declares
"the emitter call shape, defined once in this group's `SKILL.md`" as the
guaranteed surface. It shows no `--auto`, not even the optional `[--auto]` form a
consumer already uses. The rule requiring the flag arrives three paragraphs later.
Given F3's fail-open polarity, the one artifact a consumer copies encodes the
unsafe case.

### F15 — §7a's applicability roster is wrong in both directions

**Medium.** `skills/issue/SKILL.md:213` enumerates "the eight surfacing skills"
including `/jim:partition` (which never auto-files) and omitting `/jim:review`
and `/jim:verify` (which both do). It is the sentence a consumer reads to decide
whether §7a binds it, so review and verify read a contract that on its face is
not addressed to them. `new.sh:115` and `ARCHITECTURE.md:395` both say nine.
Latent — both comply today — and partially tracked as #45.

### F16 — `reconcile.sh -c <cfg>` still skips routing

**Medium. Pre-existing, tracked as #277.** The routing loop has no `skip_next`,
so `-c` matches `-*`, its value matches `*)` and becomes `dir`, and routing
returns before `place.sh mode` is called — `--apply` then rewrites the
working-tree collection. `migrate.sh` has the exact `skip_next` this lacks. Also
means reconcile's routing can never be exercised through the `-c` fixture path.
Audited the same bug class across all five loops: `index.sh` and `backfill.sh`
are clean (no value-taking flags), `migrate.sh` is correct, `render.sh` has a
different classification defect (F17).

### F17 — `render.sh list <non-filter-token>` bypasses routing and litters

**Medium. Pre-existing.** `dir_given` classifies a single non-filter `list`
argument as a directory, so routing is skipped, `cmd_list` sets `dir` to the
token, and `index.sh` `mkdir -p`s it — creating a stray `<token>/INDEX.md` in the
developer's checkout under a placement. Reachable from a user typo, since
`SKILL.md:36` forwards the argument string verbatim.

### F18 — `WORKFLOW.md` tells the user to close an issue by editing it directly

**Medium.** `WORKFLOW.md:127`: "Close an issue by editing its `status:` field
directly." Under a placement that file is not in the working tree. The correct
two-phase flow exists only in `skills/issue/SKILL.md` §6a — which
`tests/docsurfaces.sh` guards precisely because the flow "has to stay documented
where an agent editing an issue will look", while sweeping only `SKILL.md`.
`WORKFLOW.md:215`'s skills tree also still omits `place.sh` and `reconcile.sh`.

### F19 — `ARCHITECTURE.md`'s bookmark claim is plumbing-path-only

**Medium. New in the fix pass.** The refresh states the bookmark "records the tip
this clone last *saw at the destination* … a commit that only ever reached this
clone does not advance it." True on the plumbing path; false in direct mode,
where `place_direct_publish:484` advances it before the push and never rolls back
on rejection. The sentence states an invariant as achieved that one writer
breaks. The fix pass created the invariant and did not bring that writer into it.

### F20 — the blueprint's `new.sh` Provides face omits `--auto` and exit 4

**Medium.** The entry documents stdout, failure codes, identity and atomicity, and
says "the file lands wherever `issue_placement` directs" without qualification —
but rc 4 means nothing lands. This is the group's widest fan-in provides face,
consumed by nine skills in another group. There is also no invariant for the
scrub gate, so `/jim:verify issue` can never check AC #13 even though
`tests/docsurfaces.sh` proves the property is mechanically checkable. Judged
**not** `breaking`: the gate is guarded by `(( auto ))`, so a consumer written
against the declaration alone can never receive rc 4, and the sibling §7a entry
does document it.

### F21 — the docsurfaces sweep proves mention, not handling

**Medium. New in the fix pass.** `tests/docsurfaces.sh:197-198` greps each file
for `new\.sh \[\?--auto` and the literal `exit code 4`. Both are **file-scoped,
not branch-scoped**: a skill whose `--auto` sat on its *interactive* emitter call
while the auto path omitted it would pass, and the second grep proves the phrase
appears, not that anything handles the code. The test also never checks that the
fallback target exists. Structurally the same weakness as the §7a pointer the
first review faulted — proximity asserted, binding not. Latent; current code is
correct by manual reading.

### F22 — `BLUEPRINT.md`'s `issue` territory omits `tests/place.sh`

**Medium.** The declared territory is `skills/issue`, `agents/issue-analyst.md`,
`tests/issues.sh`. Every other group enumerates its test files individually, and
`tests/place.sh` is the **only** unclaimed test file in the repo — so it is an
omission, not a convention difference. The group's own blueprint names it twice.
With `group_territory = "declared-paths"`, a change to this group's largest test
file maps to no group: invisible to blast-radius attribution and to `/jim:verify`
scoping, and it counts toward the partition-health `uncovered` signal.

### F23 — the dangling-origin test still does not exercise a dangling origin

**Medium. The fix pass changed this case and did not fix it.** The origin
`docs-only-here.md` contains no `/`, so `index.sh`'s `*/*` guard exempts it from
the lint entirely — the file's existence is never checked either way. Removing
the working-tree file (the fix pass's change) was therefore a no-op. A
path-shaped origin resolvable only on the filing branch remains untested, which
is also why F24's churn is unexercised.

### F24 — placement turns the origin lint into published churn

**Medium. Pre-existing, tracked as #273.** `index.sh` resolves `origin:` against
the invoking CWD while writing the destination's index, so the Integrity Warnings
block is a function of which branch the last mutator stood on. The fix pass
widened the blast radius: reads now regenerate too, so a reader on a divergent
checkout is served the flapping warning set (harmlessly, in a discarded copy).

### F25 — `SKILL.md` §6's ordinal read-back is unachievable under a placement

**Medium.** §6 tells the agent to read the written file's `num:` back from the
printed path. Under a placement that path is destination-relative and not in the
working tree, and the emitter's stdout carries slug and path only — so there is
no route to the ordinal at all. The likely recoveries are both bad: re-running
`new.sh` allocates a **second** coordinated ordinal, or hand-composing breaks
`single-emitter`. §6a got a placement arm; §6 did not, and `SKILL.md:17`'s "Only
two places need to know" is now wrong — it is four.

### F26 — commit subjects exceed the 50-character limit

**Low.** 25 of 41 subjects over the full range, including 10 of the 14 fix-pass
commits. CLAUDE.md: "Subject: all lowercase, imperative mood, 50 characters or
less". Pre-existing as a pattern; continued rather than corrected.

### F27 — `place_commit_changes`' contract comment is stale

**Low. New in the fix pass.** The header documents nine parameters; the signature
takes ten. `place_land`'s comment *was* updated for the same change.

### F28 — lower-severity residue

**Low.** Grouped: `--title '{}'` exactly is still substituted (the narrowing
closed contains-braces, not equals — durable-id consequence unchanged);
`cmd_begin:653-654` flattens a containment refusal from rc 2 to rc 1 where
`cmd_run:1192` preserves it; the docsurfaces non-vacuity guard asserts `n >= 8`
against 9 actual consumers, so one skill can leave the sweep silently;
`skills/verify`'s `[--auto]` bracket notation is the weakest of the nine
restatements; `skills/meta-skill`'s authoring checklist does not carry the gate;
`place_land`'s two `update-ref` calls lack `--end-of-options`; `place_snapshot`
is the only collection enumerator that does not exclude the `.tmp.*` namespace,
so a stranded tmp is publishable; `migrate.sh`'s commit phase deletes every old
name before renaming any, so a mid-loop failure leaves files with neither;
`migrate.sh:67`'s header asserts the collision discriminator is re-validated when
it is not; `place_seed_traversal` checks none of its own exit statuses; two
`rev-parse` baselines in `tests/issues.sh` still lack `--verify`;
`stale_dest_index` drops sibling paths outside the collection prefix (latent);
the direct arm's HEAD-mismatch message misattributes what `begin` saw; the direct
arm returns a repo-relative dir where the plumbing arm returns absolute.

## Test quality

The fix pass repaired the four cases the first review named, and the repairs
hold: the vacuous cleanup case now has a landing assertion, the two "tip unmoved"
cases run against a stale destination index that gives read-only routing
something real to discriminate on, and `place_seed_collection` checks its own
statuses. The local-tier retry case genuinely drives the local tier and genuinely
loses a race. Twenty-three of the new cases were confirmed to kill a specific
named mutation.

Three problems remain, two of them introduced by the fix pass:

- **`case_place_direct_commit_refuses_the_branch_sentinel` cannot catch its
  named mutation.** Delete the sentinel guard and control falls to the very next
  guard, which returns the same rc 2 with a non-empty message. It asserts only rc
  and non-emptiness, so it is green either way — indistinguishable from its
  neighbouring case. Pinning the distinguishing text fixes it.
- **`case_issues_placement_preview_publishes_nothing`'s reconcile half is
  non-discriminating.** Delete `route_placement` from `reconcile.sh` and the
  preview runs against a non-existent working-tree collection, prints "no pending
  provisional issues", and returns 0. The migrate half *is* discriminating.
- **The dangling-origin case still tests nothing** (F23).

Worst remaining coverage holes: **no test asserts the bookmark ref's value at any
point**, so neither of the fix pass's two bookmark conditions is pinned — deleting
the `tier == origin || -z remote` guard leaves the entire suite green. Then:
`cmd_begin`'s dirty guard for a direct-mode write handle (deleting it leaves the
suite green and reopens security Finding 9); `begin` against a hostile tree (F4's
home); the rewind shape of rewrite detection; and the `--auto --dir` combination.

## Security regressions

Five, all placement-only, none of them a *new* weakening of the containment gate
— the security investigator confirmed the fix pass introduced no new regression,
and that the new git argument construction is validated, `place_base_snapshot`'s
`rm -rf` is not redirectable, and the `--auto` gate fails **closed** on a config
error.

1. **F3** — the scrub gate's polarity is fail-open on a forgotten flag, and three
   artifacts document the inverse.
2. **F4** — the Critical containment gate's refusal is invisible to `begin`'s
   caller (reporting degradation, not a gate weakening).
3. **F10** — `commit direct` publishes uncommitted work with no dirty guard.
4. **F14** — the canonical call-shape snippet encodes the fail-open case.
5. Pre-existing and unfixed: `place_direct_publish` stages without the
   worktree-top containment gate (#268), and `place_conf` discards jimconf's exit
   status so a failed read is indistinguishable from an unset key (fail-open on
   the infrastructure path).

## Living intent

The `issue` group blueprint exists, so the sensor ran — after the verdict was
assigned, and it did not change it. Appetite `low`, so every invariant was above
threshold; all 8 were change-selected and judged; **0 undelegated**. The floor ran
whole-group with no `UNSCOPED`; there are no `pattern`/`structure`/`registry`
invariants, so the floor contributed territory conformance only.

```
VERIFY-OUTCOME issue (adapter: from-review)
id=untrusted-body-never-shell criticality=critical rung=judge outcome=violated channel=in-change reason=- evidence=skills/issue/scripts/new.sh:260
id=materialization-contained criticality=critical rung=judge outcome=violated channel=in-change reason=- evidence=skills/issue/scripts/place.sh:644
id=placement-gate-before-git criticality=critical rung=judge outcome=holds channel=- reason=- evidence=-
id=id-gate-before-path criticality=critical rung=judge outcome=holds channel=- reason=- evidence=-
id=insights-capability-boundary criticality=high rung=judge outcome=violated channel=in-change reason=- evidence=agents/issue-analyst.md:45
id=single-emitter criticality=high rung=judge outcome=holds channel=- reason=- evidence=-
id=atomic-index-write criticality=medium rung=judge outcome=violated channel=in-change reason=- evidence=skills/issue/scripts/migrate.sh:225
id=staleness-gated-reads criticality=medium rung=judge outcome=violated channel=in-change reason=- evidence=skills/issue/scripts/render.sh:93
edge=sdlc>issue entry=emitter side=provider criticality=high rung=judge outcome=violated channel=in-change reason=- class=- evidence=docs/specs/issue/000-blueprint/spec.md:37
edge=sdlc>issue entry=emitter side=consumer criticality=high rung=judge outcome=holds channel=- reason=- class=- evidence=-
edge=sdlc>issue entry=candidate-batch-contract side=provider criticality=high rung=judge outcome=violated channel=in-change reason=- class=breaking evidence=skills/issue/SKILL.md:226
edge=sdlc>issue entry=candidate-batch-contract side=consumer criticality=high rung=judge outcome=holds channel=- reason=- class=- evidence=-
```

**8 sensed · 3 hold · 5 violated · 0 failed · 0 unconfigured · 0 skipped.**

- **`untrusted-body-never-shell` (critical)** — two gaps. `--origin` is *not*
  YAML-encoded despite the invariant naming it alongside title and labels; it is
  newline-collapsed and emitted as a bare scalar, which cannot inject a key but
  can change the parsed type. And the argv round-trip is not byte-for-byte for an
  argument that is exactly `{}` or `{token}`. The first is a pre-existing
  design-level divergence the code's own comment admits; the second is the
  residue of the fix pass's narrowing.
- **`materialization-contained` (critical)** — the gates themselves are all
  intact and blobs are still read by object name. The violation is F4's refusal
  flattening plus the rc 2 → rc 1 collapse at `cmd_begin:653-654`.
- **`insights-capability-boundary` (high)** — the main agent reads no bodies and
  the analyst is write-free, but §8 step 2 directs an action the skill grants no
  capability for (counting `*.md` with no `Glob`/`LS`), whose nearest granted
  substitute is the `INDEX.md` read step 3 forbids; plus F5.
- **`atomic-index-write` (medium)** — tmp+mv holds at all seven writer sites; the
  breach is `migrate.sh`'s non-transactional commit phase, plus `place_snapshot`
  as the one enumerator that does not exclude the tmp namespace.
- **`staleness-gated-reads` (medium)** — the recorded violation *is* fixed, but
  `render.sh` swallows a regeneration failure and serves the known-stale index at
  rc 0 (the one read surface that does; both siblings treat it as loud), and the
  "only when stale" clause is now literally untrue of the placement path.

All five are channelled `in-change` **by selection**, per the sensor's rule that
selection is the anchor. Several have pre-existing substance — the `--origin`
encoding, `migrate.sh`'s commit phase, `render.sh`'s tolerant regen, the analyst's
literal path — and a consumer of these records should weigh that when routing.

**Blueprint currency:** `staleness-gated-reads`' wording ("regenerate the index
only when stale") no longer describes the placement arm, where staleness is not
knowable by mtime because materialization writes every entry in `ls-tree` order.
The fork should either amend the wording or accept a standing letter-violation.

### Contracts

The map names `issue` as provider on two edges, and this change touched both
provides-side entries, so the phase fired. The mechanical floor reported 4/4
edges covered with no leak or breaking facts. **2 edges · 4 sides checked · 2
violations, both provider-side.**

- **`sdlc > issue :: emitter` — provider: violated.** F20. Judged *not* a
  spec-034 class: additive, opt-in, unreachable by a declaration-only consumer,
  and covered today by the sibling §7a entry, which `sdlc`'s Requires face also
  binds. A declaration-currency gap; remedy is a declaration edit only.
- **`sdlc > issue :: candidate-batch-contract` — provider: violated
  (`breaking`).** F14 and F15, plus §7a's pre-rewrite rule still standing in
  directive voice *before* the paragraph that supersedes it, and an unlabelled
  negative example fenced like a runnable one.
- **Both consumer sides hold.** The prior failure mode is genuinely closed: the
  branch is local at every call site, exit 4 is distinguished from other non-zero
  codes, the fallback target exists in every file, and the interactive paths
  correctly omit the flag. Consumer-side outcomes route to this review's batch,
  never into the reviewed group's own update.

**Territory.** One stray: `tests/place.sh` (F22). ~796 further files in the set
difference are other groups' declared territory or scaffolding — bucketed, not
enumerated.

## Metrics

**Build range** (`f024b9e..3c1a78f`, the ledger's record): 15 commits (11 feat,
4 docs/chore), 19 files, +2905/−32.

**Reviewed range** (`f024b9e..2f7e6ed`, build + review + fix pass): **41 commits**
(12 feat, 5 fix, 1 test, 20 docs, 3 chore), **55 files, +5722/−67**. Suite **1284
green**.

Stage durations: spec 1h46m, research 18m, plan 9h33m, sec 10h26m, build 3h49m.
`review_duration_seconds=42661` is the **span** from the first review's start to
this one's finish, not this run's elapsed time — the known ledger span-vs-sum
defect, already tracked; treat it as non-comparable.

## Deviations & feedback

The pattern worth naming is not the individual defects but their shape. The first
review found four defects living at **seams between two states** the fixtures
never put together. The fix pass closed those four and introduced three more of
the same kind:

- F1 lives at *deferred-then-raced* — the fix handled deferred-then-reconnect and
  deferred-then-diverged, but not deferred-then-lost-a-race.
- F2 lives at *diverged-then-same-file* — the conflict rule existed, on the retry
  path, and the diverged case needed it on the first.
- F6 lives at *retry-then-raced-again* — the initial captures were ordered
  conservatively and the retry's were not.

Each is one state deeper than the case that was fixed. Adding a state to a state
machine and testing only the transitions you were thinking about is the
generalizable lesson, and the suite reflects it: every new case tests the
scenario the fix was written for, and none tests that scenario plus one more
event.

The second lesson is about prose. Three artifacts state a security property the
code inverts (F3), one states an invariant as achieved that one writer breaks
(F19), and the canonical snippet a consumer copies encodes the unsafe case (F14).
All three were written in the same pass as the code, by the same author, and each
reads as more true than the code is. Writing the guarantee and the mechanism
together makes the guarantee sound established. The `--origin` case is the older
instance of exactly this: the invariant has named it for a long time and the code
has never encoded it, with a comment quietly recording the narrower truth.

Finally, F4 is worth its own note as a process observation: the fix pass edited
the exact line carrying a Critical-adjacent defect the previous review had already
filed, changed one variable on it, and did not fix the defect. A filed finding
sitting on a line you are already touching is the cheapest fix available, and it
was missed because the pass was organized by issue rather than by file.
