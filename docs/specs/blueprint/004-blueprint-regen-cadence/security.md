---
spec: "docs/specs/blueprint/004-blueprint-regen-cadence/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-03"
---

# Security Review: Blueprint regen-cadence signal

## Summary

**Findings:** 0 Critical · 0 Notable · 0 open · 4 resolved-by-plan

Plan-phase dual-lens re-review (spec + plan.md). **The plan closes every finding.**
The prior Notable (count/watermark integrity) is pinned by DD3 (validation in
`updates-since`, rc 2 → no-fire) + DD7 (events bounded to iso `<= now`) + Task 2
belt tests; the two prior Advisories by DD5/Task 1 and DD8/Task 5. One new
Advisory surfaced from the plan lens (Finding 4 — threshold config-value
fail-safe) and was **routed into the plan** (Task 6 + DD6). Status `Active`; no
spec↔plan misalignment; no task writes a sensitive path. Feature crosses no new
trust boundary and handles only non-sensitive internal telemetry; LINDDUN N/A.

## Coverage

- spec.md — reviewed 2026-07-03 (requirements-gap lens; research.md read as design context)
- plan.md — reviewed 2026-07-03 (design-flaw lens; verified mitigations for the spec-phase findings)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | — |
| Credentials | No | Generate mode scans group code that *may* contain secrets, but that is existing spec 029/030 behavior with `secret-looking value at <path:line>` redaction — unchanged and not extended by this feature. |
| Session data | No | — |
| Internal-only | Yes | `last_full_generate` watermark timestamp, the derived targeted-update count, `blueprint finished` ledger events, and the create/update commit-message label — all project-internal, non-sensitive. |
| Public | No | The commit-message label (create vs update) lands in git history, but reveals nothing sensitive. |

## Findings

### 1. Count/watermark integrity now gates an unattended regen — validate before acting

