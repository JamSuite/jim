---
spec: "docs/specs/issue/010-ordinal-coordination/spec.md"
reviewed_phases: [spec]
status: "Needs Plan Review"
date: "2026-07-28"
---

# Security Review: Coordinated issue display ordinals

## Summary

**Findings:** 0 Critical · 3 Notable · 1 Advisory

Spec-only review (no plan.md yet), requirements-gap lens. Hybrid freeform +
STRIDE sweep; LINDDUN active because the registry publishes the filer identity
and a title-derived slug. The three Notable findings are design gates for the
plan phase (provisional-id collapse, ordinal-value injection surface via `num`
widening, and unbatched-push contention); the Advisory is a spec-level
disclosure acknowledgement. No finding is a break of an existing `platform/007`
control — they are the consumer-side obligations that come with wiring issue
filing onto a branch-writable coordination point.

## Coverage

- spec.md — reviewed 2026-07-28 (requirements-gap lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | Yes | The registry `<who>` field is the filer's `git config user.name`; the durable id embeds a title-derived slug that may describe the work. Both reach the coordination point at filing (see Finding 4). Inherited from `platform/007`, newly applied to *issue* filing here. |
| Credentials | No | No secrets handled; `GIT_TERMINAL_PROMPT=0` (007) keeps auth non-interactive. |
| Session data | No | None. |
| Internal-only | Yes | Project-internal ordinals and durable ids; registry log records on the coordination branch. |
| Public | No | Registry is repo-internal (visible to repo-read-access holders), not published externally. |

## Findings

### 1. Provisional durable ids are undisambiguated — reconcile can collapse two distinct issues

- **Severity:** Notable
- **Description:** Under `provisional` mode the durable id is computed over an
  *empty* log (`alloc_provisional_issue`), so it is never disambiguated against
  the registry or the local collection. Two issues filed offline with the same
  natural slug on the same day — or one offline issue whose slug matches a real
  id allocated concurrently elsewhere — receive the *same* durable id, which is
  also the issue *filename* (`docs/issues/<id>.md`). The second write silently
  overwrites the first (data loss), and `reconcile issue` keys realization on
  that durable id, so two distinct issues can map to one ordinal — exactly what
  AC 7 forbids. This is a Tampering / integrity hazard reachable without any
  malicious actor, purely from the offline path.
- **Suggestion:** In the plan, disambiguate the provisional durable id against
  the *local* collection at filing time (mirroring today's `next-id` tree
  disambiguation, `-2`/`-3` suffix) before it is stored as a filename, and add a
  reconcile-time guard that refuses to realize two distinct local issues onto one
  ordinal. Add a fixture: two same-day same-slug provisional filings must yield
  distinct filenames and distinct realized ordinals.
- **Route:** Plan
- **Relates to:** AC 7; Handoff Insight 3; Open Questions

### 2. `num`-field widening weakens the untrusted-ordinal boundary at the display surface

- **Severity:** Notable
- **Description:** The emitter today constrains `num` to `^[0-9]+$`
  (`new.sh:96`). AC 6/9 require storing a provisional `P-…` ordinal, which forces
  that guard to widen. A *real* ordinal is registry-derived
  (`allocate`/`resolve`/`reconcile issue`) and the coordination branch is
  push-writable, so a crafted `issue allocate` record could carry a non-numeric
  ordinal. AC 10 revalidates a value "before it is used as a filesystem path,
  git argument, or ref" — but the ordinal's *primary* fate is being written into
  frontmatter and rendered into `INDEX.md`, `list`, and `show` output, which
  AC 10's path/git/ref scope does not name. A widened-but-loose guard (e.g. "any
  non-empty string") would let a branch-writable ordinal inject arbitrary text
  into rendered markdown.
- **Suggestion:** In the plan, make the widened `num` guard a strict union of two
  *exact* grammars — real `^[0-9]+$` OR the allocator's precise provisional form
  (`P-` prefix + its defined charset) — applied at the point the value enters
  frontmatter, and reject anything else. Optionally broaden AC 10 so revalidation
  explicitly covers "stored into frontmatter or rendered," not only path/git/ref.
- **Route:** Plan
- **Relates to:** AC 6, AC 9, AC 10

### 3. Unbatched per-item CAS pushes make the auto candidate-batch a contention / partial-write surface

- **Severity:** Notable
- **Description:** Wiring coordination into the emitter turns the end-of-run
  candidate batch (the surfacing skills, N issues per pipeline run) into N
  serialized push-CAS operations under a reachable remote, each with bounded
  retry. On an active coordination branch this amplifies contention (a
  self-inflicted DoS on the pipeline's own tail), and a mid-batch hard-fail under
  `fail` mode leaves the batch partially filed — some issues holding real
  coordinated ids, the rest unfiled. Gaps are acceptable (AC 3 lineage), but the
  amplification and the partial-batch behavior are not specified.
- **Suggestion:** In the plan, file a candidate batch through the allocator's
  shared batch path (`alloc_publish`, one CAS for N records — Insight 2) so a
  run is one round-trip, and define the batch's failure semantics (all-or-nothing
  vs. documented partial) explicitly.
- **Route:** Plan
- **Relates to:** AC 1, AC 5, AC 8; Handoff Insight 2; Out of Scope (coordination not opt-out)

### 4. Filer identity and title-derived slug are disclosed to the coordination point earlier and wider than today

- **Severity:** Advisory
- **Description:** Today an issue's slug and filer identity live on the working
  branch until merge. After wiring, every filing writes the durable id (embedding
  the title-derived slug) and `<who>` to the coordination branch at filing time —
  readable by everyone with repo read access, before the work merges. This is the
  same disclosure surface `platform/007` acknowledged for specs ("Opaque
  reservation for sensitive work"), but the *issue*-specific case is not yet
  acknowledged in this spec, so a team cannot weigh it. `issue_placement` being
  deferred limits the exposure to the id record (not the issue body).
- **Suggestion:** Add a one-line Out-of-Scope acknowledgement mirroring
  `platform/007`: coordinated filing publishes the readable, title-derived slug
  and the filer identity to the coordination point at creation time; binding an
  opaque token at reservation is a follow-on, not built here.
- **Route:** Spec
- **Relates to:** Out of Scope; `platform/007` disclosure acknowledgement

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | `<who>` is forgeable but advisory-only; `platform/007` reduces it to a safe token on write and forbids any auth/integrity use. No new surface here. |
| Tampering | Yes | Findings 1, 2 (provisional-id collapse; registry-ordinal injection at the display surface). Registry-log erosion is guarded upstream (007). |
| Repudiation | N/A | Ids carry no authority and there is no audit-trail claim (007 non-goal, carried down in Out of Scope). No repudiation obligation. |
| Information Disclosure | Yes | Finding 4 (slug + filer identity published earlier/wider). |
| Denial of Service | Yes | Finding 3 (unbatched per-item CAS pushes; branch contention). |
| Elevation of Privilege | N/A | Ordinals and registry records are never authorization anchors (007 non-goal). |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | No issues found | `<who>` links a filer's allocations within the registry, but this is intended, within-team provenance; no cross-context linking beyond repo access. |
| Identifying | No issues found | `<who>` identifies the filer by design (provenance); not anonymized data being re-identified. |
| Non-repudiation | N/A | `<who>` is self-asserted / forgeable, so a subject *can* deny — the privacy-preserving direction; no LINDDUN non-repudiation threat. |
| Detecting | No issues found | Presence of a filer's provisional/issue in the registry is inferable, but bounded to repo-read-access holders; subsumed by Finding 4. |
| Data Disclosure | Yes | Finding 4 — slug and filer identity reach the coordination point before merge. |
| Unawareness & Unintervenability | No issues found | The filer performs the filing and is aware; `<who>` is their own git identity. |
| Non-compliance | N/A | Internal developer tooling; no stated privacy policy or applicable regulation governs project-internal ids. |

## Routing Recommendations

### Spec amendments
- Finding 4: add the issue-specific disclosure acknowledgement to Out of Scope,
  mirroring `platform/007`.

### Plan amendments
- Finding 1: disambiguate provisional durable ids against the local collection at
  filing; add a reconcile-time anti-collapse guard + fixture.
- Finding 2: make the widened `num` guard a strict two-grammar union enforced at
  frontmatter-write; optionally broaden AC 10's revalidation scope.
- Finding 3: file candidate batches through the allocator's batch-CAS path; define
  batch failure semantics.
