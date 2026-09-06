---
id: 20260717-evaluate-optional-ears-when-then-testable-ac-grammar-and-a-spec-
num: 81
title: "Evaluate optional EARS/WHEN-THEN testable-AC grammar and a spec-check testability lint"
status: open
priority: medium
type: issue
filed-by: "dorsma"
claimed-by: ""
outcome: ""
labels: [spec, spec-check, testability, grammar]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-17T22:22:04Z
updated: 2026-07-17T22:22:04Z
origin: docs/research/20260717-competitive-landscape-sdd-skills.md
---

## Description

## Why

jim's acceptance criteria are **free-prose** today. `/jim:spec-check` judges their testability by (good, but) subjective reading. The developer prefers **more deterministic-looking grammar when possible**. Evaluate offering an *optional*, constrained AC grammar that spec-check can audit mechanically — tightening testability at *authoring* time instead of catching vagueness later.

## What EARS is (plain terms)

**EARS = "Easy Approach to Requirements Syntax."** A small constrained grammar that forces every AC to name a **trigger + the system + an obligation + an observable outcome**:

- Free-prose (today): *"The system should handle invalid logins gracefully."*
- EARS: *"**WHEN** a user submits invalid credentials, **THE SYSTEM SHALL** reject the login and **SHALL NOT** create a session."*

Keywords: `WHEN` (event) / `WHILE` (state) / `WHERE` (feature context) / `IF…THEN` (edge) + `THE SYSTEM SHALL`. Kiro uses this; it has a bug-spec non-regression variant *"…SHALL CONTINUE TO…"*. OpenSpec's variant: each requirement carries `#### Scenario:` blocks with WHEN/THEN bullets — testability baked into structure rather than audited after.

## Value for jim

- Each AC maps ~1:1 to a test (trigger → action → observable outcome).
- `/jim:spec-check` gains a **deterministic lint** ("does each AC name a trigger + an observable outcome?") — more mechanical than judging prose quality, which is exactly the "deterministic-looking grammar" the developer wants.
- The bug-spec `SHALL CONTINUE TO` clause could strengthen jim's existing bug-spec regression-guard requirement.

## The nuance to evaluate (why "evaluate," not "adopt wholesale")

- EARS can feel rigid/verbose; jim deliberately keeps ACs **user-observable and free-prose** to avoid the over-specification anti-pattern. So this is most likely an **optional grammar mode** and/or a **spec-check lint that *flags* untestable ACs** — NOT a mandatory rewrite of every AC.
- Decide at spec time: opt-in per spec? default-on with an escape hatch? lint-only (warn) vs. enforce (gate)?
- **Interaction with existing spec-check (spec 015):** the grammar check would be an added, more-deterministic *testability tier* that complements — not replaces — the three-tier AC classification (Functional / External Constraint / Implementation Detail) and the Socratic Probes. spec-check works well today; this makes its testability judgment more mechanical, it doesn't rip anything out.

## Scope sketch

- Add an optional EARS/WHEN-THEN AC style to the spec template + guidance in `/jim:spec` (Mockup-First / interview already produce ACs; this shapes their form).
- Add a `/jim:spec-check` lint that classifies each AC as grammar-conformant/testable or flags it, feeding the existing audit output.
- Keep free-prose allowed by default; grammar is an option/lint, not a hard gate — unless the developer chooses to make it a gate.

## Meta-skill boundary (does this belong in a meta-skill?)

Considered per developer question. **No — this is a `/jim:spec` + `/jim:spec-check` feature, not a `/jim:meta-skill` / `/jim:meta-agent` concern.** The meta-skills *build jim's own plugin components*; EARS governs how *user-facing acceptance criteria* are authored and audited. The only artifacts it touches — `skills/spec/assets/spec-template.md` and `skills/spec/references/spec-dod.md` — live **inside the spec skill**; `/jim:meta-skill` would merely be the *tool* used to edit them, not the owner of the grammar. (Note the self-hosting wrinkle: jim writes its *own* specs via `/jim:spec`, so the grammar would also apply to jim's internal specs — but still via the spec skill, not the meta layer.) If a shared convention doc is wanted, the natural home is `ARCHITECTURE.md` conventions or the spec-check references, not a meta-skill.

## References

- Landscape doc: Kiro EARS + OpenSpec `#### Scenario:` WHEN/THEN anchors; Cross-Cutting Pattern #1 (testable-AC grammar). `docs/research/20260717-competitive-landscape-sdd-skills.md`.
- `/jim:spec-check` (spec 015 — Socratic DoD, three-tier AC classification): where the lint would live.
