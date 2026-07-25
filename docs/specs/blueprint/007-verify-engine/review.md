---
spec: "blueprint/007"
type: "feature"
base_sha: "4902ffbb3bc1d30b86e78d42e1a2b273d3539401"
head_sha: "b98bf5defad3f1a516447fe87019668401c86557"
commits: "13"
commits_test: "0"
commits_feat: "7"
commits_fix: "0"
commits_refactor: "0"
files_changed: "17"
insertions: "1589"
deletions: "34"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "3487"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "907"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "3330"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "2914"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "3208"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "446"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "2"
security_regressions: "0"
alignment: "minor-drift"
date: "2026-07-04"
---

# Review: Invariant verification engine core (spec 035)

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 6 · **Plan deviations:** 2 · **Security regressions:** 0

Reviewed the `/jim:verify` engine-core build (range `4902ffb..b98bf5d`, 13 commits, 17 files, +1589/−34) against its 14 spec ACs, the plan's 12 tasks, and ARCHITECTURE.md. Six read-only investigators fanned out over the high-stakes surfaces. **The security core is sound — every trust-boundary and injection claim (registry never-execute, regex-injection foreclosure, path-param gates, TSV integrity, capability-narrowed judge, path-scoped self-commit) verified as *satisfied*.** The drift is narrow: the plan's explicitly-specified check-verb test matrix was only half-covered, and one config-degrade rule (DD #5, `verify_registry_timeout`) was dropped from the skill. Both are real and plan-traceable, but the shipped behavior matches the spec's user-observable requirements.

## Alignment

### vs. Spec acceptance criteria

- AC #1 (per-invariant outcomes, five distinctions) — met: `holds/violated/failed/unconfigured/skipped` vocabulary in `jimverify.sh` + SKILL Step-4/5/6/7.
- AC #2 (criticality-led report; graceful absent/empty blueprint) — met: SKILL gates on missing `000-blueprint` / zero-invariant parse, stops plainly.
- AC #3 (honest coverage; capped fan-out named; `none` degradation named) — met: `UNSCOPED` sentinel named; fan-out remainder named.
- AC #4 (zero-config floor, territory-scoped, `valid-relpath` at use, never appetite-gated) — met; see Findings 3–4 for two bounded edge-cases in the deterministic core.
- AC #5 (territory conformance when declared) — met: deterministic set difference; skill frames attribution.
- AC #6 (operator registry; name validated before lookup; no blueprint-derived args; contained failure) — **met, verified twice** (`jimverify.sh:85` parse gate + `jimconf.sh:157` resolver gate; SKILL Step 6 runs via the Bash tool, no jim script executes a config string).
- AC #7 (judge fallback; capability-backed read-only; evidence-as-data) — met: `agents/judge.md` tools exactly `[Read, Glob, Grep]`, no stray grant.
- AC #8 (appetite threshold + per-group + per-run override + cap; skipped named; malformed config degrades) — met for appetite/cap; **drift: the `verify_registry_timeout` degrade of DD #5 is not applied in the skill** (Finding 2).
- AC #9 (structured closed-vocabulary check data) — met.
- AC #10 (legacy blueprints verify via judge fallback) — met for well-formed legacy tables; one bounded completeness edge (Finding 5).
- AC #11 (issues offered; no verdict artifact; counters durably recorded; self-commit) — met: `commit-verify` stages `ledger.md` alone, fixed subject.
- AC #12 (engine read-only toward the project) — met: judge is capability-narrowed; script never mutates project files.
- AC #13 (untrusted content incl. command output; delimited evidence) — met.
- AC #14 (secret redaction incl. command output and issue bodies) — met.

### vs. Plan tasks

- Tasks 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12 — done as specified.
- **Task 4 — done with a coverage shortfall.** The `check` verb ships and works, but the plan text ("must/must-not pattern pass+fail, structure exists/absent … negative param cases") is only half-covered by tests (Finding 1). This is the one task with a deviation.
- No scope creep observed — the build stayed within the 12 tasks; the only `plan.md` change was flipping task checkboxes.

### vs. ARCHITECTURE.md

- Bash-vs-Prompt split — respected (deterministic floor in `jimverify.sh`; judgment in the skill).
- Never source/eval config or scanned content — respected (awk/grep/sed only; registry executed by the model via the Bash tool, never a jim script).
- `allowed-tools` names exact script paths, correct `${CLAUDE_SKILL_DIR}`/`${CLAUDE_PLUGIN_ROOT}` sigils — respected (one benign wildcard, Finding 6).
- One-level nesting / read-only capability-narrowed subagents — respected (judge is the single level; `/jim:verify` runs inline).
- SKILL ≤500 lines (verify 195, blueprint held at 497) — respected.

## Investigation

Six read-only `investigator` subagents, session model, thorough depth. No fan-out cap hit (6 < cap 10); full high-stakes set covered.

### High-stakes regions investigated

#### `jimverify.sh` check-verb param gates (AC #4/#6, sec Finding 6)
- locations examined: `skills/verify/scripts/jimverify.sh:189-195,236-278,284-308,335-370`; `skills/file/scripts/jimfile.sh:215-232`
- callers/consumers traced: `safe_path_param` call sites :256/:294/:300; `cmd_check` dispatch :361-366 (only pattern/structure run)
- tests checked: `tests/jimverify.sh:373-411,204-222`
- verdict: satisfied — repo-escape and option-injection blocked by `safe_path_param` + `valid-relpath` + `-e`/`--`/`./` guards; failing params `return` before grep/find; `[^ ]` char class preserved by the key-aware `parse_params`. One advisory (Finding 3).

#### `jimverify.sh` parse / TSV integrity / legacy fallback (AC #9/#10, sec Finding 7)
- locations examined: `skills/verify/scripts/jimverify.sh:71-131,200-204`
- tests checked: `tests/jimverify.sh:54-166`
- verdict: satisfied — column stability proven safe (`san()` + single-line `RS`); no code execution; malformed id/registry-name degrade without raw-echo; legacy 3-col → judge. Two bounded edges (Findings 4–5).

#### `jimconf.sh` verify_* resolver (sec Finding 1)
- locations examined: `skills/conf/scripts/jimconf.sh:42,88-91,104-109,123-131,148-196,200-211`
- tests checked: `tests/jimconf.sh:847-938,313-316,324`
- verdict: satisfied — suffix charset gate precedes `parse_value`, so `verify_command_.*` never reaches grep; fixed keys resolve correctly; no regression from the `verify_*` disjunct.

#### `verify/SKILL.md` registry trust boundary (AC #6/#11/#13/#14)
- locations examined: `skills/verify/SKILL.md:14,47-58,109-176`; cross-checked all 5 `allowed-tools` paths against the tree
- tests checked: `tests/jimverify.sh:103-132`
- verdict: satisfied — registry runs via the Bash tool (never a jim script); allowed-tools least-privilege with correct sigils; registry commands deliberately undeclared (permission prompt at run time); untrusted + redaction discipline applied to registry output and issue bodies. Three minor nits (Findings 2, 6, and a stylistic SET-line note).

#### `judge.md` capability + `commit-verify` (AC #7/#11/#12)
- locations examined: `agents/judge.md:1-16,24-37,63-65`; `skills/review/scripts/jimledger.sh:211-226,324`
- verdict: satisfied — tools exactly `[Read, Glob, Grep]`, zero mutating grant; `commit-verify` stages `ledger.md` alone, fixed literal subject, `--` guard, degrades outside a repo; four commit arms confirmed.

#### Test-coverage completeness (the omission class)
- locations examined: `tests/jimverify.sh` (whole), `tests/jimconf.sh:842-938`, `tests/jimledger.sh:793-856`
- verdict: partial — jimconf / parse / jimledger / territory / UNSCOPED coverage is substantive and real (fixtures run the real scripts against real grep/find/git); the `check`-verb outcome matrix is half-covered (Finding 1). `commits_test=0` confirmed a commit-labeling artifact, **not** a coverage gap — the ~330 assertions ride `feat:`/`chore:` commits per jim's TDD-bundled atomic-commit convention.

### Coverage

- Depth: thorough; review_model: inherit (session model). Full high-stakes set of 6 targets investigated; no cap bound.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 13 (0/7/0/0) |
| Files changed · insertions · deletions | 17 · +1589 · −34 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 3487s·907s·3330s·2914s·3208s·446s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

`commits_test=0` is expected under jim's convention — tests are committed inside their feature commits, not under a standalone `test:` prefix. `sec_runs=2` reflects the spec-phase + plan-phase dual-lens security review.

## Security regressions

- None identified. All trust boundaries introduced by the build were verified intact by the fan-out: the never-execute-config model holds (registry runs via the Bash tool through Claude Code's permission layer, from operator config only), regex-injection into the config resolver is foreclosed before any lookup, path-bearing check params cannot escape the repo or inject grep/find options, and the judge subagent is capability-narrowed. The advisory items under Findings are defense-in-depth thinness, not regressions — every guarantee held.

## Findings

### 1. `check`-verb outcome matrix is only half-covered by tests

- **Priority:** medium
- **Description:** Plan Task 4 specified "must/must-not pattern pass+fail, structure exists/absent … negative param cases." The tests cover `must`→holds and `must-not`→violated but omit `must`→violated (required pattern absent) and `must-not`→holds (forbidden pattern absent); structure covers only the holds direction (missing-`exists`→violated and matching-`absent`→violated are untested); and the param-gate "never executed" guarantee is asserted only via `verdict=failed`, with no side-effect probe, and only `scope` is tested for `..`/leading-dash (`exists` only for absolute, `absent` not at all). A mutation hardwiring a `must` check to never fire, or a `must-not` to always fire, would pass CI.
- **Suggestion:** Add the missing outcome-direction and param-gate cases to `tests/jimverify.sh`; mirror the side-effect probe pattern from `tests/jimledger.sh:639-657` ("no command executed") for the never-execute guarantee.
- **Relates to:** Task 4; AC #4

### 2. `verify_registry_timeout` is resolved but never degraded in the skill

- **Priority:** medium
- **Description:** DD #5 requires `verify_registry_timeout` to degrade a junk/non-positive value to `120` (the same degrade + report-note rule as its siblings). SKILL Step 1 validates `verify_appetite`, `verify_fanout_cap`, and `verify_model`, but the `verify_registry_timeout` resolve (`skills/verify/SKILL.md:50`) is carried straight to Step 6's Bash-tool timeout with no range/type gate. A malformed operator value could produce a malformed timeout. It is operator-config (not blueprint-derived), so this is robustness, not a trust-boundary risk.
- **Suggestion:** Add the junk→`120` degrade (+ report note) to Step 1 alongside the other knobs.
- **Relates to:** DD #5; AC #8

### 3. `safe_path_param` leading-dash reject bypassed by a leading space

- **Priority:** low
- **Description:** A crafted params line like `scope= -rf` yields the value `" -rf"` (empty value + stray token, rejoined with a leading space). This slips past `safe_path_param`'s `[[ "$v" == -* ]]` check (leads with a space, not a dash) and passes `valid-relpath`. It is contained harmlessly by the `--`/`-e` call-site guards as a nonexistent path operand — but the defense-in-depth is thinner than intended; the guarantee rests entirely on the call-site guards.
- **Suggestion:** Trim leading/trailing whitespace in `safe_path_param` (or reject whitespace-bearing values) so the leading-dash intent is airtight.
- **Relates to:** sec Finding 6; `skills/verify/scripts/jimverify.sh:189-195`

### 4. Separator-row filter silently drops a dashes-only Id

- **Priority:** low
- **Description:** `parse`'s separator-row filter `c1 ~ /^:?-+:?$/` runs on every table row before the data branch. In the 4-col format `c1` is the Id, so an Id of `-` or `---` is silently skipped as if it were a table separator — a silent drop that contradicts the "never a silent drop" contract. Pathological (a dashes-only Id is not real blueprint content), but a genuine hole.
- **Suggestion:** Apply the separator-shape skip only to the row immediately following the header, or exclude it once the header has been seen.
- **Relates to:** AC #1; `skills/verify/scripts/jimverify.sh:117`

### 5. Legacy row with an out-of-enum criticality degrades to `failed`, not `judge`

- **Priority:** low
- **Description:** AC #10's "legacy blueprints verify unchanged via the judge fallback" holds only when the legacy criticality is in the lowercase `critical|high|medium|low` enum. A legacy table using a non-standard criticality word emits `malformed`→`failed` rather than `judge`. Realistic legacy blueprints use the spec 029 enum, so this is normally moot, and the legacy test only exercises in-enum values.
- **Suggestion:** Consider whether a legacy (Id-less) row with an unrecognized criticality should still judge-fall-back; at minimum document the enum-strictness in `check-authoring.md`.
- **Relates to:** AC #10

### 6. `Bash(mkdir *)` is an un-narrowed (and possibly unused) allowed-tools grant

- **Priority:** low
- **Description:** `verify/SKILL.md` declares `Bash(mkdir *)`, the one allowed-tools entry that is a wildcard rather than an exact script path. The issue-offer files through `new.sh` (which resolves its own dir), so the skill body may not invoke `mkdir` at all. Benign (`mkdir` cannot execute arbitrary code), but it is minor permission-creep.
- **Suggestion:** Confirm whether the skill needs `mkdir`; if not, drop the grant. (The `/jim:review` skill keeps it for its auto-file `mkdir -p`; verify's issue path differs.)
- **Relates to:** ARCHITECTURE.md → Permission Conventions

## Deviations & feedback

- The two plan deviations both point the same way: the *deterministic, security-critical* code was implemented and tested faithfully (the fan-out found the injection/escape/capability guarantees all intact), while the *completeness* edges — the opposite-direction test cases and one config-degrade instruction — were where corners were rounded. A TDD build naturally over-invests in the paths it writes tests for first; the missing cases are the ones a red-test-first discipline would have forced up front.
- `sec_runs=2` (dual-lens spec + plan security review) clearly paid off: every security AC and finding this review re-checked was already satisfied in the code, so the design-time review front-loaded the hard parts.
- Two build follow-ups were already filed during the completion gate (the `count=` test and territory-conformance volume); Finding 1 here supersedes/extends the former into a full outcome-matrix gap.
