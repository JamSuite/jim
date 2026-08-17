---
spec: "blueprint/017"
type: "refactor"
base_sha: "ff647b4976219d84804d11dd8b4df130a1c45985"
head_sha: "c1d38d662e16b2f902c9d557c04692945f5e6496"
commits: "6"
commits_test: "0"
commits_feat: "2"
commits_fix: "0"
commits_refactor: "1"
files_changed: "6"
insertions: "253"
deletions: "23"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "1950"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "334"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "951"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "1518"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "936"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "371"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "0"
contract_violations: ""
alignment: "aligned"
date: "2026-07-13"
---

# Review: Compute reconcile face-size counters deterministically

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 2 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the spec-045 refactor over the build range `ff647b4..c1d38d6` (6 commits,
6 files, +253/−23): a new deterministic `jimverify.sh faces-aggregate` verb, the
reconcile Step 2a rewrite to copy its output verbatim, the methodology reword, and
9 new tests. All ten acceptance criteria are fully satisfied, the plan was executed
exactly with no scope creep, and every project convention holds. Verdict: **aligned**.
Two low-priority cosmetic/advisory findings, neither blocking.

## Alignment

### vs. Spec acceptance criteria
- AC #1 (single call emits total/max/max-holders) — met (`faces-aggregate`; tested).
- AC #2 (slug-guard before path construction; crafted heading → no file access) — met; independently verified, no bypass (see Investigation).
- AC #3 (same surface emits fan-in holders) — met (`FANIN_GROUP`; tested).
- AC #4 (sorted comma-joined slugs, ties→all, ≤256B, script-emitted) — met (`join_slugs_cap`; shape parity with the ledger consumer confirmed).
- AC #5 (Step 2a copies four verbatim, no LLM sum/max/sort/join) — met.
- AC #6 (all-zero → `faces_max=0`, no `faces_max_group`) — met (tested).
- AC #7 (ledger contract unchanged; consumers insulated) — met (fifteen-key set + validators untouched; consumers provenance-agnostic).
- AC #8 (methodology reworded; contract true for all fifteen) — met.
- AC #9 (new tests) — met (9 cases: sum, max, ties, all-zero, ≤256B cap, crafted-heading, fan-in single/ties/omitted).
- AC #10 (existing tests pass without modification) — met (full suite 572/572; no existing test body changed).

### vs. Plan tasks
- Task 1 (aggregator core + slug guard + tests) — done.
- Task 2 (fan-in holders) — done.
- Task 3 (rewrite Step 2a) — done.
- Task 4 (reword methodology) — done.
- Task 5 (regression gate) — done.
- Scope: exactly the five tasks, no creep. The `ARCHITECTURE.md` refresh (`798a5a9`) is outside the build range — pipeline-owned by the completion gate, not build scope.

### vs. ARCHITECTURE.md
- Bash-vs-Prompt rule — respected (the refactor *moves* counter arithmetic prompt→script, the prescribed direction).
- `jimverify.sh` deterministic-core / TSV-sanitized-output doctrine — respected (integers + slug-validated cells only).
- Bash conventions (`set -uo pipefail`, no third-party deps, no source/eval, in-file reuse) — respected.

## Investigation

Depth `thorough`: 3 read-only investigators over the high-stakes regions, plus the
living-intent sensor's 7 judges (below). Investigator/judge evidence was treated as
untrusted; the verdict is reviewer judgment over it.

### High-stakes regions investigated

#### AC #2 — slug-guard data path (security)
- locations examined: `skills/verify/scripts/jimverify.sh:1166` (guard), `:1167` (path construction), `:1168-1169` (the only in-loop FS ops), `:1129-1135` (`join_slugs_cap`); `tests/jimverify.sh` crafted-heading case.
- callers/consumers traced: `groups_of` (permissive source), `cmd_contracts_check:906` (the mirrored precedent).
- tests checked: `case_jimverify_faces_aggregate_crafted_heading_no_file_access` — a decoy blueprint (5 provides) at the traversal-resolved path with `FACES_TOTAL==2`/`FACES_MAX==2` assertions, a genuine no-file-access proof.
- verdict: satisfied — the `^[a-z0-9][a-z0-9-]*$` guard is strictly before path construction; every FS op is post-guard; no bypass found (traversal impossible through the anchored class; `join_slugs_cap` does no FS and receives only validated slugs).

#### AC #7 — consumer insulation (omission class)
- locations examined: `skills/review/scripts/jimledger.sh:613-616` (15-key whitelist), `:628-633` (`valid_sluglist`); `skills/partition/scripts/jimpartition.sh:1150` (`faces_max` reader); `skills/conf/scripts/jimconf.sh:97`.
- callers/consumers traced: all four counters' downstream readers.
- tests checked: `tests/jimledger.sh:1320-1361` (slug-list accept/reject parity).
- verdict: satisfied — emitted value shapes match the consumer validators exactly; the 15-key set is unchanged and correctly untouched; `cmd_health_eval`/`jimconf` read the counter provenance-agnostically. No downstream file left stale.

