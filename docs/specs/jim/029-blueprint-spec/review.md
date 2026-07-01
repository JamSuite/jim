---
spec: "jim/029"
type: "feature"
base_sha: "c4b255de6187c88c012d768792600382977fd847"
head_sha: "7b78aeb75f3ee0deb862edda4719eafcff43460a"
commits: "7"
commits_test: "1"
commits_feat: "3"
commits_fix: "0"
commits_refactor: "0"
files_changed: "9"
insertions: "241"
deletions: "6"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "10148"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "1205"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "3272"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "10857"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "4400"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "94"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
alignment: "aligned"
date: "2026-07-01"
---

# Review: Group blueprint spec (000-blueprint)

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 1 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the build of spec jim/029 over `c4b255d..7b78aeb` (6 task commits, +241/−6 across 9 files). The build shipped exactly what was scoped: the `/jim:blueprint` skill + template and the supporting `jimfile`/`jimconf` changes, with 314/314 deterministic tests green. Verdict is `aligned`; the single finding is a coverage note, not drift.

## Alignment

### vs. Spec acceptance criteria
- AC1–AC11 — **all met.** Path/slot (AC2), the five blueprint sections incl. invariants with criticality + verification method (AC3–7), grounding/traceability (AC8), generate-or-update (AC9), judgment-over-evidence (AC10) + secret-scrub (AC11) guardrails, and the approval gate with the `auto_blueprint` override (AC1) are all present in the shipped skill/template + the `jimfile` kind. Evidence under ## Investigation.

### vs. Plan tasks
- Tasks 1–7 — **all done, and only those tasks.** No scope creep: the `kinds`/enumeration test updates are required consequences of adding a kind/key, not extras. Security Finding 3 (write-path validation) landed in Task 1; Finding 4 (least-privilege tools) in Task 6 / DD #8.

### vs. ARCHITECTURE.md
- **Respected.** New `blueprint` kind follows the `cmd_path` pattern and validates the group through the single `is_valid_slug` boundary; `auto_blueprint` follows the bare-name `auto_*` convention; `SKILL.md` is <500 lines, uses `assets/` for the template, `!`-injection for config + a fenced block for the runtime-valued path, a scoped-Bash `allowed-tools` (no broad Bash, no Agent), and mirrors `/jim:arch`. Zero third-party deps.

## Investigation

### High-stakes regions investigated

#### `blueprint` path kind (AC2, security Finding 3)
- locations examined: `skills/file/scripts/jimfile.sh` (`KINDS`, the `blueprint)` arm in `cmd_path`)
- callers/consumers traced: `is_kind` (drives `path` validation — now accepts `blueprint`); the `kinds` output (test updated 6→7). No other consumers — the kind is new.
- tests checked: `tests/jimfile.sh` `case_jimfile_path_blueprint_resolves_reserved_slot`, `case_jimfile_path_blueprint_rejects_invalid_group`, `case_jimfile_next_id_ignores_000_blueprint`
- verdict: satisfied — composes `{specs}/<group>/000-blueprint/spec.md`, validates the group (rejects `Bad Group`), never touches `next-id`/`mv-spec`.

#### `auto_blueprint` config key (AC1 auto-override)
- locations examined: `skills/conf/scripts/jimconf.sh` (`KEYS`, `default_for`)
- callers/consumers traced: `resolve()` `auto_*` arm (resolves bare, no `_path`); the four enumeration tests (defaults / full-config / list / keys) + the malformed-lines count — all updated in lockstep
- tests checked: `tests/jimconf.sh` `case_jimconf_auto_blueprint_default_and_resolve` + the five enumeration cases
- verdict: satisfied — default `"false"`, resolves configured `"true"`, enumerations consistent (33 keys).

#### Skill guardrails + tool grant (AC8, AC10, AC11, security Finding 4)
- locations examined: `skills/blueprint/SKILL.md` (frontmatter `allowed-tools`; Step 2 untrusted-ingestion; Step 3 grounding + secret-scrub; Step 5 `auto_blueprint` branch)
- verdict: satisfied — data-not-instruction rule, `secret-looking value at <path:line>` scrub, "assert nothing the sources do not support", and a tool grant scoped to jimfile/jimconf Bash only (no broad Bash, no Agent).

#### Blueprint template (AC3–7)
- locations examined: `skills/blueprint/assets/blueprint-template.md`
- verdict: satisfied — Responsibility / Provides / Requires / Structure sections + an Invariants table carrying criticality and verification method per row.

### Coverage

- Depth: thorough.
- Full high-stakes set investigated directly. Investigator subagents were **not** dispatched: for a 9-file, 6-commit, single-author build with complete deterministic test coverage and full diff visibility, a fan-out would be disproportionate — the omission class was reasoned from the ground truths against the tree instead. No coverage gaps.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 7 (1/3/0/0) |
| Files changed · insertions · deletions | 9 · +241 · −6 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 10148s·1205s·3272s·10857s·4400s·94s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec, research, security, plan, ledger |

## Security regressions

- None identified. The build *adds* guardrails (untrusted-ingestion, secret-scrub, least-privilege `allowed-tools`) and validates the write-path through the id/slug boundary; no secrets committed, no weakened boundary, no new injection surface.

## Findings

### 1. The `/jim:blueprint` skill is checklist-validated but not exercised end-to-end

- **Priority:** low
- **Description:** The deterministic scripts are unit-tested (314/314), but the skill's actual behaviour — the scan → synthesize → diff-and-confirm flow, the fenced-block path resolution (`${CLAUDE_PLUGIN_ROOT}` expanding at Bash-tool runtime, vs. `!`-injection which substitutes at load), and the guardrails — has not been run against a real group. This is inherent to prompt artifacts (they are validated by checklist, not tests), so it is not drift; it is simply the only unverified surface.
- **Suggestion:** Smoke-test `/jim:blueprint jim` (generate the `jim` group's own blueprint) to confirm the end-to-end flow and the runtime path resolution.
- **Relates to:** Task 6 / AC1.

## Deviations & feedback

- **No code deviations** — the changed files matched the plan's File Manifest one-for-one.
- **Design-time security paid off at build time:** the plan-phase `/jim:sec` dual lens caught two Notables that were folded *before* any code (least-privilege tools → DD #8; the spec's absolute approval gate vs. the plan's auto-write → spec AC #1), so the build had no security rework.
- **Naming churned, cleanly:** the artifact name moved current → current-spec → blueprint-spec across the pre-build phases, each via a clean unpushed-history rewrite rather than stacked rename commits.
- **A latent test-runner gap surfaced:** `run.sh jimconf` matches only 2 of 63 cases (the file's cases lack the `case_jimconf_*` prefix), a false-green trap caught during Task 3 and tracked as issue #23.
