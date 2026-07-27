---
spec: "docs/specs/platform/009-provisional-reconcile/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-27"
---

# Security Review: Provisional allocation and reconcile (unreachable-origin mode)

## Summary

**Findings:** 0 Critical · 1 Notable (resolved) · 3 Advisory · **status: Active**

Dual-lens review — spec.md (2026-07-27, requirements-gap) and plan.md (2026-07-27,
design-flaw), plus a STRIDE re-sweep and an artifact-misalignment pass. LINDDUN is
N/A — project-internal ids/slugs/group names, no PII, credentials, or session
data. **Plan-phase outcome: the plan resolves the spec-phase Notable (Finding 1)**
— DD 2 consolidates the erosion-guarded publish (folding #122) and Tasks 1/5 build
reconcile on it, making AC 4's "same guarantees" literal. The two spec-phase
Advisories (Findings 2, 3) were folded into the spec ACs and the plan preserves
them (DD 5, DD 7, Task 4). One new plan-phase Advisory (Finding 4 — a
defense-in-depth within-batch dedup guard) is raised. No misalignment: the plan
satisfies every spec AC, and DD 5 supersedes a non-binding *Insight*, not an AC.
No new secret-handling or network sink class — provisional issuance is strictly
local; reconcile reuses the shared-ref CAS.

## Coverage

- spec.md — reviewed 2026-07-27 (requirements-gap lens)
- plan.md — reviewed 2026-07-27 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Handles ordinals, slugs, group names — no personal data. |
| Credentials | No | Git transport auth is environmental (SSH/config); the script never handles it, and `GIT_TERMINAL_PROMPT=0` (007) blocks mid-flow prompts. |
| Session data | No | None. |
| Internal-only | Yes | The registry logs and provisional markers are project-internal; the coordination branch is repo-internal. |
| Public | No | Nothing public-facing. The readable-slug disclosure to repo-read holders is an inherited 007 surface, not public exposure. |

## Findings

### 1. Reconcile's realize-publish must inherit the allocation path's in-loop erosion re-check

- **Severity:** Notable
- **Description:** AC 4 requires reconcile to realize provisionals "over the same compare-and-swap … path a normal allocation uses." In the current allocator the *allocate* path (`alloc_cas_append`, `jimalloc.sh:709-783`) runs an in-loop byte-prefix erosion check (`:742`) before publishing, but the *seed's* batch publisher (`jimalloc.sh:1021-1081`) — the closest existing N-record commit builder reconcile would reuse — **omits** that re-check (already tracked as issue #122 / platform/008 review Finding 2). If the plan reuses seed's drifted publisher, a coordination-history truncation (force-push / revert) occurring between a provisional's offline filing and its later reconcile would go undetected, and reconcile could realize onto a truncated log — reissuing an already-consumed real ordinal, the exact reissue AC 4 and platform/007 AC 11 forbid.
- **Suggestion:** Plan reconcile's publish on the erosion-guarded path. This is the security teeth behind the research Peer Feedback: factor one shared publish step (tier-select + CAS + erosion re-check + baseline-arm), folding #122, so reconcile's realization is byte-for-byte as guarded as a normal allocation. Defense-in-depth; branch protection remains the primary control (007 AC 11 first-clone caveat unchanged).
- **Route:** Plan
- **Relates to:** AC 4, AC 5; platform/007 AC 11; issue #122
- **Resolution (plan phase):** Resolved. Plan DD 2 factors one erosion-guarded `alloc_publish` shared by seed and reconcile; Task 1 migrates seed onto it (closing #122) with a seed-eroded-history fixture, and Task 5 publishes reconcile through it. Reconcile's realization is now byte-for-byte as guarded as a normal allocation.

### 2. Make the marker→ordinal independence explicit

- **Severity:** Advisory
- **Description:** A pending provisional marker rides in a branch-writable artifact (AC 12), so its content is attacker-influenceable. AC 2 already bars a provisional identifier from the shared registry and the next-id computation — which *implies* a marker cannot dictate which real ordinal reconcile assigns, since the ordinal comes from the shared high-water under CAS (AC 8). But the property is only implicit, and it is the load-bearing guard against an injection-of-intent vector: a crafted marker attempting to force a *specific* target ordinal or a deliberate collision.
- **Suggestion:** Add a clause to AC 2 (or AC 8) stating that reconcile derives the realized ordinal solely from the shared registry's high-water under CAS, never from any field of the provisional marker. No behavior change if built as intended — the AC just makes the independence non-optional.
- **Route:** Spec
- **Relates to:** AC 2, AC 8, AC 12
- **Resolution (plan phase):** Folded into AC 8 (spec) and preserved by plan DD 5 + Task 4 (the realized ordinal derives solely from the shared high-water; a crafted marker cannot force it).

### 3. Bound spurious realizations — scope reconcile's pending discovery

- **Severity:** Advisory
- **Description:** Reconcile realizes any well-formed pending marker it discovers through the consumer contract (AC 11). Because markers live in branch-writable artifacts, anyone who can write the tree/branch can plant one, and reconcile will realize it — consuming a real ordinal (a harmless gap, or a spurious issue). This is **not** a privilege escalation: ids and registry records are never authorization or integrity anchors (platform/007 non-goal), so a forged marker grants nothing. But an unbounded or arbitrary-tree discovery scan would let a crafted tree inflate the registry with spurious real allocations.
- **Suggestion:** Require the consumer contract (AC 11) to scope discovery to the consumer's genuine artifact set (e.g. the issue collection under its configured root), not an arbitrary tree walk — bounding realizations to real pending work. State the trust model in the spec: markers are self-asserted, the same trust model as issue files today, and ids carry no authority.
- **Route:** Spec
- **Relates to:** AC 11; platform/007 non-goals (ids not auth/integrity anchors)
- **Resolution (plan phase):** Folded into AC 11 (spec) and preserved by plan DD 7 + Task 4/7 (discovery scoped to the consumer's genuine artifact set; markers self-asserted, ids carry no authority).

### 4. Reconcile should guard against duplicate provisional identities within a batch

- **Severity:** Advisory
- **Description:** The plan's unique-by-construction resume model (DD 5) keys reconcile's realization on a globally-unique provisional identity the *consumer* supplies (AC 11 contract obligation). The mechanism cannot verify global uniqueness — it sees only its registry and the pending set. If a buggy or hostile consumer (pending markers ride in branch-writable artifacts) surfaces **two** pending entries sharing one identity, reconcile's keyed find-or-allocate would realize the first and then treat the second as "already realized," silently collapsing two distinct provisionals onto one real ordinal. Not a privilege escalation — ids carry no authority — but a data-integrity confusion the contract's uniqueness guarantee is meant to prevent.
- **Suggestion:** Add a cheap defense-in-depth check to the reconcile mechanism: halt-and-report on a duplicate provisional identity *within a single pending batch* (which the mechanism can see), rather than silently realizing one. Cross-batch uniqueness stays the consumer's AC 11 obligation. A within-batch adversarial fixture (two pending entries, same identity → halt) covers it.
- **Route:** Plan
- **Relates to:** AC 11, AC 6; plan DD 5; Finding 3
- **Resolution:** Folded into plan Task 4 — halt-and-report on a within-batch duplicate provisional identity, with an adversarial fixture.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 3 — provisional markers are self-asserted in branch-writable artifacts; ids carry no authority, so a forged marker at most consumes an ordinal. |
| Tampering | Yes | Finding 1 (erosion re-check gap) — **resolved** by plan DD 2. Finding 4 (within-batch duplicate-identity guard). The branch-writable coordination point and markers are covered by AC 12 revalidation + Finding 2. |
| Repudiation | N/A | Registry records are advisory provenance by platform/007 non-goal; no authentication, authorization, or audit decision rides on them, and #115 adds no audit requirement. |
| Information Disclosure | Yes | No finding. Realization publishes the readable slug to the coordination branch exactly as 007 does; provisional mode *delays* that publication (local until reconcile) — a slight net reduction. The reconcile preview echoes provisional→real mappings to the developer by design. |
| Denial of Service | No | No issues found. Reconcile realizes N pending markers in one bounded CAS commit; N tracks real pending volume, and the registry is trivially small at jim scale. |
| Elevation of Privilege | N/A | Ids and registry records are never authorization or integrity anchors (platform/007 non-goal); provisional mode and reconcile grant no capability. |

## Artifact Misalignment

No misalignment. The plan satisfies every spec AC, and it explicitly *resolves*
the spec-phase Notable (AC 4 / Finding 1) via the consolidated erosion-guarded
publish rather than the weaker path the finding warned against. Plan DD 5
supersedes spec **Insight 1**'s "reconcile suffixes on collision" note — but an
Insight is non-binding architect context, not an AC, so superseding it is the
plan's prerogative, and the replacement (unique-by-construction) still satisfies
AC 6 and AC 11.

## Routing Recommendations

### Spec amendments
- None outstanding — Findings 2 and 3 were folded into the spec ACs (AC 8, AC 11) at the spec phase and the plan preserves them.

### Plan amendments
- Finding 4 (new, Advisory) — add a within-batch duplicate-provisional-identity guard to the reconcile mechanism (halt-and-report), with an adversarial fixture. Best folded into Task 4.

### Candidate issues
- None — no finding routes to `Issue` this run. Finding 1 is resolved by the plan; Finding 4 is a plan-local hardening for the coder.
