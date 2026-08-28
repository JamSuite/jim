# Retrospective — Epic authoring and views

A post-increment review of how `issue/015` was built, where it drifted, and
what would have caught the drift earlier. Written after the plan was marked
complete and the build-scope follow-ons were closed.

**Blameless by construction.** Every defect below was produced by an agent
executing an artifact another agent wrote, under gates a third designed. The
useful question is never who missed it but *which artifact was allowed to be
wrong without anything contradicting it* — so the findings are stated as
properties of the pipeline, and the actions change surfaces rather than
habits.

**Scope.** The instrumented range `c910f14..40c1110` (24 commits), plus the
follow-on pass that closed § 5a (11 commits). Evidence is the spec directory's
own artifacts, the append-only ledger, and the repository; every number here
was read from one of those rather than recalled.

---

## 1. What shipped

| | |
| :--- | :--- |
| criteria | 38 declared · **38 satisfied** at close · 33 satisfied first pass |
| plan | 29 tasks, all `[x]` · 4 disclosed deviations · 0 scope creep |
| range | 24 commits — 14 build, 10 remediation · 22 files · +3,087 / −510 |
| suite | 1,673 → **1,677** green |
| living intent | 15 invariants — 10 hold · 4 violated · 1 skipped (scope) |
| contracts | 4 edges checked · 0 violations · additive on every provides face |
| security | 0 regressions · all 4 critical invariants hold |
| issues | 14 filed and tracked, `#405`–`#418` |
| verdict | `major-drift`/13 → **`minor-drift`**/11, both on the ledger |

**First-pass criterion satisfaction: 33 / 38 (87%).** Five criteria — two
unmet, three partial — survived a plan whose 29 tasks were every one of them
executed. That gap is the subject of § 4.

---

## 2. Cost, and what it implies

Honest per-run timings, reconstructed from the ledger's event pairs rather
than taken from the `<stage>_duration_seconds` metric — see § 8 for why that
metric cannot be used here.

| stage | runs | actual time | product |
| :--- | :--- | :--- | :--- |
| spec (incl. nested research + sec) | 1 | 3h 08m | 38 criteria |
| research | 1 | 19m | anchors, 2 spec corrections |
| sec (spec lens) | 1 | 3m | — |
| plan (incl. nested sec) | 1 | 1h 39m | 29 tasks, 11 decisions |
| sec (plan lens) | 1 | 19m | 10 notable · 4 advisory |
| **build** | 1 | **2h 04m** | 14 commits |
| **review 1** | 1 | **13m** | **13 findings, 5 unmet criteria** |
| remediation | — | 1h 41m | 6 fixes, 10 commits |
| **review 2** | 1 | **11m** | **11 findings, 1 data-loss bug** |

**Review cost roughly a tenth of build and returned more per minute than any
other stage.** The second review — 11 minutes over a blueprint the first had
already sensed — raised judge coverage from 11 invariants to 14 and found a
data-loss path (`#410`) the first pass recorded as holding.

This inverts the economics that make "one review" the industry default. In a
human organisation a second full review is expensive because reviewer
attention is the scarce resource and its cost scales with change size. Here a
second pass costs eleven minutes, its cost is roughly flat in the size of the
change, and its yield scales with the defects actually present. **The
constraint that justifies reviewing once does not exist in this pipeline.**

The corollary is in § 7.

---

## 3. What worked, and should not be traded away

Recording these matters as much as the failures: a retrospective that lists
only problems invites the removal of the controls that found them.

- **Every defect was found by the pipeline, not by a user.** Nothing here was
  discovered in production. That is the system working.
- **Red-first with a mutation per fix.** Each remediation item was seen red
  before its fix, mutated after, and restored `md5sum`-identical. One mutation
  lied — see § 6 — and was caught by its own positive control.
- **The census oracle.** `render.sh stats` over a copy of the real 409-record
  collection, byte-identical to a stored pre-increment oracle, verified four
  times. A whole-collection regression guard that costs one command.
