---
spec: "docs/specs/sdlc/017-coordinated-spec-identity/spec.md"
reviewed_phases: [spec]
status: Needs Spec Review
date: "2026-07-30"
---

# Security Review: Coordinated spec identity

## Summary

**Findings:** 0 Critical · 5 Notable · 1 Advisory

Spec-phase review of the spec-ID allocator consumer and its provisional
realization loop. The spec inherits `platform/007`–`011`'s sound trust model
(push-writable registry, single validation boundary, advisory-only ids);
findings concern input classes and observables the consumer adds, not the
substrate. STRIDE fully swept; LINDDUN active (filer identity and slugs
publish to the shared coordination point).

## Coverage

- spec.md — reviewed 2026-07-30 (requirements-gap lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | Yes | Filer identity (`<who>` from git config) and title-derived slugs enter registry records at reservation — published to the shared coordination branch pre-merge |
| Credentials | No | None handled; the allocator forecloses credential prompts (`GIT_TERMINAL_PROMPT=0`) |
| Session data | No | None |
| Internal-only | Yes | Spec ordinals, provisional identities, ledger events, registry records |
| Public | Yes | All artifacts are repo-visible content |

## Findings

### 1. The untrusted-input enumeration omits the tree — the realizer's primary input

- **Severity:** Notable
- **Description:** The revalidation AC enumerates values "read back from the
  registry or configuration," but the realizer's driving input is
  *tree-derived*: provisional identities read from directory names (and any
  frontmatter consulted). The tree is writable by anyone who can commit or
  merge to a branch, so a crafted `P-…` directory name reaches the realizer
  before any registry read. The issue-side precedent (`reconcile.sh`
  revalidating frontmatter `id:`) treats tree data as untrusted for exactly
  this reason.
- **Suggestion:** Widen the revalidation AC's input classes to name
  tree-derived identity tokens — directory names and frontmatter — alongside
  registry and configuration values.
- **Route:** Spec
- **Relates to:** AC 13 (revalidation boundary)

### 2. No specified observable for a local identity collision (registry-vs-tree drift)

- **Severity:** Notable
- **Description:** When `allocate spec` (at bind) or realization returns
  `group/NNN` and a local `NNN-*` directory already exists, the registry and
  tree disagree — drift. The spec never states what the developer observes.
  Silently suffixing is not available (a spec ordinal is path identity, unlike
  a provisional issue filename), and silent overwrite is corruption. The
  issue consumer hard-errors on this case ("registry drift",
  `new.sh:153-156`); the spec side has no equivalent requirement.
- **Suggestion:** Add the observable to the ACs: a local collision with an
  allocator-returned identity halts loudly, names the drift, and writes
  nothing — repair belongs to the drift-repair follow-on (#116/#130), never
  to a silent local workaround.
- **Route:** Spec
- **Relates to:** AC 1 (reservation-before-write), AC 7 (realization)

### 3. The realizer's mutation pass needs the established write-discipline envelope

- **Severity:** Notable
- **Description:** Realization is a mass mutation — a directory rename plus a
  citation sweep across tree files — driven by derived mappings. jim's two
  shipped mutating verbs (`rewrite-identity`, `rewrite-refs`) each carry a
  hard-won envelope from their own security reviews: every target validated
  and containment-checked (worktree-contained, symlink-escape refused)
  *before any edit*, remap-as-whitelist matching, and location-only output
  (matched content never echoed). The spec's exact-token AC covers matching
  but not the envelope.
- **Suggestion:** The plan must adopt the full envelope for the realizer's
  mutation pass — guards-before-any-edit, containment, whitelist-keyed
  rewriting, location-only reporting — reusing the `jimpartition.sh`
  precedent rather than a new discipline.
- **Route:** Plan
- **Relates to:** AC 7 (realization step), AC 8 (committed/uncommitted move)

### 4. Scope the new allocator grant to the verbs the flow uses

- **Severity:** Notable
- **Description:** `/jim:spec`'s `allowed-tools` must gain a `jimalloc.sh`
  grant for the wiring. A whole-script grant
  (`Bash(bash …/jimalloc.sh *)`) also authorizes `seed --apply` (registry
  bootstrap), `reconcile issue`, and `allocate issue` from inside the spec
  interview — mutations that flow never needs. Prefix-matched permission
  tokens can scope to the verb level.
- **Suggestion:** Grant exactly the verbs the flow uses — `peek spec`,
  `allocate spec`, and the spec-side reconcile verb — as separate verb-level
  prefixes, mirroring the tightest-verb-grant discipline used elsewhere.
- **Route:** Plan
- **Relates to:** AC 1, AC 7; `skills/spec/SKILL.md:10`

### 5. The ledger-recorded mapping is untrusted input to the future registry lift

- **Severity:** Notable
- **Description:** The durable ledger redirect (AC 9) becomes the source the
  rename-emitting follow-on lifts into registry redirect records. The
  specs-root ledger is ordinary branch content — writable by anyone who can
  push a branch — so a tampered realize event could later cause the lift to
  emit a redirect pointing an arbitrary citation at an attacker-chosen
  target (the same shape as the phantom-resolution concern recorded on
  #113). The lift must treat ledger-recorded mappings as untrusted:
  charset-gate every element on read (the `vacated-max` precedent) and
  corroborate against registry state before emitting.
- **Suggestion:** Record this constraint on the already-filed lift issue
  (`20260730-lift-realization-redirects-into-the-registry`) rather than a new
  issue — it is that work's acceptance concern, created by this spec's
  design decision.
- **Route:** Issue
- **Relates to:** AC 9 (ledger redirect record)

### 6. Realize-event hygiene: the ledger write side validates nothing

- **Severity:** Advisory
- **Description:** `jimledger.sh event` appends phase/event/kv verbatim — no
  charset gate, no tab stripping (`append_line`). The realization event's kv
  carries provisional tokens and allocated ids; if any value bypassed the id
  boundary, a crafted token could shift TSV columns or forge kv pairs for
  future readers.
- **Suggestion:** In the plan: every kv value in the realize event passes the
  id boundary before append (they already must for path use — make the
  ordering explicit), and any future reader of the event charset-gates
  elements on read, per the `vacated-max` `consider()` precedent.
- **Route:** Plan
- **Relates to:** AC 9 (ledger redirect record)

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | No new issues — `<who>` is self-asserted advisory provenance by upstream non-goal (ids never authenticate); registry-derived tokens shown in the interview are `valid-id`-constrained (≤128 chars, no whitespace), bounding presentation-injection |
| Tampering | Yes | Findings 1, 5 — crafted tree content (dir names) and tampered ledger mappings; registry tampering carries down to the erosion guard + fold monotonicity |
| Repudiation | N/A | Upstream non-goal: records are advisory provenance, never an audit trail; no consumer may treat them as proof of action |
| Information Disclosure | Yes | No new issues — pre-merge publication of slug + filer identity is an acknowledged, recorded surface (spec Out of Scope, mirroring `platform/007` / `issue/010`); no new channel added |
| Denial of Service | Yes | No new issues — bounded CAS retries, terminal exhaustion refusal, and ordinal-width guards carry down; a crafted flood of `P-` dirs is bounded by tree size and the batch's halt conditions |
| Elevation of Privilege | Yes | Finding 4 — whole-script grant would hand the interview registry-bootstrap capability |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | Yes | No new issues — `<who>` + slug + date across records link a contributor's activity timeline on the coordination branch; acknowledged surface (spec Out of Scope: opaque reservation deferred) |
| Identifying | No | `<who>` is direct self-asserted identity, not anonymized data — no re-identification gap beyond the acknowledged disclosure |
| Non-repudiation | No | Records are deniable by design (advisory provenance non-goal) — no forced non-repudiation |
| Detecting | No | Presence inference (a batch of realizations reveals offline work happened) is trivial and matches the visible-push design intent |
| Data Disclosure | Yes | No new issues — same acknowledged pre-merge slug/who surface as Information Disclosure; no widening beyond `issue/010`'s accepted posture |
| Unawareness & Unintervenability | No | Reservation is a visible git push at a developer-triggered step; realization is preview-then-apply — intervention points preserved |
| Non-compliance | N/A | No stated privacy policy or applicable regulation for jim's own artifacts |

## Routing Recommendations

### Spec amendments
- Finding 1: widen AC 13's untrusted-input enumeration to tree-derived
  identity tokens (directory names, frontmatter). *(Applied 2026-07-30 —
  AC 13 now names registry, configuration, and tree input classes.)*
- Finding 2: add the loud-halt observable for a local identity collision
  (registry-vs-tree drift) at bind and at realize. *(Applied 2026-07-30 —
  new AC 14.)*

### Plan amendments
- Finding 3: adopt the guards-before-any-edit / containment /
  whitelist-keyed / location-only envelope for the realizer's mutation pass.
- Finding 4: verb-scope the new `jimalloc.sh` grant (`peek spec`,
  `allocate spec`, spec-side reconcile) — never the whole CLI.
- Finding 6: boundary-validate every realize-event kv value before append;
  future readers charset-gate on read.

### Candidate issues
- Finding 5: fold into the existing
  `20260730-lift-realization-redirects-into-the-registry` issue (untrusted
  ledger mapping — charset-gate on read, corroborate against registry state
  before emitting) rather than filing a duplicate. *(Folded 2026-07-30 —
  recorded as that issue's third design constraint.)*
