---
spec: "docs/specs/platform/012-registry-integrity-and-drift/spec.md"
reviewed_phases: [spec, plan]
status: Needs Plan Review
date: "2026-08-01"
---

# Security Review: Registry integrity and drift

## Summary

**Findings:** 0 Critical · 5 Notable · 4 Advisory — findings 1–5 discharged
(1–3 folded into the spec, 4–5 absorbed by the plan's DD 4/DD 5); the live
set is 6–9 from the dual-lens pass.

First pass reviewed spec.md alone (requirements-gap lens). Second pass
(same date) added plan.md under the design-flaw lens plus the artifact-
misalignment check. STRIDE swept both passes; LINDDUN inactive — no PII,
credentials, or session data (see classification). The new findings are two
spec↔plan misalignments (a detection mechanism underspecified for AC 3, a
site missed for AC 11), one execution-hygiene advisory, and one follow-on
gap routed to an issue.

## Coverage

- spec.md — reviewed 2026-08-01 (requirements-gap lens)
- plan.md — reviewed 2026-08-01 (design-flaw lens + artifact misalignment)

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

*Findings 1–3 were folded into the spec on 2026-08-01 (AC 7 clauses, AC 15,
the Out of Scope boundary statement); findings 4–5 are absorbed by the
plan's DD 4 and DD 5. The findings below are the dual-lens pass's.*

### 6. AC 3's retired-group naming has no mechanism in the plan

- **Severity:** Notable
- **Description:** AC 3 requires the sweep to name retired /
  partition-source groups as non-coverage. Plan task 7 says "retired groups
  via record-less group detection" — but a retired group (jim's own `jim`)
  has *no derivable tree rows* (only the reserved slot) *and* no records, so
  a tree+log comparison never sees it at all: nothing to derive, nothing to
  match. As specified, the one live instance of the class would be invisible
  to the shipped sweep.
- **Suggestion:** Specify the mechanism: a specs-tree group directory whose
  only entries are the reserved slot (zero derivable rows) and which has
  zero registry records is named as an uncovered group. That is exactly the
  retired-group signature the tree exposes, needs no ledger read, and makes
  the `jim` case the fixture.
- **Route:** Plan
- **Relates to:** AC 3, plan task 7

### 7. AC 11's realization clause covers two maps; the plan fixes one

- **Severity:** Notable
- **Description:** AC 11 includes "realization's already-realized lookup."
  Plan task 5 names only the issue-side `alloc_reconcile_realize`
  `existing[]` map. The spec-side `alloc_reconcile_realize_spec` keys its
  map on (group, slug, date) with the same silent last-wins when two records
  claim one triple — the deliberate surfaced-not-prevented collision
  residual makes the *have/new column* visible, but a duplicate-claiming
  record pair still resolves silently to the later record.
- **Suggestion:** Extend task 5 to both realize maps: a second record
  claiming an already-claimed key halts the batch with both claimants named,
  mirroring the within-batch duplicate halt.
- **Route:** Plan
- **Relates to:** AC 11, plan task 5

### 8. Task 11's Verify collapses resolve-and-execute into one line

- **Severity:** Advisory
- **Description:** The Verify command `bash -c "$(… jimconf.sh get
  verify_command_id-sweep)"` substitutes a config-resolved string straight
  into an executing shell. The verify rung's sanctioned pattern is
  model-mediated: resolve the value, see it, then run it — the nested
  substitution executes whatever the config holds with no reading step
  between.
- **Suggestion:** Split the Verify into resolve-then-run (two commands), so
  the executed string is visible in the transcript before execution —
  matching `skills/verify/SKILL.md`'s own discipline for the same value.
- **Route:** Plan
- **Relates to:** Plan task 11

### 9. Reported contradictions have no sanctioned repair path

- **Severity:** Advisory
- **Description:** The sweep reports mismatch and duplicate classes, and the
  spec correctly scopes their repair out (operator decision). But the
  operator's only concrete recourse today is hand-editing the push-writable
  coordination branch — the exact unsanctioned surgery #130 exists to
  eliminate for the append case. After this spec ships, a reported
  contradiction is loud but has no documented, disciplined resolution;
  detection without a repair story invites exactly the ad-hoc edits the
  registry's guarantees depend on avoiding.
- **Suggestion:** File as a follow-on: design the sanctioned repair path
  for registry-internal contradictions (a precedence/tombstone record, a
  documented manual procedure with erosion-baseline handling, or an
  explicit "this is destructive, here is the checklist" doc) — decided
  there, not here.
- **Route:** Issue
- **Relates to:** AC 2, AC 9, Out of Scope (mismatch repair)

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 3 (a fabricated record reads as a legitimate identity; the self-asserted `<who>` is platform/007's accepted advisory-provenance posture, referenced not restated) |
| Tampering | Yes | Findings 2 (report forgery via crafted tokens), 6–7 (detection-completeness gaps that would let tampered/absent state go unnamed), 9 (a detected contradiction has no disciplined repair); registry tampering itself inherits the erosion guard + read-side revalidation already documented in ARCHITECTURE.md |
| Repudiation | No | No issues found — records are advisory provenance by design (007 out-of-scope: not an audit trail); AC 10's distinct marker *improves* attribution of catch-up appends |
| Information Disclosure | No | No issues found — all report content is repo-scoped and derivable by any repo reader |
| Denial of Service | Yes | Findings 4, 5 (log growth vs the verify timeout; drift-flood report volume); allocation-path contention handling is inherited |
| Elevation of Privilege | N/A | Ids carry no authority (007 non-goal, restated by 011); no privilege surface — writes ride the operator's ambient git credentials. Finding 8 is execution hygiene on a developer-trusted config value, not a privilege boundary |

## Artifact Misalignment

- **Finding 6 — retired-group naming:** spec AC 3 requires naming retired
  groups as non-coverage; plan task 7's "record-less group detection" cannot
  see a group with no derivable rows and no records. Route: Plan.
- **Finding 7 — realization lookup coverage:** spec AC 11 names the
  realization lookup generically; plan task 5 covers the issue-side map
  only, missing `alloc_reconcile_realize_spec`'s triple-keyed twin. Route:
  Plan.

## Routing Recommendations

### Spec amendments
All three applied 2026-08-01 at the developer's direction:
- Finding 1: preview renders every record verbatim; apply reports the
  actually-appended set → folded into AC 7.
- Finding 2: emitted-token sanitization → new AC 15.
- Finding 3: guarantee-boundary statement (consistency, not authorization),
  naming #118 as the primary-control dependency → new Out of Scope bullet.

### Plan amendments
All applied 2026-08-01 at the developer's direction:
- Finding 4: batch validation over per-record forks — **absorbed by plan
  DD 4**.
- Finding 5: cap-and-name report truncation — **absorbed by plan DD 5**.
- Finding 6: retired-group detection specified (empty group dir + zero
  records → named uncovered) → task 7.
- Finding 7: duplicate halt extended to both realize maps → task 5.
- Finding 8: task 11's Verify split into resolve-then-run.

### Candidate issues
- Finding 9: sanctioned repair path for registry-internal contradictions —
  filed as `20260801-design-the-repair-path-for-registry-internal-contradictions`.
