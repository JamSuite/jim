# Context — epic authoring and views

A handoff for a reader starting cold. The increment shipped, then four
follow-on passes took nine of the issues it filed. **Nothing is pending and
nothing is half-done** — the tree is clean, the suite is green, and every
artifact is committed and self-consistent.

**What this document is for.** It records what is expensive or impossible to
re-derive: design forks already settled, claims already attacked and rejected,
operational facts of this environment, and the small number of records and docs
whose surface text misleads. It does **not** restate findings — those live in
`review.md`, `remediation.md` and `retrospective.md` — and it does not restate
general process lessons, because § 2's reading list reaches them in
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
| `retrospective.md` | drift causes, three actions, and the metric caveat in § 8 |
| `ledger.md` | every stage closed; the verdict trajectory is two lines |

- Suite **1,693 green**.
- Fourteen issues trace here, `#405`–`#418`. **Nine closed**, five open.
- The group blueprint was **fully regenerated** on 2026-08-29 and the project
  map's contract graph re-derived with it (§ 6).

**Closed, newest first**, each as a fix commit plus a close commit carrying a
`## Resolution`:

| | fix | close |
| :--- | :--- | :--- |
| `#418` — state the resolution rule where the verb is | `70a110e1` | `d40a05ad` |
| `#410` critical-in-effect — index regeneration ownership | `bc9631eb` | `a47c16ea` |
| `#413` — `leave` clears a dangling umbrella | `db567f08` | `f2775e6c` |
| `#412` — capture flag extraction | `1954c7a8` | `49daba6d` |
| `#415` — fence-scope backfill/migrate reads | `40827a63` | `5610c724` |

`#411`, `#414`, `#416`, `#417` closed in an earlier pass; their attribution is
`remediation.md` § 5.

---

## 2. Building deep context

Read this document first, then **do all of the following**. Each grounds a
different class of claim, and every failure this work cost time on was a claim
made without opening the thing it described.

**In the spec directory, in this order:**

1. **`retrospective.md`** — start here. The only artifact explaining *why* the
   increment drifted rather than *what* drifted: § 4 traces the unmet criteria
   to two rows of the plan's coverage table, § 5 to an invariant whose
   quantifier could not cover the breach, § 8 warns the ledger's duration
   metric cannot be read literally, and § 9 carries three actions targeting
   causes rather than instances.
2. **`remediation.md`** — the completed fix pass. § 2 is what landed and the
   mutation that proved each item; § 4 is what was attacked and held; **§ 5 is
   the per-issue attribution**, the only place it survives.
3. **`review.md`** — the second review. Coverage records what was rejected on
   verification; Deviations carries process lessons since promoted to the notes
   file.
4. `plan.md` — 29 tasks, 11 design decisions. Read the **Requirements Coverage
   Summary** specifically: it is the artifact the retrospective indicts, and
   seeing its two-column shape is the fastest way to understand the drift.
5. `spec.md` — the 38 criteria. Read **Out of Scope** too; it is what makes
   several open issues correctly deferred rather than missed.
6. `security.md` — the plan-lens pass. Every guard it produced was
   mutation-tested and holds.
7. `research.md` — its Peer Feedback documents two places the spec was
   factually wrong, the failure mode most likely to recur.
8. `ledger.md` — the stage record, including the `major-drift → minor-drift`
   trajectory and the second build pair the remediation opened.

**Grounding beyond this increment — all four are load-bearing:**

9. `docs/specs/issue/000-blueprint/spec.md` — the group's present-tense
   specification, regenerated 2026-08-29. Its **Invariants** table is what the
   sensor judges: **18 rows, 17 `judge` and 1 `pattern`**. Its **Provides**
   entries are the group's cross-group faces.
10. `BLUEPRINT.md` — the project map and derived contract graph. Read the
    **Territory** lines, not just the purposes: they are what settles which
    group owns a file, and several arguments in this collection turn on it.
11. **`docs/notes/process-improvements.md`** — **read before working, not after
    something goes wrong.** The general lessons a handoff would otherwise
    duplicate live there, which is why § 4 below is short. Read whole sections,
    not headings — see the trap in § 4 about exactly that.
12. `docs/brainstorms/20260817-issue-epics-and-enhanced-filtering.md` — the
    origin. Its design-options analysis explains why membership is stored on the
    member and derived on the umbrella, which no later artifact re-argues.

**Then read the closing commits** for the five issues in § 1. Each fix commit's
body carries the reasoning its issue's `## Resolution` then records durably; the
resolutions are the better read of the two.

---

## 3. Settled — do not reopen

Each cost real work to decide. Re-deciding them is cheap to start and expensive
to finish.

- **The emitter owns the kind vocabulary; the skill does not pre-validate it.**
  `--type <not-a-kind>` is forwarded whatever it is, and `new.sh`'s enum gate
  refuses above the allocator, so no ordinal is spent. Chosen over restating
  `issue|epic` in prose, which would hand-maintain a derived enumeration.
