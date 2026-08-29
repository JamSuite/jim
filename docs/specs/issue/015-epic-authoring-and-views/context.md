# Context — epic authoring and views

A handoff written after the increment closed, after its follow-on pass, and
after a third pass that took three more of the issues it filed. The pipeline
has run to the end; `plan.md` is `complete`. **Nothing in this increment is
pending, but one gesture is owed across it** — see § 6.

This replaces a handoff written when the last thing done was the retrospective.
That one correctly said nothing was pending; three issues have since been
fixed and closed, and the blueprint question they raise is new.

**What this document is for.** It records what is **expensive or impossible to
re-derive**: design forks already settled, claims already attacked and
rejected, operational facts of this environment, and the small number of
records whose surface text misleads. It does **not** restate findings — those
live in `review.md`, `remediation.md` and `retrospective.md` — and it does not
restate the general process lessons, because § 2's reading list reaches them in
`docs/notes/process-improvements.md`, which is their home.

**Anything below that looks like a setting is a pointer.** Configuration is the
half of a handoff that rots fastest; where a value matters this names the
resolver rather than quoting what it answered.

---

## 1. Where this stands

| artifact | state |
| :--- | :--- |
| `spec.md` | `approved` — 38 criteria, **all 38 satisfied** |
| `plan.md` | **`complete`** — 29/29 tasks, 0 open questions, 4 disclosed deviations |
| `security.md` | `[spec, plan]` — 0 critical · 10 notable · 4 advisory |
| `review.md` | **`minor-drift`** — 11 findings, 38/38 criteria, `undelegated=0` |
| `remediation.md` | the completed fix pass; § 5 attributes every issue, § 5a discharged |
| `retrospective.md` | the post-increment analysis — drift causes, actions, metric caveat |
| `ledger.md` | every stage closed; the verdict trajectory is two lines |

- Suite **1,687 green** (1,673 at build; +4 follow-on, +10 this pass).
- Fourteen issues trace here, `#405`–`#418`. **Seven closed** — 411, 414, 416,
  417 in the follow-on pass; **415, 412, 413** in this one — and seven open.
- The last sensor run is the review's. Living intent then: 15 invariants —
  10 hold · 4 violated · 1 skipped (scope); contract edges 4 checked · 0
  violations. **Those numbers are stale** — three fixes have landed since, one
  of them against a violated invariant.

**This pass's six commits**, oldest first, all on `feat/issue-epics`:

| | fix | close |
| :--- | :--- | :--- |
| `#415` critical — fence-scope backfill/migrate reads | `40827a63` | `5610c724` |
| `#412` high — capture flag extraction | `1954c7a8` | `49daba6d` |
| `#413` medium — `leave` clears a dangling umbrella | `db567f08` | `f2775e6c` |

`13ba52f8` is the commit before all six and is **the baseline the owed
blueprint run should use** (§ 6).

---

## 2. Building deep context

Read this document first, then **do all of the following**. Each grounds a
different class of claim, and every failure this work cost time on was a claim
made without opening the thing it described.

**In the spec directory, in this order:**

1. **`retrospective.md`** — start here. It is the only artifact that explains
   *why* the increment drifted rather than *what* drifted: § 4 traces the five
   unmet criteria to two rows of the plan's coverage table, § 5 to an invariant
   whose quantifier could not cover the breach, § 8 warns that the ledger's
   duration metric cannot be read literally, and § 9 carries the three actions
   that target causes rather than instances.
2. **`remediation.md`** — the completed fix pass. § 2 is what landed and the
   mutation that proved each item; § 4 is what was attacked and held; **§ 5 is
   the per-issue attribution**, the only place it survives, with § 5a marked
   discharged.
3. **`review.md`** — the second review. Its Coverage section records what was
   rejected on verification; its Deviations section carries process lessons
   since promoted into the notes file.
