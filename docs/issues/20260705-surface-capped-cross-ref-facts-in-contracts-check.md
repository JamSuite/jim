---
id: 20260705-surface-capped-cross-ref-facts-in-contracts-check
num: 56
title: "Surface capped CROSS-REF facts in contracts-check"
status: open
priority: low
labels: [verify, contract-graph]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T22:17:53Z
updated: 2026-07-05T22:17:53Z
origin: docs/specs/jim/037-verify-contracts/plan.md
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
