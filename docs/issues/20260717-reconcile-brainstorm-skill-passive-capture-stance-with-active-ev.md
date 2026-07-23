---
id: 20260717-reconcile-brainstorm-skill-passive-capture-stance-with-active-ev
num: 85
title: "Reconcile brainstorm skill's passive-capture stance with users' expectation of active evaluation"
status: open
priority: medium
labels: [brainstorm, skill, ux]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-17T18:07:21Z
updated: 2026-07-17T18:07:21Z
origin: conversation
---

## Description

# Reconcile brainstorm skill's passive-capture stance with users' expectation of active evaluation

## Discovery

During a design session on the arch/knowledge-corpus brainstorm, the user explicitly
asked to be reasoned *with* — "help me brainstorm this topic, don't just ask me what do
you want, do your job" — expecting positions, tradeoffs, and recommendations, not passive
capture.

But `skills/brainstorm/SKILL.md` Step 4 currently instructs the **opposite**:
- *"Do not critique or evaluate ideas — capture them. Evaluation happens later if the user decides to spec."*
- *"The PM's role is active listener and synthesizer."*
- *"Ask light clarifying questions ... Not a full PM interview."*

So there is a genuine tension: the skill is scoped as pure freeform capture (no
frameworks, no evaluation), while at least this user expects a brainstorm to include
active synthesis, position-taking, and reasoned recommendation.

## Proposed action (to scope later)

Revisit whether `/jim:brainstorm` should support (or default to) an **evaluative /
position-taking mode** distinct from pure capture — e.g. a toggle, a config key, or a
revised Step 4 that permits reasoned synthesis and recommendations while still not
*pushing* toward a spec. Weigh against the deliberate design intent (freeform ideation,
"don't impose frameworks") and VISION's "transparency over automation." Decide via
`/jim:spec` or a follow-up brainstorm on the skill itself.

## Notes

- Surfaced from user feedback while producing `docs/brainstorms/20260717-jim-arch-knowledge-corpus.md`.
- Not urgent; captured so the design decision isn't lost.
