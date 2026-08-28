# Context — epic authoring and views

A handoff written at the boundary between `/jim:review` and the remediation
pass it produced. It records what is **expensive or impossible to re-derive**:
the review's findings and how each was reproduced, the claims that were
attacked and *held*, the claims that were attacked and **rejected**, and the
traps that cost real time.

This replaces the pre-build handoff of the same name. That one pointed forward
at a build; the build is done, the review is done, and what is now in flight is
a fix pass against the review's findings.

**Anything below that looks like a setting is a pointer.** Configuration is the
half of a handoff that goes stale fastest — findings survive, settings change
under you — so where a value matters this document names the resolver rather
than quoting what it answered.

**This document is a starting point, not a substitute for grounding.** § 2 is
not optional, and `remediation.md` is the first thing on its list.

---

## 1. Where this stands

The build shipped all 29 tasks and the suite is green at **1,669 cases**. The
review then returned **`major-drift`** — not because the mechanisms are wrong,
but because the increment's headline capability is unreachable from the command
it was specified against.

| artifact | state |
| :--- | :--- |
| `spec.md` | `approved` — 38 ACs |
| `plan.md` | `approved`, all 29 tasks `[x]` — **not `complete`**, deliberately |
| `security.md` | `[spec, plan]` — 0 Critical · 10 Notable · 4 Advisory |
| `review.md` | **`major-drift`** — 13 findings, 33/38 ACs satisfied, `undelegated=0` |
| `remediation.md` | **the work in flight** — agreed, not started |
| `ledger.md` | spec → research → sec → plan → sec → build → review, all closed |

**Two decisions are already made and should not be reopened:**

- **The AC gaps get fixed, not filed.** An increment whose own criteria are
  known-unmet is not marked complete because its tasks were executed.
- **The blueprint update is held.** `require_blueprint` is `true`, so the
  review's completion gate is open on purpose. Folding a major-drift review
  into the group blueprint would record capabilities that are not reachable.

**Nothing in the remediation has been started.** Working tree clean at
`6a5fe65`. The review-stage commits, oldest first: `e37b9b4` (ledger open),
`fef4020`, `565e658`, `1f177b5`, `515c1fe`, `b6518b7`, `940b32d`, `78b1a0d`,
`5dbbf5b`, `0571f79`, `f3ac0b7`, `8bd603f`, `6e7b823`, `7c746d6`, `64d69ea`
(ledger close), `e363a24` (verify), `6a5fe65` (review).

---

## 2. Building deep context

Read this document first, then **do all of the following**. Each grounds a
different class of claim, and every failure this session cost time on was a
claim made without opening the thing it described.

**Start here:**

1. **`remediation.md`** — the work in flight. It carries each item's finding, a
   reproduction known to work, the fix shape, and the case the fix owes. It
   also lists what is deliberately *not* in the pass. Read it before touching
   any code.

**In the spec directory** — the rest, in this order:

2. `review.md` — the verdict and its evidence. Its Coverage section records
   which claims were rejected on verification, which matters as much as the
   findings.
3. `plan.md` — the 29 tasks and 11 design decisions. Still the contract for
   what shipped, and its Requirements Coverage is where the largest finding's
   root cause lives (two capture-flow ACs mapped to script tasks).
4. `spec.md` — the 38 ACs. Its Problem Statement is what makes finding 1 severe
   rather than cosmetic: the friction it names is the one still present.
5. `security.md` — findings 6–14 are the plan-lens pass; every guard they
   produced was mutation-tested during the build and holds.
6. `research.md` — its Peer Feedback documents two places the spec was
   factually wrong, which is the failure mode most likely to recur.
7. `ledger.md` — the stage record, including the review verdict trajectory.

**Grounding beyond this increment** — all four are load-bearing:

8. `docs/specs/issue/000-blueprint/spec.md` — the group's present-tense
   specification. Its **Invariants** table is what the living-intent sensor
   judged: 8 hold, 3 violated, 4 skipped. Two of the violations are this
   increment's. Read the Provides section too — `place.sh`'s verb enum is a
   declared face.
9. `BLUEPRINT.md` — the project map and derived contract graph. It is what
   says the placement door and the emitter have consumers **outside** this
   group, which is why the contract-edge phase ran (4 edges, 0 violations).
