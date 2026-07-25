---
spec: "blueprint/013"
type: "feature"
base_sha: "8cbe1c919f530dcb77fc5733a6f58c32db64748f"
head_sha: "def719932f5dea9e49f686d70985466d956480ac"
commits: "8"
commits_test: "1"
commits_feat: "3"
commits_fix: "0"
commits_refactor: "0"
files_changed: "11"
insertions: "1776"
deletions: "11"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "4688"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "988"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "4155"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "5849"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "866"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "382"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "0"
contract_violations: ""
alignment: "aligned"
date: "2026-07-08"
---

# Review: Retirement sweep

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 1 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the spec 041 build (`8cbe1c9..def7199`, the final slice of issue #22's
invariant-verification-engine). The build ships exactly what the plan scoped —
one new facts-only `scope-census` verb, the judge's third claim type, a
methodology reference, and `--retirement` wiring — with all 11 ACs satisfied,
no scope creep, and the security-critical Finding-4 pathspec guard verified
airtight. **Metrics caveat:** `base_sha` was recorded before three pre-build
commits (the spec-chain docs + the issue update), so `files_changed=11` and
`insertions=1776` are inflated by those documents; the actual code change is 5
files (`jimverify.sh`, `tests/jimverify.sh`, `judge.md`, `SKILL.md`, and the
new `retirement-methodology.md`).

## Alignment

### vs. Spec acceptance criteria

- AC #1 (two grains + <2-group short-circuit) — met: SKILL.md routing + methodology R1; host self-check confirmed the single-group short-circuit path.
- AC #2 (three retirement classes, exhaustive buckets) — met: methodology outcome vocabulary + ladder; `scope-census` supplies the invariant staleness fact, `edges`/`contracts-check` the requires + dead-surface facts.
- AC #3 (per-source disagreement diagnostic) — met: judge `sources_examined` block + report shape.
- AC #4 (hints first, candidate-generators, mass-anomaly guard) — met: `scope-census` counts (verified), methodology DD-8 guard.
- AC #5 (judge evidence-fed, appetite-gated, per-source-evidence-or-inconclusive) — met: judge.md retirement contract + methodology confirmation burden.
- AC #6 (unavailable ≠ found-nothing) — met: `scope-census` emits `na` on a non-git tree, never `0` (investigator-confirmed at `jimverify.sh:628`); judge `unavailable` handling.
- AC #7 (consolidated criticality-led report, issues, verify-then-trim framing) — met: methodology report shape + R5/R6.
- AC #8 (never writes) — met: no write path in code; SKILL.md/methodology state signal-only.
- AC #9 (project-tier counters, self-commit, no verdict artifact) — met: methodology durable-counters section.
- AC #10 (flags only on declared data; unswept named; coverage explicit) — met: `scope-census` `UNSCOPED`/`na`; methodology degradation rules.
- AC #11 (untrusted discipline, location-only incl. spec corpus, redaction) — met: `emit_scope` sanitization + location-only desc (investigator-confirmed); judge.md + methodology extend it to the corpus.

### vs. Plan tasks

- Tasks 1–7 — all done, and only those. No scope creep; no files touched beyond the manifest.
- TDD discipline honored: `test:` commit preceded `feat:`; Red confirmed (9/10 failed pre-impl), Green 10/10, full suite 70/70.

### vs. ARCHITECTURE.md

- Bash + POSIX, no third-party deps, `set -uo pipefail` — respected (`scope-census` is bash/awk/git).
- Facts-vs-verdicts (script emits facts, skill judges) — respected: `scope-census` emits counts; classification lives in the methodology/skill.
- Judge capability boundary (`Read`/`Glob`/`Grep`) — respected: third claim type, no tool change.
- No new configuration keys; read-only toward the project; no-standing-verdict — respected.
- ARCHITECTURE.md itself was refreshed via `/jim:arch` (verify-engine tree block, judge line + claim narrative, new spec 041 paragraph) — pending commit.

## Investigation

### High-stakes regions investigated

#### `cmd_scope_census` + `emit_scope` (the sole executable change)
- locations examined: `skills/verify/scripts/jimverify.sh:561-659` (function + helper), `:270-301` (`safe_path_param`/`path_under`), `:222-260` (`cmd_territory`), `:343-360` (`parse_params`), `:1107` (dispatch), `:28-37` (header doc); `skills/file/scripts/jimfile.sh:209-232` (`valid-relpath`).
- callers/consumers traced: dispatch case `:1107`; consumed by `/jim:verify --retirement` (no other in-repo caller). Reuses `cmd_territory`/`cmd_parse`/`parse_params`/`safe_path_param`/`path_under`.
- tests checked: `tests/jimverify.sh:1201-1386` — `census_repo` fixture + 10 cases (populated / empty / territory-default / exists / absent-kind / judge-no-record / pathspec-magic / non-git-na / unscoped-sentinel / no-args-rc2).
- verdict: satisfied — **Finding-4 guard airtight**: the only git call (`git ls-files`, `:607`) is enumerated once with no pathspec; the untrusted scope reaches only `path_under` (double-quoted base → literal) and the deliberate `absent=` bash glob, never git. Magic scopes (`:(exclude)*`, `:/`) pass `valid-relpath` but are counted literally as 0, so no count skew is possible. Output contract, counting, and location-only evidence all met; no quoting/scoping/subshell bug (process-substitution loop runs in-shell, locals re-scoped per iteration).

