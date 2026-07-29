---
id: 20260726-add-provisional-and-reconcile-unreachable-origin-mode
num: 115
title: "Add provisional and reconcile unreachable-origin mode"
status: closed
priority: medium
labels: [id-coordination, config]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-26T19:02:00Z
updated: 2026-07-29T19:38:53Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

`platform/007` ships `on_unreachable = fail` plus local-tier degradation. This adds the opt-in `provisional` mode: visibly non-real provisional IDs (shape TBD, e.g. `P-<date>-<slug>`) issued when origin is unreachable, and a `reconcile` path that on the next successful origin contact allocates real IDs for pending provisionals and rewrites references — for specs, that renames the directory (the same churn as allocate-on-merge).

Open questions to settle:
- Reconcile trigger: automatic on next allocator invocation vs. an explicit verb.
- Provisional-ID shape so it can never collide with an allocated ordinal.

This is also the honest path for fork-workflow contributors (G5) who push only to their fork and cannot allocate against the shared repo: provisional mode plus maintainer-side reconcile at PR review (or the future service backend).

Follow-on to `platform/007` (foundation); `platform`-group.

## Resolution

Shipped as spec `platform/009` (Provisional allocation and reconcile), whose
`origin` is this issue. All 13 ACs met; the post-build review is **`aligned`**
over `ea225c8..61a7891` (8 commits, 4 files, +741/−55) with one low finding and
no invariant or security regressions.

Both open questions were settled:

- **Reconcile trigger** → an explicit, preview-then-apply verb
  (`jimalloc.sh reconcile [--apply]`), not automatic-on-next-allocate. Auto-on-
  allocate couples two concerns and silently no-ops in exactly the offline case
  it would exist for; an explicit verb matches jim's uniform migration doctrine
  and the real workflow of reconciling deliberately, on the host or at PR review.
- **Provisional-ID shape** → a grammar disjoint from every allocated-ordinal
  grammar (the reserved uppercase `P-` prefix, `ALLOC_PROV_PREFIX`). A
  provisional never enters the registry, the next-id high-water, or `peek`, so
  it can neither inflate a later real allocation nor be mistaken for one.

Issuing a provisional touches neither network nor registry; reconcile realizes a
batch through the same guarded CAS as a normal allocation, as one all-or-none
commit, idempotent and resumable, with still-unreachable a clean no-op. Pending
state is embedded in the consumer's own artifact rather than a per-clone log —
which is what makes the fork-workflow (G5) case work by construction: the marker
travels with the branch, so a maintainer reconciles the provisionals a
contributor's change carries. A productized maintainer-facing PR-review flow was
explicitly not built; the mechanism suffices.

The consumer side landed separately as `issue/010`
([[20260726-wire-the-issue-display-ordinal-onto-the-id-coordination-allocato]],
#111): `/jim:issue reconcile`, distinguishable provisional rendering, and the
frontmatter rewrite through the single emitter.

**Spec-side provisional reconcile did not ship here**, by design. Realizing a
provisional *spec* renames its directory and rewrites its references — the
rename/redirect churn owned by the spec-wire and rename-emitting follow-ons
[[20260726-wire-spec-id-allocation-onto-the-id-coordination-allocator]] (#112)
and
[[20260726-emit-rename-split-redirect-records-and-wire-jim-partition-batche]]
(#113). 009's reconcile is consumer-agnostic and composes with them.

Residuals, both tracked: reconcile's high-water filter is stricter than
`alloc_next_num_issue`, so the two can disagree in the presence of a malformed
record —
[[20260727-align-reconcile-high-water-with-alloc-next-num-issue]] (#124); and
whether jim's own agent sandbox should run `id_coordination_unreachable =
provisional` (the machinery now exists — this is a config-and-docs call, not a
build) —
[[20260728-coordinated-issue-filing-hard-fails-in-the-mvm-agent-sandbox]]
(#129).
