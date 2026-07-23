---
spec: "jim/048"
type: "feature"
base_sha: "29ff5068df5fdef8e2baf7e401166a01ea3cad96"
head_sha: "ed684cae178e544f188cebb650384414d25f37db"
commits: "16"
commits_test: "2"
commits_feat: "9"
commits_fix: "0"
commits_refactor: "0"
files_changed: "17"
insertions: "1364"
deletions: "88"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "5576"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "641"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1920"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "4831"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "3254"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "653"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "1"
security_regressions: "0"
invariant_violations: "1"
contract_violations: ""
alignment: "minor-drift"
date: "2026-07-23"
---

# Review: Partition merge

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 2 · **Plan deviations:** 1 · **Security regressions:** 0

Reviewed the partition-merge build (spec 048) over `29ff506..ed684ca` — 16 commits, +1364/−88 across 17 files. Six read-only investigators covered the high-stakes verb regions and a 34-invariant living-intent sensor ran against the `jim` group blueprint. All 21 acceptance criteria are functionally satisfied and the merge verbs, the `commit-merge` arm, and the `identity-check` refactor are correct and secure. One verified consistency finding — `merge-preflight` runs its read-only `test -d` probes on un-slug-validated components, diverging from the sibling preflights' gate-before-probe discipline — drives the **minor-drift** verdict. It is low-impact (read-only, developer-supplied args, no exec/write) with a trivial sibling-parity fix.

## Alignment

### vs. Spec acceptance criteria

