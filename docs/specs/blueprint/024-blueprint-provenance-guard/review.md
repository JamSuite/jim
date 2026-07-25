---
spec: "blueprint/024"
type: "feature"
base_sha: "fc810bcbee7f147476ecb8289eee0f18d4491ee7"
head_sha: "e9f60cbbc18824fb4b22945c188501f02becc9ca"
commits: "8"
commits_test: "4"
commits_feat: "2"
commits_fix: "0"
commits_refactor: "0"
files_changed: "8"
insertions: "295"
deletions: "38"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "4773"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "328"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "2158"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "4367"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "3443"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "269"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "0"
contract_violations: ""
alignment: "aligned"
date: "2026-07-24"
---

# Review: Guard blueprints and maps against provenance references

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 0 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the build over `fc810bc..e9f60cb` (8 commits, 8 files, +295/−38): a companion `provenance.md` doctrine mirroring present-tense, its wiring at all 10 exit-door composition sites with a second self-scan, and a deterministic `tests/provenance.sh` guard whose Green step normalized jim's own project map *through* `/jim:blueprint` — the feature dogfooding itself. Every in-range acceptance criterion is fully met, verified by execution (adversarial `prov_scan_file` probes + the 701-green suite), two read-only investigators (wiring omission class; doctrine + map), and three living-intent judges. AC 8 (the verify wiring-invariant extension) is pipeline-owned — it rides the post-build blueprint fold (Step 10), correctly outside this range.

## Alignment

### vs. Spec acceptance criteria
- AC 1 (canonical companion doc, cited by path) — **met**: `provenance.md` created, cited-by-path at every site, never restated (investigator + judge evidence).
- AC 2 (flagged forms + normalization, illustrative/extensible) — **met**: all four forms enumerated with normalizations, framed as a class (investigator: `provenance.md:26-40`).
- AC 3 (over-constraint guard) — **met**: verb names, functional groupings, the reserved `000-blueprint` path, dates/counts explicitly not flagged (`provenance.md:43-48`); confirmed by 7 false-positive probes staying clean.
- AC 4 (untrusted-text + secret-scrub, pinned by doc-structure test) — **met**: both safety sections present (`provenance.md:61-66,72-80`), asserted by `case_provenance_rule_doc_structure`; the security Advisory that drove this AC is resolved.
- AC 5 (deterministic guard: jim artifacts provenance-free) — **met**: `case_provenance_self_hosting_clean` green; blueprint spec authored clean, map normalized to 0 hits.
- AC 6 (wiring min-count test) — **met**: `case_provenance_sites_reference_rule` green at 5/2/3; investigator confirmed per-*site* adjacency (not just totals).
- AC 7 (map normalized through the blueprint surface) — **met**: normalized via a `/jim:blueprint` project-tier pass (commit `49887c6`), partition-preserving, both freshness headers restamped.
- AC 8 (`/jim:verify` senses a dropped provenance citation) — **pipeline-owned**: delivered via the post-build `/jim:blueprint --from-review` fold, not this build range (per plan Out of Scope). The build delivered everything the fold consumes.
- AC 9 (coverage exercises the shipped forms) — **met**: `case_provenance_detect_forms` fixtures (`spec-047`, `017–025`, `v2.0.0`); adversarial probes extended coverage to ids ≥100, all three dash types, uppercase.

### vs. Plan tasks
- Tasks 1–4 — **all done, only these**: doctrine doc + structure guard; wiring + scan prose; detection helper + fixtures; self-hosting guard + map normalization via `/jim:blueprint`. No functionality beyond the plan. No new production script (DD 4 held — patterns live in the test helper).

### vs. ARCHITECTURE.md
- Bash-vs-Prompt — **respected**: the mechanical guard is a deterministic test; provenance *detection in authored drafts* stays LLM judgment in the exit-door scan.
- No third-party deps — **respected**: floor `no-third-party-deps` holds; the test uses `grep`/`sed`/`wc`/`tr` only.
- Textual-invariant test convention + file-level identifier uniqueness — **respected**: `PROV_`-prefixed globals, cloned from `presenttense.sh`.
- Single-source doctrine; untrusted-supplied-text discipline; generated docs edited via their skill — **respected**: one `provenance.md` cited by path; the doc carries the untrusted-text section; the map was edited through `/jim:blueprint` (not hand-edited).
- The completion-gate `/jim:arch` refresh added a parallel **Provenance Discipline** subsection (uncommitted housekeeping, outside `head_sha`).

## Investigation

### High-stakes regions investigated

