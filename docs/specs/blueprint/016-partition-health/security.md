---
spec: "docs/specs/blueprint/016-partition-health/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-12"
---

# Security Review: Partition-health sensors

## Summary

**Findings:** 0 Critical · 0 Notable · 0 Advisory open (all 6 findings
resolved)

Dual-lens re-run: spec.md (requirements-gap) + plan.md (design-flaw) +
artifact-misalignment pass. All four first-run findings are resolved — two
by spec amendment (AC #13, the AC #5/#6 unarmed notice), two by plan design
decisions (DD #8 structural cycle guard, DD #7 recorded inline rationale).
Open: one spec↔plan misalignment on the mismatch sensor's input claim, and
one least-privilege tightening on the new `allowed-tools` clause. LINDDUN
remains omitted — no PII, credentials, or session data.

## Coverage

- spec.md — reviewed 2026-07-12 (requirements-gap lens; re-reviewed same
  day after AC #4 attribution-key amendment)
- plan.md — reviewed 2026-07-12 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | — |
| Credentials | No | — |
| Session data | No | — |
| Internal-only | Yes | Ledger counters, group names, territory paths, provides-face prose — project-internal dev telemetry, committed to the repo |
| Public | No | — |

## Findings

*Findings 1–4 are from the 2026-07-12 spec-only run and are **resolved**;
resolution noted per finding. Findings 5–6 are new in the dual-lens re-run
(Finding 5 lives in § Artifact Misalignment).*

### 1. Trend series lacks a per-event shape-validation requirement — RESOLVED

- **Severity:** Notable
- **Description:** The sensors consume a *series* of reconcile events, but
  the ACs only constrain the single-event cases: AC #12 requires firing
  decisions to derive from the trusted counter channel, and AC #9 covers
  too-few events. Nothing requires that each event in the consumed series
  is shape-validated with malformed events excluded *and the exclusion
  named*, nor that an `na`-valued health counter (coverage not computable)
  is carried as not-computable rather than entering a trend as a number. A
  corrupted or adversarial ledger line could skew the trend silently, and
  an `na` read as 0 would fabricate a coverage change. Spec 039 AC #2
  solved exactly this at single-event grain ("fails shape validation →
  treated as absent — and the report names that degradation").
- **Suggestion:** Add an AC mirroring 039 AC #2 at series grain: events
  failing shape validation are excluded from the trend with a named
  degradation note in the report; `na` values never participate in a trend
  as numeric values.
- **Route:** Spec
- **Relates to:** AC #2, AC #9, AC #12
- **Resolution:** Spec AC #13 (series-grain exclusion + named degradation +
  na-never-numeric); plan Tasks 2/4 carry the test cases.

### 2. Blueprint↔partition invocation cycle is broken only by a prompt-level property — RESOLVED

- **Severity:** Notable
- **Description:** The reconcile hook adds a `/jim:blueprint` →
  `Skill(jim:partition)` invocation edge while `/jim:partition` already
  invokes `Skill(jim:blueprint)` to materialize maps (spec 038). The only
  cycle-breaker is that health mode is read-only (AC #1) — a prompt-enforced
  property, not a capability boundary. Under `auto_blueprint` +
  `auto_health` both edges can run unattended; a mode confusion inside the
  health invocation (e.g. the partition skill falling through to an
  entry-mode that writes) would produce an unattended write loop.
- **Suggestion:** The plan must make "a health run never invokes the
  blueprint surface, and never writes" an explicit design invariant with
  test coverage, and shape the hook's invocation so it cannot land in a
  materializing mode (an argument form that dispatches only to the health
  section).
- **Route:** Plan
- **Relates to:** AC #1, AC #5, AC #7
- **Resolution:** Plan DD #8 — the `health` token dispatches to a section
  with no `Skill(jim:blueprint)` call site and read-only verbs only; the
  cycle is broken structurally.

### 3. Unarmed `require_health` is silent fail-open — RESOLVED

- **Severity:** Advisory
- **Description:** Per AC #7's arming rule, `require_health = "true"` with
  no thresholds configured holds nothing — correct by design, but an
  operator who sets the knob may believe the pipeline now enforces health
  checks. The misconfiguration is invisible: the hook is silent (AC #5),
  so nothing ever tells them the gate is unarmed.
- **Suggestion:** When `require_health` or `auto_health` is truthy and no
  valid threshold is configured, the reconcile report notes it in one line
  ("health knobs set but no thresholds configured — hook unarmed"),
  mirroring AC #6's junk-value noting.
- **Route:** Spec
- **Relates to:** AC #5, AC #6, AC #7
- **Resolution:** Spec AC #5/#6 amendments (the one-line unarmed-knob
  notice); plan `health-eval` emits the `THRESHOLDS` record the hook keys
  on.

### 4. Interpretation runs in a write-capable context (prompt-enforced, not capability-backed) — RESOLVED

- **Severity:** Advisory
- **Description:** The sensor's LLM interpretation reads untrusted
  map/blueprint content inline in the main context, which carries
  `Write`/`Edit`. The mitigations are delimiters + data-not-instruction
  discipline (AC #12) — consistent with the inline precedents (031 fork
  evidence, 034 reconcile report, 036 sweep), but weaker than spec 020's
  capability-backed `issue-analyst` boundary, and the health report is a
  *judgment* surface, the class of work jim elsewhere fans out to read-only
  subagents (judge, gatherer).
- **Suggestion:** The plan should consciously choose the execution context:
  either a read-only fan-out for interpretation, or a recorded rationale
  for inline execution with AC #12's delimiting plus advisory-only outputs
  and human-gated issue filing as the standing mitigations.
- **Route:** Plan
- **Relates to:** AC #3, AC #12
- **Resolution:** Plan DD #7 — inline execution consciously chosen with
  recorded rationale; mitigations are AC #12 delimiters, advisory-only
  outputs, human-gated issue filing, and zero agent fan-out.

### 6. Blueprint's new `jimpartition.sh` grant is script-level where verb-level suffices

- **Severity:** Advisory
- **Description:** Plan Task 7 adds
  `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/partition/scripts/jimpartition.sh *)`
  to `/jim:blueprint`'s `allowed-tools`. The blueprint surface (its own
  hook plus the inline health run under its grants) needs exactly two of
  the script's nine verbs — `health-eval` and `identity-check` — never the
  mutating-adjacent migration/rename verbs (`scan`, `ingest`, `aggregate`,
  `coverage`, `rename-preflight`, `occurrences`, `edges-diff`). Spec 042
  established verb-scoped grants and Permission Conventions allows scoping
  "tighter still"; issue #52 tracks allowed-tools exactness drift as
  critical.
- **Suggestion:** Declare two verb-scoped clauses —
  `…jimpartition.sh health-eval *` and `…jimpartition.sh identity-check *`
  — instead of the script-level wildcard; update plan Task 7's clause
  accordingly.
- **Route:** Plan
- **Relates to:** plan Task 7, DD #8
- **Resolution:** Applied 2026-07-12 — plan Task 7 now declares the two
  verb-scoped clauses; File Manifest and Constitution Check updated.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity or auth boundary — all inputs are repo-local artifacts within the developer trust boundary |
| Tampering | Yes | Finding 1 (resolved — AC #13/Tasks 2, 4). The new attribution keys (`faces_max_group=`/`fanin_group=`) admit at most a well-formed, length-capped slug list from a tampered ledger, consumed as display data only — the 028 Finding-1 bounded-value pattern |
| Repudiation | No | No issues found — AC #11's per-run ledger event is the audit trail |
| Information Disclosure | No | No issues found — health events numeric-only (AC #11), delimited quotes (AC #12), and the spec 017 AC-C2 scrub reminder at issue-edit cover the internal-only data; attribution slugs are already-public repo identifiers |
| Denial of Service | Yes | Finding 2 (resolved — DD #8 structural guard). `auto_health` + low thresholds is bounded at one health run per developer-triggered reconcile; a held completion under `require_health` inherits the bounded re-run/report-held semantics of spec 026 |
| Elevation of Privilege | Yes | Finding 4 (resolved — DD #7 recorded rationale); Finding 6 (open — verb-scope the new `jimpartition.sh` grant) |

## Artifact Misalignment

- **Finding 5 — Mismatch sensor's input claim (Notable):** Spec AC #8
  states the name-mismatch sensor "fires on the current map alone (no
  history)"; plan DD #5's `retired` match class additionally reads `old=`
  slugs from `partition finished op=rename` **ledger events** — history,
  even if not *trend* history. The retired class is the higher-value half
  (it is exactly issue #71's stalled docs-only rename), so the plan should
  keep it and the spec should say what the plan builds. Route: **Spec** —
  amend AC #8 to "requires no reconcile-event trend history; the
  docs-only-rename class may consult recorded rename events (spec 043)".
  **Resolution:** Applied 2026-07-12 — spec AC #8 reworded as proposed.

## Routing Recommendations

### Spec amendments
- Finding 1: series-grain shape-validation AC. **Applied 2026-07-12** —
  spec AC #13.
- Finding 3: unarmed-gate notice. **Applied 2026-07-12** — spec AC #5/#6.
- Finding 5: reword AC #8's "current map alone (no history)" to license
  the retired-class rename-event read. **Applied 2026-07-12** — spec AC #8.

### Plan amendments
- Finding 2: **Resolved** — DD #8 (structural read-only guard, no blueprint
  call site in the health section).
- Finding 4: **Resolved** — DD #7 (inline execution, rationale recorded).
- Finding 6: verb-scope the blueprint `jimpartition.sh` clause to
  `health-eval` + `identity-check`. **Applied 2026-07-12** — plan Task 7.

### Candidate issues
No findings routed to Issue this run.
