---
spec: "docs/specs/blueprint/025-rename-redirect-record-emission/spec.md"
reviewed_phases: [spec, plan]
status: "Needs Plan Review"
date: "2026-08-02"
---

# Security Review: Rename/redirect record emission

## Summary

**Findings:** 0 Critical · 1 Notable · 1 Advisory open (4 resolved)

Dual-lens review of spec + plan. The spec-phase findings (1–3) are resolved —
folded into the spec as AC amendments — and Finding 4 is discharged by the
plan's DD 4. The plan pass adds one Notable (the lift's corroboration must
run inside the publish builder, mirroring the batch verb's design) and one
Advisory (fixture explicitness). LINDDUN active (developer identity tokens);
no spec↔plan misalignment found.

## Coverage

- spec.md — reviewed 2026-08-02 (requirements-gap lens)
- plan.md — reviewed 2026-08-02 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | Yes | Developer identity tokens in the required `<who>` slot — same exposure class as git commit authorship on the same branch |
| Credentials | No | Registry and ledger records carry ids, slugs, dates, and identity tokens only; no secret can enter a field-gated record |
| Session data | No | — |
| Internal-only | Yes | Spec/issue ordinals, group names, provenance markers, ledger pair events |
| Public | No | Records are internal coordination data, though designed safe for publicly hosted repos |

## Findings

### 1. "Corroborated against registry state" is load-bearing but undefined

