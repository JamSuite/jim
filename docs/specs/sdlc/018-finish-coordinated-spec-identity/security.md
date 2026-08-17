---
spec: "docs/specs/sdlc/018-finish-coordinated-spec-identity/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-31"
---

# Security Review: Finish coordinated spec identity

## Summary

**Findings:** 0 open — all 4 resolved (3 by plan coverage, 1 routed and
applied to the plan)

Second pass, dual lens: `spec.md` re-checked and `plan.md` reviewed
(design-flaw lens) with the spec↔plan misalignment check. All three
first-pass findings are resolved — Finding 1 by the AC 4 amendment plus plan
DD 2/task 6, Finding 2 by DD 9/task 16, Finding 3 by DD 1/task 2. One new
Notable from the misalignment check: the nesting guard's end state
contradicts AC 12's refuse-semantics. STRIDE swept in full; LINDDUN inactive
(no PII, credentials, or session data in scope).

## Coverage

- spec.md — reviewed 2026-07-31 (requirements-gap lens; re-checked in the
  dual-lens pass)
- plan.md — reviewed 2026-07-31 (design-flaw lens + artifact misalignment)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | The registry's pre-existing `who` provenance token (from `git config user.name`) is out of this spec's scope and unchanged |
| Credentials | No | — |
| Session data | No | — |
| Internal-only | Yes | Registry allocation records, spec ordinals and provisional tokens, ledger `moved=` mappings |
| Public | Yes | Repo docs the citation sweep rewrites and the AC 14 docs pass touches |

## Findings

### 1. Padding-variant spellings can still split one ordinal identity inside the registry — RESOLVED

*Resolved 2026-07-31: routed to Spec (AC 4 amendment) at the first pass;
`plan.md` DD 2 applies `alloc_canon_specid` at resolve's literal comparison
sites and the `have` branch, task 6 carries the resume-against-unpadded-record
fixture.*

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

### 2. The widened citation sweep is the flow's first write path not enumerated from git — RESOLVED

*Resolved 2026-07-31: `plan.md` DD 9 scopes enumeration to the realized
directory and requires worktree-contained realpath before any edit; task 16
fixtures the symlink escape.*

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

### 3. The shared occupancy predicate should degrade per-identity on junk siblings — RESOLVED

*Resolved 2026-07-31: `plan.md` DD 1 skips malformed/over-wide sibling
basenames (never counted as holders, never an error); task 2 fixtures it.*

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

### 4. The nesting guard's end state contradicts AC 12's refuse-semantics — RESOLVED

*Resolved 2026-07-31: routed to Plan and applied — DD 7 now restores the
source on detection before failing, and task 14's fixture asserts the
unchanged end state plus a non-zero exit.*

- **Severity:** Notable
- **Description:** plan DD 7 (correctly) rejects GNU-only `mv -T` and detects
  the nesting artifact *after* the `mv` — but "fail loudly, undoing nothing"
  leaves the source directory nested inside the target when the race fires.
  Spec AC 12 promises the primitive "refuses rather than nests": the promised
  observable is an unchanged tree plus a loud error, and a realized-but-nested
  spec directory is precisely the silent-wrong-state class this spec exists
  to remove — made loud, but still wrong on disk.
- **Suggestion:** on detecting the artifact, restore the source
  (`mv` the just-nested directory back to its original path — safe, since the
  nested entry was created by this same command) and then fail; the fixture
  asserts end state unchanged plus a non-zero exit.
- **Route:** Plan
- **Relates to:** AC 12; plan DD 7, task 14

## Artifact Misalignment

- **Finding 4 — nesting guard end state:** Spec AC 12 states the rename
  primitives *refuse rather than nest*; plan DD 7 detects the nest post-hoc
  and leaves it in place. Route: Plan.

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
- Finding 2: containment bound on the widened sweep enumeration —
  **resolved by DD 9 / task 16.**
- Finding 3: per-identity degradation semantics for the occupancy predicate —
  **resolved by DD 1 / task 2.**
- Finding 4: amend DD 7 and task 14 so the guard restores the source on
  detection (end state unchanged + loud failure) — **resolved, routed and
  applied 2026-07-31.**