- **Full-suite discipline.** The remediation's only defect was a locale-pinning
  breach in a file none of the six items was about. No per-script run could
  have caught it; the full suite did, at 1,672 of 1,673.
- **Findings reproduced before being recorded.** Every finding in the second
  review was reproduced by execution, three with negative controls, one with a
  purpose-built fault-injection rig. Four investigator claims were attacked and
  **rejected** — that work is preserved in `remediation.md` § 4 so it is not
  paid for twice.
- **Deferrals held.** Every explicitly out-of-scope item is still undone. Zero
  scope creep across 24 commits.

---

## 4. The drift: five criteria unmet under a faithfully-executed plan

### What happened

`/jim:issue add` parsed no flags. The dispatch routed the entire argument
remainder to the capture subject and the emitter invocation forwarded neither
`--type` nor `--part-of`, so the spec's own worked example would have filed an
issue *titled* `Auth hardening --type epic`.

### The mechanism, visible in two table rows

`plan.md`'s Requirements Coverage Summary has exactly two columns:

```
| Spec Acceptance Criterion                              | Task(s) |
| Create an umbrella kind without a separate capture flow| 5       |
| Name an umbrella at capture time                       | 6       |
```

Tasks 5 and 6 are `new.sh` tasks. Both criteria are about the **capture
flow** — a skill surface living in `SKILL.md`. The File Manifest then scoped
the `SKILL.md` edit to the `join`/`leave` dispatch entries alone. Executing
tasks 5 and 6 faithfully produces an emitter that accepts flags nobody passes.

Those two rows are precisely the two criteria the first review recorded as
*not satisfied*. The drift is legible in the plan, before a line was written.

### Why nothing contradicted it

Three contributing factors, each systemic:

1. **The coverage table records presence, not sufficiency.** Every criterion
   had a task, so the table read complete. A task list is not falsifiable: you
   cannot run "tasks 5, 6" and watch it fail. Nothing downstream could tell a
   correct mapping from a category error.

2. **Both witnesses shared an author.** The coverage table and the File
   Manifest are separate artifacts that agreed — because one agent wrote both
   in one pass, from one model of the work. Defence in depth adds assurance
   only when the layers are *independently derived*; these were independently
   *formatted*. This is the plan-stage form of the same effect the review skill
   records at review stage, where an author reading their own range produced
   `minor-drift`/5 findings and a fan-out over identical commits produced
   `major-drift`/15.

3. **The build's compliance was the amplifier, not the cause.** A human builder
   holding "the `add` subcommand accepts `--type`" while implementing "add
   `--type` to `new.sh`" would likely notice the gap between them. An agent
   executing a task list will not: the task is the unit of work and it was
   completed correctly. **Agent fidelity converts plan defects into shipped
   defects at close to 1:1.** This is the single most important difference from
   a human workflow, and it argues for moving verification effort upstream in
   proportion.

### What would have caught it

**A verification method per criterion, not a task linkage.** If the coverage
table's second column named the *observable* that demonstrates each criterion —
a test case, a command, a doc-surface assertion — then "38 satisfied" becomes a
set of runnable things rather than a judgment, and the build's completion gate
can check it mechanically.

The decisive detail: **the mechanism already existed.** `tests/docsurfaces.sh`
checks exactly this class of prose-surface property, and the case that finally
closed the criterion —
`case_docsurfaces_capture_flags_reach_the_emitter_invocation`, which derives
its required set from `new.sh`'s own parser and is fail-closed by default —
was written during *remediation*. Had the plan been required to name an
observable per criterion, that case would have been a task, and the criterion
could not have been reported satisfied without it passing.

This is standard requirements-engineering practice (a verification method
attached to each requirement, as in ATDD or safety-critical traceability
regimes), and it is *more* load-bearing here than there, because of factor 3.

---

## 5. The blueprint divergences: why living intent found them late

Four invariant violations, three in-change. Two are the interesting ones.

### `#411` — the build created the divergence

