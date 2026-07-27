---
spec: "platform/008"
type: "feature"
base_sha: "bed03177999dcf6cbf432cc0b56bdd948e036168"
head_sha: "baa76830d6570eef5a36c0444eded2ecb80840d5"
commits: "10"
commits_test: "0"
commits_feat: "7"
commits_fix: "0"
commits_refactor: "0"
files_changed: "5"
insertions: "683"
deletions: "9"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "7068"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "5115"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "480"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "1615"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "1660"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "472"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "1"
contract_violations: "0"
alignment: "minor-drift"
date: "2026-07-27"
---

<!-- Findings record references, counts, and locations — no raw secrets. -->

# Review: Registry seed from existing artifacts

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 3 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the `platform/008` build (`bed0317..baa7683`, 5 files, +683/−9) — a new
one-time `seed` verb on `jimalloc.sh` that reconstructs the id-coordination
registry from the repo's existing spec directories and issue files — against 10
spec ACs, 7 plan tasks, and ARCHITECTURE.md. Three read-only investigators
covered the injection boundary, the CAS landing + atomicity, and next-id parity +
immutability; a change-scoped living-intent sensor judged three platform
invariants. All 10 ACs are functionally satisfied for real inputs and the build
is clean (767/767 tests, TDD Red→Green per task, zero interruptions). The verdict
is **minor-drift** on one confirmed reserved-slot edge in `alloc_seed_derive_specs`
(a directory whose ordinal parses to zero but is not literally `000`), plus two
low advisories on the landing path's parity with the allocation CAS.

## Alignment

### vs. Spec acceptance criteria
- AC 1 (derive spec/group/issue allocate records in the frozen grammar) — met. Specs from directory names, issues from frontmatter, into the per-kind logs.
- **AC 2 / AC 3 (next-id parity for materialized groups; reserved slot not seeded) — minor-drift.** Parity holds for live groups (investigator-confirmed: seeded high-water == `jimfile.sh next-id` for a clean group; gap stays a gap). But the reserved-slot skip is a literal `"000"` match, so a directory parsing to ordinal 0 without the literal prefix (`0-foo`/`00-foo`) bypasses it and emits a `<group>/000` record — a reserved-coordinate breach. Bounded: id 0 never raises the next-id max, so parity/no-reissue still hold. See Finding 1.
- AC 4 (single durable commit, all-or-none) — met. `alloc_seed_commit` sets both logs in one two-blob tree (or one blob), preserving siblings, via plumbing; `rev-list --count == 1` fixture confirms.
- AC 5 (refuse a kind whose log is non-empty; no-op re-run) — met. Per-kind emptiness gates writing; a populated kind is skipped-and-reported; re-run is a byte-stable no-op failure.
- AC 6 (conflict halts, names offenders, no records) — met. Dup ordinal, dup durable id, unparseable spec dir, and absent/unparseable issue num/id all halt with named offenders and zero records.
- AC 7 (never mutates artifacts) — met. Plumbing-only; the docs tree and worktree status are byte-identical after `--apply` (fixture-verified).
- AC 8 (same guarantees as an allocation; no weaker path) — met on the enumerated guarantees (durable-before-return, coordination point, reachability tier, unreachable hard-fail), with two low parity notes: the landing omits the allocation path's in-loop erosion re-check (Finding 2) and re-implements the CAS ref-update inline (Finding 3).
- AC 9 (revalidate every tree/artifact token before git/ref/fs use) — met. Judge-confirmed: every id/slug/group/durable-id token passes the single `is_valid_id` boundary, ordinals get a numeric-class check, the branch passes `check-ref-format`; record content reaches git only as blob stdin, never as an argument.
- AC 10 (bash conventions; parse as data; no third-party deps) — met. `no-third-party-deps` floor holds; judge-confirmed no `source`/`eval`; grep/sed/awk only.

### vs. Plan tasks
- Tasks 1–7 — all done, each via Red→Green with a `**Verify:**` gate. No scope creep; the file manifest (`jimalloc.sh` + `tests/jimalloc.sh`) held, plus the pipeline-owned `docs(arch)` refresh.
- Implementation note (not a deviation): slugs validate through `alloc_valid_token` (the single `is_valid_id` boundary) rather than a separate `is_valid_slug` copy — plan DD 6 listed both; the single-boundary route better honors the no-duplicate-validator constitution.

