---
spec: "docs/specs/issue/012-schema-and-state-model/spec.md"
reviewed_phases: [spec, plan]
status: "Needs Plan Review"
date: "2026-08-18"
---

# Security Review: Schema and state model

## Summary

**Findings:** 1 Critical · 5 Notable · 4 Advisory

Both lenses now applied. The spec-phase pass (2026-08-17) found the emitter's
first dependency on ambient identity and personal data written into every
tracked issue file, so LINDDUN runs alongside STRIDE. The plan-phase pass
(2026-08-18) adds four design-flaw findings, two of which are spec↔plan
misalignments. Denial of Service and Elevation of Privilege remain N/A with
justification.

Findings are numbered by phase, then severity within phase — spec-phase 1–6 keep
their original numbers so existing references to them stay valid, and plan-phase
findings continue at 7.

## Coverage

- spec.md — reviewed 2026-08-17 (requirements-gap lens)
- plan.md — reviewed 2026-08-18 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | Yes | `filed-by` and `claimed-by` store contributor email addresses; the existing collection resolves to two distinct real addresses, verified this session (values withheld here — recording them in a published artifact is the exposure this review flags) |
| Credentials | No | No passwords, keys, or tokens handled |
| Session data | No | No sessions; every operation is a one-shot CLI invocation |
| Internal-only | Yes | Issue bodies, project-internal ids and ordinals |
| Public | Yes | `ROADMAP.md` § Now lists "Make repo public" as a committed deliverable, so `docs/issues/` becomes public content |

## Findings

### 1. Identity fields can inject arbitrary frontmatter

- **Severity:** Critical
- **Description:** `filed-by` derives from `git config user.email`, which is
  local configuration that accepts embedded newlines. Verified in a throwaway
  repo this session: setting `user.email` to a multi-line value and reading it
  back with `printf 'filed-by: %s\n'` — the exact pattern `new.sh:317-318`
  already uses for `created`/`updated` — emitted `status: closed` and `num: 999`
  as genuine frontmatter lines. The spec mandates that filing be *refused*
  without an identity but says nothing about *encoding* the identity it does
  find. This is not hypothetical: the open issue
  `20260812-emitter-writes-created-and-updated-to-yaml-unencoded`
  documents that `new.sh` already prints two of its nine scalars unencoded while
  encoding three others, so an implementer has a live in-file precedent for
  making the wrong choice. A malformed-but-innocent value (a stray quote or
  colon) corrupts frontmatter and breaks the index by the same path, with no
  attacker required.
