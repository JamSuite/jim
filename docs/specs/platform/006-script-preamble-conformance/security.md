---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-26"
---

# Security Review: Script-preamble conformance and invariant restoration

## Summary

**Findings:** 0 Critical · 1 Notable (routed & resolved in plan DD5) · 0 Advisory  (dual-lens re-run)

Re-reviewed under the dual lens now that plan.md exists (requirements-gap + design-flaw). This is build-time developer tooling — a `set -uo pipefail` preamble on three scripts, a bash guard test sweeping first-party files, a blueprint restore via `/jim:blueprint`, and an issue closure. No runtime, external input, trust boundary, privilege change, or sensitive data, so most STRIDE stays N/A and LINDDUN is inactive. The plan resolves the spec-phase safe-path advisory (now Finding 2); the plan-phase lens surfaces one Notable design gap — the guard can pass vacuously on empty enumeration (Finding 1).

## Coverage

- spec.md — reviewed 2026-07-26 (requirements-gap lens)
- plan.md — reviewed 2026-07-26 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | No personal data anywhere in scope. |
| Credentials | No | No secrets, tokens, or keys handled. |
| Session data | No | No sessions or runtime state. |
| Internal-only | Yes | First-party shell scripts, test files, and the platform `000-blueprint` doc; developer-facing build tooling only. |
| Public | No | Nothing published externally. |

## Findings

### 1. Guard test can pass vacuously when file enumeration yields nothing

- **Severity:** Notable
- **Description:** The plan's guard (Interface Contracts) loops `for f in "$REPO_ROOT"/skills/*/scripts/*.sh …`, guards each hit with `[[ -e ]]`, and asserts per examined file. If the enumeration yields zero files — `REPO_ROOT` unset/misresolved, the suite run from an unexpected context, or a future directory reorg that moves scripts out of the three globbed roots — the loop makes zero `assert_eq` calls, the case reports PASS, and the suite is green. A guard that passes when it examined nothing silently voids the entire mechanical protection this spec adds, defeating AC2's intent ("fails when any script omits the preamble"). This is a spec↔plan robustness gap: the spec wants fail-closed detection; the plan's design fails *open* on empty enumeration.
- **Suggestion:** Make the guard fail-closed on empty enumeration — count the files it examined and assert the count meets a floor (e.g. `assert` examined ≥ a known minimum, or ≥ 1 per globbed root) so a zero-file sweep fails loudly instead of passing green. Fold this into the Interface Contract / Design Decision 4.
- **Route:** Plan
- **Relates to:** AC #2
- **Status:** Routed & resolved — folded into plan Design Decision 5 and the Interface Contract: the guard now asserts each globbed root (`skills/*/scripts`, `tests/`, `scripts/`) is non-empty, so an empty sweep fails closed.

### 2. Guard test enumerates and greps first-party paths safely — Resolved by plan

- **Severity:** Advisory
- **Status:** Resolved. The plan's Design Decision 4 and Interface Contract anchor the sweep to absolute `$REPO_ROOT` paths (operands begin with `/`, so a filename is never mistaken for an option) and quote every path expansion, addressing the spec-phase safe-path concern. No further action.
- **Route:** Plan (closed)
- **Relates to:** AC #2

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity, authentication, or actor-impersonation surface — build-time tooling. |
| Tampering | Yes | The guard is a drift-detection control over the script corpus, but as designed it can silently fail to detect (Finding 1) — the control must fail-closed. |
| Repudiation | N/A | No user actions requiring an audit trail; the ledger stage-events are jim's normal instrumentation, out of scope here. |
| Information Disclosure | No | Failure output prints only repo-relative paths of first-party files (Finding 1); no secrets, PII, or sensitive data leak. |
| Denial of Service | N/A | The sweep greps ~24 scoped files; no unbounded resource use and no external attacker surface. |
| Elevation of Privilege | N/A | Scripts run as the invoking user; no setuid, capability grant, or privilege change. |

## Routing Recommendations

### Plan amendments
- Finding 1 (Notable) — Routed & resolved: plan Design Decision 5 + the Interface Contract now assert each globbed root is non-empty (fail-closed).
- Finding 2 (Advisory) — Resolved: safe path handling is already specified by the plan's Design Decision 4; no amendment needed.
