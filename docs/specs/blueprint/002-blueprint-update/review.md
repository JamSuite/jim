---
spec: "blueprint/002"
type: "feature"
base_sha: "b6c413c9405bfa2dcae45ff758143db28a1a6f01"
head_sha: "9850c4c84ee8710afc2607d04fb6667381551d38"
commits: "8"
commits_test: "0"
commits_feat: "6"
commits_fix: "0"
commits_refactor: "0"
files_changed: "9"
insertions: "315"
deletions: "24"
spec_runs: "2"
spec_interruptions: "0"
spec_duration_seconds: "44293"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "1405"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "38700"
sec_runs: "3"
sec_interruptions: "0"
sec_duration_seconds: "39255"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "2826"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "366"
artifacts_present: "spec,research,security,plan,ledger,review"
plan_deviations: "2"
security_regressions: "0"
alignment: "minor-drift"
date: "2026-07-01"
---

# Review: Blueprint update

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 6 · **Plan deviations:** 2 · **Security regressions:** 0

Reviewed the spec-030 build over `b6c413c..9850c4c` (8 commits, 9 files, +315/-24)
against spec, plan, and ARCHITECTURE.md. Depth-aware thorough review with a 4-way
`investigator` fan-out over the two security-critical git verbs and the two prompt
surfaces. All 11 ACs are functionally satisfied and both security-critical regions
(the `diff-range` ref-injection foreclosure and `commit-blueprint` path-scoping)
are sound. The drift is one real instrumentation bug on the absent-blueprint edge
path plus a handful of documentation / test-coverage nits — hence minor-drift, not
aligned.

## Alignment

