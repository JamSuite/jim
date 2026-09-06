---
id: 20260723-skills-prose-invocation-lint
num: 90
title: "Generalize the prose-pin pattern into a skills-prose invocation lint"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [meta-test, partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-23T18:43:32Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/023-partition-ref-sweep/plan.md
---

## Description

## Problem

Canonical script-invocation lines in skills prose (SKILL.md flows, methodology
references) carry load-bearing detail — verb order, flags, file sets — that no
mechanical check validates against the scripts' actual contracts. The partition
ref-sweep defect shipped through exactly this channel: the documented sweep
composition was wrong and nothing could catch it.

The ref-sweep fix pins its own composition with a one-off prose-pin test case
(a grep over the four canonical `rewrite-identity --skip-typed-refs` invocation
lines in `skills/partition/SKILL.md` and
`skills/partition/references/partition-methodology.md`), but every other
canonical invocation line in skills prose remains unwatched.

## Suggested action

Evaluate generalizing the prose-pin pattern into a lint: a deterministic check
that verifies the canonical `jimpartition.sh` / `jimledger.sh` / `jimverify.sh`
invocation lines in skills prose against the scripts' usage contracts (verbs
exist, required flags present where flows depend on them). Could live in the
meta-test suite or as a standalone check verb. Weigh value against maintenance
cost — prose is prose, and over-pinning it makes doc edits brittle; the lint
may only be worth it for flag-bearing / order-sensitive invocations.

## Origin

Planning for the partition ref-sweep fix — the prose-pin design decision noted
this covers one composition only.
