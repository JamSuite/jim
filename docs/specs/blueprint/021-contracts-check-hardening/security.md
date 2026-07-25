---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-23"
---

# Security Review: Harden contracts-check

## Summary

**Findings:** 0 Critical · 0 Notable · 1 Advisory (addressed in plan)

Reviewed spec.md (requirements-gap lens) and plan.md (design-flaw lens) for a
refactor of jim's deterministic, read-only verify engine. STRIDE swept in full;
LINDDUN N/A (no PII, credentials, or session data). Net-positive for security
posture — AC #8 pins the existing location-only evidence guard, and DD 2
*reduces* input surface by dropping the redundant `<specs-root>` positional. The
single Advisory (self-edge sanitization) is now addressed by the plan's DD 1, and
no spec↔plan misalignment surfaced.

## Coverage

- spec.md — reviewed 2026-07-23 (requirements-gap lens)
- plan.md — reviewed 2026-07-23 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | — |
| Credentials | No | The engine never handles secrets; it reads project specs/code and emits location facts. |
| Session data | No | — |
| Internal-only | Yes | Project-internal spec paths, group slugs, contract-graph edges, and source file locations. |
| Public | No | — |

## Findings

### 1. Self-edge HYGIENE emission must preserve column-shift sanitization

- **Severity:** Advisory
- **Description:** AC #5 requires a self-edge (consumer == provider) to surface
  as a HYGIENE row rather than a silent drop. The existing HYGIENE branch in
  `cmd_edges` (`jimverify.sh:787`) emits the dropped row through `san()`
  (tab/newline/CR stripping, 512-char cap) precisely so a crafted Contract Graph
  cell cannot shift downstream TSV columns — the column-shift guard recorded in
  ARCHITECTURE.md (`:385`, the sanitize-every-emitted-field rule). If the new
  self-pair guard emits its dropped row through a separate/raw path instead of
  that same `san()` emission, a map row bearing embedded tabs or newlines could
  shift columns or smuggle content into the HYGIENE channel.
- **Suggestion:** Implement the self-pair guard as an extension of the existing
  slug branch in `cmd_edges` — HYGIENE-emit via the same `san(trim($0))` call
  when `c1 == c3` — rather than a parallel echo, so there is exactly one
  sanitized HYGIENE emission path. Add a test asserting a self-pair row carrying
  an embedded control character emits sanitized (no column shift), mirroring the
  existing `crafted_cell_hygiene` case.
- **Route:** Plan
- **Relates to:** AC #5
- **Addressed by:** plan.md DD 1 — the guard is the `&& c1 != c3` extension of
  the existing slug branch at `cmd_edges:786`, so a self-pair falls to the same
  `san(trim($0))` HYGIENE emission (one sanitized path); plan Task 3 adds the
  control-character self-pair sanitization test.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | Deterministic local script; no identity or authentication surface. |
| Tampering | No | Map/blueprint content is data, never executed; the resolver (`jimfile.sh path blueprint`) is a pure path-printer; group slugs are validated on both the caller (`:906/:956/:957`) and resolver (`jimfile.sh:672`) sides; the never-execute-config boundary is untouched. DD 2 drops the redundant `<specs-root>` positional, reducing external input surface. |
| Repudiation | N/A | Read-only measurement tool; no audit-trail obligation (the ledger is out of scope and unchanged). |
| Information Disclosure | Yes | Finding 1 (preserve HYGIENE sanitization on the self-pair drop) — addressed by plan DD 1. Net-positive: AC #8 pins the existing location-only edge-outcome evidence guard (matched source content never emitted). |
| Denial of Service | No | The self-pair guard is an O(1) per-row string compare; the existing CROSS-REF per-pair output cap is unchanged. |
| Elevation of Privilege | N/A | No privilege model; the resolver executes nothing (emits a path string only). |

## Artifact Misalignment

None — the plan's design preserves every boundary the spec asserts: AC #5
(self-edge → HYGIENE) ↔ DD 1's `san()` reuse; AC #8 (location-only evidence) ↔
Task 8's test; Finding 1 ↔ DD 1. The interface change (DD 2) reduces surface and
introduces no new trust boundary.

## Routing Recommendations

### Plan amendments
- Finding 1 — **addressed** in plan.md DD 1 (self-pair routes through the
  existing `san()` HYGIENE emission) and Task 3 (control-character test). No
  further action required.

<!-- No findings route to Spec or Issue. -->
