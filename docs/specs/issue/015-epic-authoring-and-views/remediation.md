# Remediation — Epic authoring and views

The fix pass agreed after `review.md` returned **`major-drift`**. It is scoped
deliberately: **the acceptance criteria this increment does not satisfy**, plus
the three cheap correctness defects the review found in code this build wrote.
Everything else the review surfaced is follow-on work and is listed under
§ 5 — filing it is not this pass's job, but neither is fixing it.

**Nothing here has been started.** The working tree is clean at `6a5fe65`.

---

## 1. What was agreed

Two decisions, both the developer's, both explicit:

- **Fix the AC gaps now** rather than filing them. An increment whose own
  criteria are known-unmet must not be marked complete on the grounds that its
  tasks were executed. The plan stays incomplete until its criteria hold.
- **Hold the blueprint update.** `require_blueprint` is `true`, so the review's
  completion gate is held open — deliberately. The group blueprint records what
  the group *is*, and folding a major-drift review into it would describe
  capabilities that are not reachable. Re-run `/jim:blueprint --from-review`
  after this pass, so living intent describes the increment as it ends up.

---

## 2. The work, item by item

Each item carries the finding, a reproduction that is known to work, the fix
shape, and the case the fix owes. **Red-first on every one** — the review found
two cases in this increment that cannot go red, so a case added here that
passes before the fix is a defect in the case, not evidence.

### 2.1 The capture flow is not wired — *the reason this review is major-drift*

**Finding.** `/jim:issue add` parses no flags. `skills/issue/SKILL.md:33`
routes the entire remainder after `add` to the capture **subject**, and step 6's
emitter invocation (`SKILL.md:210-216`) passes neither `--type` nor
`--part-of`. The spec's own UI mockup (`spec.md:220,223`) therefore files an
issue *titled* `Auth hardening --type epic`.

`SKILL.md:156` compounds it, still stating the rule this increment reversed:

> **type** — always `issue` for new captures. An umbrella is made by changing
> this field on an existing record, not by filing a different kind of one.

That is the identical claim the plan told the build to delete from `new.sh`'s
comment because the increment makes it false. It was deleted in one file and
left standing in the other.

**Reproduction.** Read `SKILL.md:33`, `:156`, `:160` (the relations bullet,
which never mentions `part-of`), and `:210-216`. No flag reaches the emitter.

**ACs unmet.** *"A developer can create a record of the umbrella kind without
learning a capture flow separate from the one that files an ordinary issue"*
and *"A developer can name an umbrella at capture time … one command rather
than two."* Both are about the **capture flow**, which is the command, not the
script's flag surface.

**Root cause, and why it is not a build defect.** `plan.md`'s Requirements
Coverage maps both criteria to tasks 5 and 6 — *script* tasks — and its File
Manifest scopes the `SKILL.md` edit to the `join`/`leave` dispatch entries and
the § 6a `updated` correction. The build executed the plan faithfully. The
plan mapped a capture-flow criterion to a flag task.

**Fix shape.**

- `SKILL.md:33` — the `add` dispatch must extract `--type <kind>` and
  `--part-of <csv>` from `$ARGUMENTS` before the remainder becomes the subject.
  State the extraction explicitly; a skill body is instructions to an agent, so
  "parse flags" is not enough — say which flags, and say that the remainder
  after removing them is the subject.
- `SKILL.md:210-216` — step 6's emitter template forwards both when present.
- `SKILL.md:156` — replace the superseded rule. Say what is now true: a capture
  may file either kind, `--type epic` creates an umbrella, and the field is no
  longer always `issue`.
- `SKILL.md:160` — the relations bullet should mention `part-of` alongside the
  four it lists.

**Case owed.** A `tests/docsurfaces.sh` case asserting the capture flags reach
the documented emitter invocation — derived from `new.sh`'s own flag list
rather than a retyped pair, so a third capture flag enters it without an edit.
Note the review's own finding 12: a sweep carrying its own list has the defect
it exists to catch.

### 2.2 The two write paths disagree about nesting

**Finding.** `new.sh` validates that the `--part-of` *target* is an epic, but
never that the record *being filed* is not itself one. So the capture path
writes the state `join` refuses.

**Reproduction** (verified during the review):

```
new.sh --type epic --part-of <existing-epic>   → rc 0, writes type: epic + part-of: [outer]
transition.sh join <epic> <epic>               → rc 1, "an epic cannot belong to an epic"
```

**AC unmet.** *"An attempt to put an umbrella under an umbrella is refused."*
Unscoped in the spec — it is not a `join`-only criterion. The index warns after
the fact, but the spec's own Open Question settled this as *"enforced at the
write path and in the index both."*

**Fix shape.** In `new.sh`'s `--part-of` resolution block, after the target's
kind is known, also refuse when `$type` is `epic`. It belongs in the same
pre-spend block — the refusal must cost no ordinal, which is what
`case_new_refusals_leave_the_ordinal_unspent` pins.

