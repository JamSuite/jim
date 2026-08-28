# Remediation — Epic authoring and views

The fix pass agreed after the first review returned **`major-drift`**, and the
record of what it delivered. It was scoped deliberately: **the acceptance
criteria the increment did not satisfy**, plus the three cheap correctness
defects the review found in code the build wrote. Everything else the review
surfaced is follow-on work and is listed under § 5.

**The pass is complete.** All six items landed, the re-review returned
**`minor-drift`** with **38 of 38** criteria satisfied, and the held blueprint
update has since run to completion. The commits, oldest first:

| commit | item |
| :--- | :--- |
| `9ca4c1b` | § 2.2 — refuse an epic filed into an epic |
| `770bcf0` | § 2.3 — roll up every umbrella, not only joined ones |
| `fa4a4cc` | § 2.4 — refuse a bad umbrella on an empty collection |
| `b53a0b6` | § 2.5 — drop dead state and correct two comments |
| `37bd305` | § 2.6 — put `join` and `leave` on the help surface |
| `40c1110` | § 2.1 — wire the capture flags through `/jim:issue add` |

---

## 1. What was agreed

Two decisions, both the developer's, both explicit:

- **Fix the AC gaps rather than filing them.** An increment whose own criteria
  are known-unmet must not be marked complete on the grounds that its tasks
  were executed. The plan stays incomplete until its criteria hold.
- **Hold the blueprint update** until the fixes land, so living intent
  describes the increment as it ends up rather than as it was.

Both are discharged. The criteria hold; the blueprint update ran after the
re-review and is committed.

---

## 2. The work, item by item

Each item carries the finding, the reproduction, the fix, and the case it owes
— followed by **what landed**. Every case was proven red before its fix, and
every fix was mutation-tested with the file restored byte-identical by
`md5sum`.

### 2.1 The capture flow was not wired — *the reason the first review was major-drift*

**Finding.** `/jim:issue add` parsed no flags. The `add` dispatch routed the
entire remainder to the capture **subject**, and step 6's emitter invocation
passed neither `--type` nor `--part-of`. The spec's own UI mockup therefore
filed an issue *titled* `Auth hardening --type epic`. The `type` field bullet
compounded it, still stating the rule the increment reverses.

**Root cause, upstream of the build.** `plan.md`'s Requirements Coverage mapped
both capture-flow criteria to tasks 5 and 6 — *script* tasks — and its File
Manifest scoped the `SKILL.md` edit to the `join`/`leave` dispatch entries. The
build executed the plan faithfully. The plan mapped a capture-flow criterion to
a flag task.

**What landed.** The `add` dispatch now names both flags, states that each is
removed **with its value** before anything else is read, and carries the spec's
own mockup as a worked example with the broken outcome explicitly forbidden.
The `type` bullet states the current rule; the `relations` bullet says where
`part-of` comes from and that it is not hand-authored; step 6 forwards both
flags and describes the pre-spend refusals.

**Case owed, and delivered.**
`case_docsurfaces_capture_flags_reach_the_emitter_invocation` derives its
required set from `new.sh`'s own flag parser, with a hand-maintained
`capture_flag_excused` list whose default arm makes an unlisted flag
**required**. Proven fail-closed by adding a `--severity` flag to the parser
and watching the case go red **with no edit to the case**. Both directions are
checked: a flag the emitter parses must reach the documented invocation, and
the invocation may pass no flag the emitter would refuse.

**What it did not close.** Two defects on the same surface survived and are now
tracked — see § 5.

### 2.2 The two write paths disagreed about nesting

**Finding.** `new.sh` validated that the `--part-of` *target* was an epic but
never that the record *being filed* was not itself one, so the capture path
wrote the state `join` refuses.

**What landed.** A self-kind refusal in the `--part-of` resolution block, after
the target's kind is validated — the same order `join` checks the same pair, so
both paths refuse the identical state with a byte-identical message. It sits
above the allocator with the other capture-time checks.

**Cases owed, and delivered.** `case_new_refuses_an_epic_filed_into_an_epic`,
plus a third refusal driven through
`case_new_refusals_leave_the_ordinal_unspent`. The two discriminate: moving the
refusal below the allocator leaves the first **passing** and the second
**failing**, so wording and position are separately pinned.

### 2.3 The census rollup dropped a zero-member umbrella

