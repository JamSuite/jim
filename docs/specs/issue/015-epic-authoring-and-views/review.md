---
spec: "issue/015"
type: "feature"
base_sha: "c910f141bab73c639fe578846c91e18344e4a0ab"
head_sha: "7c746d6d081fb22fa623d94374089e51c3ccdefc"
commits: "14"
commits_test: "0"
commits_feat: "7"
commits_fix: "1"
commits_refactor: "1"
files_changed: "18"
insertions: "2050"
deletions: "117"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "11256"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "1122"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "5950"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "31024"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "7417"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "786"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "3"
security_regressions: "0"
invariant_violations: "3"
contract_violations: "0"
alignment: "major-drift"
date: "2026-08-28"
---

# Review — Epic authoring and views

## Summary

**`major-drift`.** The build executed all 29 plan tasks faithfully and the
suite is green at 1,669 cases. Every load-bearing mechanism this increment
introduced was attacked directly and held: the roster derivation terminates by
the shape of its pass rather than a cycle guard, the `(member, umbrella)` dedup
is honoured on both derivation sides, the new index section cannot forge a line
or a nesting level, the write-only-on-change filter is correct for both field
classes, and the capture-time refusals genuinely cost no ordinal.

The drift is not in those mechanisms. It is that **the increment's headline
capability is unreachable from the command it was specified against.**
`/jim:issue add` parses no flags — it takes everything after `add` as the
capture subject — and the emitter invocation it runs passes neither `--type`
nor `--part-of`. So the spec's own UI mockup, `/jim:issue add "Auth hardening"
--type epic`, files an issue *titled* `Auth hardening --type epic`.
`skills/issue/SKILL.md:156` still instructs the filing agent that "an umbrella
is made by changing this field on an existing record, not by filing a different
kind of one" — the exact friction the spec's Problem Statement says this
increment exists to remove. Three investigators reached this independently.

Four further acceptance criteria are incompletely satisfied in corners, and
five surfaces still state superseded behaviour — including `/jim:issue help`
itself, whose regression test hand-lists the five old verbs and therefore
passes green.

The root of the largest finding is upstream of the build: `plan.md`'s
Requirements Coverage maps the two capture-flow criteria to tasks 5 and 6,
which are *script* tasks, and its File Manifest scopes the `SKILL.md` edit to
the `join`/`leave` dispatch entries alone. The build did what the plan said.

## Alignment vs spec

38 acceptance criteria. **33 satisfied · 5 not fully satisfied.**

| Criterion | Verdict |
| :--- | :--- |
| Create an umbrella kind without a separate capture flow | **not satisfied** — script-level only; `/jim:issue add` cannot reach it |
| Name an umbrella at capture time, one command not two | **not satisfied** — same; `--part-of` is unreachable through the command |
| An umbrella under an umbrella is refused | **partial** — refused by `join`, permitted by the capture path |
| The read views list the umbrellas, each with progress | **partial** — the census rollup drops zero-member umbrellas |
| A refusal is distinguishable from a query that matched nothing | **partial** — an empty collection answers instead of refusing |

Everything else held under investigation, including the whole "A change that
changes nothing" group (all four criteria, pinned by a vocabulary-driven case
that reads the verb list from the script), the containment reporting at the
index, the identity-spend guarantee, the index section's structure and bound,
and the census regression (verified byte-identical against the real
409-record collection, not only a fixture).

## Alignment vs plan

All 29 tasks are marked and were done. **Three deviations**, each a deliberate
build-time judgment, all disclosed rather than silent:

1. **A new script the plan did not name.** `resolve.sh` was added as the shared
   reference ladder, on the developer's explicit sign-off, after the build found
   the plan had not settled where that ladder lives. The plan's File Manifest
   lists no new file.
2. **The no-op filter is simpler than specified.** The plan called for two
   readers (`fm_field` for scalars, `relation_targets` for relations). Comparing
   the composed `field: value` line needs neither and covers both field classes
   uniformly; `relation_targets` is still used inside `apply_verb` for the set
   logic, which is where the relation-reader requirement actually bites.
3. **Containment is enforced on `join` only.** The plan did not say. Refusing on
   `leave` would make a hand-edited violation permanent through the one verb
   that undoes it.

No scope creep. Every explicitly deferred item was confirmed undone: membership
cardinality is still unbounded, `ROSTER_CAP` is a plain constant, `part-of`
edges still render in `## Graph`, the `updated` field still has no reader, and
no read view groups by umbrella.