- **Suggestion:** Add an acceptance criterion requiring that the recorded
  identity be encoded through the emitter's existing untrusted-scalar path
  before it reaches the file, and that a value which cannot be safely encoded
  causes the same refusal as a missing one. State it as an observable
  requirement ("a recorded identity can never introduce additional frontmatter
  fields"), leaving the mechanism to the plan.
- **Route:** Spec
- **Relates to:** AC "When the developer's identity cannot be determined from
  the environment, filing an issue is refused and nothing is written"
  (Filer identity)

### 2. Contributor emails become plaintext in a repo slated to go public

- **Severity:** Notable
- **Description:** The conversion writes 350 real email addresses into tracked
  markdown bodies. Those addresses already exist in commit metadata, so this
  publishes nothing new in principle — but it moves them into a far more
  harvestable form: plain text in file content, greppable, indexed by code
  search and crawlers, and trivially scraped in bulk. `ROADMAP.md` § Now commits
  to making this repo public, so the change lands ahead of publication rather
  than after it. The spec treats the identity value as an implementation detail
  and never states what form it takes.
- **Suggestion:** Make the recorded identity's *form* an explicit spec decision
  rather than an implicit one — a full address, a local-part, or a configured
  handle. If addresses are kept, say so deliberately in Out of Scope so the
  choice is on the record before the repo goes public.
- **Route:** Spec
- **Relates to:** AC "A newly filed issue has its filer recorded automatically"
  (Schema); § Out of Scope

### 3. Claim takeover silently forges the provenance record

- **Severity:** Notable
- **Description:** The spec preserves `claimed-by` through close specifically as
  "the record of who did the work", and separately allows any developer to take
  a held issue with `--force`. Nothing records that a takeover happened or who
  performed it. A contributor can therefore overwrite the holder to themselves
  and close the issue, and the resulting record is indistinguishable from having
  genuinely done the work. The one field the spec designates as provenance is
  forgeable by design, and the spec's decision that "any developer can close any
  issue" removes the last coupling that would make this visible.
- **Suggestion:** Either weaken the claim that `claimed-by` is a provenance
  record (it is a *current holder* field, and Out of Scope should say
  attribution is not a security property), or add an acceptance criterion that a
  forced takeover is recorded observably. The first is cheaper and probably
  correct for a trusted-developer tool; what matters is that the spec not assert
  a guarantee it does not provide.
- **Route:** Spec
- **Relates to:** AC "Closing an issue preserves the record of who held it";
  AC "Claiming an issue another developer holds is refused ... can override"
  (Transitions)

### 4. New integrity warnings must route through the existing sanitizer

- **Severity:** Advisory
- **Description:** The spec's integrity ACs add three new warning shapes to
  `INDEX.md`. A closed issue in this collection
  (`index-sh-warnings-and-row-set-escape-the-sanitizer-discipline`) records that
  this exact surface has already leaked unsanitized content once. The spec's AC
  covers *body* content but the new warnings will interpolate field *values*
  (`outcome`, `type`, `part-of`) that are themselves untrusted.
- **Suggestion:** When the plan is written, require the new warnings to pass
  every interpolated value through `index.sh`'s existing `row_safe` (`:259`),
  matching the sibling warnings at `:392,399,430,459,479`.
- **Route:** Plan
- **Relates to:** AC "Integrity reports identify offending issues without
  reproducing their body content" (Integrity)

### 5. Mass rewrite of 350 files has no stated recoverability

- **Severity:** Advisory
- **Description:** The conversion rewrites every file in the collection. The
  spec requires a preview and a refuse-loudly failure mode, but says nothing
  about what happens if `--apply` fails partway — leaving the collection in a
  half-converted state that the preview's own accounting would then misreport.
- **Suggestion:** In the plan, inherit `migrate.sh`'s established guards rather
  than inventing new ones: per-file atomic tmp+mv, and the PLAN-HASH drift check
  (`migrate.sh:206-212`) that refuses an apply whose preview has gone stale.
- **Route:** Plan
- **Relates to:** AC "The conversion previews what it will change before
  changing anything" (Existing collection)

### 6. Per-contributor activity profile with no opt-out or redaction path

- **Severity:** Advisory
- **Description:** `filed-by` attributes every discovery in the collection to a
  named individual, and `claimed-by` records what each person holds. Aggregated
  across a public collection this composes into a per-person activity profile —
  what someone works on, when, how much, and what they abandoned. The 8 issues
  attributable to the second contributor are backfilled without that person's
  involvement, and the spec provides no way for anyone to remove or alias their
  identity afterward (identity reconciliation is explicitly Out of Scope).
- **Suggestion:** Track as a follow-on rather than expanding this spec: a
  redaction or aliasing path so a contributor can amend how they appear.
  `git check-mailmap` is available (verified, git 2.55.0) and is the
  conventional mechanism.
- **Route:** Issue
- **Relates to:** § Out of Scope "Reconciling one person's several identities"

### Plan-phase findings (2026-08-18)

### 7. Identity validation is specified as a blocklist, not an allowlist

- **Severity:** Notable
- **Description:** The plan resolves the identity and rejects "any value bearing
  a newline, carriage return, quote, or colon." That enumerates *known-bad*
  characters, so anything unanticipated passes: Unicode line separators (U+2028,
  U+2029), a value beginning `---`, a trailing backslash, or a stray control
  character all survive a blocklist while remaining capable of disturbing the
  record. The spec's criterion is absolute — a recorded identity can never
  introduce additional fields *whatever the environment supplied* — and a
  blocklist cannot satisfy a "whatever" clause, because it only ever covers what
  its author thought of. The demonstrated injection used a newline; the point is
  that the next one will not.
- **Suggestion:** Specify the validator positively — accept only a bounded
  character set on a single line, reject everything else — so unanticipated input
  fails closed rather than open. This also matches the group's existing
  validate-before-use discipline, where ids clear a positive validator before any
  path is composed.
- **Route:** Plan
- **Relates to:** Design Decision 2; Task 2

### 8. No task verifies a transition under a branch placement

- **Severity:** Notable
- **Description:** The spec requires that every transition behave identically
  whether the collection sits on the working branch or a designated shared one.
  The plan opens the placement door in task 9 and tests the five verbs in task
  10, but nothing pins those tests to a destination-branch placement — and under
  the default placement the door is inert by design, so a green suite would
  demonstrate only that transitions work where the door does nothing. The
  existing coverage is lopsided in the same direction: the door's own tests
  reference placement heavily while the issue-script tests barely do, so the
  gap would not be caught incidentally.
- **Suggestion:** Add a task that exercises at least one transition against a
  configured destination branch, asserting the edit lands there and the commit
  carries the matching verb. Without it, the placement criterion is satisfied by
  construction rather than by evidence.
- **Route:** Plan
- **Relates to:** AC "Every transition works identically whether the collection
  lives on the working branch or on a designated shared branch"; Tasks 9, 10

### 9. The outcome argument is not stated to be validated before it is written

- **Severity:** Notable
- **Description:** The Interface Contract enumerates the four permitted outcomes,
  but no task requires the close verb's outcome argument to be checked against
  that enum before it reaches the file. It is developer-supplied input on the
  same path as the identity, and the plan hardens the identity while leaving this
  one unstated. The index would report an unrecognized value afterward, which
  detects the problem rather than preventing it.
- **Suggestion:** Require enum validation of the outcome argument at the point of
  transition, refusing an unrecognized value before any write — mirroring the
  identity treatment rather than relying on downstream reporting.
- **Route:** Plan
- **Relates to:** Interface Contracts; Task 10

### 10. A superseded outcome's link is detected but never enforced

- **Severity:** Advisory
- **Description:** The spec states that an issue whose outcome is superseded
  identifies the issue that supersedes it. The plan maps that criterion solely to
  the index integrity warning, so closing an issue as superseded without naming a
  superseding issue is permitted at write time and reported only afterward. The
  criterion reads as a data requirement; the plan implements it as a lint.
- **Suggestion:** Either require the superseding reference when closing with that
  outcome, or record in the plan that the criterion is deliberately satisfied by
  detection rather than prevention. Both are defensible; leaving it implicit is
  what should not stand.
- **Route:** Plan
- **Relates to:** AC "An issue whose outcome is superseded identifies the issue
  that supersedes it"; Tasks 5, 10

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Findings 1, 3, 7 — forged frontmatter identity; forged work attribution via takeover; unanticipated identity input surviving a blocklist |
| Tampering | Yes | Findings 1, 7, 9 — injected frontmatter can rewrite `status`, `num`, and any other field; unvalidated outcome argument on the same write path |
| Repudiation | Yes | Findings 3, 8 — no audit trail for takeover, and the holder record is overwritable without trace; the published verb that would make a centralized collection's history self-describing is never exercised in tests |
| Information Disclosure | Yes | Findings 2, 4, 6 — emails in public content; warning-surface leakage; profile aggregation. The claim refusal naming the current holder is an intentional disclosure the spec requires, accepted under the trusted-developer model — not a finding |
| Denial of Service | N/A | No service and no request path — every operation is an operator-run one-shot CLI invocation against local files |
| Elevation of Privilege | N/A | jim has no privilege tiers; the trusted-developer model gives every contributor equal repo access, so there is no boundary to cross |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | Yes | Finding 6 — every discovery links to one subject across the whole collection |
| Identifying | Yes | Finding 2 — an email address identifies the subject directly, with no anonymization step |
| Non-repudiation | Yes | Finding 6 — permanent attribution; a contributor cannot plausibly disclaim a filing |
| Detecting | N/A | Presence is recorded outright rather than inferable — there is no side channel to detect through |
| Data Disclosure | Yes | Finding 2 — personal data moves into content published beyond the subject's original act of committing |
| Unawareness & Unintervenability | Yes | Finding 6 — the second contributor is backfilled without involvement and has no intervention path |
| Non-compliance | No | No stated privacy policy or applicable regulation governs an open-source project's own issue collection; addresses were already published by the subjects' own commits |

## Artifact Misalignment

*Both artifacts reviewed together; these identify spec↔plan inconsistencies
rather than defects in either alone.*

- **Finding 8 — placement parity is asserted but not evidenced.** Spec requires
  every transition to behave identically under either placement; the plan
  verifies transitions only where the placement door is inert. Route: Plan — the
  spec's requirement is right, the plan's evidence is missing.
- **Finding 10 — a data requirement implemented as a lint.** Spec states a
  superseded outcome *identifies* its superseding issue; the plan satisfies that
  criterion solely through an after-the-fact index warning, permitting the
  inconsistent state at write time. Route: Plan — or an explicit spec note that
  detection is the intended standard.

**Checked and aligned.** Two spec-phase findings are resolved by the plan rather
than misaligned with it: the integrity-warning sanitizer (Finding 4) is required
explicitly by Task 5, and the conversion's recoverability (Finding 5) is
satisfied by Design Decision 1's shared drift guard plus per-file atomic writes.
The drift guard's refusal path is covered by the existing suite, so the plan's
"existing tests are the contract" mitigation for that extraction is load-bearing
rather than aspirational.

## Routing Recommendations

### Spec amendments

*All three applied to `spec.md` on 2026-08-17.*

- **Finding 1 (Critical):** ✅ Applied — new AC under *Filer identity*: a
  recorded identity can never introduce additional fields into the issue record,
  and an unrecordable value is refused exactly as a missing one is.
- **Finding 2:** ✅ Applied and since **resolved**. The open question closed to:
  store what version control supplies, unmodified. The form is already a
  per-contributor decision — each contributor's own VCS config decides it, and
  one wanting non-routable attribution configures a forge noreply address, so
  the preference is expressed where it belongs and jim carries no branch for it.
  Two Out of Scope exclusions record the reasoning: no normalization or
  obscuring of the value, and no project-wide identity policy. The residual
  exposure is accepted knowingly — a public commit history publishes the same
  addresses in bulk, so reducing the stored form would not prevent harvesting.
- **Finding 3:** ✅ Applied — the Out of Scope provenance claim was withdrawn
  ("a record of who *held* the issue", not "who did the work") and a new
  exclusion states outright that the holder field is a coordination signal, not
  a tamper-evident attribution, and must not be relied on as one.

### Plan amendments

*Findings 4 and 5 are now **resolved** — the plan consumed both.*

- **Finding 4:** ✅ Resolved — Task 5 requires every interpolated value in the
  new integrity warnings to pass through the existing sanitizer.
- **Finding 5:** ✅ Resolved — Design Decision 1 puts the conversion on the
  shared drift-guard machinery, with per-file atomic writes. The guard's refusal
  path is covered by the existing suite.

*From the plan-phase pass — all four applied to `plan.md` on 2026-08-18.*

- **Finding 7 (Notable):** ✅ Applied — Design Decision 2 now specifies the
  identity validator positively, with the reasoning that an absolute criterion
  cannot be met by an enumeration of known-bad input. Task 2 adds a case proving
  the validator fails closed on input outside any obvious blocklist.
- **Finding 8 (Notable):** ✅ Applied — new task 10c exercises a transition
  against a configured destination branch, asserting both the landing place and
  the published verb.
- **Finding 9 (Notable):** ✅ Applied — new task 10a validates the outcome
  argument against its enum before any write, refusing at rc 2 with nothing
  written.
- **Finding 10 (Advisory):** ✅ Applied — resolved toward enforcement rather than
  detection: new task 10b refuses a superseded close that names no superseding
  issue. The spec states the link as a property of the record, so permitting the
  record to contradict it and reporting afterward was the weaker reading.

### Candidate issues

- **Finding 6:** Filed as
  `20260817-add-a-redaction-or-aliasing-path-for-contributor-identity`, then
  **closed as obsolete** once this spec's open questions resolved — the issue
  had been filed before them. It is no longer live tracking; the closure note on
  that issue carries the full reasoning. In short: a configurable recorded form
  is now excluded outright; a redaction verb would not deliver privacy while the
  commit history retains the same addresses; and alias adoption folded back into
  this spec as an architect note on Insight 3, since the derivation can honor a
  project's existing alias mapping at no cost.

  The residual privacy exposure is therefore **accepted, not mitigated**. What
  stays genuinely uncovered is retroactive change for a contributor who files
  under one address and later prefers another — a version-control history
  problem rather than an issue-collection one, and one to re-file against that
  framing if it ever becomes a real request.
