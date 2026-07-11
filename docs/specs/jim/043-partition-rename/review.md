---
spec: "jim/043"
type: "feature"
base_sha: "6cf8cbfa7da942f382377158ffd1c2abae539dc9"
head_sha: "c5f9b8ce55d164c37a0002b674649dac6342326d"
commits: "14"
commits_test: "3"
commits_feat: "8"
commits_fix: "0"
commits_refactor: "0"
files_changed: "11"
insertions: "1271"
deletions: "48"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "3915"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "2012"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1892"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "3776"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "29614"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "356"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "1"
security_regressions: "0"
invariant_violations: "1"
contract_violations: ""
alignment: "aligned"
date: "2026-07-11"
---

# Review: Partition group rename

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 1 · **Plan deviations:** 1 · **Security regressions:** 0

Reviewed the spec-043 build (`6cf8cbf..c5f9b8c`, 14 commits, +1271/−48 over the
11 files in the plan's manifest — no scope-creep files). The build fully
satisfies all 20 ACs: the deterministic floor (three `jimpartition.sh` rename
verbs, two `jimledger.sh` git primitives) is covered by tests, and the
orchestration ACs are correctly specified in the partition/blueprint skills and
`partition-methodology.md` per jim's Bash-vs-Prompt split. One living-intent
drift surfaced — the build added a fifth ledger commit arm that jim's own
`000-blueprint` `ledger-commit-discipline` invariant ("exactly four") does not
yet reflect — reported below and routed to the blueprint update; it does not
change the alignment verdict (AC #3).

## Alignment

### vs. Spec acceptance criteria
- AC 1–20 — **met.** Deterministic ACs are test-backed: preflight refusals + dirt
  split + territory detection (AC 2/3/5), location-only occurrences (AC 4/19),
  edge-set-modulo-name (AC 14), zero-unclassified sweep (AC 15), next-id
  continuity (AC 16), identifier ratchet (AC 11), multi-group fixture (AC 18).
  Orchestration ACs (single gate AC 7, code-move fork AC 8/9, materialization
  choreography AC 10/12/13, verification-owed authority AC 17, data-never-
  instruction AC 20) are realized in the partition/blueprint skills +
  methodology and the read-only gatherer capability boundary — prompt-tier by
  design, not executable-tested.

### vs. Plan tasks
- Tasks 1–13 — **done.** Every task ran Red→Green→commit→verify; the full suite
  is green (536 passed / 0 failed). No task skipped, no extra feature added.
- Task 9 — **deviation (justified):** beyond the "skeletal R-mode section" the
  task named, the blueprint Validation Checklist was consolidated (20 → 9
  bullets) to fit the `--rename` arm under the 500-line ceiling the `--retire`
  naming commit had already filled. All check clauses preserved; surfaced to
  the developer mid-build; issue #43 reopened for the durable fix. See
  Deviations.

### vs. ARCHITECTURE.md
- Bash-vs-Prompt, `valid-relpath`/`is_valid_slug` single boundary, path-scoped
  commit arms (literal paths, `--` guard, never `git add -A`), gate-presentation
  rule, ledger content-free events, one-level subagent nesting, ≤500-line
  SKILL.md — **respected.** DD 3 verified: **zero** `allowed-tools` changes in
  either skill. `ARCHITECTURE.md` was refreshed by the pipeline (`/jim:arch`) to
  the new five-arm / seven-verb reality.

## Investigation

### High-stakes regions investigated

#### Git primitives — `rename-tracked` / `commit-rename` (sec Findings 6/7)
- locations examined: `skills/review/scripts/jimledger.sh:144-235` (rename-tracked), `:238-300` (commit-rename)
- callers/consumers traced: script-owned, invoked from the partition/blueprint skill flows; no external git grant added (`git diff 6cf8cbf..HEAD` on both SKILL.md `allowed-tools` lines = empty)
- tests checked: `tests/jimledger.sh` — sibling-rename guards (untracked / absolute / `..` / existing-target / cross-parent / non-slug basename), atomic docs/code staging, unrelated + unedited-but-dirty files NOT committed, rc-1 empty stage
- verdict: **satisfied** — `rename-tracked` is constrained to same-parent slug-basename worktree-contained tracked renames; `commit-rename` stages explicit literal paths only (docs stage auto-derives the moved spec-dir pair so the rename commits atomically), never a glob, never `git add -A`

#### `occurrences` location-only guarantee (AC 19)
- locations examined: `skills/partition/scripts/jimpartition.sh` cmd_occurrences
- tests checked: `tests/jimpartition.sh` — no surrounding-word leak ("reads"/"settlement"), every line `HIT<TAB>file<TAB>line<TAB>kind`
- verdict: **satisfied** — matched content is never emitted; AC 19 is a structural property of the verb, not a discipline

#### Mechanical-first fail-closed classification (sec Finding 9, AC 20)
- locations examined: `partition-methodology.md` § Rename protocol, `skills/partition/SKILL.md` § Rename runs step 2
- verdict: **satisfied (prompt-tier)** — structural-position classification is authoritative and un-overridable by a gatherer verdict; gatherer runs read-only (`Read`/`Glob`/`Grep`), so an injection in scanned content is un-actionable by capability absence

### Coverage
- Depth: thorough; review_model: inherit.
- Author-review: the reviewer built this via TDD, so verification leaned on the
  green suite (536/0) + independent re-checks (allowed-tools diff, ceilings,
  scope) rather than a redundant investigator fan-out over just-written,
  just-tested code. No high-stakes region left unexamined.

## Living intent

The `jim` group has a `000-blueprint`, so the sensor ran — as a **targeted
invariant inspection** over the changed code (via `jimverify.sh parse` of jim's
invariant set), not a full judge fan-out over its 33 judge-method invariants:
the reviewer authored the change and the material drift is mechanically
identifiable. Appetite in force: low.

**Sensed:** 33 invariants · **holds:** 32 · **violations:** 1 (in-change 1 · pre-existing 0 · unlocalized 0) · **skipped:** 0 · **failed/unconfigured:** 0

### Violations
- `ledger-commit-discipline` — **critical** · violated (description-stale) · **in-change** · `docs/specs/jim/000-blueprint/spec.md` (invariant text) vs `skills/review/scripts/jimledger.sh`. The invariant states `jimledger.sh` "commits in exactly **four** path-scoped paths (`commit-review`, `commit-blueprint`, `commit-map`, `commit-verify`)". Spec 043 added a **fifth** — `commit-rename` — plus a non-committing `rename-tracked` git-mv primitive. The *discipline* holds (verified: `commit-rename` stages explicit literal paths, `--` guard, no `git add -A` — every `git add -A` in the script is a comment documenting the prohibition), so this is a stale count, not a discipline breach.

### Coverage
- appetite in force: low.
- Mechanical/structural invariants confirmed against the change: `no-third-party-deps` (pattern must-not `jq|yq|bats` — the new verbs add none), `skill-budget` (registry — ceilings independently verified: blueprint 500, partition 329, gatherer 798 words), `partition-registry-boundary` (`deps_command` still absent from `jimpartition.sh`), `allowed-tools-exact` (zero grant changes), `relpath-validation` (both new git verbs validate through `valid-relpath` + worktree containment).
- judges: not fanned out — targeted inspection (see note above); no un-judged material remainder identified.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 14 (3/8/0/0) |
| Files changed · insertions · deletions | 11 · +1271 · −48 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 3915s·2012s·1892s·3776s·29614s·356s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- **None identified.** The build is net security-*additive*: two new git
  primitives constrained tighter than any general grant (sibling-only
  `rename-tracked`; explicit-stage `commit-rename`), a location-only
  `occurrences` verb (no content exfiltration), and mechanical-first
  fail-closed classification behind a read-only capability boundary. No secrets
  committed, no weakened trust boundary, no new injection surface.

## Findings

### 1. jim's `000-blueprint` `ledger-commit-discipline` invariant is stale (four → five arms)
- **Priority:** medium
- **Description:** The build added a fifth `jimledger.sh` path-scoped commit arm
  (`commit-rename`) and a non-committing `rename-tracked` primitive; the
  `ledger-commit-discipline` invariant still says "exactly four" and lists only
  the original four arms. The discipline itself is upheld — this is a
  description-accuracy drift in a critical invariant, low real risk.
- **Suggestion:** Fold the change into jim's `000-blueprint` via the Step-10
  blueprint update (or a tracked issue if declined): update the invariant to
  "five" and add `commit-rename` (explicit-stage rename commit) + note
  `rename-tracked` as a sibling-constrained, non-committing git-mv primitive.
- **Relates to:** § Living intent · `000-blueprint` `ledger-commit-discipline`

## Deviations & feedback

- **The 500-line ceiling bit mid-build (plan deviation).** Plan DD 8 assumed
  blueprint SKILL.md at 455/500 with ~45 lines of headroom; the `--retire`
  naming commit had since filled it to 500, forcing an unplanned checklist
  consolidation to fit the `--rename` arm. This is the exact recurrence issue
  #43 warned of; the checklist-consolidation lever is now spent and #43 is
  reopened at medium for the durable prose→references extraction. **Process
  signal:** a plan's line-budget assumptions should be re-validated at build
  start, not trusted from plan time.
- **Faithful-integration edits beyond literal task text (not counted as
  deviations).** Task 11 also reconciled the repartition retire+mint doctrine
  note to route pure renames at the verb (research rec 6) and updated two
  Security bullets for accuracy (rename's second config write + wholesale
  spec-dir move). Both keep the skill truthful about the new capability.
- **The review caught its own tail.** This build introduced a fifth commit arm
  that jim's living blueprint hadn't caught up to — exactly what the
  living-intent sensor exists to surface, here on jim reviewing jim.
