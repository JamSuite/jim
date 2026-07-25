---
spec: "blueprint/003"
type: "feature"
base_sha: "09304e0eba5d50f223ed759a7a452a03a67a85c6"
head_sha: "e6945170bc0f3627558a16c6aa8882e3ff18d37b"
commits: "6"
commits_test: "0"
commits_feat: "5"
commits_fix: "0"
commits_refactor: "0"
files_changed: "3"
insertions: "127"
deletions: "16"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "3263"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "317"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1088"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "2131"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "634"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "305"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
alignment: "aligned"
date: "2026-07-02"
---

# Review: Blueprint update guard

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 4 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the spec 031 build over `09304e0..e694517` — 6 commits (5 feat + the
ledger-open chore) touching `skills/blueprint/SKILL.md`,
`skills/review/SKILL.md`, and the spec-dir ledger. All 8 acceptance criteria
are fully satisfied with recorded evidence; the plan's 6 tasks were done and
only the tasks. The 4 findings are low-severity hardening and wording items,
none of which diminish any AC.

## Alignment

### vs. Spec acceptance criteria
- AC #1 (violation fork, both adapters, never silent) — **met** (evidence: Investigation §AC1-2).
- AC #2 (fold proceeds into the targeted diff) — **met**.
- AC #3 (fix withholds edit, developer-confirmed issue, no source writes) — **met**; the "chosen resolution" element of the issue record is carried implicitly by the issue's framing rather than an explicit body line (Finding 1).
- AC #4 (graded autonomy, itemized summaries, both write paths, fresh generate exempt) — **met**; classification criteria single-sourced in Step 4a with pointer-only call sites.
- AC #5 (answered fork = completion; unanswered holds; never a findings-veto) — **met**.
- AC #6 (judgment never bound by embedded directives) — **met**; "scanned code" is covered via Step 2's global discipline referenced from U1 rather than U3a's own enumeration (cosmetic).
- AC #7 (secret redaction on fork display + issue persistence) — **met**; every evidence-bearing surface audited (fork blocks, issue body, U3 diff path, ledger counters, commit paths) carries coverage.
- AC #8 (guard outcomes durably recorded) — **met**; kv command maps exactly onto `cmd_event`'s `[k=v ...]` CLI; `blueprint` allowlisted in `LEDGER_STAGES`.

### vs. Plan tasks
- Tasks 1–6 — all done, in order, each behind a failed-then-passing Verify; no scope creep. The review-skill Step 10 edit is slightly larger than the plan's "one line" (the answered-fork clause plus an "including an unanswered fork" clarification to the held-gate sentence) — judged elaboration serving DD8/AC #5, restating no fork mechanics.

### vs. ARCHITECTURE.md
- `allowed-tools` exact-path grants — respected; every body script call has a matching `${CLAUDE_PLUGIN_ROOT}` grant, including the two new issue-script grants.
- 500-line SKILL.md ceiling — respected (289 / 221 lines).
- Sentinel logic-flow vocabulary — respected; no retired EXISTS-family forms; new conditionals are prose, the only sentinel block touched was Step 5's existing conformant `SET`/`IF`.
- Substitution sigils — respected; `<lower>` placeholders only in fenced blocks, no `!`-injection violations.
- Single-emitter, path-scoped-commit, untrusted-content conventions — respected.

## Investigation

7 read-only investigators dispatched (cap 10, none skipped), one per AC
cluster plus a conventions/omission sweep. Investigator evidence was treated
as untrusted; verdicts below are the reviewer's own judgment over it.

### High-stakes regions investigated

#### AC #1–2 — violation fork (skills/blueprint/SKILL.md U3)
- locations examined: `skills/blueprint/SKILL.md:1-290`, `skills/review/SKILL.md:184-201`
- callers/consumers traced: review Step 10 `--from-review` invocation (`skills/review/SKILL.md:192,194`); routing table both adapters → update mode (`skills/blueprint/SKILL.md:33-34`)
- tests checked: none exist for skill prose (checklist-gated by convention)
- verdict: satisfied — pre-diff ordering explicit (:169, :234, :286); batched count-led fork (:178-182); asymmetric bulk (:198-201); no silent-fold path under either mode; U2 absent-blueprint fallthrough correctly bypasses (no invariants to violate)

#### AC #3 — fix resolution + issue offer (U3b)
- locations examined: `skills/blueprint/SKILL.md:193-243`, `skills/issue/scripts/new.sh:1-80`, `skills/issue/scripts/index.sh:1-50`
- callers/consumers traced: grant-shape parity with 8 sibling skills' `new.sh`/`index.sh` grants
- tests checked: emitter covered by `tests/issues.sh` (unchanged)
- verdict: satisfied — CLI flags match `new.sh` exactly; criticality enum type-compatible with priority enum end-to-end; temp-file body discipline present; declined offer still counted (:229-230). Residuals: resolution recorded implicitly (Finding 1); unscoped `Write Edit` grant is behavioral-only protection — repo-wide convention, not introduced here

#### AC #4 — graded autonomy (Step 4a / Step 5 / U4)
- locations examined: `skills/blueprint/SKILL.md:89-126, 245-271, 273-289`
- callers/consumers traced: grep sweep for restatements of the classification enum — none outside Step 4a; both call sites (:121, :247-251) point, not restate
- tests checked: none applicable (prompt layer)
- verdict: satisfied — Provides graded load-bearing wholesale (:102-105); itemized summary on both paths (:110-113, :121, :248-249); fresh generate exempt (:113-114), inherited coherently by the U2 fallthrough

