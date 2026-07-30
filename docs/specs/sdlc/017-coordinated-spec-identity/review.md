---
spec: "sdlc/017"
type: "feature"
base_sha: "f930730067bc42563a90a36e822235b5d0e036fa"
head_sha: "781d0b1251e93271ff7e36ff8f997eb514088646"
commits: "25"
commits_test: "11"
commits_feat: "11"
commits_fix: "1"
commits_refactor: "0"
files_changed: "10"
insertions: "2194"
deletions: "33"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "4441"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "1123"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1742"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "3153"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "6699"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "167"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "3"
security_regressions: "0"
invariant_violations: ""
contract_violations: ""
alignment: "minor-drift"
date: "2026-07-30"
---

# Review: Coordinated spec identity

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 5 · **Plan deviations:** 3 · **Security regressions:** 0

Reviewed the full `sdlc/017` build (25 commits, `f930730..781d0b1`) against the spec's 15 acceptance criteria, the plan's 13 tasks, and `ARCHITECTURE.md`. Every task landed with tests and the suite is green at 903 cases, no pre-existing fixture modified. The verdict is minor-drift on three disclosed plan deviations plus three gaps the build left behind — the most consequential being that the path helper downstream stages use cannot compose a provisional spec directory from that spec's own frontmatter id, which weakens AC 5's promise that later stages run unchanged.

Two coverage limits are recorded honestly under Investigation: the reviewer authored the build under review, and subagent dispatch was unavailable this session, so the high-stakes set was read directly rather than fanned out to independent investigators.

## Alignment

### vs. Spec acceptance criteria

