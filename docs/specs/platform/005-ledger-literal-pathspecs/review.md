---
spec: "platform/005"
type: "bug"
base_sha: "8109b5ae8ddb9b22f1f44b9ed8b0942713ce96cb"
head_sha: "746710adff9427b2a6c5048838159b8d48959dec"
commits: "7"
commits_test: "1"
commits_feat: "0"
commits_fix: "1"
commits_refactor: "0"
files_changed: "9"
insertions: "51"
deletions: "19"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "1234"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "767"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "592"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "798"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "1561"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "465"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "1"
contract_violations: ""
alignment: "minor-drift"
date: "2026-07-26"
---

# Review: Neutralize pathspec magic in the ledger git-mv primitives

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 1 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the `platform/005` build over `8109b5a..746710a`. The code fix is
correct, complete, and in-scope for the two git-mv primitives (one investigator
+ two judges concur). The single drift is **not in the code but in the artifact
Task 4 produced**: the restored `relpath-validation` blueprint invariant
over-claims — its clause 2 asserts *every* untrusted path (and names
`commit-map`'s arguments) is handed to git under literal-pathspec semantics, but
only the two git-mv primitives carry `--literal-pathspecs`; the `commit-*` verbs
do not. The living-intent sensor independently graded `relpath-validation`
**violated (in-change)**.

## Alignment

### vs. Spec acceptance criteria
- AC #1 (magic treated literally at the tracked-check) — **met**: `:(glob)…` / `:/…` paths refuse at the tracked-check, proven by two regression cases.
- AC #2 (every path-receiving git call *in both primitives*) — **met**: all four calls neutralized (`jimledger.sh:307,313,608,617`).
- AC #3 (legit renames/moves unregressed) — **met**: full suite 707/707; existing happy-path cases green.
- AC #4 (invariant restored, reworded, project-wide, dropped from note) — **drift**: the row was restored and the note updated, but the reworded text over-claims coverage the code does not provide (see Findings 1). The AC was satisfied *mechanically*; the wording chosen is inaccurate.
- AC #5 (regression test) — **met**: two cases, long-form + short-form magic, both primitives.

### vs. Plan tasks
- Tasks 1–4 — **done**, no scope creep. The diff is exactly the plan's file manifest plus the expected ledger/map/arch administrative changes.

### vs. ARCHITECTURE.md
- Bash+POSIX, no third-party deps, `--` guards, per-call scoping — **respected**. Code comments carry no artifact IDs (script rule); the arch note was refreshed via `/jim:arch`.

## Investigation

### High-stakes regions investigated

#### Pathspec neutralization completeness (`cmd_rename_tracked` / `cmd_move_spec_dir`)
- locations examined: `skills/ledger/scripts/jimledger.sh:272-316`, `:564-620`, `:205-236`, `:331-376`, `:393-446`, `:467-551`; `skills/file/scripts/jimfile.sh:227-244`
- callers/consumers traced: invoked by `/jim:partition` orchestrator; `jimpartition.sh` does not call these (git primitives live in ledger)
- tests checked: `tests/jimledger.sh:1231`, `:1495` (the two new cases)
- verdict: **partial/divergence** — within the two primitives, all four path→git sinks are neutralized, flag placement is correct (top-level option before the subcommand), guards/messages are otherwise unchanged, and there is no process-wide neutralization (Q1–Q4 hold). But the sibling `commit-*` verbs hand config/caller-supplied paths to `git add`/`git commit`/`git diff --cached` pathspecs without `--literal-pathspecs` (`:235-236`, `:367/369/375`, `:438/440/443`, `:537/539/543-547`) — the `git add` calls are mostly defused by a preceding `[[ -e "$p" ]]` guard, the `git commit`/`git diff --cached` pathspecs are genuinely exposed.

### Coverage
- Depth: thorough; one investigator (security region) + three change-selected judges. Full high-stakes set investigated; no cap bound.

## Living intent

**Sensed:** 8 invariants · **holds:** 3 · **violations:** 1 (in-change 1 · pre-existing 0 · unlocalized 0) · **skipped:** 4 · **failed/unconfigured:** 0

### Violations
- `relpath-validation` — critical · violated · in-change · `skills/ledger/scripts/jimledger.sh:235`

  <untrusted-content id="relpath-validation">
  Clause 1 (valid-relpath) holds everywhere. Clause 2 (literal-pathspec) holds
  for the two git-mv primitives (:307,:313,:608,:617) but not for `commit-map`
  (:235-236, config-derived `$map`/`$ledger`) or the `commit-rename`/`split`/
  `merge` add/commit/diff pathspecs — all named or implied by the invariant's
  "every untrusted path … `commit-map`'s config-derived arguments" wording.
  </untrusted-content>

  This is an **in-change** violation: the invariant row itself changed this build
  (Task 4), so it routes to the blueprint-update fork, not the issue batch.

### Coverage
- appetite in force: low (judge everything within change-selection).
- Whole-group floor ran (territory declared; no strays — the 525 set-difference files are scaffolding/other-group, bucketed).
- judges: change-selected (`relpath-validation`, `ledger-commit-discipline`, `tests-under-tests`), all within cap.
- skipped by scope: 4 (`no-source-eval`, `bash-source-relative`, `ref-validation`, `blueprint-slot-reserved` — the change did not touch them) · skipped by appetite: 0.
- registry: 0 configured. No engine failure.

<!-- Contract-edge phase: platform is a provider (jimledger-cli), but the change
     touched only internal git-call flags — no jimledger-cli provides-face
     guarantee (verb surface, arg contract, legitimate-input behavior) changed —
     so the affected-edges set is empty and the phase added nothing.
     contract_violations left empty. -->

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 7 (1/0/1/0) |
| Files changed · insertions · deletions | 9 · +51 · -19 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 1234s·767s·592s·798s·1561s·465s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. The change is a security *improvement* (it closes a pathspec-injection sink); it introduces no new secret handling, weakened boundary, or injection surface. It also incidentally stops git's raw `fatal:` line from surfacing on magic inputs.

## Findings

### 1. Restored `relpath-validation` invariant over-claims literal-pathspec coverage

- **Priority:** medium
- **Description:** The invariant restored in Task 4 states every untrusted path — and explicitly names `commit-map`'s config-derived arguments — is handed to git under literal-pathspec semantics. The code applies `--literal-pathspecs` only to the two git-mv primitives (matching spec 005's deliberate scope; research.md guardrail: "the two primitives' untrusted-path git calls **only**"). So the blueprint asserts a guarantee the code does not provide for `commit-map`, `commit-rename`, `commit-split`, `commit-merge` — confirmed by an independent judge (`violated`) and investigator.
- **Suggestion:** Resolve via the blueprint-update fork (Step 10). Recommended: **fold-intent** — narrow clause 2 to scope literal-pathspec neutralization to the git-mv primitives' path→git sinks (which is also what the pre-restoration ancestor invariant claimed: neutralization of *tracked-file filtering*, not the commit verbs). Separately, **file a follow-on issue** for the `commit-*` verbs' `git add`/`git commit`/`git diff --cached` pathspec exposure (a real, lower-severity hardening gap that #107 does not cover — #107 tracks only `jimpartition`). Alternative: **fix-code** — extend `--literal-pathspecs` to the `commit-*` sites, making the broad wording true (out of spec 005's declared scope; a separate hardening decision).
- **Relates to:** AC #4; the `relpath-validation` blueprint invariant.

## Deviations & feedback

- The drift originated in the blueprint-restoration wording (Task 4), not the code — a reminder that a reworded invariant is itself a design artifact whose breadth must match the code, and that the living-intent sensor is the right net for catching it (it graded the exact over-claim `violated` in-change).
- Two independent read paths (a review investigator and a `/jim:verify` judge) converged on the same `commit-*` gap — the fix's own rationale ("valid-relpath does not neutralize pathspec magic") generalizes past the two primitives it scoped.
