---
spec: "sdlc/015"
type: "feature"
base_sha: "540dc676f3eab944a50b193c1f8b65fa8f434bc0"
head_sha: "edb99171f7800f48425b1dc8865d52d8ac1b01bc"
commits: "9"
commits_test: "0"
commits_feat: "6"
commits_fix: "0"
commits_refactor: "0"
files_changed: "11"
insertions: "304"
deletions: "19"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "3040"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "340"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "3181"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "3713"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "1214"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "1"
security_regressions: "0"
alignment: "minor-drift"
date: "2026-06-26"
---

<!-- Budget: findings are specific and actionable. Record references, counts, and
     locations — never raw secrets or sensitive diff content (scrub before write). -->

# Review: Depth-aware post-build review

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 4 · **Plan deviations:** 1 · **Security regressions:** 0

Reviewed the spec-027 build (`540dc67..edb9917`, 9 commits, 11 files, +304/−19) at `thorough` depth with a 6-investigator fan-out (cap 10, none bound; model `inherit`). All 10 spec ACs are satisfied and there is no scope creep — the three deferred follow-ons stayed out. Two real quality gaps surfaced: a **verified vacuous test** for the `--function-context` flag and an **incomplete `review_fanout_cap` validation** that diverges from the plan/F7 "else default". The implementation itself is functionally correct; these are a test-validity gap and an input-edge-case, hence minor-drift.

**Update (fixed before completion):** all four findings resolved — Finding 2 in `6da9343` (SKILL.md guard now rejects non-positive caps), Findings 1/3/4 in `699d1ec` (function-context test anchored to a context line and verified non-vacuous; no-baseline stderr assertion; new malformed-SHA case). Suite 303/303. The `alignment`/`plan_deviations` frontmatter records the *as-found* review state.

## Alignment

### vs. Spec acceptance criteria
<!-- Verdict per AC; evidence under ## Investigation. -->
- AC1–AC10 — **all met.** Depth concentration (AC1), complete-satisfaction/omission-class wiring (AC2), adversarial stance (AC3), auditable evidence template (AC4), real-change scoping (AC5), depth knob + `--depth` (AC6), configurable investigator model end-to-end (AC7), bounded coverage (AC8), read-only/advisory (AC9), untrusted across the deep pass incl. investigator results (AC10). No AC unmet or partial.

### vs. Plan tasks
- Tasks 1–8 — **all done, and only those.** One deviation: Task 4 / DD5 / sec F7 specify `review_fanout_cap` validation as "positive integer, else default", but `SKILL.md` Step 4a only falls back on a *non-numeric* value (Finding 2).
- No scope creep: the deferred follow-ons (review-as-ledger-stage / verdict history; template `spec`-column metrics fix; frontmatter↔body count check) were confirmed **not** pulled in.

### vs. ARCHITECTURE.md
- Respected — one-level nesting (inline reviewer → first-level investigators), capability-absent read-only subagent, bare-name `review_*` config arm, scripting-layer conventions, SKILL.md ≤500 lines. ARCHITECTURE.md refreshed for the new components.

## Investigation

<!-- Auditable depth record. Locations only — no raw secrets. -->

### High-stakes regions investigated

#### `jimledger.sh diff` (command construction / range safety)
- locations examined: `skills/review/scripts/jimledger.sh:57-60,129-145,157-167,250`
- callers/consumers traced: `resolve_range → validate_sha → jimfile.sh valid-id → is_valid_id`; `cmd_diff` is a leaf consumed as untrusted output
- tests checked: `tests/jimledger.sh:331-378`
- verdict: **satisfied** — SHAs validated before interpolation (alnum-anchored allowlist forecloses `-`-prefix / space / `..` injection), `--` guard present, `--function-context` a fixed literal, exit 2 on no baseline. Mirrors `cmd_files` exactly (DD1, sec F4).

#### `jimconf.sh` `review_*` dispatch (shared resolver — regression risk)
- locations examined: `skills/conf/scripts/jimconf.sh:42,65-67,114-122,143-179`
- callers/consumers traced: `resolve()` consumers `cmd_get`/`cmd_list`/`cmd_keys`; enumerated all 32 keys
- tests checked: `tests/jimconf.sh:680-730` + enumerations
- verdict: **satisfied** — bare-name resolution correct (not `_path`); no pre-existing key captured by `review_*` (`require_review`/`auto_review` resolve via their own arms); unknown `review_`-prefixed key still errors via the `default_for` gate.

#### `investigator.md` (capability boundary)
- locations examined: `agents/investigator.md:13-14,23-34,44-58`; `agents/issue-analyst.md:13` (precedent)
- verdict: **satisfied** — `tools: [Read, Glob, Grep]` only; zero `Bash` grants (stricter than `issue-analyst`); no write/exec/spawn path; adversarial + untrusted discipline present (sec F2/F6, AC9).

#### `SKILL.md` depth orchestration
- locations examined: `skills/review/SKILL.md:12-13,29,59-94,110,158-170`
- verdict: **partial** — knobs/validation, model-param-when-concrete, fan-out bound + named coverage, untrusted investigator results, AC-by-AC omission-class, `--depth`, followability all encoded. **Gap:** `review_fanout_cap` guard catches only non-numeric, not non-positive (Finding 2).