The build added `resolve.sh`, whose header declares it *"the single definition
of what an ordinal, an exact slug or a slug prefix resolves to on a write
path"*, and left `transition.sh`'s `resolve_slug` in place implementing the
same ladder — unmarked and uncompared, the only duplicate in the territory
that was neither, where five other duplicated guards all carry a marker and a
fixture.

**The invariant could not have caught it.** `cross-copy-lockstep` reads:
*"Every guard carrying a sync marker stays byte-identical to the other copies
of that marker."* Its enforceable half is quantified over **marked** copies. An
unmarked duplicate is invisible to it by construction. This is not an
enforcement gap — it is a specification gap: the invariant governs maintenance
of duplicates and is silent on their *creation*.

The generalisable form: **a uniqueness claim in a header is an untested
assertion.** A comment saying "the single definition of X" is a proposition
about the whole repository, made in a file that cannot see the rest of it.

### `#410` — found only on the second pass

A completed transition is destroyed when a post-write reindex fails under a
branch placement. Pre-existing, but the first sensor pass recorded the
governing invariant as **holding**; the second found it. The difference was not
the code — it was which invariants the change-selection dispatched.

### The structural finding underneath both

**All 15 of the group's invariants are `judge`-method. There is no
pattern/structure rung, and no `verify-checks` block.** Verified by count
against the blueprint: 15 judge, 0 mechanical.

Three consequences:

1. **Every invariant costs an LLM dispatch**, so coverage is bounded by
   appetite and fan-out cap rather than by cost-free mechanical scanning.
2. **Coverage is non-deterministic.** The same change, the same blueprint, two
   passes: 11 invariants judged, then 14. Three that were `skipped (scope)` the
   first time were in scope on re-derivation, and all three held — meaning the
   first review reported *unexamined* where the second reported *checked*. LLM
   change-selection is not idempotent.
3. **Nothing fails fast.** A mechanical floor breach is loud and free; a judge
   verdict is neither.

This matters most for `issue` specifically: it carries the project's widest
fan-in provides face after `platform`, and it has no mechanical floor at all.

### What would help

Not "replace judges with patterns" — the prose captures more than a pattern
can, which is why it is prose. Rather: **give each invariant a mechanical
necessary condition where one exists**, so the floor catches the common breach
loudly and for free, and the judge is spent on the residue. Several are cheap:

| invariant | mechanical necessary condition available |
| :--- | :--- |
| `insights-capability-boundary` | the analyst's tool grant is a frontmatter set — a structure check |
| `issue-file-never-sourced` | `must-not` pattern for `source` / `eval` on an issue path |
| `atomic-index-write` | no direct redirect to the index path outside the writer |
| `cross-copy-lockstep` | byte-compare every *marked* copy pair — the shape `tests/jimfile.sh` already uses for `is_valid_id` |
| `declared-vocabularies` | every declared array's members are not restated literally elsewhere |

None of these is the whole invariant. Each is a condition whose breach is
certainly a violation, which is all a floor needs to be worth having.

---

## 6. The recurring shape: the second site

Four of this increment's defects are one failure mode wearing different
clothes. Naming it is more useful than the four individually.

| defect | the first site | the second site that was missed |
| :--- | :--- | :--- |
| `#411` | `resolve.sh` added | `transition.sh`'s ladder left behind |
| `#416` | `new.sh` comment fixed | `SKILL.md` checklist still forbidding `epic` |
| `#417` | `SKILL.md` updated | `docs/features/issues.md` untouched |
| arch miscount | `ARCHITECTURE.md` tree updated to ten | prose still says "Nine" (`:1937`, still open) |

The last is the most instructive: **`/jim:arch` produced it.** An automated
generator ran at the build's completion gate, updated one representation of the
script count, and left the other. Automation does not exempt a surface from
this failure — it just makes the second site harder to notice, because the
first was refreshed by a tool that reported success.

### Why agents are especially prone to it

