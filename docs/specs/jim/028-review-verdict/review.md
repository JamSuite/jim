---
spec: "jim/028"
type: "feature"
base_sha: "683210f9af0ed3963f2b24a38a063941758792cb"
head_sha: "95983c9f35b7637acc0e0b41b5d27bcd1176d8c7"
commits: "6"
commits_test: "0"
commits_feat: "5"
commits_fix: "0"
commits_refactor: "0"
files_changed: "5"
insertions: "216"
deletions: "38"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "4374"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "266"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "34177"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "2325"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "829"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "425"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "1"
security_regressions: "0"
alignment: "minor-drift"
date: "2026-06-26"
---

# Review: Instrument /jim:review as a ledger stage and preserve verdict history

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 4 · **Plan deviations:** 1 · **Security regressions:** 0

Reviewed the spec-028 build (5 feat commits over `683210f..95983c9`, +216/−38 across 5
files, all under `skills/review/` + `tests/`) against spec, plan, and architecture. This
was a self-hosting dogfood — the just-built `/jim:review` reviewing the code that built
it. **All 10 spec ACs are functionally met** (independently verified). The drift is
entirely **documentation/test-hygiene completeness**: one plan-specified test
reconciliation was skipped, and the architecture's declared single-source-of-truth
(`WORKFLOW.md`) plus `agents/reviewer.md` were left stale. No functional defect, no
security regression.

## Alignment

### vs. Spec acceptance criteria
- AC1 (review instrumented stage) — **met**: `review` in `LEDGER_STAGES` (`jimledger.sh:196`); started/finished wired in the skill.
- AC2 (completion event carries verdict + findings) — **met**: `event … review finished alignment=… findings=…` (`SKILL.md:104-108`).
- AC3 (trajectory recoverable; review.md latest snapshot; re-run appends) — **met**: append-only `review finished` lines; `SKILL.md:130` overwrite-snapshot wording.
- AC4 (fixed code-literal key set; no key from ledger text) — **met**: keys are `printf` literals (`jimledger.sh:236,239`); loop over fixed `LEDGER_STAGES`.
- AC5 (interruption visible) — **met**: `phase_event_metrics` interruption math applies to `review` (demonstrated live: the Step-2 read showed `review_interruptions=1` before `finished`).
- AC6 (un-instrumented build self-measurable) — **met**: `cmd_metrics` decouple emits stage metrics with no baseline (`case_jimledger_metrics_review_no_baseline`).
- AC7 (review.md reports its own metrics) — **met**: started→finished→re-read→compose ordering; this review's own `review_runs=1`/`review_duration_seconds=425` landed in the frontmatter.
- AC8 (atomic path-scoped commit) — **met**: `git commit -- review.md ledger.md`, no `-A`.
- AC9 (verdict value validated; review.md authoritative) — **met**: enum `case` + `^[0-9]+$` gate; no metacharacter leak through `ledger_kv`.
- AC10 (least-privilege commit) — **met**: single `commit-review` site; `allowed-tools` unchanged (no broad `Bash(git *)`).

### vs. Plan tasks
- Tasks 1–6 — **done**, each TDD-committed; full suite 310/310, jimledger 34/34.
- **Task 1 deviation:** the task body specified *"Reconcile any existing no-baseline test that asserts rc=2."* The new positive case was added but `case_jimledger_metrics_no_baseline_exits_2` (`tests/jimledger.sh:305-310`) was left unreconciled — see Finding 1.
- No scope creep beyond the plan (the build correctly touched only the 4 File-Manifest files).

### vs. ARCHITECTURE.md
- The script/`/jim:review` invariants are honored: the metrics channel's no-key-injection property holds (key set fixed, value shape-validated), and the "non-build stages don't commit" convention is overturned exactly as the spec authorized (terminal review self-commits). `ARCHITECTURE.md` itself was refreshed by the build gate's `/jim:arch` and is consistent.
- **Drift:** `ARCHITECTURE.md:234-238` declares `WORKFLOW.md` the single source of truth that "all agents and skills must be consistent with." `WORKFLOW.md` now lags the implementation — see Finding 2.

## Investigation

Thorough depth; 3 read-only `investigator` subagents (session model), full high-stakes set, no fan-out cap reached.

### High-stakes regions investigated

#### `cmd_commit_review` — git-write safety (AC8/AC10/DD4)
- locations examined: `jimledger.sh:97-113` (function), `:291-303` (dispatch), `:1-25,34-45` (docs); `tests/jimledger.sh:361-403`; `SKILL.md:13` (allowed-tools).
- callers/consumers traced: only `SKILL.md:137`; the only git-write in the script (every other `git -C` is a read).
- tests checked: `case_jimledger_commit_review_{scoped,message,tampered_verdict,non_repo}` — path-scoping proven via the `^ M` unstaged-porcelain assertion; injection proven absent (`$(touch hacked)` → no `hacked` file).
- verdict: **satisfied** — literal paths + `--` guards on add and commit, no `git add -A`, enum-gated message, graceful non-zero on failure, no broad git grant.

#### `review_verdict_metrics` + `ledger_kv` — verdict validation (AC4/AC9)
- locations examined: `jimledger.sh:130-149` (`ledger_kv`), `:226-240` (`review_verdict_metrics`), `:242-289` (`cmd_metrics`).
- callers/consumers traced: `cmd_metrics:287`; `ledger_kv` reused by `resolve_range`.
- tests checked: `case_jimledger_metrics_review_verdict` (happy) + `…_tampered` (rejection) — both anchored.
- verdict: **satisfied** — keys are literals; `alignment` exact-`case`-gated, `findings` `^[0-9]+$`-gated; embedded `=`/`;`/newline/metacharacter cannot leak a forged line. (Non-security note: `ledger_kv`'s `last` branch doesn't reset `val` per line — harmless, every emitted `finished` line carries both keys.)