**Case owed.** `case_new_refuses_an_epic_filed_into_an_epic`, plus extending
the existing unspent-ordinal case to drive this third refusal.

### 2.3 The census rollup drops a zero-member umbrella

**Finding.** `cmd_stats`' `== Epics ==` rollup iterates `EPIC_TOTAL`'s keys,
and `build_epic_progress` only creates a key when it sees a `part-of` **edge**
targeting that umbrella. An umbrella with no members never becomes a key, so it
is omitted entirely — while the same run's `Epics: N open · M closed` headline
still counts it.

**Reproduction** (verified): a collection with `20260101-empty` (no members) and
`20260102-full` (one member). The index section lists both; `list epic` lists
both (`0/0 closed`); `show` reports `_no members_`. Only `stats` drops it.

**ACs unmet.** *"The read views can list the umbrellas in the collection, each
with its progress"* and *"An umbrella with no members reports an empty roster
rather than failing or reporting nothing at all."*

**Fix shape.** The rollup must enumerate **epic rows**, not edge targets —
looking each up with the `${EPIC_TOTAL[$slug]:-0}` default that `format_row`
and `render_issue_file` already use, which is exactly why those two surfaces
are correct. Note this is the mirror of the defect fixed in `f3ac0b7`: that one
listed non-umbrellas because it trusted edges; this one omits umbrellas for the
same reason.

**Case owed.** `case_issues_render_stats_rollup_lists_a_memberless_umbrella`.

### 2.4 An empty collection answers where it should refuse

**Finding.** `build_derived_axes` defers its `--epic` refusal when no row
carries `type`, so the schema gate can name the row field instead. With **zero
rows** that guard also fires, and `schema_gate`'s own `seen_rows > 0`
precondition declines too — so nothing refuses.

**Reproduction, with a negative control:**

```
empty collection      list --epic no-such-umbrella → rc 0, "_No matching issues._"
populated collection  list --epic no-such-umbrella → rc 1, "no epic matches '…'"
```

**AC unmet.** *"The refusal is distinguishable from a query that matched
nothing. An empty result means no record matched; it never means the reference
could not be resolved."*

**Contested, and worth carrying.** The `staleness-gated-reads` judge argued
this is *not* a violation of that invariant: with zero rows there is no row a
current-schema index would have written differently, so the empty answer is
truthful. That reasoning is sound for the **blueprint invariant** and does not
answer the **spec AC**, which is about a developer distinguishing two outcomes.
Both readings are recorded; the fix is cheap either way.

**Fix shape.** Distinguish "rows exist but none carries `type`" (genuine schema
staleness — keep deferring) from "no rows at all" (nothing to be stale about —
resolve, and refuse when resolution finds nothing). Track whether any row was
seen alongside `any_type`.

**Case owed.** `case_issues_render_refuses_an_unresolvable_umbrella_on_an_empty_collection`.

### 2.5 Dead code and two comments that contradict adjacent code

Three small defects in code this build wrote. Each is a one-line class of
error, and each is the kind a later reader trusts.

- **`row_status` is dead.** `render.sh` declares it, seeds it, and writes it
  once per row — and **never reads it**. It was added for the rollup, then
  orphaned when the rollup moved into `build_epic_progress`, which does its own
  read. It costs an associative-array build over every row for no effect, and
  its comment asserts a purpose it does not serve. Delete it and the comment.
- **`render.sh`'s comment above `AXIS_FIELDS`** still says `epic` and `blocked`
  "are derived from the index's Graph section rather than from a row field, and
  carry `-` to say so" — three lines above the array where `epic:type` no
  longer does. Correct it to describe the split.
- **`index.sh`'s header** says the script writes "four sections" and enumerates
  Summary / Issues / Graph / Integrity Warnings. It emits five.

**Case owed.** None for the comments — they are prose about current behaviour.
The dead-code removal is covered by the existing suite going green.

### 2.6 Adjacent, cheap, and arguably part of "reachable through the command"

Not among the five ACs, but it is the same failure in the same surface and the
fix is small. **Raise it before doing it** if the pass is being kept strictly to
the agreed scope.

`/jim:issue help` — `render.sh`'s `cmd_help` — omits `join` and `leave`
entirely. Its regression test, `case_issues_render_help_points_at_the_lifecycle_verbs`,
hand-lists the five old verbs and therefore passes green. This is a repeat of a
defect class already recorded in the collection: a help text that told users to
close an issue by hand was fixed once for the five-verb rollout, and the same
staleness has returned for the two new verbs.

The right fix is not to add two lines. It is to make the case derive its verb
domain from `TRANSITION_VERBS`, the way `tests/docsurfaces.sh` and
`tests/place.sh` already do — then the help text must follow.