10. `docs/notes/process-improvements.md` — **read this before working, not
    after something goes wrong.** The sections that bit this session are named
    in § 5. This session added two fresh instances of rules already written
    there, which is the argument for reading it first.
11. `docs/brainstorms/20260817-issue-epics-and-enhanced-filtering.md` — the
    origin. Its design-options analysis explains why membership is stored on
    the member and derived on the umbrella, which no later artifact re-argues.

---

## 3. What the review found, and how each was proven

Every finding below was reproduced by execution before being recorded. Two
carry a negative control. The full list is in `review.md`; this section records
the *reproductions*, which are the expensive half.

**The one that set the verdict.** `/jim:issue add` parses no flags —
`SKILL.md:33` takes everything after `add` as the subject, and step 6's emitter
template passes neither new flag. So the spec's own mockup files an issue
*titled* `Auth hardening --type epic`. `SKILL.md:156` still states the rule the
increment reversed, which the plan had explicitly told the build to delete from
`new.sh`'s comment — it was deleted in one file and left in the other. **Three
investigators reached this independently**, which is why it is recorded as
confirmed rather than plausible.

**The two write paths disagree.** `new.sh --type epic --part-of <epic>` returns
0 and writes the forbidden state; `join` on the identical pair returns 1 with
*"an epic cannot belong to an epic"*. The capture path checks the target's kind
and never the filing record's own.

**The census rollup drops a memberless umbrella.** Reproduced against a
two-umbrella fixture: the index section lists both, `list epic` lists both,
`show` says `_no members_`, and only `stats` omits one. It enumerates edge
targets rather than epic rows — the mirror of the defect fixed in `f3ac0b7`,
which listed non-umbrellas for the same reason.

**An empty collection answers where it should refuse**, with a negative
control: the populated collection refuses at rc 1, the empty one returns
`_No matching issues._` at rc 0. Note that the `staleness-gated-reads` judge
argued this is *not* a violation of that invariant — sound for the blueprint
invariant, and it does not answer the spec AC. Both readings are in
`remediation.md`.

**`/jim:issue help` omits the new verbs**, and its test hand-lists the five old
ones so it passes green. This is a repeat of a defect class the collection has
already recorded once.

**`row_status` is dead code** — declared, seeded, written once per row, never
read. Added for the rollup, orphaned when the rollup moved into
`build_epic_progress`, which does its own read.

**`backfill.sh` reads past the fence.** Reproduced: a record whose frontmatter
lacks `num:` and whose body carries `num: 5` answers **5** where the
fence-scoped read correctly answers absent. Pre-existing — neither
`backfill.sh` nor `migrate.sh` is in this build's change set — and the most
serious thing the review found that the remediation is not fixing.

---

## 4. Attacked and held — do not re-litigate

Negative results cost as much as findings and are invisible in the artifacts.
Thirteen investigators and nine judges tried to break these and could not; the
full list is in `remediation.md` § 4. The shape worth carrying:

- Every mechanism this increment *introduced* holds — termination by bucketing,
  the `(member, umbrella)` dedup on both sides, the index section's containment
  and bound, the no-op filter across both field classes, the pre-spend refusals.
- Three critical invariants hold, and the `id-gate-before-path` census came out
  **uniform at one guard per path-composing site** — the mechanical form of
  "count the guard per site and expect a uniform number."
- The contract edges hold; growing the verb enum removes nothing from either
  outside consumer.

**Three investigator claims were rejected on verification and should stay
rejected.** An agent's report is evidence, not a verdict:

- The raw-id echo in `transition.sh` is **pre-existing** (`fa77304`), not this
  increment's — settled with `git log -S`.
- The `leave`-availability comment is **not** false: it is scoped to
  containment violations, where the target record exists and resolves. The
  dangling-umbrella case is a different scenario, separately filed.
- `status` reaching the new section unsanitized **does not** matter for
  row-shape: the judge showed it is sanitized once, before both the open/closed
  bucketing and the display, so the "index can never assert a count its own
  rows deny" property holds without a vocabulary check on it.

---

## 5. Traps and environment

**Configuration — resolve, do not trust this page.** Every gate flag, the
identity scheme and the appetite knobs answer to
`bash skills/conf/scripts/jimconf.sh get <key>`.

