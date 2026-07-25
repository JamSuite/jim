---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-13"
---

# Security Review: Compute reconcile face-size counters deterministically

## Summary

**Findings:** 0 Critical · 1 Notable (**routed & resolved**) · 0 Advisory

The single Notable finding was routed back into spec.md as a new acceptance
criterion (group-slug validation before path construction) with matching test
coverage; status is therefore `Active`. The record of the finding is retained
below for audit trail.

**Plan-phase update (2026-07-13, dual lens):** the design-flaw pass over
`plan.md` surfaced **no new findings**. The plan is purely additive — the new
`faces-aggregate` verb reuses `cmd_faces` and `cmd_health` read-only, adds no
dependency, and carries no face `text`/`params` into output — and it **bakes
Finding 1 into the design**: DD #4 applies the `^[a-z0-9][a-z0-9-]*$` guard
before path construction (mirroring `cmd_contracts_check`) and Task 1 asserts a
crafted/`..`-bearing heading yields no file access. No spec↔plan misalignment
(§ Artifact Misalignment).

Reviewed spec.md (requirements-gap lens) and plan.md (design-flaw lens) plus a
full STRIDE sweep. This refactor is **net security-positive**: it removes an LLM
string-assembly step over shape-validated, security-relevant ledger values and
replaces it with deterministic script, so directives embedded in untrusted face
content can no longer bind the counter assembly (the capability is absent, not
merely forbidden). The one Notable finding is a preserved-invariant requirement:
the new aggregator resolves per-group blueprint paths and must carry forward the
established slug-guard-before-path-use convention. LINDDUN is not active (no PII,
credentials, or session data).

## Coverage

- spec.md — reviewed 2026-07-13 (requirements-gap lens)
- plan.md — reviewed 2026-07-13 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Counters are integer measurements and project-internal group slugs. |
| Credentials | No | The aggregator emits only counts + slugs; it never carries face `text`/`params` content into output, so a secret-looking value in a face entry cannot reach a counter. |
| Session data | No | None handled. |
| Internal-only | Yes | Group slugs and integer face/fan-in counters — dev telemetry persisted to the specs-root ledger. |
| Public | No | Not published; internal development artifacts. |

## Findings

### 1. Aggregator must slug-validate group names before constructing blueprint paths

- **Severity:** Notable
- **Description:** The aggregator enumerates blueprint-bearing groups (via the
  map's `## Groups` headings) and resolves each group's face as
  `<specs-root>/<group>/000-blueprint/spec.md` (AC #1). The map is **untrusted
  data** in jim's threat model (`reconcile-methodology.md` § Inputs and the
  trust boundary), and `groups_of` (jimverify.sh:796) is deliberately permissive
  — it emits the raw first token of each `###` heading with no slug validation.
  Every existing caller that turns a group name into a path applies the
  `^[a-z0-9][a-z0-9-]*$` guard first (`cmd_contracts_check` jimverify.sh:905 and
  957) precisely to prevent a crafted heading (e.g. `### ../../something`) from
  driving path traversal. The spec does not yet state this guard as a
  requirement, so a new aggregator that iterated `groups_of` output directly
  would reintroduce the traversal exposure the sibling verbs already close.
- **Suggestion:** Add an acceptance criterion: the aggregator validates each
  group token against `^[a-z0-9][a-z0-9-]*$` **before** using it in path
  construction, skipping (and, consistent with the map-hygiene degradation
  pattern, not resolving) any token that fails — mirroring `cmd_contracts_check`.
  A test case should assert that a map carrying a non-slug/`..`-bearing group
  heading yields no file access for that token.
- **Route:** Spec
- **Relates to:** AC #1
- **Status:** Resolved — spec.md gained an AC requiring the aggregator to
  validate each group token against `^[a-z0-9][a-z0-9-]*$` before path
  construction (skip on failure, no file access), and the test-coverage AC now
  includes a crafted/`..`-bearing heading case. **Plan-confirmed:** plan.md
  DD #4 implements the guard (mirroring `cmd_contracts_check`) and Task 1 carries
  the no-file-access test.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No authentication or actor-identity surface; group identities are slug-validated map data, not spoofable principals. |
| Tampering | Yes | Finding 1 (resolved) — a crafted map `###` heading could drive path traversal absent the slug guard; plan.md DD #4/Task 1 apply the guard before path construction. Conversely, tampering with face **content** can no longer bind the counter assembly, since the deterministic script has no instruction-following capability (net improvement over the LLM path). |
| Repudiation | No | Counters are deterministic and land on the append-oriented specs-root ledger (audit trail); determinism improves reproducibility vs the prior LLM counting. |
| Information Disclosure | No | Output is integer counts + validated group slugs only; face `text`/`params` never reach a counter, so the "never persist a secret" invariant holds by construction (enforced by the slug/integer-only shape in AC #4 / AC #7; plan DD #5 confirms in-script shaping). |
| Denial of Service | No | One bounded awk pass per blueprint-bearing group — same profile as the existing `cmd_contracts_check`/`cmd_health` per-group reads — over developer-authored repo files; the ≤256-byte attribution cap (AC #4) bounds output. |
| Elevation of Privilege | N/A | No privilege model; the script runs at the developer's existing shell privilege with no capability change. |

## Artifact Misalignment

Dual-lens (spec + plan) — no misalignment. The plan preserves every
security-relevant spec assertion:

- Spec AC #2 (slug guard before path construction) → plan DD #4 + Task 1.
- Spec AC #4 (attribution values sorted/comma-joined slugs, ≤256 bytes,
  script-emitted) → plan DD #5 (in-script sort · join · cap · emit-when->0).
- Spec AC #7 (ledger contract unchanged; consumers insulated) → plan reuses
  `cmd_health`/`cmd_faces` read-only, copies verbatim, and lists the downstream
  consumers as Out of Scope (unchanged).

## Routing Recommendations

### Spec amendments
- Finding 1 (**applied 2026-07-13**): spec.md gained an AC requiring the
  aggregator to slug-validate each group token (`^[a-z0-9][a-z0-9-]*$`) before
  path construction and skip failing tokens, with a test asserting no file
  access for a crafted heading — mirroring the existing `cmd_contracts_check`
  convention.