#### New tests (validity)
- locations examined: `tests/jimledger.sh:331-378`, `tests/jimconf.sh:680-730` + enumerations; `testlib.sh:111-123` (`assert_match` = unanchored `grep -E`)
- verdict: **partial** — range-scoping and jimconf `review_*` cases are genuine; **`case_jimledger_diff_function_context` is vacuous** (Finding 1, verified); `diff_no_baseline` is weak (Finding 3).

#### AC completeness sweep (omission class)
- locations examined: `spec.md:46-88` vs all shipped artifacts
- verdict: **satisfied** — all 10 ACs fully met; no scope creep; deferred follow-ons confirmed excluded.

### Coverage

- Depth: thorough; `review_model`: inherit (investigators ran the session model).
- Full high-stakes set investigated — 6 investigators, fan-out cap (10) not bound. No regions left un-investigated.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 9 (0/6/0/0) |
| Files changed · insertions · deletions | 11 · +304 · −19 |
| Stage runs (spec·research·plan·sec·build) | 1·1·1·2·1 |
| Stage durations (research·plan·sec·build) | 340s·3181s·3713s·1214s |
| Interruptions (research·plan·sec·build) | 0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

<!-- Note: spec stage ran 3040s (instrumented) but the template's duration/interruption
     rows omit a spec column — the deferred follow-on, not fixed here. commits_test=0
     because tests were folded into each task's feat commit (green-on-its-own). -->

## Security regressions

- None identified. The build *improves* posture (capability-absent investigator, validated diff range, untrusted-results discipline). All seven design-time findings are designed-in. `review_fanout_cap=0` silently disabling the fan-out (Finding 2) is an availability/quality edge, not a security regression under jim's trusted-developer model.

## Findings

### 1. `case_jimledger_diff_function_context` is vacuous (verified)

- **Priority:** medium
- **Description:** The test's only behavioral assertion is an unanchored `grep` for `ctx_fn() {`, which git emits in the `@@` hunk header even at plain `-U3` (default funcname heuristic; there is no built-in `bash` userdiff driver, so the fixture's `.gitattributes diff=bash` is inert). Empirically confirmed: the assertion matches in both `-U3` and `--function-context` output, so the test would pass even if the flag were removed.
- **Suggestion:** Anchor the assertion to a *context* line only `--function-context` produces — e.g. `'^ ctx_fn\(\) \{'` (leading space excludes the `@@` header) or `'^ +a=1'` (a body line outside the `-U3` window).
- **Relates to:** Task 1, `tests/jimledger.sh:344-358`

### 2. `review_fanout_cap` validation lets a non-positive value through

- **Priority:** medium
- **Description:** `SKILL.md` Step 4a says "treat `review_fanout_cap` as a positive integer — on a non-numeric value use `10`." A configured numeric-but-non-positive value (`0`, `-3`) is not non-numeric, so the fallback misses it; `0` would silently disable the fan-out — the exact AC8 silent-degradation risk the cap exists to prevent. Diverges from plan DD5 / sec F7 ("positive integer, else default").
- **Suggestion:** Tighten the guard wording to "on a non-positive or non-numeric value use `10`."
- **Relates to:** AC8, plan DD5, sec F7, `skills/review/SKILL.md` Step 4a

### 3. `case_jimledger_diff_no_baseline_exits_2` is weak

- **Priority:** low
- **Description:** Asserts only `RC==2`; an unknown subcommand also exits 2, so in isolation it can't distinguish "diff handles no-baseline" from "diff arm removed" (mitigated suite-wide by the three exit-0 diff cases). Matches the equally-bare sibling `files`/`metrics` no-baseline cases.
- **Suggestion:** Add `assert_nonempty "$ERR"` (ideally `assert_match 'baseline' "$ERR"`).
- **Relates to:** Task 1, `tests/jimledger.sh:360-365`

### 4. No explicit malformed-SHA test for the range branch

- **Priority:** low
- **Description:** `resolve_range`'s malformed-SHA reject (`jimledger.sh:138-143`) is exercised only indirectly; no test feeds a tampered SHA into the ledger and asserts `diff`/`files`/`metrics` exit 2.
- **Suggestion:** Add one shared case feeding a malformed `base_sha`/`head_sha` and asserting exit 2.
- **Relates to:** sec F4, `skills/review/scripts/jimledger.sh:138-143`

## Deviations & feedback

- The depth-aware fan-out paid off on its first real run: an adversarial investigator caught a **vacuous test in its own suite** that a green-bar build masked — exactly the "looks fine but isn't" class the feature targets. Worth noting the test passed CI; only deep, adversarial reading surfaced it.
- The single plan deviation (Finding 2) is a wording-vs-intent gap that slipped from plan → skill text; a tighter "else default" phrasing in the plan's task body would have carried through.
- Both medium findings are one-line fixes — cheap to fold in before marking the build complete.