An agent given a list works the list. The remediation fixed the superseded
`type` rule at the four sites the review's finding named; the file had five.
Neither the build nor the fix pass derived the set — both inherited it, and an
inherited enumeration carries its author's blind spot forward with the
authority of a specification. An agent asked to "fix these four sites" will fix
four sites and report success; it will not spontaneously ask whether four is
the whole set.

### The fix that actually works

**Derive the enumeration from a declared constant rather than restating it.**
This is what closed `#416` and `#417`, and the project already had the idiom —
`transition_verbs()` reads `TRANSITION_VERBS` out of the script; the new
`issue_kinds()` reads `ISSUE_TYPES` out of the emitter. A derived check cannot
inherit a stale list because it has no list.

It is mistake-proofing rather than diligence: the failure becomes structurally
impossible instead of merely discouraged. The limit is real, though — `#418`
records a convention (the close-side resolution note) that is **not**
derivable, because whether a body carries a resolution is a property of prose,
not of a declared vocabulary. Where derivation is unavailable, the rule has to
be stated at the point of use, and stating it is then the whole of the control.

---

## 7. Agentic-specific dynamics

The findings above that generalise beyond this project, stated as properties of
LLM-driven development rather than of this pipeline.

**Fidelity amplifies upstream defects.** A compliant executor removes the
informal error-correction a human builder performs by noticing that an
instruction does not accomplish its stated purpose. Verification effort should
be redistributed toward the artifacts that instruct — spec and plan — in
proportion to how faithfully they will be executed. § 4 is one plan defect
becoming five unmet criteria.

**Independence is worth roughly 3×, and it is measurable.** The review skill
records the comparison: same commits, author's own reading → `minor-drift`/5;
fan-out → `major-drift`/15. Independence is not a process nicety here, it is
the dominant term in detection rate. It follows that *self-review by the
authoring context should not count as review at all* — which the skill already
encodes by requiring an undelegated fan-out to be disclosed and counted.

**Coverage is non-deterministic where scope is chosen by judgment.** 11 vs 14
invariants on identical input (§ 5). Wherever the selection input is
mechanically computable — territory ∩ changed files — computing it removes the
variance for free. Where it is not, the mitigation is repetition: run the
sensor twice and treat *agreement* as the signal rather than the first pass's
verdict.

**Verification steps that fail open are disproportionately dangerous.** Two
occurred here. A `sed` mutation whose `||` clashed with its own `s|…|`
delimiter never applied, and the case "passed" for the wrong reason. A `grep`
presence probe with an unescaped `$` in a BRE pattern reported the mutant
absent while it was present. A human watching a terminal carries ambient
skepticism; an agent reads the exit code. **Every verification step needs a
positive control** — a mutation must prove it applied, a probe must be run
against the unmutated copy where a matching result exposes the probe rather
than the code. Both instances are now in the false-success table in
`docs/notes/process-improvements.md`, which is the right home precisely because
that table is a list of things that *looked like success*.

**Cheap verification changes the optimal number of passes.** § 2: review cost
~10% of build and its second application still returned a data-loss bug. Team
practice that reviews once is calibrated to scarce human attention. That
constraint is absent here, and the policy should be recalibrated to the actual
cost rather than inherited from the human case.

**Context discontinuity is a first-class risk, and the mitigation is
selective.** This increment spanned several compactions. What made the handoff
work was recording *what is expensive to re-derive* — claims attacked and
rejected, traps that cost real time, environment facts — and deliberately
**not** restating findings that live in the artifacts. Four rejected claims
were preserved; without that record each would have been re-raised and
re-investigated by the next context, at full cost, indefinitely.

**A verb that completes can still leave the record incomplete.** Closing an
issue set `status`, `outcome` and the stamp, and the result looks finished from
every field a reader would check — while the half that cannot be re-derived
(which commit, what pins it, what was deliberately left alone) is simply
absent. An agent does what the verb does and stops. Where a convention lives
only in a maintainer's habit, it is invisible to the executor; `#418` records
this one.

---

## 8. A caveat on this document's own metrics

