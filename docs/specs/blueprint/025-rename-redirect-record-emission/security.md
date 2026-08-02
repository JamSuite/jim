---
spec: "docs/specs/blueprint/025-rename-redirect-record-emission/spec.md"
reviewed_phases: [spec]
status: "Needs Spec Review"
date: "2026-08-02"
---

# Security Review: Rename/redirect record emission

## Summary

**Findings:** 0 Critical · 2 Notable · 2 Advisory

Spec-only review (no plan.md yet) of the registry write path: rename/redirect
record emission, the resolver's disclosure semantics, and the ledger→registry
lift. Freeform review + STRIDE; LINDDUN active (developer identity tokens in
records). The spec already carries strong security requirements (AC 12's
untrusted-ledger handling, AC 6's occupied-destination refusal); the Notable
findings sharpen under-specified clauses rather than add missing controls.

## Coverage

- spec.md — reviewed 2026-08-02 (requirements-gap lens)

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

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 3 — self-asserted `<who>`/marker tokens |
| Tampering | Yes | Findings 1, 2 — ledger tampering feeding the lift; crafted records at parse time. In-flight registry tampering is covered by the existing CAS + erosion re-check the batch publish inherits |
| Repudiation | Yes | Findings 3, 4 — trail = append-only branch history plus in-record provenance; lifted-record date ambiguity |
| Information Disclosure | No | No issues found — records are field-gated ids/slugs/dates/identity tokens; spec and issue body content never reaches the registry |
| Denial of Service | No | No issues found — publish retries bounded; element gates bound token sizes; lift idempotency bounds re-runs; a bloated pushed log is pre-existing exposure owned by the sweep (platform/012) |
| Elevation of Privilege | Yes | Finding 1 — content-branch write access converted into coordination-branch records through an operator's lift run; corroboration is the control |

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

## Routing Recommendations

### Spec amendments
- Finding 1: define AC 12's corroboration — destination established and
  matching, source conflict-free, failures refused by name.
- Finding 2: one requirement binding field gating + output sanitization on
  every new token-echoing output, `<who>` included.
- Finding 3: one sentence marking in-record provenance as an audit hint with
  branch history as the authoritative trail.

### Plan amendments
- Finding 4: decide and document lifted-record date semantics (recommended:
  historical event date; marker carries repair-time).

### Candidate issues
No findings route to Issue.
