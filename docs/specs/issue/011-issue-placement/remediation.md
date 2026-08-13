---
title: "Issue placement — remediation plan"
spec: "docs/specs/issue/011-issue-placement/spec.md"
type: remediation
status: complete
bar: regression
base_sha: "ae4b877"
---

# Issue placement (`issue/011`) — remediation

*Written 2026-08-10 against a clean tree at `ae4b877`, after two reviews and one
defect-fix pass. This plan defines the bar for closing the spec, the work that
meets it, and what is deliberately left tracked.*

## Status

**All work packages complete, WP7 included.** Fifty-two commits over
`ae4b877..96d5731`. Suite **1284 → 1322 green**. The range is pinned at both
ends on purpose: written against `HEAD` it grew with every later round, and a
reader counting commits got a number this plan never claimed.

**The spec is deliberately held open.** `/jim:review` returned `minor-drift` —
up from `major-drift` twice — and the completion gate was answered **no** on the
developer's judgment: a single review pass surfaced 24 new follow-ons, of which
five are fixes owed against invariants the fork left standing, four of those
against `critical` ones. A pass that still finds two dozen items is not a tail.
`plan.md` stays `approved`; closing it is a separate decision against the
tracked set, not against this plan.

This remediation is finished in the sense its bar defines: what the build and
fix pass introduced or touched is closed, and everything else is filed. It is
not a claim that the feature is done.

| WP | State | Closes |
| :--- | :--- | :--- |
| WP0 baseline | done | — |
| WP1 fixtures | done | #293 |
| WP2 publish state machine | done | #282, #285, #284, #287, #274; #295 **retry half only** |
| WP3 `cmd_begin` reporting | done | #263, #280 |
| WP4 scrub gate | done | #289; #278 **prose only** |
| WP5 bookmark honesty | done | #271 |
| WP6 documentation | done | #292 |
| WP8 direct-mode arm | done | #281, #283, #268, #295 (both halves) |
| WP9 analyst + routing | done | #266; #277 **items 1–3 only** |
| WP10 origin lint | done | #273 |
| WP11 declarations | done | #279, #296 |
| WP12 atomic writes | done | #288 |
| WP13 read posture + emitter stdout | done | #291, #294, #277 (item 4) |
| WP14 placeholder + capability | done | #286; #290 **part 2 only** |
| WP15 conformance pass | done | #269 |
| WP16 declare two rules | done | — |
| WP7 close out | done | — |

**Twenty-five issues closed by this remediation**, on top of the 8 the fix pass
had closed — 33 of the 36 then filed against the spec, leaving **3 open** when
the review ran. Every closed issue in that set carries a `## Resolution` section
naming what shipped, the commit, and the case that pins it; the collection's
convention is that a close without one is incomplete.

