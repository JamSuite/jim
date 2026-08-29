---
id: 20260829-machine-resolvable-contract-graph
num: 421
title: "Machine-resolvable contract graph"
status: open
priority: high
type: epic
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [blueprint, contract-graph, faces, reconcile]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-29T07:44:25Z
updated: 2026-08-29T07:44:25Z
origin: "conversation"
---

## Description

Umbrella for the work that makes the blueprint's provides/requires faces resolve
as a graph rather than read as prose.

The faces are authored as prose and consumed as data, and the two do not meet:
the `faces` verb sees only backtick-first entries, `Provides` keys off artifacts
while `Requires` names capabilities so requires tokens join no provides entry,
and several real cross-group couplings are declared on one side only. Every
downstream consumer — verify's contract checks, reconcile, blast radius, and the
map's Relations column — is reasoning over a graph that does not connect, which
makes their agreement today a coincidence rather than a result.

VISION names the reconciling contract graph as one of jim's two differentiating
pillars, so this is the surface that has to hold before anything built on it
means what it claims.

Sequencing inside the umbrella: fix the reader first (#374 — any measurement
taken while it is blind to a sixth of the faces is wrong), then the vocabulary
join (#377), then the per-group declarations (#373, #420, #204, #376), and only
then the consumers (#40, #41, #44, #97). #373 and #420 describe the same
coupling four days apart and are very likely a duplicate pair — resolve that
before either is scheduled.
