---
spec: "issue/015"
type: "feature"
base_sha: "c910f141bab73c639fe578846c91e18344e4a0ab"
head_sha: "40c1110f8a2bf86c99d5e28cbb5cc2dfb8089c04"
commits: "24"
commits_test: "0"
commits_feat: "7"
commits_fix: "6"
commits_refactor: "2"
files_changed: "22"
insertions: "3087"
deletions: "510"
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
build_runs: "2"
build_interruptions: "0"
build_duration_seconds: "15212"
review_runs: "2"
review_interruptions: "0"
review_duration_seconds: "7437"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "4"
security_regressions: "0"
invariant_violations: "4"
contract_violations: "0"
alignment: "minor-drift"
date: "2026-08-28"
---

# Review — Epic authoring and views (post-remediation)

## Summary

**`minor-drift`.** This is the second review of this increment. The first
returned `major-drift` over `c910f14..7c746d6`: five acceptance criteria were
unmet, headed by the increment's own headline capability being unreachable from
the command it was specified against. A remediation pass then landed six
commits against a scoped fix list. This review covers the widened range
`c910f14..40c1110f` — the build **and** the remediation, 24 commits.

**All five previously-unmet criteria are now satisfied; 38 of 38 hold.** Each
was re-investigated by a dedicated investigator against the current tree, and
each fix was proven red-first and mutation-tested during the pass. The suite is
green at 1,673 cases.

The verdict is `minor-drift` rather than `aligned` because the increment leaves
two defects on its own primary surface. `skills/issue/SKILL.md:382` still tells
the filing agent that a new capture's `type` is `issue` — the exact rule this
increment reverses, surviving at a site nobody enumerated — and the new
flag-extraction instruction is silent on malformed input in a way that
reproduces the original title-pollution defect from a different direction. Both
are in the document that stands between the user's typed command and the
scripts.

**A range note.** The remediation ran without opening its own build stage, so
the ledger's validated range ended at the build's close and would have excluded
every fix. The range was extended by recording a second `build started` /
`build finished` pair before this review's Step 2. That makes the code range
honest but distorts two duration metrics: `build_duration_seconds` and
`review_duration_seconds` are both measured first-started to last-finished, so
each now spans the pause between the two runs rather than hands-on time. Read
the run counts, not the durations.

## Alignment

### vs. Spec acceptance criteria

38 criteria. **38 satisfied · 0 not satisfied.**

The five the previous review recorded as unmet, re-judged against the current
tree:

| Criterion | Previous | Now |
| :--- | :--- | :--- |
| Create an umbrella kind without a separate capture flow | not satisfied | **satisfied** |
| Name an umbrella at capture time, one command not two | not satisfied | **satisfied** |
| An umbrella under an umbrella is refused | partial | **satisfied** |
| The read views list the umbrellas, each with progress | partial | **satisfied** |
| A refusal is distinguishable from a query that matched nothing | partial | **satisfied** |

The remaining 33 were confirmed by the previous review over code the
remediation does not touch; a regression sweep re-checked the seven most
exposed to the changed regions and found none broken or weakened.

### vs. Plan tasks

All 29 plan tasks remain `[x]` and were done. **Four deviations**, all
disclosed:

1. **A new script the plan did not name.** `resolve.sh`, added on the
   developer's explicit sign-off. (Carried from the first review.)
2. **The no-op filter is simpler than specified.** Comparing the composed
   `field: value` line needs neither of the two readers the plan called for.
   (Carried.)
3. **Containment is enforced on `join` only** in `transition.sh`; the plan did
   not say. (Carried — and the remediation added the matching check on the
   capture path, which is what closed the AC.)
4. **The remediation pass is outside the task breakdown.** Six commits of
   work no plan task describes, scoped instead by `remediation.md` and
   authorized directly. The plan was deliberately left at `approved` rather
   than being amended, so the task list no longer describes everything the
   range contains.

No scope creep. Every explicitly deferred item is still undone: membership
cardinality is unbounded, `ROSTER_CAP` is a plain constant, `part-of` edges
still render in `## Graph`, `updated` still has no reader, and no read view
groups by umbrella.

### vs. ARCHITECTURE.md