### vs. ARCHITECTURE.md
- Bash-vs-Prompt placement, `set -uo pipefail`/`LC_ALL=C`/`GIT_TERMINAL_PROMPT=0` (inherited), BASH_SOURCE-relative composition, the single id boundary, plumbing-only git, parse-as-data — all respected. The completion-gate `/jim:arch` refresh documented the new verb.

## Investigation

### High-stakes regions investigated

#### AC 9 / AC 10 — injection & source/eval boundary
- locations examined: `skills/file/scripts/jimalloc.sh:329-456` (derive/validate), `:888-897` (tree-root resolve), `:965-991` (commit), `:1021-1081` (land); `jimfile.sh:191-210` (`is_valid_id`)
- verdict: satisfied — every derived token validated before a record or git use; ordinals numeric-class-checked; branch `check-ref-format`-gated; no `source`/`eval`; record content flows via stdin, never a git argument.

#### AC 4 / AC 5 / AC 8 — CAS landing, atomicity, empty-precondition
- locations examined: `skills/file/scripts/jimalloc.sh:965-991`, `:1021-1081`; cross-referenced `alloc_cas_append`/`alloc_build_commit` `:659-783`
- verdict: satisfied — one commit lands both/one blobs preserving siblings; the two awk filters drop only the rewritten logfile; empty-check re-read from each attempt's fetched tip (TOCTOU closed); local update-ref old-value + origin push non-ff CAS with bounded retry and unreachable hard-fail. Two parity notes (Findings 2, 3).

#### AC 2 / AC 3 / AC 7 — parity, reserved slot, immutability
- locations examined: `skills/file/scripts/jimalloc.sh:343-404`, `:248-291`; `jimfile.sh:295-361`
- verdict: partial — parity and immutability hold; the reserved-slot recognition is narrower than the invariant (Finding 1).

### Coverage
- Depth: thorough; review_model: inherit (session model).
- Full high-stakes set investigated (3 investigators, well under the cap of 10). Lower-risk ACs assessed from the diff spine and the 22 new passing tests.

## Living intent

**Sensed:** 9 invariants · **holds:** 3 · **violations:** 1 (in-change 1 · pre-existing 0 · unlocalized 0) · **skipped:** 5 · **failed/unconfigured:** 0

The platform `000-blueprint` sensor ran in `--from-review` scoped mode over the
whole-group floor + change-selected judges (appetite `low`). The floor
(`no-third-party-deps`) holds; two critical judges (`no-source-eval`,
`ref-validation`) confirm the seed's parse-as-data and injection boundary. One
judge found a bounded violation.

### Violations
- **blueprint-slot-reserved** — high · in-change · `skills/file/scripts/jimalloc.sh:373`. The reserved-slot skip is a literal `"000"` string match, not a numeric `10#$ord == 0`; a directory `0-foo`/`00-foo` parses to id 0 yet emits `spec allocate <group>/000 …`, occupying the reserved coordinate. Bounded — id 0 never raises the next-id max, so allocation/reissue is unaffected — but it breaches "emits no record for the reserved slot." Same root cause as Finding 1; routed there.

### Coverage
- appetite in force: low (judge everything the change selects).
- Whole-group floor ran (territory declared; not UNSCOPED).
- judges: change-selected — `ref-validation`, `no-source-eval`, `blueprint-slot-reserved`; the other five judge invariants (`script-preamble`, `bash-source-relative`, `relpath-validation`, `ledger-commit-discipline`, `tests-under-tests`) were `skipped` (reason `scope` — adding a `jimalloc.sh` verb does not plausibly touch them). All within cap.
- **Territory conformance:** `tests/jimalloc.sh` is a stray (in-change) — already tracked as **#120**; `tests/scripthygiene.sh` a pre-existing stray — **#110**. Both are map-territory declarations, not code breaches; not re-filed.
- registry: 0 configured for platform.