## Alignment vs architecture

`ARCHITECTURE.md` was refreshed during the completion gate and describes the
increment accurately. Two in-file comments now contradict the code they sit
beside — `render.sh`'s comment above `AXIS_FIELDS` still says `epic` carries
`-` "to say so" three lines above `epic:type`, and `index.sh`'s header still
says the file writes "four sections" while it emits five.

## Living intent

Sensor ran against `docs/specs/issue/000-blueprint` — whole-group floor,
change-selected judges. **15 invariants: 8 holds · 3 violated · 4 skipped
(scope).** No registry entries are configured; all 15 invariants are
judge-method, so there is no pattern/structure rung. Judge fan-out: 10
change-selected, dispatched as 9 agents covering 11 invariants (two agents
carried two each). `undelegated=0`.

**Violated**

- `declared-vocabularies` (high, **in-change**) — `ISSUE_TYPES` is now declared
  three times under two names (`new.sh`, `index.sh`, and `render.sh`'s
  `TYPE_TOKENS`); this build added the third. Beyond that: `ISSUE_OUTCOMES` is
  declared twice, `PRIORITY_TOKENS` has a hand-typed twin in `new.sh`'s `case`,
  `cmd_help`'s heredoc restates six declared vocabularies with no test tying
  them back, and `TRANSITION_VERBS ⊆ PLACE_VERBS` is a required-but-unchecked
  containment. Widens the existing record on this invariant.
- `cross-copy-lockstep` (high, **in-change**) — `resolve.sh` and
  `transition.sh`'s retained `resolve_slug()` implement the same write-path
  ladder with no marker on either side and no fixture comparing them, while
  `resolve.sh`'s own header claims to be "the single definition … so a capture
  and a lifecycle verb cannot disagree". The copies have **already diverged**:
  `resolve.sh` distinguishes no-match from multiple-match on stderr;
  `resolve_slug` collapses both.
- `issue-file-never-sourced` (critical, **pre-existing**) — nothing sources or
  evaluates an issue file anywhere, and both new read paths are correctly
  fence-scoped. But `backfill.sh`'s `field_value`/`num_of` and `migrate.sh`'s
  `field_value` grep the whole file rather than the frontmatter fence.
  Reproduced: a record whose frontmatter lacks `num:` and whose body carries
  `num: 5` answers **5**. In `backfill.sh`'s own operating condition — records
  that lack the field — that silently skips a record forever. Classified
  pre-existing on a trusted input: neither file is in this build's change set.

**Skipped (reason: scope)** — `materialization-contained`,
`insights-capability-boundary`, `identity-validated-before-record`,
`collection-rewrite-preview-gated`. None is touched by this change.

**Territory** — 0 strays · 953 files bucketed as scaffolding or other groups'
territory (docs 846 · skills 66 · root 15 · tests 14 · agents 11 · scripts 1).
`resolve.sh` landed inside the declared territory.

### Contracts

Contract-edge phase ran — the graph names `issue` as a provider and the change
touched provides-side code. **4 edges checked · 4 hold · 0 violations.** The
emitter's new flags are additive, and growing `PLACE_VERBS` removes nothing:
the spec group's reconcile drives `mode`/`begin`/`commit --verb edit`/`abort`,
and the partition surface holds a read-only trio with no publish verb.

## Metrics

| | |
| :--- | :--- |
| commits | 14 (7 feat · 1 fix · 1 refactor · 5 docs/chore) |
| diffstat | 18 files · +2050 / −117 |
| suite | 1,669 cases green |
| build duration | 7,417 s |
| sec stage | 2 runs · 31,024 s |