#### `prov_scan_file` — the one executable region (AC 3/5/9)
- locations examined: `tests/provenance.sh:60-70` (helper), `:89-104,113-121` (fixtures + self-hosting cases).
- callers/consumers traced: called by `case_provenance_detect_forms` and `case_provenance_self_hosting_clean` — the single home of the patterns (DD 4).
- tests checked: full file green (4 cases); full suite 701/701.
- verdict: **satisfied** — adversarially executed by the reviewer: 6 false-negative probes all hit (spec ids ≥100, uppercase `Spec`, en/em/ascii-dash ranges, paths ≥100, `v10.2.3`); 7 false-positive probes all clean (ISO dates, `Last reconciled` timestamps, the reserved path even with subpaths, criticality/counts, verb names, `v2`-in-prose). The `sed` mask neutralizes the reserved `000-blueprint` path before the grep; no file content is interpolated into the pattern (no injection, linear patterns, no ReDoS).

#### Wiring omission class (AC 4/6)
- locations examined: `skills/blueprint/SKILL.md` (5 sites incl. checklist `:518`), `references/map-methodology.md` (2), `references/migrate-arms.md` (3).
- verdict: **satisfied** — investigator confirmed complete per-*site* coverage: all 10 present-tense exit doors carry an adjacent provenance citation, every scan-invocation names both scans, no half-wired door (the gap the min-count test cannot see). Remaining bare present-tense mentions are non-scan references correctly needing no companion.

#### Doctrine doc + project map (AC 1/2/3/4/7)
- locations examined: `skills/blueprint/references/provenance.md:1-98`; `BLUEPRINT.md:1-46`.
- verdict: **satisfied** — investigator confirmed the four sections (exactly), forms + normalizations, over-constraint guard, untrusted-text + secret-scrub, and that the doc does not self-violate (placeholder N-forms only); the map is provenance-free, partition-preserving (group/role/relations/territory intact), headers restamped to 2026-07-23.

### Coverage
- Depth: thorough; review_model: inherit.
- Full high-stakes set investigated (one executable region by reviewer execution; two read-only investigators for the reading-heavy regions). ACs verified by execution + investigation rather than per-AC fan-out — runtime evidence (adversarial probes, full suite, per-site grep) is stronger than a code-read for these.

## Living intent

**Sensed:** 35 invariants · **holds:** 7 · **violations:** 0 (in-change 0 · pre-existing 0 · unlocalized 0) · **skipped:** 27 · **failed/unconfigured:** 1

### Violations
- None — every checked invariant holds.

### Coverage
- appetite in force: low (no per-group override).
- Whole-group floor ran (`no-third-party-deps` holds); territory conformance: 0 strays, 407 scaffolding files bucketed (informational, single-group by design).
- judges: change-selected, all within cap — 6 selected (the change plausibly touches them), 3 judged via `Agent(judge)` (`present-tense`, `untrusted-content`, `map-partition-authority` — all hold), 3 confirmed mechanically (`no-source-eval` holds — sources only the trusted `testlib.sh`; `script-preamble` holds — `set -uo pipefail`; `tests-under-tests` holds).
- skipped by scope: 27 (the change did not touch them) · skipped by appetite: 0 (appetite low judges everything selected).
- registry: `skill-budget` (`registry:skill-line-budget`) reported **unconfigured** — no command wired, executed nothing. Reviewer observation (not a sensor violation): `skills/blueprint/SKILL.md` is 531 lines, over the invariant's stated 500-line budget; this change added ~13 lines of necessary wiring to an already-over-budget file, tracked by open issue `20260704-restructure-blueprint-skill-line-budget` (#43).
- contract-edge phase: not run — the map's graph has no edges (single-group project; `jim` is named as provider by nothing).

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 8 (4/2/0/0) |
| Files changed · insertions · deletions | 8 · +295 · −38 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 4773s·328s·2158s·4367s·3443s·269s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. The change adds a read-only `grep`/`sed` guard (no `source`/`eval`, no untrusted path derivation, no file content interpolated into the pattern) and doctrine prose that reinforces the untrusted-supplied-text boundary. The `untrusted-content` and `map-partition-authority` invariants both hold over the changed code; the security review's one Advisory (companion-doc safety discipline) was folded into AC 4 and implemented.

## Findings

No findings — the build aligns with spec, plan, and architecture.

## Deviations & feedback

- Clean run: 0 interruptions across every stage. The two `sec` runs were the planned dual lens (spec-only, then spec+plan once the plan existed), not a correction; the spec-phase Advisory was resolved by the plan's AC 4 implementation.
- The feature dogfooded itself: Task 4's Red was jim's *real* map being dirty, its Green the just-built provenance scan flagging jim's own boundary-rationale ranges during a `/jim:blueprint` pass. Routing the map edit through the skill (DD 5) kept the freshness headers correct — the anti-pattern that hand-editing would have caused.
- Line-budget pressure: wiring provenance at every present-tense site necessarily grew `SKILL.md` to 531 lines (over the 500 budget). The growth is intrinsic to per-site citation; the structural remedy (move detail to `references/`) is tracked by issue #43, not this spec.
