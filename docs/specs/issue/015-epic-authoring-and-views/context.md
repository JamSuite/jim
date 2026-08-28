# Context — epic authoring and views

A handoff written after the increment closed **and** after its follow-on pass.
Everything the pipeline asks for has run, `plan.md` is `complete`, the
build-scope follow-ons are fixed and closed with resolutions, and the
retrospective is written. **Nothing in this increment is pending.**

This replaces a handoff written when the plan was still `approved`. That one
pointed at one outstanding gesture; the gesture was made.

**What this document is for.** It records what is **expensive or impossible to
re-derive**: design forks already settled, claims already attacked and
rejected, operational facts of this environment, and the small number of
records whose surface text is misleading. It does **not** restate findings —
those live in `review.md`, `remediation.md` and `retrospective.md` — and it no
longer restates the general process lessons, because § 2's reading list now
reaches them in `docs/notes/process-improvements.md`, which is their home.

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
| `remediation.md` | the completed fix pass; § 5 attributes every issue, § 5a marked discharged |
| `retrospective.md` | the post-increment analysis — drift causes, actions, metric caveat |
| `ledger.md` | every stage closed; the verdict trajectory is two lines |

- Suite **1,677 green** (1,673 before the follow-on pass, plus 4 cases).
- Living intent: 15 invariants — 10 hold · 4 violated · 1 skipped (scope).
  Contract edges: 4 checked · 0 violations.
- The group blueprint and project map are current and committed. **No blueprint
  edit is owed:** all in-change violations resolved *fix the code*.
- Fourteen issues trace here, `#405`–`#418`. **Four closed** (411, 414, 416,
  417); ten open and correctly so.

**Nothing is owed on this increment.** If you are here to do work, it is either
one of the open issues in § 5 or something new.

---

## 2. Building deep context

Read this document first, then **do all of the following**. Each grounds a
different class of claim, and every failure this work cost time on was a claim
made without opening the thing it described.

**In the spec directory, in this order:**

1. **`retrospective.md`** — start here. It is the only artifact that explains
   *why* the increment drifted rather than *what* drifted: § 4 traces the five
   unmet criteria to two rows of the plan's coverage table, § 5 to an invariant
   whose quantifier could not cover the breach, and § 8 warns that the ledger's
   duration metric cannot be read literally.
2. **`remediation.md`** — the completed fix pass. § 2 is what landed and the
   mutation that proved each item; § 4 is what was attacked and held; **§ 5 is
   the per-issue attribution**, the only place it survives, with § 5a now
   marked discharged.
3. **`review.md`** — the second review. Its Coverage section records what was
   rejected on verification, and its Deviations section carries process lessons
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
   specification. Its **Invariants** table is what the sensor judged. Note
   before relying on it: **all 15 are `judge`-method with no `verify-checks`
   block**, so this group has no mechanical floor at all. Its **Provides**
   entries describe the umbrella capability and publish `transition.sh`'s
   validator-before-the-door ordering as a guarantee — see § 3.
10. `BLUEPRINT.md` — the project map and derived contract graph. It is what
    says the emitter and the placement door have consumers **outside** this
    group, which is why the contract-edge phase runs at all.
11. **`docs/notes/process-improvements.md`** — **read before working, not after
    something goes wrong.** 50 sections; five were added by this increment and
    three existing ones extended. The general lessons that used to be listed in
    this handoff now live there, which is why § 4 below is short.
12. `docs/brainstorms/20260817-issue-epics-and-enhanced-filtering.md` — the
    origin. Its design-options analysis explains why membership is stored on
    the member and derived on the umbrella, which no later artifact re-argues.

---

## 3. Settled — do not reopen

Each of these cost real work to decide. Re-deciding them is cheap to start and
expensive to finish.

**Design forks, settled with the developer:**

- **`transition.sh` resolves its primary `<id>` through `resolve.sh`.** The
  fork was delegate-or-mark; it was settled by *deleting* the duplicate ladder,
  not annotating it. `resolve_slug` and both open-coded validate blocks are
  gone.
- **The `jimfile.sh valid-id` call before the placement door stays.** It looks
  like leftover duplication and is not: the group blueprint publishes *the id
  clears the validator and the outcome clears its enum before the placement
  door opens* as a `transition.sh` guarantee. Removing it breaks a published
  guarantee to buy nothing. It is commented in place as a fail-fast.
- **The census rollup is scoped to the query; its progress numbers are not.**
  An umbrella whose own row the filter excludes is not listed; one it admits
  reports its whole roster. This mirrors the `== Blocking ==` rollup twenty
  lines below, which is the precedent that settled it.
- **Membership is one-sided on the member**, and rosters are derived by
  **bucketing, never traversal**. From the brainstorm; re-argued nowhere.

**Claims raised, checked, and rejected:**

- The raw-id echo in `transition.sh` is **pre-existing** — settled with
  `git log -S`.
- The `leave`-availability comment is **not false**; it is scoped to
  containment violations. The dangling-umbrella case is different, filed as
  `#413`.
- `status` reaching the index section unsanitized **does not matter for
  row-shape** — it is sanitized once, before both bucketing and display.
