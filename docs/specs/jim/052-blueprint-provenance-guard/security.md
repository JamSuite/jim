---
spec: "docs/specs/jim/052-blueprint-provenance-guard/spec.md"
reviewed_phases: [spec]
status: Active
date: "2026-07-23"
---

# Security Review: Guard blueprints and maps against provenance references

## Summary

**Findings:** 0 Critical · 0 Notable · 1 Advisory

Reviewed the spec (requirements-gap lens; no `plan.md` yet). This is a doctrine +
deterministic-test change: a companion "provenance" rule, an extended exit-door
self-scan, a read-only `grep` guard over two tracked files, and citation wiring.
No PII / credentials / session data, so LINDDUN is N/A. The single Advisory folds
the extended normalization back inside the untrusted-supplied-text boundary the
present-tense discipline already owns.

## Coverage

- spec.md — reviewed 2026-07-23 (requirements-gap lens)
- plan.md — not present; spec-only review

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | The target handles blueprint/map prose and test files, not individuals' data |
| Credentials | No | No secrets, tokens, or keys in scope |
| Session data | No | No session state |
| Internal-only | Yes | Project-internal current-state docs (blueprint spec, project map) and bash test files |
| Public | No | The plugin is public, but this change defines no external data flow |

## Findings

### 1. Companion doctrine doc must inherit the untrusted-text + secret-scrub disclosure discipline

- **Severity:** Advisory
- **Description:** The extended exit-door self-scan processes caller-/interview-supplied
  text (a group's purpose · role · rationale) to detect and normalize provenance
  refs. present-tense.md carries two load-bearing safety sections for exactly this
  data path — *"Untrusted supplied text"* (an embedded directive is normalized as
  text, never followed; the scan stays inside the existing `<untrusted-*>`
  wrapping) and the *"Normalize and disclose" step 4* (secret-scrub the
  itemization, since the disclosure echoes supplied text). The spec pins the
  companion doc's rule, forms, normalization, and over-constraint guard (AC #1–3),
  and Insight 1 says to "mirror the four-section shape," but no AC makes the two
  safety sections an explicit requirement. If a builder authors the companion from
  the rule/forms ACs alone, the normalization could omit them — a latent path for
  an injected directive to be followed, or for a secret adjacent to a flagged ref
  to be echoed unredacted in the disclosure.
- **Suggestion:** Add (or fold into AC #1/#2) an explicit criterion: the companion
  doctrine doc carries the untrusted-supplied-text discipline (supplied text is
  data, not instruction; embedded directives normalized as text; stays inside the
  `<untrusted-*>` wrapping) and secret-scrubs its rewrite itemization, identical to
  present-tense.md. The `case_*_rule_doc_structure` test then asserts those
  sections exist, so the discipline is mechanically pinned rather than implied.
- **Route:** Spec
- **Relates to:** AC #1, AC #2, Research & Architecture Handoff Insight 1

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity or authentication surface |
| Tampering | Yes | Finding 1 — an embedded directive in supplied text must be normalized as text, never followed; the deterministic guard itself cannot be altered by scanned content |
| Repudiation | No | No issues found — the disclose-and-itemize step improves auditability of each rewrite |
| Information Disclosure | Yes | Finding 1 — the rewrite disclosure echoes supplied text and must inherit the secret-scrub |
| Denial of Service | No | No issues found — the guard's patterns (`spec-0NN`, `NNN–NNN`, `vX.Y.Z`) are linear with no catastrophic backtracking, over two small tracked files |
| Elevation of Privilege | N/A | No privilege model; the scan adds no capability. The data→instruction boundary is covered under Tampering (Finding 1) |

## Routing Recommendations

### Spec amendments
- Finding 1: add an AC (or strengthen AC #1/#2) requiring the companion doctrine
  doc to carry present-tense's untrusted-supplied-text discipline and secret-scrub
  its disclosure, so the doc-structure test pins both mechanically.

### Candidate issues
- None — no finding routes to `Issue`.