4. `plan.md` — 29 tasks, 11 design decisions. Read the **Requirements Coverage
   Summary** specifically: it is the artifact the retrospective indicts, and
   seeing the two-column shape is the fastest way to understand the drift.
5. `spec.md` — the 38 criteria. Read **Out of Scope** too; it is what makes
   several open issues correctly deferred rather than missed.
6. `security.md` — the plan-lens pass. Every guard it produced was
   mutation-tested and holds.
7. `research.md` — its Peer Feedback documents two places the spec was
   factually wrong, which is the failure mode most likely to recur.
8. `ledger.md` — the stage record, including the `major-drift → minor-drift`
   trajectory and the second build pair the remediation opened.

**Grounding beyond this increment — all four are load-bearing:**

9. `docs/specs/issue/000-blueprint/spec.md` — the group's present-tense
   specification. Its **Invariants** table is what the sensor judges. Note
   before relying on it: **all 15 are `judge`-method with no `verify-checks`
   block**, so this group has no mechanical floor at all — which is why no fix
   in this pass could be confirmed closed without a fan-out. Its **Provides**
   entries are the faces § 6 asks about.
10. `BLUEPRINT.md` — the project map and derived contract graph. Read the
    **Territory** lines, not just the purposes: they are what says
    `tests/docsurfaces.sh` belongs to **platform**, not to this group, which
    matters for § 6.
11. **`docs/notes/process-improvements.md`** — **read before working, not after
    something goes wrong.** 50 sections (`###` level, under 6 `##` groupings).
    The general lessons that a handoff would otherwise duplicate live there,
    which is why § 4 below is short.
12. `docs/brainstorms/20260817-issue-epics-and-enhanced-filtering.md` — the
    origin. Its design-options analysis explains why membership is stored on
    the member and derived on the umbrella, which no later artifact re-argues.

**Then read this pass's six commits** (`git log 13ba52f8..HEAD`). Each fix
commit's body carries the reasoning that its issue's `## Resolution` section
then records durably; the resolutions are the better read of the two.

---

## 3. Settled — do not reopen

Each of these cost real work to decide. Re-deciding them is cheap to start and
expensive to finish.

**Settled with the developer in this pass:**

- **The emitter owns the kind vocabulary; the skill does not pre-validate it.**
  `--type <not-a-kind>` is forwarded whatever it is, and `new.sh`'s enum gate
  refuses above the allocator, so no ordinal is spent. Chosen over restating
  `issue|epic` in prose, which would hand-maintain a derived enumeration. This
  mirrors the rule the `list` bullet already states for filters.
- **`leave` matches the record's own `part-of` entries *before* the resolver,
  not as a fallback after it.** Two reasons decided it: `resolve.sh` writes its
  refusal to stderr as it fails, so a fallback would repair the record and exit
  0 having already printed an error; and a dead entry that prefixes a live
  record would resolve away to that record, remove nothing, and report success.
  The issue proposed the fallback shape; this deviates from it deliberately.
- **`join` keeps resolving.** The asymmetry is the design: entering a set
  requires the set to exist, leaving one does not.

**Settled earlier, still binding:**

- **`transition.sh` resolves its primary `<id>` through `resolve.sh`.** Settled
  by *deleting* the duplicate ladder, not annotating it.
- **The `jimfile.sh valid-id` call before the placement door stays.** It looks
  like leftover duplication and is not: the group blueprint publishes *the id
  clears the validator and the outcome clears its enum before the placement
  door opens* as a `transition.sh` guarantee.
- **The census rollup is scoped to the query; its progress numbers are not.**
  Mirrors the `== Blocking ==` rollup twenty lines below.
- **Membership is one-sided on the member**, rosters derived by **bucketing,
  never traversal**. From the brainstorm; re-argued nowhere.

**Claims raised, checked, and rejected:**

- The raw-id echo in `transition.sh` is **pre-existing** — settled with
  `git log -S`.
- `status` reaching the index section unsanitized **does not matter for
  row-shape** — sanitized once, before both bucketing and display.
