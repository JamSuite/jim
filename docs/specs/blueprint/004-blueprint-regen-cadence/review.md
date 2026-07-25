---
spec: "blueprint/004"
type: "feature"
base_sha: "28617f9fc529b5dcc6bfc1eadce5b209e2341af7"
head_sha: "26ccc1e3ee0126a42babd418108875075ffc4c24"
commits: "8"
commits_test: "0"
commits_feat: "6"
commits_fix: "0"
commits_refactor: "0"
files_changed: "8"
insertions: "249"
deletions: "28"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "3784"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "484"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1374"
sec_runs: "3"
sec_interruptions: "0"
sec_duration_seconds: "3344"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "1356"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "412"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
alignment: "aligned"
date: "2026-07-03"
---

# Review: Blueprint regen cadence

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 1 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the spec 032 build over `28617f9..26ccc1e` — 8 commits (6 feat + a
ledger-open chore + a plan-marks docs commit) touching exactly the plan's six
manifest files plus the build's own `plan.md`/`ledger.md`. All 8 acceptance
criteria are fully satisfied with recorded evidence; the plan's 8 tasks were
done and only the tasks; all four design-time security findings landed as
designed. The single finding is a low-severity documentation-completeness note.

## Alignment

### vs. Spec acceptance criteria
- AC #1 (cadence signal in update mode, suppressed at 0) — **met** (Investigation §Blueprint-wiring).
- AC #2 (baseline is the last full generate; watermark) — **met**; stamped solely from `jimfile.sh now`, a hardcoded `date -u` literal that cannot carry scanned content.
- AC #3 (both interactive and review-triggered paths) — **met**; U2a/U4 read the ledger via `updates-since` independent of the adapter flag.
- AC #4 (fix-only ledger-only-commit preserved) — **met**; single-writer watermark keeps update mode from writing `spec.md`, and `case_jimledger_commit_blueprint_ledger_only` still guards it.
- AC #5 (opt-in threshold, default off) — **met**; `blueprint_regen_threshold` defaults `"0"`, treated as disabled.
- AC #6 (threshold-triggered regen, graded under `auto_blueprint`) — **met**; on a positive threshold met, U2a regenerates *instead of* the targeted diff, still Step-4a graded, else prompts.
- AC #7 (first-time create labeled a create) — **met**; U2 fallthrough passes `create` to the whitelisted `commit-blueprint`.
- AC #8 (no fire without a trustworthy baseline/count) — **met**; `updates-since` returns rc 2 on malformed/absent watermark and a non-positive-integer threshold is fail-safe-disabled.

### vs. Plan tasks
- Tasks 1–8 — all done, in dependency order, each behind a passing Verify; no scope creep. Each `feat` commit carries its script **and** its belt tests together (Tidy-First), which is why `commits_test=0` rather than tests being absent.
- File manifest honored exactly: a tree-wide trace found the new surface (`blueprint_regen_threshold` / `updates-since` / `last_full_generate`) only in the six manifest files (+ ARCHITECTURE.md, committed out-of-range). No out-of-manifest consumer.