- AC 1–4 (grammar/arms/preflight/collapse) — met (`merge-preflight`). AC 3's slug-validity CHECK is emitted; the *probe gating* below it is the consistency finding, not an AC breach.
- AC 5–8 (interview/collision/edge-collapse/hard-gate) — met (methodology § Merge protocol; SKILL `## Merge runs`; `<untrusted-merge-evidence>` delimiter; per-group disposition header).
- AC 9 (deterministic renumber-append, floored verbatim `<start>`) — met (`merge-map`; the Finding-6 property holds exactly).
- AC 10–11 (identity modes / reference sweep, verbs reused as-is) — met; the "no code change" claim is sound (`rewrite-identity`/`rewrite-refs` signatures accommodate merge's per-source invocation).
- AC 12–13 (blueprint `--merge` arm / territory union & residue) — met (migrate-arms § Merge arm; methodology).
- AC 14–18 (event provenance / machine-consumer widenings / edges-diff / commit choreography / reconcile-to-clean) — met (`vacated-max`, `next-id`, `identity-check` op=merge; `merge-edges-diff`; `commit-merge`).
- AC 19–21 (misalignments as issues / gatherer role / tests) — met (candidate-batch prose; gatherer merge role; 36 new bash cases over `merge_repo`).

### vs. Plan tasks

- Tasks 1–13 — all done and marked `[x]`; no scope creep. File-level scope matched the manifest exactly (12 Updated files, **zero new files**) plus the completion-gate housekeeping (ARCHITECTURE.md, WORKFLOW.md/README.md).
- **Deviation (1):** `merge-preflight` mirrors `split-preflight`'s structure but diverges from its gate-before-probe hardening discipline (DD 1's "sibling verbs", DD 4's "mechanical-first") — see Finding 1.

### vs. ARCHITECTURE.md

- Conventions respected — no skill git grant, script-owned primitives, counters-only ledger, content-as-data, the identifier ratchet. The arch refresh landed via `/jim:arch`.
- The `ledger-commit-discipline` blueprint invariant text ("exactly six commit sites") now lags the code (seven, with `commit-merge`) — an in-change living-intent violation routed to the blueprint fold (below), not a code defect.

## Investigation

### High-stakes regions investigated

#### commit-merge (jimledger.sh)
- locations examined: `skills/review/scripts/jimledger.sh:462-546`; mirror `:388-441`; header `:30-38`
- tests checked: `tests/jimledger.sh:1659-1741` (six cases)
- verdict: satisfied — CONFIRMED-secure. The `--rekey` charset gate is provably pre-git (rc 2 before any git op, proven with a prior staged move); paths dual-gated (valid-relpath + worktree containment), `--` guards throughout, no `git add -A`; a strict superset of `commit-split`'s guards. "Seven path-scoped places" count accurate.

#### merge-map (jimpartition.sh)
- locations examined: `skills/partition/scripts/jimpartition.sh:1407-1453`; `LC_ALL=C` at `:38`
- tests checked: `tests/jimpartition.sh` merge_map (7 cases)
- verdict: satisfied — the first spec receives exactly `<start>` (the target dir is never globbed → no recomputation; Finding-6 core); `LC_ALL=C` makes the glob sort numerically; 000-blueprint skip, `src==target` skip, wip-suffix, and the buffer-then-print `>999` refusal (no partial output, exact boundary) all correct.

#### identity-check refactor (jimpartition.sh)
- locations examined: `skills/partition/scripts/jimpartition.sh:1980-2046`; prior `29ff506:…`
- tests checked: `tests/jimpartition.sh` identity_check (rename/split/merge)
- verdict: satisfied — CONFIRMED-no-regression. The retired set is byte-identical to the old logic for every well-formed rename/split event; the only two OLD↔NEW divergences (no-op `old==new`, malformed comma-bearing `old=`) are unreachable from real verbs and both fail-closed (one is a false-positive *reduction*). Per-event `split("", newset)` isolation confirmed.

#### merge-preflight (jimpartition.sh)
- locations examined: `skills/partition/scripts/jimpartition.sh:1151-1307`; siblings `:1015-1135`, `:916-966`
- tests checked: `tests/jimpartition.sh` merge_preflight (9 cases)
- verdict: partial — edge cases 1–7 (effective-set dedup, sources-dup, degenerate→rename, target-collision, COLLAPSE set-cover, DIRT, fatal-flag correctness) all correct. **Divergence:** the `blueprint-exists` (`:1213`) and `target-collision` (`:1250`) `test -d` probes run on un-slug-validated `$e`/`$target`, unlike both sibling preflights which gate/`continue` before probing. Read-only (existence oracle only), never recorded, never a git pathspec. The target-explicitly-listed dedup path is correct but untested.

#### merge-edges-diff (jimpartition.sh)
- locations examined: `skills/partition/scripts/jimpartition.sh:1558-1604`; original `:1505-1544`
- tests checked: `tests/jimpartition.sh` merge_edges (5 cases)
- verdict: satisfied — multi-source `rw()` injection-safe; self-edge elision is B-side only (a stray after-graph self-edge fails loud as EXTRA, never a false pass); relies-on ratchet preserved. A multiset over-count nuance (two bystander edges to different merged groups sharing a byte-identical relies-on cell) is fail-loud, safe-direction, and inherited verbatim from `cmd_edges_diff` — not merge-introduced.

#### AC-omission sweep (spec)
- locations examined: spec 21 ACs; plan Requirements Coverage; the referenced code/prose
- verdict: satisfied — all 21 ACs land code where code is required and prose where prose suffices. Surfaced one pre-existing latent risk (below, out of scope).

### Coverage

- Depth: thorough; review_model: inherit (session model).
- Full high-stakes set investigated — 6 investigators, no fan-out cap reached (cap 10).

## Living intent

**Sensed:** 34 invariants · **holds:** 10 · **violations:** 1 (in-change 1 · pre-existing 0 · unlocalized 0) · **skipped:** 22 · **failed/unconfigured:** 1

### Violations

- `ledger-commit-discipline` — critical · violated · in-change · `skills/review/scripts/jimledger.sh:462-546`. The commit discipline holds across all **seven** sites (commit-merge is path-scoped, `--`-guarded, no `git add -A`); the invariant's factual claim "exactly **six** … commit-split" is stale. Remediation is a **text-only** blueprint update (six→seven, append `commit-merge`) — no code change. Routed to the blueprint-update fold.

### Coverage

- appetite in force: low (default; no `verify_appetite_jim` override).
- Whole-group floor ran (territory declared).
- judges: change-selected, all within cap (6 dispatched + 4 directly-assessed holds); no cap reached.
- skipped by scope: 22 (the merge change did not touch them) · skipped by appetite: 0.
- registry: `skill-budget` → **unconfigured** (`verify_command_skill-line-budget` unwired). NOTE: partition SKILL 559 / blueprint SKILL 504 exceed the 500-line doctrine — a **developer-authorized overage** (plan DD 6); the mechanical check could not verify it, so it lands `unconfigured`, not `violated`.
- Held holds beyond the floor: `no-source-eval`, `ref-validation`, `untrusted-content`, `relpath-validation`, `gate-presentation` (judged); `allowed-tools-exact`, `agent-boundaries`, `arch-via-skill`, `tests-under-tests` (directly assessed). `relpath-validation` explicitly confirms the merge-preflight probe gap is a read-only hardening concern, not an invariant breach.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 16 (2/9/0/0) |
| Files changed · insertions · deletions | 17 · +1364 · −88 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 5576s·641s·1920s·4831s·3254s·653s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. Every security-relevant living-intent invariant holds (`no-source-eval`, `ref-validation`, `untrusted-content`, `relpath-validation`), and the six investigators confirmed the merge verbs' injection-safety, path discipline, and fail-closed parsing. The `merge-preflight` probe finding is read-only (no exec/write, no git pathspec) — a hardening/consistency gap, not a security regression.

## Findings

### 1. merge-preflight probes the filesystem with un-slug-validated components

- **Priority:** medium
- **Description:** `merge-preflight`'s `blueprint-exists` (`jimpartition.sh:1213`) and `target-collision` (`:1250`) `test -d` probes run on `$e`/`$target` slug components that are not validated before the probe — `source-mapped`/`target-slug-valid` record `fail=1` but do not `continue`. Both sibling preflights (`split-preflight` `:1086/:1091`, `rename-preflight` `:921/:950`) gate before probing. Impact is low: read-only `test -d`, developer-supplied args, `$specs_dir` itself is valid-relpath-gated, never recorded, never a git pathspec — worst case a boolean directory-existence disclosure at a `..`-escaped path. A verified defense-in-depth convention break in shipped code.
- **Suggestion:** Slug-gate `$e`/`$target` (or `continue`/skip the probe on an invalid slug) exactly as the sibling preflights do — a small `fix(partition)` restoring parity.
- **Relates to:** AC #3, Task 5, DD 1/4

### 2. Two correct-but-untested edge paths in the merge verbs

- **Priority:** low
- **Description:** (a) `merge-preflight`'s target-explicitly-listed dedup (`merge wishlist cart into cart` → cart once, `listed` not `implicit`) is correct but has no test. (b) `identity-check`'s two OLD↔NEW divergence edges (no-op `old==new`, malformed comma-bearing `old=`) are fail-closed but uncovered — a regression there would be caught by reasoning, not the suite.
- **Suggestion:** Add the dedup case and the two identity-check edge cases; fold into the Finding-1 `fix` commit.
- **Relates to:** Task 5, Task 8

## Deviations & feedback

- The build ran clean (0 interruptions across every stage; 0 fix commits) and every deterministic verb shipped test-first. The one drift is a hardening-parity gap the six-investigator + judge fan-out surfaced that the tests alone did not — the omission/consistency class the deep review exists to catch.
- One **pre-existing, out-of-scope** latent risk surfaced (not a spec-048 finding): the materialize order runs `rewrite-identity` (rewrites typed refs *preserving* the number) before `rewrite-refs` (renumber-append *changes* numbers), so an intra-group numbered self-ref inside a moved body could be mis-rewritten. **Split ships the identical two-verb, same-order sweep** — merge inherits it. Narrow exposure; worth a tracked follow-on against the shared ripple engine.
