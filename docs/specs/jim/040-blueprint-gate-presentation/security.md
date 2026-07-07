---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-07"
---

# Security Review: Blueprint-surface approval-gate presentation

## Summary

**Findings:** 0 Critical · 1 Notable · 4 Advisory

Dual-lens review (spec + plan). The Notable and both spec-phase Advisories are
**resolved** (folded into the spec / carried into the plan's rule-doc structure).
The plan adds no blocking findings: it honors the folded sec constraints, adds no
new `!`-injection or `allowed-tools` call-site (no permission creep), and uses
only bash/POSIX. Two new Advisories concern the regression test's precision and a
spec↔plan wording reconciliation. LINDDUN not run (no PII / Credentials /
Session data).

## Coverage

- spec.md — reviewed 2026-07-07 (requirements-gap lens)
- plan.md — reviewed 2026-07-07 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | jim's own skill/artifact text; no individual data. |
| Credentials | No | Feature manages none; scanned draft content may *incidentally* contain secret-looking values — Finding 1 (resolved). |
| Session data | No | None. |
| Internal-only | Yes | Blueprint / map / partition-proposal drafts, ledger, spec content. |
| Public | No | Artifacts follow the repo's visibility; scrub reminder is the existing control. |

## Findings

### 1. Reviewable-file write can bypass the secret-scrub that guards the final artifact

- **Severity:** Notable
- **Status:** Resolved — folded into spec (safety AC, sec Finding 1) and carried into the plan's `gate-presentation.md` `## When content exceeds ~20 lines` structure (plan Interface Contract + task 2).
- **Description:** A raw U4 diff / partition/reconcile evidence written verbatim to a reviewable file is a new persistence path the secret-scrub was designed to keep secret-looking values out of.
- **Suggestion:** Reviewable-file write applies the same secret-scrub + untrusted-evidence handling as the final artifact; summary reproduces scrubbed content only; session/repo-scoped location.
- **Route:** Spec
- **Relates to:** AC 2a, AC 5

### 2. Untrusted-evidence delimiting must survive into the summary and the reviewable file

- **Severity:** Advisory
- **Status:** Resolved — folded into spec (safety AC, sec Finding 2); the plan's rule-doc structure keeps untrusted evidence delimited in both file and summary (task 2).
- **Description:** U3a fork / reconcile / partition quote untrusted content only inside delimited blocks; the verbatim summary must not launder it into trusted prose.
- **Suggestion:** State the delimiting requirement in the canonical rule for both file and summary.
- **Route:** Spec
- **Relates to:** AC 2b, AC 3

### 3. Decline cleanup must be best-effort and non-fatal

- **Severity:** Advisory
- **Status:** Addressed in plan — DD4 (scratchpad working file) + the rule doc's `## On decline` (best-effort removal), task 2.
- **Description:** Removing a pre-approval reviewable file on decline must not become a new failure mode.
- **Suggestion:** Specify cleanup as best-effort / non-fatal; do not disturb the decline discipline.
- **Route:** Plan
- **Relates to:** AC 4

### 4. Regression test should assert per-file pointer counts, not mere presence

- **Severity:** Advisory
- **Status:** Open — routes to plan.
- **Description:** Task 7's reference-presence test asserts the token appears in each checked file. `blueprint/SKILL.md` carries **six** inline pointers (one per gate); a bare presence check passes even if five of six survive and one gate silently loses its pointer — the exact drift AC 6 exists to catch.
- **Suggestion:** Have `tests/gatepresentation.sh` assert the expected per-file count (`blueprint/SKILL.md` ≥ 6; others ≥ 1), mirroring task 3's own `grep -c … -ge 6` verify, so a single dropped gate pointer fails the suite.
- **Route:** Plan
- **Relates to:** AC 6, task 7

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity/authN surface; single local trusted developer at the gate. |
| Tampering | Yes | Integrity of the reviewable-file → committed-artifact path: a cleared/truncated file must never yield an empty commit (AC 5, plan `## Data safety` / `test -s`). |
| Repudiation | N/A | Ledger `started`/`finished` boundaries unchanged; no new action to deny. |
| Information Disclosure | Yes | Findings 1, 2 (resolved) — the reviewable file / summary as a draft-content persistence path. |
| Denial of Service | N/A | One extra file write + summary per gate; no resource-exhaustion vector. |
| Elevation of Privilege | N/A | Plan lens confirms: no new `!`-injection or `allowed-tools` call-site is added (Constitution Check), so the fix grants no new capability. |

## Artifact Misalignment

- **Finding 5 — "no orphan survives" (spec) vs "best-effort" cleanup (plan):**
  Spec AC 4 states declining *removes* the pre-approval file so no orphaned
  artifact survives; the plan (DD4, sec Finding 3) makes removal *best-effort*.
  These reconcile only because the reviewable file is a **session-ephemeral**
  scratchpad working file — a failed unlink leaves nothing in the repo or beyond
  the session. Advisory. **Route: Plan** — state that reconciliation explicitly
  in the rule doc's `## On decline` (the scratchpad is session-ephemeral, so
  best-effort cleanup still satisfies "no orphan survives"), so the two artifacts
  do not read as contradictory.

## Routing Recommendations

### Spec amendments
- Findings 1, 2 — resolved (already folded into the spec). No further action.

### Plan amendments
- Finding 3 — resolved (addressed in the plan's `## On decline`). No further action.
- Finding 4 — strengthen `tests/gatepresentation.sh` (task 7) to assert per-file pointer counts, not mere presence.
- Finding 5 — state the ephemeral-scratchpad reconciliation explicitly in the rule doc's `## On decline`.
