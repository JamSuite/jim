---
spec: "jim/046"
type: "feature"
base_sha: "26fb0c909712c8f6c4dc6328c245c1591b923b7d"
head_sha: "c92b8381a758c8e4625e96e8b5c29a9be9e65f3b"
commits: "11"
commits_test: "0"
commits_feat: "7"
commits_fix: "0"
commits_refactor: "0"
files_changed: "10"
insertions: "461"
deletions: "43"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "6532"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "2505"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1769"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "7487"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "1885"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "462"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "0"
contract_violations: ""
alignment: "aligned"
date: "2026-07-21"
---

# Review: Spec migration (jim/046)

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 3 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the `spec-migration` feature over build range `26fb0c9..c92b838` (10 files, +461/−43, 11 commits). All 13 acceptance criteria are satisfied with `file:line` evidence, the reconciled freeze-history doctrine lands consistently in both its homes, no scope creep, and the living-intent sensor found no blueprint-invariant regression. The three findings are advisory hardening opportunities, none blocking.

## Alignment

### vs. Spec acceptance criteria
- **AC 1–13 — met.** The three-mode preference (default `rewrite`), the reconciled doctrine (directory = live binding, body = preference, ledger `op=` = bridge, `000-blueprint` re-identifies every mode), the `rewrite-identity` mechanical floor + gatherer freeze-on-doubt, `immutable` stated-not-applicable to rename, scrubbed gate diffs, the `identity=`/`frozen=` ledger keys + frozen-candidate, and the split/merge mode-to-op mapping + composition rule are each present and correct. Evidence under **## Investigation**.
- One residual substance-fidelity edge in AC 3's mechanical rule — see Finding 1 (advisory; mitigated by the AC-12 gate diff).

### vs. Plan tasks
- **Tasks 1–10 — done, and only these.** Every spec-046 passage in the changed files traces to a specific plan task; no edit untraceable to a task, no partial implementation. The `identity=` half of the ledger keys was incidentally introduced by Task 5's mode-description before Task 7 completed it — noted during the build, not drift.

### vs. ARCHITECTURE.md
- **Respected.** Group identity stays path-derived; map/blueprint writes still route only through the blueprint surface; the new ledger keys are bounded display-data (the spec-044 precedent); the mechanical rewrite is a script verb and prose judgment the gatherer's (Bash-vs-Prompt); mode resolves only from config/developer (never-execute-config). The freeze-history invariant was intentionally revised — the deliverable, not a violation. ARCHITECTURE.md was refreshed via the `/jim:arch` completion-gate step (commit `2a5f4d7`), outside the build range.

## Investigation

Thorough depth. Three focused `Agent(investigator)` runs (read-only) plus the reviewer's diff-spine read of the two code files; all three returned *satisfied*.

### High-stakes regions investigated

#### `rewrite-identity` verb (jimpartition.sh — first in-place mutating verb)
- locations examined: `skills/partition/scripts/jimpartition.sh:1092-1231` (`cmd_rewrite_identity` + `rewrite_scan_malformed`), `:64` (usage), `:1401` (dispatch)
- callers/consumers traced: `skills/review/scripts/jimledger.sh:198-230` (`commit-map`, the cited containment precedent), `:265-296` (`rename-tracked`, same realpath/top idiom); dispatched only from `main()`
- tests checked: `tests/jimpartition.sh:1206-1223` (`rewrite_repo` fixture), `:1228-1322` (structural / location-only / idempotent / symlink-escape / untracked / malformed / usage)
- verdict: satisfied — containment guard is a faithful reuse of the write-primitive precedent (valid_relpath → realpath-under-top → tracked); **all guards run in a separate loop before any edit**, so a mix of good + guard-failing files edits nothing (partial-edit hazard closed by construction); the `cart.cart-session-api` dotted surface half is left intact (`after=='-'` fails the boundary); success and error output are location-only; malformed frontmatter is fail-closed. Residual over-match edge → Finding 1; test gaps → Finding 2.

#### 13-AC omission class
- locations examined: `skills/conf/scripts/jimconf.sh:42,99,175,190-192`; `skills/partition/SKILL.md:256-335,425-433,453,455`; `skills/partition/references/partition-methodology.md:240-268,283-311,336-343,357-384`; `agents/gatherer.md:24-37`; `jimconf.toml.example:94-108`
- callers/consumers traced: `jimledger.sh:369-381` (`cmd_event` appends `k=v` verbatim — `identity=`/`frozen=` are emit-only, no schema change); the `identity-check` retired-slug parse reads the same `;`-joined format
- tests checked: `tests/jimconf.sh:1048-1057` (default+resolve), `:331/:339-340` (list/keys); `tests/jimpartition.sh:1228-1322`
- verdict: satisfied — every AC met with evidence; no omission. AC 2/8/9's doctrine is actually written (not merely word-present) in the methodology; the two files the build did not touch (ARCHITECTURE.md, `jimledger.sh`) are correct as-is.