**The review then filed 24 more** (#298–#319 plus two realized later), so the
spec's open set is **27**, not 3. Those are the next round's subject, not this
plan's — `review.md` is their record and lists the five that gate closure. Do
not read the counts below as current; they describe the set this remediation
was scoped against.

**Four things have since run.** In order, and each recorded at the end of this
file: *§ The review-remediation round*, *§ The fourth review*, *§ The containment
round*, and *§ The sweep round*. The last two worked the fourth review's tracked
set rather than producing a new review. `review.md` still holds the fourth
review; its predecessor's per-AC evidence is preserved at commit `0563c42`. Every
list of "what gates closure" written before those sections is stale; the current
tracked set is the last subsection of this file, and it is the only count in this
file that is maintained.

The fix pass's 8 recorded their resolutions in commit trailers alone and were
**backfilled** here, each marked as reconstructed and dated to the backfill
rather than to the close. Four of them carry something the trailers did not: the
half that was left, and where it went. The placeholder fix closed the realistic
brace case but not the literal one; the test repair fixed two vacuous cases but
not the class; the reconnect fix handled every composition but reconnect-plus-
race; and the emitter gate shipped alongside a commit message asserting the
opposite of the polarity it implemented. Each is linked to the issue that
finished it, so the record reads as a chain rather than as eight closes.

Two of those three stayed open having been narrowed rather than deferred whole,
each to the half that carries a decision, and each carrying a `## Progress`
section saying what is done and what is left:

- **#278** — the three false-prose sites are corrected; the polarity is not
  taken.
- **#290** — the placeholder collision is fixed; the encode-or-narrow fork is not
  taken.

**WP8 was added after the bar was set**, on the developer's approval, once the
scoreboard showed the direct-mode arm carrying four of the remaining defects in
one file region and WP5 having unblocked the one they were sequenced behind. It
flips **AC 12** and half of **AC 3**, and clears two of the three security
regressions the second review listed.

Two things this plan predicted wrongly, corrected here so a resuming reader does
not inherit them:

- **#284 does not fall out of the graft decision.** Reverting only that decision
  leaves the lost-race case green. #282 is closed by the *base re-resolution*
  and #285/#284 by the *graft-on-attempt-1* — two independent mechanisms, each
  separately pinned.
- **#271's false negative was not live.** The fix pass had already stopped the
  bookmark rewinding, so only the false *alarm* was real. WP5 makes the guard
  structural rather than scattered across each advance, and the rewind is now
  pinned by a case that goes silent when it is reintroduced.

WP7 ran. Its outcome — the verdict, the fan-out, and the answered completion
gate — is recorded in its own section below.

## Context

The build shipped a working feature (`skills/issue/scripts/place.sh`, ~1330
lines). What blocks closure is not the feature but the repair history:

- **First review** — `major-drift`, 22 findings, four reproducible data defects.
- **Fix pass** — closed all four, and introduced one critical and two high
  **of the same class**.
- **Second review** — `major-drift`, 28 findings, 5 of 8 invariants violated,
  both provider-side contract edges violated (one `breaking`).

35 follow-ons were filed against this spec (#262–#296); 8 were closed by the fix
pass and **27 stood open** when this plan was written. The plan sits at
`status: approved` with 14/14 tasks checked, and was deliberately not marked
`complete`. *(Current counts are under **Status**; this paragraph describes the
starting position.)*

`review.md` is the authoritative record and now holds the **third** review, which
supersedes the two described above. It carries the per-AC verdicts, the
investigation evidence, the living-intent outcomes, and the five items that gate
closure. Read it before this plan for anything about current state; read this
plan for why the remediation did what it did.

### Why the last pass produced new defects

`place_commit_changes` is a state machine over four axes — three tip states
(`current` / `ahead` / `diverged`) × two tiers (origin / local) × two arms
(plumbing / direct) × attempt-1-vs-attempt-N — and **attempt 1 and attempt N are
different code paths**. Every defect in both rounds lives where two of those axes
compose:

- **#282** — `ahead` + lost race. The fix handled `ahead`+reconnect and
  `ahead`+diverged.
- **#285** — `diverged` + same-file. The conflict rule existed, on the retry path.
- **#287** — retry + raced-again. The initial captures were ordered
  conservatively; the retry's were not.

Every fixture in `tests/place.sh` drives **one** axis. `case_place_deferred_
mutation_publishes_on_reconnect` (`:765`) covers deferred+reconnect;
`…survives_a_moved_destination` (`:794`) covers deferred+diverged; nothing covers
deferred+race.

Two process observations from the second review shape the plan below:

1. The fix pass **edited the exact line** carrying a filed Critical-adjacent
   defect (#263, `place.sh:644`), changed one variable on it, and left the defect
   — because the pass was organized by issue rather than by file.
2. Three artifacts state a security property the code inverts (#278), one states
   an invariant one writer breaks (#292), and the canonical snippet a consumer
   copies encodes the unsafe case (#289). All were written in the same pass as
   the code, by the same author. Writing the guarantee and the mechanism together
   makes the guarantee sound established.

## The closure bar

**Regression bar.** This spec's build and fix pass own two things:

1. **What they introduced** — every defect new in the build or the fix pass.
2. **What they touched** — a filed defect sitting on a line the pass edited.

Everything else — findings that predate `issue/011` and were merely surfaced by
first-time invariant judging — routes to its own lifecycle as a tracked issue.
The no-drop guarantee is intact either way: all 27 are filed.

**In scope: 14 issues.**

| Cluster | Issues |
| :--- | :--- |
| Publish state machine | #282, #285, #284, #287, #274, #295 |
| `cmd_begin` refusal reporting | #263, #280 |
| Scrub-gate prose & binding | #278 *(prose only)*, #289 |
| Bookmark honesty | #271 |
| Documentation | #292 |
| Tests | #293 |

**#271 is an argued-in addition**, not a strict regression. Its false-negative
half degrades the force-push detector, and this spec's own #267 fix made that
path reachable more often than it was — so it reads as a regression in effect.
Strike it if you disagree; nothing else depends on it.

**Out of scope: 13 issues** as the bar was set. Seven of those were taken anyway
by the later packages; what is left is listed under *Deferred* below.

### What this bar does and does not buy

- **Closes:** AC 7 (currently *violated*), AC 12's retry half, AC 13's caveat,
  the `materialization-contained` invariant (critical), and **both** contract
  violations.
- **Leaves partial:** AC 3 and AC 5 (both for pre-existing reasons — #277, #266),
  AC 6's mid-run half is closed by #274 but AC 10/11 stay partial on test shape
  and #273.
- **Likely verdict:** `minor-drift` rather than `aligned`. That is the honest
  outcome of this bar and should not be argued away at review time.

*This section describes the bar as set. WP8–WP16 were taken after it on the
developer's approval; they moved AC 3, 5, 11 and 12 past what it promised and
cleared the remaining contract violation — see **Status**. AC 3 is no longer
partial.*

## Work packages

Ordered by dependency. Each names the issues it closes; close them as part of the
package, not afterwards.

Two standing rules for this remediation, both from the second review's findings:

- **Organize by file, not by issue.** Before editing any function, read the whole
  function and check every open issue that names it. This is what #263 cost last
  time.
- **CLAUDE.md commit discipline holds.** 25 of 41 subjects in the reviewed range
  exceeded the 50-character limit (10 of 14 fix-pass commits). Subjects ≤50 chars,
  lowercase, imperative; IDs in `Issue: <num>/<id>` trailers only.
- **A close is not finished without a `## Resolution` section.** The collection's
  convention is a dated section naming what shipped, where, and what pins it —
  and a status flip alone leaves the resolution discoverable only by grepping
  commit trailers. The fix pass skipped it, and so did this remediation until the
  developer asked; both had to be backfilled. An issue narrowed rather than
  closed takes a `## Progress` section instead, naming the half that remains.

---

### WP0 — Baseline

Capture the remediation range base and confirm the suite is green before touching
anything.

```
git rev-parse HEAD > .git/jim-remediation-base-011
bash skills/meta-test/scripts/run.sh > /tmp/suite.log 2>&1 &
until grep -q '^Ran ' /tmp/suite.log; do sleep 10; done; tail -1 /tmp/suite.log
```

The suite takes **~7m40s** and exceeds a single foreground command's timeout — run
it in the background and poll. **Never run two suites concurrently**; they contend
badly (a 16s file took 5m41s alongside another run). Expect 1284 green.

---

### WP1 — Fixtures for the seams *(red-first)*

**Closes #293.** This is the enabling work and the anti-recurrence measure; it
comes first so WP2 lands against tests that can fail.

**Repair what cannot catch its mutation:**

- `tests/place.sh:1262` `case_place_direct_commit_refuses_the_branch_sentinel` —
  asserts only rc 2 + non-empty. Delete the sentinel guard (`place.sh:702-706`)
  and the next guard returns the same rc 2 with a non-empty message. Pin the
  distinguishing text (`'no longer names a destination'`).
- `tests/issues.sh:3086` `case_issues_placement_preview_publishes_nothing`,
  reconcile half — delete `route_placement` from `reconcile.sh` and the preview
  prints "no pending provisional issues" and returns 0. Assert the preview reports
  the **destination's** provisional.
- `tests/issues.sh:2845` `case_issues_placement_tolerates_a_branch_only_origin` —
  the origin `docs-only-here.md` contains no `/`, so `index.sh:461-462`'s `*/*`
  guard exempts it and the file's existence is never checked. Use a path-shaped
  origin. This also makes #273's churn exercisable.

**Add the highest-value missing assertions.** No test in the suite asserts the
bookmark ref's value at any point:

- Pin `place.sh:1267`'s `tier == origin || -z remote` gate. Deleting it currently
  leaves the **entire suite green**.
- Pin `place_check_rewrite`'s `authoritative` argument — no case distinguishes 0
  from 1; hardcoding `1` changes no observable outcome today.

**Add the composed-state cases WP2 needs** (each must be red against current
code):

- `ahead` + lost push race — the deferred close must survive at the destination.
- `diverged` + same-file concurrent edit — expect **rc 3 with the path named**,
  the teammate's content intact. The symmetric ordinary-race case at
  `tests/place.sh:892` is the shape to mirror.
- `diverged` — the published `INDEX.md` must list the teammate's issue. The
  assertion pattern at `:884-886` is what would have caught it.
- `begin` against a hostile tree — `place_seed_traversal` (`:89-107`) exists and
  is driven only through `run`, which is why WP3's two defects are uncaught.

**Also add** (untested production changes from the fix pass): `cmd_begin`'s dirty
guard for a direct-mode **write** handle (`place.sh:615` — deleting it leaves the
suite green and reopens security Finding 9); `place_disclose_unpublished`'s two
message arms; the `--auto --dir` combination under a placement.

**Fixture hygiene:** `place_seed_traversal` checks none of its own exit statuses,
unlike `place_seed_collection`. Two `rev-parse` baselines in `tests/issues.sh`
(`:3071`, `:3140`) lack `--verify`.

**Verify:** each new case red against current code; each repaired case red when
the guard it names is neutered. Non-vacuity is proven by neutering, not asserted.

---

### WP2 — Collapse the publish state machine

**Closes #282, #285, #284, #287, #274, #295.** One function; do it as one change.

**The design decision:** do *not* patch the `ahead` arm's base resolution. That is
the same move that produced this round — add a state, test the transition you were
thinking of. Instead **make attempt 1 and attempt N the identical path**, so the
seam does not exist to be missed:

1. **Re-resolve the triple inside the retry loop.** `place_resolve_tips` runs once
   at `place.sh:1183`; `place_commit_changes` re-reads only `tip` (`:1280`). An
   `ahead` state that loses a race *is* a `diverged` state on the next attempt.
2. **Route every attempt through `place_regraft` when `PLACE_BASE_TIP` differs
   from the current onto-tip.** True exactly in the diverged case on attempt 1 and
   false in the ordinary case, so the conflict rule stops being retry-only. This
   closes #285 and gives #284 the correct index handling for free — `place_regraft`
   already excludes `INDEX.md` from the graft (`:1046`) and regenerates over the
   merged result (`:1062`).
3. **Read `ref_old` before `tip`** at all four sites (`:1282-1283`, `:1286-1287`;
   the initial captures at `:1168` and `:627` are already correct). Then either
   `ref_old` is stale relative to `tip` — the swap fails, the loop retries, safe —
   or they agree. `jimalloc.sh:2208` avoids the split entirely by reading the ref
   once and deriving from it; prefer that shape if it fits.
4. **Distinguish non-contention push failure from contention** (#274). The loop
   already re-reads the tip one line after the failure: an unchanged tip means the
   push failed for a reason retrying will never fix (no push rights, protected
   branch, pre-receive hook, network drop) — different message, no further
   retries. Capture git's stderr rather than discarding it.
5. **Report a mid-loop tier degradation** back to the caller (#274's silent half).
   Both deferral notices key on state fixed before the loop — `cmd_run:1212` on
   `unreachable` (computed at `:1174`) and `cmd_commit:748` on the handle's
   recorded `tier` — so a run whose remote drops mid-loop commits locally and
   returns rc 0 saying nothing.
6. **Call `place_check_rewrite` inside the loop** (#295's retry half). Today a
   rejection caused by a force-push regrafts onto the rewritten tip, lands, and
   advances the bookmark — the rewrite is neither disclosed nor afterwards
   detectable. #295's direct-mode half is **deferred** with cluster 3.

**The two-phase flow needs the same treatment.** `cmd_begin` persists only `tip`
and the base snapshot (`:658-666`), not the tip state, so an `ahead` handle whose
commit loses a race drops the deferred content identically.

**Verify:** WP1's composed-state cases go green; the full suite stays green; the
`ahead`/`diverged` fixtures at `:765`/`:794` still pass unmodified.

---

### WP3 — `cmd_begin` refusal reporting

**Closes #263, #280.** ~5 lines, one edit, and the whole recorded violation of the
`materialization-contained` invariant (critical).

`place.sh:644-648` is the only `if ! cmd; then x=$?` construct in the repository:

```bash
if ! place_materialize "$tip" "$prefix" "$handle/collection"; then
  local mrc=$?          # $? is the negated pipeline's status — always 0
```

A Critical containment refusal reaches the caller as **rc 0 with empty stdout**, so
an agent following `SKILL.md`'s contract holds an empty `<dir>` and edits relative
paths in the project checkout. Nothing escapes the temp root and no publish
follows — this is a lost signal, not a filesystem escape.

Immediately below, `:651` and `:653-654` flatten a containment refusal from rc 2 to
rc 1, where `cmd_run:1192` preserves it with `|| return $?`.

Fix both with the capturing form. **Read the whole function first** — this is the
package where organizing by file rather than by issue is the point.

**Verify:** WP1's `begin`-against-a-hostile-tree case.

---

### WP4 — The scrub gate: prose, snippet, and binding

**Closes #289 and #278's part 1.** The gate *works* — all nine consumers pass the
flag and handle rc 4, independently verified — so AC 13 is satisfied today. What
is not defensible is a security property documented as holding that the code
inverts.

**Correct the false claim in three places.** `auto` initializes to `0`
(`new.sh:65`) and the gate is `if (( auto )) && …` (`:119`), so a skill on the
quiet path that **omits** `--auto` skips the gate and publishes the unreviewed
batch. The safe-sounding case is the other omission. All three say the opposite:

- `skills/issue/scripts/new.sh:117-118`
- `skills/issue/SKILL.md:247`
- `ARCHITECTURE.md:395` — **via `/jim:arch`, never a hand edit.** WP6's bookmark
  correction lands in the same paragraph; batch them into one `/jim:arch` run.

**Put `--auto` in the canonical snippet.** `skills/issue/SKILL.md:228-231` is
billed as *the* emitter call shape, and the blueprint's Provides face declares it
as the guaranteed surface — but it shows no `--auto`, not even the optional
`[--auto]` form a consumer already uses. The rule requiring the flag arrives three
paragraphs later at `:238`. Given the fail-open polarity, the one artifact a
consumer copies encodes the unsafe case.

**Strengthen the sweep from mention to handling.** `tests/docsurfaces.sh:197-198`
greps each file for `new\.sh \[\?--auto` and the literal `exit code 4`. Both are
**file-scoped, not branch-scoped**: a skill whose `--auto` sat on its *interactive*
emitter call while the auto path omitted it would pass, and the second grep proves
the phrase appears, not that anything handles the code. It also never checks that
the fallback target exists, and its non-vacuity floor asserts `n >= 8` against 9
actual consumers — so one skill can leave the sweep silently.

**Fix the §7a roster** (review F15). `skills/issue/SKILL.md:212` enumerates "the
eight surfacing skills" including `/jim:partition` (which never auto-files) and
omitting `/jim:review` and `/jim:verify` (which both do). It is the sentence a
consumer reads to decide whether §7a binds it. `new.sh:115` and `ARCHITECTURE.md`
both say nine.

**Do not take the polarity decision here.** See *Open decisions* below.

---

### WP5 — Bookmark honesty *(argued in — strike if rejected)*

**Closes #271.** Two paths corrupt the last-seen bookmark, and the same defect
both manufactures a tamper alarm where none exists and creates a **false negative
for the attack the detector exists to catch**:

- `place_direct_publish:484` advances the bookmark *before* the push at `:487` and
  never rolls back on rejection, so it names a commit that exists only in this
  clone.
- `place_check_rewrite` runs on the local tier too, where no fetch happened. The
  ordinary sequence read-online-then-work-offline rewinds the bookmark to an older
  commit — after which an attacker's force-push built on that commit passes the
  ancestry check **silently**.

Fix: advance only after a successful publish; compare and advance only after an
actual fetch. DD 5's rule is scoped to "after any fetch"; the code applies it after
a non-fetch. Separately, `merge-base --is-ancestor` exits 128 on a missing object,
which `:809` reads as "not an ancestor" and reports as a rewrite — one
`rc=$?; (( rc == 1 ))` away.

This changes what WP1's bookmark pins assert. That is the point: the pins make the
change visible instead of silent.

---

### WP6 — Documentation pass

**Closes #292.** One editing pass.

- `WORKFLOW.md:127` — "Close an issue by editing its `status:` field directly."
  Under a placement that file is not in the working tree. The correct two-phase
  flow exists only in `skills/issue/SKILL.md` §6a, which `tests/docsurfaces.sh:207`
  guards precisely because it "has to stay documented where an agent editing an
  issue will look" — while sweeping only `SKILL.md`.
- `WORKFLOW.md:215` — the skills tree reads
  `scripts (index/new/render/backfill/migrate)`, missing `place.sh` and
  `reconcile.sh`.
- `ARCHITECTURE.md:395` — the bookmark sentence states an invariant as achieved
  that `place_direct_publish` breaks. Once WP5 lands, the writer is brought into
  the invariant and the sentence becomes true; if WP5 is struck, scope the sentence
  to the plumbing path instead. **Via `/jim:arch`**, batched with WP4.
- `skills/issue/SKILL.md:163` (§6 step 4) — tells the agent to read the written
  file's `num:` back from the printed path. Under a placement that path is
  destination-relative and not in the working tree, and the emitter's stdout
  carries slug and path only, so there is no route to the ordinal at all. The
  likely recoveries are both bad: re-running `new.sh` allocates a **second**
  coordinated ordinal, or hand-composing breaks `single-emitter`. §6a got a
  placement arm; §6 did not. `SKILL.md:17`'s "Only two places need to know" is now
  wrong — it is four.

---

### WP8 — Harden the checked-out arm *(added mid-flight)*

**Closes #281, #283, #268, #295's remaining half.** Not part of the original bar;
taken once the post-WP6 scoreboard showed four of the remaining defects living in
one file region, and WP5 having settled the bookmark discipline that #295's own
text sequenced the direct half behind.

The four turned out to share one root: **the arm had no handle.** Its write token
was the fixed literal `direct`, so `commit` could not read what `begin`
established and had to re-resolve it — which is why nothing proved the dirty
guard ran (#281) and why a changed `issues` key published the wrong collection
(#283). Issuing a real handle closes both; the handle carries state only, and the
directory handed back stays the working tree's own collection.

The other two are independent and small: resolve the staging target against the
worktree top before the wrapped command *and* before `git add` (#268), and check
HEAD against the bookmark on the read path (#295), which needs no fetch because
on this arm HEAD **is** the destination's tip.

One design consequence worth recording: adding that check broke WP5's bookmark
pin, because `place_check_rewrite` both discloses and records. The two were split
— `place_disclose_rewrite` compares, `place_check_rewrite` compares and records —
so the direct arm can do the first without claiming the second. WP5's test caught
this, which is the whole reason it exists.

### WP9 — The analyst's directory and routing classification *(added mid-flight)*

**Closes #266 and #277 items 1–3.** The two remaining defects with no decision
attached, taken together because both are about a path being taken for something
it is not.

**#266** — the skill was taught to materialize the destination and hand the
analyst a directory; the analyst was not, and still named `docs/issues/*.md`. It
is the collection's terminal reader, so pairing one collection's roster with
another's bodies is unobservable downstream. Its `Read` grant is ungated and
already reaches the materialized path under the git dir, so the capability
question the finding left open wanted verifying, not changing.

**#277 items 1–3** — three ways an invocation was read as naming a collection
when it did not, each of which declines routing: a flag's *value* (`reconcile -c
<cfg>`), an invocation missing its operand (`show` with no id, where the appended
directory lands in the id slot), and a token that is not a directory (`list
<typo>`, which then had one created for it by a read verb).

The `list` fix needed two edits, not one, and the second is the load-bearing one:
`dir_given` now requires the argument to *be* a directory, and `cmd_list` refuses
a token that is neither filter nor collection. Without the second, the stray
directory is still reachable with no placement configured at all.

**Item 4 was not taken here** — it was a decision rather than a fix, and it went
to WP13, which closed it.

### WP10 — The origin lint *(added mid-flight)*

**Closes #273.** A decision, taken by the developer: skip the lint when the
collection is placed on a branch, rather than resolving origins against the
destination's tree.

Resolving against the destination was rejected on the merits, not deferred. A
dedicated issues branch is an orphan carrying only the collection (AC 8), so
every path-shaped origin — `docs/brainstorms/…`, `docs/specs/…` — fails to
resolve there *by construction*: the flapping warning set would become a
permanently full one, and worst for the push-protected-`main` case the spec's
third user story exists to serve. It would also put git inside `index.sh`, which
is filesystem-only and usable outside a repository.

Two implementation facts worth keeping:

- **The gate keys on configuration, not on materialization.** In direct mode the
  invoking CWD *is* the collection's branch, so the lint has ground truth there
  and none on the plumbing path. Gating on the arm keeps the flapping and moves
  the seam.
- **The skip is stated, not silent.** A constant note in the warnings block, so
  no churn, and a check that cannot be grounded says so rather than being
  inferred from absence.

The signal is not restored, only stopped from lying. Computing it per reader at
read time — where a checkout-dependent fact belongs — is filed as a follow-on
(`20260811-compute-checkout-dependent-index-warnings-at-read-time`), held back
because it changes the stored artifact for projects with no placement at all,
which no review finding asked for.

### WP11 — The two declarations *(added mid-flight)*

**Closes #279 and #296.** Both are declaration edits with no decision content,
taken through the blueprint surface at its two tiers rather than by hand.

**#279, group tier.** The `new.sh` emitter face closed with "the file lands
wherever `issue_placement` directs" unqualified, while the emitter exits 4
having written nothing when `--auto` meets an unacknowledged placement. The
entry now records the flag, the code, and that the flag is a declaration the
emitter cannot verify — so a consumer binding this entry alone is not told a
guarantee the code does not give. Graded a **weakening of a Provides entry**:
the declared guarantee narrows, the entry declares no criticality so it grades
`critical`/`high`, and it was gated rather than written. Blast radius `sdlc` and
`blueprint`, read from the graph's edge table since no `blast radius:`
annotation exists to consume. **This clears the last contract violation.**

**#296, project tier.** `tests/place.sh` — the group's largest test file — was
in no group's declared territory, the only unclaimed test file of sixteen. Added
to the `issue` territory; `tests/` no longer appears in `health`'s
`UNCOVERED_DIR` output at all, which is the mechanical confirmation.

Three faces were considered and left alone, each for a stated reason:
`render.sh`'s "regenerates only when stale" is the carried
`staleness-gated-reads` decision and amending it would settle a fork not taken;
`index.sh`'s face describes parse discipline and atomicity, which the origin-lint
gate does not falsify; and the `insights-capability-boundary` invariant was
always the right rule — the code now honors it better.

### WP12 — The remaining atomic-write violation *(added mid-flight)*

**Closes #288**, the last `atomic-index-write` violation and the last code item
carrying no decision.

**The migration's commit phase.** It retired every old name and only then renamed
the staged files into position — two loops, in that order — so a failure part-way
through the second left every issue past it under neither name, its only copy a
tmp the return path did not remove. Reproduced by neutering: the second issue
vanishes entirely and a re-run does not recover it.

Renaming first inverts the failure to a duplicate rather than a hole. The
delete-first ordering was not arbitrary, though: it is what makes a rename chain
or swap safe, since one file's old name can be another's new one. So the old
names are retired in a second pass that skips any name another issue was just
renamed onto.

That guard is **defensive and unpinned**. Under the prefix migration a chain
appears unreachable — a re-derived target conforms by construction, so an
existing file at that name is skip-conforming and the collision resolver
discriminates instead. Testing it would mean forcing an internal map. It is kept
because the rename-first ordering depends on it for correctness under any map,
and it costs two lines.

**The collection snapshot.** It was the one enumerator admitting the dotfile
namespace the atomic writers stage through, and the one whose output becomes
tree entries — so a stranded tmp was publishable to the shared branch, where it
would be re-materialized every run, sit unchanged in both snapshots, and appear
in no index. Excluding it makes the property self-enforcing rather than dependent
on every writer's cleanup surviving a crash.

### WP13 — One read posture, and a publish-conditional stdout *(added mid-flight)*

**Closes #291, #294, and #277's item 4.** Three of the four decisions the plan
carried, taken by the developer once the scoreboard showed the remaining work
was deliberation rather than code.

**The read-failure posture (#291, #294).** The group had two and had chosen
neither: `render.sh` established staleness, failed to regenerate, and served the
view at rc 0 with the failure discarded; `place.sh` refused the same failure
outright, on the read path as well as the write one. The rule taken is **a view
known to be stale is never reported as success, and never published** — which
adopts `reconcile.sh`'s existing shape rather than inventing one. `render.sh`
serves the index it already held, names the directory on stderr, and carries a
non-zero status; `place.sh` keeps refusing on the write path and takes the same
disclose-and-carry shape on the read path.

The blast radius was checked before choosing rather than after: `render.sh`'s
only consumers are `/jim:issue`, which presents stdout verbatim, and the
`issue-analyst`. No script reads its exit status, so a non-zero rc breaks no
automated path. The analyst is told what a non-zero status alongside facts
means, since it is the terminal reader.

Four cases pin it, one per read verb, plus a fifth that pins the other
direction — a cleanly regenerating index stays silent at rc 0, so the four
cannot pass against a render that fails every read. `place.sh`'s read
relaxation is **not** pinned by a case: the directory it reindexes is one
`place.sh` creates and owns, so the failure is unreachable without a production
test hook, which this group avoids. It was verified by neutering instead.

**The emitter's stdout (#277 item 4).** On the plumbing arm the printed
`<slug>\t<path>` names the destination branch, which is not written until the
publish that follows — so a failed publish left a caller holding a path that
exists nowhere, the staging copy having been discarded with the run. The output
is now held and released only once the publish lands. On a refusal it goes to
stderr under a marker rather than being dropped: the ordinal it names is spent
either way, so discarding the line would destroy the only record of which one
was burned.

Only the plumbing arm changed. The checked-out arm writes into the working tree,
where the file is there for the caller whether or not the commit succeeds — its
stdout was never a claim about something absent. One correction to the issue's
own text, which this plan had repeated: `new.sh`'s `EXIT CODES` header already
documented rc 3; only the wording about what it leaves behind was missing.

**The blueprint followed the code.** `staleness-gated-reads` said "regenerate
only when stale and never serve a stale view". Both halves were false — the
placement arm rebuilds unconditionally, because a materialized collection's
mtimes encode extraction order rather than edit history, and the failure path
served a stale view before this change did so honestly. Amending it settles the
carried wording decision; it records the posture chosen here, not a rewrite to
match code this remediation left alone.

### WP14 — The placeholder and the ungranted count *(added mid-flight)*

**Closes #286 and #290's part 2.** Two items carrying no decision, taken
together because both are cases of a boundary being crossed by something that
merely looked like it belonged.

**The placeholder (#290 part 2).** `place_substitute` matched on value alone, so
an argument that *was* exactly `{}` was rewritten wherever it sat. The emitter
re-execs carrying its own caller's entire argv, so `--title '{}'` arrived as a
bare marker. Reproduced before fixing, and worse than the issue's "low
likelihood, permanent consequence" reads: it filed at **rc 0** with the slug
`20260811-tmp-tmp-<rand>-collection` and wrote that row to the append-only
registry, which no later run can reclaim.

A placeholder is now read by position as well as value — the operand of
`--dir` / `--place-token`, or the trailing argument. Every entry script already
builds its re-exec in one of those two shapes, so nothing travelling through the
middle of an argv can reach a marker position. That removes the class instead of
shrinking it a second time, which is what the finding asked for and what the
first narrowing did not achieve. Nine fixtures passed a marker mid-argv and now
pass it last, which is the shape the contract describes.

**The ungranted count (#286).** The insights step asked the main agent to count
`*.md` files with no granted way to do it — `Glob`, `LS` and `Bash(ls *)` are all
absent — leaving a `Read` of `INDEX.md`, the exact read the next step forbids and
the checklist checks against. The step is dropped: the analyst already returns a
one-line note when there is nothing to analyze, so it bought nothing while
applying pressure at the `insights-capability-boundary`'s instruction-enforced
half. A question only the trusted party can answer belongs to that party.

### WP15 — The conformance pass *(added mid-flight)*

**Closes #269.** Filed `low` and read as hygiene, but two of its nine items were
behavioral and one of those was a fail-open on the infrastructure path.

**`place_conf` discarded jimconf's exit status.** A broken plugin tree then
produced an empty value indistinguishable from an unset key — and every caller
reads unset as a default. On `issue_placement` that default is `branch`, so an
infrastructure failure silently stopped centralizing and put the write on the
working branch, three lines below a comment promising no silent fallback. Proven
against the prior code rather than argued: with the resolver unreadable it
printed `direct` at rc 0. The discrimination is exact, which is what makes the
fix safe — jimconf applies defaults at rc 0, so an absent config file and an
unset key still resolve normally; only a genuine resolver failure refuses.

**`place_prefix` admitted a dot segment.** `./` resolved to `.`, which names the
repository root and would make the whole checkout the collection, and a repeated
`./` was half-stripped into a path that read fine here and failed opaquely when
git was asked to build a tree from it. Both are now pinned, each red when its
guard is neutered.

The remaining seven were conformance: the display sanitizer adopts the corpus
form with its length cap and reaches the two sites that printed a
branch-supplied name raw; the handle token clears the shared id boundary instead
of an inline charset that was that boundary minus its length cap and its `..`
rejection; four git calls taking a derived argument gained `--end-of-options`;
the coordination branch lost its local default so the value lives in one place;
and the header stopped claiming `mktree`, documented all five verbs rather than
two, and recorded the bash floor this script raised to 4.3 by being the corpus's
first nameref user.

The two knowingly duplicated functions now carry the marker the convention's own
precedent uses: reciprocal `SYNC` comments, and for the byte-identical pair an
agreement fixture that fails if either drifts. `place_handle_root`'s note records
that it is the deliberately *tighter* of its pair, so the two are not
interchangeable — the reason extraction was declined, written where the next
reader meets it.

**Not in this package, despite the plan previously saying so:** enforcing the
nameref *prefix* convention. #269 mentions namerefs only as the portability floor
they raised. The enforcement is #259, which originates from this spec's plan
rather than from a review.

### WP16 — The two rules worth declaring *(added mid-flight)*

Closes no issue. The last three packages established two rules the blueprint did
not carry, and a rule that lives only in a test and a code comment is one the
next author has to rediscover.

**`placeholder-by-position` (new, high).** The placement wrapper substitutes only
the placeholders a caller positioned. Nothing existing reached it: the shell/YAML
interpolation rule governs a different mechanism, and the id-validation rule
would not have caught the observed failure because the corrupted slug was
well-formed and passed cleanly. It was valid and wrong — which is exactly the
shape a validator cannot see.

**`placement-gate-before-git` (amended, still critical).** It already forbade
falling back to the working branch when a configured value fails. The code
reached that same forbidden outcome by a route the wording did not name — the
configuration *read* failed, and an empty result was read as an unset key. The
amendment names both routes. Additive: the rule widens, nothing loosens.

Three candidates were declined and why is recorded at the gate: the emitter's
publish-conditional stdout is already declared in its Provides face and this
group's invariants are cross-cutting rules rather than one script's output
contract; the `--end-of-options` hardening covered arguments that were git's own
hex output, so it was discipline rather than a gap; and the insights change
removed *pressure* toward violating an existing invariant rather than
establishing a rule.

The reconcile pass that follows the write measured no change — the edits touch no
face, so the graph, its health and the face counts all stand where they were.

### WP7 — Close out

1. Full suite green, run in the background per WP0.
2. Re-run `/jim:review`, and assign the verdict over that run's own evidence. The
   `minor-drift` estimate under *What this bar does and does not buy* was made
   against bar C alone, before seven further packages moved AC 3, 5, 11 and 12 and
   cleared both contract violations; it is stale as a prediction and is left
   standing only because a remediation should not revise its own forecast upward
   over its own work. AC 3 is now whole — #277's last item is closed. What
   remains against the ACs is the set under *Deferred* — two entries, one a
   decision and one this remediation filed itself.
3. Blueprint: three invariant edits landed, and each survives the standing rule
   — do **not** amend an invariant to match code this remediation did not
   change. `staleness-gated-reads` is amended because WP13 *chose* the posture
   it now records; the rule it replaced was already false before this
   remediation, since a failed regeneration served a stale view at rc 0.
   `placement-gate-before-git` is widened to name the second route to an outcome
   it already forbade, after WP15 closed that route in the code.
   `placeholder-by-position` is new, and is the only rule this remediation adds
   rather than corrects — it records what WP14 established. Every one follows a
   code change made here; none rewrites the spec to match code left alone.
4. Take the completion gate: mark `plan.md` `status: complete` only on explicit
   human confirmation.

**Outcome — the gate was answered `no`.** The review ran at `thorough` depth over
16 investigators (the configured fan-out cap of 10 was lifted for the run), with
the living-intent sensor judging all nine invariants. Verdict `minor-drift`; 24
follow-ons filed; 7 invariants violated, 2 folded, 5 owed a fix.

`plan.md` stays `approved`. The reasoning is recorded here so it is not
re-derived: the spec's own paths are sound and the data-loss class is closed and
independently re-verified, but one review pass still surfaced two dozen items —
including two cross-group flows that write into this collection without routing,
and a containment gate missing from the door § 6a makes the default for every
edit under a placement. Closing on that count would record a verdict the evidence
does not support.

**What closure now waits on**, in the order that matters:

1. The containment gate on `cmd_begin`'s checked-out arm (`critical` class).
2. `commit`'s routed arm re-establishing the placement gate (`critical`).
3. The two cross-group write paths (`/jim:spec reconcile`, `/jim:partition`).
4. The `awk -v` frontmatter injection and both index-row forgery routes.
5. The `id-gate-before-path` ordering in the emitter.

Each is filed with a concrete action. The remaining nineteen are tracked and do
not gate closure.

**Superseded 2026-08-12.** **All five are closed** by the round that followed,
item 3 — the two cross-group write paths — included. That round's bar was set
wider than this list: close the whole reviewed set bar `#297`. The per-issue
`## Resolution` and `## Progress` sections are its record; this list is left
standing as what was true when WP7 answered the gate, not as work outstanding.
For the current open set see *§ The tracked set* — the count is deliberately not
restated here, because a number written in two places rots in one of them.

## Deferred

Tracked, not dropped. Each is pre-existing substance surfaced by this spec's
reviews rather than introduced by them. The direct-mode cluster that sat here
was taken as WP8 and is gone from the list.

| Issue | Why deferred |
| :--- | :--- |
| #290 *(part 1 only)* | ~~A text-vs-code fork: encode `--origin` or narrow the invariant.~~ **Taken 2026-08-12** — encoded, not narrowed. Part 2 was a defect rather than a fork and is closed under WP14; the issue is now closed whole. |
| #297 | Not surfaced by a review — filed *by* this remediation, as the successor to #273. Moving the origin check out of the stored index and into the reader's view restores a signal WP10 could only stop from lying, but it changes the stored artifact for projects with no placement at all. |

## Open decisions carried forward

Two items remain **decisions, not fixes** — cheap in code, expensive in
deliberation. Three of the original five were taken as WP13 and are recorded
there: the group's read-failure posture, the emitter's stdout timing, and the
`staleness-gated-reads` wording that followed from the first.

1. **The `--auto` polarity** (#278 part 2). The genuinely fail-closed shape is the
   inverse: treat every filing as unreviewed, and have the interactive path opt out
   with `--reviewed`. Real cost — every interactive caller, including
   `/jim:issue add`, then carries a flag. A third shape neither the issue nor this
   plan originally listed: require an explicit declaration and refuse when neither
   flag is given, scoped to the routing condition, which removes the fail-open
   without installing a new silent default and changes nothing for a project with
   no placement. Twelve call sites either way, ten of them prose. WP4 corrects the
   prose whichever is chosen.
2. **`--origin`: encode or narrow** (#290 part 1). Quote it the way `title` is
   quoted, or narrow `untrusted-body-never-shell` to the documented scope
   (title + labels). One fact the issue does not record and this plan previously
   read one-sidedly: `new.sh` contradicts itself — its file header says the
   encoding exists because `--title`/`--labels`/`--origin` are untrusted, while the
   implementation comment says origin is skill-controlled and out of that set. A
   comment changes whichever way this goes, so "the code deliberately meant the
   narrower scope" is not settled authorial intent to defer to.

**A sixth item listed here previously is already taken.** Whether rc 4 belongs in
the emitter's declared face was settled by WP11: the entry records the flag, the
code, and that the flag is a declaration the emitter cannot verify.

**Both of the two are now taken as well (2026-08-12), by the round that followed
this one.** Neither is carried forward any longer, and each decision is recorded
on its own issue rather than here — which is where a reader should go, since the
issue also carries what was weighed against it.

- **The `--auto` polarity** went to the third shape this section describes:
  require an explicit declaration and refuse when neither flag is given, scoped
  to the routing condition. Not the inverse — that removes the fail-open but
  installs a new silent default in the other direction. Implemented in `e7982b7`,
  and the scoping is what keeps it inert for every project without a placement.
- **`--origin`** is encoded, not narrowed. The fact this section says is missing
  turned out to settle it: the field is defined by a skill's *prompt* as "a path
  when knowable, else a sentinel", with nothing enforcing either, so it is
  model-produced text of a title's trust class and the narrower scope was never
  settled authorial intent. Implemented.

Two forks this round *added* to the carried set are both settled and shipped:
`#311`'s remaining three parts (an unsupported value form now refuses; the
walk-up is declined in favour of locate-and-refuse; a strict mode for unknown
keys is declined with reasoning), and the cross-group routing decisions on `#316`
and `#314`.

**One fork is open again (2026-08-13), and it lives on its issue, not here.**
`place.sh begin` does not report which arm it took, and a caller holding a handle
therefore cannot know whether what it was handed was materialized. The sweep
round removed the one consequence — its consumer re-derives containment from the
enumeration instead — and left the interface question to
`20260813-begin-does-not-report-which-arm-it-took`, which carries three candidate
shapes and what each costs. It is filed rather than carried here because closing
it moves `place.sh`'s Provides face and both placement contract edges, so it is a
spec-scoped design decision rather than a remainder of this plan.

## Nameref hazard

`place.sh` uses a per-function nameref prefix convention (`_pp_`, `_rg_`, `_ps_`,
`_ch_`, `_sv_`, `_ld_`). **Keep it.** A nameref whose own name matches the array it
points at resolves to itself and yields an **empty array with no error** — it cost
two debugging rounds during the build. Nothing mechanically enforces the
convention; that is #259, which originates from this spec's plan rather than
from a review and sits outside the tracked follow-on set.

## The review-remediation round

*The round `review.md` set up, run 2026-08-12 against `c6aadf2`. Recorded here
because this file is tracked and the session note that carried it is not.*

**The bar was: close everything in the reviewed set except `#297`.** Met. Zero
follow-ons with `origin: review.md` remain open. Seventeen commits, and the suite
moved **1356 → 1370**.

| Issue | What shipped |
| :--- | :--- |
| `#301` | `backfill.sh` writes only a value the normalizer minted, and passes it through the environment rather than `awk -v` |
| `#313` | `migrate.sh`'s commit-failure handler holds a staged file that is an issue's last copy, and claims no all-clear it cannot make |
| `#311` | `jimconf` refuses an unsupported value form, and refuses to ignore a config it can see above the working directory — located, never read |
| `#278` | the batch declaration is required under a placement (`--auto` XOR `--reviewed`), rc 2 when absent or contradictory |
| `#317` + `#45` | the surfacing-skill roster is a property held to the emitter grant by a sweep, not a count restated in four places |
| `#316` | the spec citation sweep rewrites the collection where placement puts it, published as one commit |
| `#314` | partition discloses the re-points it will not apply, read from the destination through a read-only handle |

Every close carries a `## Resolution` naming what shipped, the commit, and the
case that pins it. **Every fix was proven by neutering its guard and watching the
case go red**; each reproduced the filed defect exactly. `#45` was closed
alongside `#317` because the by-file rule put both under the same edit.

**Three issues' own text was wrong, and their resolutions say so.** `#317` names
§ 7a's "ten" as the canonical roster to correct the others to — that roster was
itself short, since `/jim:blueprint` files through the emitter and appeared in
none of the four. `#314` says rename, split and merge all edit issue bodies —
only split and merge do. `#311` proposes a walk-up — declined, because
`pre_commit`, `pre_completion` and the `deps_command_*` / `verify_command_*`
families are values jim hands to bash, so honouring a config from above the
trusted folder runs a command from outside it.

**Nine decisions were taken across the round**, each recorded in its issue with
the alternatives weighed and rejected. Do not re-litigate them from the issue
bodies alone — the body states the original proposal, and the correction lives in
the `## Decision` or `## Resolution` below it.

### The four things this round flagged for the next review

All four were answered by the fourth review. The ledger gap was recorded and
worked around a third time — and is now filed rather than re-derived (`#335`).
The fan-out ran at 21 on explicit authorization, again exceeding the cap of 10.
The third review was read before being overwritten and is cited by commit. The
gate was presented, not answered.

## The fourth review

*Run 2026-08-12 against `2860869`. Verdict `minor-drift`, its second consecutive
— but over a tree three prior reviews had already worked.*

**Coverage was the widest yet: 21 investigators and 9 living-intent judges, all
dispatched, none undelegated.** 10 investigators by acceptance criterion, 8 by
high-stakes region, 3 meta — test-suite integrity, resolution-note accuracy, and
plan/architecture conformance.

**Alignment improved on every axis:**

| | 3rd review | 4th review |
| :--- | :--- | :--- |
| ACs met / drift / violated | 5 / 8 / 0 | **6 / 7 / 0** |
| Invariant violations | 7 of 9 | **3 of 9** |
| Contract violations | 0 | 0 |
| Findings | 30 | 45 |

Both `critical` security regressions the third review recorded are fixed and
pinned. Both cross-group routing bypasses are closed. Of the round's own claims,
**every one held under independent judging**: 28 cited test cases all exist, 18
cited shas all resolve, and 60 closed issues all carry a `## Resolution`.

**The count rose because the depth did.** Three of the sharpest findings needed
two or three agents converging independently before they were visible.

### What it found that four passes had not

- **`index.sh:338`** — an unquoted expansion. A shared-branch filename carrying a
  newline splits, re-globs against the *developer's own checkout*, and publishes
  that checkout's markdown frontmatter to the shared branch as forged issue rows.
  No gate anywhere rejects a control character in an entry name. Reached
  independently by one investigator and two judges. `#328`.
- **`place.sh:749-750`** — `place_direct_publish` discards `git status`'s exit
  status, so a git failure reads as "nothing to publish": rc 0, nothing committed,
  handle deleted, success reported. The sibling guard 145 lines earlier carries
  the identical two lines *with* the check and a comment naming this exact failure
  class. Found by two investigators. `#340`.

### What this round itself introduced

Two of the four criticals were **created by the fixes meant to close the spec**:

- **`migrate.sh:144-148`** (`#336`) — the discriminator fix moved a downgrade past
  the reservation loop its siblings sit inside. A row that degrades to
  `skip-unmigratable` keeps its filename without reserving it; a later row is
  assigned that name, the second `mv` overwrites the first, the retire loop
  deletes the survivor, and the run exits 0 reporting success.
- **`skills/spec/scripts/reconcile.sh:644-648`** (`#326`) — the routed sweep
  correctly stopped enumerating the worktree copy, then re-added the handle's
  entries *past* the containment guard, on the justification that `place.sh`
  materialized them. True of the plumbing arm only.

**Both fixes were proven red-first against the defect they targeted.** That is
the lesson worth carrying: neuter-and-verify proves a fix, and says nothing about
what the edit is now adjacent to. This is the third consecutive round where the
failure mode was composition rather than the fix itself, and the first where
red-first verification passed cleanly on both.

### Living intent, and the blueprint fold

Nine invariants sensed, **six hold**. The four the third review recorded as
violated and this round repaired: `id-gate-before-path`,
`placement-gate-before-git`, `insights-capability-boundary`,
`staleness-gated-reads`. The three violated —
`untrusted-body-never-shell`, `materialization-contained`, `atomic-index-write` —
were all resolved **fix the code**: in each case the invariant is right and the
code is wrong, so no rule was folded to match a defect.

Two edits landed through `/jim:blueprint --from-review`:

- **`single-emitter`** now records that the two-phase door publishes a content
  diff rather than a verb-scoped one, so the create/edit separation rests on the
  caller's discipline rather than a mechanism the door enforces. A deliberate
  weakening, confirmed at the gate — it makes an enforcement model explicit rather
  than implied.
- The **`place.sh` Provides entry** declares that `begin --read` hands back a
  usable handle at non-zero status when the index could not be regenerated, and
  that the handle still requires an `abort`.

### The contract graph lost two rows, on purpose

The reconcile derives edges from `Requires` faces and is the graph's sole writer.
The two placement rows added in the previous round — `sdlc → issue`
(placement-door) and `blueprint → issue` (placement-read) — were hand-carried
into a table marked *do not edit*, with no backing `Requires` entry in either
consumer blueprint. Deriving honestly drops them: **25 edges → 23**.

The dependencies are real in code; only the declarations are missing. The
consequence is now visible rather than masked — the `place.sh` placement-door
Provides entry is required by no mapped consumer, which the reconcile records as
its one finding, **dead-surface = 1**. The class's stock remedy ("trim the
entry") is wrong here. `#338` carries the right one: add the reciprocal
`Requires` entries, after which both edges re-derive and the finding clears
itself.

## The containment round

*Run 2026-08-13 against `05523ea`, working the fourth review's tracked set
rather than a new review. Twelve commits; the suite moved **1370 → 1383**.*

**Two declarations, then two file-scoped fix passes.** The order was deliberate:
the contract edges first, so blast-radius analysis was honest before any code in
`place.sh` moved.

| Issue | What shipped |
| :--- | :--- |
| `#338` | both placement edges derive from reciprocal `Requires` entries; the graph is 25 rows and `dead-surface` cleared itself from 1 to 0 |
| `#333` | the index's row set and Summary counts derive from one population, and four warning values clear the display sanitizer |
| `#328` | a control character is refused at both ends — the enumeration no longer splits a name, and neither end of the round trip accepts one |
| `#340` | the publish side checks `git status`'s exit status instead of reading a failure as nothing to publish |
| `#329` | the direct arm's commit is hook-free, unstages on failure, and excludes the dotfile namespace |
| `#332` | items 5 and 6 only — the snapshot's enumerability precondition and the replay's mode preservation |

**Every fix was proven by neutering its own guard and watching the case that
names it go red**, with each neuter diffed against a saved copy first so a
pattern that silently missed could not be recorded as a proof. Fourteen cases
were added across the two files.

### What the round learned

**A fix opened a hole its own issue did not name.** Correcting the index
enumeration stopped mangling filenames, which delivered the raw name intact to a
refusal message that concatenated it unsanitized — so a committed filename could
forge a second `## Issues` section and a row inside it. The site is named by
neither `#328` nor `#333`. This is the fourth consecutive round where the
failure mode is composition rather than the fix, and the first where the rule
recorded after the last one (*re-read the whole function and ask what else
depends on the state you just moved*) caught it prospectively rather than a
review catching it afterwards.

**Two mechanisms were tested rather than assumed, and both changed the fix.**
`--no-verify` does not protect a commit subject — a `prepare-commit-msg` hook
rewrites it through that flag — so the direct arm scopes hooks off by
`core.hooksPath` instead. And `:(exclude)` pathspec magic is unavailable under
`--literal-pathspecs`: the whole `add` fails rather than the pathspec being
ignored, so the dotfile exclusion is applied by unstaging.

**One guard ships pinned by nothing, named rather than left to be found.**
`place_snapshot`'s enumerability precondition cannot be driven from any external
invocation — the directory it enumerates is one `place.sh` creates and owns, and
the reindex fails against the same directory first. It is recorded as unpinned
in `#332`'s progress section, since `#343` is an open issue about exactly this
class.

**Three fixtures wrote into the real collection before being caught.** On the
direct arm `begin` hands back a *repo-relative* prefix, and a test process's CWD
is the project's own checkout — so writing through the returned path landed in
`docs/issues/`. Two untracked files, nothing committed, `INDEX.md` untouched;
removed, and the cases anchored at their fixture repo with the trap named in a
comment. It also exposed one of those cases as passing for the wrong reason.

## The sweep round

*Run 2026-08-13 against `297ca80`, on one function: `sweep_citations` in
`skills/spec/scripts/reconcile.sh`, and the two issues filed against it. The
suite moved **1384 → 1392**.*

| Issue | What shipped |
| :--- | :--- |
| `#326` | containment is a property of the enumeration rather than a claim about the provider: every target clears the boundary of the root it came from, and all four enumerations now carry the same symlink discipline — two already did, the handle enumeration had neither half, and the tracked one had only the escape half, so a *contained* tracked symlink used to be rewritten through and is now skipped |
| `#327` | the handle is released on the one exit that leaked it; the `begin`-failure message states what has actually happened; a routed collection's worktree fork is dropped by resolved prefix rather than by pathspec alone; `place.sh`'s header stops claiming stranded handles are reported and reclaimed |

**Eight guards, each proved by neutering it and watching its case go red**, with
every neuter diffed against a saved copy first. Eight cases were added; the
`route`-with-the-destination-checked-out arm had no coverage at all before this,
on either half.

### What the round learned

**The tidiest-looking fix was the trap, and naming why is what kept it out.**
Having `cmd_mode` report which arm `begin` would take reads as the obvious fix —
one verb, one field, no breaking change. It is wrong: `mode`'s contract is *"should
you re-exec through place.sh?"*, and the entry scripts gate their re-exec on it.
A `mode` that answered `direct` when the destination is checked out would stop
them routing and lose `place_direct_publish` — trading a containment bug for a
silent publishing one. **A verb's contract is what its consumers gate on, not
what its name suggests.**

**The fix that removes a coupling beats the fix that patches it.** The issue's own
wording — check containment "when `place_dir` resolves inside the worktree" —
would have worked, and would have asked which arm `begin` took. That question is
what caused the defect. Bounding every path by the root it came from never asks
it: on the arm that materializes, the check is redundant, and that redundancy is
the price of not coupling to the provider again.

**Layered guards need separate proofs.** With the containment check neutered the
escape still did not land, because the symlink skip beside it caught the write —
each guard produces a different *outcome* (a refusal versus a silent skip), so
each needed its own case. A proof that a hole is closed is not a proof that the
guard you wrote is what closes it.

**A case was green because the ordering defused it.** The symlinked-collection
case passed with its guard removed: the link sorted *after* its target, so by the
time the rewrite followed the link the target had already been swept and there
was nothing left to rewrite. Renaming the link so it sorts first made the case
able to fail. This is the second round in a row where a case that could not go
red was found by neutering rather than by reading.

**Half of one finding dissolved instead of being fixed.** `#327`'s complaint that
`issue_touched` cannot fire for the worktree fork under `route` was a symptom of
the fork being swept at all. With the fork out of the enumeration there is nothing
in it to regenerate an index for, and the guard it named needs no change.

**A second guard ships pinned by nothing, and that is now a pattern rather than
an exception.** The check that `begin`'s directory resolves at all cannot be
driven from outside, and is load-bearing anyway: the empty string it refuses
would make the loop below it glob the filesystem root. Recorded in `#326`'s
resolution and on `#343`, which owns the class. Two consecutive rounds have each
added one, which is the signal — `#343`'s action should say what a sweep does
with a deliberately unpinned guard rather than each round re-deriving it.

**One claim in this round's own record was wrong and is corrected on the issue.**
The `#326` resolution first said the fix applied the discipline "three other
enumerations already carry". Two carried it; the tracked one carried only the
escape half, which meant the fix silently changed that path's behavior. The
count was the small half of the error — the sentence hid a behavior change that
had a case written for it. `#326` carries the dated `## Correction`; the commit
body that repeats it stands, because five resolutions already cite shas in that
range.

## The tracked set

**Twenty-one follow-ons stand against the spec, and none is `critical`.**

- **Twelve from the fourth review** — `#323` `#324` `#325` `#330` `#331` `#332`
  `#334` `#335` `#339` `#341` `#342` `#343`. Seven are `high`.
- **Eight predating it** — `#255` `#256` (from `research.md`), `#257` `#258`
  `#259` `#260` `#261` (from `plan.md`), `#297` (from this file, deliberately
  deferred).
- **One filed by the sweep round** — the `mode`/`begin` divergence, deferred out
  of `#326` because closing it breaks `begin`'s output shape and moves the
  `place.sh` Provides face and both placement contract edges with it. It carries
  a provisional ordinal: this clone cannot reach the coordination point, so
  `/jim:issue reconcile` settles it where one is reachable.

`#332` is open on items 1–4 of six, and carries a `## Progress` saying which.

Three worth reading before touching anything nearby:

- **`#258`** — `-c` does not carry placement. Latent only because no production
  caller passes `-c`, and the routed citation sweep now depends on that
  resolution.
- **`#335`** — the ledger's change set is the build's 19 files against a 113-file
  subject. It is not only a reporting gap: the same set drives the living-intent
  sensor's judge selection, so a remediation touching a *new* file would leave its
  invariants unjudged and the review would report clean coverage.
- **`#343`** — three load-bearing `place.sh` guards are unpinned, and two rounds
  have now added their own named-but-unpinned guard to that class. It is the
  sharpest thing still open.

**The completion gate remains unanswered.** `plan.md` stays `approved`. The fact
that turned it on when the fourth review closed — a deeper pass finding two
defects that destroy user data, one freshly introduced by the round meant to be
closing this out — is now fully addressed: both are closed, and every `critical`
against the spec is closed with it. What remains is a `high`-and-below tail, which
is a different judgment from the one the gate was answered `no` on.
