---
spec: "platform/010"
type: "bug"
base_sha: "152dc73bcb82193128d93eda01b200eb5585ae04"
head_sha: "addc0234788bd90ebe22dbb6b7a98668ce81ac46"
commits: "6"
commits_test: "2"
commits_feat: "0"
commits_fix: "1"
commits_refactor: "0"
files_changed: "5"
insertions: "151"
deletions: "15"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "35867"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "105"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "900"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "35053"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "1863"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "185"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "1"
contract_violations: ""
alignment: "aligned"
date: "2026-07-28"
---

# Review: Allocator honors the configured issue-id prefix

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 0 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the build range `152dc73..addc023` (a fully-instrumented bug fix). The
only source change is `alloc_durable_issue_id` in `jimalloc.sh` plus its two
caller updates; every acceptance criterion is satisfied with passing test
coverage, no scope crept in, conventions hold, and the config→durable-id
injection boundary is intact. The living-intent sensor found every checked
platform invariant holding; its one flagged territory stray (`tests/jimalloc.sh`)
is a pre-existing map-declaration gap already tracked as issues #120/#125, not
drift this build introduced.

## Alignment

### vs. Spec acceptance criteria
- AC 1 (honor the configured scheme; ordinal schemes use the coordinated num) — **met**: `case_jimalloc_durable_id_honors_sequential_prefix` asserts `0001-alpha-bug`; `project`/`timestamp` cases confirm num-independent schemes.
- AC 2 (degrade to date-slug where non-derivable; never error/malformed) — **met**: provisional `sequential` and `{seq:04}` cases fall back to date-slug; crafted `project` degrades.
- AC 3 (stays coordinated + consistent; disambiguation; sequential prefix == ordinal) — **met**: disambiguation loop unchanged (collision case green); sequential case asserts prefix == coordinated ordinal.
- AC 4 (default `date` byte-for-byte unchanged; 007 frozen contract) — **met**: `date_default_unchanged` asserts both the durable id and the registry record are identical.
- AC 5 (revalidate prefix + composed id through the id boundary) — **met**: DD4's `alloc_valid_token "$base"` gate (`jimalloc.sh:329`); crafted-project case; judge-confirmed (see Living intent).
- AC 6 (regression test covers the reported scenario) — **met**: the reproduction case + provisional coverage.

### vs. Plan tasks
- Task 1 (Reproduce) — **done**: reproduction case, confirmed red on unfixed code.
- Task 2 (Fix per DD1–DD4; thread num) — **done**: exactly the three-function change.
- Task 3 (Regression coverage) — **done**: sequential/`{seq}`-template fallback, project/timestamp, date-default, crafted-project.
- Task 4 (Full-suite gate) — **done**: jimalloc 87/87, issues 112/112.
- No scope creep — the diff is precisely the planned change.

### vs. ARCHITECTURE.md
- Bash conventions (`set -uo pipefail`, `export LC_ALL=C`) — **respected** (unchanged preamble).
- No third-party deps — **respected** (floor `no-third-party-deps` holds).
- Registry/config untrusted, revalidate before use — **respected**: config-derived prefix passes `prefix-from`'s `is_valid_id` and the composed-base boundary; stderr sunk, never interpolated.
- `validator-lockstep` (byte-identical `is_valid_id`) — **respected**: reuses `alloc_valid_token`, does not alter the boundary.
- No spec IDs in code comments — **respected**: the new comment block describes behavior/rationale, no AC/Finding/spec references.

## Investigation

### High-stakes regions investigated