- **`leave` matches the record's own `part-of` entries *before* the resolver**,
  not as a fallback after it. Two reasons: `resolve.sh` writes its refusal to
  stderr as it fails, so a fallback would repair the record and exit 0 having
  already printed an error; and a dead entry that prefixes a live record would
  resolve away to that record, remove nothing, and report success. The issue
  proposed the fallback shape; this deviates deliberately.
- **`join` keeps resolving.** The asymmetry is the design: entering a set
  requires the set to exist, leaving one does not.
- **The index is regenerated by whichever party publishes the collection.**
  `place.sh commit` rebuilds the index of what it publishes, so `transition.sh`
  rebuilds only a collection nothing will publish — named with `--dir`, or the
  working tree under no placement. This replaced a call that was redundant on
  exactly the path where its failure handler deleted the developer's work.
- **The close-side resolution rule is unconditional.** A `wontfix` or `obsolete`
  explains itself nowhere else, and a `done` whose commit rides the closing
  trailer still owes what a trailer cannot hold. Length is proportional;
  absence is not one of the lengths.
- **`transition.sh` resolves its primary `<id>` through `resolve.sh`.** Settled
  by *deleting* the duplicate ladder, not annotating it.
- **The `jimfile.sh valid-id` call before the placement door stays.** It looks
  like leftover duplication and is not: the blueprint publishes *the id clears
  the validator and the outcome clears its enum before the placement door
  opens* as a `transition.sh` guarantee.
- **The census rollup is scoped to the query; its progress numbers are not.**
- **Membership is one-sided on the member**, rosters derived by **bucketing,
  never traversal**. From the brainstorm; re-argued nowhere.

**Claims raised, checked, and rejected:** the raw-id echo in `transition.sh` is
pre-existing (settled with `git log -S`); `status` reaching the index section
unsanitized does not matter for row shape (sanitized once, before both
bucketing and display); `EPIC_ROWS` needs no sentinel-key guard (the idiom
applies to arrays declared without an `=()` initializer; this one has one).
`remediation.md` § 4 carries the mechanisms attacked and held.

---

## 4. Traps and environment

The general verification lessons are in `process-improvements.md` and are not
repeated. What follows is operational, plus one correction.

**A correction to the previous handoff.** It claimed the lesson *a negative test
that accepts any failure is not a guard* was "general and belongs in
`process-improvements.md`; it is not there yet." **That was wrong.** It is
there, as trap 5 of *Neuter the guard, watch the case go red* — "A proof that
the hole is closed is not a proof that the guard you wrote is what closes it."
The sweep behind the claim matched headings rather than reading sections. This
is the same error `#418` was filed on and then corrected for: asserting
something is undocumented after a search that did not reach where it lives.
**Read sections, not headings.**

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
ordinal (`close 413 with its resolution`) and an appended `## Resolution` in the
body — now stated in `skills/issue/SKILL.md` at the `close` bullet and in the
validation checklist, not only in the notes file.

**Anything touching the whole collection needs backgrounding.** `index.sh` over
~420 records takes ~2 minutes; each `transition.sh close` takes ~40 seconds.

**The suite takes ~9 minutes**, exceeds a foreground timeout, and must run
backgrounded and **never concurrently with anything, subagents included**. Its
per-file summary line is `Ran N tests:`. Piping it through `tail` discards the
per-case lines — keep the full log if you need to confirm a specific case ran.

**A file-wide `sed -i` on a test helper hits every match in the file.** Adding a
parameter to `transition_issue` changed five `  part-of: []` lines when only one
was inside the helper. Take a copy before any `sed -i`, and diff after.

**Splicing before a function header orphans its comment.**
`awk '/^case_[a-z_]+\(\) \{$/ { if (prev !~ /^#/ && prev != "") print NR }'`
catches it after the fact; run it after every insertion into a test file.

**The coordination remote is unreachable from this VM**, so every filing returns
a `P-` provisional ordinal that the host realizes with `/jim:issue reconcile`.
An ordinal is **spent even when a run later refuses**, because the allocator is
append-only.

**No `python3`.** Bash and POSIX tools only.

---

## 5. Tracked but unfixed

Five issues remain on this spec. Two more were filed against other groups.

- **`#408` (medium)** — membership doubles the index graph section.
- **`#406` (medium)** — report an honest completion rate from `outcome`. **A
  design fork is parked here and was deliberately not decided:** the record asks
  that a caveat about the one-time conversion's unaudited `done` backfill be
  stated "wherever the number is displayed", and taken literally that is a
  permanent line on every census. The collection is 274 `done` / 1 `obsolete`,
  so the caveat is nearly the whole story for *this* collection while being a
  statement about a one-time migration. Options weighed: help-text only, every
  run, both, or none. **Ask before building.** Note also that `stats` prints no
  completion rate today — the headline is `Open: N · Closed: M`, and the issue
  describes the reading that headline invites, not a number it emits.
- `#407`, `#409`, `#405` are `low` and correctly deferred.

**Filed against other groups, both provisional:**