`<stage>_duration_seconds` in the ledger is the span from the stage's **first**
`started` to its **last** `finished` — verified at `jimledger.sh:928-931`,
where `se` takes the first start and `fe` the last finish. For a stage run more
than once it therefore includes every other stage that ran in between:

| stage | runs | reported | actual | inflation |
| :--- | :--- | :--- | :--- | :--- |
| `sec` | 2 | 31,024s | 1,340s | **23×** |
| `review` | 2 | 7,437s | 1,426s | 5× |
| `build` | 2 | 15,212s | 7,417s | 2× |
| `spec`, `research`, `plan` | 1 | — | — | accurate |

The failure mode is self-selecting in the worst way: the metric is accurate for
untroubled increments and wrong for exactly the ones that were re-run, which
are the ones a retrospective most wants to measure. § 2's table is reconstructed
from event pairs for this reason.

Already tracked as **`#252`** (`open`, medium), filed 2026-08-05. This
increment is a concrete instance that quantifies it.

---

## 9. Actions

Ordered by expected value. Each names the surface it changes and the check that
would make it stick — an action with neither is a wish.

| # | Action | Surface | Made durable by |
| :--- | :--- | :--- | :--- |
| 1 | Add a **Demonstrated by** column to Requirements Coverage naming the observable per criterion; hold the completion gate on each passing | `/jim:plan`, `/jim:build` | a check that every coverage row names a runnable observable |
| 2 | Add a **coverage-adversarial pass** at plan time — one independent reader asked only "does this task set produce this criterion?" per criterion | `/jim:plan` | a recorded per-criterion verdict, as review records findings |
| 3 | Give the `issue` blueprint a `verify-checks` block with mechanical necessary conditions, starting with the five in § 5 | `docs/specs/issue/000-blueprint` | the floor runs free on every sensor pass |
| 4 | Mechanise judge change-selection wherever scope ∩ changed-files is computable | `/jim:verify` | removes the 11-vs-14 variance by construction |
| 5 | Treat a **uniqueness claim in a header as a testable assertion**: a script declaring itself the single definition of X requires a case asserting exactly one implementation | `cross-copy-lockstep`, authoring convention | extend the invariant to cover creation, not only maintenance |
| 6 | Require a **positive control on every verification step** — mutations prove they applied, probes run against the unmutated copy | `process-improvements.md` (recorded) | the two instances are in the false-success table |
| 7 | Run the living-intent sensor **twice with independently derived selection**, treating agreement as the signal | `/jim:review` | § 2's economics make this ~11 minutes |
| 8 | Open a build stage for any fix pass | `/jim:build` (recorded in `review.md`) | costs one command; without it the review range excludes every fix |
| 9 | Fix `#252` so stage durations sum rather than span | `jimledger.sh` | already filed |
| 10 | Close the `ARCHITECTURE.md` prose/tree miscount through `/jim:arch` | `ARCHITECTURE.md:1937` | still open; declined at review |

**1 and 2 are the ones that address the drift.** 3, 4 and 5 address the
blueprint divergences. The rest are hygiene with known cost.

---

## 10. Open risks carried forward

- **`#415`** (critical, pre-existing) — `backfill.sh` and `migrate.sh` read
  past the frontmatter fence, and under `--apply` that path reaches a file
  rename. The most serious thing either review found, and outside this
  increment's change set. Not fixed.
- **`#410`** (data loss, branch placements) — reproduced end to end, not fixed.
- **One invariant remains scope-skipped** in every pass so far
  (`collection-rewrite-preview-gated`), because its code lives in the two files
  above, which no recent change has touched. An invariant that is never in
  scope is never checked, and its skip reads identically to a clean result on
  every report.
- **`ARCHITECTURE.md:1937`** still miscounts the group's scripts.
- **Judge-only enforcement** for all 15 invariants, until action 3 lands.

---

## 11. The one-sentence version

The pipeline detected everything it was built to detect and detected it late:
the drift was already legible in two rows of the plan's coverage table before
any code was written, and it survived because a task list cannot be run and
both artifacts that could have contradicted it were written by the same author
in the same pass.