#### Doctrine two-home consistency + scope creep
- locations examined: `skills/partition/SKILL.md:256-280,301-335,425-433,453,455`; `skills/partition/references/partition-methodology.md:240-268,305-311,336-384`
- verdict: satisfied — both homes agree on all four reconciled-doctrine elements and the mode-conditional numbered-body rule; the sole surviving absolute-wording quote (`methodology:358`) is the *reconciled contradiction being named*, not stale doctrine. One intentional asymmetry: the split/merge mapping + composition rule lives only in the methodology (per the plan's File Manifest / Task 4). No scope creep.

### Coverage
- Depth: thorough; review_model: inherit.
- Full high-stakes set investigated (3 investigators, no cap reached). The low-stakes `spec_migration` config key was assessed from the diff spine — the standard three-touchpoint bare-name pattern (KEYS + default_for + resolve arm), correct.

## Living intent

**Sensed:** 37 invariants · **holds:** 8 · **violations:** 0 (in-change 0 · pre-existing 0 · unlocalized 0) · **skipped:** 28 · **failed/unconfigured:** 1

The `/jim:verify --from-review` sensor ran against `docs/specs/jim/000-blueprint/` after the verdict was assigned (it never sets the verdict). Every invariant the change touches holds — no regression.

### Violations
- None — every checked invariant holds.

### Coverage
- appetite in force: low (thorough — `verify_appetite_jim` unset; no per-run override).
- Whole-group mechanical floor ran: `no-third-party-deps` holds; territory conformance shows only bucketed scaffolding (root docs/config), no strays — the changed files are all within the jim territory.
- judges: the change-selected set (`allowed-tools-exact`, `injection-set-rhs`, `no-source-eval`, `untrusted-content`, `agent-boundaries`, `relpath-validation`, `partition-registry-boundary`) was resolved via mechanical inspection + this review's adversarial investigator evidence rather than a redundant fresh judge fan-out — all hold; coverage stated, not silently capped. Key confirmations: the new verb rides the existing exact-script-path `allowed-tools` grant (no grant change needed); no `source`/`eval`; `deps_command` absent from `jimpartition.sh`; gatherer tools `[Read, Glob, Grep]` unchanged.
- skipped by scope: 28 (the change does not touch them) · skipped by appetite: 0.
- registry: 1 (`skill-line-budget`) unconfigured — `skipped`/`unconfigured`; SKILL.md is 455 ≤ 500 lines by eyeball.
- No contract-edge phase — single-group project, the contract graph has no edges.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 11 (0/7/0/0) |
| Files changed · insertions · deletions | 10 · +461 · −43 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 6532s·2505s·1769s·7487s·1885s·462s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

*(`commits_test=0` reflects the repo convention that a config-key/verb's tests ride its `feat` commit — not a missing-test signal; the two touched suites are green at 580/580.)*

## Security regressions

- None identified. The one net-new surface — the `rewrite-identity` mutating verb — is a *safer* path than a raw skill `Edit`: containment-guarded (worktree-top realpath, symlink-escape and non-tracked refused before any edit), fail-closed on malformed frontmatter, and location-only on both success and error output. No secrets committed; no trust boundary weakened; the mode-selection boundary (config/developer only, never scanned content) is preserved.

## Findings

### 1. `rewrite-identity` mechanical rules can over-match a few non-identity tokens

- **Priority:** low
- **Description:** The dotted-key rule rewrites any whole-token `<old>.<lower-alnum>` and the typed-ref rule any `<old>/<digit>`. In a numbered body these could touch a token that is not group identity — e.g. a literal `cart.json` / `cart.py`, or a `cart/001`-shaped value in a frontmatter field other than `group:` (non-`group:` frontmatter lines fall through to the body token scan). All such edits stay within the worktree (a substance-fidelity edge, never a containment breach) and are surfaced to the developer as a scrubbed old→new diff at the gate before commit (AC 12), which is the safety net.
- **Suggestion:** Consider narrowing the dotted-key rule (e.g. exclude a known file-extension suffix set) or routing `<old>.<ext>`-shaped tokens to the gatherer under freeze-on-doubt. Low priority — the gate diff catches it and the caller only ever passes clean numbered-spec paths.
- **Relates to:** AC 3; Interface Contract (`rewrite-identity`)

### 2. Test gaps for the mutating verb's guards and negative branches

- **Priority:** medium
- **Description:** The "all guards before any edit" property is asserted by code structure (loop separation) but no test passes one good + one guard-failing file to prove the good file is left unedited. The `after2` alpha-negative branch (a `cart/subdir` path segment left untouched) has no case, and the `valid_relpath` `..`/absolute rejection, an invalid `<new>` slug, and the not-in-a-git-repo branch are untested.
- **Suggestion:** Add a multi-file guard-abort case, a `cart/subdir` no-rewrite case, and the `valid_relpath`/invalid-`new`/no-git negative cases to `tests/jimpartition.sh`.
- **Relates to:** AC 11; security Findings 5/6

### 3. User-facing docs post-ship pass (WORKFLOW.md / README.md)

- **Priority:** low
- **Description:** The completion gate auto-refreshes only ARCHITECTURE.md. WORKFLOW.md / README.md may reference the freeze-history doctrine or the config surface and now warrant a manual pass to mention the `spec_migration` preference.
- **Suggestion:** Post-merge, scan WORKFLOW.md / README.md for freeze-history / config-key mentions and update as needed.
- **Relates to:** Out of Scope (ARCHITECTURE.md pipeline-owned); user-facing-docs convention

## Deviations & feedback

- Clean build: 0 interruptions across every instrumented stage, no re-plan. The two spec-phase security passes (`sec_runs=2`) folded findings into the spec and plan before build, so the plan-phase security surface (`rewrite-identity` containment + location-only) was already designed in — the build introduced no new security finding.
- The `spec_migration` config key was settled through two rename iterations at plan time; the build carried the final name cleanly with no residue of the intermediate names.