- **Status:** ✅ Resolved by the plan — DD3 (validation + rc 2 → no-fire, centralized in `updates-since`), DD7 (events bounded to iso `<= now`), and Task 2's belt tests (malformed watermark → rc 2; future-dated excluded). Interface Contract pins the rc-2 semantics; Task 6 has the skill degrade to signal/prompt on rc 2. Implementation correctness is `/jim:review`'s post-build check.
- **Severity:** Notable *(elevated from Advisory once the count began gating the auto-regen; now design-closed)*
- **Description:** The derived count is a function of two untrusted-or-editable
  inputs: the `last_full_generate` watermark (git-committed, developer-editable
  blueprint frontmatter) and the `blueprint finished` lines in the committed,
  untrusted `ledger.md`. In the signal-only design a bad value only skewed a
  *displayed* number (cosmetic). With the opt-in threshold (AC #5/#6), the count
  now **gates an unattended full regeneration** under `auto_blueprint`, so
  integrity of that count becomes a pre-build requirement. Two concrete vectors:
  (a) a malformed watermark (empty / garbage) makes the count unreliable; (b)
  **future-dated `blueprint finished` events** (iso `> now`, plantable via a
  merged contribution) stay "after" the watermark even across a regen — because a
  regen stamps the watermark at `now`, which is still *before* a future-dated
  event — so the inflated count persists and re-triggers a regen on *every*
  subsequent update run. Neither is shell-injectable (quoted args, `awk -v`, no
  eval), and each regen is itself bounded and idempotent-ish; the risk is
  **unwanted, repeatable unattended compute/writes**, not code execution or data
  loss.
- **Suggestion:** Before the count can gate a regen, (1) validate the watermark
  against `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$` (mirrors the
  script's SHA validation via `jimfile.sh valid-id`) and treat malformed as "no
  baseline" → **do not fire** (AC #8); and (2) bound the counted events to those
  with iso `<= now`, so future-dated ledger lines cannot force a persistent
  re-trigger. A malformed/untrustworthy count must degrade to the signal/prompt,
  never to a spurious auto-regen.
- **Route:** Plan
- **Relates to:** AC #6, AC #8; research.md Peer Feedback / Security & Performance

### 2. `commit-blueprint` mode argument should be whitelisted

- **Status:** ✅ Resolved by the plan — DD5 (whitelist to `create`|`update`, default `update`) + Task 1 belt tests (create vs. update subject).
- **Severity:** Advisory
- **Description:** The new `commit-blueprint <dir> [create|update]` arg is
  interpolated into the commit subject (`docs(blueprint): <mode> 000-blueprint`).
  The mode is trusted-origin (set by the skill's own prose, `create` in the U2
  fallthrough / `update` in U4) and is **not** injectable — it lands inside a
  single quoted `-m` argument to git, and bash does not re-evaluate command
  substitution embedded in a variable's value. Worst case from a future
  misuse is a malformed commit subject, not execution.
- **Suggestion:** Defensively whitelist the arg to exactly `create` | `update`
  in `cmd_commit_blueprint`, defaulting anything else (including absent) to
  `update` for back-compat. This keeps the subject well-formed regardless of
  caller and documents the closed value set. Back-compat is safe: existing
  callers pass no mode → `update` → byte-identical to today's behavior.
- **Route:** Plan
- **Relates to:** AC #6

### 3. Make the "watermark is `now`, never content-derived" discipline explicit

- **Status:** ✅ Resolved by the plan — DD8 + Task 5 (generate stamps `last_full_generate` solely from `jimfile.sh now`; Constitution Check row affirms the trust boundary carry-forward).
- **Severity:** Advisory
- **Description:** The security of the watermark rests on it being a system-clock
  value (`jimfile.sh now`) stamped by generate mode, **never** a value lifted
  from scanned code, a diff, a commit, or the ledger. This is the anti-directive
  trust boundary carried forward from specs 026/029/030/031 (embedded
  directive-style content is data, never instruction), but the spec/research do
  not yet state it explicitly for the watermark stamp. Without it stated, a
  future implementer could inadvertently source the watermark from scanned
  content, opening a poisoning vector.
- **Suggestion:** Have the plan state that generate mode stamps
  `last_full_generate` solely from `jimfile.sh now` and that no scanned/diff/
  ledger content may influence the watermark value or the count — an explicit
  carry-forward of the existing trust boundary.
- **Route:** Plan
- **Relates to:** AC #2; Handoff Insight 1

### 4. Threshold config value is not validated before gating the auto-regen (plan lens)

- **Status:** ✅ Resolved by the plan — routed into Task 6 (non-positive-integer threshold → disabled, never fire) + DD6 fail-safe note + a checklist row.
- **Severity:** Advisory
- **Description:** `blueprint_regen_threshold` is a developer-authored `jimconf`
  value. `jimconf.sh resolve()` returns it verbatim (or the `"0"` default for
  missing/whitespace) — it does **not** guarantee an integer. Plan Task 6 gates
  the regen on `blueprint_regen_threshold > 0` without stating that the skill
  first confirms the value is a non-negative integer. A typo'd value (e.g.
  `"5x"`, `"-3"`) would make a bash arithmetic test error or behave undefinedly,
  and the failure should be **fail-safe** (do not fire) rather than error mid-run
  — the same posture the count already takes (Finding 1). Trusted-origin, so
  low-likelihood; called out because the value gates an unattended action.
- **Suggestion:** Have the skill treat a non-positive-integer threshold as
  **disabled** (signal-only), never firing on a malformed knob. Add a checklist
  row asserting the fail-safe, mirroring the count's rc-2 degradation.
- **Route:** Plan
- **Relates to:** AC #5, AC #6; plan Task 6 / DD6

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity or authentication surface; the sole principal is the developer via Claude Code (existing trust boundary). No new principals. |
| Tampering | Yes (mitigated in plan) | Finding 1 — tampered watermark / spurious `blueprint finished` lines skew the count that gates the regen. Closed by DD3 (validate + rc 2 → no-fire) and DD7 (bound to iso `<= now`); artifacts are git-committed (tamper-evident). |
| Repudiation | N/A | The feature is itself a visibility/audit signal; the ledger already provides the event record. Nothing here needs additional non-repudiation. |
| Information Disclosure | No issues found | Count + timestamp + create/update label are internal-only and non-sensitive. Secret-scrubbing for scanned content is unchanged spec 029/030 behavior. No new disclosure surface. |
| Denial of Service | Yes (mitigated in plan) | Finding 1(b): future-dated ledger events would re-trigger the regen every run. Plan DD7 bounds counted events to iso `<= now`, and DD7's regen re-baselines (resets the count), so a past-tampered event triggers at most one bounded regen. No exhaustion path remains. |
| Elevation of Privilege | N/A | No privilege model and no `allowed-tools` change — the new subcommand runs under blueprint's existing wildcard `jimledger.sh *` grant. No capability gained. |

## Artifact Misalignment

No spec↔plan misalignment. The plan's design honors each load-bearing spec AC:
AC #5 (opt-in, default off) → DD6 + Task 3 (`blueprint_regen_threshold` default
`"0"`); AC #6 (threshold regen, graded under `auto_blueprint`) → DD7 (generate
differential path inherits spec 031 grading); AC #8 (no fire without a
trustworthy baseline/count) → DD3 + Task 2 (rc 2) + Task 6 (skill degrades to
signal/prompt). AC #4 (fix-only ledger-only-commit) is preserved by the
single-writer watermark (DD1). No task writes a sensitive path (manifest is
scripts, tests, template, skill prose).

## Routing Recommendations

### Resolved by the plan
- **Finding 1 (Notable):** design-closed — DD3 (validate + rc 2 no-fire in `updates-since`), DD7 (bound to iso `<= now`), Task 2 belt tests, Task 6 skill degradation.
- **Finding 2 (Advisory):** design-closed — DD5 whitelist + Task 1 tests.
- **Finding 3 (Advisory):** design-closed — DD8 + Task 5, plus the Constitution Check trust-boundary row.
- **Finding 4 (Advisory):** routed into the plan this pass — Task 6 (non-positive-integer threshold → disabled) + DD6 fail-safe note + checklist row.

_No open findings remain; nothing routes to a follow-on issue._

### Confirmations (no action)
- **Auto-triggered regen inherits spec 031's graded autonomy:** the threshold-fired regeneration is generate mode's differential path (plan DD7), so a `critical`/`high` invariant or Provides downgrade still prompts even under `auto_blueprint` (AC #6) — the auto-regen cannot silently weaken load-bearing content.
- **Fix-only ledger-only-commit (spec 031) preserved:** single-writer watermark (DD1) keeps update mode from writing `spec.md` to count; Task 7 guards `case_jimledger_commit_blueprint_ledger_only` against regression.
- **Ordering hazard (research Peer Feedback) has no security implication:** plan DD4 ("stamp watermark last") uses `jimfile.sh now` (system clock); no new trust crossing or injection — purely a correctness ordering concern.