#### `alloc_durable_issue_id` — changed signature (added `num`) + config→id boundary
- locations examined: `skills/file/scripts/jimalloc.sh:314-345` (function), `:319/:323/:325-326/:329` (scheme read, ordinal-bearing guard, prefix-from call, boundary gate).
- callers/consumers traced: `alloc_build_issue` `:902` (passes `num`), `alloc_provisional_issue` `:965` (passes `""`), test `case_jimalloc_durable_issue_id_collision` `tests/jimalloc.sh:249/252/256` (one-arg, backward-compatible via `${2:-}`, still green). Every consumer of the changed signature accounted for — no un-updated caller (the omission class).
- tests checked: `tests/jimalloc.sh` — reproduction + 7 regression cases across schemes and both real/provisional paths.
- verdict: **satisfied** — the config value is fenced by `prefix-from`'s internal `is_valid_id` and the composed-base `alloc_valid_token` gate; the durable id reaches git only as blob content on stdin, never as an argument.

### Coverage

- Depth: thorough (reviewer-direct spine + full consumer trace + boundary trace). No separate investigator fan-out for the alignment pass — a 20-line single-function change with all three consumers traced inline is fully holdable; the living-intent sensor's 3 change-selected judges provided the independent deep read on the security-relevant dimensions.

## Living intent

**Sensed:** 9 invariants · **holds:** 4 · **violations:** 1 (in-change 1 · pre-existing 0 · unlocalized 0) · **skipped:** 5 · **failed/unconfigured:** 0

### Violations
- `TERRITORY` (tests/jimalloc.sh) — high · territory-conformance stray · channel in-change · `tests/jimalloc.sh`. Platform-owned test code outside the group's declared territory (`skills/conf, skills/file, skills/ledger, skills/meta-test` + `tests/jimconf.sh`/`jimfile.sh`/`jimledger.sh`/`metatest.sh`). This is a **pre-existing map-declaration gap already tracked as issues #120/#125** — the build only edited the file; it did not create the gap. Not re-filed (Resolution filter: already tracked).
- Blueprint invariants: **None — every checked invariant holds.** `no-third-party-deps` (floor), `ref-validation`, `no-source-eval`, `bash-source-relative` all hold; the config→durable-id boundary is judge-confirmed at `jimalloc.sh:329`.

### Coverage
- appetite in force: low (no per-group override).
- Whole-group floor ran, territory-scoped (no `UNSCOPED`).
- judges: change-selected (`ref-validation`, `no-source-eval`, `bash-source-relative`), all within cap (3 of 10).
- skipped by scope: 5 (`script-preamble`, `relpath-validation`, `ledger-commit-discipline`, `blueprint-slot-reserved`, `tests-under-tests` — the change touches none) · skipped by appetite: 0.
- registry: 0 configured. Contract-edge phase did not run — the map names `platform` as a provider only for the `jimconf`/`jimfile`/`jimledger`/`testlib` interfaces, none of which is `jimalloc.sh`, so no provides-side code was touched.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 6 (2/0/1/0) |
| Files changed · insertions · deletions | 5 · +151 · -15 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 35867s·105s·900s·35053s·1863s·185s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. The change adds one untrusted input path (config `issue_id_prefix` → durable id), fully fenced: `prefix-from`'s internal `is_valid_id`, the composed-base `alloc_valid_token` gate (`jimalloc.sh:329`), `prefix-from` stderr sunk (`2>/dev/null`, never interpolated), no `eval`/`source`, and the durable id reaches git only as stdin blob content — all judge-confirmed.

## Findings

No findings — the build aligns with spec, plan, and architecture.

## Deviations & feedback

- Clean single-pass build: no interruptions across any stage, no re-plan. The plan's malformed-verify lesson (carried from `issue/010`) paid off — task Verify commands (`! bash tests/jimalloc.sh` for the red gate, `grep FILE && suite` for coverage) all fired correctly.
- The build surfaced a genuinely separate infrastructure finding, out of scope for this spec: jim's coordination remote (`origin`) is unreachable inside the mvm agent sandbox, and with `id_coordination_unreachable = fail` both coordinated issue-filing and registry realign are host-only. This blocked the end-of-build candidate batch (deferred to a host session) but did not affect the code under review. Worth deciding whether jim's agent profile should run `provisional` mode.
