---
spec: "docs/specs/sdlc/018-finish-coordinated-spec-identity/spec.md"
reviewed_phases: [spec]
status: "Needs Plan Review"
date: "2026-07-31"
---

# Security Review: Finish coordinated spec identity

## Summary

**Findings:** 0 Critical · 2 Notable · 1 Advisory

Reviewed `spec.md` (requirements-gap lens; no `plan.md` exists yet). This spec
exists to close two recorded security regressions on the id-coordination
surface, and its ACs encode the fixes soundly; the findings below are seams
the ACs as written leave open, not flaws in the remediation direction. STRIDE
swept in full; LINDDUN inactive (no PII, credentials, or session data in
scope).

## Coverage

- spec.md — reviewed 2026-07-31 (requirements-gap lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | The registry's pre-existing `who` provenance token (from `git config user.name`) is out of this spec's scope and unchanged |
| Credentials | No | — |
| Session data | No | — |
| Internal-only | Yes | Registry allocation records, spec ordinals and provisional tokens, ledger `moved=` mappings |
| Public | Yes | Repo docs the citation sweep rewrites and the AC 14 docs pass touches |

## Findings

### 1. Padding-variant spellings can still split one ordinal identity inside the registry

- **Severity:** Notable
- **Description:** AC 4 normalizes what the allocator *reports*, and AC 3
  makes tree occupancy numeric — but the spec is silent on whether two
  log-resident spellings of one ordinal (`sdlc/18` vs `sdlc/018`, reachable
  via a crafted record on the push-writable branch) are one identity for the
  realize path's keyed find-or-allocate readback and for `resolve` replay. A
  resumed realization that must find its own prior record, or a
  fold-vs-resolve disagreement over spelling, re-opens the duplicate-issue
  seam the spec closes elsewhere.
- **Suggestion:** add the requirement that ordinal comparison is numeric at
  every site the flow compares ordinals — tree occupancy, resolve replay, and
  the realize key readback — so two spellings of one ordinal are one identity
  everywhere; fixture a resume against a log holding an unpadded record.
- **Route:** Spec
- **Relates to:** AC 3, AC 4, and inherited `sdlc/017` AC 7 (via AC 1)

### 2. The widened citation sweep is the flow's first write path not enumerated from git

- **Severity:** Notable
- **Description:** AC 12's third clause extends the sweep beyond
  `git ls-files` output to an uncommitted realized directory's own files.
  Every other rewrite target in this flow is enumerated from tracked content;
  an untracked pending directory is attacker-shapeable in ways tracked
  content is not (e.g. symlinked entries), and the spec states the sweep-or-
  warn requirement without a containment bound.
- **Suggestion:** at plan time, confine the widened enumeration to the
  realized spec directory itself and pass each target through the existing
  write-containment discipline (worktree-contained realpath before any edit —
  the `rewrite-identity` precedent) so an untracked directory cannot direct a
  rewrite outside the worktree.
- **Route:** Plan
- **Relates to:** AC 12

### 3. The shared occupancy predicate should degrade per-identity on junk siblings

- **Severity:** Advisory
- **Description:** the new predicate parses sibling directory basenames
  numerically; the tree is branch-writable by contributors, so a non-numeric
  or over-wide basename must not error the whole batch or, worse, be
  silently treated as unoccupied space.
- **Suggestion:** skip malformed sibling basenames per the fold's
  skip-malformed discipline, and keep the failure surface per-identity —
  matching the realizer's existing halt semantics.
- **Route:** Plan
- **Relates to:** AC 3

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No authentication surface in scope; a registry record's `who` is advisory provenance, never an auth basis (`platform/007` non-goal, per `ARCHITECTURE.md` → Security Considerations) |
| Tampering | Yes | The push-writable registry / branch-writable tree is the core vector; ACs 2–5 and 9 close its silent variants; residual spelling seam is Finding 1 |
| Repudiation | Yes | The durable `moved=` mapping is the audit bridge; AC 5 makes its silent loss loud — no further issues |
| Information Disclosure | No | No issues found — evidence and sweep output stay location-only per existing discipline; this spec publishes nothing new to the coordination point |
| Denial of Service | Yes | Accepted residual, unchanged: push access can plant colliding records forcing loud halts — fail-closed integrity over availability, `sdlc/017`'s accepted design; repair is Spec E's charter (#116, #130). No new finding |
| Elevation of Privilege | N/A | No privilege model — scripts run as the developer; any new script verb grants stay verb-scoped per Permission Conventions (plan-time check) |

## Routing Recommendations

### Spec amendments
- Finding 1: state that two spellings of one ordinal are one identity at
  every comparison site (occupancy, resolve replay, realize key readback),
  with a resume-against-unpadded-record fixture. **Routed and applied
  2026-07-31** — folded into AC 4, which now carries the
  every-comparison-site identity clause and the resume fixture. The
  remaining Notable (Finding 2) routes to the future plan, hence the
  `Needs Plan Review` status.

### Plan amendments
- Finding 2: containment bound on the widened sweep enumeration
  (realized-directory-only, worktree-contained realpath before edit).
- Finding 3: per-identity degradation semantics for the occupancy predicate
  on malformed sibling basenames.