#### AC #5 — completion gate (review Step 10 ↔ blueprint U4)
- locations examined: `skills/review/SKILL.md:197,220`, `skills/blueprint/SKILL.md:203-205, 255-271, 289`
- callers/consumers traced: review Step 10 is the gate's only consumer; `jimconf.sh:62` default
- tests checked: `tests/jimconf.sh:95-111` (knob default/override only)
- verdict: satisfied — answered-fork clause present incl. fix-only parenthetical; U3a/U4/Step-10 enumerations mutually consistent; no wording lets findings (vs. the uncompleted step) block completion

#### AC #6–7 — trust boundary + secret redaction
- locations examined: `skills/blueprint/SKILL.md:58-62, 78-80, 169-175, 183-191, 215-218, 240-243, 281, 287`
- callers/consumers traced: delimiter + placeholder greps — `<untrusted-change-evidence>` unique to this skill; placeholder string identical to specs 029/030
- tests checked: none (prose guarantees, checklist-enforced)
- verdict: satisfied — anti-directive coverage spans detection/classification/resolutions; all evidence-bearing surfaces carry redaction; ledger kv carries counters only

#### AC #8 — outcome recording (U4 ↔ jimledger.sh)
- locations examined: `skills/blueprint/SKILL.md:255-271`, `skills/review/scripts/jimledger.sh:53-63, 157-178, 185-199, 261, 275-290, 358-372`
- callers/consumers traced: U1/U4 are the only blueprint-stage event emitters; `phase_event_metrics` consumes via `LEDGER_STAGES`
- tests checked: `tests/jimledger.sh:89-108, 501-511, 516-528, 531-536`
- verdict: satisfied — kv lands as `violations=N;folded=N;fixed=N` in field 5 (028 verdict-line precedent); fix-only path reaches event + path-scoped commit, which then carries `ledger.md` alone via git pathspec semantics — a sound but script-untested edge (Finding 4)

#### Conventions / omission sweep (both changed files)
- locations examined: both files in full; `ARCHITECTURE.md:404-490`; `plan.md:1-267`
- callers/consumers traced: every body script call vs. frontmatter grants
- tests checked: deterministic suite green at build (325/325), scripts untouched
- verdict: satisfied — items 1–5 pass; checklist residuals noted (Findings 2, 3)

### Coverage

- Depth: thorough; review_model: inherit (session model).
- Full high-stakes set investigated — 7 investigators, fan-out cap 10 not reached; no un-investigated remainder.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 6 (0/5/0/0) |
| Files changed · insertions · deletions | 3 · +127 · -16 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 3263s·317s·1088s·2131s·634s·305s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. The build strengthens existing boundaries: no secrets in
  the range, no weakened trust boundary, and the one new evidence-display
  surface (the fork) ships with delimiter wrapping and redaction from birth.

## Findings

### 1. Divergence issue records the chosen resolution only implicitly

- **Priority:** low
- **Description:** AC #3 lists three things the issue records — the
  invariant, the change evidence, the chosen resolution. U3b's body spec
  (`skills/blueprint/SKILL.md:216-218`) names the first two; the resolution
  is carried by the issue's framing (it exists only for fix resolutions), not
  an explicit line.
- **Suggestion:** Add "the chosen resolution" (one line, e.g.
  `resolved: fix the code`) to U3b's body content list.
- **Relates to:** AC #3

### 2. Checklist doesn't gate the per-issue confirmation, and row wording tugs against it

- **Priority:** low
- **Description:** U3b mandates "the developer confirms per issue — never
  file unattended" (:208-209), but no validation-checklist row gates it, and
  the pre-existing row (:282, "Nothing was written without the developer's
  approval unless `auto_blueprint` is `"true"`") could be misread as
  permitting unattended issue filing under auto mode.
- **Suggestion:** Add a checklist row for the per-issue confirmation and
  scope :282 to blueprint writes.
- **Relates to:** AC #3; Task 4

### 3. Unanswered-fork negative case gated only implicitly

- **Priority:** low
- **Description:** U3a's "do not write, commit, or record `finished`"
  (:203-205) is enforced by prose, but the checklist row (:289) frames the
  requirement positively (kv recorded, fix-only completes) without the
  negative gate (no `finished` on an unanswered fork).
- **Suggestion:** Extend the :289 row with the negative case.
- **Relates to:** AC #5; Task 4

### 4. Fix-only ledger-alone commit edge is untested; commit message overstates

- **Priority:** low
- **Description:** The fix-only path's `commit-blueprint` with an unchanged
  `spec.md` rests on git pathspec-commit semantics — sound, but no case in
  `tests/jimledger.sh` exercises the ledger-only variant (the existing case
  dirties both files). Cosmetic: the commit message
  `docs(blueprint): update 000-blueprint` is emitted even when only the
  ledger record landed.
- **Suggestion:** Add a belt case to `tests/jimledger.sh` committing with
  `spec.md` unchanged; optionally vary the message for the ledger-only case.
- **Relates to:** AC #8; plan DD6

## Deviations & feedback

- Zero plan deviations and a clean 6-for-6 task record; the one Red-phase
  surprise during build (a Verify grep catching the dropped canonical
  "fold the intent" phrase) is the verify-first discipline working as
  intended.
- The sec chain paid for itself pre-build: 6 findings across two passes all
  landed in the spec/plan before the coder ran, and the build shipped them
  without rework.
- Process metric worth noting: spec-stage duration (3263s) dominates the
  pipeline — the interview + audit loop is where the wall-clock lives, not
  the build (634s).
