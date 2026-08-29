---
id: 20260707-strengthen-039-graph-health-test-coverage
num: 64
title: "Strengthen 039 graph-health test coverage"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [test, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-07T06:33:25Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/011-graph-health/review.md
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

Origin: post-build review of spec blueprint/011
(`docs/specs/blueprint/011-graph-health/review.md`).

## Resolution (2026-07-09)

Added four `case_jimverify_health_*` tests (`tests/jimverify.sh`, suite
72→76 green); no production change — all guard existing behavior. The
self-loop face moved to #62 in a prior commit.

- **Determinism → CYCLE ordering.** Augmented `case_..._deterministic`:
  kept run-twice byte-equality and added a direct assertion that CYCLE
  nodes emit in sorted order. Used the codebase's own ordering-assertion
  idiom (awk field extraction, as in `..._fanin_ties_sorted`) rather than
  a tab-laden golden byte-string. This is the **only** guard on
  `isort(AN)`, the cycle-node sort — `isort(FG)` (fan-in) is already
  guarded by `..._fanin_ties_sorted`.
- **Adjacent prefix.** `case_..._coverage_adjacent_prefix`: a file under
  `accountsfoo/` stays uncovered under the `accounts/` territory, pinning
  the slash-anchored prefix (`index(f "/", t "/") == 1`).
- **Length cap.** `case_..._coverage_dir_capped`: a >512-char uncovered
  directory (three nested ~200-char components, each < `NAME_MAX`) is
  capped in `UNCOVERED_DIR`.
- **Duplicate row.** `case_..._duplicate_row`: a repeated
  `(consumer, provider)` row counts in `EDGES` (raw) but is deduped out of
  fan-in / cycles.

**Deliberately not done — the control-char coverage-path case.** The
original third bullet paired the 512-cap (done) with a control-char strip
test. The strip is **belt-only and unreachable through the real path**:
`git ls-files` C-escapes control bytes before they reach the coverage awk
(the same escaping guarantee behind #65). Exercising it would mean driving
the awk in isolation on input the real path can't produce — no coverage of
a reachable behavior. The reachable half (length cap) is covered; the
unreachable half is left, noted here rather than tested for show.

**Teeth verified by mutation.** Neutralizing `isort(AN)` flips the CYCLE
order to hash order and fails the determinism case; making the edge dedup a
no-op inflates fan-in 1→2 and fails the duplicate-row case. Both new
assertions fail when their guarded behavior regresses.