**The placement mode is the exception, and the config CLI answers it
misleadingly.** `get issue_placement` returns `branch` — not a branch name but
the sentinel for *the working branch*, fabricated as the default and read at
`place.sh`'s destination resolver. Taken at face value it says the collection
is centralized when it is not. Ask the door: `place.sh mode`. Verified this
session — the key reads `branch`, the door reports `direct`.

**A probe named after its own subject will match itself.** A case asserting a
census carries no epic line used a fixture directory named `..._no_epics`, and
the census header echoes the collection path — so the word matched and the
probe reported its own name as a finding. Assert the *structure* (`^  Epics: `,
`^== Epics ==$`), never the bare word.

**A `sed` range does not test its end pattern on the start line.** Extracting a
single-line array with `/^readonly X=(/,/)/p` runs on to the next paren in the
file. The awk idiom in `tests/issues.sh`'s `script_vocabulary` handles both
shapes; copy it rather than reaching for sed.

**Escaped backticks inside double quotes in a heredoc get executed.** A `perl`
substitution inserting `"`$v`"` into a test produced command substitution at
run time. This is the same family as the finding the increment fixed in
`place.sh`'s own `usage()`.

**A whole-file grep over the collection reads body content as frontmatter.**
Two records carry `status: open` in their bodies; `grep -l '^status: open'`
over-counts open issues by one. Scope to the fence with awk. The origin
brainstorm's closing section says this, and it still bit.

**The coordination remote is unreachable from this VM**, so every filing
returns a `P-` provisional ordinal and the host realizes them. An ordinal is
**spent even when a run later refuses**, because the allocator is append-only —
which is the whole reason the capture-time refusals sit above the spend.

**The suite takes ~9 minutes** and exceeds a foreground timeout; run it
backgrounded and **never concurrently with anything, subagents included**. Its
summary line is `Ran N tests:` — grep for that, not for a per-file format.

**No `python3` in this VM.** Bash and POSIX tools only.

**The process-improvements sections that bit this session**, worth re-reading
before working rather than after: *A case that cannot go red is a finding* (the
build produced one and the review found two more), *A false success is the
failure mode that survives every gate*, *A grep over a wrapped document
measures the rendering*, *Verify a claim about a document by opening it*
(finding 1 is a textbook instance), *Name the set before you write the
enumeration*, and *Budget for second priors, not for diligence* — the fan-out
found five AC gaps the author's own build did not.

---

## 6. If you are picking up from here

The next action is the remediation pass in `remediation.md` § 2, red-first on
every item. Four things it owes beyond the item list:

1. **Red-first is not optional.** This increment has already produced three
   cases that cannot go red. A case added here that passes before its fix is a
   defect in the case, and finding it later costs more than checking now.
2. **Mutation-test each fix** on the pattern the build used: neuter the guard,
   watch the named case go red, restore by `cp` from an absolute scratch path,
   verify by `md5sum`.
3. **Re-verify the census oracle** — copy the collection, delete the copied
   index, run `stats` against the copy, diff against `census-before.txt`. It
   has been byte-identical three times and must stay so while the collection
   holds no umbrellas.
4. **Then re-review, then the blueprint.** The verdict rides an append-only
   ledger, so a second `review finished` adds to the trajectory rather than
   replacing it — `major-drift → aligned` is what that ledger is for. The
   blueprint update is held until that lands.

**One thing this pass should decide rather than inherit.** The
`cross-copy-lockstep` violation is sharp: `resolve.sh`'s header claims to be
*"the single definition of what an ordinal, an exact slug or a slug prefix
resolves to on a write path"*, and `transition.sh` keeps its own `resolve_slug`
for the primary id — copies that have **already diverged** in their stderr
granularity. Either the primary id delegates too, or the header stops claiming
it. That is a design fork, not a typo, and it belongs to the held blueprint
fork rather than to this pass — but whoever runs the fork should know the
divergence is real and reproduced, not theoretical.

**A session grant that does not survive this document.** The developer
authorized agent fan-out for the session that produced this work. **It was a
per-session grant**, and it was spent well — the review's five AC findings came
from the fan-out, not from the author's own reading. A later session must not
read this paragraph as standing authorization; confirm before fanning out.