- AC 1 — met. Identity resolves through `allocate spec` at write, ahead of the spec file; the refusal branch writes nothing (`skills/spec/SKILL.md` Step 8). Prompt-level, so asserted by reading the flow, not by a fixture.
- AC 2 — met. Rides the shipped CAS; the batch path is covered by `case_jimalloc_reconcile_spec_apply_single_commit` and the pre-existing `allocate spec` concurrency fixtures.
- AC 3 — met. Both tiers exercised: origin tier via bare+clone fixtures, local tier via plain-repo fixtures (`alloc_origin_reachable` treats no-remote as reachable).
- AC 4 — met. `peek` is advisory and mutating-free (`case_jimalloc_peek_spec_no_mutation`); the shift is absorbed by `mv-spec-id` (`case_jimfile_mv_spec_id_absorbs_ordinal_shift`); nothing binds before Step 8.
- AC 5 — **partial drift.** Offline completion, registry exclusion, and high-water exclusion all hold (`case_jimalloc_provisional_spec_offline`, the two seed-skip cases, and `cmd_next_id`'s numeric gate which silently passes over a `P-` dir). But "the downstream stages run against it unchanged" is not fully true: see Finding 1.
- AC 6 — met. Bounded retries and the hard fail are pre-existing; the build made the reason single and unambiguous (`case_jimalloc_allocate_refusal_single_stderr_reason`).
- AC 7 — met. Preview-then-apply with the state column visible, idempotent and resumable, and no silent collapse: `case_specreconcile_preview_shows_state`, `case_specreconcile_apply_resume_converges`, `case_specreconcile_apply_halts_on_drift`, `case_jimalloc_realize_spec_keyed_have`.
- AC 8 — met. `case_specreconcile_apply_committed` asserts git records an `R`; `case_specreconcile_apply_uncommitted` covers the plain move.
- AC 9 — met. The `moved=` record lands on the specs-root ledger and no rename record is emitted — the publish builder composes only `spec allocate` and `group allocate` lines. Inertness to the vacated floor is asserted directly.
- AC 10 — met. Both refusals are classified by matching stderr anywhere, with the redirect asked about and the returned group treated as authoritative; exhaustion is presented as terminal.
- AC 11 — met. `case_jimalloc_seed_skips_provisional_dir` and `..._only_group`, with `..._prefix_invalid_token_conflicts` keeping the skip narrow.
- AC 12 — met. No `next-id` call remains in `skills/spec/SKILL.md`; the verb keeps its partition callers.
- AC 13 — met, with a duplication concern. Every tree/registry/config-derived token crosses a boundary before use. See Finding 2 for the cost of how that was achieved.
- AC 14 — met. The drift halt refuses on an occupied ordinal rather than the exact name, so another slug on the same ordinal still halts.
- AC 15 — met. 903 cases pass; `git diff --numstat` over the build range shows 0 deletions in `tests/jimalloc.sh`, `tests/jimfile.sh`, and `tests/jimledger.sh`, so no shipped fixture was modified or removed.

### vs. Plan tasks

- Tasks 1–5, 7–10, 12–13 — done as specified.
- Task 6 — **deviation (justified).** The plan directed widening `rename-tracked`'s source-basename gate. No such gate exists; `cmd_rename_tracked` gates the *new* basename and otherwise checks only paths and tracking. A committed `P-` dir already renames (verified in a scratch repo), and adding the described gate would have broken `/jim:partition`'s group- and territory-dir renames. The build pinned the behavior with three guards instead and left `jimledger.sh` untouched, making the File Manifest's third row unnecessary. The instruction traces to `move-spec-dir`, whose gate really is 3-digit-only — the verb DD 4 had rejected.
- Task 11 — **deviation (justified).** DD 3 requires renaming the placeholder to `P-<token>`, which DD 4's four-argument `mv-spec-id` cannot compose. Closed by adding a three-argument form restricted to the reserved provisional target, keeping the move inside the validated verb rather than putting raw `mv` in a skill body.
- Task 4 — **deviation (justified).** The plan's allocator contract said the preview prints fields 1–2, while its consumer contract required the preview to show the have/new column. Two fields makes that unimplementable, so both paths print three.
- No scope creep found: every changed file is in the File Manifest except `jimledger.sh`, which was *not* changed.

### vs. ARCHITECTURE.md

- Scripting Layer (bash + POSIX, no third-party deps) — respected. Only `awk`/`grep`/`sed`/`git` and shell builtins.
- `set -uo pipefail` + `export LC_ALL=C` — respected in the new `reconcile.sh`.
- `BASH_SOURCE`-relative composition — respected; `reconcile.sh` resolves jimfile/jimconf/jimalloc/jimledger that way.
- Single `is_valid_id` boundary, no new validator copy — respected in letter (every new predicate delegates the token check to `jimfile.sh valid-id`) but strained in spirit: the *provisional-form* grammar is now written three times. See Finding 2.
- Operational git (plumbing, literal pathspecs, containment) — respected; registry writes ride `alloc_publish` unchanged, the tracked rename rides `rename-tracked`'s literal-pathspec `git mv`, and the sweep containment-checks every target before any edit.
- Skill `allowed-tools` exactness — respected; the three new grants are verb-scoped prefixes, no `jimalloc.sh *`.
- No artifact IDs in code comments — respected. A sweep of added comment lines found one mention of `sdlc/001`, describing a fixture's own expected ordinal created two lines above rather than citing a spec, so it cannot rot.
- Tests under `tests/`, meta-test conventions — respected; `tests/specreconcile.sh` was produced by the scaffolder and keeps the dual-mode tail.

## Investigation

### High-stakes regions investigated

#### `alloc_cas_append` builder-status change (shared by both allocate paths)
- locations examined: `skills/file/scripts/jimalloc.sh:1016-1030`
- callers/consumers traced: `alloc_allocate_spec` (`:1201`), `alloc_allocate_issue` (`:1205`) — both allocation kinds flow through the changed lines
- tests checked: `tests/jimalloc.sh` refusal case plus the whole pre-existing allocate suite (111 → 124 cases, all green)
- verdict: satisfied — replacing the process-substitution `mapfile` with a captured command substitution preserves multi-line record output (trailing newlines are stripped by capture, and `<<<` restores exactly one), and the generic line survives only for the malformed-output case it was written for.

#### `alloc_reconcile_realize_spec` (untrusted registry → ordinal decisions)
- locations examined: `skills/file/scripts/jimalloc.sh:608-712`
- callers/consumers traced: `alloc_reconcile_spec_publish_builder`, and the preview path in `alloc_reconcile_spec`
- tests checked: 10 cases (`case_jimalloc_realize_spec_*`)
- verdict: satisfied — every candidate record is revalidated per field before it can become an identity to match, the ordinal derives only from the shared fold, and the batch validates wholly before emitting so a halt leaves no partial mapping.

#### `reconcile.sh` apply path (filesystem mutation from tree-derived names)
- locations examined: `skills/spec/scripts/reconcile.sh` — `scan_pending`, `apply_pending`, `ordinal_holder`, `rewrite_id`
- callers/consumers traced: `jimledger.sh rename-tracked` and `jimfile.sh mv-spec-id` as the only mutation primitives; both validate independently
- tests checked: 8 `case_specreconcile_apply_*` cases
- verdict: satisfied — corroboration gates the scan, the drift halt is per-identity and refuses on ordinal occupancy rather than exact name, and the frontmatter rewrite is anchored to the leading block (asserted by `..._rewrites_only_frontmatter`).

#### Citation sweep (writes across four content roots)
- locations examined: `skills/spec/scripts/reconcile.sh` — `build_remap`, `sweep_citations`
- callers/consumers traced: `skills/issue/scripts/index.sh` for the one conditional regen
- tests checked: 7 `case_specreconcile_sweep_*` cases
- verdict: satisfied — the remap is the whitelist, guards run over every target before any edit, output is location-only (asserted with a canary that must not appear), and excluding a trailing dash from the boundary is what keeps a `-2`-suffixed sibling from being matched inside.

#### AC 5's "downstream stages run unchanged"
- locations examined: `skills/file/scripts/jimfile.sh` `cmd_path` (`spec|plan|research` branch), `cmd_next_id` spec branch, `skills/partition/scripts/jimpartition.sh:1450`
- callers/consumers traced: `/jim:plan` Step 7 and `/jim:research` Step 2 both resolve their write path via `path <kind> <group> <id> <name>`
- tests checked: none exist for provisional-dir path composition
- verdict: **divergence** — see Finding 1. `cmd_next_id` and the partition renumber scan both pass over a `P-` dir harmlessly (numeric gates), which is the desired behavior for the former and a silent omission for the latter (Finding 5).

### Coverage

- Depth: thorough; `review_model: inherit`.
- **Reviewer independence gap:** the reviewer authored this build. Findings 1, 2, 4, and 5 are omissions found by reading against the ground truths rather than defects the build's own tests would surface, but an independent reviewer remains the stronger check on this range.
- **Fan-out not used:** subagent dispatch was unavailable this session, so no `Agent(investigator)` ran. The five high-stakes targets above were read directly instead. No region was left unexamined, but the evidence is single-perspective rather than independently gathered.
- Instrumentation: complete — ledger present, all stages instrumented, metrics trusted.

## Living intent

**Sensed:** 0 invariants · **holds:** 0 · **violations:** 0 (in-change 0 · pre-existing 0 · unlocalized 0) · **skipped:** 0 · **failed/unconfigured:** 1

### Violations

- None recorded — the sensor did not run, so this section asserts nothing about the group's invariants.

### Coverage

- The `sdlc` group *does* have a blueprint (`docs/specs/sdlc/000-blueprint/spec.md`), so the existence gate passed and the sensor was in scope.
- **Engine not run, contained:** the sensor's judge rung dispatches `Agent(judge)`, and subagent dispatch was unavailable this session. Rather than record a partial pass as a clean one, the sensor was skipped wholesale and reported here. Per the containment rule this did not abort the review; `invariant_violations` is left empty rather than `0`, since empty means "not measured" and `0` would claim a clean check.
- Re-running `/jim:verify --from-review docs/specs/sdlc/017-coordinated-spec-identity sdlc` in a session with dispatch available would close this gap without re-running the build.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 25 (11/11/1/0) |
| Files changed · insertions · deletions | 10 · +2194 · -33 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 4441s·1123s·1742s·3153s·6699s·167s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. The build's new write surfaces each carry the shipped envelope: the sweep validates and containment-checks every target before the first edit and reports locations only; the ledger record is composed from charset-gated elements because `append_line` gates nothing; the new grants are verb-scoped rather than whole-CLI, so the interview cannot reach `seed --apply` or the issue verbs.
- Noted, not a regression: `reconcile.sh` takes its specs root from configuration and globs it without a worktree-containment check. That matches how `jimfile.sh` and its siblings already treat configured paths — config is a checked-in, developer-owned file — so it is consistent with existing practice rather than something this build weakened.

## Findings

### 1. The path helper cannot compose a provisional spec directory from its own frontmatter id

- **Priority:** high
- **Description:** DD 2 makes the whole provisional token the directory basename (`P-<date>-<slug>`), while `jimfile.sh cmd_path` composes `<specs>/<group>/<id>-<name>/<kind>.md`. A caller passing the frontmatter `id:` (`P-20260728-alpha`) plus the slug (`alpha`) resolves `P-20260728-alpha-alpha/` — a directory that does not exist. The composition only works if the caller splits the token into `P-<date>` and `<slug>`, which nothing documents. `/jim:plan` Step 7 and `/jim:research` Step 2 both resolve their write path this way, and `/jim:spec` Step 8 as rewritten resolves the spec path the same way on the provisional branch. In practice the later stages are invoked with the spec directory and would likely write into it, which is why no test caught this — but AC 5's "downstream stages run against it unchanged" is not fully earned.
- **Suggestion:** decide the contract explicitly: either teach `cmd_path` to accept a provisional token as the whole basename (a third form, mirroring `mv-spec-id`), or state in the skill bodies that a provisional spec's paths are taken from the directory rather than composed. Then cover it with a fixture.
- **Relates to:** AC 5, DD 2, Task 11

### 2. The provisional-form grammar is written three times with nothing keeping them in lockstep

- **Priority:** medium
- **Description:** the reserved form (prefix, 8-digit issuance date, slug) is now expressed in `alloc_is_prov_form` / `alloc_valid_provid` (`jimalloc.sh`), `is_prov_basename` / `is_spec_dir_basename` (`jimfile.sh`), and `is_prov_identity` (`reconcile.sh`). Each delegates the token check to `jimfile.sh valid-id`, so the id boundary itself is not duplicated and `ARCHITECTURE.md`'s rule is met in letter. But the grammar around it is triplicated across a trust boundary: if one copy loosens, a token the others would reject reaches a path. The repo's precedent for a knowingly-duplicated check (`is_valid_id`, mirrored in three files) carries a documented SYNC note and a fixture asserting the copies are byte-identical; these have neither.
- **Suggestion:** single-source it — expose the check as a `jimfile.sh` verb the other two call — or, if the shell-out cost is unwanted, add the SYNC comments and a lockstep fixture matching the `is_valid_id` precedent.
- **Relates to:** AC 13, ARCHITECTURE.md → Scripting Layer

### 3. `/jim:spec`'s own validation checklist contradicts the provisional branch it now has

- **Priority:** medium
- **Description:** `skills/spec/SKILL.md:395` still requires "`id` is 3-digit zero-padded, sequential within group" while Step 8 of the same file now writes `id: "P-<date>-<slug>"` when the coordination point is unreachable. A spec bound offline fails its own skill's checklist.
- **Suggestion:** amend the checklist item to admit the reserved provisional form, naming it as the offline case that realization later replaces with an ordinal.
- **Relates to:** AC 5, Task 11

### 4. The new realization surface is absent from the user-facing docs

- **Priority:** medium
- **Description:** neither `WORKFLOW.md` nor `README.md` mentions `/jim:spec reconcile`, `/jim:issue reconcile`, or provisional mode at all, so the offline posture and the step that settles it are undiscoverable outside the skill bodies. The plan deliberately deferred this to review rather than treating it as a build task.
- **Suggestion:** document the offline posture and both reconcile surfaces together — the issue side has been undocumented since it shipped, so one edit covers both.
- **Relates to:** plan § Out of Scope

### 5. A partition renumber silently passes over a pending provisional spec

- **Priority:** low
- **Description:** `jimpartition.sh:1450` selects spec dirs with `^[0-9]{3}(-.*)?$`, so a `P-` directory is skipped during a split or merge renumber. A partition run inside an offline window therefore leaves a pending spec behind in the old group rather than renumbering or moving it. Skipping is the fail-safe direction — the directory is left intact rather than mangled — but the outcome is silent.
- **Suggestion:** decide deliberately whether partition should refuse while provisional specs are pending, or carry them; either way say so. Same family as the filed issue about realization not following a group rename, and worth settling together.
- **Relates to:** AC 5

## Deviations & feedback

- **Two of three plan deviations were plan defects, not build drift, and both were the same kind of error:** an instruction that described the right change in the wrong place. Task 6 named `rename-tracked`'s gate when it meant `move-spec-dir`'s, and Task 11 assumed a verb form DD 4 had not specified. Both surfaced only when the coder tried to execute them literally. A plan-phase check that each named verb actually has the property the task assumes — cheap to do while the research anchors are open — would have caught both.
- **The third deviation was an internal contradiction between two sections of the same plan** (the allocator contract said two fields, the consumer contract required three). One of the two readings was unimplementable, which is what made it safe to resolve without stopping. Worth noting that the security review's own finding drove the three-field requirement, so the later-written section was the correct one — a general rule when a security amendment and an earlier draft disagree.
- **The omission class produced every finding here.** All five come from reading the ground truths against untouched code, and none would have failed a test. The build's 903 green cases say the implemented behavior is right; they say nothing about the four places that should have changed and did not. That is the review's whole value on this range, and it argues for keeping the review a separate phase rather than folding it into the build's own verification.
- **`sec` ran twice for a reason worth keeping:** the dual-lens plan-phase pass caught the AC 7 / DD 1 misalignment that a spec-only review could not see, and the resulting amendment is what made the residual same-identity case a documented, surfaced condition rather than an unstated gap.
