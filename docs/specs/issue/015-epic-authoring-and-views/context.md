# Context — epic authoring and views

A handoff written after the increment closed. Everything the pipeline asks for
has run: build, review, remediation, re-review, living-intent sensor, blueprint
update, reconcile, and the issue reconciliation. **One gesture is deliberately
outstanding** — `plan.md` is `approved`, not `complete`, and marking it is the
developer's.

This replaces the handoff written at the review/remediation boundary. That one
pointed forward at a fix pass; the fix pass is done and its record is
`remediation.md`.

**What this document is for.** It records what is **expensive or impossible to
re-derive**: claims that were attacked and rejected, traps that cost real time,
and the operational facts of this environment. It does **not** restate the
findings — those live in `review.md` and `remediation.md`, and § 2 is how you
reach them.

**Anything below that looks like a setting is a pointer.** Configuration is the
half of a handoff that goes stale fastest; where a value matters this document
names the resolver rather than quoting what it answered.

---

## 1. Where this stands

| artifact | state |
| :--- | :--- |
| `spec.md` | `approved` — 38 ACs, **all 38 satisfied** |
| `plan.md` | `approved`, 29/29 tasks `[x]` — **not `complete`**, deliberately |
| `security.md` | `[spec, plan]` — 0 Critical · 10 Notable · 4 Advisory |
| `review.md` | **`minor-drift`** — 11 findings, 38/38 ACs, `undelegated=0` |
| `remediation.md` | the completed fix pass, with per-issue attribution in § 5 |
| `ledger.md` | every stage closed; the verdict trajectory is two lines |

- Range `c910f14..e805a4b`, 33 commits. Suite **1,673 green**, run last after
  the blueprint and map writes and the ordinal realization.
- Living intent: 15 invariants — 10 hold · 4 violated · 1 skipped (scope).
  Contract edges: 4 checked · 0 violations.
- The group blueprint and the project map are both updated and committed. The
  blueprint's six edits are additive; its Invariants table took none, because
  all three in-change violations resolved *fix the code*.
- **Thirteen issues** trace to the increment, `#405`–`#417`, all with durable
  ordinals. `remediation.md` § 5 groups them by whether the build should have
  done them: **5a build scope · 5b outside it · 5c pre-existing · 5d declined**.

**Two decisions already made. Do not reopen them.**

- **The AC gaps were fixed, not filed.** That is why the tracked set contains
  follow-ons rather than unmet criteria — and why § 5a names three-and-a-half
  issues rather than eight.
- **The three in-change invariant violations resolved *fix the code*.** The
  blueprint therefore records nothing about them; issues `#410` and `#411` are
  the only things keeping the pending fixes visible.

---

## 2. Building deep context

Read this document first, then **do all of the following**. Each grounds a
different class of claim, and every failure this work cost time on was a claim
made without opening the thing it described.

**In the spec directory, in this order:**

1. **`remediation.md`** — the completed fix pass. § 2 is what landed and the
   mutation that proved each item; § 4 is what was attacked and held; **§ 5 is
   the per-issue attribution** and the only place it survives.
2. **`review.md`** — the second review. Its Coverage section records what was
   rejected on verification, which matters as much as the findings, and its
   Deviations section carries the process lessons.
3. `plan.md` — the 29 tasks and 11 design decisions. Its Requirements Coverage
   is where the first review's largest finding had its root: two capture-flow
   criteria mapped to script tasks.
4. `spec.md` — the 38 ACs. Read the **Out of Scope** list too; it is what makes
   several open issues correctly deferred rather than missed.
5. `security.md` — the plan-lens pass. Every guard it produced was
   mutation-tested and holds.
6. `research.md` — its Peer Feedback documents two places the spec was
   factually wrong, which is the failure mode most likely to recur.
7. `ledger.md` — the stage record, including the `major-drift → minor-drift`
   trajectory and the second build run the remediation opened.

**Grounding beyond this increment — all four are load-bearing:**

8. `docs/specs/issue/000-blueprint/spec.md` — the group's present-tense
   specification. Its **Invariants** table is what the sensor judged; four are
   violated and three of those are tracked as issues. Its **Provides** entries
   now describe the umbrella capability — read them before claiming a face is
   missing something.
9. `BLUEPRINT.md` — the project map and derived contract graph. It is what says
   the emitter and the placement door have consumers **outside** this group,
   which is why the contract-edge phase runs at all.
10. `docs/notes/process-improvements.md` — **read this before working, not
    after something goes wrong.** The sections that bit this work are named in
    § 4. Two fresh instances of rules already written there were added during
    it, which is the argument for reading it first.
11. `docs/brainstorms/20260817-issue-epics-and-enhanced-filtering.md` — the
    origin. Its design-options analysis explains why membership is stored on
    the member and derived on the umbrella, which no later artifact re-argues.

---

## 3. Attacked and rejected — do not re-derive these

An agent's report is evidence, not a verdict. Four claims were raised by
investigators or judges, checked, and **rejected**. Each is cheap to raise
again and expensive to settle.

- **The raw-id echo in `transition.sh` is pre-existing**, not this increment's
  — settled with `git log -S`.