- `EPIC_ROWS` **needs no sentinel-key guard** — the idiom applies to arrays
  declared without an `=()` initializer; this one has one.

`remediation.md` § 4 carries the mechanisms attacked and held.

---

## 4. Traps and environment

The general verification lessons are in `process-improvements.md` (§ 2, item
11) and are not repeated. What follows is operational, plus one lesson from
this pass that is not yet in the notes file.

**A guard test that accepts any failure is not a guard.** Two of this pass's
cases exist to catch an *over-broad* fix rather than to prove a feature. The
first version of the `join` guard asserted only that a refusal happened —
and removing the `verb == leave` guard **still passed it**, because `join` then
refused for a different reason. It only bites now that it asserts *which*
refusal. A negative test must pin the mechanism, not the exit code. **This is
general and belongs in `process-improvements.md`; it is not there yet.**

**Configuration — resolve, do not trust this page.** Gate flags, the identity
scheme and the appetite knobs answer to
`bash skills/conf/scripts/jimconf.sh get <key>`.

**The placement mode is the exception, and the config CLI answers it
misleadingly.** `get issue_placement` returns `branch` — not a branch name but
the sentinel for *the working branch*. Ask the door: `place.sh mode`, which
answers `direct`.

**`new.sh` does not regenerate the index.** After filing, run `index.sh`
yourself or the collection ships with a stale index that `git status` will not
flag, because the new file is untracked and `INDEX.md` merely unchanged.

**`transition.sh` does not commit under a direct placement.** It writes the
fields and stops. The convention for that commit is a subject naming the
ordinal (`close 413 with its resolution`) and an appended `## Resolution`
section in the body — see `process-improvements.md`, *A resolution note is the
durable record*.

**Anything touching the whole collection needs backgrounding.** `index.sh` over
~420 records takes ~2 minutes; each `transition.sh close` takes ~40 seconds.

**The suite takes ~9 minutes**, exceeds a foreground timeout, and must run
backgrounded and **never concurrently with anything, subagents included**. Its
per-file summary line is `Ran N tests:`.

**A file-wide `sed -i` on a test helper hits every match in the file.** Adding
a parameter to `transition_issue` changed five `  part-of: []` lines when only
one was inside the helper. Caught by diffing against a pre-edit copy — take
one before any `sed -i`, and diff after.

**Splicing before a function header orphans its comment.** Three of this
pass's four insertions left a preceding `# AC:` block attached to the wrong
function. `awk '/^case_[a-z_]+\(\) \{$/ { if (prev !~ /^#/ && prev != "") print
NR }'` catches it after the fact.

**The coordination remote is unreachable from this VM**, so every filing
returns a `P-` provisional ordinal and the host realizes them. An ordinal is
**spent even when a run later refuses**, because the allocator is append-only.

**No `python3`.** Bash and POSIX tools only.

---

## 5. Tracked but unfixed — and one record that misleads

Seven issues remain open. These are the ones a reader is most likely to
mis-assess:

- **`#410` (data loss)** — a completed transition destroyed when a post-write
  reindex fails under a branch placement. Reproduced end to end with a
  fault-injection rig; the rig's construction notes are in the issue. **The
  most serious thing still open**, and the natural next piece of work. Its
  `## The fix` section is one paragraph and prescriptive: preserve the handle
  on a post-write reindex failure rather than aborting it.
- **`#408` (medium)** — membership doubles the index graph section.
- **`#406` (medium)** — report an honest completion rate from `outcome`.
- `#407`, `#409`, `#405` are `low` and correctly deferred.

**One record whose surface text is wrong. Read the correction.**

- **`#418` — the description is factually wrong and a `## Correction` says so.**
  It claims the close-side resolution convention is undocumented; it is
  documented, in `process-improvements.md`. The sweep behind that sentence
  covered three operator surfaces and not the notes file. **The Correction is
  the operative half.**