### vs. Spec acceptance criteria
- AC1–AC11 — **met.** Targeted diff-driven core with two adapters, review + ad-hoc
  triggers, `auto_blueprint` / `require_blueprint` gating, single-group targeting,
  absent-blueprint generate fallthrough, commit via `commit-blueprint`,
  secret-scrub, and untrusted-evidence handling all verified against the skills and
  scripts (evidence under ## Investigation).
- AC10 caveat — the *update* commit path is correct; the absent-blueprint fallthrough
  legitimately does not commit (generate leaves the commit to the developer, and
  review Step 10 accepts a fresh generate as gate-completing). Not an AC violation,
  but see Finding 1 for the ledger side-effect on that path.

### vs. Plan tasks
- Tasks 1–7 — **all done**, TDD, atomically committed; the 9 changed files map 1:1
  to the tasks + plan/ledger tracking. No scope creep beyond the plan.
- **Deviation:** `cmd_diff_range` runs `git diff --function-context "$base..$head" --`
  (validated-SHA range form) rather than the `--end-of-options <base> <head> --`
  two-arg form the plan's Interface Contract sketched — equivalent security (Finding 4).
- **Deviation:** the `blueprint` ledger-stage pairing is incomplete on the
  absent-blueprint path (Finding 1) — a gap vs DD4's auditability intent.

### vs. ARCHITECTURE.md
- Conventions **respected**: `require_*` bare-name config dispatch; path-scoped ledger
  commits (`--` guard, never `git add -A`); single `is_valid_id` boundary before git
  interpolation; `allowed-tools` naming exact script paths + tools (no bare wildcard);
  `set -uo pipefail` / `LC_ALL=C`; SET/IF sentinel gate vocabulary; skill→skill via the
  Skill tool. The `--from-review` / `--since` adapters follow the `--depth` flag idiom.

## Investigation

### High-stakes regions investigated

#### diff-range ref-injection foreclosure (security Finding 5)
- locations examined: `skills/review/scripts/jimledger.sh:85-100` (`valid_git_ref`), `:102-114` (`resolve_ref`), `:241-254` (`cmd_diff_range`); `skills/file/scripts/jimfile.sh` (`is_valid_id`)
- callers/consumers traced: `skills/blueprint/SKILL.md:127` (`--since <ref>` → `diff-range <ref> HEAD`); no path reaches git without `valid_git_ref` first
- tests checked: `tests/jimledger.sh` diff-range cases (accepts `feat/x`; `--output=$marker` proves rc1 + no file written; bad-ref rejection loop)
- verdict: **satisfied** — no exploitable bypass; positive allowlist `^[A-Za-z0-9._/-]+$` + leading-`-` / `..` / edge-`/` rejects, `--end-of-options` belt, SHA re-validation. Legit `/`-refs accepted; crafted refs cannot inject an option or write a file.

#### commit-blueprint path-scoping (security Finding 2 / AC #9)
- locations examined: `skills/review/scripts/jimledger.sh:150-163` (`cmd_commit_blueprint`) vs `:132-148` (`cmd_commit_review`)
- tests checked: `tests/jimledger.sh` commit-blueprint scoped + non-repo cases
- verdict: **satisfied** — doubly path-scoped (`--`-guarded literal `spec.md ledger.md` on both add and commit), no `git add -A`; the `seed.txt not swept / still dirty` test genuinely exercises the `git add -A` regression vector.

#### blueprint update-mode ACs (AC1/2/3/8/9/10/11)
- locations examined: `skills/blueprint/SKILL.md` Update mode §U1–U4 (:101-165), argument routing (:24-34), `allowed-tools` (:14)
- verdict: **partial** — all 7 ACs met, but the absent-blueprint fallthrough records `blueprint started` (U1) *before* the absence check (U2) and routes a successful generate to Step 5, which records no `blueprint finished` → **Finding 1**.

#### review Step 10 + require_blueprint (AC1/2/4/5/6/7)
- locations examined: `skills/review/SKILL.md:184-201` (Step 10/11), `:13` (`allowed-tools`); `skills/conf/scripts/jimconf.sh:42,62,116-124`; `tests/jimconf.sh` (dedicated + 4 aggregate cases)
- verdict: **satisfied** — all 6 ACs + sub-questions confirmed (`Skill(jim:blueprint)` present; group from `spec.md`; `require_blueprint` in KEYS+`default_for`+`resolve()`; test count `"34"` correct). Two doc nits → Findings 2, 3.

### Coverage
- Depth: thorough; review_model: inherit (investigators ran on the session model). Full high-stakes set investigated — fan-out of 4, under the cap of 10. No region left un-investigated.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 8 (0/6/0/0) |
| Files changed · insertions · deletions | 9 · +315 · -24 |
| Stage runs (spec·research·plan·sec·build·review) | 2·1·1·3·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 44293s·1405s·38700s·39255s·2826s·366s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger,review |

*(Durations are wall-clock between each stage's ledger `started`/`finished`, so they
include inter-turn gaps across the session — not active-work time. The `blueprint`
stage is uninstrumented for this build: the update runs at Step 10, after this file.)*

## Security regressions

- **None identified.** The two new git surfaces were the review's focus and both are sound: `diff-range` forecloses option/metacharacter injection (validated-SHA-only interpolation; `--output=` injection proven inert), and `commit-blueprint` is strictly path-scoped. No secrets in the diff; the untrusted-evidence trust boundary (AC #9) is carried into the update mode.

## Findings

### 1. Absent-blueprint fallthrough leaves an unmatched `blueprint started` event
- **Priority:** medium
- **Description:** In `blueprint/SKILL.md`, U1 records `blueprint started` unconditionally *before* the U2 absent-blueprint check. On the first-time path (no blueprint yet), U2 routes a successful generate to Step 5 — not U4 — so `blueprint finished` is never recorded. `phase_event_metrics` then computes `interruptions = started − finished`, mis-recording a legitimately-completed first generate as `blueprint_interruptions=1`, and muddying the `require_blueprint` "interrupted update holds the gate" signal.
- **Suggestion:** In U2, record `blueprint finished` (and stop) after the Step-5 generate write, **or** defer the `blueprint started` event until *after* the absence check.
- **Relates to:** AC8/AC10, plan DD4; `skills/blueprint/SKILL.md` U1–U2

### 2. Adapter arg-order stated inconsistently across the two skills
- **Priority:** low
- **Description:** `/jim:review` Step 10 invokes `"<group> --from-review <spec-dir>"` (group-first), while `/jim:blueprint`'s `argument-hint` / routing table document flag-first `--from-review <spec-dir> <group>`. Both parse correctly (the flag carries its own value, so stripping is position-independent), but the two skills *state* the order differently.
- **Suggestion:** Align the documented order (pick one and make both skills match).
- **Relates to:** plan DD1; `review/SKILL.md:192` vs `blueprint/SKILL.md:13,33`

### 3. Step 10 cross-reference imprecision ("loaded in Step 1")
- **Priority:** low
- **Description:** Step 10 says the group was "loaded in Step 1", but Step 1 only calls out reading the ACs and `type`. `spec.md` is read whole (so `group` is available and is used again in Step 8), but the parenthetical is imprecise about where `group` is named.
- **Suggestion:** Adjust the parenthetical, or name `group` explicitly in Step 1.
- **Relates to:** `review/SKILL.md:186`

### 4. `diff-range` invocation deviates from the plan's Interface Contract sketch
- **Priority:** low
- **Description:** `cmd_diff_range` uses the range form `git diff --function-context "$base..$head" --` rather than the `--end-of-options <base> <head> --` two-arg form the plan sketched. Security is identical — both refs are already validated SHAs — so this is a wording/contract deviation, not a gap.
- **Suggestion:** None required; optionally reconcile the plan text with the (equally safe) implementation.
- **Relates to:** plan Interface Contract; `jimledger.sh:253`

### 5. `diff-range` injection tests sample, but don't exhaustively cover, the danger set
- **Priority:** low
- **Description:** The rejection tests exercise `--output=`, `;`, space, `~`, `^`, `:`, `..`, `/leading` and prove the `--output=` no-file-write foreclosure — but do not individually assert glob metacharacters (`* ? [ ]`), backtick / command-substitution-shaped refs, a trailing `/`, or a newline-bearing ref. All are foreclosed uniformly by the allowlist, so risk is low; `valid_git_ref` is the sole security boundary, so a belt test would harden the guard against future edits.
- **Suggestion:** Add a case for a command-substitution-shaped ref (e.g. `` a`touch x` ``) and a trailing-`/` ref.
- **Relates to:** `tests/jimledger.sh` diff-range cases

### 6. TDD commits bundled test+impl (`commits_test=0`)
- **Priority:** low
- **Description:** The build committed test+implementation together in green `feat:` commits rather than separate `test:` (Red) / `feat:` (Green) commits, so the metrics show `commits_test=0`. This is a defensible "atomic, green-on-its-own" reading (CLAUDE.md) but deviates from the build skill's suggested `test:`/`feat:` split, and it makes the Red step invisible in git history.
- **Suggestion:** Process note only — no code change. Decide the intended convention for jim's self-build.
- **Relates to:** commit discipline; build skill Step 4

## Deviations & feedback

- **The iterative chain worked as designed** — and the ledger proves it: `spec_runs=2`
  (re-opened mid-plan for the ad-hoc scope expansion) and `sec_runs=3` (spec-phase,
  plan-phase, and a third pass on the new ad-hoc surface). That third `/jim:sec` is
  exactly what caught security Finding 5 (the `is_valid_id`-wrong-for-git-refs flaw)
  before it shipped — a strong signal for keeping the "re-sec after scope change" habit.
- **Independent review earned its keep**: the builder's own confidence notwithstanding,
  the fan-out surfaced a real instrumentation bug (Finding 1) the builder missed.
- Stage durations are wall-clock (inter-turn gaps included); treat them as latency, not effort.