- **The `leave`-availability comment is not false.** It is scoped to
  containment violations, where the target record exists and resolves. The
  dangling-umbrella case is a different scenario, filed as `#413`.
- **`status` reaching the index section unsanitized does not matter for
  row-shape.** It is sanitized once, before both the open/closed bucketing and
  the display, so the value classified and the value displayed are one.
- **`EPIC_ROWS` needs no sentinel-key guard.** An investigator flagged it as
  the only new global expanded as a whole array without the file's
  create-then-unset idiom, on a bash floor below the version that fixed the
  empty-array/`nounset` bug. The idiom applies to arrays declared **without**
  an `=()` initializer; `EPIC_ROWS` has one, the identical count-guarded
  pattern already shipped against `EPIC_TOTAL`, and the guard means the
  whole-array expansion is never reached empty.

`remediation.md` § 4 carries the mechanisms that were attacked and held.

---

## 4. Traps and environment

**Configuration — resolve, do not trust this page.** Every gate flag, the
identity scheme and the appetite knobs answer to
`bash skills/conf/scripts/jimconf.sh get <key>`.

**The placement mode is the exception, and the config CLI answers it
misleadingly.** `get issue_placement` returns `branch` — not a branch name but
the sentinel for *the working branch*. Taken at face value it says the
collection is centralized when it is not. Ask the door: `place.sh mode`.

**A mutation that silently fails to apply reports a false pass.** A `sed`
substitution containing `||` clashed with its own `s|…|` delimiter; the
mutation never applied and the case "passed" for the wrong reason. It was
caught only because the step echoed the `grep` proving the mutant was in place.
**Prove the mutant is present before believing the result.**

**A narrow grep produces a confident false finding.** A sweep for `"$PLACE"`
found two scripts and nearly produced a finding that the blueprint's "the six
re-exec themselves through" was wrong. Five more scripts reach `place.sh`
through a differently-named variable; the claim was correct and the grep was
not. Check a negative before reporting one.

**A fix list derived from a findings report inherits that report's
enumeration.** The remediation fixed the superseded `type` rule at the four
sites the review's finding named. The file had five. Name the set mechanically
before writing the enumeration.

**A probe named after its own subject will match itself.** A fixture directory
named `..._no_epics` matched a word search against a census header that echoes
the collection path. Assert the *structure*, never the bare word. The same
shape reappeared in a doc-surface helper that anchors on the string it then
asserts — recorded as a review finding.

**A `sed` range does not test its end pattern on the start line.** Extracting a
single-line array with `/^readonly X=(/,/)/p` runs on to the next paren. Copy
the awk idiom in `tests/issues.sh`'s `script_vocabulary`.

**A whole-file grep over the collection reads body content as frontmatter.**
Two records carry `status: open` in their bodies. Scope to the fence with awk.
This is the same defect class as `#415`, which is still open.

**The coordination remote is unreachable from this VM**, so every filing
returns a `P-` provisional ordinal and the host realizes them. An ordinal is
**spent even when a run later refuses**, because the allocator is append-only —
which is why the capture-time refusals sit above the spend.

**The suite takes ~9 minutes**, exceeds a foreground timeout, and must run
backgrounded and **never concurrently with anything, subagents included**. Its
summary line is `Ran N tests:` — grep for that.

**No `python3` in this VM.** Bash and POSIX tools only.

**The census oracle.** `render.sh stats` over a copy of the real collection is
byte-identical to a stored pre-increment oracle, verified four times. Take it
against a **copy** — a read regenerates `INDEX.md`, which is a write to a
tracked artifact — and expect a difference of exactly the records filed since
the oracle was taken.

**Fault injection at a boundary beats guessing.** `#410` was proven by copying
`skills/` to a scratch tree and giving `index.sh` a call-counting failure, then
identifying which call was `transition.sh`'s. The first two attempts failed
because `place.sh` reindexes at materialize time and because a stub that
`exec`s a copy breaks `BASH_SOURCE`-relative resolution. Both are worth
knowing before rebuilding such a rig.

---

## 5. If you are picking up from here

**There is no pending work in this increment.** The next actions are:

1. **Mark `plan.md` complete** — the developer's confirmation, the one gate
   this pipeline never takes on its own.
2. **Nothing else is owed.** Every artifact is written, committed, and
   self-consistent; the suite is green; the blueprint and map are current.

If you are here to act on the tracked follow-ons instead, read
`remediation.md` § 5 first and take its grouping seriously — **`#415` is the
critical one** (fence-scoping in `backfill.sh` / `migrate.sh`, pre-existing,
reaches a file rename under `--apply`), and **`#410` is the data-loss one**
(a completed transition destroyed under a branch placement). Both are
reproduced; the reproductions are in the issue bodies.

**A session grant that does not survive this document.** The developer
authorized agent fan-out for the session that produced this work. **It was a
per-session grant**, and it was spent well — the first review's five AC
findings and the second review's data-loss finding both came from the fan-out,
not from the author's own reading. A later session must not read this paragraph
as standing authorization; confirm before fanning out.