### Contracts
- Not run — the change adds a `jimalloc.sh` verb, which is not a declared contract-graph edge (jimalloc has no consumers yet; those arrive with #111/#112). No provides-side edge touched.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 10 (0/7/0/0) |
| Files changed · insertions · deletions | 5 · +683 · −9 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 7068s·5115s·480s·1615s·1660s·472s |
| Interruptions (all stages) | 0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. The seed adds no new secret handling; it reuses 007's injection boundary, sanitized identity, and write-containment guard, and the two critical security invariants (`no-source-eval`, `ref-validation`) hold. The one bounded gap (Finding 1) is a reserved-coordinate/normalization edge, not an injection or reissue vector — the value stays log content and is rejected by the read-side boundary on replay.

## Findings

### 1. Reserved-slot skip and spec-ordinal magnitude use literal/value checks, not numeric normalization

- **Priority:** medium
- **Description:** `alloc_seed_derive_specs` skips the reserved slot with a literal `[[ "$ord" == "000" ]]` (`jimalloc.sh:373`) and bounds the spec ordinal with a value-only `(( 10#$ord > 999 ))` (`:380`) — no digit-length cap. Two consequences, both bounded: (a) a directory whose ordinal parses to 0 but is not literally `000` (`0-foo`, `00-foo`) bypasses the skip and emits `spec allocate <group>/000 …` (judge-confirmed `blueprint-slot-reserved` violation); (b) a pathological ≥19-digit ordinal could overflow `intmax_t` and wrap past the `>999` guard. Neither reissues a consumed id (id 0 never raises the next-id max; a wrapped ordinal is rejected by the read-side `alloc_valid_specid` on replay) and neither injects (the value is log content, never a git argument). The issue-num path already does this correctly with a `${#num} > 15` length cap (`:427`).
- **Suggestion:** Normalize the reserved-slot skip to `(( 10#$ord == 0 ))` and add a digit-length cap on the spec ordinal, mirroring the issue-num path. Add fixtures for `0-foo`/`00-foo` and an over-long ordinal.
- **Relates to:** AC 3, AC 9/F3; blueprint-slot-reserved; `skills/file/scripts/jimalloc.sh:373,380`

### 2. Seed landing omits the in-loop erosion re-check

- **Priority:** low
- **Description:** `alloc_cas_append` runs `alloc_check_erosion` inside its retry loop to hard-fail on a truncated/rewritten coordination history; `alloc_seed_land` has no equivalent before writing. Narrow in practice — seed only writes a kind whose tip-log is empty and reconstructs the complete state from the tree (not incrementally), and re-seeding a populated kind is already refused, so it cannot reissue a consumed id from a truncated log. But AC 8's "no path … with weaker guarantees" reads strictly against the missing re-check. (The baseline is still armed post-seed, F4.)
- **Suggestion:** Consider adding the same in-loop erosion check to `alloc_seed_land` for allocation-path parity.
- **Relates to:** AC 8, F4; `skills/file/scripts/jimalloc.sh:1021-1081`

### 3. Seed re-implements the CAS ref-update inline rather than reusing the allocation helpers

- **Priority:** low
- **Description:** `alloc_seed_land` inlines the push / `update-ref` CAS (`:1065-1076`) instead of calling `alloc_origin_cas`/`alloc_local_cas`, because those take a single logfile + piped content and the seed needs a two-blob commit (factored into `alloc_seed_commit`). The inlined mechanics are byte-equivalent, so guarantees are identical, but it is a second registry-writing code path kept in sync by convention — the maintainability risk Handoff Insight 1 flagged.
- **Suggestion:** Consider factoring the shared land step (tier select + CAS + baseline) so allocation and seed share one implementation; low priority.
- **Relates to:** AC 8, DD 1; `skills/file/scripts/jimalloc.sh:1021-1081`

## Deviations & feedback

- The build ran clean: 0 interruptions across every stage, 7 TDD tasks each Red→Green verified, full suite 767/767. All four design-time security findings (F1–F4) shipped with adversarial fixtures.
- Findings 1–3 are hardening/parity refinements, not correctness holes for real inputs. Finding 1 is the one worth prioritizing (it is a judge-confirmed invariant violation, albeit bounded); Findings 2 and 3 are consistency notes on the landing path.
