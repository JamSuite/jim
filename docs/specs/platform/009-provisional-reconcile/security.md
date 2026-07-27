---
spec: "docs/specs/platform/009-provisional-reconcile/spec.md"
reviewed_phases: [spec]
status: "Needs Plan Review"
date: "2026-07-27"
---

# Security Review: Provisional allocation and reconcile (unreachable-origin mode)

## Summary

**Findings:** 0 Critical · 1 Notable · 2 Advisory

Reviewed spec.md only (no plan.md yet) with the requirements-gap lens plus a full
STRIDE completeness sweep. LINDDUN is N/A — the target handles project-internal
ids/slugs/group names, no PII, credentials, or session data. The spec already
carries a strong injection-boundary AC (AC 12) and inherits platform/007's
discipline; the findings are one defense-in-depth land-path property (Notable) and
two AC-hardening clarifications (Advisory). No new secret-handling or network sink
class is introduced — provisional issuance is strictly local, and reconcile reuses
the existing shared-ref CAS.

## Coverage

- spec.md — reviewed 2026-07-27 (requirements-gap lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Handles ordinals, slugs, group names — no personal data. |
| Credentials | No | Git transport auth is environmental (SSH/config); the script never handles it, and `GIT_TERMINAL_PROMPT=0` (007) blocks mid-flow prompts. |
| Session data | No | None. |
| Internal-only | Yes | The registry logs and provisional markers are project-internal; the coordination branch is repo-internal. |
| Public | No | Nothing public-facing. The readable-slug disclosure to repo-read holders is an inherited 007 surface, not public exposure. |

## Findings

### 1. Reconcile's realize-land must inherit the allocation path's in-loop erosion re-check

- **Severity:** Notable
- **Description:** AC 4 requires reconcile to realize provisionals "over the same compare-and-swap … path a normal allocation uses." In the current allocator the *allocate* path (`alloc_cas_append`, `jimalloc.sh:709-783`) runs an in-loop byte-prefix erosion check (`:742`) before landing, but the *seed's* batch lander (`alloc_seed_land`, `:1021-1081`) — the closest existing N-record commit builder reconcile would reuse — **omits** that re-check (already tracked as issue #122 / platform/008 review Finding 2). If the plan reuses seed's drifted lander, a coordination-history truncation (force-push / revert) occurring between a provisional's offline filing and its later reconcile would go undetected, and reconcile could realize onto a truncated log — reissuing an already-consumed real ordinal, the exact reissue AC 4 and platform/007 AC 11 forbid.
- **Suggestion:** Plan reconcile's land on the erosion-guarded path. This is the security teeth behind the research Peer Feedback: factor one shared land step (tier-select + CAS + erosion re-check + baseline-arm), folding #122, so reconcile's realization is byte-for-byte as guarded as a normal allocation. Defense-in-depth; branch protection remains the primary control (007 AC 11 first-clone caveat unchanged).
- **Route:** Plan
- **Relates to:** AC 4, AC 5; platform/007 AC 11; issue #122

### 2. Make the marker→ordinal independence explicit

- **Severity:** Advisory
- **Description:** A pending provisional marker rides in a branch-writable artifact (AC 12), so its content is attacker-influenceable. AC 2 already bars a provisional identifier from the shared registry and the next-id computation — which *implies* a marker cannot dictate which real ordinal reconcile assigns, since the ordinal comes from the shared high-water under CAS (AC 8). But the property is only implicit, and it is the load-bearing guard against an injection-of-intent vector: a crafted marker attempting to force a *specific* target ordinal or a deliberate collision.
- **Suggestion:** Add a clause to AC 2 (or AC 8) stating that reconcile derives the realized ordinal solely from the shared registry's high-water under CAS, never from any field of the provisional marker. No behavior change if built as intended — the AC just makes the independence non-optional.
- **Route:** Spec
- **Relates to:** AC 2, AC 8, AC 12

### 3. Bound spurious realizations — scope reconcile's pending discovery

- **Severity:** Advisory
- **Description:** Reconcile realizes any well-formed pending marker it discovers through the consumer contract (AC 11). Because markers live in branch-writable artifacts, anyone who can write the tree/branch can plant one, and reconcile will realize it — consuming a real ordinal (a harmless gap, or a spurious issue). This is **not** a privilege escalation: ids and registry records are never authorization or integrity anchors (platform/007 non-goal), so a forged marker grants nothing. But an unbounded or arbitrary-tree discovery scan would let a crafted tree inflate the registry with spurious real allocations.
- **Suggestion:** Require the consumer contract (AC 11) to scope discovery to the consumer's genuine artifact set (e.g. the issue collection under its configured root), not an arbitrary tree walk — bounding realizations to real pending work. State the trust model in the spec: markers are self-asserted, the same trust model as issue files today, and ids carry no authority.
- **Route:** Spec
- **Relates to:** AC 11; platform/007 non-goals (ids not auth/integrity anchors)

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 3 — provisional markers are self-asserted in branch-writable artifacts; ids carry no authority, so a forged marker at most consumes an ordinal. |
| Tampering | Yes | Finding 1 (erosion re-check gap in the realize-land). The branch-writable coordination point and markers are covered by AC 12 revalidation + Finding 2. |
| Repudiation | N/A | Registry records are advisory provenance by platform/007 non-goal; no authentication, authorization, or audit decision rides on them, and #115 adds no audit requirement. |
| Information Disclosure | Yes | No finding. Realization publishes the readable slug to the coordination branch exactly as 007 does; provisional mode *delays* that publication (local until reconcile) — a slight net reduction. The reconcile preview echoes provisional→real mappings to the developer by design. |
| Denial of Service | No | No issues found. Reconcile realizes N pending markers in one bounded CAS commit; N tracks real pending volume, and the registry is trivially small at jim scale. |
| Elevation of Privilege | N/A | Ids and registry records are never authorization or integrity anchors (platform/007 non-goal); provisional mode and reconcile grant no capability. |

## Routing Recommendations

### Spec amendments
- Finding 2 — assert marker→ordinal independence in AC 2/AC 8.
- Finding 3 — scope the consumer contract's discovery (AC 11) to the genuine artifact set; state the self-asserted-marker trust model.

### Plan amendments
- Finding 1 — plan reconcile's realize-land on the erosion-guarded shared land step (fold #122); do not reuse seed's erosion-omitting inline copy.

### Candidate issues
- None — no finding routes to `Issue` this run.
