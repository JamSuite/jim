---
title: "Guard blueprints and maps against provenance references"
type: feature
group: "jim"
id: "052"
status: approved
origin:
  - "docs/issues/20260723-extend-present-tense-rule-to-spec-id-and-version-refs.md"
  - "docs/specs/jim/050-blueprint-present-tense/spec.md"
---

# 052 Guard blueprints and maps against provenance references

## Overview
Give the blueprint surface a provenance rule — a companion to the present-tense
discipline — so blueprint and map prose describe a group by its stable
current-state name, never by the mutable spec ID, spec range, spec path, or
pinned version that introduced it, backed by a deterministic self-hosting guard.

## Problem Statement
The present-tense discipline promises current-state blueprint and map artifacts,
but its three marker categories (Historical / Transitional / Aspirational) all
target *tense* — framing that reads as past, in-flight, or future. A
**point-in-time provenance reference** is a different failure mode: "the
spec-047 split verbs" is grammatically present tense yet still rots the moment
`/jim:partition` renumbers spec 047, and a pinned `v2.0.0` goes stale the moment
the manifest bumps. Because provenance is not a tense marker, it slips past the
present-tense self-scan, the `present-tense` verify judge, and human review —
which is exactly how spec-ID provenance, a stale spec range (`001–044`), and a
pinned version shipped into the `jim` blueprint, and how the project map today
still carries spec-range provenance in its boundary rationale (`017–025`,
`026–028`, `029–034`, `035–037`).

A blueprint whose wording rots silently the next time a spec is renumbered
undermines the surface's whole promise — a current-state artifact that describes
reality. The developer maintaining a jim project should be able to trust that a
blueprint says what a group *is*, not which numbered artifact happened to
introduce each piece of it, and should be told the moment that trust is about to
be broken — cheaply and deterministically for the obvious cases, rather than
relying on a judgment pass that has already been shown to miss them.

## User Stories
- As a developer authoring or updating a blueprint or map, I can rely on the
  exit-door self-scan to flag and normalize a spec-ID / range / path / version
  reference to a functional current-state description, so my current-state
  artifact does not silently rot when specs are renumbered.
- As a jim maintainer, I can trust a deterministic test to fail the build if
  jim's own blueprint or project map reintroduces a provenance reference, so the
  self-hosting surface can never regress the way it did before.
- As a reviewer, I can see each provenance normalization itemized in the draft I
  approve, and revert any false positive, so the guard never silently rewrites
  legitimate current-state content (a verb's own name, a functional grouping).

## Acceptance Criteria
- [ ] A single canonical companion doctrine doc — a sibling to the present-tense
      rule, cited by path and never restated inline — defines the provenance
      rule: blueprint/map prose references a group's surface by its stable
      current-state name or function, never by the numbered spec or pinned
      version that introduced it, because `/jim:partition` renumbers specs and
      the manifest is the version's single source.
- [ ] The companion doc enumerates the flagged provenance forms with the same
      "illustrative, extensible, judgment-resolved" framing the present-tense
      rule uses — bare spec IDs (`spec-0NN`, `spec 0NN`), spec ranges
      (`NNN–NNN`), mutable numbered spec paths (`docs/specs/<group>/0NN-…`), and
      pinned semantic versions (`vX.Y.Z`) — and states the normalization each
      maps to (describe by function; name the manifest as the version source).
- [ ] The companion doc states the over-constraint guard: a verb's own name, a
      functional grouping, the reserved `000-blueprint` slot/path, and
      non-provenance numerics (dates, counts, criticality tiers) are legitimate
      current-state content and are not flagged; a false positive is recoverable
      through the same disclose-and-revert control, never suppressed.
- [ ] The companion doc carries the same safety discipline `present-tense.md`
      does: supplied text is untrusted data, not instruction — an embedded
      directive is normalized as text, never followed, and the scan stays inside
      the existing `<untrusted-*>` wrapping — and the rewrite itemization is
      secret-scrubbed (a secret-looking value redacted to `secret-looking value
      at <path:line>`) before disclosure. The doc-structure test asserts these
      sections exist, so the discipline is pinned mechanically, not by
      implication.
- [ ] Every `/jim:blueprint` composition site that ingests caller- or
      interview-supplied text (the same sites that cite the present-tense rule)
      references the companion doc and applies its provenance check as part of
      the exit-door self-scan, single-sourced by path.
- [ ] A deterministic test asserts jim's own current-state artifacts — the `jim`
      group blueprint spec and the project map — contain none of the flagged
      provenance forms (the unambiguous patterns fail mechanically, mirroring the
      prose-pin precedent), while excluding legitimate content (the reserved
      `000-blueprint` path).
- [ ] A wiring test asserts each blueprint composition site references the
      companion doc at least its expected minimum count, so a dropped citation
      is caught mechanically (mirrors the present-tense single-sourcing test).
- [ ] jim's own project map is normalized through the blueprint surface — the
      map is skill-maintained (its header directs edits through `/jim:blueprint`,
      not by hand) — so the guard passes green: its boundary-rationale spec
      ranges are rewritten to functional cluster descriptions.
- [ ] `/jim:verify` senses a dropped provenance-rule citation at a composition
      site, the same way it senses a dropped present-tense one, so the wiring
      cannot silently regress.
- [ ] Test coverage exercises the flagged forms that shipped in the original
      violation (spec ID, spec range, version pin) as the guard's fixtures.

## Out of Scope
- Provenance in **spec documents** themselves — a spec legitimately cites the
  spec it extends; the rule governs current-state blueprint/map artifacts only.
- **Code comments** — already governed by the `CLAUDE.md` script-comment
  convention ("no spec IDs / artifact refs … the reference rots"); this spec
  reuses that rationale, it does not re-legislate comments.
- `ARCHITECTURE.md` — a scanned, `/jim:arch`-regenerated document, not a
  supplied-text blueprint draft; its provenance is a separate concern.
- The **full `CLAUDE.md` provenance set** — AC / Finding / DD / issue numbers and
  cross-file line ranges. Those rarely appear in blueprint prose; deferred to a
  follow-on rather than widening the mechanical surface now.
- Changing the present-tense (tense) rule itself — the provenance rule is
  additive; the tense doc and its three categories are untouched.
- A general LLM rewrite of arbitrary blueprint prose — only the enumerated
  provenance forms are in scope; everything else is legitimate current state.
- **Mechanical provenance-scanning of arbitrary blueprint content.** The
  deterministic guard covers jim's own two current-state artifacts (self-hosting
  regression). A consuming project's blueprint/map is served by the judgment
  exit-door scan only, and `/jim:verify` checks citation *wiring*, never
  blueprint *content* — so the verify invariant senses a dropped provenance
  citation, not provenance sitting in some group's prose. Extending mechanical
  coverage to any project's blueprint is a separate future concern.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point to