- **Severity:** Notable
- **Description:** AC 12 requires lifted pairs be "corroborated against
  registry state" but does not say what corroboration means. The lift is a
  confused-deputy shape: the specs-root ledger lives on ordinary content
  branches while the registry branch may be more protected — an attacker with
  content-branch write access could plant a `moved=` pair and let an
  operator's lift run convert it into a registry record under the operator's
  authority. Weak corroboration amplifies AC 7: once rename sources resolve,
  a bogus lifted record `spec rename victim/001 attacker/target` makes a real
  citation dereference to an attacker-chosen destination (the phantom shape
  measured on #113), disclosed but resolving.
- **Suggestion:** Define corroboration in the AC: a lifted record's
  destination must already be established in the registry (its allocate
  record present and matching the event's identity — the realize claim-key
  discipline), and its source must not conflict with a live claim. A pair
  failing corroboration is refused by name, never emitted.
- **Route:** Spec
- **Relates to:** AC #12 (interaction with AC #7)
- **Resolved (2026-08-02):** folded into AC 12 — corroboration defined
  (destination established and matching, source conflict-free, refusals by
  name).

### 2. New output surfaces echo untrusted tokens without a binding requirement

- **Severity:** Notable
- **Description:** The spec adds several outputs that echo registry- or
  ledger-sourced tokens: the resolver's disclosure line (AC 7/8), emission
  refusals naming conflicts (AC 5) and pending identities (AC 10), and the
  lift's refusal/report lines (AC 12). Registry and ledger content is
  push-writable, and ARCHITECTURE.md's untrusted-content discipline plus the
  sweep's existing sanitize/truncate pattern cover *existing* surfaces — but
  no AC binds the new ones, including the new `<who>` field itself, which is
  stored attacker-influencible text replayed into terminals.
- **Suggestion:** Add one requirement: every new output path that echoes a
  registry or ledger token prints it only after the same field gating applied
  at parse time (the `<who>` slot included), sanitized/truncated per the
  established sweep discipline.
- **Route:** Spec
- **Relates to:** AC #1, #5, #7, #10, #12
- **Resolved (2026-08-02):** AC 18 added, binding field gating and the
  sanitize/truncate output discipline to every new token-echoing path.

### 3. Provenance markers are hints, not authentication

- **Severity:** Advisory
- **Description:** `<who>` and the marker class (AC 14) are self-asserted by
  whoever pushes the record — a hand-pushed record can claim the lift's
  marker, and nothing in the record proves authorship. This is already true
  of `jim-seed`/`jim-catchup` on allocate records; the extension inherits it.
- **Suggestion:** State in the spec that in-record provenance is an audit
  *hint* and the append-only coordination-branch git history is the
  authoritative trail — so no consumer is ever specified to make a trust
  decision from `<who>` alone.
- **Route:** Spec
- **Relates to:** AC #14
- Reinforces ARCHITECTURE.md → Security Considerations (untrusted git
  content); referenced rather than restated.
- **Resolved (2026-08-02):** AC 14 amended — provenance is an audit hint;
  branch history is the authoritative trail.

### 4. Date semantics for lifted records are undecided

- **Severity:** Advisory
- **Description:** Backfilled records could carry the historical event date
  (e.g. the 2026-07-25 split) or the lift date. Appending
  historically-dated records at the log tail is safe for replay (file order
  governs) but ambiguous for audit: a reader correlating record dates with
  branch history sees records "from" a date the branch never saw.
- **Suggestion:** Decide once at plan time and document in the lift's
  contract; recommended: historical event date in `<date>` (it is the
  identity-relevant fact) with the marker class (AC 14) carrying the
  repair-time distinction.
- **Route:** Plan
- **Relates to:** AC #13, #14
- **Resolved (2026-08-02):** plan DD 4 — historical event date in `<date>`;
  the `jim-lift` marker carries repair-time.

### 5. The lift's corroboration runs outside the CAS window

- **Severity:** Notable
- **Description:** The plan states corroboration-in-the-builder for
  `partition-batch` ("each CAS attempt re-validates against fresh registry
  content") but not for the lift. If `lift --apply` publishes a row set
  corroborated at preview time through a builder that only appends, a
  registry change between preview and apply — a concurrent lift run, an
  allocation claiming a destination — publishes stale rows: the same TOCTOU
  the batch design closed.
- **Suggestion:** State in task 8 and the lift's interface contract that
  corroboration and the `have` dedupe run inside the lift's publish builder
  on every CAS attempt against the fresh log content; the preview is
  advisory only, and the `emit` set is recomputed at publish, never
  replayed.
- **Route:** Plan
- **Relates to:** Task 8; Interface Contracts (lift verb); AC #12

### 6. Group-mode occupied-destination refusal not explicitly fixtured

- **Severity:** Advisory
- **Description:** DD 10 decides occupied-destination semantics generically,
  but task 7's fixture list names only the spec-pair refusals; the
  group-mode occupied destination — the exact classifier shape #202's first
  defect fixes — is not named on the emitter side.
- **Suggestion:** Add the group-mode occupied-destination refusal to task
  7's fixture list so emitter and classifier are fixtured on the same
  shape.
- **Route:** Plan
- **Relates to:** Task 7; DD 10; AC #6

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 3 (resolved into AC 14) — self-asserted `<who>`/marker tokens |
| Tampering | Yes | Findings 1, 2 (resolved into ACs 12/18) and 5 — ledger tampering feeding the lift; the lift's CAS-window corroboration. In-flight registry tampering is covered by the existing CAS + erosion re-check the batch publish inherits |
| Repudiation | Yes | Findings 3, 4 (both resolved) — trail = append-only branch history plus in-record provenance; date semantics settled by plan DD 4 |
| Information Disclosure | No | No issues found — records are field-gated ids/slugs/dates/identity tokens; spec and issue body content never reaches the registry |
| Denial of Service | No | No issues found — publish retries bounded; element gates bound token sizes; lift idempotency bounds re-runs; a bloated pushed log is pre-existing exposure owned by the sweep (platform/012) |
| Elevation of Privilege | Yes | Findings 1 (resolved — corroboration defined in AC 12) and 5 — the control must also hold inside the CAS window |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | No | No issues found — `<who>` links a developer to identity operations; equivalent linkage already exists via git authorship on the same branch |
| Identifying | No | No issues found — tokens are overt repo identities, not anonymized data |
| Non-repudiation | No | No issues found — attribution is the deliberate accountability property of a provenance slot, symmetric with existing allocate records |
| Detecting | N/A | No subject-presence inference beyond repository membership git history already exposes |
| Data Disclosure | No | No issues found — no personal data beyond the identity token enters a record |
| Unawareness & Unintervenability | No | No issues found — developers author records through their own invocations and can read the log; markers distinguish tool-generated repair |
| Non-compliance | N/A | No privacy policy governs project-internal developer metadata; same class as git commit metadata |

## Artifact Misalignment

No spec↔plan inconsistencies found. Spot-checked pairings: AC 9's
one-ordinal-authority ↔ DD 6's retirements; AC 2's dereference guarantee ↔
DD 3's live emission; AC 14's marker class ↔ DD 4's `jim-lift`; AC 15's
either-form allowance ↔ DD 9's SYNC choice.

## Routing Recommendations

### Spec amendments
All applied 2026-08-02: Finding 1 → AC 12; Finding 2 → AC 18; Finding 3 →
AC 14.

### Plan amendments
- Finding 4: resolved by DD 4 (historical event date; the marker carries
  repair-time) — no further action.
- Finding 5: state the lift's in-builder corroboration and `have` dedupe
  per CAS attempt in task 8 and the lift's interface contract.
- Finding 6: add the group-mode occupied-destination refusal to task 7's
  fixture list.

### Candidate issues
No findings route to Issue.