One active misdescription, introduced by this range. `ARCHITECTURE.md:1937`
says "Nine deterministic scripts own the issue-tracking surface" while the
tree at `:81-90` in the same document correctly lists **ten**, including
`resolve.sh` annotated `(issue/015)`. `/jim:arch` ran at the build's completion
gate and updated the tree without updating the prose count. The narrative never
describes `resolve.sh`'s role.

## Investigation

### High-stakes regions investigated

#### AC — umbrella kind reachable from the capture flow
- locations examined: `skills/issue/SKILL.md` (whole), `skills/issue/scripts/new.sh` (whole), `spec.md`
- verdict: **satisfied** — the spec's own mockup `add "Auth hardening" --type epic` was traced end to end through dispatch → draft → emitter → file and files an epic titled `Auth hardening`. One residual: the Validation Checklist contradiction at `SKILL.md:382` (Finding 1).

#### AC — name an umbrella at capture time
- locations examined: `SKILL.md:33-37,164,216-224`, `new.sh:254-307`, `resolve.sh`, `transition.sh:361-367`
- verdict: **satisfied** — one command; `--part-of` resolves through the same `resolve.sh` ladder `join` uses, so a reference that works on one path works on the other. Multi-value CSV confirmed against the script.

#### AC — an umbrella under an umbrella is refused
- locations examined: `new.sh:254-307`, `transition.sh:378-399`, `index.sh:781-792`, `place.sh:1835,1875`
- callers/consumers traced: every route to the forbidden state — `new.sh` direct, `new.sh` under a branch placement (the `place.sh` re-exec re-enters the same validation because `--dir` is then non-empty), `join`, `leave`, hand edit
- tests checked: `tests/issues.sh:6088`, `:6116`, `:4530`, `:5680`, `:5850`
- verdict: **satisfied** — refused on both write paths with a byte-identical message, above the allocator on both. A hand edit remains detected by the index, which is what the spec's Open Question required.

#### AC — read views list umbrellas with progress / empty roster
- locations examined: `render.sh:622-810,960-1013,814-861,1523-1622`, `index.sh:745-829`
- tests checked: `tests/issues.sh:9988`, `:9950`, `:10047`, `:10064`, `:5714`
- verdict: **satisfied** — all four surfaces (index `## Epics`, `list epic`, `show`, `stats` rollup) now agree on which records are umbrellas and on each one's progress, including a memberless umbrella. Surfaced a separate inconsistency in the same output block (Finding 3).

#### AC — refusal distinguishable from an empty match
- locations examined: `render.sh:1101-1133,504-554,1015-1057`, `index.sh:865-946`
- tests checked: `tests/issues.sh:10109` (with its stale-index control), `:10082`
- verdict: **satisfied** — the new `any_row && ! any_type` condition is correct in both directions; the exit status of `build_derived_axes` was traced on every branch and no legitimate query is newly refused.

#### Region — `cmd_stats` after the dead-code removal
- locations examined: `render.sh:622-810`, `:1202-1215`
- verdict: **satisfied** — `row_status` had no reader, established with a positive control: `row_matches` genuinely does read `cmd_stats`' locals by dynamic scope, and `row_status` was not among them. The filter-independence property the deleted comment claimed is provided by `build_epic_progress`' own unfiltered re-read and is stated at `render.sh:760-765`.

#### Region — the shared roster derivation
- locations examined: `render.sh:960-1013`, all three call sites
- verdict: **satisfied** — `EPIC_ROWS` is reset with the maps; the kind test matches `index.sh:813`'s; slugs are `printf` data, never a format string or path; `sort` is locale-pinned by the file's `LC_ALL=C`.

#### Region — the SKILL.md capture flow
- locations examined: `SKILL.md` (whole), `new.sh`, `resolve.sh`
- verdict: **partial** — every factual claim the new text makes about the emitter is true, and § 7a correctly omits both flags. But the instruction is silent on three malformed inputs (Finding 2) and the checklist contradiction survives (Finding 1).

#### Omission sweep across operator surfaces
- locations examined: `README.md`, `WORKFLOW.md`, `docs/features/*.md`, every `skills/*/SKILL.md`, `skills/*/references/*.md`, `ARCHITECTURE.md`, `skills/issue/assets/issue-template.md`, `docs/specs/issue/000-blueprint/spec.md`
- verdict: **divergence** — `docs/features/issues.md` is stale in four places (Finding 7) and `ARCHITECTURE.md:1937` misstates the script count (Finding 5). `README.md`, `WORKFLOW.md`, `SKILL.md`, the template and every other skill were checked and found clean.

