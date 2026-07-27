---
spec: "docs/specs/platform/008-registry-seed/spec.md"
reviewed_phases: [spec]
status: "Needs Plan Review"
date: "2026-07-27"
---

# Security Review: Registry seed from existing artifacts

## Summary

**Findings:** 0 Critical · 2 Notable · 2 Advisory

Spec-only review (no plan.md yet) of a one-time bootstrap that reads a project's
existing spec directories and issue files and turns them into an initial
id-coordination registry, landed through `platform/007`'s compare-and-swap. The
seed inherits 007's whole threat model (branch-writable registry, the
`is_valid_id` injection boundary, the erosion guard) and adds one new input class:
developer-authored directory names and issue frontmatter, read and turned into
registry tokens and git arguments. The dominant residual risks are a spec-level
conflict-handling asymmetry (issue frontmatter vs. spec dirs) and a
bootstrap-guard TOCTOU. LINDDUN is N/A — no PII, credential, or session data is
handled (the synthetic seed `<who>` is not personal data).

## Coverage

- spec.md — reviewed 2026-07-27 (requirements-gap lens)
- plan.md — not present; plan-phase design-flaw findings (F2–F4) route forward to
  the `/jim:plan` security pass.

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Registry records carry a synthetic seed `<who>` marker, not a personal handle; even 007's real `<who>` only duplicates git commit metadata. |
| Credentials | No | Seeding relies on the developer's ambient git auth for the CAS push/fetch; it stores and transmits no new secrets. |
| Session data | No | None. |
| Internal-only | Yes | Registry ids, slugs, group names, ordinals, durable issue ids — project-internal metadata, all already present in the committed tree. |
| Public | No | Registry is repo-read-visible but not intended for external publication. |

## Findings

### 1. Conflict handling is asymmetric: issue frontmatter parse failures are unspecified

- **Severity:** Notable
- **Description:** AC 6 makes the seed stop-and-report on "a collision or
  ambiguity that the registry's uniqueness cannot represent — most notably two
  issues claiming the same display ordinal, or a spec directory whose ordinal or
  group cannot be parsed." Spec directories get an explicit parse-failure clause;
  issue files do not. An issue whose frontmatter `num` is absent or non-numeric,
  or whose durable `id` is missing/malformed, is neither a duplicate ordinal nor a
  spec-dir parse failure, so the AC does not clearly cover it. Without a defined
  behavior the seed could silently skip such an issue (a registry that
  under-represents the collection, so a later allocation reissues a consumed
  ordinal) or coerce a bad value into a record. Adopting projects — the seed's
  whole audience — are exactly the ones likely to hold hand-created or
  legacy-schema issues without a well-formed `num`.
- **Suggestion:** Extend AC 6 so an issue file whose display ordinal or durable id
  cannot be parsed is a stop-and-report condition symmetric with the spec-dir
  case: name the offending file, issue no records. Keep it a stop (not a skip) so
  the developer resolves the artifact before adoption, consistent with the
  halt-and-report decision.
- **Route:** Spec
- **Relates to:** AC 6
- **Resolution (spec-phase routing 2026-07-27):** Resolved — AC 6 now stops and
  reports on an issue file whose display ordinal or durable id is absent or
  cannot be parsed, symmetric with the spec-directory parse-failure clause.

### 2. The "refuse if non-empty" precondition must be re-evaluated inside the CAS attempt

- **Severity:** Notable
- **Description:** AC 5 refuses to seed a kind whose registry already has records;
  AC 8 lands the seed through 007's compare-and-swap. If the emptiness check is
  read once before the CAS loop, a concurrent allocation that lands between the
  check and the push opens a time-of-check/time-of-use window: the seed built its
  records against an empty log, the branch is now non-empty, and — depending on
  realization — the push could append the seed's bulk records onto a registry that
  is no longer empty, defeating the one-time-bootstrap guarantee and risking
  duplicate ordinals. 007's CAS rejects a stale-parent push, but only the
  emptiness *precondition*, re-checked against the freshly fetched tip on each
  attempt, closes the window deterministically.
- **Suggestion:** In the plan, require the empty-registry precondition to be
  evaluated against the CAS-fetched tip inside the retry loop (not a stale prior
  read), so a registry that became non-empty during the attempt is refused rather
  than appended to. Add a test that races an allocation against a seed.