- `EPIC_ROWS` **needs no sentinel-key guard.** The idiom applies to arrays
  declared *without* an `=()` initializer; this one has one, and the
  count-guard means the whole-array expansion is never reached empty.

`remediation.md` § 4 carries the mechanisms attacked and held.

---

## 4. Traps and environment

The general verification lessons are in `process-improvements.md` (§ 2, item
11) and are not repeated. What follows is operational — facts about *this*
checkout and *these* scripts that no document elsewhere states.

**Configuration — resolve, do not trust this page.** Gate flags, the identity
scheme and the appetite knobs answer to
`bash skills/conf/scripts/jimconf.sh get <key>`.

**The placement mode is the exception, and the config CLI answers it
misleadingly.** `get issue_placement` returns `branch` — not a branch name but
the sentinel for *the working branch*. Taken at face value it says the
collection is centralized when it is not. Ask the door: `place.sh mode`, which
answers `direct`.

**`new.sh` does not regenerate the index.** The skill instructs the caller to,
and its checklist confirms it. After filing, run `index.sh` yourself or the
collection ships with a stale index that `git status` will not flag, because
the new file is untracked and `INDEX.md` merely unchanged.

**`transition.sh` does not commit under a direct placement.** It writes the
fields and stops; the developer commits. The repo's convention for that commit
is a subject naming the ordinal (`close 380 with its resolution`) and an
appended `## Resolution` section in the body — see `process-improvements.md`,
*A resolution note is the durable record*.

**Anything touching the whole collection is slow enough to need backgrounding.**
`index.sh` over ~420 records takes ~2 minutes; each `transition.sh close`
takes ~40 seconds. A loop closing four issues exceeds a foreground timeout.

**The suite takes ~9 minutes**, exceeds a foreground timeout, and must run
backgrounded and **never concurrently with anything, subagents included**. Its
per-file summary line is `Ran N tests:`.

**The coordination remote is unreachable from this VM**, so every filing
returns a `P-` provisional ordinal and the host realizes them. An ordinal is
**spent even when a run later refuses**, because the allocator is append-only —
which is why the capture-time refusals sit above the spend.

**No `python3`.** Bash and POSIX tools only.

**The census oracle.** `render.sh stats` over a copy of the real collection is
byte-identical to a stored pre-increment oracle, verified four times. Take it
against a **copy** — a read regenerates `INDEX.md`, which is a write to a
tracked artifact.

---

## 5. Tracked but unfixed — and two records that mislead

Ten issues remain open. These are the ones a reader is most likely to
mis-assess:

- **`#415` (critical)** — `backfill.sh` and `migrate.sh` read past the
  frontmatter fence, and under `--apply` that path reaches a file rename.
  Reproduced twice. **The most serious thing either review found**, pre-existing
  and outside this increment's change set. Nothing here fixed it.
- **`#410` (data loss)** — a completed transition destroyed when a post-write
  reindex fails under a branch placement. Reproduced end to end with a
  fault-injection rig; the rig's construction notes are in the issue.
- **`#412` (high)** — malformed capture-flag input is undefined. Downstream of
  the remediation, not the build: the flags did not exist until then.

**Two records whose surface text is wrong. Read the corrections.**

- **`#418` — the description is factually wrong and a `## Correction` says so.**
  It claims the close-side resolution convention is undocumented; it is
  documented, in `process-improvements.md`. The sweep behind that sentence
  covered three operator surfaces and not the notes file. **The Correction is
  the operative half**: the rule exists but sits where retrospectives are read
  rather than at the verb.
- **The ledger's `<stage>_duration_seconds` cannot be read literally.** It spans
  first-`started` to last-`finished`, so any re-run stage is overstated —
  23× on `sec` here. Tracked as **`#252`**. `retrospective.md` § 2 carries
  timings reconstructed from event pairs; use those.

**Also open and unowned:** `ARCHITECTURE.md:1937` says "Nine deterministic
scripts" where the tree in the same document lists ten. Declined at review,
still true. It must be fixed through `/jim:arch`, never by hand.

---

## 6. If you are picking up from here

**There is no pending work in this increment.** Every artifact is written,
committed and self-consistent; the suite is green; the blueprint and map are
current; the plan is complete.

The candidates, in the order I would take them:

1. **`#415`** — it outranks everything else open, and its blast radius reaches
   a file rename under `--apply`.
2. **`#410`** — data loss, reproduced, with the rig described.
3. **`retrospective.md` § 9 actions 1–3** — a *Demonstrated by* column on
   Requirements Coverage, a coverage-adversarial pass at plan time, and a
   `verify-checks` block giving this group its first mechanical floor. These
   target the causes rather than the instances, and 1–2 address the drift that
   made this increment `major-drift` at first review.

**A session grant that does not survive this document.** Agent fan-out was
authorized for an earlier session and is **per-session**. The follow-on pass
that closed § 5a used **no fan-out at all** — everything was read directly —
so nothing here depends on it. Confirm before fanning out.

**One habit worth copying from the last pass.** Before filing anything, grep
the collection for an existing record. A duration-metric defect found during
the retrospective was already `#252`, filed three weeks earlier; checking cost
one command and avoided a duplicate. The counter-example is `#418`, filed after
a sweep that was one surface too narrow.
