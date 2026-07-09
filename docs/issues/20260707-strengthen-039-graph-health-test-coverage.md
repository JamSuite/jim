---
id: 20260707-strengthen-039-graph-health-test-coverage
num: 64
title: "Strengthen 039 graph-health test coverage"
status: open
priority: low
labels: [test, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-07T06:33:25Z
updated: 2026-07-09T10:50:29Z
origin: docs/specs/jim/039-graph-health/review.md
---

## Description

The spec 039 graph-health build shipped correct and fully green (434/434), but
the thorough post-build review surfaced test-strengthening opportunities in the
`health`-verb suite. None are correctness defects — quality hardening for the
test suite.

- **Determinism assertion is weaker than it looks.**
  `case_jimverify_health_deterministic` asserts same-input-twice byte-equality;
  awk hash order is stable within a version, so the case would still pass if the
  `isort` / sorted-scan were dropped. A fixed expected byte-string, or a direct
  assertion on `FANIN_GROUP` / `CYCLE` line ordering, would faithfully guard
  AC #9.
- **No adjacent-prefix boundary case.** Add coverage that a file under
  `accountsfoo/` stays *uncovered* when the declared territory is `accounts/`
  (the slash-anchored prefix match) — currently only covered/stray/na cases
  exist.
- **No control-char coverage-path case.** The Finding-1 control-char strip /
  512-cap is exercised only on graph *cells* (`crafted_cell_excluded`), not on
  an uncovered *filename* fed through the coverage awk.
- **Duplicate-row semantics are unspecified by test.** The code counts a
  duplicated `(consumer, provider)` row in `EDGES` (the density numerator) but
  dedupes it out of fan-in / cycles (the `eseen` guard). Pin that split with a
  test.

The **self-loop** face of the original combined bullet moved to #62, the
self-edge umbrella. A self-loop (`a→a`) reaching `cmd_health` as a 1-node cycle
cluster is the health-side face of the same "what is a self-edge in the contract
graph?" doctrine #62 settles across `cmd_edges` / `cmd_contracts_check` /
`cmd_health` — a layer decision (guard at the shared `cmd_edges` root vs
per-loop), not a current behavior to pin blind here.

Origin: post-build review of spec jim/039
(`docs/specs/jim/039-graph-health/review.md`).
