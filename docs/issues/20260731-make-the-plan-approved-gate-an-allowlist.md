---
id: 20260731-make-the-plan-approved-gate-an-allowlist
num: 167
title: "Make the plan approved gate an allowlist"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-31T11:49:24Z
updated: 2026-07-31T11:49:24Z
origin: docs/specs/sdlc/000-blueprint/spec.md
---

## Description

`/jim:verify sdlc` scored the `spec-id-sequencing` invariant (high) a partial.
Its two identity clauses hold with strong, converging evidence — the spec flow
mints exclusively through the coordination allocator, explicitly disclaims tree
derivation, is tool-restricted so `next-id` is unreachable from it, and admits
both a 3-digit ordinal and a reserved `P-<date>-<slug>` token end to end.

The third clause — "a spec must be `approved` before its plan is produced" — is
enforced as a one-value **blacklist** rather than an allowlist:

    skills/plan/SKILL.md:32-35
    - `status: draft` — Stop. Tell the user: "This spec is still in draft. …"
    - `status: approved` — Continue.

The lifecycle defines five statuses (`skills/spec/references/spec-types.md:137,
140-146`). A spec whose `status:` is `deprecated`, or absent/garbage in a
hand-authored file, matches **neither** row and has no stated stop. Step 7
(`skills/plan/SKILL.md:102-125`) then writes `plan.md` with no re-check.

The only allowlist phrasing sits in the post-write Validation Checklist —
`skills/plan/SKILL.md:260`, "Spec was `status: approved` before planning began" —
which is evaluated after the plan artifact already exists, so the invariant's
ordering is unenforced for the unenumerated statuses.

`in-progress` and `complete` post-date approval, so continuing there is
consistent with intent; `deprecated` and a missing field are the genuine holes.
`skills/build/SKILL.md:33-36` has the same blacklist shape, so this is the flow's
pattern rather than a one-off.

## Fix

Make the Step-1 gate an allowlist: continue only on `approved` / `in-progress` /
`complete`; stop on anything else, including a missing status. Consider the same
treatment for `/jim:build`'s plan gate.

Surfaced by a `/jim:verify sdlc` run during the `sdlc/018` build. Note that the
two identity clauses were verified holding in that same run, immediately after
the invariant was folded to admit both identity states.
