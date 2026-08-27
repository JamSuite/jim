---
spec: "docs/specs/issue/015-epic-authoring-and-views/spec.md"
reviewed_phases: [spec]
status: "Needs Spec Review"
date: "2026-08-27"
---

# Security Review: Epic authoring and views

## Summary

**Findings:** 0 Critical · 3 Notable · 2 Advisory

Spec-lens review of the epic increment, against the `issue` group blueprint's
invariants and `ARCHITECTURE.md`'s recorded trust boundaries. The increment
adds no new external surface and no new class of secret; its risk is
concentrated in one place — it introduces a **second structure** into a
generated artifact whose safety properties were written for the first, and a
**second id-shaped operand** onto a write path whose validator ordering was
written for one. LINDDUN is active because the records carry contributor
identities, but every finding it raises is inherited rather than introduced.

## Coverage

- spec.md — reviewed 2026-08-27 (requirements-gap lens)

`plan.md` does not exist yet, so no design-flaw lens was applied. The
plan-phase gate will need its own pass; three of the findings below are
specifically the kind that a spec-lens review can only state as a requirement
and a plan-lens review must then check as a design.

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | Yes | Contributor identities in `filed-by` and `claimed-by`. An umbrella is an issue and carries both; the spec adds no new identity field and no new identity display. Inherited from spec 012 / 013. |
| Credentials | No | No secret, key, token or password is read, stored or transported. |
| Session data | No | No session state exists in this system. |
| Internal-only | Yes | Issue bodies, `origin` paths naming internal spec directories, and project-internal ordinals. |
| Public | Yes | The collection is published content — the index and the issue files reach the same destination by the same door. |

## Findings

### 1. The index's new section inherits a safety property written for a different shape

- **Severity:** Notable
- **Description:** The spec requires that "a record's own field values can
  never corrupt the structure of the index that carries them," and sources
  that to the existing row sanitizer, which strips the row separator and
  control characters and bounds length. That sanitizer was designed for a
  **flat, single-line, separator-delimited row**. The section this spec adds
  is a different structure: a per-umbrella line carrying an untrusted title
  and a derived count, followed by **indented member lines**. Nesting is a
  structural dimension the row format does not have, and the property "cannot
  forge a row" does not by itself establish "cannot forge a nesting level or a
  member entry." The blueprint's `row-shape-is-the-writers` invariant is
  likewise written in terms of rows and `key: value` pairs.
- **Suggestion:** State the containment requirement in terms of the new
  section's own structure rather than by citing the row sanitizer — that no
  field value can introduce a line into the section, change a member's
  apparent umbrella, or alter nesting depth. That forces the plan to
  demonstrate the sanitizer covers the new dimension instead of assuming
  inheritance, and it gives the plan-lens pass something specific to check.
- **Route:** Spec
- **Relates to:** AC — "A record's own field values can never corrupt the
  structure of the index that carries them" (§ What the index records)

### 2. The roster derivation has no stated termination guarantee, and the index only warns about the records that would break it

- **Severity:** Notable
- **Description:** The spec forbids epic-inside-epic at the write path and
  requires the index to *report* violations that arrive by hand-edit. Reporting
  is not refusing: a violating record persists in the collection and is read by
  every derivation on every subsequent write. Two records naming each other as
  umbrellas are representable, and nothing in the ACs requires the roster or
  progress derivation to terminate over them. The blast radius is
  disproportionate to the cause — the index regenerates on **every** write, and
  every group's end-of-phase candidate batch files through the emitter that
  triggers it, so a non-terminating derivation stops all filing project-wide,
  not just epic views.
- **Suggestion:** Add a requirement that the derivations terminate for any
  content the collection can hold, including membership that violates the
  containment rule. The spec already decided membership is one level; the
  derivation should depend on that decision being *enforced at read time*, not
  on it having been enforced at write time. This is the reason the write-path
  refusal and the index warning are not redundant.
- **Route:** Spec
- **Relates to:** AC — "The collection index reports any membership that
  violates either rule" (§ What an umbrella may contain) and "An umbrella's
  roster can never disagree…" (§ The umbrella's own views)

### 3. A second id-shaped operand reaches a write path whose validator ordering was written for one

- **Severity:** Notable
- **Description:** Every existing lifecycle verb takes exactly one id, and the
  script gates it deliberately: the id clears the validator **before any path
  is composed from it, including the stat inside the slug resolver**, and the
  resolved slug is re-validated afterwards because only one of the resolver's
  two arms returns a value the first check covered. `join`/`leave` introduce a
  second id-shaped operand — the umbrella — and the ACs require only that an
  unresolvable umbrella be refused. "Refused because it names no record" and
  "validated before it is composed into a path" are different properties, and
  only the first is stated. The group's blueprint carries `id-gate-before-path`
  at **critical**.
- **Suggestion:** Require that an umbrella reference clear the same validation
  as the issue reference, in the same order relative to any path composition or
  filesystem access. Stating it at the spec level matters because the natural
  implementation — resolve the umbrella against the index to check it exists —
  reads like validation while performing a lookup, and the existing code's
  comment exists precisely because that distinction was subtle the first time.
- **Route:** Spec
- **Relates to:** AC — "A developer can put an existing issue under an umbrella,
  and take it out again, through a single command each" (§ Creating an umbrella
  and joining it)