### Coverage

- Depth: thorough; review_model: inherit (session model).
- Full high-stakes set investigated. The one executable region got a dedicated investigator; the four prompt/doc changes (`judge.md`, `SKILL.md`, `retirement-methodology.md`) were spine-assessed against their ACs (not runtime-executable), and the test change is corroborated by the green suite. No fan-out cap reached.

## Living intent

**Sensed:** 33 invariants · **holds:** 2 (mechanical) · **violations:** 0 · **skipped:** 0 · **failed/unconfigured:** 1 (registry, unconfigured) · judge rung: change-selected, assessed inline

The reviewed group is `jim` (single-group). The whole-group mechanical floor ran
against the post-build tree; the judge rung's change-selected prose invariants
were assessed inline against the build's diff.

### Violations

- None — every checked invariant holds. The build was designed to honor jim's living intent: `no-source-eval`, `ref-validation` / `relpath-validation`, `untrusted-content`, `agent-boundaries`, `script-preamble`, `bash-source-relative`, `allowed-tools-exact`, `verify-no-verdict`, and `tests-under-tests` all hold against the changed code (`scope-census` gates scopes through `valid-relpath`, never sources/evals, emits location-only evidence; `judge.md` keeps its capability boundary; no new `allowed-tools`; no verdict artifact persisted).

### Coverage

- appetite in force: `low` (default — thorough; judges everything above threshold).
- Whole-group floor ran. `no-third-party-deps` (critical, pattern) → **holds** (`skills/` carries no forbidden imports). Territory conformance flagged only pre-existing root/docs scaffolding (`ARCHITECTURE.md`, `BLUEPRINT.md`, `README.md`, `.claude-plugin/`, …) — informational, not violations; every changed *code* file sits inside `skills/`/`agents/`/`tests/`.
- `skill-budget` (medium) is `registry:skill-line-budget` — **unconfigured** in this repo (no `verify_command_skill-line-budget`), so the floor executes nothing; substantively it holds (`skills/verify/SKILL.md` is 308 lines, under the 500 budget).
- judges: 31 judge-method invariants; change-selected against the diff and assessed as holding. No cap reached.
- Contract-edge phase did not run — jim is single-group with no contract graph (`contract_violations` empty).
- Sensor mechanism: the whole-group floor was executed directly via `jimverify.sh check` (context-efficient) rather than the full `Skill(jim:verify) --from-review` adapter, so no separate `verify` event was recorded on `000-blueprint/ledger.md`; the outcomes are reported here. A degenerate case for single-group jim — no cross-group edges, no in-change fork to ground.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 8 (1/3/0/0) |
| Files changed · insertions · deletions | 11 · +1776 · -11 (incl. pre-build doc commits — see Summary) |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 4688s·988s·4155s·5849s·866s·382s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. The build adds no new executable surface: `scope-census` runs no config-derived command, and its one git call is a pathspec-free enumerate. The Finding-4 pathspec guard was verified airtight (investigation above); the untrusted scope never reaches git, and evidence stays location-only with sanitized fields.

## Findings

### 1. `na` wins over `HYGIENE` on a non-git tree when both apply

- **Priority:** low
- **Description:** In `cmd_scope_census`, the non-git `na` check (`jimverify.sh:628`) precedes the `safe_path_param` HYGIENE gate (`:636`), so on a non-git tree an unsafe/magic explicit scope emits `SCOPE <id> na <kind> <sanitized-scope>` rather than a `HYGIENE` line. Harmless — on a non-git tree there is nothing to count, the desc is sanitized (no leak, no column shift), and the skill routes both `na` and `HYGIENE` to the judge. The plan's Interface Contract lists the two as distinct cases without specifying precedence when both apply; this is an unspecified edge resolved sensibly, not drift.
- **Suggestion:** No change required. If ever tightened, gate HYGIENE before the na short-circuit for a cleaner contract; not worth a follow-on on its own.
- **Relates to:** AC #6; Interface Contracts (`scope-census`)

## Deviations & feedback

- Clean build: 7 TDD tasks, 0 interruptions, 866s. The two `/jim:sec` runs (spec-lens then dual-lens) each folded findings before the next gate — the dual-lens run caught the Finding-4 git-pathspec surface that the spec lens could not see, which is exactly the value of re-running security once the plan's mechanics exist. Worth carrying forward: the plan-lens security pass earns its keep on specs that introduce new deterministic primitives.
- The `base_sha`-before-pre-build-commits ordering inflated the diff metrics with doc content. A cleaner future pattern: commit the spec chain before `jimledger.sh start` so the build range is code-only. Minor, cosmetic to the metrics.
