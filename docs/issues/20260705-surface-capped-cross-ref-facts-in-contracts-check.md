---
id: 20260705-surface-capped-cross-ref-facts-in-contracts-check
num: 56
title: "Surface capped CROSS-REF facts in contracts-check"
status: closed
priority: low
labels: [verify, contract-graph]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T22:17:53Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/009-verify-contracts/plan.md
---

## Description

`contracts-check` (`skills/verify/scripts/jimverify.sh`, `cmd_contracts_check`)
caps `CROSS-REF` reference facts at `head -n 50` per consumer→provider territory
pair, and emits no marker when the truncation fires. On a consumer with more than
50 distinct references into one provider's territory, the overflow facts are
silently dropped.

The bite is low: a consumer reaching into a provider that many times is already
an unmistakable leak, so the first 50 facts carry the signal. But the truncation
is **silent**, which conflicts with jim's "name every degradation, never absorb
it silently" doctrine (the same reason the floor emits `UNSCOPED`/`UNSCOPED-GROUP`
rather than dropping quietly).

**Proposed action (one of):**

- Emit a `CROSS-REF-CAPPED <consumer> <provider> <n-shown>` record when a pair
  hits the cap, so the `/jim:verify --contracts` skill layer can name the capped
  remainder in the report (mirroring the judge fan-out cap's "un-examined
  remainder" line), or
- Make the per-pair cap configurable (reusing an existing knob rather than
  minting a new one, per spec 037's no-new-config doctrine).

Surfaced during the spec 037 build (`contracts-check` verb, task 3). Not a
correctness bug in the shipped behavior — a completeness/observability hardening.

## Resolution (2026-07-09)

Took **Fork 1 (emit the marker)** and deliberately dropped Fork 2 (configurable
cap): the issue's own text concedes >50 references into one provider is already
an unmistakable leak, so the first 50 carry the signal — there is no dial anyone
needs to turn, and "reuse an existing knob" doesn't fit (`verify_fanout_cap` is
*judge* fan-out, not a grep-line budget; overloading it is a semantic smell, and
minting a new knob violates 037's no-new-config doctrine). Once the cap is
*named*, the literal `50` can be bumped in place if a real need ever appears.

Grounding refined the grain: the `head -n 50` at `jimverify.sh:928` truncates per
**(consumer, provider-territory-path)**, not per pair. The marker is aggregated
to the **pair** grain (the grain the report names), firing once per
consumer→provider when any of that provider's territory-path scans overflowed.

Changes (one atomic commit):

1. **`jimverify.sh` — `cmd_contracts_check`.** Grep now caps at `head -n 51`; the
   loop emits at most 50 CROSS-REF facts (byte-identical output for ≤50) and, when
   a 51st line proves the cap fired, emits one
   `CROSS-REF-CAPPED <consumer> <provider> <n-shown>` after the territory-path
   loop. New record documented in the verb's output vocabulary.
2. **`contracts-methodology.md`.** C3 correlates the new record; the closing
   degradation-naming line names any `CROSS-REF-CAPPED` pair — honoring "name
   every degradation, never a silent drop."
3. **`tests/jimverify.sh`.** `case_jimverify_contracts_crossref_cap_named` builds
   a 60-line consumer reference into one provider and asserts exactly 50 facts
   shown plus the `CROSS-REF-CAPPED\tbilling\taccounts\t50` marker. Suite green at 73.

Left untouched, with reasons: spec 037 artifacts (`plan.md`/`research.md`/
`security.md`) are point-in-time records; `retirement-methodology.md` reads
CROSS-REF only for presence/absence, and the cap never drops a pair below 50, so
it can never fabricate a "no reference" / dead-surface signal.
