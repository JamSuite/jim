---
id: 20260702-surface-targeted-update-count-since-last-full-blueprint-regen
num: 27
title: "Surface targeted-update count since last full blueprint regen"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [000-blueprint, fold-back]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-02T07:00:12Z
updated: 2026-07-25T07:49:14Z
origin: docs/brainstorms/20260630-000-current-spec.md
---

## Context

Spec 030's blueprint update is deliberately diff-scoped: it edits only the
sections the change affects and never regenerates the rest. That keeps the
per-review cost low, but accumulated targeted updates can drift from what a
full whole-group regeneration (spec 029's generate mode) would produce —
non-local implications the diff lens cannot see. The originating brainstorm
called for a gate *or* a visible staleness flag ("behind N reviewed specs");
the gate shipped (`require_blueprint`, default off) but no staleness signal
exists — with default knobs a declined update leaves no trace.

## What

Surface a lightweight regen-cadence signal: when `/jim:blueprint` runs in
update mode, report "N targeted updates since last full generate" so the
developer knows when a whole-group regen is due. Prefer deriving N from
existing state rather than adding new state — e.g. the blueprint file's git
history (`commit-blueprint` commits are distinguishable from a developer-
committed full generate) or a frontmatter field stamped by generate mode.
Signal only — no new gate, no auto-regen.

See also [[20260630-wire-the-000-blueprint-fold-back-loop-into-review]].

## Resolution

Shipped as spec `blueprint/004` (Blueprint regen cadence), `status: complete`. The
signal landed as scoped — `/jim:blueprint` update mode reports "N targeted
updates since last full generate" — via a single-writer `last_full_generate`
frontmatter watermark (stamped only by generate mode) and a deterministic
`jimledger.sh updates-since` counter, so N derives from existing state without
a spec.md write (preserving spec 031's fix-only ledger-only-commit). During
scoping the developer expanded scope beyond the issue's "signal only": an
opt-in, default-off `blueprint_regen_threshold` now triggers a full
regeneration when the count is reached (unattended under `auto_blueprint`,
honoring spec 031 graded autonomy; else prompt). Reviewed `aligned`.