### 4. Membership cardinality is unbounded, and the index renders it on every write

- **Severity:** Advisory
- **Description:** An issue may name several umbrellas and nothing enforces a
  count — a deliberate decision carried from spec 012. The new section renders
  membership into a committed artifact that regenerates on every write, so the
  cost of an unbounded field is paid repeatedly and by every reader of the
  repository, not once by its author. One spec in this collection's own history
  generated 88 issues, so a full roster is already large at realistic scale
  without anyone behaving unusually.
- **Suggestion:** The spec's second open question already asks whether the
  section lists every member or a capped view. Settle membership *cardinality*
  in the same decision rather than only the display: they are one question
  about how much a single record can add to a generated file. Measuring against
  the real collection, as the preceding increment did for its row widening, is
  the cheap way to answer it.
- **Route:** Spec
- **Relates to:** AC — "An issue can belong to several umbrellas" (§ Creating an
  umbrella and joining it); Open Question 2

### 5. Derived progress is computed from records the umbrella's author does not control

- **Severity:** Advisory
- **Description:** Membership is stored on the member and the roster is derived,
  so any record can enter any umbrella's roster by editing its own frontmatter,
  and the umbrella's file records nothing about it. The progress figure an
  umbrella reports is therefore a function of records its author neither owns
  nor can see from the file. This is within the project's stated trust boundary
  — repository write access — and it follows directly from the storage model
  the spec chose deliberately. It is not a defect. It is an integrity property
  that the spec does not currently state, and the same class has been stated
  explicitly in each of the three preceding increments.
- **Suggestion:** Record it where those precedents put it — an Out of Scope
  entry saying the progress figure is a coordination signal rather than an
  attestation, that it moves when any member record changes, and that it must
  not be relied on as evidence about who did what. This is a documentation
  requirement, not an acceptance criterion; see Routing Recommendations.
- **Route:** Spec
- **Relates to:** § Out of Scope; AC — "An umbrella's roster can never disagree
  with the records that claim membership in it" (§ The umbrella's own views)

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | No | The increment adds no authentication surface and no new identity field. Identity is inherited from specs 012/013 and reviewed there. |
| Tampering | Yes | Finding 1 (structure forgery in the new section), Finding 5 (roster composition by any record). |
| Repudiation | No | Every membership change publishes through the existing two-phase door under a verb enum, so a centralized collection's history stays self-describing. No new unlogged mutation is introduced. |
| Information Disclosure | No | The new section carries slugs, titles, statuses and counts — no identity. The identity-concentration trade was named and accepted in spec 014 and is not extended here. |
| Denial of Service | Yes | Finding 2 (non-terminating derivation blocks the single write door), Finding 4 (unbounded roster in an artifact regenerated on every write). |
| Elevation of Privilege | N/A | There is no privilege model to elevate within — membership is edited by whoever runs the verb, with no ownership check, which the spec states as a deliberate exclusion rather than an oversight. |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | No | The new section carries no identity field, so grouping by umbrella adds no linkage the row identities did not already permit. The concentration trade is recorded in spec 014's Out of Scope. |
| Identifying | No | No anonymized or pseudonymized data is introduced that re-identification could act on; recorded identities are already direct. |
| Non-repudiation | No | Subjects are contributors acting on their own records; nothing here removes an ability to deny an action that they previously had. |
| Detecting | No | Membership reveals that an issue exists in a theme, over a collection that is published in full. Presence is not concealed anywhere in this system. |
| Data Disclosure | No | No data crosses a boundary it did not already cross — the index and the issue files share one destination and one door. |
| Unawareness & Unintervenability | N/A | Data subjects are the project's own contributors, acting directly on their own records, with no third-party processing to be unaware of. |
| Non-compliance | N/A | No privacy policy or regulatory regime is asserted over this collection; spec 013 states explicitly that this is not a privacy feature. |

## Routing Recommendations

### Spec amendments

- **Finding 1** — new AC requiring the containment property to hold for the
  index section's own structure, including nesting and member lines, rather
  than by inheritance from the row sanitizer.
- **Finding 2** — new AC requiring the roster and progress derivations to
  terminate over any membership the collection can hold, including one the
  containment rule forbids.
- **Finding 3** — new AC requiring an umbrella reference to clear the same
  validation as an issue reference, in the same order relative to path
  composition.
- **Finding 4** — new AC bounding what one record can contribute to the
  generated section, settled together with Open Question 2.
- **Finding 5** — **not an acceptance criterion**, and applied by hand rather
  than by the auto-router, whose sanctioned target is the Acceptance Criteria
  list. Landed as the Out of Scope entry *"Tamper-evident membership or
  progress"*, recording that an umbrella's progress is a coordination signal
  rather than an attestation, that it moves when any member record changes
  without leaving a trace in the umbrella, and that nothing downstream may read
  it as evidence of how much work was done or who did it. Phrased to restate
  for progress what the schema increment recorded for the holder field, so the
  two read as one policy rather than two coincidences.

### Plan amendments

None — `plan.md` does not exist. Findings 1, 2 and 3 each state a requirement
that the plan-lens pass must then check as a design; they are the reason a
second security pass on this increment is likely to earn itself.
