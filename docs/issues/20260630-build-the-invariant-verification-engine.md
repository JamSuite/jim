---
id: 20260630-build-the-invariant-verification-engine
num: 22
title: "Build the invariant verification engine"
status: open
priority: medium
labels: [000-blueprint, verification]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-30T20:35:19Z
updated: 2026-06-30T20:35:19Z
origin: docs/specs/jim/029-blueprint-spec/spec.md
---

## Description

## Context

Deferred slice of the `000-blueprint` initiative (spec 029). 029 records each
invariant's criticality + intended verification method but runs nothing.

## What

Execute the recorded verification methods to **check code against a group's
blueprint**:

- A fixed cheap **floor** (always-on mechanical checks — lint / type / AST) plus
  a tunable expensive **ceiling** (tests / judges / adversarial swarm).
- The invariant's type picks the rung; appetite is a config knob keyed off
  **criticality** (verify critical invariants hard, low ones cheaply).
- Detection fans out (per region / layer / invariant); the contract the swarm
  checks IS the blueprint's invariant set.

## Depends on

Spec 029 (which records the invariants + methods).