**Finding.** The `== Epics ==` rollup iterated the progress maps' keys, which
exist only where a membership **edge** points. An umbrella nobody had joined
never became a key and was omitted — while the same run's container headline
still counted it, and the index, `list epic` and `show` all reported it.

**What landed.** The shared derivation now carries `EPIC_ROWS`, the roster of
umbrella rows in index order, reset with the progress maps. The rollup
enumerates that and reads progress with a zero default — the reason
`format_row` and `show` were already correct. This is the mirror of the defect
fixed earlier in the build: that one listed non-umbrellas because it trusted
the edges for membership; this one omitted umbrellas because it trusted them
for existence.

**Case owed, and delivered.**
`case_issues_render_stats_rollup_lists_a_memberless_umbrella`. Two mutations
kill it: reverting to the edge-keyed enumeration, and dropping the kind test
from the roster (which also breaks the non-umbrella case).

### 2.4 An empty collection answered where it should refuse

**Finding.** `build_derived_axes` deferred its `--epic` refusal when no row
carried `type`, so the schema gate could name the row field instead. **Zero
rows** satisfied that condition vacuously, and the schema gate's own
`seen_rows > 0` precondition declined too — so nothing refused.

**What landed.** The condition now also requires that a row exists, so the
deferral applies to a genuinely stale index and not to a rowless one.

**Case owed, and delivered.**
`case_issues_render_refuses_an_unresolvable_umbrella_on_an_empty_collection`,
carrying its stale-index control. It discriminates in both directions:
restoring the vacuous condition kills the empty half; removing the deferral
entirely kills the control half.

**The contested reading, resolved.** The `staleness-gated-reads` judge argued
the empty answer was not a violation of *that invariant*, since a zero-row
collection has no row a current-schema index would have written differently.
That reasoning was sound and did not answer the spec AC. Both now hold: the
re-review's judge confirmed the new condition is correct in both directions,
and the invariant still holds.

### 2.5 Dead code and two comments that contradicted adjacent code

**What landed.** `row_status` deleted — declared, seeded, written once per row,
never read; orphaned when the rollup moved into the shared derivation. The
`AXIS_FIELDS` comment now describes the `epic`/`blocked` split accurately, and
`index.sh`'s header says five sections and names `## Epics`.

**Verified rather than assumed.** The re-review established a positive control
for the dynamic-scoping risk — `row_matches` genuinely does read `cmd_stats`'
locals — and showed `row_status` was not among them. It also corrected the
framing: the filter-independence property the deleted comment claimed is
provided by the shared derivation's own unfiltered re-read, and is stated where
that call is made. Deleting the comment removed a false attribution rather than
the only statement of a live invariant.

### 2.6 `/jim:issue help` omitted the new verbs

Raised as adjacent-to-scope and done, on the argument that it is the same
failure in the same surface as § 2.1. It is reversible alone (`37bd305`).

**What landed.** The help view lists `join` and `leave`, and — the actual fix —
`case_issues_render_help_points_at_the_lifecycle_verbs` now reads its verb
domain from `TRANSITION_VERBS` instead of hand-listing five. Proven by adding
an eighth verb to the array and watching the case name it.

---

## 3. What the pass owed, and delivered

- **Red-first evidence for every case.** Delivered — each case was run and seen
  red before its fix, and the failing assertions recorded.
- **A mutation per fix.** Delivered, with the file restored and `md5sum`
  verified each time. One mutation silently failed to apply (a `sed`
  substitution containing `||` clashed with its own `s|…|` delimiter) and
  reported a false pass; it was caught only because the step echoed the grep
  proving the mutant was in place. **A mutation must prove it applied before
  its result means anything** — worth adding to
  `docs/notes/process-improvements.md`.
- **The census oracle re-verified.** Byte-identical to the stored pre-increment
  oracle for the fourth time, over the same 409-record set, taken against a
  copy. The first attempt differed by exactly one record — an issue filed by
  the first review *after* the oracle was taken — and removing it restored
  identity by `md5sum`.
- **The full suite, backgrounded and alone.** Run three times. The first
  failed at 1,672/1,673 on a project-wide locale-pinning hygiene invariant that
  the new doc-surface sweep's `sort -u` breached — a file none of the six items
  was about, which no per-script run could have caught. Pinned, amended into
  its own commit, and green at **1,673** thereafter.
- **A re-review.** Delivered. `major-drift`/13 → **`minor-drift`**/11 on the
  append-only ledger, both lines visible.