---

## 3. What this pass owes at the end

- **Red-first evidence for every case added.** A case that passes before its
  fix is a finding about the case.
- **A mutation for each fix**, on the pattern the build used: neuter the guard,
  watch the named case go red, restore from an absolute scratch path, verify by
  `md5sum`. Two of this increment's existing cases cannot go red; do not add a
  third.
- **The census oracle re-verified.** Copy `docs/issues/*.md` to a scratch
  directory, delete the copied `INDEX.md`, run `render.sh stats` against the
  copy, and diff against the stored `census-before.txt`. It has been
  byte-identical three times; it must stay so, because the collection still
  holds no umbrellas. Take it against a **copy** — a read regenerates
  `INDEX.md` when it judges it stale, which is a write to a tracked artifact.
- **The full suite, backgrounded and alone.** ~9 minutes, longer under load,
  and never concurrently with anything — subagents included.
- **A re-review.** The verdict is recorded on an append-only ledger, so a
  second `review finished` line adds to the trajectory rather than replacing
  it. `major-drift → aligned` is exactly what that ledger is for.
- **Then** `/jim:blueprint --from-review`, which is held until this lands.

---

## 4. Do not re-litigate these

The review attacked each of these directly and they held. Re-deriving them is
the expensive half of what has already been paid for.

- **The roster derivation terminates by the shape of its pass**, not a cycle
  guard — traced against A↔B and a self-loop.
- **The `(member, umbrella)` dedup is honoured on both sides**, `index.sh` and
  `render.sh`, with the identical key shape. Removing it was mutation-tested.
- **The new index section cannot forge a line or a nesting level.** `row_safe`
  strips the control range containing `\012`; the case asserts counts and
  shapes, not the absence of the injected string, and it kills the mutant.
- **The no-op filter is correct for both field classes.** The composed-line
  comparison was mutation-tested against the value-comparison it replaces, and
  the failure it prevents is the partial, silent one.
- **The capture refusals genuinely cost no ordinal**, proven by reading the
  allocator's registry log, and the case goes red when a refusal is moved below
  the spend.
- **Three critical invariants hold** — `id-gate-before-path` (census uniform at
  one guard per site), `untrusted-body-never-shell`, `placement-gate-before-git`
  — and the placement door's negative-offset markers are provably undisturbed
  by the two new forwarded flags.
- **The contract edges hold.** 4 checked, 0 violations; growing the verb enum
  removes nothing from either outside consumer.
- **Three investigator claims were rejected on verification** and should stay
  rejected: the raw-id echo in `transition.sh` predates this increment
  (`fa77304`); the `leave`-availability comment is scoped to containment
  violations, where the target resolves; and `status` reaching the section is
  sanitized once before both bucketing and display.

---

## 5. Explicitly **not** in this pass

Follow-on work the review surfaced. Filing it is a separate decision — the
end-of-review candidate batch was not run, so **none of this is tracked yet**.

- **`issue-file-never-sourced` is violated in `backfill.sh` and `migrate.sh`**
  (critical, pre-existing — neither file is in this build's change set). Their
  `field_value`/`num_of` grep the whole file rather than the frontmatter fence.
  Reproduced: a record whose frontmatter lacks `num:` and whose body carries
  `num: 5` answers **5**. In `backfill.sh`'s own operating condition — records
  that lack the field — that silently skips a record forever. This is the most
  serious thing the review found that this pass is not fixing.
- **`declared-vocabularies` and `cross-copy-lockstep` are violated
  in-change.** Both route to the held blueprint fork rather than here. The
  second is sharp: `resolve.sh` and `transition.sh`'s retained `resolve_slug()`
  have **already diverged** — `resolve.sh` distinguishes no-match from
  multiple-match on stderr, `resolve_slug` collapses both — while
  `resolve.sh`'s header claims to be "the single definition". Either
  `transition.sh`'s primary id delegates too, or the header stops claiming it.
- `docs/features/issues.md` still says "Five verbs move it."
- `resolve.sh`'s exact-match branch lacks the `INDEX.md` exclusion its prefix
  branch applies; `resolve.sh <dir> INDEX` resolves at rc 0.
- The group blueprint's § Structure says "nine scripts" and omits `resolve.sh`.
- **Two cases that cannot go red**: the stats ordering case's fixture strips
  `type`, so the row never satisfies the guard's condition and both placements
  pass; the cap case's all-open fixture makes the correct overflow formula and
  a wrong one coincide.
- **Coverage gaps**: `join`/`leave` never driven through `place.sh`'s engine or
  under a branch placement; the capture refusals pinned only on the direct
  invocation shape; no adversarial-charset case for `--type`/`--part-of`; the
  container exclusion pinned for the priority cluster only, not origin or
  label; multi-umbrella independent progress never verified end-to-end; an
  author-set status contradicted by its members has no negative test.
