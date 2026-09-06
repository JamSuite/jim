---
id: 20260712-record-and-sense-chronic-domain-domain-straddle-flags
num: 72
title: "Record and sense chronic domain-domain straddle flags"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [partition, health, spec-advisor]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-12T07:21:07Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/016-partition-health/spec.md
---

## Description

## Context

`/jim:spec`'s assignment advisor (spec 033) flags a domain↔domain straddle
as a partition smell during spec filing — but the flag is conversational
only, recorded nowhere. Spec 044's partition-health sensors deliberately
scoped this signal out: "chronic straddle" needs a durable record to trend
over, and the recording surface touches a second skill (`/jim:spec`), so it
deferred to keep 044 thin.

## What

Two slices:

- **A recording surface** — when the advisor flags a domain↔domain
  straddle, record it durably as a content-free trace (following the
  established stage-event pattern), so "chronic" becomes measurable.
- **A trend sensor** — the partition-health surface shipped by spec 044
  reads the accumulated straddle records as an additional signal class:
  chronic straddling of the same group pair is a split/merge smell feeding
  the reasoned proposal.

Sibling of the signal classes shipped by 044 (origin). Distinct from the
**straddle-count metric** (one territory unit serving multiple groups),
which remains separately deferred behind spec 038's extractor fork per
spec 039 — this issue is about advisor-flag recording, not code-level
dependency extraction.

See also [[20260704-add-partition-health-sensors-split-merge-signals]].
