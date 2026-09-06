---
id: 20260701-align-blueprint-update-adapter-docs-arg-order-and-step-1-cross-r
num: 25
title: "Align blueprint-update adapter docs (arg-order and Step-1 cross-ref)"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [blueprint, review, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-01T21:48:41Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/002-blueprint-update/review.md
---

## Description

## Context

Surfaced by the spec 030 post-build review (Findings 2 and 3). Both are cosmetic
documentation inconsistencies with no functional impact — the adapter parses
correctly either way — bundled here.

## Arg-order inconsistency (Finding 2)

`/jim:review` Step 10 invokes `/jim:blueprint` with `"<group> --from-review <spec-dir>"`
(group-first), while `/jim:blueprint`'s `argument-hint` and routing table document
flag-first `--from-review <spec-dir> <group>`. Both parse correctly (the flag
carries its own value, so stripping is position-independent), but the two skills
state the order differently. Pick one order and make both match.

## Step-1 cross-reference (Finding 3)

`/jim:review` Step 10 says the group was "loaded in Step 1", but Step 1 only calls
out reading the ACs and `type`. `spec.md` is read whole (so `group` is available),
but the parenthetical is imprecise. Adjust it, or name `group` in Step 1.

## Relates to

spec 030 DD1; `skills/review/SKILL.md` Step 10; `skills/blueprint/SKILL.md` lines 13, 33.

## Resolution

Both cosmetic doc inconsistencies aligned (no spec — prose only):

- **Arg-order (Finding 2):** picked **flag-first** as canonical and aligned the
  caller to it. `/jim:blueprint`'s user-facing `argument-hint`, routing table,
  and parse prose were already flag-first (`--from-review <spec-dir> <group>`)
  and self-consistent; the divergence was only in `/jim:review` Step 10's
  invocation and offer text, both now flag-first. Rationale: the callee owns
  its published grammar, so the caller matches it rather than editing the
  contract. Parsing is position-independent, so runtime is unchanged. Swept
  both skills — no group-first references remain.
- **Step-1 cross-ref (Finding 3):** `/jim:review` Step 1 now names `group`
  alongside the ACs and `type` in the `spec.md` read, so Step 10's "the
  `group:` field (loaded in Step 1)" is accurate.