#### Test-vacuity sweep
- locations examined: the six added/changed cases plus `skills/meta-test/scripts/testlib.sh`
- verdict: **satisfied** — no case is vacuous; each was traced to the assertion that flips when its fix is reverted. Two decorations recorded (Findings 8 and 10's neighbour).

#### Security of the remediation delta
- locations examined: `new.sh`, `render.sh`, `index.sh`, `place.sh`, `SKILL.md`, both test files, `000-blueprint/spec.md`
- verdict: **satisfied** — no regression; see § Security regressions.

#### Regression sweep on previously-satisfied criteria
- verdict: **satisfied** — none broken or weakened. The zero-umbrella census was additionally verified empirically, not only by trace (below).

### Coverage

- Depth: `thorough`; `review_model: sonnet`.
- Full high-stakes set investigated. **12 investigators stated, 12 dispatched**; `undelegated=0`. Nothing rests on spine-level reading.
- The 33 criteria the first review confirmed over code this range does not touch were not re-investigated individually; the regression sweep covered the seven the changed regions could plausibly disturb.
- **Every finding below was reproduced by execution before being recorded.** Three carry a negative control, and one (Finding 4) required a purpose-built fault-injection rig.
- **Census oracle re-verified.** `render.sh stats` over a copy of the real 409-record collection is byte-identical to the stored pre-increment oracle for the fourth time. The first attempt differed by exactly one record — an issue filed by the previous review *after* the oracle was taken — and removing it restored identity by `md5sum`. Taken against a copy, because a read regenerates `INDEX.md`.

## Living intent

Sensor ran against `docs/specs/issue/000-blueprint` — whole-group floor,
change-selected judges. **15 invariants: 10 holds · 4 violated · 1 skipped
(scope).** No registry entries are configured; all 15 are judge-method, so
there is no pattern/structure rung. `undelegated=0`.

Judge selection was decided fresh rather than copied from the previous run,
which raised coverage from 11 invariants to 14: `materialization-contained`,
`insights-capability-boundary` and `identity-validated-before-record` were
skipped for scope last time, but `place.sh`, `SKILL.md` and `new.sh`
respectively put each inside this change set. All three were judged and all
three hold. Only `collection-rewrite-preview-gated` remains scope-skipped —
its code lives in `migrate.sh` / `backfill.sh`, neither in the change set.

**Sensed:** 15 · **holds:** 10 · **violations:** 4 (in-change 3 · pre-existing 1 · unlocalized 0) · **skipped:** 1 · **failed/unconfigured:** 0

### Violations

- **`issue-file-never-sourced`** — critical · violated · **pre-existing** ·
  `skills/issue/scripts/backfill.sh:69`. Nothing sources or evaluates an issue
  file anywhere, and every read path added by this increment is fence-scoped.
  But `backfill.sh`'s `field_value`/`num_of` and `migrate.sh`'s `build_plan`
  `field_value` grep the whole file rather than the frontmatter fence.
  Reproduced: a record whose frontmatter lacks `num:` and whose body carries
  `num: 5` answers **5**. Sharper than previously recorded — `migrate.sh`
  contains *both* readers, the unscoped one at `:111` and a correctly
  fence-scoped `frontmatter`/`fm_field` pair at `:442`, so the file
  demonstrably knows the hazard and its `prefix` path uses the wrong helper.
  Under `--apply` that path reaches a file rename. Classified pre-existing on
  the trusted changed-file list: neither file is in this range.
- **`declared-vocabularies`** — high · violated · **in-change** ·
  `skills/issue/scripts/render.sh:76`. The record kind is declared three times
  under two names; `ISSUE_OUTCOMES` twice plus prose, its test hand-typing two
  of four members; `PRIORITY_TOKENS` has a retyped twin in `new.sh`'s `case`;
  `STATUS_TOKENS` is silently narrowed there to `open|closed` with no comment
  saying whether that is intent; `TRANSITION_VERBS ⊆ PLACE_VERBS` is required
  and unchecked. This increment's help-text fix tied one of the six restated
  vocabularies back to its declaration; five remain untied.
- **`cross-copy-lockstep`** — high · violated (judge `partial`) ·
  **in-change** · `skills/issue/scripts/transition.sh:125`. `resolve.sh`'s
  header claims to be "the single definition of what an ordinal, an exact slug
  or a slug prefix resolves to on a write path", while `transition.sh` keeps
  its own `resolve_slug()` for the primary id. Neither copy carries a sync
  marker and no fixture compares them — the only unmarked, untested duplicate
  in a territory where five other copy-pairs are all marked and
  test-enforced, two of them declaring a deliberate asymmetry in their own
  marker. The ladders already differ internally on multi-match; that
  divergence is currently *masked* because both callers discard `resolve.sh`'s
  stderr and substitute their own message, so today's observable behaviour
  coincides by accident rather than by construction.
- **`atomic-index-write`** — medium · violated (judge `partial`) ·
  **in-change** · `skills/issue/scripts/transition.sh:449`. New this review.
  `set_fields` writes the transition durably into the materialized collection;
  if the subsequent index regeneration then fails, `transition.sh:451` calls
  `place.sh abort`, whose body is `rm -rf -- "$handle"` — destroying a
  completed, unpublished write that is its only copy. Reproduced end to end
  under a branch placement with an injected transient index failure: the
  collection carried `claimed-by` at the moment of the failing call, the
  destination branch was left unchanged, and the write survived nowhere. The
  line predates this range (`fa77304`), and the blast radius is branch
  placements only — under the default placement `abort` on a direct handle is
  a no-op and the write stays in the working tree. Every sibling migration in
  the group does the opposite on the same "write succeeded, reindex failed"
  shape: keep the state, flag the stale index.

### Coverage

- appetite in force: `low` (no per-group override) — every invariant is above threshold.
- Whole-group floor ran; territory is declared, so no `UNSCOPED` degradation.
- judges: change-selected, 14 dispatched, all within the cap of 20. None un-judged.
- skipped by scope: 1 · skipped by appetite: 0.
- registry: 0 configured — no registry rung exists for this group.
- **Territory** — 0 strays · 955 files bucketed as scaffolding or other groups' territory (docs 848 · skills 66 · root 15 · tests 14 · agents 11 · scripts 1). `resolve.sh` sits inside the declared territory.

### Contracts

Contract-edge phase ran — the graph names `issue` as a provider and the change
touched provides-side code (`new.sh`, `place.sh`, `SKILL.md`).

**Edges checked:** 4 · **holds:** 4 · **violations:** 0 (provider-side 0 · consumer-side 0)

- None — every checked edge holds. The floor reports `COVERAGE 4 4` with no
  leak or breaking record. The change is additive on every provides face: two
  new optional emitter flags withdraw nothing, and growing `PLACE_VERBS`
  removes no verb a consumer depends on.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 24 (0/7/6/2) |
| Files changed · insertions · deletions | 22 · +3087 · −510 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·2·2 |
| Stage durations (spec·research·plan·sec·build·review) | 11256s·1122s·5950s·31024s·15212s·7437s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

The `build` and `review` durations span both runs of each stage, including the
pause between them — see the range note in the Summary. Suite: 1,673 cases green.

## Security regressions

**None.** The four critical invariants governing this increment's surfaces were
each judged and all hold. Specifics worth recording:

- The placement door's negative-offset markers are undisturbed by the two new
  forwarded flags, and the argument is structural: `--dir '{}' --place-token
  '{token}'` are appended *after* the forwarded argv, so `-3` and `-1` are
  fixed regardless of its length, and `place_marker_at` independently verifies
  the literal marker at the computed offset before substituting.
- `--type` clears a two-member enum before its bare write; `--part-of` writes
  only an id that cleared `valid-id` twice through `resolve.sh`.
- The `id-gate-before-path` census came out uniform at one guard per
  path-composing site across sixteen sites in ten scripts.
- `place.sh` runs the wrapped command as an array expansion, never through
  `bash -c "<string>"`, so argv forwarding adds no shell surface.

The security-adjacent items are the pre-existing fence-scoping gap recorded
under Living intent and the message-sanitization inconsistency at Finding 6.

## Findings

### 1. The Validation Checklist still states the superseded rule

- **Priority:** high
- **Description:** `skills/issue/SKILL.md:382` reads "`type` is `issue`, and `claimed-by` and `outcome` are both empty" as a pre-write gate for every capture. That is the exact claim this increment reverses, and it contradicts `SKILL.md:34` and `:160` in the same file. An agent running the checklist literally on an epic capture meets a rule its own correct draft fails. Three investigators reached this independently. The line predates the range (`b2b68b7`) — this increment is what made it false. The remediation's fix list enumerated four sites from the first review's finding text; the file had five.
- **Suggestion:** Amend to `type` is `issue`, or `epic` when `--type epic` was given.
- **Relates to:** AC — create an umbrella without a separate capture flow

### 2. The flag-extraction instruction is silent on malformed input

- **Priority:** high
- **Description:** `SKILL.md:33-37` says to take each flag "and its value" out of the argument string, which grammatically assumes one well-formed occurrence of each. Three inputs are undetermined: a repeated flag (`add x --type epic --type issue` — extracting only the first leaves `--type issue` in the string, which by the bullet's own rule is filed as part of the title, reproducing the original defect); a trailing flag with no value (`add see PR --part-of`); and a token after `--type` that is not a kind. The first is the serious one: it is the same title-pollution failure arriving through a different door.
- **Suggestion:** State the tie-break for a repeat, what a valueless trailing flag does, and whether to pre-validate the kind before extraction or forward it and let the emitter refuse.
- **Relates to:** AC — create an umbrella without a separate capture flow

### 3. The census container headline and its rollup describe different populations

- **Priority:** medium
- **Description:** `cmd_stats`' `Epics: N open · M closed` line is accumulated after the row filter, while the `== Epics ==` rollup reads the unfiltered shared derivation. Under a filter an umbrella's own row fails, the headline vanishes while the rollup still names that umbrella. Reproduced with a negative control (unfiltered: headline present; `--priority low` against a `high` umbrella: headline absent, rollup unchanged), and reproduced identically against pre-remediation `render.sh` — so this is the build's, not the remediation's. The fix does widen the population that can hit it: before, only umbrellas with members appeared.
- **Suggestion:** Decide which population the block describes and make both halves use it. The code comment already claims progress is a property of the umbrella, not the query; the headline does not follow that.
- **Relates to:** AC — the view reports containers separately

### 4. A failed reindex destroys a completed transition under a branch placement

- **Priority:** high
- **Description:** See the `atomic-index-write` entry under Living intent. Reproduced end to end. Data loss, narrow reachability (branch placement plus a transient index failure), pre-existing line.
- **Suggestion:** On the post-write reindex failure, preserve the handle and report it rather than aborting — the shape every sibling migration in the group already uses.
- **Relates to:** invariant `atomic-index-write`

### 5. `ARCHITECTURE.md` miscounts the group's scripts

- **Priority:** low
- **Description:** `ARCHITECTURE.md:1937` says "Nine deterministic scripts" while the tree at `:81-90` lists ten including `resolve.sh`; the prose never describes `resolve.sh`'s role. The refresh updated the tree and not the count.
- **Suggestion:** Correct via `/jim:arch` — the document is machine-refreshed and must not be hand-edited.
- **Relates to:** ARCHITECTURE.md alignment

### 6. The `--epic` refusal echoes its operand unsanitized

- **Priority:** low
- **Description:** `render.sh:1127` emits `no epic matches '$alt'` with the raw operand. Every sibling refusal in the file routes its echoed token through `token_safe` — `:214`, `:322`, `:336`, `:342`, `:360`, `:365`, `:394` — and that helper's own comment argues an argv token deserves the same terminal-injection discipline as a file-derived one. This is the sole outlier.
- **Suggestion:** Wrap the operand in `token_safe`.
- **Relates to:** AC — the refusal names the reference

### 7. `docs/features/issues.md` is stale in four places

- **Priority:** medium
- **Description:** The feature doc has zero occurrences of `epic`, `join`, `leave`, `--type`, `--part-of` or `--epic`. Its Usage block omits the two verbs and both capture flags (`:33-46`); `:101` states "Five verbs move it, and they are the supported path"; the Read views section (`:199-207`) describes the filter vocabulary and the stats output without `--epic`, the `Epics:` headline or the rollup; and `:211-218` says the index has "Four sections" while `index.sh` writes five. The first review recorded this as one place; it is four.
- **Suggestion:** Bring the doc up to the shipped surface, and consider whether the doc-surface sweep should quantify over it the way it does over README and WORKFLOW.
- **Relates to:** omission class

### 8. A new doc-surface assertion is tautological

- **Priority:** low
- **Description:** `tests/docsurfaces.sh`'s `skill_emitter_invocation` locates the emitter block by searching for the literal `new.sh --reviewed`. The forward check that `--reviewed` reaches the invocation therefore cannot fail — the string that finds the block is the string sought in it. Low stakes: one of ten required flags, and the reverse-direction check catches a dropped `--reviewed` independently. But it is a self-matching probe, the same class as a fixture directory named after the word its probe searches for.
- **Suggestion:** Anchor on the script path alone and let `--reviewed` be checked like every other flag.
- **Relates to:** test integrity

### 9. Nothing pins the refusal-message parity the two write paths rely on

- **Priority:** low
- **Description:** `new.sh:301` and `transition.sh:396` emit a byte-identical refusal deliberately, so the two write paths refuse the same state for the same stated reason — and `new.sh`'s comment says so. No test asserts the parity; both sides assert non-emptiness or a substring, so wording drift on one side passes green.
- **Suggestion:** A fixture comparing the two strings, or a shared constant.
- **Relates to:** AC — an umbrella under an umbrella is refused

### 10. Coverage asymmetry on the empty-collection refusal

- **Priority:** low
- **Description:** The new empty-collection refusal is exercised for `list --epic` only. `cmd_stats` shares the code path through `build_derived_axes`, and the path was traced correct, but no case drives `stats --epic <bogus>` on an empty collection. The previous review's finding 13 named the same class for `join`/`leave` under a placement, which also remains open.
- **Suggestion:** Extend the case to drive both verbs, as `case_issues_render_unanswerable_axes_refuse_on_both_verbs` already does for the schema gate.
- **Relates to:** AC — a refusal is distinguishable from an empty match

### 11. Inconsistent quoting in the documented emitter invocation

- **Priority:** low
- **Description:** `SKILL.md:219` shows `--type <issue|epic>` unquoted while its sibling `--part-of "<csv-umbrella-refs>"` and every other scalar flag are quoted. No practical consequence — `--type`'s value is a two-word vocabulary — but the asymmetry is arbitrary and the surrounding template is what an agent copies.
- **Suggestion:** Quote it for consistency.
- **Relates to:** SKILL.md capture flow

## Deviations & feedback

- **A fix list derived from a findings report inherits that report's
  enumeration.** The remediation's § 2.1 named four sites for the superseded
  `type` rule because the first review's finding named four. The file had five,
  and the fifth is Finding 1 here. The lesson is the project's own: name the
  set mechanically before writing the enumeration. The sweep the remediation
  added quantifies over the emitter's parser but not over the surfaces that
  restate its semantics in prose.
- **The second review found what the first did not, in both directions.** This
  run raised judge coverage from 11 invariants to 14 by re-deriving change
  selection instead of copying it, and all three newly-judged invariants hold —
  turning unexamined `skipped` into checked `holds`. It also found one new
  violation (Finding 4, a data-loss path) that the first review's judge rung
  recorded as holding. A second pass over the same blueprint is not redundant.
- **The suite caught the fix pass's only defect, and no per-script run could
  have.** All six remediation items passed their own suites individually; the
  full run failed on a locale-pinning hygiene invariant in a file none of them
  was about. That is the omission class `tests/docsurfaces.sh`'s own header
  describes, arriving in the test tree rather than the doc tree.
- **A mutation that silently fails to apply reports a false pass.** During the
  pass a `sed` substitution containing `||` clashed with its own `s|…|`
  delimiter; the mutation never applied and the case "passed" for the wrong
  reason. It was caught only because the mutation step echoed the grep that
  proves the mutant is in place. A mutation must prove it applied before its
  result means anything — worth adding to `docs/notes/process-improvements.md`.
- **Stage instrumentation does not survive a pass that reopens a closed
  stage.** The remediation ran with no build stage open, so the range would
  have excluded every fix and this review would have re-reported all thirteen
  original findings as unfixed. Reopening the stage fixed the range and
  distorted two durations. A fix pass is a build run; opening the stage costs
  one command.
