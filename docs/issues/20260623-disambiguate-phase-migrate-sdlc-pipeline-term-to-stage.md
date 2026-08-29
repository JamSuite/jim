---
id: 20260623-disambiguate-phase-migrate-sdlc-pipeline-term-to-stage
num: 12
title: "Disambiguate \"phase\": migrate SDLC pipeline term to \"stage\""
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [terminology, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-06-23T07:10:26Z
updated: 2026-06-23T07:10:26Z
origin: conversation
---

## Description

"Phase" is overloaded across jim's docs. It names two different things:

1. **SDLC pipeline stages** — spec → plan → build → review → ship. This is the
   dominant usage: "downstream phase", "gated phase", "Skipping Phases", "phase
   gate", "end-of-phase candidate batch", "end of each development phase".
2. **Roadmap milestones** — VISION.md's "Phase 1 / Phase 2 / Phase 3" and
   ROADMAP.md's "phase sequence" / "phase breakdowns", a higher-level strategic
   grouping that spans many pipeline runs.

The collision is a readability tax: a field or sentence mentioning "phase"
forces the reader to infer which sense is meant. It surfaced concretely while
reviewing `/jim:review`'s `phase_coverage` frontmatter field, where "phase"
reads as "which pipeline stages ran" but the field is actually populated with
artifact names.

**Proposed action:** migrate the *pipeline* sense to "stage" and reserve
"phase" for the higher-level roadmap milestone sense. This is a cross-cutting
terminology change — it would touch WORKFLOW.md, the ARCHITECTURE.md glossary
("Phase gate"), the "end-of-phase candidate batch" step shared across seven
skills, config-key descriptions (`issue_capture`), and frontmatter field names
(`phase_coverage`, `reviewed_phases`). Given the blast radius and the
back-compat surface (existing `security.md` / `review.md` frontmatter), it
warrants a dedicated spec rather than an ad-hoc rename.