**And one metric that cannot be read literally.** The ledger's
`<stage>_duration_seconds` spans first-`started` to last-`finished`, so any
re-run stage is overstated — 23× on `sec` here. Tracked as **`#252`**, filed
three weeks before this increment. `retrospective.md` § 2 carries timings
reconstructed from event pairs; use those.

**Also open and unowned:** `ARCHITECTURE.md:1937` says "Nine deterministic
scripts" where the tree in the same document lists ten. Declined at review,
still true. It must be fixed through `/jim:arch`, never by hand.

---

## 6. Owed: one batched blueprint run

**This is the only thing outstanding, and it was deliberately deferred.** The
developer chose to hold the fan-out until several issues were done so the
blueprint machinery runs once against a larger range rather than per fix.

Run it as `/jim:blueprint --since 13ba52f8 issue`, which grounds its violation
fork in `/jim:verify --since` — **judge fan-out, which needs the developer's
authorization; the grant is per-session and this session had none.** Everything
below is a reading of the blueprint against the diff, **not an engine outcome**.

What to expect, and what to check it against:

- **One additive Provides candidate, from `#413`.** The `transition.sh` entry
  publishes that containment is enforced on the way in only, *so `leave` stays
  available to repair a violation a hand edit introduced*. `leave` now repairs
  a second class — a membership whose umbrella no longer resolves — which the
  entry does not mention. A **widened** guarantee grades **additive**, so it
  should not trip the `critical`/`high` downgrade prompt.
- **Nothing from `#412`.** Skill prose only; no script changed, no face moved.
  Its own docsurfaces test now holds the `--type` synopsis to `ISSUE_TYPES`,
  which moves *toward* `declared-vocabularies` rather than against it.
- **Nothing owed from `#415` on the invariant itself.** It was a genuine
  `issue-file-never-sourced` divergence and resolved *fix the code*, which is
  the fork branch that writes no blueprint edit. But its closure is exactly
  what cannot be confirmed without the sensor.
- **One pre-existing Structure gap.** The group blueprint's Structure names
  `tests/issues.sh` and `tests/place.sh` as the group's test files and takes
  the trouble to name `tests/jimfile.sh` as its one acknowledged reach into
  **platform's** files, with the reason. `tests/docsurfaces.sh` is also
  platform's (confirm in `BLUEPRINT.md`'s platform Territory line) and now
  carries **eleven** cases asserting this group's doc surfaces, unnamed. A full
  generate would likely rediscover it — `last_full_generate` is
  `2026-08-25T05:10:57Z` and the regen-cadence threshold is 5 targeted updates,
  so weigh a regenerate against another targeted diff before running.

---

## 7. If you are picking up from here

**No fix is half-done.** Every artifact is written, committed and
self-consistent; the suite is green; the working tree is clean.

In the order I would take them:

1. **The owed blueprint run** (§ 6) — it closes the loop on three fixes at once
   and is the cheapest thing on this list, once fan-out is authorized.
2. **`#410`** — data loss, reproduced, with the rig and the fix both described.
3. **`retrospective.md` § 9 actions 1–3** — a *Demonstrated by* column on
   Requirements Coverage, a coverage-adversarial pass at plan time, and a
   `verify-checks` block giving this group its first mechanical floor. Action 3
   is the one this pass kept running into: with 15 judge-only invariants, no
   fix can be shown closed without spending a fan-out.
4. **Promote the guard-test lesson** in § 4 into `process-improvements.md`.

**A session grant that does not survive this document.** Agent fan-out is
**per-session**. Neither the follow-on pass nor this one used any — every fix
was read, written and verified directly. Confirm before fanning out.

**Two habits worth copying.** Before filing anything, grep the collection for
an existing record; a duration-metric defect found during the retrospective was
already `#252`. And before asserting a claim an issue makes, check it — `#412`'s
closing Note (last-occurrence-wins, enum gate above the allocator) was verified
against the code before the new prose was written to lean on it.