#### AC #5 / AC #8 — doc↔code consistency
- locations examined: `skills/blueprint/SKILL.md:412-417` (Step 2a call + key mapping), `skills/blueprint/references/reconcile-methodology.md:258-294` (§ Outcome counters).
- verdict: satisfied — correct arg order (`<map-path> <specs-root>`), verbatim copy with correct key→counter mapping, arithmetic explicitly forbidden; no stale "counted at Step 2a" framing remains; "every counter script-emitted" reads true for all fifteen.

### Coverage

- Depth: thorough; review_model: inherit (session model).
- Full high-stakes set investigated — 3 investigators + 7 living-intent judges, no fan-out cap bind. No instrumentation gaps.

## Living intent

The `jim` group has a `000-blueprint`, so the sensor ran (`--from-review`), after the
alignment verdict was fixed — it never sets that verdict.

**Sensed:** 34 invariants · **holds:** 8 · **violations:** 0 (in-change 0 · pre-existing 0 · unlocalized 0) · **skipped:** 25 · **failed/unconfigured:** 1

### Violations

- None — every checked invariant holds.

### Coverage

- appetite in force: low (judge everything at/above `low`); no per-group override.
- Whole-group floor ran (territory declared, not `UNSCOPED`); the one pattern invariant `no-third-party-deps` holds. No changed source/test file is a territory stray — the change introduces no conformance violation.
- judges: change-selected, all 7 within the cap of 10 — `allowed-tools-exact`, `no-source-eval`, `untrusted-content`, `relpath-validation` (all critical), `reconcile-durable-record`, `reconcile-declared-data`, `sigil-discipline` (high). All **hold**.
- skipped by scope: 25 (the change did not touch them — e.g. `ref-validation` is git-SHA/ref specific, `verify-no-verdict` is the `/jim:verify` artifact, `script-preamble` unchanged) · skipped by appetite: 0.
- registry: `skill-budget` — unconfigured (`verify_command_skill-line-budget` empty; executed nothing). No contract-edge phase — the map's graph names no group `jim` provides to (single-group), so it was correctly not run.
- Pre-existing observation (not a violation, out of scope for 045): the `reconcile-durable-record` judge noted the nothing-to-reconcile short-circuit path leaves the `faces=`/`faces_max=` value type underspecified — the docs call them "always non-negative integers" while spec 045's own Out-of-Scope note says the four counters "ride as `na`", yet `jimledger` types `faces`/`faces_max` as int (not int-or-na). This originates in spec 044 and is untouched here; surfaced as a low-priority follow-on.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 6 (0/2/0/1) |
| Files changed · insertions · deletions | 6 · +253 · −23 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 1950s·334s·951s·1518s·936s·371s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec, research, security, plan, ledger |

## Security regressions

- None identified. The change is net security-positive: it removes an LLM string-assembly step over shape-validated ledger values, slug-guards untrusted map tokens before path construction, never sources/evals file content, and emits only integers + validated slugs (no face `text`/`params` reaches a counter, so no secret can be persisted). Independently confirmed by the `no-source-eval`, `untrusted-content`, and `relpath-validation` judges.

## Findings

### 1. Stale line-number citation in the new verb's header comment

- **Priority:** low
- **Description:** The `cmd_faces_aggregate` header comment cites the slug-guard precedent as `cmd_contracts_check:905`; after this build's one-line `usage()` insertion shifted the file, the actual guard is now at `jimverify.sh:906`. The convention reference is correct; only the line number drifted by one.
- **Suggestion:** Drop the line number (cite `cmd_contracts_check` by name) or update to `:906`, to keep the comment accurate. Line-number citations in comments are inherently fragile.
- **Relates to:** AC #2

### 2. Holder attribution has no per-element length pre-check

- **Priority:** low
- **Description:** `join_slugs_cap` caps the joined value at 256 bytes on element boundaries. A single group slug longer than 256 bytes (with `FACES_MAX>0`) would make the first candidate overflow, yielding an empty join and silently omitting the `FACES_MAX_GROUP` attribution. This is impossible in practice (group slugs are short nouns) and is safe by construction — no invalid value is ever emitted, and the ledger consumer accepts the absence.
- **Suggestion:** No action required; noted for completeness. If ever hardened, emit a truncated single-element form rather than omitting the key.
- **Relates to:** AC #4

## Deviations & feedback

- Zero plan deviations. The build executed the five tasks exactly and stayed inside scope.
- `commits_test=0` is expected, not a gap: per jim's "green on its own" convention, each new-behavior task bundled its tests into the `feat`/`refactor` commit rather than a separate red `test:` commit — every commit is green in isolation.
- The security-critical AC (#2) was scoped as an External Constraint at spec time, baked into the plan (DD #4 + Task 1), and independently re-verified here with no bypass — the spec→plan→build→review chain closed the loop on it cleanly.