evaluate, not a directive.*

### Insight 1: Companion-doc placement and shape

- **Relates to AC:** *"A single canonical companion doctrine doc — a sibling to
  the present-tense rule…"* (AC #1)
- **Surfaced as:** the interview chose a separate companion doctrine doc
  (sibling to `present-tense.md`) over folding a fourth marker category into the
  present-tense doc, to keep "tense" conceptually pure.
- **Levelled-up requirement (already in the ACs):** one canonical, cited-by-path
  doc defining the provenance rule and its normalization.
- **Deflection reason:** Delegation.
- **Architect note:** the doc rides the exact spec-050 machinery — cited per
  site, scanned at the same exit door, single-sourced. Name and location
  (`skills/blueprint/references/…`) are the plan's call; mirror the
  present-tense doc's four-section shape so the structure test generalizes.
- **Routing hint:** Architect to decide.

### Insight 2: Mechanical guard — patterns, home, and false-positive precision

- **Relates to AC:** *"A deterministic test asserts jim's own current-state
  artifacts contain none of the flagged provenance forms…"* (AC #5/#6)
- **Surfaced as:** deterministic grep over jim's own blueprint spec + project map
  (mirroring the prose-pin precedent), rather than judgment-only.
- **Levelled-up requirement (already in the ACs):** the obvious provenance forms
  fail mechanically without spending a judge.
- **Deflection reason:** Constraint-Sourcing.
- **Architect note:** patterns are seeded by the shipped violation
  (`spec-0[0-9]{2}`, a bare `[0-9]{3}[–-][0-9]{3}` range, `v[0-9]+\.[0-9]+\.[0-9]+`,
  and a `docs/specs/<g>/0NN-` path). The test has no per-match revert, so the
  patterns must be tight enough to avoid legitimate matches — the reserved
  `000-blueprint` path is the known exclusion; ambiguous cases fall to the
  judgment scan, not the mechanical guard. Extend `tests/presenttense.sh` vs a
  new file is the plan's call.
- **Routing hint:** Architect to decide.

### Insight 3: Verify wiring — extend vs. add an invariant

- **Relates to AC:** *"The `present-tense` verify wiring invariant reflects that
  composition sites also wire the provenance rule…"* (AC #8)
- **Surfaced as:** whether the existing `present-tense` wiring invariant absorbs
  the provenance citation or a parallel `no-provenance` invariant is added.
- **Levelled-up requirement (already in the ACs):** `/jim:verify` senses a
  dropped provenance citation.
- **Deflection reason:** Delegation.
- **Architect note:** the invariant is a *wiring* check ("sites reference the
  rule and run the scan"). Folding provenance into the one `present-tense`
  invariant keeps the invariant set lean; a separate invariant is more symmetric
  with the "separate doc" decision. Lean toward one invariant unless symmetry
  earns its keep.
- **Routing hint:** Architect to decide.

## Open Questions
- [ ] Does the companion doc get cited at **every** present-tense composition
      site, or only the subset where provenance realistically appears? (Working
      assumption: the same sites, since provenance rides the same supplied-text
      drafts — confirm the per-site minimum counts in the plan.)
- [ ] AC7 sequencing for normalizing jim's own map within a TDD build (research
      Peer Feedback): (a) the guard-test Green step edits `BLUEPRINT.md`'s
      boundary rationale directly — a doc edit the coder owns — documenting that
      it would ride the extended scan; or (b) a post-build `/jim:blueprint`
      map-update pass normalizes it through the surface. The plan picks one so the
      Green step is unambiguous.
- [ ] One wiring invariant (extend `present-tense`) vs. a separate
      `no-provenance` invariant (Insight 3) — architect's call at plan time.