- **Route:** Plan
- **Relates to:** AC 5, AC 8

### 3. Ordinals need a numeric-class check, not only the id/slug boundary

- **Severity:** Advisory
- **Description:** AC 9 revalidates "an id, slug, group name, or a durable id"
  through the allocator's boundary, and lists "an ordinal" among them. But the
  `is_valid_id` boundary admits tokens like `1abc` or `007x` that are valid ids
  yet not well-formed ordinals; a display ordinal or spec `NNN` read from an
  artifact feeds `printf '%03d'` / base-10 `next-id` arithmetic and the record's
  ordinal field. A non-numeric or absurdly large ordinal that passes `is_valid_id`
  could corrupt a record or the high-water computation.
- **Suggestion:** In the plan, gate every artifact-derived ordinal with a pure
  numeric-class check (`^[0-9]+$`, sane magnitude) in addition to the id boundary
  before it enters a record or arithmetic — mirroring `alloc_next_id_spec`'s own
  base-10 discipline (`jimalloc.sh:247-268`).
- **Route:** Plan
- **Relates to:** AC 9

### 4. Arm the erosion baseline at seed time

- **Severity:** Advisory
- **Description:** 007's erosion guard compares the fetched registry against a
  local, per-clone baseline; a clone with no baseline cannot detect a rewritten
  history (`jimalloc.sh:456-464`). A fresh clone that seeds then allocates has no
  baseline written by the seed, so the first post-seed allocation's erosion check
  passes trivially — a force-push that rewrote the registry between seed and first
  allocation would go undetected until a later allocation establishes a baseline.
- **Suggestion:** In the plan, have the seed write the local erosion baseline for
  each seeded log immediately after its commit (as `alloc_update_baseline` does
  for an allocation), so the guard is armed from the seeded state. Defense in
  depth; the primary control remains force-push/deletion denial on the
  coordination branch.
- **Route:** Plan
- **Relates to:** AC 8 (inherits 007 AC 11 erosion behavior)

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Seeded records carry a synthetic `<who>`; 007's non-goal already declares registry attribution advisory-only, never an authorization/authentication anchor — the seed inherits it and must not let any consumer treat seeded provenance as meaningful. No new finding. |
| Tampering | Yes | F2 (bootstrap-guard TOCTOU), F3 (ordinal coercion). The seed adds no new local filesystem write surface beyond 007's baseline; registry integrity otherwise rests on 007's CAS + erosion guard (F4). |
| Repudiation | Yes | Registry is advisory provenance, not an audit trail (007 non-goal, inherited). Seeded records deliberately carry no authored identity. No issue. |
| Information Disclosure | Yes | The seed publishes existing spec/issue slugs to the coordination branch, but those artifacts are already committed and repo-read-visible, so there is no new disclosure — *except* if the seed is run against a branch carrying still-unmerged artifacts, which would publish their slugs early (the reservation-time surface 007 acknowledged in its Out of Scope). Guidance: run the one-time seed against the shared/merged state. No new finding. |
| Denial of Service | Yes | One-time, bounded single pass over ~65 specs / ~120 issues landing one commit; contention inherits 007's bounded-retry-then-hard-fail. No new surface. |
| Elevation of Privilege | Yes | Git option-injection is the EoP vector (as in 007), foreclosed by AC 9's revalidation of every artifact-derived token before git use; F3 sharpens the ordinal sub-case. |

## Routing Recommendations

### Spec amendments
- Finding 1: **applied 2026-07-27** — AC 6 extended so an issue file with an
  unparseable/absent display ordinal or durable id is a stop-and-report condition
  symmetric with the spec-directory parse-failure clause.

### Plan amendments
- Finding 2: evaluate the empty-registry precondition against the CAS-fetched tip
  inside the retry loop; test with an allocation racing a seed.
- Finding 3: gate every artifact-derived ordinal with a numeric-class check in
  addition to the id boundary before record emission or arithmetic.
- Finding 4: write the local erosion baseline per seeded log immediately after its
  commit, arming the guard from the seeded state.

### Candidate issues
- None — no findings routed to Issue this run.