- **Then the blueprint.** Delivered — see § 6.

---

## 4. Do not re-litigate these

Attacked directly and held, across both reviews. Re-deriving them is the
expensive half of what has already been paid for.

- **The roster derivation terminates by the shape of its pass**, not a cycle
  guard — traced against A↔B and a self-loop.
- **The `(member, umbrella)` dedup is honoured on both sides** with the
  identical key shape; removing it was mutation-tested.
- **The new index section cannot forge a line or a nesting level.** The case
  asserts counts and shapes rather than the absence of the injected string,
  and it kills the mutant on all three sanitizer stages.
- **The no-op filter is correct for both field classes** — the composed-line
  comparison was mutation-tested against the value comparison it replaces.
- **The capture refusals cost no ordinal**, proven by reading the allocator's
  registry log; the case goes red when a refusal is moved below the spend.
- **All four critical invariants hold** — `untrusted-body-never-shell`,
  `id-gate-before-path` (census uniform at one guard per site across sixteen
  sites in ten scripts), `placement-gate-before-git`,
  `materialization-contained` — plus `identity-validated-before-record`. The
  placement door's negative-offset markers are undisturbed by the two forwarded
  flags, and the argument is structural: the offsets count back from a
  fixed-length appended suffix, so they never reference the forwarded argv's
  length.
- **The contract edges hold.** 4 checked, 0 violations, twice; the change is
  additive on every provides face.
- **Claims rejected on verification, which should stay rejected.** The raw-id
  echo in `transition.sh` predates the increment; the `leave`-availability
  comment is correctly scoped to containment violations; `status` is sanitized
  once before both bucketing and display; and — from the re-review —
  `EPIC_ROWS` needs no sentinel-key guard, because the file's sentinel idiom
  applies to arrays declared *without* an `=()` initializer and the identical
  count-guarded pattern already shipped against `EPIC_TOTAL`.

---

## 5. The open issues, and whose they are

Thirteen issues trace to this increment, all now carrying durable ordinals.
They divide by one question — **should this have been done in the build?** —
and the answer is not the same as *when it was found*: the second review found
the build's defects and the build's own batch found follow-ons. Attribution is
recorded here because it is the only place it survives; an issue's body says
what it is, not whose it was.

### 5a. Build scope — should have been done then

**All four are closed** (`b686454a`, `d4984a8c`, `414fc3b4`, `b58b4d5c`;
closed at `25da3537`), in a follow-on pass after this document was written.
The attribution below is left as it was recorded — it is why the work was
taken, and a record that rewrites itself once the work lands stops being
evidence of anything.

Three of the four closed by a **derived check** rather than by the edit alone,
which is the shape their shared failure asked for: the capture checklist now
reads the emitter's `ISSUE_TYPES`, the lifecycle-verb sweep now covers
`docs/features/issues.md`, and the duplicate reference ladder was deleted
rather than annotated. `#414` closed on a behavioural test alone, having no
enumeration to derive. Suite 1,677 green.

One correction the pass produced: `#417` named four stale places and there
were **five** — the interactive-capture section documented `add` with neither
flag. Derived from the doc's own structure rather than from the issue's list,
which is the failure `#416` itself was.


- **#411 `cross-copy-lockstep`** (high). The build *created* the duplicate:
  it added `resolve.sh` and left `transition.sh`'s `resolve_slug` in place,
  unmarked and uncompared, in a territory where five other copy-pairs all carry
  a marker and a fixture. The divergence is real but currently **masked** —
  both callers discard `resolve.sh`'s stderr, so today's observable behaviour
  coincides by accident rather than by construction. The issue frames it as the
  design fork it is: either the primary id delegates too, or the header stops
  claiming to be the single definition.
- **#414 census headline vs rollup** (medium). Both halves shipped in the same
  increment — a filter-scoped `Epics:` line above an unfiltered rollup.
  Confirmed by running pre-remediation code against the same fixture, so it is
  the build's rather than this pass's, though § 2.3's fix widens the population
  that can hit it.
- **#416 the checklist's superseded `type` rule** (high). The plan told the
  build to delete this claim; it was deleted at one site in `SKILL.md` and left
  standing at a second in the same file. Three investigators found it
  independently.