## Security regressions

**None.** Three critical invariants governing this increment's new surfaces —
`id-gate-before-path`, `untrusted-body-never-shell`, `placement-gate-before-git`
— were each judged and hold. The id-gate census came out uniform at exactly one
guard per path-composing site, including both new resolvers. The placement
door's negative-offset markers are provably undisturbed by the two new
forwarded flags. `--type` clears an exact two-member enum before being written
bare; `--part-of` writes only a slug that cleared the id allowlist twice.

The one security-adjacent finding is the pre-existing fence-scoping gap above,
which is a correctness defect in two opt-in migrations rather than a regression
this build introduced.

## Findings

1. **The capture flow was never wired.** `/jim:issue add` cannot pass `--type`
   or `--part-of`; `SKILL.md:156` states the superseded rule. Two ACs unmet.
2. **The two write paths disagree about nesting.** `new.sh --type epic
   --part-of <epic>` succeeds; `join` refuses the identical state.
3. **The census rollup drops a zero-member umbrella.** It enumerates edge
   targets rather than epic rows. The index, `list` and `show` are all correct.
4. **`--epic <bogus>` on an empty collection answers instead of refusing.**
   Narrow; the staleness judge argues the empty answer is truthful for a
   zero-row collection, which is why this is recorded as advisory rather than a
   clean violation.
5. **`/jim:issue help` omits `join`/`leave`**, and its test hand-lists the five
   old verbs, so it passes green — a repeat of a defect class this project has
   already filed once.
6. **`docs/features/issues.md` still says "Five verbs move it."** Not in the
   change set; not reached by the doc-surface check this build added.
7. **`row_status` is dead code** in `cmd_stats` — declared, seeded, written,
   never read. Introduced by this build and orphaned by its own refactor.
8. **`resolve.sh`'s header overclaims** a single definition that
   `transition.sh`'s primary id does not use.
9. **`resolve.sh`'s exact-match branch lacks the `INDEX.md` exclusion** its
   prefix branch applies; `resolve.sh <dir> INDEX` resolves at rc 0. Not
   currently exploitable — downstream guards refuse — but a real inconsistency
   in the shared resolver.
10. **Two comments contradict adjacent code** — `render.sh`'s `AXIS_FIELDS`
    note and `index.sh`'s "four sections" header.
11. **The group blueprint's § Structure says "nine scripts"** and omits
    `resolve.sh`. Owned by `/jim:blueprint`.
12. **Two cases cannot go red.** The stats ordering case's fixture strips
    `type`, so the row never satisfies the guard's condition and both guard
    placements pass it; the cap case's all-open fixture makes the correct
    overflow formula and a wrong one coincide.
13. **Coverage gaps on new surfaces** — `join`/`leave` are never driven through
    `place.sh`'s actual engine or under a branch placement; the capture
    refusals are pinned only on the direct invocation shape; no adversarial
    charset case exists for `--type`/`--part-of`; the container exclusion is
    pinned for the priority cluster only, not origin or label; multi-umbrella
    independent progress is never verified end-to-end; an author-set status
    contradicted by its members has no negative test.

## Coverage

**Depth: `thorough`.** 13 investigators dispatched against the high-stakes set
(cap 20, model sonnet) — six against changed regions, three against read-view
behaviour, three AC sweeps covering all 38 criteria, one omission/scope-creep
pass. Stated 13, ran 13; `undelegated=0`, nothing rests on spine-level reading.

Every finding above was reproduced by execution before being recorded, and two
were reproduced with a negative control. Three investigator claims were
**rejected** on verification: that the raw-id echo in `transition.sh` is this
build's (it predates it), that the `leave`-availability comment is false (it is
scoped to containment violations, where the target resolves), and — from the
containment investigator — that `status` reaching the section unsanitized
matters for row-shape, which the judge settled by showing status is sanitized
once before both bucketing and display.

**Convergence.** The capture-flow gap was reached independently by three
investigators; the zero-member rollup by two. Both are recorded as confirmed
rather than plausible.