#### Omission class — consumers + docs outside the diff
- locations examined: every `jimledger.sh` call site (`skills/{review,build,spec,research,plan,sec}/SKILL.md`, `agents/reviewer.md`); `WORKFLOW.md:86,420`; `tests/jimledger.sh:305-310`.
- callers/consumers traced: `metrics` is consumed only by `SKILL.md:53,129`; **no caller branches on its exit code** (the skill degrades on empty stdout, not rc), so the no-baseline `2→0` change breaks nothing. `start`/`finish`/`event` consumers unaffected.
- verdict: **partial** — functional blast radius fully covered; documentation/test omissions found (Findings 1–4).

### Coverage

- Depth: thorough. Full high-stakes set investigated; no fan-out cap bound (3 of ≤10).
- All findings are documentation/test hygiene; the functional implementation is independently confirmed correct.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 6 (0/5/0/0) |
| Files changed · insertions · deletions | 5 · +216 · −38 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 4374s·266s·34177s·2325s·829s·425s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

*(0 `commits_test` because the build bundled each task's test with its `feat` commit as one green unit — TDD with the test landing in the behavioral commit, not a separate `test:` commit.)*

## Security regressions

- None identified. The two security-relevant additions were adversarially verified: the `commit-review` git invocation is injection- and option-injection-resistant with a fixed-path `--`-guarded commit, and the verdict extraction is shape-validated so a tampered ledger cannot surface arbitrary text or a forged metrics line. The path-scoped commit also cannot sweep an unrelated staged secret.

## Findings

### 1. Stale, mislabeled no-baseline test — plan Task 1 reconciliation skipped

- **Priority:** medium
- **Description:** `tests/jimledger.sh:305-310` `case_jimledger_metrics_no_baseline_exits_2` asserts "metrics with no recorded baseline exits 2," but the new contract is "no baseline + ledger present → exit 0." It passes only incidentally: its `git_fixture` (`:307`) creates no `ledger.md`, so it exercises the absent-ledger `return 2` path (`jimledger.sh:247`), not the no-baseline path its name claims. Plan Task 1 explicitly called to reconcile it.
- **Suggestion:** Rename/re-comment to its real behavior (absent-ledger → exit 2) and add a distinct assertion, so the test names the contract it actually guards.
- **Relates to:** Task 1; AC6/DD6

### 2. `WORKFLOW.md` (declared single source of truth) is stale

- **Priority:** medium
- **Description:** `WORKFLOW.md:86` (Stage Ledger row) and `:420` (`@jim:reviewer` description) omit `review` from the instrumented stages and `:420` still calls the channel "a trusted, content-free metrics channel" — the exact descriptor `ARCHITECTURE.md` was reframed away from. `ARCHITECTURE.md:234-238` declares `WORKFLOW.md` the SoT all components must match, so it should lead, not lag.
- **Suggestion:** Update both `WORKFLOW.md` sites to list `review` as an instrumented, self-committing stage and reframe the channel descriptor to "fixed key set, trusted-origin shape-validated values." (Root cause: the plan's File Manifest omitted `WORKFLOW.md`.)
- **Relates to:** ARCHITECTURE.md SoT convention

### 3. `agents/reviewer.md` is stale

- **Priority:** low
- **Description:** `agents/reviewer.md:45,58` calls metrics a "trusted, content-free channel," lists ledger use as `(metrics, files, diff)`, and its flow omits the review-stage `started`/`finished` instrumentation and the `commit-review` self-commit.
- **Suggestion:** Refresh the reviewer agent body to mention its own ledger instrumentation and the self-commit, and align the channel wording.
- **Relates to:** spec 028 scope

### 4. Residual "content-free" wording in changed/adjacent files

- **Priority:** low
- **Description:** `skills/review/SKILL.md:65` and the script comments `jimledger.sh:194,242` retain "content-free" framing the verdict-surfacing now loosens (still defensible — keys literal, value shape-validated — but out of step with the authoritative `ARCHITECTURE.md` reframe).
- **Suggestion:** Align the wording to "fixed key set, shape-validated values" for consistency.
- **Relates to:** AC4

## Deviations & feedback

- **A spec/plan completeness gap, not a build defect.** The build faithfully implemented its plan's File Manifest (scope discipline held — no creep). The stale `WORKFLOW.md`/`reviewer.md` trace to the plan never scoping them and research never flagging `WORKFLOW.md` as a downstream of the ledger-convention change. Future ledger/convention specs should treat `WORKFLOW.md` (the declared SoT) as a mandatory File-Manifest entry alongside `ARCHITECTURE.md`.
- **The one true execution gap** is Task 1's skipped test reconciliation — a reminder that "reconcile existing test X" sub-steps are easy to miss when the headline is "add new test."
- **Issues #15 (this spec's source) and #16 (absorbed by AC7's metrics-row edit) remain `open`** — both are closeable now that 028 shipped.
- **Dogfood success:** the newly built depth-aware review caught real drift in the very build that produced it (a mislabeled test + a stale source-of-truth), surfaced via the omission-class investigator reaching outside the diff. The instrumentation worked end-to-end — review recorded its own boundaries, verdict, and metrics, and the verdict trajectory is now on the ledger.