- **#417 the feature doc** (medium) — the weaker case, recorded as arguable
  rather than settled. No criterion required updating
  `docs/features/issues.md`, but the build falsified four statements in it, and
  the doc-surface sweep the build *added* to catch exactly this class was
  scoped to README, WORKFLOW and the skill body rather than to the feature doc
  for the verbs it derives.

**What these three-and-a-half share:** each is a *second site the build did not
sweep for* — a second resolver, a second population, a second restatement of a
rule. That is the same failure that made the first review `major-drift`, and
the same one § 2.1's fix pass then repeated by working from a four-site list
when the file held five.

**And what is not here.** The five unmet acceptance criteria were
unambiguously build scope and are absent from this list because they were fixed
rather than filed (§ 1). Had they been filed, this section would name eight.

### 5b. Outside the build — deferred by the spec, or genuine follow-ons

- **#405 grouping the read views by umbrella** (low) — the spec's Out of Scope
  names it and says it is tracked with the other grouping work.
- **#408 membership doubles the index graph section** (medium) — the spec
  *states* this design: the complete membership stays in the Graph section
  below the roster, always. A size question the spec accepted, not an oversight.
- **#406 an honest completion rate from `outcome`** (medium) — a new capability
  the increment's fields make cheap. No criterion asked for it.
- **#409 the `updated` field has no reader** (low) — confirmed deferred, and
  named as such in both reviews' scope-creep checks.
- **#413 `leave` cannot remove a dangling membership** (medium) — reachable
  because membership is one-sided by design, but no criterion required
  repairing it. The `leave`-availability comment beside it is correctly scoped
  to containment violations, which is a different scenario (§ 4).
- **#412 malformed capture-flag input** (high) — downstream of *this pass*, not
  the build: the build never wired the flags at all, so the ambiguity could not
  have existed until § 2.1 introduced the extraction instruction.

### 5c. Pre-existing — older than this increment

- **#415 fence-scoped frontmatter reads** (critical). `backfill.sh`'s
  `field_value`/`num_of` and `migrate.sh`'s `build_plan` `field_value` read
  past the frontmatter fence. Reproduced twice. Sharper than first recorded:
  `migrate.sh` carries **both** readers — the unscoped one and a correctly
  fence-scoped pair — so the file knows the hazard and its `prefix` path uses
  the wrong helper anyway, and under `--apply` that path reaches a file rename.
  Neither file is in this increment's change set. The most serious thing either
  review found that this pass did not fix.
- **#410 `atomic-index-write`** (medium). `transition.sh` aborts the placement
  handle after a successful write, destroying a completed transition under a
  branch placement. Reproduced end to end with a fault-injection rig, and new
  in the second review — but the line predates the range, so it is pre-existing
  despite being found here. Blast radius is branch placements plus a transient
  index failure.
- **#407 an unbounded relation type reaches the graph** (low) — in
  `index.sh`'s `parse_relations`, untouched by this increment.

### 5d. Declined, and already tracked

**Declined, recorded in `review.md` only:** the unsanitized `--epic` refusal
operand, the `ARCHITECTURE.md` script miscount, the tautological `--reviewed`
assertion in the new sweep, the unpinned refusal-message parity, the
`stats --epic` coverage asymmetry, the `--type` quoting inconsistency, and the
two cases that cannot go red. Two of those — the miscount and the tautological
assertion — are build scope by the § 5a test and were declined anyway; that is
a deliberate call, not an oversight.

**Already tracked:** `declared-vocabularies` has an open record, which is why
the fork filed two divergence issues rather than three. It is build scope by
the § 5a test: this increment added the third declaration of the record-kind
vocabulary.

---

## 6. Where this ends

| | |
| :--- | :--- |
| criteria | **38 / 38** satisfied |
| review verdict | `major-drift`/13 → **`minor-drift`**/11, both on the ledger |
| living intent | 15 invariants — 10 hold · 4 violated · 1 skipped (scope) |
| contract edges | 4 checked · 0 violations |
| suite | 1,673 green |
| blueprint | updated and committed — six additive edits |
| project map | contract graph restamped; 26 edges, unchanged |

The blueprint update ran with all three in-change violations resolved **fix the
code**, so its Invariants table took no edits and the two untracked divergences
became issues. Its six edits are additive: the umbrella capability across
Responsibility, three Provides faces, the lifecycle verb list, and `resolve.sh`
in Structure with the script count corrected.

**`plan.md` is still `approved`, not `complete`.** Marking it is the
developer's call and the one gesture this pass deliberately did not make.
