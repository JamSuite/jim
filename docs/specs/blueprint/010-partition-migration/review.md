---
spec: "blueprint/010"
type: "feature"
base_sha: "391e5a828de087934f5c12ad3085fc64f96c4692"
head_sha: "af0bab365fcdd14c234e6884a8649b005991e1b4"
commits: "18"
commits_test: "0"
commits_feat: "12"
commits_fix: "0"
commits_refactor: "1"
files_changed: "13"
insertions: "2095"
deletions: "40"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "3309"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "542"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "9239"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "16429"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "3329"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "371"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "1"
security_regressions: "0"
invariant_violations: "0"
contract_violations: ""
alignment: "aligned"
date: "2026-07-07"
---

# Review: Partition migration skill (spec 038)

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 3 · **Plan deviations:** 1 · **Security regressions:** 0

Reviewed the 11-task TDD build of `/jim:partition` over `391e5a8..af0bab3`
(13 files, +2095/−40, 18 commits: 12 `feat`, 1 `refactor`, tests bundled per
jim's green-per-commit convention). The build shipped exactly the planned
scope — the `deps_command` config family, the four-verb `jimpartition.sh`
substrate with a five-language scan, the blueprint `--retire` arm, the
read-only `gatherer` agent, the `/jim:partition` skill + methodology, and the
doc seams — with 472/472 tests green. All 21 spec ACs are encoded and
operationalized, the three trust boundaries (ingest, activation, manifest-token
gating) hold, and the living-intent sensor found no blueprint violations.
Verdict: **aligned**; the three findings are advisory polish, none a divergence.

## Alignment

### vs. Spec acceptance criteria
- AC #1–#21 — **met.** An adversarial completeness pass mapped each AC to a
  concrete mechanism in the shipped artifacts (not merely a mention) and
  verified the referenced primitives exist (`jimledger.sh last-reconcile`
  health keys, the `jimverify.sh` floor, `aggregate` STRADDLE, `group_territory`).
  Two clarity notes (Findings 2–3) sit under met ACs, not divergences.

### vs. Plan tasks
- Tasks 1–11 — **done**, each with its Verify command passing.
- **Minor scope beyond plan (1):** Task 10's planned WORKFLOW.md change was a
  "command-reference entry"; the build also added the plugin-tree entries
  (`gatherer.md`, `partition/`) and the second §7a surfacing-skills list in
  `issue/SKILL.md`. Benign — internal-consistency edits within the same seam
  files, keeping the docs honest — but recorded for transparency.

### vs. ARCHITECTURE.md
- Bash-vs-Prompt, `set -uo pipefail`/`LC_ALL=C`, `BASH_SOURCE`-relative
  composition, SKILL.md ≤500 lines, one-level subagent nesting, path-scoped
  ledger commits, `allowed-tools` exactness, untrusted-content discipline —
  all **respected** (confirmed by the living-intent sensor, below).

## Investigation

### High-stakes regions investigated

#### `jimpartition.sh` trust boundaries (AC #17 · sec Findings 3, 7)
- locations examined: `skills/partition/scripts/jimpartition.sh:173-241`
  (`cmd_ingest`), `:202-208` (`safe`/`tracked`), `:395-414` (`scan_go`),
  `:648-692` (`scan_rust`), `:694-753` (`scan_elixir`), `:138`/`:201`/`:780`
  (three `san()` sites); `skills/file/scripts/jimfile.sh:209-232` (canonical
  boundary the ingest `safe()` inlines).
- callers/consumers traced: `valid_relpath`→`jimfile valid-relpath` (positional
  argv, not eval); scan token flows Go `${imp#"$module"/}`, Rust `MEMBER[$first]`,
  Elixir `MODMAP[$ref]` (all literal subscripts / quoted prefix strips).
- tests checked: `tests/jimpartition.sh:196-307` (ingest hostile-path matrix),
  `:369-379`/`:453-463` (Go/Rust metachar-manifest degradation).
- verdict: **satisfied** — ingest gates both endpoints × both checks
  (shape + tracked) with correct precedence (malformed > unsafe > untracked);
  the `..`-segment check `index("/" p "/","/../")` is provably equivalent to the
  canonical `*/../*` glob; manifest tokens are charset-gated before fixed-string
  matching in all three languages. One low note (Finding 1): the `scan` verb's
  EDGE lines emit without `san()`, relying on git's control-char escaping — safe
  as written (endpoints are tracked-by-construction), a defense-in-depth gap.

#### `deps_command` activation boundary (AC #18 · DD 3)
- locations examined: `skills/conf/scripts/jimconf.sh:105-110` (`is_dynamic_family`),
  `:150-166` (`resolve` dynamic arm), `:202-213` (`cmd_get` gate);
  `skills/partition/scripts/jimpartition.sh` (full grep — family name absent);
  `skills/partition/SKILL.md:18` (`allowed-tools`), `:71-79`, `:246-248`.
- verdict: **satisfied** — the suffix is slug-validated (`^[a-z0-9][a-z0-9-]*$`)
  before any TOML read, so a non-slug/metacharacter suffix resolves inert and
  never reaches the grep pattern; bare `deps_command` is rejected (rc 1); the
  deterministic script never resolves or executes the family; the skill
  discovers by grepping config key names (data, not sourced), resolves via the
  slug-validating resolver, and runs the command via a deliberately-undeclared
  Bash grant (no `Bash(*)` in `allowed-tools`) so activation prompts.

#### AC-to-artifact completeness (all 21 ACs)
- locations examined: `spec.md:54-156`; `skills/partition/SKILL.md:1-268`;
  `references/partition-methodology.md:1-222`; `agents/gatherer.md:1-95`;
  `skills/blueprint/SKILL.md:448-465` (§ Retire); plus the referenced primitives
  in `jimledger.sh`, `jimverify.sh`, `jimconf.sh`, `issue/SKILL.md:190-192`.
- verdict: **satisfied** — every AC encoded and operationalized; no omission-class
  gap. Two clarity notes: AC #19's superseded-group *set derivation* is left to
  judgment (mechanism complete — Finding 2), and AC #4's `coverage` counts all
  tracked files, over-surfacing non-source dirs as a superset (Finding 3).

### Coverage

- Depth: thorough; review_model: inherit.
- Full high-stakes set investigated via a 3-way investigator fan-out; no cap
  reached. The security-critical regions received independent deep reads.

## Living intent

**Sensed:** 31 invariants · **holds:** 14 · **violations:** 0 (in-change 0 ·
pre-existing 0 · unlocalized 0) · **skipped:** 16 · **failed/unconfigured:** 1

The `--from-review` sensor ran against `docs/specs/jim/000-blueprint`. The
new code honors every blueprint invariant it touches; nothing routes to a fork
or an issue.

### Violations
- None — every checked invariant holds.

### Coverage
- appetite in force: `low` (thorough — every change-selected invariant eligible).
- Whole-group floor ran (territory declared, no `UNSCOPED`): `no-third-party-deps`
  **holds**; territory-conformance is entirely `docs/` + root scaffolding + the
  spec archive (informational — no `skills/`/`agents/`/`tests/` code strayed).
- judges: the change-selected set — `allowed-tools-exact`, `no-source-eval`,
  `untrusted-content`, `relpath-validation`, `verify-registry-boundary`,
  `name-matches-path`, `script-preamble`, `bash-source-relative`,
  `agent-boundaries`, `map-partition-authority`, `sigil-discipline`,
  `blueprint-slot-reserved`, `tests-under-tests` — all **hold**, established via
  the review's own investigator fan-out (deep-reading the same territory) plus
  deterministic checks; no dedicated judge subagents were additionally spawned,
  avoiding redundant re-verification of code already deep-read this run.
- skipped by scope: 16 (the change never touched jim's ledger / reconcile /
  verify-fork / blueprint-update / plugin-manifest machinery) · skipped by
  appetite: 0.
- registry: 0 configured — `skill-budget` (`registry:skill-line-budget`) is
  `unconfigured`; budgets self-check within limits (partition SKILL.md 267,
  blueprint SKILL.md 498, both ≤500).
- The contract-edge phase did not run: the map declares a single group (`jim`),
  so there are no provider edges to check (`contract_violations` empty).

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 18 (0/12/0/1) |
| Files changed · insertions · deletions | 13 · +2095 · −40 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 3309s·542s·9239s·16429s·3329s·371s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. No secrets committed (scanned content is redacted at the
  ingest/output boundary via `san()` and the gatherer's `secret-looking value
  at path:line` rule); no trust boundary weakened (the three boundaries above
  hold); no new injection surface (the resolver slug-gates before lookup, and
  the deterministic core has no `eval`/`source`/dynamic-exec of untrusted data).

## Findings

### 1. `scan` EDGE emit relies on git escaping rather than the `san()` belt

- **Priority:** low
- **Description:** The `scan_*` helpers emit `EDGE` lines directly via `printf`
  (`jimpartition.sh:410,467,540,595,749`), not through the `san()`
  control-strip/length-cap the ingest, coverage, and aggregate verbs apply.
  Not exploitable as written — scan endpoints are tracked-by-construction from
  `git ls-files`, which C-escapes control characters, and a quoted filename
  fails `classify_ext` — but it is a defense-in-depth/consistency gap.
- **Suggestion:** Route scan's EDGE fields through `san()` too (or add a comment
  pinning the git-escaping guarantee the emit path depends on), so a future
  refactor piping non-git data through scan's emit path can't shift TSV columns.
- **Relates to:** AC #2/#17; the "fields sanitized" Interface Contract note.

### 2. AC #19 superseded-group *set derivation* is left implicit

- **Priority:** low
- **Description:** `SKILL.md:152` says "For each superseded group … `--retire`"
  but does not spell out how the superseded set is computed (old `BLUEPRINT.md`
  groups minus the newly approved partition). The retire *mechanism* is fully
  operationalized; only the set derivation is left to run-time judgment.
- **Suggestion:** Add a one-line rule to the materialize step (or methodology)
  naming the superseded set as `old-map groups ∖ approved-partition groups`.
- **Relates to:** AC #19.

### 3. `coverage` over-surfaces non-source directories

- **Priority:** low
- **Description:** The `coverage` verb counts all `git ls-files`
  (`jimpartition.sh:124-155`), so UNCOVERED surfaces non-source dirs (docs/,
  config) alongside source — a superset of AC #4's "source directory". It
  satisfies AC #4 (every uncovered *source* dir is presented) and matches the
  039 `health` coverage precedent, but adds acknowledgment friction at the gate.
- **Suggestion:** Optional — have the skill's gate presentation focus the
  UNCOVERED list on source dirs (reusing `classify_ext`), or accept the superset
  as consistent with 039. No code change required for correctness.
- **Relates to:** AC #4.

## Deviations & feedback

- A clean, uneventful build: 18 commits, zero interruptions across every stage,
  472/472 tests green throughout. The per-language TDD decomposition of the
  large `scan` task (one green cycle per resolver) kept each commit atomic and
  green-on-its-own — the pattern paid off in traceability.
- The two security re-runs (`sec_runs=2`) folded Findings 3/4/6/7/8/9 before the
  build; the build then shipped those folds with no security regression — the
  design-time security investment landed cleanly, nothing bounced back at review.
- The one plan deviation (Task-10 doc-tree entries) is the kind of
  internal-consistency edit worth pre-authorizing in the plan's File Manifest
  ("wire into WORKFLOW.md tree + command reference") to avoid the after-the-fact
  deviation flag.
