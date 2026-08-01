---
spec: "docs/specs/platform/012-registry-integrity-and-drift/spec.md"
reviewed_phases: [spec]
status: Needs Spec Review
date: "2026-08-01"
---

# Security Review: Registry integrity and drift

## Summary

**Findings:** 0 Critical · 3 Notable · 2 Advisory

Reviewed spec.md (requirements-gap lens; no plan.md exists yet). STRIDE swept;
LINDDUN inactive — no PII, credentials, or session data (see classification).
The spec inherits a well-hardened surface (platform/007/008/011's registry
threat model); every finding is about the two *new* trust flows this spec
introduces — tree content becoming registry records, and registry content
becoming report output.

## Coverage

- spec.md — reviewed 2026-08-01 (requirements-gap lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | The record `<who>` field is the sanitized git `user.name` — the same ambient developer identity every git commit already carries; platform/007 classifies it advisory provenance, and this spec adds no new person-linked data |
| Credentials | No | The allocator never handles credentials; pushes ride the operator's ambient git auth outside the script |
| Session data | No | None |
| Internal-only | Yes | Registry records, ordinals, slugs, drift reports — all repo-scoped |
| Public | No | Nothing intended for exposure beyond repo readers |

## Findings

### 1. The human gate must see, and report, the actual records

- **Severity:** Notable
- **Description:** Catch-up converts working-tree content — which in a team
  setting includes merged contributions — into durable registry records. The
  spec requires preview-then-apply (AC 7) but does not require the preview to
  render every record it would append, nor apply to report what it actually
  landed — which can differ from the preview, because the publish path
  recomputes against the current tip inside the CAS retry loop (a
  preview→apply TOCTOU window). Without both, the operator approves counts,
  not content.
- **Suggestion:** Extend AC 7 and AC 9's reporting clause: the preview renders
  each record verbatim (the seed preview's existing discipline), and apply's
  output names the records it actually appended rather than echoing the
  previewed set.
- **Route:** Spec
- **Relates to:** AC 7, AC 9, AC 10

### 2. Report output needs a sanitization requirement

- **Severity:** Notable
- **Description:** The sweep echoes registry-derived and tree-derived tokens
  (ids, slugs, dates, `<who>`) into a report consumed by humans, CI logs, and
  — under AC 13's wiring — `/jim:verify`'s evidence handling. The registry is
  push-writable, so a crafted record can attempt to forge report rows, shift
  columns, or embed directive text. No AC requires emitted fields to be
  revalidated or sanitized; `jimverify.sh` sanitizes every emitted field for
  exactly this reason.
- **Suggestion:** Add a clause (on AC 1 or AC 3): every token the sweep or
  catch-up echoes is revalidated at the id boundary or sanitized before
  emission, so a crafted record can neither forge nor suppress report lines.
- **Route:** Spec
- **Relates to:** AC 1, AC 3, AC 4

### 3. State the guarantee boundary: consistency, not authorization

- **Severity:** Notable
- **Description:** The sweep detects the *absence* of records. An attacker
  with push access to the coordination branch fabricates a well-formed record
  matching a rogue tree entry and the sweep reports clean — the erosion
  guard's accepted residual (a well-formed append is undetectable) extends to
  the sweep unchanged. The spec's framing ("only-door enforced by detection")
  oversells unless bounded, and the primary control — coordination-branch
  protection — is still an open docs item (#118).
- **Suggestion:** State in the spec (Problem Statement or Out of Scope) that
  the sweep verifies tree↔registry *consistency*, never record provenance or
  authorization; name branch protection as the primary control with #118 as
  the standing dependency.
- **Route:** Spec
- **Relates to:** Problem Statement, Out of Scope

### 4. Read-path cost over an attacker-growable log

- **Severity:** Advisory
- **Description:** The sweep validates every record; the id boundary costs
  ~56 ms/record in subprocess forks (#142, measured), and log length is
  influenceable by anyone who can push the branch. A grown log slows every CI
  sweep and, under the verify wiring, pushes the run toward
  `verify_registry_timeout` (default 120 s), degrading the check to `failed`.
  Bounded and loudly named, but cheap to avoid.
- **Suggestion:** The plan should batch-validate records in one pass rather
  than per-record forks; reference #142 rather than duplicating it.
- **Route:** Plan
- **Relates to:** AC 1, AC 5

### 5. Bound the report under drift-flood, loudly

- **Severity:** Advisory
- **Description:** A partition accident or hostile push could produce
  thousands of findings; an unbounded report floods CI logs and the verify
  evidence channel.
- **Suggestion:** The plan adopts cap-and-name truncation for report rows
  (the `CROSS-REF-CAPPED` precedent): a bounded listing that always reports
  the full count — never a silent drop.
- **Route:** Plan
- **Relates to:** AC 3, AC 4

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 3 (a fabricated record reads as a legitimate identity; the self-asserted `<who>` is platform/007's accepted advisory-provenance posture, referenced not restated) |
| Tampering | Yes | Finding 2 (report forgery via crafted tokens); tampering with the registry itself inherits the erosion guard + read-side revalidation already documented in ARCHITECTURE.md |
| Repudiation | No | No issues found — records are advisory provenance by design (007 out-of-scope: not an audit trail); AC 10's distinct marker *improves* attribution of catch-up appends |
| Information Disclosure | No | No issues found — all report content is repo-scoped and derivable by any repo reader |
| Denial of Service | Yes | Findings 4, 5 (log growth vs the verify timeout; drift-flood report volume); allocation-path contention handling is inherited |
| Elevation of Privilege | N/A | Ids carry no authority (007 non-goal, restated by 011); no privilege surface — writes ride the operator's ambient git credentials |

## Routing Recommendations

### Spec amendments
All three applied 2026-08-01 at the developer's direction:
- Finding 1: preview renders every record verbatim; apply reports the
  actually-appended set → folded into AC 7.
- Finding 2: emitted-token sanitization → new AC 15.
- Finding 3: guarantee-boundary statement (consistency, not authorization),
  naming #118 as the primary-control dependency → new Out of Scope bullet.

### Plan amendments
- Finding 4: batch validation over per-record forks (with #142 referenced) —
  for the plan when it exists.
- Finding 5: cap-and-name report truncation — for the plan when it exists.

### Candidate issues
No findings routed to Issue this run.