### vs. ARCHITECTURE.md
- Bash + POSIX only — respected; `updates-since` uses `awk -v` + lexicographic iso compare + `date -u` for the `now` bound. No `jq`/`date -d`, no third-party dep.
- `allowed-tools` exact grants — respected; **no new grant** — the new verbs ride the pre-existing `jimledger.sh *` / `jimconf.sh *` wildcards.
- Single-emitter / path-scoped commit — respected; `commit-blueprint` keeps `-- spec.md ledger.md` (never `git add -A`); the mode arg only interpolates a whitelisted `create|update` literal.
- SKILL.md ≤ 500 lines — respected (389).
- Sentinel vocabulary — respected; only `SET`/`IF`, no retired EXISTS-family forms (see Finding 1's sibling note).
- `resolve()` bare-name convention — respected; a **specific** bare-name match, not a `blueprint_*` prefix arm (out-of-scope item honored).
- ARCHITECTURE.md refresh — the clean pipeline step: `docs(arch)` commit `e818c94` sits *outside* the build range, `/jim:arch`-generated (fresh `Last updated`), not a hand-edit.

## Investigation

5 read-only `investigator` subagents dispatched (cap 10, none skipped), thorough
depth on the session model. Investigator evidence was treated as untrusted;
verdicts below are the reviewer's judgment over it, with two convention items
the write-free investigators could not close (git) confirmed by the reviewer.

### High-stakes regions investigated

#### AC #8 / DD3 / DD7 — `updates-since` validation + bound (jimledger.sh)
- locations examined: `skills/review/scripts/jimledger.sh:364-383` (`cmd_updates_since`), `:397` (dispatch), `:281-296` (`phase_event_metrics` comparator); `tests/jimledger.sh:666-723`
- callers/consumers traced: dispatch `:397`; sole skill consumer `skills/blueprint/SKILL.md:216-217`
- tests checked: count-after-watermark, zero, excludes-future, malformed→rc2, missing-ledger→rc2
- verdict: satisfied — watermark regex exact; malformed **and** empty → rc 2; `$2>w && $2<=now` proven both ways (strict `>` distinguished from `>=` by the count=2 case; future 2099 event dropped); parse-only awk, no `source`/`eval`.

#### AC #4/#6/#7 / DD5 — `commit-blueprint` mode + fix-only (jimledger.sh)
- locations examined: `skills/review/scripts/jimledger.sh:159-169`; `tests/jimledger.sh:534-582`
- callers/consumers traced: `SKILL.md:202` (`create`, U2), `SKILL.md:347` (`update`, U4)
- tests checked: create-subject, update-default, bad-mode→update, ledger-only (spec 031 AC #4)
- verdict: satisfied — `[[ "$mode" == "create" ]] || mode="update"` collapses any non-`create` value before interpolation (injection unreachable); path-scoping byte-identical to 030/031; absent-arg back-compat byte-identical.

#### AC #1/#2/#3/#5/#6 — blueprint SKILL wiring (SKILL.md, template)
- locations examined: `skills/blueprint/SKILL.md:116-140,176-249,331-389`; `assets/blueprint-template.md:1-7`; `jimfile.sh:138-140`
- callers/consumers traced: `updates-since` → jimledger contract; `jimfile.sh now` (no arg, not config-driven); review `SKILL.md:192` (`--from-review`)
- tests checked: none (skill prose, checklist-gated) — verified against the referenced script contracts
- verdict: satisfied — DD4 ordering explicit (finished → stamp fresh `now` → commit create); signal suppressed at 0; rc-2 never fires; threshold fail-safe; both paths adapter-independent.

#### AC #5 / DD6 — `blueprint_regen_threshold` key (jimconf.sh)
- locations examined: `skills/conf/scripts/jimconf.sh:42,63,117`; `tests/jimconf.sh:66,118-127,228-229,269,307`
- callers/consumers traced: sole consumer `SKILL.md:228`
- tests checked: dedicated default/override + all four enumeration guards (moved 34→35)
- verdict: satisfied — bare-name integer, default `"0"`, no `_path`; no sprawl (`auto_blueprint_regen` appears only as the rejected alternative).

#### Scope + conventions sweep (whole build)
- locations examined: `plan.md` (manifest), `spec.md:142-158`; tree-wide trace of the new surface; `skills/conf/SKILL.md:1-34`; `ARCHITECTURE.md:3,223,328,331`
- callers/consumers traced: new-surface terms confined to the six manifest files; jim-group `000-blueprint/spec.md` carries **no** `last_full_generate` (not back-stamped)
- tests checked: full suite green at build (336/336)
- verdict: satisfied — no creep; conventions honored; the two git-dependent items (arch out-of-range, per-commit atomicity) confirmed by the reviewer.

### Coverage

- Depth: thorough; review_model: inherit (session model).
- Full high-stakes set investigated — 5 investigators, fan-out cap 10 not reached; no un-investigated remainder.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 8 (0/6/0/0) |
| Files changed · insertions · deletions | 8 · +249 · -28 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·3·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 3784s·484s·1374s·3344s·1356s·412s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. The build strengthens boundaries it touches: `updates-since` parses the untrusted ledger read-only (same posture as `phase_event_metrics`), the watermark is format-validated before it can gate the unattended regen, the `<= now` bound forecloses the future-dated-event inflation vector, and the `commit-blueprint` mode is whitelisted against subject injection. All four design-time findings (DD3/DD7 validation+bound, DD5 whitelist, DD8 watermark-from-`now`, F4 threshold fail-safe) are present in the shipped code.

## Findings

### 1. New config knob absent from `jimconf.toml.example`

- **Priority:** low
- **Description:** `blueprint_regen_threshold` is not listed in `jimconf.toml.example`. Two investigators flagged this; both noted it is **consistent with existing precedent** — the spec-027 `review_depth` / `review_model` / `review_fanout_cap` knobs are also absent from that file, which documents keys selectively. So it is a completeness question, not a regression, and it was outside the plan's file manifest.
- **Suggestion:** Either add `blueprint_regen_threshold` (and, for consistency, the other undocumented behavior knobs) to `jimconf.toml.example`, or make a deliberate call that behavior knobs stay undocumented there. Low priority; optional.
- **Relates to:** AC #5

*Sibling note (not a separate finding):* U2a's threshold gate uses a compound natural-language predicate (`IF the threshold is a positive integer AND a trustworthy N was obtained AND N >= threshold`), which is not one of ARCHITECTURE.md's two canonical comparison forms. It is a reasonable extension for an integer knob (no canonical boolean/path form applies) and is not a retired EXISTS-style shape, so it satisfies the sentinel-vocabulary convention; noted only as a stylistic edge.

## Deviations & feedback

- Zero plan deviations and a clean 8-for-8 task record. The design work paid for itself before the build: the create-event ordering hazard (research Peer Feedback) and all four security findings were resolved in the spec/plan, so the build shipped them without rework.
- The security chain ran **three** times (spec-phase, a re-review after the auto-regen scope expansion, and the plan-phase dual lens) — the mid-stream scope change (adding the opt-in threshold) is what drove the extra pass, and it correctly re-classified the count-integrity finding to Notable once the count began gating an unattended action. That escalation-on-scope-change is the sec loop working as intended.
- Process metric worth noting: spec-stage duration (3784s) again dominates, and `sec` (3344s across 3 runs) is the second-largest — the design/interview loop is where the wall-clock lives, not the build (1356s).
