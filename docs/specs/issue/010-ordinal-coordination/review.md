---
spec: "issue/010"
type: "feature"
base_sha: "90b9dd0677e6c7881dedabad56678689978b83e1"
head_sha: "cb692e9234814460549fdad6f8536ddb744a26bf"
commits: "22"
commits_test: "5"
commits_feat: "6"
commits_fix: "2"
commits_refactor: "0"
files_changed: "7"
insertions: "673"
deletions: "60"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "2415"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "381"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "2077"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "22008"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "4304"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "589"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "0"
contract_violations: "0"
alignment: "minor-drift"
date: "2026-07-28"
---

# Review: Coordinated issue display ordinals

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 4 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the build range `90b9dd0..cb692e9` (22 commits, 7 files, fully
instrumented). All 11 acceptance criteria and all 8 plan tasks are satisfied and
investigator-confirmed, every security finding folded into the plan is correctly
implemented in the code, and the living-intent sensor found every checked issue
invariant holding (including the emitter contract that sdlc/blueprint depend on).
The verdict is `minor-drift` for one reason only: the build added four code
comments that cite spec/AC/Finding numbers, violating the CLAUDE.md
"no spec IDs in comments" convention — a continuation of a pre-existing systemic
pattern in these scripts, not functional drift. Three additional low-severity
robustness observations are recorded as findings.

## Alignment

### vs. Spec acceptance criteria
- AC 1 (identity through allocator, durable-before-write) — **met**: new.sh fallback → `allocate issue`, id reserved before write (no file on allocation failure).
- AC 2 (no colliding ordinals/durable ids; disambiguation both forms) — **met**: real ids registry-disambiguated; provisional ids locally disambiguated (distinct filenames).
- AC 3 (INDEX pure projection) — **met**: index.sh projects `num` verbatim, orders by slug, no allocation authority (investigator-confirmed; the omission is correct).
- AC 4 (show resolves realized ordinal; stale provisional never mis-resolves) — **met**: reconcile rewrites `num` + reindexes; show resolves via index.
- AC 5 (tier follows reachability; no per-machine setup) — **met**: inherited from the allocator; local-tier CAS exercised in a temp-repo test.
- AC 6 (provisional ordinal structurally distinct, never enters registry/high-water) — **met**: `P-…` form; allocator provisional guarantee inherited.
- AC 7 (reconcile preview→apply, idempotent, never merges; cross-clone residual at merge) — **met**: idempotent find-or-allocate; documented cross-clone limit (DD4).
- AC 8 (fail mode: bounded retry + hard-fail) — **met**: inherited from allocator; new.sh exits without writing on hard-fail.
- AC 9 (readers render real vs provisional distinguishably) — **met**: render.sh `show`/`list` mark `P-…`; `--sort num` tolerates it.
- AC 10 (revalidate every read-back value, incl. reconcile rewrite + display) — **met**: strict two-grammar `num` guard; `valid-id` gate on frontmatter durable ids.
- AC 11 (emitter guarantees unchanged) — **met**: single-emitter, atomic tmp+mv, untrusted-body encoding all preserved (sensor + investigators confirmed).

### vs. Plan tasks
- Tasks 1–6, 8 — **done** exactly as specified (num-guard, fallback, provisional disambig, rendering, reconcile.sh, SKILL.md add-flow/routing, full suite).
- Task 7 (allocator-side fixtures) — **done** as a confirm-coverage: the reconcile realize/idempotent/within-batch-halt fixtures already existed in `tests/jimalloc.sh` from platform/009, so no new fixture was needed — a defensible no-op, not a gap.
- No scope creep — the diff is exactly new.sh / reconcile.sh / render.sh / SKILL.md / tests/issues.sh; index.sh correctly left untouched.

### vs. ARCHITECTURE.md / conventions
- Bash+POSIX, single-emitter, atomic writes, validator-lockstep, BASH_SOURCE-relative — **respected** (sensor + investigators).
- **No spec IDs in code comments — VIOLATED** (Finding 1): 4 new comment citations. This drives the `minor-drift` verdict.

## Investigation

### High-stakes regions investigated (3 investigators, thorough)

#### new.sh — identity path (num-guard DD3/F2, provisional disambig DD4/F1, fallback DD1)
- locations: `new.sh:98-122` (resolve + num-guard), `:141-160` (disambig + valid-id), `:187-213` (atomic write).
- verdict: **satisfied** — strict two-grammar num-guard before the write, applied to fallback and `--num`; provisional local disambiguation yields distinct filenames; real-mode collision errors (no overwrite); durable-before-write + stdout contract preserved.

#### reconcile.sh — untrusted-frontmatter rewrite (DD5/F5)
- locations: `reconcile.sh:91-107` (scan + valid-id gate), `:129-136` (awk-anchored rewrite), `:141-166` (atomic apply).
- verdict: **satisfied** — `num:` rewrite awk-anchored to `fm==1 && !done` (never a body line); frontmatter durable ids `valid-id`-gated before the allocator; path from glob not id; atomic + single-regen + idempotent + halt-is-noop.

#### render.sh + index.sh — provisional display + INDEX purity (DD6/AC9, AC3)
- locations: `render.sh:314-319/510-515` (provisional markers), `:423` (sort tolerance); `index.sh:132-153/296/479` (verbatim projection, slug ordering).
- verdict: **satisfied** — provisional renders distinguishably; `--sort num` degrades gracefully; index.sh has zero numeric assumptions on `num`, confirming the omission-class decision (leaving it unchanged) is correct.

### Coverage
- Depth: thorough. 3 investigators over the high-stakes regions; full high-stakes set covered, no cap bind. Verdict is the reviewer's judgment over the (untrusted) investigator evidence.