- *Bind the twice-declared kind and outcome vocabularies* — `ISSUE_TYPES`
  (`new.sh:81`, `index.sh:79`) and `ISSUE_OUTCOMES` (`transition.sh:69`,
  `index.sh:80`) are each declared twice with no `SYNC(` marker and no
  comparison test, where every other shared definition in this group has both.
  This is a live violation of the `declared-vocabularies` invariant.
- *Declare the mirrored branch-name gate on platform's provides face* — the
  leak the reconcile reports (§ 6).

**And one metric that cannot be read literally.** The ledger's
`<stage>_duration_seconds` spans first-`started` to last-`finished`, so any
re-run stage is overstated — 23× on `sec` here. Tracked as **`#252`**, filed
before this increment. `retrospective.md` § 2 carries timings reconstructed from
event pairs; use those.

**Resolved since the previous handoff:** `ARCHITECTURE.md`'s script miscount is
gone, fixed by `6e7b8236`. Do not go looking for it.

---

## 6. The blueprint, and how to date the next run

The group blueprint was **fully regenerated** on 2026-08-29 (`47a0cd84`), and
the project map's contract graph re-derived with it (`ee430a5c`).

**How to pick a `--since` baseline, because the previous handoff got this
wrong.** It recommended the commit before that pass's own fixes. The right
baseline is *the code state the blueprint currently describes*, which the
blueprint's own ledger dates: take the timestamp of the last
`blueprint finished` in `docs/specs/issue/000-blueprint/ledger.md` and find the
commit that was `HEAD` then. Scoping to "the work I just did" skips everything
an earlier pass left unreviewed — in that instance, 21 commits including four
that changed this group's code.

**A generate records nothing on the group ledger.** Only update mode writes
`blueprint started`/`finished` there, so that ledger's newest entry still reads
2026-08-28 and predates the regenerate. The evidence of the full run is the
`last_full_generate` watermark in the blueprint's frontmatter
(`2026-08-29T05:38:09Z`). Read the watermark, not the ledger, to date a
generate. The regen-cadence counter reads **0** against a threshold of 5.

**What the regenerate changed:** `leave`'s widened guarantee and the index
ownership rule on the `transition.sh` face; three `Requires` corrections
(`specs` added, `issue_id_*` removed as platform's own read behind
`jimfile.sh`, `auto_issue_file` scoped to the skill flow); `docsurfaces` named
in Structure as platform's second test file asserting against this group; and
three new invariants — `refusal-discloses-no-input`,
`collection-scan-excludes-its-own-files`, and `no-in-place-rewrite`.

**The group's first mechanical rung** is `no-in-place-rewrite`, a `must-not`
pattern for `sed[[:space:]]+-i` scoped to `skills/issue` — the tests
legitimately use `sed -i` to stale a fixture, so the scope is narrower than the
territory. Verified both ways: `holds` clean, `violated` with `file:line` when a
`sed -i` is introduced.

**One mechanical check was tried and rejected.** `process-improvements.md`'s
*A judge-only invariant set has no floor* suggests `"never sourced" is a
must-not pattern`. It does not work here: every match of `eval|source` across
this group is the English word "source" in prose, so the check would report a
permanent false violation. That section is also now stale in its numbers — it
says "fifteen invariants, all fifteen `judge`-method, with no `verify-checks`
block", which the regenerate changed to 18 with one pattern rung. The lesson
stands; the count does not.

**The reconcile's one finding, and a judgment reversed.** `issue` requires
`platform.valid-branch-shape`, and platform's provides face never declares it —
a **leak**. The prior run reported the same leak but kept the edge row in the
graph; the row is now removed, because the graph is the join of declared faces
and there is nothing on the provider side to join to. Edges went 26 → 25. The
coupling is real (`SYNC(valid-branch)` on both copies, compared by a test) —
what is missing is platform's declaration, which is what the filed issue asks
for. **If you disagree, restoring the row is a one-line edit.**

`dead=0` is a calibration, not a measurement. Applied literally at full
coverage the detector would flag most entries in every group's face — the
user-facing command surfaces among them — which is alarm fatigue rather than 18
trimmable entries. The prior run made the same call.

---

## 7. If you are picking up from here

**Nothing is half-done.** In the order I would take them:

1. **`#406`** — the largest remaining piece, and the one with a fork to settle
   first (§ 5). Ask before building.
2. **`#408`** — membership doubles the index graph section.
3. **`retrospective.md` § 9 actions 1–2** — a *Demonstrated by* column on
   Requirements Coverage, and a coverage-adversarial pass at plan time. Action 3
   (a mechanical floor) is now partly done: one rung of eighteen.
4. **The two cross-group issues** in § 5, both of which touch other groups'
   territory and should be taken with that group's blueprint open.

**A session grant that does not survive this document.** Agent fan-out is
**per-session**. The blueprint regenerate used three read-only scans under an
explicit grant; nothing else in five passes used any. Confirm before fanning
out.

**Three habits worth copying.** Before filing anything, grep the collection for
an existing record — a duration-metric defect found during the retrospective was
already `#252`. Before asserting a claim an issue makes, check it against the
code — twice now a record's central claim has been wrong. And before writing
that something is undocumented, read the candidate sections rather than
grepping their headings; that specific error has now happened twice.