## Living intent

**Sensed:** 6 invariants · **holds:** 4 · **violations:** 0 · **skipped:** 2 · **failed/unconfigured:** 0

### Violations
- **None — every checked invariant holds.** `id-gate-before-path` (critical), `untrusted-body-never-shell` (critical), `single-emitter` (high) judge-confirmed hold; `atomic-index-write` (medium) holds (tmp+mv confirmed in new.sh and reconcile.sh).

### Coverage
- appetite in force: low (no per-group override).
- Whole-group floor ran (issue has only judge invariants; no pattern rung). No territory strays — all of issue/010's files are within issue's declared territory.
- judges: change-selected (`id-gate-before-path`, `untrusted-body-never-shell`, `single-emitter` dispatched fresh; `atomic-index-write` grounded on the alignment investigation), all within cap.
- skipped by scope: 2 (`staleness-gated-reads`, `insights-capability-boundary` — the change touches neither) · skipped by appetite: 0.
- registry: 0 configured.

### Contracts
**Edges checked:** 2 · **holds:** 2 · **violations:** 0

- The build touched issue's provides-side emitter (`new.sh`), so the two emitter edges — `sdlc > issue "emitter"` and `blueprint > issue "emitter"` — were checked. Both **hold**: `contracts-check` found no breaking, and new.sh's public contract (`<slug>\t<path>` stdout + `--slug`/`--num` overrides) is byte-preserved. The §7a candidate-batch and validator-lockstep provides entries were not touched (no is_valid_id change), so those edges are unaffected.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 22 (5/6/2/0) |
| Files changed · insertions · deletions | 7 · +673 · -60 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 2415s·381s·2077s·22008s·4304s·589s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. Every trust boundary the security review flagged (F1 provisional-id collapse, F2 display-surface ordinal injection, F5 reconcile frontmatter rewrite) is correctly fenced in the shipped code, confirmed by both the alignment investigators and the living-intent judges. No secrets, no new shell/YAML interpolation surface.

## Findings

### 1. New code comments cite spec/AC/Finding numbers (convention violation)

- **Priority:** low
- **Description:** Four comments added by this build cite artifact IDs, violating the CLAUDE.md bash-scripts convention "No spec IDs or artifact references in comments" (whose rationale is that rename/split verbs renumber the very specs the references point at): `new.sh:157` (`AC5`), `reconcile.sh:89` (`Finding 5`), `render.sh:314` and `render.sh:510` (`spec 010 AC 9`). This is the sole driver of the `minor-drift` verdict.
- **Context:** a pre-existing systemic pattern — new.sh already carries 7 such citations (spec 025), render.sh 6 (specs 019/020/021). The 4 new ones match the surrounding (non-conforming) style rather than introducing a novel problem.
- **Suggestion:** reword the 4 comments to describe the behavior/rationale without the artifact reference; ideally sweep the whole issue-group scripts' pre-existing citations in one cleanup pass (a separate follow-on).
- **Relates to:** ARCHITECTURE.md / CLAUDE.md bash-scripts conventions.

### 2. new.sh mixed-pin (`--slug` XOR `--num`) produces a registry/on-disk skew

- **Priority:** low
- **Description:** The identity fallback fires when *either* `--slug` or `--num` is unset (`new.sh:98`), but it always allocates a full coordinated pair. A caller pinning exactly one flag uses that pin and silently discards the allocator's other half, so the registry's recorded pair can diverge from the on-disk id/ordinal. Latent: the USAGE header documents `--slug`/`--num` as a pre-resolved *pair*, and no in-tree caller (add flow, candidate batch) pins exactly one — so this never fires today.
- **Suggestion:** either only allocate when *both* are unset (and require both-or-neither), or reconcile the pinned half against the allocated pair; add a test for the mixed-pin case.
- **Relates to:** DD1; AC 1.

### 3. reconcile.sh provisional detection is not fence-bounded like the rewrite

- **Priority:** low
- **Description:** The `num:` *rewrite* is anchored to the first frontmatter block, but the provisional *detection* (`scan_pending`) matches the first `^num:` anywhere in the file. A hand-crafted file with a frontmatter `id:` but no frontmatter `num:` and a body line `num: P-<id>` would be misclassified as pending — causing a spurious/wasted real-ordinal allocation in the registry (no wrong-line rewrite, no unvalidated value, no path escape; the id is still `valid-id`-gated). Reachable only via a crafted file on the push-writable branch (the stated threat surface).
- **Suggestion:** fence-bound the detection to the leading frontmatter block, matching `rewrite_num`.
- **Relates to:** DD5; AC 7.

### 4. reconcile.sh swallows the index-regeneration exit code

- **Priority:** low
- **Description:** `--apply` invokes `index.sh …  >/dev/null 2>&1` with no error check (`reconcile.sh:202`), so a failed final index regeneration is silently swallowed and reconcile still reports success — leaving a stale `INDEX.md` after a successful realization.
- **Suggestion:** check the index.sh exit status and surface a non-zero regen as a warning (or failure).
- **Relates to:** DD5; AC 3.

## Deviations & feedback

- A clean, well-sequenced build: no interruptions across any stage, security dual-lens run twice (spec + plan) with all four Notables folded before build. The plan's up-front security work (DD3/DD4/DD5) shows in the code — every fenced boundary held under adversarial investigation.
- The one convention slip (spec-IDs in comments) is worth a process note: the surrounding scripts already carry this pattern pervasively, so a build naturally matches the local style. A one-time issue-group comment-provenance cleanup would remove the temptation and align with the rename-safety rationale.
- Findings 2–4 are low-severity robustness edges surfaced by deep investigation, not spec/plan gaps; they belong on a follow-on hardening pass, not a re-open.
